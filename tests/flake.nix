# Test fixture and usage example: binds brew-nix to brew-api data and to the
# tap layout in ./fixtures/taps.
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
        brewTaps = brew-nix.lib.mkTaps {
          inherit pkgs;
          source = ./fixtures/taps;
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

        # Every tap directory becomes <user>.<repo> holding that tap's casks.
        eval-taps =
          let
            inherit (self.legacyPackages.${pkgs.stdenv.hostPlatform.system}) brewTaps;
            names = lib.mapAttrs (_: lib.mapAttrs (_: lib.attrNames)) brewTaps;
            drvPaths = lib.collect lib.isString (lib.mapAttrs (_: lib.mapAttrs (_: lib.mapAttrs (_: cask: cask.drvPath))) brewTaps);
          in
          assert names == {
            example = {
              other = [ "kitty" ];
              tap = [ "rectangle" ];
            };
          };
          pkgs.writeText "eval-taps" (builtins.unsafeDiscardStringContext (lib.concatLines drvPaths));
      });
    };
}
