# Architecture

## Engine And Entry Points

Anima Echo is a Godot 4.x project. `project.godot` names the project `Mine Platform V2`, sets `res://scenes/town/mining_town.tscn` as the main scene, and enables Jolt Physics.

Important scenes:

- `res://scenes/town/mining_town.tscn`: current town entry scene.
- `res://scenes/mine/test_scene.tscn`: current mine route scene.
- `res://scenes/mine/main_character_stats.tscn`: mine player scene.
- `res://scenes/mine/small_mine.tscn`: mineable node scene.
- `res://scenes/mine/cover.tscn`, `enemy.tscn`, and `gems/*.tscn`: reusable mine interaction pieces.

## Display System

The display system is a strict three-layer model. See [decisions/0004-display-system.md](../decisions/0004-display-system.md) for the rationale.

- **World** is fixed at 1152x648 in the town. Sprite positions, NPC positions, and player movement live here. The town map texture covers the full world.
- **GameCamera** (`scripts/camera_2d.gd`) follows the player with smooth lerp, clamps inside the world bounds, and picks an integer zoom that fits the world inside the viewport. The camera is attached to the scene root, not to the player.
- **UI** lives on its own CanvasLayer (layer 10) and uses anchor presets (`PRESET_TOP_WIDE` for the top bar, `PRESET_CENTER` for the NPC popup, `PRESET_TOP_LEFT` for the warehouse label). No absolute positions for UI.
- `project.godot` declares `window/stretch/mode="viewport"`, `aspect="keep"`, and `scale_mode="integer"` so pixel art stays sharp at any window size.

## Autoloads

- `GameRuntime`: creates and owns the live catalog, event bus, **hotbar** (12-slot in-mine backpack), **warehouse** (48-slot at-home storage, soft 999-item cap), wallet, RNG, transaction service, identification service, negotiation service, shop service, and task service. Also owns the `customer_remaining_budget` map (initialized from each catalog customer's `budget` field, decremented on every successful sell) and the mine-run lifecycle methods (`begin_mine_run`, `end_mine_run`, `on_player_killed_in_mine`). See [decisions/0003](../decisions/0003-warehouse-system.md).
- `NoiseSystem`: shared noise event system used by movement, mining, and enemy detection.
- `OxygenSystem`: carry-on oxygen tank consumed in mine scenes. Consumption rate is base_rate × state_multiplier × weight_multiplier. Depletion triggers HP drain; mine death clears inventory and returns to town.
- `WeightSystem`: tiered encumbrance system (Light/Heavy/Overload) that updates only while the current scene is the mine (`testScene`). In town the bar is dormant; the warehouse does not contribute to weight.
- `ItemDatabase`: compatibility item icon, stack limit, display-name, description, and stack-key helper for the hotbar/inventory UI. Stack limits and descriptions are read from `GameRuntime.catalog` (not held locally).
- `MCPScreenshot`, `MCPInputService`, `MCPGameInspector`: Godot MCP helper autoloads from `addons/godot_mcp`.

## Runtime Data Flow

`data/game/catalog.json` is the current runtime data source for items, loot tables, identification tables, customers, and tasks. Every item carries a `description` (string) used by warehouse tooltips; new items must include it.

`GameRuntime` initializes:

1. `GameCatalog` from `data/game/catalog.json`.
2. `GameEventBus`.
3. `GameHotbar` (12 slots, in-mine backpack) and `GameWallet`.
4. `GameWarehouse` (48 slots, 999-item soft cap, in-town storage). Both hotbar and warehouse are instances of the same `GameInventory` RefCounted with different capacity and `max_items` parameters.
5. `GameTransactionService` (singleton mutation boundary — every change to either collection or the wallet flows through `apply`).
6. Economy services for identification, negotiation, shops, and tasks.
7. `customer_remaining_budget` map, initialized from each catalog customer's `budget` field.

All inventory, warehouse, wallet, and budget changes should go through `GameTransactionService.apply()`. The service snapshots all four containers at the start of each transaction and rolls them back together on failure. The hotbar (`scripts/items/inventory_manager.gd`) is a thin view that mirrors `GameRuntime.hotbar` for the in-mine UI; the warehouse has no hotbar-style mirror and is read directly from `GameRuntime.warehouse` by the warehouse UI and by NPC popups.

## Scene Flow

1. The game starts in the town.
2. The miner NPC calls `GameRuntime.begin_mine_run()` (which clears the hotbar) and opens `res://scenes/mine/test_scene.tscn`.
3. Mine interactions collect raw geodes into the hotbar.
4. `MinecartExit` calls `GameRuntime.end_mine_run()` (which dumps the hotbar into the warehouse) and returns the player to town.
5. Town NPC actions (identifier, buyer, task clerk) read the warehouse directly through a symmetric warehouse picker. Task rewards land in the warehouse.

Because `GameRuntime` is an autoload, hotbar state, warehouse state, wallet balance, event history, task progress, identified items, and customer budgets all persist across town/mine scene changes during the current session. The hotbar is reset to empty when a mine run starts and when the player dies in the mine; the warehouse is never touched by mine-scoped events.

## Directory Boundaries

- `scripts/core`: runtime state, catalog, wallet, hotbar, warehouse, transaction boundary, event bus, weight system, oxygen system, and noise system.
- `scripts/economy`: identification, shop, negotiation, and task rules.
- `scripts/items`: item database, gem pickup behavior, and hotbar compatibility.
- `scripts/player`: mine player state, stats, movement, and death handling.
- `scripts/mine`: mineable nodes, covers, mine stats, and oxygen pump interactable.
- `scripts/town`: generated town scene logic, town movement, NPC interaction, mine return route, and warehouse UI host.
- `scripts/enemies`: enemy AI.
- `scripts/ui`: health bar, hotbar, warehouse UI, NPC warehouse popups, weight bar, oxygen bar, and progress UI.
- `assets/mine`, `assets/town`, `assets/props`: current authored art assets.

## Input Map

`project.godot` defines a `toggle_warehouse` action bound to the `I` key. The warehouse UI listens to this action; `Esc` is the secondary close key. The action is a no-op in the mine scene (the player is told "no warehouse in the mine" by getting no response).

## Known Architecture TODOs

- [x] **Oxygen System**: Added `OxygenSystem` autoload, `OxygenBar` UI, and `OxygenPump` interactable. See [specs/oxygen_system.md](specs/oxygen_system.md).
- TODO: Document the intended save/load or persistence model. Current runtime state is session-local. The warehouse makes this question more urgent — cross-process persistence is the natural next step after the warehouse ships.
- TODO: Decide whether `addons/godot_mcp` is vendor-managed, manually maintained, or periodically refreshed.
- TODO: Clarify the long-term product/gameplay direction before adding large new systems.
- ~~TODO: Verify whether `CustomerShopService.list_customers()` should return customers instead of tasks before any feature relies on it.~~ **Fixed** by PR "[codex/fix-doc-scene-drift]" — see [decisions/0001](../decisions/0001-fix-doc-scene-drift.md).
- TODO: Document asset generation/source metadata if these assets will be regenerated or replaced.
- TODO: Add an `Enemy` (and `Enemy3`) instance under `EnemyCollection` in `scenes/mine/test_scene.tscn` so `_test_mine_scene_structure` passes again. Pre-existing on `origin/main`, tracked here so it does not get lost.
