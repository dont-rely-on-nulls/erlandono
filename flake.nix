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

        # Erlang
        erlangLatest = pkgs.erlang_27;
        lib_name = "erlandono";
        lib_version = "3.1.2";

        mkEnvVars = pkgs: erlangLatest: {
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

        devShells =
          {
            # `nix develop .#ci`
            ci = pkgs.mkShell {
              env = mkEnvVars pkgs erlangLatest;
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

              env = mkEnvVars pkgs erlangLatest;
            };
          };
      }
    );
}
