{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils = {
      url = "github:numtide/flake-utils/v1.0.0";
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        getErlangLibs =
          erlangPkg:
          let
            erlangPath = "${erlangPkg}/lib/erlang/lib/";
            dirs = builtins.attrNames (builtins.readDir erlangPath);
            interfaceVersion = builtins.head (
              builtins.filter (s: builtins.substring 0 13 s == "erl_interface") dirs
            );
            interfacePath = erlangPath + interfaceVersion;
          in
          {
            path = erlangPath;
            dirs = dirs;
            interface = {
              version = interfaceVersion;
              path = interfacePath;
            };
          };

        # Erlang
        erlangLatest = pkgs.erlang_27;
        erlangLibs = getErlangLibs erlangLatest;
        erl_app = "erlando";

        mkEnvVars = pkgs: erlangLatest: erlangLibs: {
          LOCALE_ARCHIVE = pkgs.lib.optionalString pkgs.stdenv.isLinux "${pkgs.glibcLocales}/lib/locale/locale-archive";
          LANG = "en_US.UTF-8";
          # https://www.erlang.org/doc/man/kernel_app.html
          ERL_AFLAGS = "-kernel shell_history enabled";
          ERL_INCLUDE_PATH = "${erlangLatest}/lib/erlang/usr/include";
        };
      in
      {
        # nix build
        packages = rec {

          # Leverages nix to build the erlang backend release
          # nix build .#server
          erlando =
            let
              deps = import ./rebar-deps.nix { 
                inherit (pkgs) fetchHex fetchFromGitHub fetchgit;
                builder = pkgs.beamPackages.buildRebar3;
              };
            in
            pkgs.beamPackages.rebar3Relx {
              pname = erl_app;
              version = "3.0.0";
              root = ./src;
              src = pkgs.lib.cleanSource ./server;
              releaseType = "release";
              profile = "prod";
              include = [
                "rebar.config"
              ];
              beamDeps = builtins.attrValues deps;
              buildPhase = ''
                runHook preBuild
                HOME=. DEBUG=1 rebar3 as prod release --relname erlando
                runHook postBuild
              '';
            };

        };

        devShells =
          {
            # `nix develop .#ci`
            ci = pkgs.mkShell {
              env = mkEnvVars pkgs erlangLatest erlangLibs;
              buildInputs = with pkgs; [
                erlangLatest
                just
                rebar3
              ];
            };

            erlando = pkgs.mkShell {
              buildInputs = with pkgs; [
                erlangLatest
                rebar3
              ];
            };

            # `nix develop`
            default = pkgs.mkShell {
              packages = with pkgs; [
                erlangLatest
                just
                rebar3
              ];

              enterShell = ''
                 echo "Starting Development Environment..."
              '';

              env = mkEnvVars pkgs erlangLatest erlangLibs;
            };
          };
      }
    );
}
