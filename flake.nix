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
    in
    {
      packages = forAllSystems (system: {
        default = self.packages.${system}.claude-desktop;
        claude-desktop = nixpkgs.legacyPackages.${system}.callPackage ./default.nix { };
      });

      overlays.default = final: prev: {
        claude-desktop = final.callPackage ./default.nix { };
      };
    };
}
