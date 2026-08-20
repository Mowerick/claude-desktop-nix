#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils curl gawk jq nix
# shellcheck shell=bash
#
# Bumps the pinned version, url and hash in sources.json, one entry per system.
set -euo pipefail

sources=pkgs/by-name/cl/claude-desktop/sources.json

if [ ! -f "$sources" ]; then
  echo "update.sh: $sources not found — run from the repo root" >&2
  exit 1
fi

apt_base=$(jq -r '.aptBaseUrl' "$sources")

# amd64 and arm64 are published independently, so each system is bumped on its own.
mapfile -t systems < <(jq -r '.systems | keys[]' "$sources")

for system in "${systems[@]}"; do
  deb_arch=$(jq -r --arg s "$system" '.systems[$s].debArch' "$sources")
  current=$(jq -r --arg s "$system" '.systems[$s].version' "$sources")

  pin=$(curl -sf "$apt_base/dists/stable/main/binary-$deb_arch/Packages" |
    gawk 'BEGIN { RS = ""; FS = "\n" }
      {
        version = sha = filename = ""
        for (i = 1; i <= NF; i++) {
          split($i, field, " ")
          if (field[1] == "Version:") version = field[2]
          else if (field[1] == "SHA256:") sha = field[2]
          else if (field[1] == "Filename:") filename = field[2]
        }
        if (version && sha && filename) print version, sha, filename
      }' | sort -V | tail -n1)

  if [ -z "$pin" ]; then
    echo "$system: no usable stanza in the $deb_arch Packages index" >&2
    exit 1
  fi

  read -r latest sha256_hex filename <<<"$pin"

  if [ "$current" = "$latest" ]; then
    echo "$system: already up to date: $current"
    continue
  fi

  # `nix hash to-sri` is the spelling on Lix and pre-2.18 Nix.
  hash_sri=$(nix hash convert --hash-algo sha256 --to sri "$sha256_hex" 2>/dev/null ||
    nix hash to-sri --type sha256 "$sha256_hex")
  echo "$system: $current -> $latest ($hash_sri)"

  jq --arg s "$system" --arg v "$latest" --arg u "$apt_base/$filename" --arg h "$hash_sri" \
    '.systems[$s] += { version: $v, url: $u, hash: $h }' \
    "$sources" >"$sources.tmp"
  mv "$sources.tmp" "$sources"

done
