# Witcher 3 mods: Signpost Router and Minimap Zoom

Two WitcherScript mods for The Witcher 3 Remastered (game version 5.0). Both are loose script mods with a settings page under Options -> Mods. No REDkit needed: loose `.ws` scripts with `@wrapMethod` / `@addMethod` annotations compile on 5.0, and no vanilla files are changed.

## Signpost Router

Uses fast-travel signposts when they get you to your objective faster than walking.

- **Route guidance.** For the tracked quest objective (or your own waypoint), the mod compares walking straight there against walking to a signpost, fast travelling, and walking from the signpost nearest the target. If the signpost route is clearly cheaper, it shows it on the minimap:
  - *Redirect game path* mode moves the game's guidance to the entry signpost by placing a waypoint there.
  - *Overlay line only* mode leaves the game's path alone.
  - In both modes, coloured dots on the minimap mark the route to the entry signpost and from the exit signpost to the target.
- **Signpost Jump.** When you open the map at a signpost, press **T** (gamepad: L3) to fast travel straight to the signpost nearest your target. Selecting the signpost you are standing at does the same. The key hint only appears when there is somewhere to jump to.

### Install

```
powershell -ExecutionPolicy Bypass -File tools\install.ps1
```

Pass `-GameDir "<path>"` if the game is not in `D:\SteamLibrary\steamapps\common\The Witcher 3`. This copies `mods\modSignpostRouter` and `modSignpostRouter.xml` into the game folder.

### Uninstall

Delete `<game>\mods\modSignpostRouter` and `<game>\bin\config\r4game\user_config_matrix\pc\modSignpostRouter.xml`.

### Settings

Options -> Mods -> Signpost Router:

| Setting | What it does |
|---|---|
| Enabled | Turns the mod on or off |
| Mode | Redirect game path / Overlay line only |
| Fast travel penalty (m) | How many metres of walking one fast travel is worth (loading screen cost). Default 150 |
| Detour factor (%) | Multiplier on straight-line distance, since roads are never straight. Default 130 |
| Minimum saving (m) | The signpost route must save at least this much. Default 200 |
| Show route dots | Draws the dotted route on the minimap |
| Route colour | Cyan, Gold, Magenta, Lime, Orange or Dark green |
| Show status (one-shot) | Shows the current plan: costs, entry/exit signposts, pin and dot state |
| Run self-test (one-shot) | Runs the planner tests; expect "ALL 20 PASSED" |

One-shot toggles run once and switch themselves back off.

### Known limits

- Distances are straight-line estimates, not real path lengths.
- Only signposts in the current region are used; no cross-region routing.
- Guidance pauses indoors, while sailing and during dialogue or cutscenes.
- After a fast travel the plan usually becomes "walk direct", so only the game's own path shows.

## Minimap Zoom

Shows more of the world on the minimap. Signpost Router's dots scale with it.

### Install

```
powershell -ExecutionPolicy Bypass -File minimap-zoom\install.ps1
```

Uninstall by deleting `<game>\mods\modMinimapZoom` and `modMinimapZoom.xml` from the same config folder.

### Settings

Options -> Mods -> Minimap Zoom:

| Setting | What it does |
|---|---|
| Minimap radius outdoors (m) | 33-200, default 100 (vanilla is 33) |
| Also zoom out indoors | Off by default, so interiors keep the vanilla zoom |

## Development

- `src/` - Signpost Router sources: scripts in `src/mods/modSignpostRouter/content/scripts/local/`, settings XML in `src/bin/...`, menu labels in `src/strings/en.txt`.
- `minimap-zoom/` - Minimap Zoom sources, same layout.
- `tools/w3strings.ps1` - reads and writes 5.0 `.w3strings` files (UTF-8, v164). The format is ported from [Witcher3StringEditor](https://github.com/0x7A2C9E5D/Witcher3StringEditor) (MIT).
- `tools/build-strings.ps1` - rebuilds both mods' `en.w3strings` from the `en.txt` files and checks every key round-trips. Run it after editing labels. Label keys: `panel_<Group>`, `option_<VarId>`, `preset_value_<OptionName>`.
- `probe/` - the original feasibility probe used to confirm what works on 5.0 without REDkit. `tools/install.ps1` removes it from the game if present.

Script errors show on the game's startup screen; lines starting with `Warning [content0]` come from the base game and can be ignored.

### Minimap path notes (verified on 5.0)

- `DeleteMapPaths` with any known id wipes every path; paths added afterwards draw fine.
- Only the last `AddMapPath` in a frame takes effect, so dots are sent one per frame.
- An id the minimap has already seen is ignored, so every dot gets a fresh id.
- Placing a map pin wipes paths.
- Path colour is ARGB (alpha 0 is invisible).
