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

`scripts/check.ps1` runs three steps in order: (1) refresh Godot's import cache in headless mode, (2) run the project regression suite, (3) optionally smoke-start the town and mine scenes. Use `-SkipImportRefresh` after a clean checkout when no assets have changed.

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
- Runtime economy initialization and the full mine-to-town loop (pickup -> hotbar -> `end_mine_run` -> warehouse -> identify / sell / deliver / claim reward).
- Single hotbar / warehouse / wallet / customer budget mutation boundary enforced by `GameTransactionService.apply()` snapshot-and-restore.
- Main scene is the town, not the mine.
- `mining_town.tscn` references the current `mining_town_scene.gd` (no `fused_` script reference).
- `CustomerShopService.list_customers()` returns the customers list, not the tasks list.
- `GameCatalog.get_customers()` returns the expected count from the catalog file.
- `InventoryManager.is_full()` proxies through to `GameRuntime.hotbar.is_full()` (the 18-slot 8-slot fiction is gone).
- `ItemDatabase.get_stack_limit()` reads from `GameRuntime.catalog` (no `const STACK_LIMITS` parallel table).

## Warehouse Manual Verification

After `godot --headless --path . --quit-after 3` (town smoke), run the game in the editor and walk through the following end-to-end flow. The expected behavior is documented in detail in [specs/warehouse-system.md](specs/warehouse-system.md).

1. **Empty start.** Launch town. Open the warehouse with `I`. The grid shows 48 empty grey slots. Press `I` or `Esc` to close. Confirm the player can move freely between open and closed.
2. **In-mine gate.** Press `I` while in the mine. Nothing happens. The input is a no-op there.
3. **Pickup round-trip.** Mine a few geodes. The hotbar at the bottom of the screen shows them. Return to town via the minecart. The hotbar is empty; the warehouse shows the new geodes.
4. **Death loss.** Mine a few more geodes. Die in the mine. Hotbar empties; warehouse is unchanged.
5. **Identify.** Talk to the identifier NPC. The popup shows a grid of raw stones from the warehouse; click one. The stone is replaced by a new mineral in the warehouse.
6. **Sell.** Talk to the buyer NPC. The popup shows a grid of minerals with `底价` labels. Click one; a toast confirms the sale. The wallet balance increases; the buyer's `budget` shrinks; the mineral leaves the warehouse.
7. **Budget exhaustion.** Sell repeatedly until the buyer's `budget` is exhausted. The grid greys out and clicks are no-ops.
8. **Task delivery.** Talk to the task clerk. Only the task whose requirements are currently in the warehouse is shown as clickable. Other active tasks are visible but greyed. Completed tasks are hidden. Press `Enter` on the deliverable task; a toast confirms the reward.

## Display System Manual Verification

The three-layer display model is verified by `scripts/mcp_warehouse_regression.py` automatically and should also be checked visually after a code change:

1. **1280x720 baseline.** Launch town. The town map fills the viewport horizontally and vertically. No black bars at the top or bottom of the map.
2. **Resize to 1920x1080.** Drag the window wider. The map stays centred and pixel-perfect; the player and NPCs stay anchored to their world positions.
3. **Resize to 900x600.** Drag to the minimum size. The map still fills the viewport; the warehouse panel (opened with `I`) is at least 360x280 and centred. The NPC popup is centred.
4. **Camera follow.** Walk the player to the four corners of the map. The camera follows with a smooth lerp and never lets the map edges go off-screen (no black bars).
5. **NPC labels.** NPC name labels stay glued to the sprite head at any window size; they do not drift off when the sprite is scaled.

## TODO

- TODO: Add GitHub Actions or another CI runner if this project needs enforced checks on pull requests.
- TODO: Add the seven per-concern regression tests spelled out in the [warehouse spec](specs/warehouse-system.md) (warehouse 48-slot cap, 999-item cap, hotbar reset on mine entry, hotbar dump on town return, warehouse intact on mine death, weight system gating, customer budget consumption and exhaustion, deliverable-task filtering). The current `_test_core_economy_loop` covers the end-to-end flow but not each rule in isolation.
- TODO: Add manual QA notes for editor-driven playtesting once the warehouse spec is fully exercised.
