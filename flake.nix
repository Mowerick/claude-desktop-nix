{
  description = "Unofficial Nix packaging of Claude Desktop for Linux (FHS-wrapped, from Anthropic's .deb)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Upstream is unfree, so this flake's own outputs have to accept that or
      # nothing here evaluates without `--impure` plus NIXPKGS_ALLOW_UNFREE.
      # Only these outputs are affected; overlay consumers keep their own config.
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
    in
    {
      packages = forAllSystems (system: {
        default = self.packages.${system}.claude-desktop;
        claude-desktop = (pkgsFor system).callPackage ./default.nix { };
      });

      overlays.default = final: prev: {
        claude-desktop = final.callPackage ./default.nix { };
      };

      # Thin re-export of the package's own passthru.tests, so `nix flake check`
      # runs them without the tests themselves knowing about flakes.
      checks = forAllSystems (system: self.packages.${system}.claude-desktop.tests);

    };
}
