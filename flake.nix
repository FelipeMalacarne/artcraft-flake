{
  description = "Nix packages and a Home Manager module for the ArtCraft creative suite (storytold/*craft)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      catalog = lib.importJSON ./releases.json;
      # Every cataloged app ships the same set of Linux tarballs.
      linuxSystems = lib.unique (lib.concatMap (app: lib.attrNames app.sources) (lib.attrValues catalog));
      allSystems = linuxSystems ++ [ "aarch64-darwin" ];
      forSystems = systems: f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      isLinux = pkgs: pkgs.stdenv.hostPlatform.isLinux;
    in
    {
      packages = forSystems allSystems (
        pkgs:
        lib.optionalAttrs (isLinux pkgs) (import ./pkgs { inherit lib pkgs; })
        // {
          artcraft-update = pkgs.writeShellApplication {
            name = "artcraft-update";
            runtimeInputs = [ pkgs.python3 ];
            text = ''
              exec python3 ${./scripts/update-releases.py} "$@"
            '';
          };
        }
      );

      overlays.default = final: _prev: {
        artcraft = import ./pkgs {
          inherit (final) lib;
          pkgs = final;
        };
      };

      homeManagerModules = {
        artcraft = ./modules/home-manager.nix;
        default = self.homeManagerModules.artcraft;
      };

      checks = forSystems allSystems (
        pkgs:
        let
          apps = lib.filterAttrs (
            name: _: catalog ? ${name}
          ) self.packages.${pkgs.stdenv.hostPlatform.system};
        in
        {
          updater = pkgs.runCommand "artcraft-updater" { nativeBuildInputs = [ pkgs.python3 ]; } ''
            python3 -B ${./.}/tests/test-update.py
            touch $out
          '';
        }
        // lib.optionalAttrs (isLinux pkgs) {
          module = import ./tests/test-module.nix {
            inherit lib pkgs;
            module = self.homeManagerModules.artcraft;
          };
          cli = pkgs.runCommand "artcraft-cli" { nativeBuildInputs = [ pkgs.python3 ]; } ''
            python3 ${./tests/test-cli.py} ${lib.escapeShellArgs (map toString (lib.attrValues apps))}
            touch $out
          '';
        }
      );

      formatter = forSystems allSystems (pkgs: pkgs.nixfmt-tree);
    };
}
