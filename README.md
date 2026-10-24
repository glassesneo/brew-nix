# brew-nix

[![test](https://github.com/glassesneo/brew-nix/actions/workflows/test.yml/badge.svg)](https://github.com/glassesneo/brew-nix/actions/workflows/test.yml)

An experimental nix expression to package macOS [Homebrew Casks](https://brew.sh/) automatically, including casks from third-party taps.

This is a fork of [BatteredBunny/brew-nix](https://github.com/BatteredBunny/brew-nix).

## Benefits over nix-darwin's homebrew module

1. No homebrew installation needed; packages are fully managed by nix.
2. Pure nix, package derivations; everything is type checked and it will give you an error when you specify an invalid package for example.

## Limitations/Flaws

1. Running most programs with `nix run` won't work, you'll have to build them first.
2. Some programs refuse to run from non-standard locations, since this is automatic there isn't a good way to fix it.
3. There're about 700 casks without hashes, so you have to [override the derivation attributes & provide a hash explicitly](#overriding-casks-derivation-attributes-for-casks-with-no-hash).
4. Having several generations with this will take A LOT of disk space, so keep that in mind.
5. Only `aarch64-darwin` is supported. Intel Macs are not tested.

## Related projects

- [mac-app-util](https://github.com/hraban/mac-app-util)
- [nixcasks](https://github.com/jcszymansk/nixcasks)

# Design

brew-nix is only the mechanism; the cask data comes from elsewhere.

- `brew-nix.lib.mkCasks { pkgs, source }` turns one data source into an attrset of cask packages. `source` is a directory containing a `cask.json`.
- [`brew-api`](https://github.com/BatteredBunny/brew-api) provides `cask.json` for the official `homebrew/cask` tap.
- `gen-tap` produces the same `cask.json` format for any third-party tap.

brew-nix pins no data and provides no overlay. You bind data to it once in your own flake and decide where the packages live.

# Setup

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    brew-nix = {
      url = "github:glassesneo/brew-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    brew-api = {
      url = "github:BatteredBunny/brew-api";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, brew-nix, brew-api, ... }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      legacyPackages.${system} = {
        brewCasks = brew-nix.lib.mkCasks {
          inherit pkgs;
          source = brew-api;
        };
      };
    };
}
```

Then reference the packages explicitly wherever you need them:

```nix
let
  brewCasks = self.legacyPackages.${system}.brewCasks;
in
[
  brewCasks.marta
  brewCasks."firefox@developer-edition" # Casks with special characters in their name need to be defined in quotes
]
```

or build them directly:

```bash
nix build .#brewCasks.blender
./result/Applications/Blender.app/Contents/MacOS/Blender
```

`mkCasks` is a plain function, so you can just as well hand its result to modules through `_module.args`, a `let` binding, or an overlay if you prefer.

## Third-party taps

Each tap is a separate data source, generated with `gen-tap` (requires `brew` on `PATH`):

```bash
nix run github:glassesneo/brew-nix#gen-tap -- nikitabobko/tap > cask.json
```

To keep the data up to date, put it in its own repository and call the reusable workflow on a schedule:

```yaml
# .github/workflows/update.yml in your tap data repository
name: update
on:
  schedule:
    - cron: "0 0 * * *"
  workflow_dispatch:

jobs:
  gen-tap:
    permissions:
      contents: write
    uses: glassesneo/brew-nix/.github/workflows/gen-tap.yml@main
    with:
      tap: nikitabobko/tap
```

Add the repository as a non-flake input and bind it next to `brewCasks`:

```nix
inputs.my-tap = {
  url = "github:you/my-tap-data";
  flake = false;
};

legacyPackages.${system} = {
  brewCasks = brew-nix.lib.mkCasks { inherit pkgs; source = brew-api; };
  brewTaps.nikitabobko = brew-nix.lib.mkCasks { inherit pkgs; source = my-tap; };
};
```

brew-nix never merges sources, so tap casks cannot shadow `homebrew/cask` ones unless you merge them yourself.

# Overriding

## Overriding cask's derivation attributes for casks with no hash

Many casks do not come with their hash so you'll have to provide one explicitly.

```nix
(brewCasks.marta.overrideAttrs (oldAttrs: {
  src = pkgs.fetchurl {
    url = builtins.head oldAttrs.src.urls;
    hash = lib.fakeHash; # Replace with actual hash after building once
  };
}))
```

## Overriding cask's variation

Some casks ship different builds per macOS version or architecture. To pick a specific one, override the cask variant chosen.
You can look up each cask's respective variations at [brew.sh](https://brew.sh/).

```nix
brewCasks.visual-studio-code.override { variation = "sequoia"; }
```

## Overriding both cask's variation & derivation attributes

```nix
(brewCasks.visual-studio-code.override { variation = "sequoia"; }).overrideAttrs (oldAttrs: {
  src = pkgs.fetchurl {
    url = lib.lists.head oldAttrs.src.urls;
    hash = lib.fakeHash; # Replace with actual hash after building once
  };
})
```

# Development

[`tests/flake.nix`](tests/flake.nix) binds brew-nix to brew-api and serves as the test fixture.

```bash
nix flake check ./tests # evaluate every cask
./test.py               # build representative casks
```
