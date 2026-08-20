# Cowork probes fixed Debian firmware paths (AAVMF_CODE.fd on arm64, else
# OVMF_CODE_4M.fd then OVMF_CODE.fd) and derives the VARS path from the hit by
# string substitution, so both files must sit side by side under those names.
# Nixpkgs ships them in $out/FV/, hence this shim.
{
  stdenv,
  runCommand,
  OVMF,
}:

let
  dir = if stdenv.hostPlatform.isAarch64 then "AAVMF" else "OVMF";
in
runCommand "claude-desktop-ovmf-layout" { } ''
  mkdir -p $out/share/${dir}
  ln -s ${OVMF.firmware} $out/share/${dir}/${dir}_CODE.fd
  ln -s ${OVMF.variables} $out/share/${dir}/${dir}_VARS.fd
''
