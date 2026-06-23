# Anima Echo Project Context

> Purpose: current AI-readable context for the clean Godot development base.
> Engine: Godot 4.6.3.
> Main scene: `res://scenes/town/mining_town.tscn`.
> Mine scene: `res://scenes/mine/test_scene.tscn`.
> Test entry: `res://tests/project/run_all.gd`.
> 主场景：`res://scenes/town/mining_town.tscn`
> 矿洞场景：`res://scenes/mine/test_scene.tscn`
> 测试入口：`res://tests/project/run_all.gd`

## Current Shape

`Anima Echo` is a single-root Godot project with a playable town-to-mine loop and a shared runtime economy core.

- Town entry: `res://scenes/town/mining_town.tscn`.
- Town logic: `res://scripts/town/mining_town_scene.gd`.
- Mine scene: `res://scenes/mine/test_scene.tscn`.
- Mine return logic: `res://scripts/town/mine_exit.gd`.
- Mine, character, enemy, and environment art: `res://assets/mine`.
- Town map and NPC art: `res://assets/town`.
- Shared runtime core: `res://scripts/core` and `res://scripts/economy`.
- Runtime catalog data: `res://data/game/catalog.json`.
- Reusable props: `res://assets/props`.

## Autoloads

- `GameRuntime`: `res://scripts/core/game_runtime.gd`
- `NoiseSystem`: `res://scripts/core/noise_system.gd`
- `ItemDatabase`: `res://scripts/items/item_database.gd`
- Godot MCP editor helpers remain enabled under `res://addons/godot_mcp`.

## Scene Flow

1. Game starts in town.
2. The miner NPC opens the mine route and loads `res://scenes/mine/test_scene.tscn`.
3. The mine contains `MinecartExit`, a minecart prop near the starting area.
4. Press interact / accept near `MinecartExit` to return to `res://scenes/town/mining_town.tscn`.
5. `GameRuntime` is an autoload, so wallet, inventory, task progress, and identified items persist across scene changes.

## Player And Movement

- Town and mine share the mine character visual identity.
- Town player uses `res://assets/mine/characters/player/main_char_sprite_frames.tres` through `AnimatedSprite2D`.
- Town NPCs use `res://assets/town/npcs`.
- Movement is cardinal-only in both town and mine. Diagonal input is resolved to one axis before movement is applied.
- Town walkable config currently has `default_walkable = true` and empty `blocked_polygons`.
- Mine player has `collision_mask = 0` so temporary map blockers do not stop movement.
- Mine player collision shape stays enabled because mining and cover interaction depend on Area2D `body_entered` detection.

## Economy Core Contract

- `GameRuntime` owns the single live inventory, wallet, catalog, transaction service, identification service, shop service, negotiation service, and task service.
- Real inventory and currency mutations must go through `GameTransactionService`.
- `scripts/items/inventory_manager.gd` remains as the hotbar compatibility view and syncs from `GameRuntime.inventory`.
- Gem pickup maps mine gem levels to runtime catalog items:
  - L1 -> `raw_common_geode`
  - L2 -> `raw_fine_geode`
  - L3 -> `raw_rare_geode`
- Town identification, selling, and task claim actions call `GameRuntime` services directly.

## Mine Systems

- `res://scenes/mine/test_scene.tscn` contains TileMaps, enemies, covers, mine nodes, patrol paths, gems, and hotbar structure.
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
- Active town helper scripts:
  - `town_walkable_map.gd`
  - `town_npc_interactor.gd`
  - `town_player_controller.gd`

## Verification

After a fresh checkout or asset move, rebuild Godot's local import cache first:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --editor --quit --path .
```

Run the current regression suite:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . -s res://tests/project/run_all.gd
```

Smoke start town:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --quit-after 3
```

Smoke start mine:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . res://scenes/mine/test_scene.tscn --quit-after 3
```

## Development Notes

- `data/game/catalog.json` is the active item and economy catalog.
- Do not introduce a second inventory, wallet, or transaction core.
- Add future task/item art under project assets and use authored sprites or generated assets, not temporary color blocks.
