# Anima Echo Project Context

> Purpose: current AI-readable context for the clean Godot development base.
> Engine: Godot 4.6.3.
> 标题界面：`res://scenes/ui/title_menu.tscn`
> Main scene (town): `res://scenes/town/mining_town.tscn`.
> Mine scene: `res://scenes/mine/test_scene.tscn`.
> Test entry: `res://tests/project/run_all.gd`.
> 标题界面：`res://scenes/ui/title_menu.tscn`
> 主场景（城镇）：`res://scenes/town/mining_town.tscn`
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

- `GameRuntime` owns the live hotbar (12 slots, in-mine backpack), the warehouse (48 slots, 999-item soft cap, in-town storage), the wallet, the catalog, the customer remaining-budget map, the transaction service, the identification service, the shop service, the negotiation service, and the task service. The hotbar and warehouse are two instances of the same `GameInventory` RefCounted.
- Real hotbar, warehouse, wallet, and customer budget mutations must go through `GameTransactionService.apply()`. The service snapshots all four containers and rolls them back together on any failure.
- `scripts/items/inventory_manager.gd` is a thin view that mirrors the 12-slot `GameRuntime.hotbar` for the hotbar UI. `is_full()` and stack-size lookups proxy through to the unified runtime so the local view cannot disagree with the source of truth. See [decisions/0002](../decisions/0002-inventory-consistency.md) and [decisions/0003](../decisions/0003-warehouse-system.md).
- `scripts/items/item_database.gd` reads stack sizes and item descriptions from `GameRuntime.catalog` instead of holding parallel constants.
- Gem pickup maps mine gem levels to runtime catalog items:
  - L1 -> `raw_common_geode`
  - L2 -> `raw_fine_geode`
  - L3 -> `raw_rare_geode`
- In town, identification, selling, and task delivery all read from the warehouse. The hotbar is empty while the player is in town by design. NPC popups present the warehouse as a grid picker. The task clerk only shows tasks that are currently deliverable; the rest are visible but greyed.

## Warehouse System

- The 48-slot warehouse is `GameRuntime.warehouse` (`GameInventory` instance). Item cap is 999, applied through `GameInventory.add_item` (returns `inventory_soft_cap` error on overflow).
- The hotbar is `GameRuntime.hotbar` (12-slot `GameInventory` instance). No item cap; only the 12-slot capacity applies.
- On mine entry (`begin_mine_run`): hotbar is cleared.
- On mine exit (`end_mine_run`): every hotbar stack moves to the warehouse through a `move_stack_from_hotbar_to_warehouse` transaction. If the warehouse is full, the untransferred items remain in the hotbar and the town scene prints a warning.
- On mine death (`on_player_killed_in_mine`): hotbar is cleared; warehouse is untouched.
- `CustomerShopService.sell_to_customer` decrements the customer's `customer_remaining_budget` inside the sell transaction. The budget is initialized at startup from each catalog customer's `budget` field and is not regenerated during a session.
- The standalone warehouse UI is opened by the `I` key (or closed by `I` / `Esc`) from town. It is a no-op in the mine. While open, the player's input is frozen (movement and NPC interactions are dropped). See [decisions/0003](../decisions/0003-warehouse-system.md) for the design rationale and [specs/warehouse-system](../specs/warehouse-system.md) for the full behavior contract.

## Mine Systems

- `res://scenes/mine/test_scene.tscn` contains TileMaps, enemies, covers, mine nodes, patrol paths, gems, and hotbar structure.
- `scripts/player/move_controller.gd` handles mine player movement, animation, and noise.
- `scripts/mine/mine_interaction.gd` starts mining when the player is inside a mine Area2D and presses interact.
- `scripts/mine/cover.gd` hides/unhides the player when inside cover Area2D and pressing interact.
- `scripts/items/gem_controller.gd` supports both Area2D pickup and distance pickup so gem collection still works while map collision is relaxed.
- Enemy attack and detection remain distance/state based and do not require player map collision.

## Display System

The game uses a strict three-layer model. See [decisions/0004-display-system.md](../decisions/0004-display-system.md) for the rationale.

- **World**: fixed at 1152x648 in the town. Sprite positions, NPC positions, walkable bounds, and player movement all live here.
- **Camera**: `scripts/camera_2d.gd` (`GameCamera`) follows the player with smooth lerp, clamps inside the world bounds, and exposes `fit_world_to_viewport_integer()` for pixel-perfect scaling. The camera is attached to the town scene root, not to the player.
- **UI**: lives on its own `CanvasLayer` (layer 10) and uses anchor presets (`PRESET_TOP_WIDE` for the top bar, `PRESET_CENTER` for the NPC popup, `PRESET_TOP_LEFT` for the warehouse label). No absolute positions for UI elements.
- `project.godot` declares `window/stretch/mode="viewport"`, `aspect="keep"`, and `scale_mode="integer"` so the world renders pixel-perfectly at any window size and aspect ratio.
- The mine scene currently still uses the old hard-coded TileMap size and a Camera2D attached to the player; bring it into this model in a follow-up.

## Town Systems

- Town map asset: `res://assets/town/map/town_map.png`.
- NPC sprite assets (under `res://assets/props/`):
  - `npc_miner_alpha.png`
  - `npc_buyer_sprites_alpha.png`
  - `npc_identifier_sprites_alpha.png`
  - `npc_task_clerk_sprites_alpha.png`
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
