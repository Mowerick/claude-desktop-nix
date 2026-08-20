#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils curl gawk git jq nix
# shellcheck shell=bash
#
# Wired up as passthru.updateScript, so `nix-shell maintainers/scripts/update.nix
# --argstr package claude-desktop` can drive it from a nixpkgs checkout. That
# runner executes update scripts with the repo root as cwd and no guaranteed
# PATH, hence the nix-shell shebang and the sources.json lookup below.
set -euo pipefail

# Located rather than hardcoded: this repo keeps the package in
# pkgs/claude-desktop, nixpkgs would keep it in pkgs/by-name/cl/claude-desktop.
find_sources() {
  local root hit

  if [ -n "${CLAUDE_DESKTOP_SOURCES:-}" ]; then
    echo "$CLAUDE_DESKTOP_SOURCES"
    return 0
  fi

  root=$(git rev-parse --show-toplevel)
  hit=$(git -C "$root" ls-files '*claude-desktop/sources.json' | head -n1)

  if [ -z "$hit" ]; then
    echo "update.sh: no claude-desktop/sources.json tracked under $root" >&2
    return 1
  fi

  echo "$root/$hit"
}

to_sri() {
  nix hash convert --hash-algo sha256 --to sri "$1" 2>/dev/null ||
    nix hash to-sri --type sha256 "$1"
}

# Prints the apt `Packages` index for $1's Debian arch. Kept free of any parsing
# so pin_from_index can be tested offline.
fetch_index() {
  local system="$1" apt_base deb_arch

  apt_base=$(jq -r '.aptBaseUrl' "$sources")
  deb_arch=$(jq -r --arg s "$system" '.systems[$s].debArch' "$sources")

  curl -sf "$apt_base/dists/stable/main/binary-$deb_arch/Packages"
}

# Reads a Packages index on stdin and prints "<version> <sha256-hex> <filename>".
# $1 selects a version; empty (the normal case) means the highest one published.
# Exits non-zero if the chosen version has no SHA256/Filename.
pin_from_index() {
  local version="${1:-}" index
  index=$(cat)

  if [ -z "$version" ]; then
    version=$(awk '/^Version:/ { print $2 }' <<<"$index" | sort -V | tail -n1)
  fi

  awk -v v="$version" '
    /^Version:/ { ver = $2 }
    ver == v && /^SHA256:/ && sha == "" { sha = $2 }
    ver == v && /^Filename:/ && file == "" { file = $2 }
    END {
      if (v == "" || sha == "" || file == "") exit 1
      print v, sha, file
    }
  ' <<<"$index"
}

# Appended to by update_system, consumed by the summary at the end.
summary_parts=()
changed=false

update_system() {
  local system="$1" apt_base deb_arch current pin latest sha256_hex filename hash_sri tmp

  apt_base=$(jq -r '.aptBaseUrl' "$sources")
  deb_arch=$(jq -r --arg s "$system" '.systems[$s].debArch' "$sources")
  current=$(jq -r --arg s "$system" '.systems[$s].version' "$sources")

  if ! pin=$(fetch_index "$system" | pin_from_index ""); then
    echo "$system: no usable stanza in the $deb_arch Packages index" >&2
    return 1
  fi
  read -r latest sha256_hex filename <<<"$pin"

  summary_parts+=("$deb_arch $latest")

  if [ "$current" = "$latest" ]; then
    echo "$system: already up to date: $current"
    return 0
  fi

  changed=true
  hash_sri=$(to_sri "$sha256_hex")
  echo "$system: $current -> $latest ($hash_sri)"

  tmp=$(mktemp)
  jq --arg s "$system" --arg v "$latest" --arg u "$apt_base/$filename" --arg h "$hash_sri" \
    '.systems[$s].version = $v | .systems[$s].url = $u | .systems[$s].hash = $h' \
    "$sources" >"$tmp"
  mv "$tmp" "$sources"
}

# Guarded so ./tests/parse-index.sh can source the functions above.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  sources=$(find_sources)

  for system in $(jq -r '.systems | keys[]' "$sources"); do
    update_system "$system"
  done

  # CI builds its PR title from this, so the pin format stays private to this script.
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    summary=$(printf '%s, ' "${summary_parts[@]}")
    {
      echo "summary=${summary%, }"
      echo "changed=$changed"
    } >>"$GITHUB_OUTPUT"
  fi
fi
