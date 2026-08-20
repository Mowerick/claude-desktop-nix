# Everything Cowork's VM needs at runtime. qemu-system-{x86_64,aarch64} come
# from a single nixpkgs qemu (it builds every target), virtiofsd is looked up at
# /usr/libexec or /usr/bin, and /dev/kvm arrives via bwrap's --dev-bind, so the
# host user only needs to be in the kvm group.
#
# Firmware is the awkward one: Cowork probes fixed Debian paths (AAVMF_CODE.fd
# on arm64, else OVMF_CODE_4M.fd then OVMF_CODE.fd) and derives the VARS path
# from the hit by string substitution, so both files must sit side by side under
# those names. Nixpkgs ships them in $out/FV/, hence the shim.
{
  stdenv,
  runCommand,
  OVMF,
  qemu,
  virtiofsd,
}:

let
  dir = if stdenv.hostPlatform.isAarch64 then "AAVMF" else "OVMF";

  firmware = runCommand "claude-desktop-ovmf-layout" { } ''
    mkdir -p $out/share/${dir}
    ln -s ${OVMF.firmware} $out/share/${dir}/${dir}_CODE.fd
    ln -s ${OVMF.variables} $out/share/${dir}/${dir}_VARS.fd
  '';
in
[
  firmware
  qemu
  virtiofsd
]
