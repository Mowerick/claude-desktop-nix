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

## Updating

Anthropic's apt repository has no "latest" alias — `default.nix` pins an
exact versioned `.deb` URL and hash per architecture, so there's nothing that
fails on its own when a new version ships (see `CLAUDE.md` for why). Bump it
with:

```
./pkgs/claude-desktop/update.sh
```

Plain bash; needs `curl`, `jq`, `git` and `nix` on `PATH`. It reads the current
version/SHA256 for each architecture straight out of Anthropic's apt `Packages`
indexes and rewrites `default.nix` in place. Review the diff, then commit.

The two architectures are pinned independently — upstream publishes amd64 and
arm64 at their own pace, so one may sit a release behind the other.

A scheduled GitHub Actions workflow (`.github/workflows/update.yml`) runs the
same script daily and opens a pull request when anything changed.

## Caveats

- `x86_64-linux` and `aarch64-linux` only (matches upstream's `.deb`
  architectures); see [Platform support](#platform-support) for what has
  actually been tested.
- Unfree (`license = lib.licenses.unfree`) — set
  `nixpkgs.config.allowUnfree = true` (or `allowUnfreePredicate`) wherever you
  consume this package.
- The package lives under `pkgs/claude-desktop/`, split the way nixpkgs splits
  such packages so it could be upstreamed with little churn.
- Unofficial: not affiliated with or endorsed by Anthropic. Packaging follows
  whatever Anthropic ships in their apt repo; behavior of the app itself is
  entirely upstream's.
