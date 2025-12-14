{
  description = "Erlandono's flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-parts,
      treefmt-nix,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem =
        { pkgs, system, ... }:
        let
          erlangLatest = pkgs.erlang;
          lib_name = "erlandono";
          rebar_config = builtins.readFile ./rebar.config;
          match = builtins.match ".*release,.+${lib_name}, \"([0-9.]+)\".*" rebar_config;
          lib_version = builtins.head match;

          treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
        in
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          # nix build
          packages = {
            default =
              let
                deps = import ./rebar-deps.nix {
                  inherit (pkgs) fetchHex fetchFromGitHub fetchgit;
                  builder = pkgs.beamPackages.buildRebar3;
                };
              in
              pkgs.beamPackages.buildRebar3 {
                name = lib_name;
                version = lib_version;
                src = ./.;
                profile = "prod";
                beamDeps = builtins.attrValues deps;
              };
          };

          devShells = {
            # nix develop .
            default = pkgs.mkShell {
              packages =
                with pkgs;
                [
                  erlang-language-platform
                  rebar3
                ]
                ++ [ erlangLatest ];
            };
          };

          # nix fmt
          formatter = treefmtEval.config.build.wrapper;

          # nix flake check --all-systems
          checks = {
            formatting = treefmtEval.config.build.check self;
          };
        };
    };
}
