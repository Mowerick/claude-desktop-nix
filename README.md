# claude-desktop-nix

[![Update](https://github.com/Mowerick/claude-desktop-nix/actions/workflows/update.yml/badge.svg)](https://github.com/Mowerick/claude-desktop-nix/actions/workflows/update.yml)
[![Nix Flake](https://img.shields.io/badge/nix-flake-5277C3?logo=nixos&logoColor=white)](https://nixos.wiki/wiki/Flakes)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Unfree](https://img.shields.io/badge/upstream-unfree-lightgrey.svg)](#caveats)

Unofficial Nix packaging of [Claude Desktop](https://claude.ai) for Linux.

Anthropic ships Claude Desktop as a `.deb` built for Debian/Ubuntu. This flake
unpacks that `.deb` and wraps it in a `buildFHSEnv` sandbox that supplies the
FHS paths, shared libraries, and Cowork VM dependencies (qemu, OVMF,
virtiofsd) it expects, without touching the host system.

## Platform support

| Platform        | Package builds | App tested |
| --------------- | -------------- | ---------- |
| `x86_64-linux`  | yes            | yes        |
| `aarch64-linux` | not verified   | **no**     |

The arm64 pin comes from Anthropic's own apt repo and the derivation evaluates,
but it has never been built or launched — the packaging was developed on
x86_64, and nothing here has run on arm64 hardware. Reports welcome.

## Usage

### Try it

```
nix run github:Mowerick/claude-desktop-nix
```

### As a flake input

```nix
{
  inputs.claude-desktop.url = "github:Mowerick/claude-desktop-nix";

  outputs = { self, nixpkgs, claude-desktop, ... }: {
    # ...
    home.packages = [ claude-desktop.packages.${system}.default ];
  };
}
```

Or via the overlay:

```nix
{
  nixpkgs.overlays = [ claude-desktop.overlays.default ];
}
```

then reference `pkgs.claude-desktop` as usual.

## Hacking

```
nix build .#claude-desktop
nix flake check
```

`checks.<system>` is a re-export of the package's `passthru.tests`. The app
cannot be launched from a build sandbox — `buildFHSEnv` needs bwrap, there is
no display, and the payload is unpatched — so the tests assert the install
layout (launcher, Electron flags, `.desktop` entry, icons, main binary) and
everything beyond that is verified by launching it by hand.

On an x86_64 machine without binfmt emulation, the `aarch64-linux` output can
be evaluated but not built:

```
nix eval .#packages.aarch64-linux.claude-desktop.drvPath
```

## Updating

Anthropic's apt repository has no "latest" alias — `sources.json` pins an
exact versioned `.deb` URL and hash per architecture, so there's nothing that
fails on its own when a new version ships (see `CLAUDE.md` for why). Bump it
from the repo root with:

```
./pkgs/by-name/cl/claude-desktop/update.sh
```

The `nix-shell` shebang pulls in `curl`, `gawk`, `jq` and `nix` itself, so
nothing has to be installed first (it needs `<nixpkgs>` on `NIX_PATH`; run it
as `bash pkgs/by-name/cl/claude-desktop/update.sh` to use the tools already on
your `PATH` instead). It is also wired up as `passthru.updateScript`, so a nixpkgs
checkout can drive it with `maintainers/scripts/update.nix`. It reads the current
version/SHA256 for each architecture straight out of Anthropic's apt `Packages`
indexes and rewrites `sources.json` in place. Review the diff, then commit.

The two architectures are pinned independently — upstream publishes amd64 and
arm64 at their own pace, so one may sit a release behind the other.

A scheduled GitHub Actions workflow (`.github/workflows/update.yml`) runs the
same script daily and opens a pull request when anything changed.

## Caveats

- `x86_64-linux` and `aarch64-linux` only (matches upstream's `.deb`
  architectures); see [Platform support](#platform-support) for what has
  actually been tested.
- Unfree (`license = lib.licenses.unfree`). `packages.<system>` builds its own
  nixpkgs with `allowUnfree`, so `nix run`/`nix build` on this flake need no
  extra flags; via the overlay it is your config that decides, so set
  `nixpkgs.config.allowUnfree = true` (or `allowUnfreePredicate`) there.
- The package lives under `pkgs/by-name/cl/claude-desktop/`, written to nixpkgs
  convention so upstreaming it, is a directory copy; the flake, `default.nix`
  and CI stay outside it.
- Unofficial: not affiliated with or endorsed by Anthropic. Packaging follows
  whatever Anthropic ships in their apt repo; behavior of the app itself is
  entirely upstream's.
