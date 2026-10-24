{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;

      # nixpkgs-unstable has dropped x86_64-darwin; mkCasks itself is system agnostic.
      systems = [ "aarch64-darwin" ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # Build an attrset of cask packages from a directory containing a cask.json
      # in brew-api's format, e.g. brew-api itself or the output of gen-tap.
      lib.mkCasks = { pkgs, source }: import ./casks.nix { inherit pkgs source; };

      packages = forAllSystems (pkgs: {
        gen-tap = pkgs.writeShellApplication {
          name = "gen-tap";
          runtimeInputs = [ pkgs.jq ];
          text = builtins.readFile ./gen-tap.sh;
        };
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            wget
            python3
            ruff
            ty
          ];
        };
      });
    };
}
