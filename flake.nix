{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    nixosModules = {
      poly = import ./modules/poly.nix;
      greetd = import ./modules/greetd.nix;
      regreet = import ./modules/regreet.nix;
      multiseat = import ./modules/multiseat.nix;
      shared = import ./modules/shared.nix;
    };
    packages.${system} = {
      greetd = pkgs.greetd.greetd.overrideAttrs (old: {
        patches = old.patches ++ [ ./patches/greetd-multiseat-support.patch ];
      });
      regreet = pkgs.greetd.regreet.overrideAttrs (old: {
        patches = old.patches ++ [ ./patches/regreet-multiseat-support.patch ];
      });
    };
  };
}
