# Entry point for `pkgs.callPackage ./default.nix { }`; the package itself lives
# under pkgs/by-name/cl/claude-desktop/, laid out for a straight copy into nixpkgs.
import ./pkgs/by-name/cl/claude-desktop/package.nix
