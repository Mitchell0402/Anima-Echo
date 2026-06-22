# mine-platform-v2 Implementation Summary

## Current Project

- Project path: `C:\Users\Mitchell\Documents\mine-platform-v2`
- Main scene: `res://scenes/town/mining_town.tscn`
- GJ mine scene: `res://scenes/mine/test_scene.tscn`
- Runtime autoload: `GameRuntime` -> `res://scripts/core/game_runtime.gd`
- AI context doc: `res://docs/PROJECT_CONTEXT.md`

## What Was Integrated

- GJ remains the presentation base. Mine scenes have been normalized to `res://scenes/mine`, scripts to `res://scripts`, and GJ art now lives under `res://assets/gj`.
- p-1 town presentation assets now live under `res://assets/town/map` and `res://assets/town/npcs`, keeping the town map and NPC sprites that are still used by the fused town.
- The unified runtime core was installed under `res://scripts/core` and `res://scripts/economy`, with catalog data in `res://data/game/catalog.json`.
- The fused town scene uses p-1 town art and NPC positions, then routes all inventory, wallet, identification, sale, and task operations through `GameRuntime`.
- The fused town player now uses the GJ mine character `SpriteFrames` resource and movement animations instead of the original p-1 town player sprites.
- Town character visuals share `TOWN_CHARACTER_SCALE` in `res://scripts/town/fused_mining_town_scene.gd`, so the GJ player and town NPCs stay in the same visual size family.
- Player movement is cardinal-only in both town and mine. Diagonal input is resolved to one axis before movement is applied.
- Temporary movement blockers are opened up for both maps: town walkable blocked polygons are empty, and the mine player has `collision_mask = 0`. The player interaction shape stays enabled because GJ mining and cover interactions depend on Area2D detection.
- The GJ mine keeps its original play structure at `res://scenes/mine/test_scene.tscn`. Gem pickup and drop penalties now use the unified transaction boundary instead of owning real economy data locally.
- The mine return route is now a generated minecart prop at `res://assets/props/minecart_return_to_town.png`.
- The GJ hotbar/inventory script now acts as a compatibility view backed by `GameRuntime.inventory`.
- Legacy p-1 demo data, unused demo UI scripts, old town player sprites, unused workshop/portrait/item atlas assets, and unused walkable mask were removed.

## Scene Flow

- Start game in the fused town.
- Talk to the miner NPC and choose `进入矿洞` to load `res://scenes/mine/test_scene.tscn`.
- In the mine, use the `MinecartExit` prop near the starting area and press interact / accept to return to `res://scenes/town/mining_town.tscn`.
- `GameRuntime` is an autoload, so inventory, wallet, task progress, and identified/unidentified item state survive scene changes.

## Architecture Contract

- Real inventory mutations must go through `GameTransactionService`.
- Real wallet mutations must go through `GameTransactionService` and `GameWallet`.
- `scripts/items/inventory_manager.gd` is allowed only as GJ UI/compatibility view.
- Removed legacy p-1 lower-level services from `scripts/town` so there is no second transaction core.
- Preserved p-1 town presentation helpers under `scripts/town`.
- Removed the old p-1 town player sprite assets so the project only has one player visual identity.
- Removed unused p-1 demo helpers (`town_hud`, `town_panel_controller`, `town_dialogue_menu`, `negotiation_bar`) and old `data/mining_economy`; the active catalog is `res://data/game/catalog.json`.

## Verification

Run the fusion regression suite:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\Mitchell\Documents\mine-platform-v2' -s res://tests/fusion/run_all.gd
```

Expected result:

```text
RESULT: PASS 456 assertions
```

Smoke start the town:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\Mitchell\Documents\mine-platform-v2' --quit-after 3
```

Smoke start the GJ mine:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\Mitchell\Documents\mine-platform-v2' res://scenes/mine/test_scene.tscn --quit-after 3
```

## Manual Acceptance Focus

- Confirm the GJ mine still looks and feels like the original: TileMaps, covers, enemies, patrols, mines, gems, pickups, and hotbar.
- Confirm the fused town is visually close enough to p-1: real town map, real NPC sprites, player sprite, NPC interaction popups, and economy actions.
- Confirm the full loop: mine gems, return to town, identify, sell, and claim task reward.
- Confirm repeated town <-> mine transitions do not reset wallet, inventory, or task state.
