# Witcher 3 mods: Signpost Router and Minimap Zoom

Two WitcherScript mods for The Witcher 3 game version 5.0 (Remastered). Both are loose script mods plus a settings XML.

## Signpost Router

When you set a map waypoint, the mod compares walking straight there against walking to a signpost, fast travelling, and walking from the exit signpost. If the route is clearly shorter it places an intermediate pin on the entry signpost (Redirect mode) or just draws a line on the minimap (Overlay mode).

### Install

```
powershell -ExecutionPolicy Bypass -File tools\install.ps1
```

Pass `-GameDir "<path>"` if the game is not in `D:\SteamLibrary\steamapps\common\The Witcher 3`. This copies `mods\modSignpostRouter` and `modSignpostRouter.xml` into the game folder.

### Uninstall

Delete `<game>\mods\modSignpostRouter` and `<game>\bin\config\r4game\user_config_matrix\pc\modSignpostRouter.xml`.

### Settings

Options -> Mods -> Signpost Router. The row labels currently render blank on 5.0 (see Known limits), so here is the row order, top to bottom:

1. Enabled (toggle)
2. Mode: Redirect game path / Overlay line only (options)
3. Fast travel penalty in metres (slider 0-500)
4. Detour factor in percent (slider 100-200)
5. Minimum saving in metres (slider 0-1000)
6. Show route line (toggle)
7. Show status, one-shot (toggle)
8. Run self-test, one-shot (toggle)
9. Calibrate line colours, one-shot (toggle)

One-shot toggles run once and switch themselves back off.

### Reading Status

Switch row 7 on. A notification shows the current plan: direct and route cost in metres, the entry and exit signpost tags, the pin state and whether the line is drawn. Rows 8 and 9 are developer aids (self-test and colour calibration lines).

### Known limits

- Distances are straight-line estimates, not real path lengths.
- No cross-region routing.
- A manual pin replaced before quitting the game is not restored after restarting.
- Settings labels are blank on 5.0: unknown localisation keys render empty, and no verified way to ship a 5.0 `.w3strings` was found yet.

## Minimap Zoom

Changes the minimap radius so you can see further.

### Install

```
powershell -ExecutionPolicy Bypass -File minimap-zoom\install.ps1
```

Uninstall by deleting `<game>\mods\modMinimapZoom` and `modMinimapZoom.xml` from the same config folder.

### Settings

Options -> Mods -> Minimap Zoom (labels also blank). Rows in order:

1. Minimap radius outdoors in metres (slider 33-200, default 100)
2. Also zoom out indoors (toggle, default off)
