# artcraft-flake

Nix packages and a Home Manager module for the
[ArtCraft](https://getartcraft.com/apps) creative suite
([storytold](https://github.com/storytold)). Each package contains the desktop
app, `<app>-cli` and `<app>-mcp-headless` (`<app>-cli mcp` over stdio).

A scheduled GitHub Action checks every app for a new stable release every six
hours, pins the published SHA-256 of each Linux tarball in `releases.json`,
builds and tests the whole suite, and commits the result.

## Apps

| App | Use |
| --- | --- |
| [PhotoCraft](https://getartcraft.com/apps/photocraft) | Image editing |
| [VectorCraft](https://getartcraft.com/apps/vectorcraft) | Vector illustration, logos and diagrams |
| [FilmCraft](https://getartcraft.com/apps/filmcraft) | Video editing |
| [LightCraft](https://getartcraft.com/apps/lightcraft) | Photo library and RAW development |
| [PdfCraft](https://getartcraft.com/apps/pdfcraft) | Read, organize, combine and split PDFs |
| [EffectCraft](https://getartcraft.com/apps/effectcraft) | Motion graphics and visual effects |
| [DesignCraft](https://getartcraft.com/apps/designcraft) | Page layout and publishing |
| [FigCraft](https://getartcraft.com/apps/figcraft) | Interface design and prototyping |
| [WordCraft](https://getartcraft.com/apps/wordcraft) | Word processing |
| [SoundCraft](https://getartcraft.com/apps/soundcraft) | Audio recording, editing and mixing |
| [DeckCraft](https://getartcraft.com/apps/deckcraft) | Presentations |
| [CADCraft](https://getartcraft.com/apps/cadcraft) | CAD drawing and drafting |
| [GridCraft](https://getartcraft.com/apps/gridcraft) | Spreadsheets |

Packages are provided for `x86_64-linux` and `aarch64-linux`. CI tests
aarch64 natively, but it is not runtime-tested on real hardware.

## Usage

```nix
{
  inputs.artcraft = {
    url = "github:FelipeMalacarne/artcraft-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

### Home Manager module

```nix
{
  imports = [ inputs.artcraft.homeManagerModules.default ];

  programs.artcraft = {
    apps.filmcraft.enable = true;
    apps.photocraft.enable = true;
    mcp.enable = true;
  };
}
```

- Importing the module installs nothing; every app is opt-in.
- `apps.<app>.package` overrides the package. It must provide `<app>-cli`.
- `mcp.enable` registers `craft-<app>` for each selected app in Home Manager's
  shared `programs.mcp.servers`, so clients with `enableMcpIntegration`
  (for example OpenCode) pick them up. The server runs
  `<app>-cli mcp` headlessly. It is not a live bridge to an open GUI window,
  so save from the agent and open the saved file in the desktop app.
- Packages are built from your Home Manager `pkgs`, so `nixpkgs.follows`
  controls the runtime libraries.

### Packages and overlay

```sh
nix run github:FelipeMalacarne/artcraft-flake#filmcraft
nix shell github:FelipeMalacarne/artcraft-flake#filmcraft --command filmcraft-cli --help
```

`overlays.default` adds `pkgs.artcraft.<app>`.

## Updating

```sh
nix run .#artcraft-update -- --check                    # report; exit 1 if updates exist
nix run .#artcraft-update -- --all --write              # update every app
nix run .#artcraft-update -- filmcraft photocraft --write
nix run .#artcraft-update -- filmcraft --version 0.7.2 --write   # pin or roll back
```

The updater fetches every selected release before writing and replaces
`releases.json` atomically, so a missing asset or checksum leaves the catalog
unchanged. It uses the GitHub API when available (`GITHUB_TOKEN` is optional)
and falls back to the public release redirect and `SHA256SUMS.txt`.

Consumers pick up new pins with `nix flake update artcraft`.

## Checks

`nix flake check` runs:

- `module`: default-off, independent selection, overrides and MCP registration.
- `cli`: builds every app and checks `--version` plus an MCP `initialize` and
  `tools/list` handshake, without opening a window.
- `updater`: offline regression tests for the release updater.

A successful build does not prove GUI, GPU or audio-device compatibility.
