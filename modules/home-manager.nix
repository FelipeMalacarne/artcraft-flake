{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.artcraft;
  catalog = lib.importJSON ../releases.json;
  packages = import ../pkgs { inherit lib pkgs; };
  enabled = lib.filterAttrs (_: app: app.enable) cfg.apps;
in
{
  options.programs.artcraft = {
    apps = lib.mapAttrs (name: _: {
      enable = lib.mkEnableOption "the ${name} desktop app, `${name}-cli` and `${name}-mcp-headless`";
      package = lib.mkOption {
        type = lib.types.package;
        default = packages.${name};
        defaultText = lib.literalMD "the pinned `${name}` package from artcraft-flake";
        description = "Package to install when ${name} is selected. It must provide `${name}-cli`.";
      };
    }) catalog;

    mcp.enable = lib.mkEnableOption ''
      registering each selected app's headless MCP server (`<app>-cli mcp`) as
      `craft-<app>` in {option}`programs.mcp.servers`
    '';
  };

  config = lib.mkIf (enabled != { }) (
    lib.mkMerge [
      {
        assertions = lib.mapAttrsToList (name: app: {
          assertion = lib.meta.availableOn pkgs.stdenv.hostPlatform app.package;
          message = "programs.artcraft.apps.${name}: no package for ${pkgs.stdenv.hostPlatform.system}.";
        }) enabled;

        home.packages = lib.mapAttrsToList (_: app: app.package) enabled;
      }
      (lib.mkIf cfg.mcp.enable {
        programs.mcp = {
          enable = true;
          # getExe would start the GUI, because each package's mainProgram is the app.
          servers = lib.mapAttrs' (
            name: app:
            lib.nameValuePair "craft-${name}" {
              command = lib.getExe' app.package "${name}-cli";
              args = [ "mcp" ];
              enabled = true;
            }
          ) enabled;
        };
      })
    ]
  );
}
