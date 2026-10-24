# Test fixture and usage example: binds brew-nix to brew-api data.
# Run from the repository root, e.g. `nix build ./tests#brewCasks.rectangle`.
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    brew-nix = {
      url = "path:..";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    brew-api = {
      url = "github:BatteredBunny/brew-api";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      brew-nix,
      brew-api,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      systems = [ "aarch64-darwin" ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      legacyPackages = forAllSystems (pkgs: {
        brewCasks = brew-nix.lib.mkCasks {
          inherit pkgs;
          source = brew-api;
        };
      });

      # Evaluate every cask without building them.
      checks = forAllSystems (pkgs: {
        eval-casks =
          let
            inherit (self.legacyPackages.${pkgs.stdenv.hostPlatform.system}) brewCasks;
            drvPaths = lib.mapAttrsToList (_: cask: cask.drvPath) brewCasks;
          in
          pkgs.writeText "eval-casks" (builtins.unsafeDiscardStringContext (lib.concatLines drvPaths));
      });
    };
}
