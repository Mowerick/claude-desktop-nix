#!/usr/bin/env bash
set -euo pipefail

sources="$(git rev-parse --show-toplevel)/pkgs/claude-desktop/sources.json"

to_sri() {
  nix hash convert --hash-algo sha256 --to sri "$1" 2>/dev/null ||
    nix hash to-sri --type sha256 "$1"
}

update_system() {
  local system="$1" deb_arch current packages latest sha256_hex hash_sri tmp

  deb_arch=$(jq -r --arg s "$system" '.[$s].deb' "$sources")
  current=$(jq -r --arg s "$system" '.[$s].version' "$sources")

  packages=$(curl -sf "https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-$deb_arch/Packages")

  latest=$(awk '/^Version:/{print $2}' <<<"$packages" | sort -V | tail -n1)
  sha256_hex=$(awk -v v="$latest" '
    /^Version:/ { ver = $2 }
    ver == v && /^SHA256:/ { print $2; exit }
  ' <<<"$packages")

  if [ -z "$latest" ] || [ -z "$sha256_hex" ]; then
    echo "$system: no version/SHA256 found in the $deb_arch Packages index" >&2
    return 1
  fi

  if [ "$current" = "$latest" ]; then
    echo "$system: already up to date: $current"
    return 0
  fi

  hash_sri=$(to_sri "$sha256_hex")
  echo "$system: $current -> $latest ($hash_sri)"

  tmp=$(mktemp)
  jq --arg s "$system" --arg v "$latest" --arg h "$hash_sri" \
    '.[$s].version = $v | .[$s].hash = $h' "$sources" >"$tmp"
  mv "$tmp" "$sources"
}

for system in $(jq -r 'keys[]' "$sources"); do
  update_system "$system"
done
