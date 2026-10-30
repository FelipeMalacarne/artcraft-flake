{
  lib,
  pkgs,
  module,
}:
let
  # Minimal stand-ins for the Home Manager options the module writes to.
  stubs = {
    options = {
      assertions = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
      };
      home.packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
      };
      programs.mcp = {
        enable = lib.mkEnableOption "mcp";
        servers = lib.mkOption {
          type = lib.types.attrsOf lib.types.attrs;
          default = { };
        };
      };
    };
  };
  evaluate =
    settings:
    (lib.evalModules {
      specialArgs = { inherit pkgs; };
      modules = [
        module
        stubs
        { programs.artcraft = settings; }
      ];
    }).config;
  none = evaluate { };
  film = evaluate { apps.filmcraft.enable = true; };
  selected = evaluate {
    apps = {
      filmcraft.enable = true;
      photocraft.enable = true;
      effectcraft.enable = true;
    };
  };
  overridden = evaluate {
    apps.filmcraft = {
      enable = true;
      package = pkgs.hello;
    };
    mcp.enable = true;
  };
  mcp = evaluate {
    apps = {
      filmcraft.enable = true;
      photocraft.enable = true;
    };
    mcp.enable = true;
  };
  mcpOnly = evaluate { mcp.enable = true; };
  all = evaluate {
    apps = lib.mapAttrs (_: _: { enable = true; }) (lib.importJSON ../releases.json);
  };
  names = cfg: map lib.getName cfg.home.packages;
in
assert lib.assertMsg (names none == [ ]) "Importing the module must install nothing";
assert lib.assertMsg (
  names film == [ "filmcraft" ]
) "Selecting FilmCraft must install only FilmCraft";
assert lib.assertMsg (
  names selected == [
    "effectcraft"
    "filmcraft"
    "photocraft"
  ]
) "App selections must be independent";
assert lib.assertMsg (names overridden == [ "hello" ]) "Package overrides must be honored";
assert lib.assertMsg (builtins.length (names all) == 13) "Every catalog app must be selectable";
assert lib.assertMsg (lib.all (
  a: a.assertion
) all.assertions) "Every app must support this platform";
assert lib.assertMsg (
  !film.programs.mcp.enable && film.programs.mcp.servers == { }
) "MCP registration must be opt-in";
assert lib.assertMsg (
  !mcpOnly.programs.mcp.enable && mcpOnly.programs.mcp.servers == { }
) "MCP without selected apps must register nothing";
assert lib.assertMsg (
  mcp.programs.mcp.enable
  &&
    builtins.attrNames mcp.programs.mcp.servers == [
      "craft-filmcraft"
      "craft-photocraft"
    ]
  && mcp.programs.mcp.servers.craft-filmcraft.args == [ "mcp" ]
) "Each selected app must register one craft-<app> server";
assert lib.assertMsg (
  mcp.programs.mcp.servers.craft-filmcraft.command
  == lib.getExe' mcp.programs.artcraft.apps.filmcraft.package "filmcraft-cli"
) "MCP must launch the CLI of the default package";
assert lib.assertMsg (
  overridden.programs.mcp.servers.craft-filmcraft.command == "${pkgs.hello}/bin/filmcraft-cli"
) "MCP must launch the CLI from the selected package, not its GUI mainProgram";
pkgs.runCommand "artcraft-module" { } "touch $out"
