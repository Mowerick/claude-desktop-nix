# claude-desktop-nix

Standalone Nix flake packaging Claude Desktop (Anthropic's Linux `.deb`) as a
`buildFHSEnv`-wrapped derivation. Extracted from a personal NixOS config so it
can be used as a flake input by anyone.

## Layout

The package is split along nixpkgs' usual file roles, so upstreaming it means
moving `pkgs/claude-desktop/` into nixpkgs' `pkgs/by-name/cl/` and fixing the
one path in `update.sh`:

- `pkgs/claude-desktop/package.nix` — the FHS wrapper, and the `callPackage`
  entry point. Pulls its two siblings in via `callPackage` defaults
  (`claude-desktop-unwrapped`, `coworkRuntime`), so both are overridable.
- `pkgs/claude-desktop/unwrapped.nix` — the .deb's payload dropped into the
  store unmodified. Owns `version`, `src` and `meta`, which the wrapper
  inherits.
- `pkgs/claude-desktop/cowork-runtime.nix` — everything Cowork's VM needs at
  runtime: firmware layout shim, qemu, virtiofsd. Evaluates to a list that
  `package.nix` splices into `targetPkgs`.
- `pkgs/claude-desktop/sources.json` — `aptBaseUrl` plus per-system
  `debArch`/`version`/`url`/`hash` pins. The only module that knows how
  Anthropic's apt repo is laid out; machine-edited by `update.sh`.
- `pkgs/claude-desktop/update.sh` — the version bumper. Splits `fetch_index`
  (network) from `pin_from_index` (pure, reads an index on stdin), so the parse
  can be tested offline.
- `pkgs/claude-desktop/tests/` — `parse-index.sh` plus a `Packages` fixture with
  deliberately out-of-order versions, run as `checks.<system>.parse-index`.
- `default.nix` — one-line `import` of `package.nix`, so
  `pkgs.callPackage ./default.nix { }` still works.
- `flake.nix` — thin wrapper, packages only:
  `packages.<system>.claude-desktop`/`default` and `overlays.default`.

## How the package works

Anthropic publishes a Debian package, not a generic Linux tarball. The package:

1. `fetchurl`s the `.deb` from the pinned `url`+`hash` that `sources.json`
   records for `stdenv.hostPlatform.system` (amd64 for `x86_64-linux`, arm64
   for `aarch64-linux`; each system is pinned independently).
2. Unpacks it with `dpkg-deb --fsys-tarfile` (a `.deb` is an `ar` archive, not
   a tarball — the default unpacker can't handle it).
3. Copies `usr/lib/claude-desktop` + desktop/icon files into a plain
   `stdenv.mkDerivation` (`unwrapped.nix`), unpatched — no patchelf.
4. Wraps that in `buildFHSEnv` (`package.nix`), supplying the FHS paths, shared
   libraries, and Cowork VM dependencies (qemu, OVMF, virtiofsd) the binary
   expects at runtime, so nothing needs runtime patching.

The `.deb` layout is identical across both arches, so only two things are
arch-dependent: the `sources.json` entry, and `cowork-runtime.nix`. Cowork probes
`/usr/share/AAVMF/AAVMF_CODE.fd` on arm64 versus
`/usr/share/OVMF/OVMF_CODE_4M.fd`/`OVMF_CODE.fd` elsewhere (strings in
`resources/app.asar`), hence the `dir` switch in `cowork-runtime.nix`.
`pkgs.OVMF.firmware`/`.variables` already resolve to the right edk2 build per
platform, and nixpkgs' `qemu` builds every target, so `qemu-system-aarch64`
needs no extra input.

Two fixups on top of the bare `buildFHSEnv` output are worth knowing about if
you touch `extraInstallCommands`:

- The launcher normalizes `cwd` to `$HOME` before exec — `buildFHSEnv`'s
  generated `bwrap` script tries to `--chdir` into the caller's cwd, which
  aborts if you launch from inside a bind-mounted-over path like `/etc/...`. A
  GUI app has no use for the caller's cwd anyway.
- Desktop/icon files are symlinked in from `unwrapped`, since `buildFHSEnv`
  only produces `bin/`.

## Updating the pinned version

Anthropic's apt repo (`downloads.claude.ai/claude-desktop/apt/stable`) has no
"latest"-style alias — every URL is versioned and therefore permanently
immutable once published. That means a plain `fetchurl` pin here can **never**
fail on its own when a new version ships (unlike, say, an AppImage published
under a stable `*-latest-*` URL, where a hash mismatch is itself the signal
that upstream moved). There is nothing to go stale loudly; it just quietly
stays on the pinned version forever until someone bumps it.

`update.sh` is the mechanism for that bump. It is repo tooling, not part of the
package — it edits the working copy — so it stays out of the flake's apps:
`flake.nix` exposes packages, the overlay and checks, and both a maintainer and
CI execute the script directly. `passthru.updateScript` points at it for the
nixpkgs convention. For each system in `sources.json` it:

1. Curls that system's apt `Packages` index, built from `aptBaseUrl` +
   `dists/stable/main/binary-$debArch/Packages`. The index lists every
   published version with its `SHA256` and `Filename` inline.
2. Picks the highest version via `sort -V`.
3. Takes that version's `SHA256` and `Filename` straight from the index — no
   need to re-fetch/re-hash the ~170MB `.deb`, and no pool path is ever
   hardcoded outside the JSON.
4. Converts hex SHA256 to Nix's SRI hash format (`nix hash convert`).
5. Rewrites that system's `version`/`url`/`hash` in `sources.json` with `jq`,
   if they've changed. Keeping the pins in JSON is why nothing here has to
   `sed` Nix source.

The systems are deliberately bumped independently: upstream publishes amd64 and
arm64 at different times, so a shared version would either stall the arch that
did get a release or fail the whole run during the skew window.

It edits the file in the repo working copy (found via
`git rev-parse --show-toplevel`), not the Nix store, so it only makes sense run
from a local checkout — not meaningful via a remote flake ref. It shells out to
`nix hash convert`, falling back to `nix hash to-sri` on Lix and pre-2.18 Nix.

`.github/workflows/update.yml` runs `update.sh` on a daily cron (plus
`workflow_dispatch`) and opens a PR via `peter-evans/create-pull-request`,
which no-ops when the working tree is unchanged. The workflow never parses
`sources.json`: the script writes `summary` and `changed` to `$GITHUB_OUTPUT`
and the PR title consumes those. Nix is installed only for `nix hash convert`.

## Testing changes

```
nix build .#claude-desktop
nix run . -- --version   # or just launch it
nix flake check          # runs checks.<system>.parse-index
```

The `aarch64-linux` output can only be evaluated (`nix eval
.#packages.aarch64-linux.claude-desktop.drvPath`) from an x86_64 machine
without emulation — building/launching it needs aarch64 hardware or binfmt.

The only logic worth unit-testing is `update.sh`'s index parsing, and
`checks.<system>.parse-index` covers it offline. Everything else is a packaging
wrapper around an upstream binary: verification is "does it build and does the
app launch".
