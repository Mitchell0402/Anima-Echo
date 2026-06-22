# mine-platform-v2 Project Context

> Purpose: current AI-readable context for the fused Godot project.
> Engine: Godot 4.6.3.
> Project root: `C:\Users\Mitchell\Documents\mine-platform-v2`.
> Main scene: `res://scenes/town/mining_town.tscn`.
> Mine scene: `res://scenes/mine/test_scene.tscn`.
> 主场景：`res://scenes/town/mining_town.tscn`
> 矿洞场景：`res://scenes/mine/test_scene.tscn`

## Current Shape

`mine-platform-v2` is the active fused project. It uses the GJ project layout as the presentation base and adds p-1 town presentation plus one unified runtime core.

- GJ mine scenes now live under `res://scenes/mine`, scripts under `res://scripts`, and GJ art now lives under `res://assets/gj`.
- Fused town entry is `res://scenes/town/mining_town.tscn`.
- Fused town logic is `res://scripts/town/fused_mining_town_scene.gd`.
- Minecart return logic is `res://scripts/town/mine_exit.gd`.
- Unified runtime core is under `res://scripts/core` and `res://scripts/economy`.
- Runtime catalog data is `res://data/game/catalog.json`.
- Current generated prop asset: `res://assets/props/minecart_return_to_town.png`.

## Autoloads

- `GameRuntime`: `res://scripts/core/game_runtime.gd`
- `NoiseSystem`: `res://scripts/core/noise_system.gd`
- `ItemDatabase`: `res://scripts/items/item_database.gd`
- Godot MCP editor helpers remain enabled under `res://addons/godot_mcp`.

## Scene Flow

1. Game starts in the fused town.
2. The miner NPC opens the mine route and loads `res://scenes/mine/test_scene.tscn`.
3. The mine contains `MinecartExit`, a generated minecart prop near the starting area.
4. Press interact / accept near `MinecartExit` to return to `res://scenes/town/mining_town.tscn`.
5. `GameRuntime` is an autoload, so wallet, inventory, task progress, and identified items persist across scene changes.

## Player And Movement

- Town and mine use the GJ player visual identity.
- Town player uses `res://assets/gj/characters/player/main_char_sprite_frames.tres` through `AnimatedSprite2D`.
- Town NPCs use p-1 NPC sprite sheets and share `TOWN_CHARACTER_SCALE` with the town player.
- Movement is cardinal-only in both town and mine. Diagonal input is resolved to one axis before movement is applied.
- Town walkable config currently has `default_walkable = true` and empty `blocked_polygons`.
- Mine player has `collision_mask = 0` so temporary map blockers do not stop movement.
- Mine player collision shape stays enabled because GJ mining and cover interaction depend on Area2D `body_entered` detection.

## Economy Core Contract

- `GameRuntime` owns the single live inventory, wallet, catalog, transaction service, identification service, shop service, negotiation service, and task service.
- Real inventory and currency mutations must go through `GameTransactionService`.
- `scripts/items/inventory_manager.gd` remains as the GJ hotbar / compatibility view and syncs from `GameRuntime.inventory`.
- GJ gem pickup maps gem levels to runtime catalog items:
  - L1 -> `raw_common_geode`
  - L2 -> `raw_fine_geode`
  - L3 -> `raw_rare_geode`
- Town identification, selling, and task claim actions call `GameRuntime` services directly.

## Mine Systems

- `res://scenes/mine/test_scene.tscn` preserves the GJ TileMaps, enemies, covers, mine nodes, patrol paths, gems, and hotbar structure.
- `scripts/player/move_controller.gd` handles mine player movement, animation, and noise.
- `scripts/mine/mine_interaction.gd` starts mining when the player is inside a mine Area2D and presses interact.
- `scripts/mine/cover.gd` hides/unhides the player when inside cover Area2D and pressing interact.
- `scripts/items/gem_controller.gd` supports both Area2D pickup and distance pickup so gem collection still works while map collision is relaxed.
- Enemy attack and detection remain distance/state based and do not require player map collision.

## Town Systems

- Town map asset: `res://assets/town/map/town_map.png`.
- NPC sprite assets:
  - `npc_miner_sprites.png`
  - `npc_buyer_sprites.png`
  - `npc_identifier_sprites.png`
  - `npc_task_clerk_sprites.png`
- Active town helper scripts kept from p-1:
  - `town_walkable_map.gd`
  - `town_npc_interactor.gd`
  - `town_player_controller.gd`
- Removed legacy p-1 demo services, demo UI scripts, old data tables, unused town player sprites, unused workshop/portrait/item atlas assets, and unused walkable mask.

## Verification

Run the current regression suite:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\Mitchell\Documents\mine-platform-v2' -s res://tests/fusion/run_all.gd
```

Expected result:

```text
RESULT: PASS 456 assertions
```

Smoke start town:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\Mitchell\Documents\mine-platform-v2' --quit-after 3
```

Smoke start mine:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\Mitchell\Documents\mine-platform-v2' res://scenes/mine/test_scene.tscn --quit-after 3
```

## Cleanup Notes

- `data/mining_economy` was removed. `data/game/catalog.json` is the active catalog.
- Old p-1 demo scripts and lower-level services were removed. Do not reintroduce a second transaction core.
- Add future task/item art under project assets and use ImageGen or authored sprites, not placeholder color blocks.
