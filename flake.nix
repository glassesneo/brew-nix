{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    brew-api = {
      url = "github:BatteredBunny/brew-api";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      brew-api,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
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

      packages = forAllSystems (
        pkgs:
        import ./casks.nix {
          inherit brew-api;
          inherit pkgs;
        }
      );

      overlays.default = final: _: {
        brewCasks = self.packages.${final.stdenv.hostPlatform.system};
      };

      darwinModules.default = lib.modules.importApply ./module.nix { brewCasks = self.overlays.default; };
    };
}
