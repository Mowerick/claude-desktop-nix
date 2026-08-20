# Anthropic's .deb unpacked into the store as-is — nothing is patchelf'd; the
# binaries stay linked against FHS paths that ./package.nix supplies.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
}:

let
  # amd64 and arm64 are published independently, so each system pins its own
  # version, url and hash. ./update.sh rewrites sources.json.
  inherit (lib.importJSON ./sources.json) systems;

  source =
    systems.${stdenv.hostPlatform.system}
      or (throw "claude-desktop: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "claude-desktop-unwrapped";
  inherit (source) version;

  src = fetchurl { inherit (source) url hash; };

  nativeBuildInputs = [ dpkg ];

  # A .deb is an ar archive, not a tarball — the default unpacker chokes.
  unpackPhase = ''
    runHook preUnpack
    # --no-same-permissions drops chrome-sandbox's setuid bit, unsettable in
    # the build sandbox; the FHS env uses the userns sandbox anyway.
    dpkg-deb --fsys-tarfile $src | tar -x --no-same-permissions --no-same-owner
    runHook postUnpack
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/share
    cp -r usr/lib/claude-desktop $out/lib/claude-desktop
    cp -r usr/share/applications $out/share/applications
    cp -r usr/share/icons $out/share/icons

    runHook postInstall
  '';

  meta = {
    description = "Desktop application for Claude.ai";
    homepage = "https://claude.ai";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames systems;
    mainProgram = "claude-desktop";
  };
})
