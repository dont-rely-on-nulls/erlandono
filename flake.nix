{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils = {
      url = "github:numtide/flake-utils/v1.0.0";
    };

    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      devenv,
      flake-utils,
      treefmt-nix,
      ...
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

        # Erlang
        erlangLatest = pkgs.erlang_27;
        lib_name = "erlandono";
        lib_version = "3.1.3";

        mkEnvVars = pkgs: {
          LOCALE_ARCHIVE = pkgs.lib.optionalString pkgs.stdenv.isLinux "${pkgs.glibcLocales}/lib/locale/locale-archive";
          LANG = "en_US.UTF-8";
          # https://www.erlang.org/doc/man/kernel_app.html
          ERL_AFLAGS = "-kernel shell_history enabled";
        };
      in
      {
        # nix build
        packages = {
          # Leverages nix to build the erlang backend release
          # nix build
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
          # `nix develop .#ci`
          ci = pkgs.mkShell {
            env = mkEnvVars pkgs;
            buildInputs = with pkgs; [
              erlangLatest
              rebar3
            ];
          };

          # `nix develop`
          default = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [
              (
                { pkgs, lib, ... }:
                {
                  languages.erlang = {
                    enable = true;
                    package = erlangLatest;
                  };

                  env = mkEnvVars pkgs;

                  enterShell = ''
                    echo "Starting Development Environment..."
                  '';
                }
              )
            ];
          };
        };

        # nix fmt
        formatter = treefmtEval.config.build.wrapper;
      }
    );
}
