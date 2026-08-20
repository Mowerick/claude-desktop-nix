# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Nix flake packaging Claude Desktop (Anthropic's unfree Linux `.deb`) as a
`buildFHSEnv`-wrapped derivation. `README.md` covers usage and the update flow;
this file covers what isn't obvious from the source.

## Commands

```
nix build .#claude-desktop
nix flake check                              # passthru.tests, re-exported as checks.<system>
./pkgs/by-name/cl/claude-desktop/update.sh   # bump pins; must run from repo root
```

## Layout rule

Everything under `pkgs/by-name/cl/claude-desktop/` is written to nixpkgs
convention and must not reference anything in this repo — upstreaming is a
directory copy. Repo-specific glue (`flake.nix`, `default.nix`, `.github/`)
stays outside it. Keep that boundary when editing; e.g. the update PR title is
built by the workflow, not by `update.sh`.

## Non-obvious details

- The `.deb` payload is unpatched — no patchelf. Everything it needs comes from
  `buildFHSEnv`'s `targetPkgs` in `package.nix`. That includes node/python/uv/
  git/bash/coreutils/cacert, because MCP servers are spawned as external
  processes.
- `ovmf-layout.nix` exists because Cowork's VM probes fixed Debian firmware
  paths (`AAVMF_CODE.fd` on arm64, else `OVMF_CODE_4M.fd` then `OVMF_CODE.fd`)
  and derives the VARS path from the hit by string substitution, so both files
  must sit side by side under those names — nixpkgs puts them in `$out/FV/`.
- `extraInstallCommands` normalizes cwd to `$HOME` before exec: `buildFHSEnv`'s
  `bwrap` script `--chdir`s into the caller's cwd and aborts inside a
  bind-mounted-over path. It also symlinks in desktop/icon files, since
  `buildFHSEnv` only produces `bin/`.
- `flake.nix` `import`s nixpkgs with `config.allowUnfree = true` instead of
  using `legacyPackages`; without it every command here needs `--impure` plus
  `NIXPKGS_ALLOW_UNFREE=1`, since pure eval can't read the environment. Overlay
  consumers are unaffected.
- `update.sh` is a plain nixpkgs updater (`passthru.updateScript`): it edits the
  working copy, and the nixpkgs runner gives it repo-root cwd and no `PATH` —
  hence the `nix-shell` shebang and the repo-root-relative `sources.json` path.
  Arches are pinned independently because upstream publishes amd64 and arm64 at
  different times.
- `tests.nix` can only assert the install layout — the app needs bwrap and a
  display. Assertions are bare commands under `set -e`/`set -x`, so the failing
  line names itself; don't add hand-rolled failure messages.
- On x86_64 without binfmt, `aarch64-linux` can be evaluated (`nix eval
  .#packages.aarch64-linux.claude-desktop.drvPath`) but not built.

## Commit messages

`<type>: <lowercase imperative summary>`, types in use: `feat`, `fix`,
`refactor`, `docs`, `test`, `ci`, `chore`. State the reason, not just the
change — e.g. `fix: let the flake's own outputs allow unfree, so pure eval
works`.
