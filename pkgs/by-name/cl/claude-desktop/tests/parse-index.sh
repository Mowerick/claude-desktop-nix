#!/usr/bin/env bash
# Exercises pin_from_index against a fixture index whose stanzas are deliberately
# out of ascending version order.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091 # sourced only to reuse its functions
source "$here/../update.sh"

fixture="$here/fixtures/Packages"

expect() {
  local what="$1" want="$2" got="$3"
  if [ "$want" != "$got" ]; then
    echo "FAIL: $what: expected '$want', got '$got'" >&2
    exit 1
  fi
}

expect "highest version wins" \
  "1.32885.1 aaaabbbbccccddddeeeeffff0000111122223333444455556666777788889999 pool/main/c/claude-desktop/claude-desktop_1.32885.1_amd64.deb" \
  "$(pin_from_index "" <"$fixture")"

expect "explicit version" \
  "1.100.2 2222222222222222222222222222222222222222222222222222222222222222 pool/main/c/claude-desktop/claude-desktop_1.100.2_amd64.deb" \
  "$(pin_from_index 1.100.2 <"$fixture")"

if pin_from_index 9.9.9 <"$fixture"; then
  echo "FAIL: unknown version should not resolve" >&2
  exit 1
fi

echo "parse-index: ok"
