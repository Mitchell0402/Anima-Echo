# Testing

## Automated Check

Preferred local command:

```powershell
pwsh -File scripts/check.ps1
```

The script expects a Godot CLI executable to be available as `godot`, `godot4`, or `godot_console`. If Godot is not on `PATH`, pass it explicitly or set `GODOT_BIN`:

```powershell
pwsh -File scripts/check.ps1 -Godot "path/to/godot"
```

## Manual Commands

Refresh Godot imports after a fresh checkout or asset move:

```powershell
godot --headless --editor --quit --path .
```

Run the regression suite:

```powershell
godot --headless --path . -s res://tests/project/run_all.gd
```

Smoke start the town:

```powershell
godot --headless --path . --quit-after 3
```

Smoke start the mine:

```powershell
godot --headless --path . res://scenes/mine/test_scene.tscn --quit-after 3
```

## What The Current Tests Cover

`tests/project/run_all.gd` currently checks:

- Mine scene structure and route back to town.
- Project layout normalization.
- Stale `res://` path cleanup.
- Town and mine asset presence.
- Town/mine movement constraints.
- Mine gem drop visibility and hotbar icon resolution.
- Runtime economy initialization and mine-to-town loop.
- Single inventory/currency mutation boundary.

## TODO

- TODO: Add GitHub Actions or another CI runner if this project needs enforced checks on pull requests.
- TODO: Add manual QA notes for editor-driven playtesting once the cleanup baseline is stable.
