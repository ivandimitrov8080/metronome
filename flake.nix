{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };
  outputs =
    inputs@{
      nixpkgs,
      systems,
      devenv,
      treefmt-nix,
      ...
    }:
    let
      eachSystem = nixpkgs.lib.genAttrs (import systems);
      mkPkgs = system: import nixpkgs { inherit system; };
      packages = eachSystem (
        system:
        let
          pkgs = mkPkgs system;
          inherit (pkgs) stdenv;
          # to update -> elm2nix --help
          fetchElmDeps = pkgs.elmPackages.fetchElmDeps {
            elmPackages = import ./elm-srcs.nix;
            elmVersion = pkgs.elmPackages.elm.version;
            registryDat = ./registry.dat;
          };
        in
        {
          default = stdenv.mkDerivation {
            name = "idimitrov.dev";
            version = "1.0";
            src = ./.;
            nativeBuildInputs = with pkgs; [
              elmPackages.elm
            ];
            env = {
              LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
              LANG = "en_US.UTF-8";
            };
            postConfigure = fetchElmDeps;
            buildPhase = ''
              runHook preBuild

              elm make src/Main.elm --output elm.js --optimize

              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall

              mkdir -p $out/
              cp index.html $out
              cp elm.js $out
              cp ports.js $out
              cp default.css $out

              runHook postInstall
            '';
          };
        }
      );
      devShells = eachSystem (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
        in
        {
          default = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [
              {
                devenv.root = "/home/ivand/src/idimitrov.dev";
                packages = with pkgs; [
                  elmPackages.elm
                  elmPackages.elm-format
                  elmPackages.elm-json
                  elmPackages.elm-test
                  elm2nix
                  python3Packages.livereload
                  watchexec
                ];
                processes =
                  let
                    livereload = "livereload --host localhost --port 3000 -o 1 -t . .";
                    watcher = "watchexec -- devenv tasks run build";
                    syncElmDeps =
                      pkgs.writers.writeBash "sync_elm_deps"
                        # bash
                        ''
                          elm2nix convert | ${pkgs.nixfmt}/bin/nixfmt -f elm-srcs.nix > elm-srcs.nix
                          elm2nix snapshot
                        '';
                    elm2nixWatcher =
                      # bash
                      ''
                        watchexec -f elm.json -- ${syncElmDeps}
                      '';
                  in
                  {
                    livereload.exec = livereload;
                    watcher.exec = watcher;
                    elm2nix-watcher.exec = elm2nixWatcher;
                  };
                tasks = {
                  "clean:all" = {
                    exec = "rm -rf elm.js";
                  };
                  "build:all" = {
                    exec = "elm make src/Main.elm --output elm.js";
                  };
                  "lint:all" = {
                    exec = "elm-review";
                  };
                  "test:all" = {
                    exec = "elm-test";
                  };
                };
              }
            ];
          };
        }
      );
      formatter = eachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        (treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs = {
            nixfmt.enable = true;
            prettier.enable = true;
            elm-format.enable = true;
            deadnix.enable = true;
            statix.enable = true;
          };
        }).config.build.wrapper
      );
      checks = eachSystem (system: devShells.${system} // packages.${system});
    in
    {
      inherit
        devShells
        formatter
        packages
        checks
        ;
    };
}
