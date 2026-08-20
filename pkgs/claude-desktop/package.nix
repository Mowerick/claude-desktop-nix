{
  lib,
  callPackage,
  buildFHSEnv,
  runtimeShell,
  writeShellScript,
  # GUI / Electron runtime
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  bash,
  cacert,
  cairo,
  coreutils,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  git,
  glib,
  gtk3,
  libGL,
  libdrm,
  libgbm,
  libglvnd,
  libnotify,
  libsecret,
  libxkbcommon,
  libxshmfence,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
  util-linux,
  xdg-utils,
  libx11,
  libxcb,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxtst,
  # MCP execution runtimes
  nodejs,
  python3,
  uv,
  # Cowork VM
  qemu,
  virtiofsd,
  claude-desktop-unwrapped ? callPackage ./unwrapped.nix { },
  ovmfLayout ? callPackage ./ovmf-layout.nix { },
}:

let
  pname = "claude-desktop";
  unwrapped = claude-desktop-unwrapped;

  # "$@" matters: the .desktop entry passes %U and its actions pass
  # claude://claude.ai/new and claude://code/new.
  runScript = writeShellScript "claude-desktop-run" ''
    exec /usr/lib/claude-desktop/claude-desktop \
      --ozone-platform-hint=auto \
      --enable-features=WaylandWindowDecorations \
      "$@"
  '';
in
buildFHSEnv {
  name = pname;
  inherit runScript;

  targetPkgs =
    pkgs:
    [
      # Lands at /usr/lib/claude-desktop inside the FHS env.
      unwrapped
    ]
    ++ [
      # The .deb's Depends:/Recommends: plus the usual Chromium runtime set.
      alsa-lib
      at-spi2-atk
      at-spi2-core
      cairo
      cups
      dbus
      expat
      fontconfig
      freetype
      glib
      gtk3
      libGL
      libdrm
      libgbm
      libglvnd
      libnotify
      libsecret
      libxkbcommon
      mesa
      nspr
      nss
      pango
      systemd
      util-linux
      xdg-utils

      libx11
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxrandr
      libxrender
      libxtst
      libxcb
      libxshmfence

      # MCP servers are spawned as external processes; their runtimes and the
      # shell basics they assume must be on PATH.
      nodejs
      python3
      uv
      bash
      coreutils
      git
      cacert

      # Cowork's VM: qemu-system-{x86_64,aarch64} on PATH (nixpkgs' qemu builds
      # every target), virtiofsd at /usr/libexec or /usr/bin, firmware from
      # ./ovmf-layout.nix. /dev/kvm comes in via bwrap's --dev-bind, so the
      # host user only needs to be in the kvm group.
      qemu
      virtiofsd
      ovmfLayout
    ];

  extraInstallCommands = ''
    mv $out/bin/${pname} $out/bin/.${pname}-fhs
    cat > $out/bin/${pname} <<EOF
    #!${runtimeShell}
    cd "\$HOME" 2>/dev/null || cd /
    exec $out/bin/.${pname}-fhs "\$@"
    EOF
    chmod +x $out/bin/${pname}

    mkdir -p $out/share
    ln -s ${unwrapped}/share/applications $out/share/applications
    ln -s ${unwrapped}/share/icons $out/share/icons
  '';

  passthru = {
    inherit unwrapped;
  };

  # buildFHSEnv does not inherit meta from its inputs.
  inherit (unwrapped) meta;
}
