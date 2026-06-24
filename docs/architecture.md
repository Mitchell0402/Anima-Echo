# Architecture

## Engine And Entry Points

Anima Echo is a Godot 4.x project. `project.godot` names the project `Anima Echo`, sets `res://scenes/town/mining_town.tscn` as the main scene, and enables Jolt Physics.

Important scenes:

- `res://scenes/town/mining_town.tscn`: current town entry scene.
- `res://scenes/mine/test_scene.tscn`: current mine route scene.
- `res://scenes/mine/main_character_stats.tscn`: mine player scene.
- `res://scenes/mine/small_mine.tscn`: mineable node scene.
- `res://scenes/mine/cover.tscn`, `enemy.tscn`, and `gems/*.tscn`: reusable mine interaction pieces.

## Autoloads

- `GameRuntime`: creates and owns the live catalog, event bus, **hotbar** (12-slot in-mine backpack), **warehouse** (48-slot at-home storage, soft 999-item cap), wallet, RNG, transaction service, identification service, negotiation service, shop service, and task service. See [decisions/0003](../decisions/0003-warehouse-system.md).
- `NoiseSystem`: shared noise event system used by movement, mining, and enemy detection.
- `ItemDatabase`: compatibility item icon, stack limit, display-name, description, and stack-key helper for the hotbar/inventory UI.
- `MCPScreenshot`, `MCPInputService`, `MCPGameInspector`: Godot MCP helper autoloads from `addons/godot_mcp`.

## Runtime Data Flow

- `data/game/catalog.json` is the current runtime data source for items, loot tables, identification tables, customers, and tasks. Every item carries a `description` (string) used by warehouse tooltips; new items must include it.

`GameRuntime` initializes:

1. `GameCatalog` from `data/game/catalog.json`.
2. `GameEventBus`.
3. `GameHotbar` (12 slots, in-mine backpack) and `GameWallet`.
4. `GameWarehouse` (48 slots, 999-item soft cap, in-town storage).
5. `GameTransactionService`.
6. Economy services for identification, negotiation, shops, and tasks.
7. `customer_remaining_budget` map, initialized from each catalog customer's `budget` field.

Inventory and currency changes should go through `GameTransactionService`. The hotbar (`scripts/items/inventory_manager.gd`) is a thin view that mirrors `GameRuntime.hotbar` for the in-mine UI; the warehouse has no hotbar-style mirror and is read directly from `GameRuntime.warehouse` by the warehouse UI and by NPC popups. See [decisions/0003](../decisions/0003-warehouse-system.md).

## Scene Flow

1. The game starts in the town.
2. The miner NPC opens `res://scenes/mine/test_scene.tscn`.
3. Mine interactions collect raw geodes into the runtime inventory.
4. `MinecartExit` returns the player to the town.
5. Town NPC actions identify raw stones, sell minerals, and claim task rewards through `GameRuntime` services.

Because `GameRuntime` is an autoload, wallet, inventory, event history, task progress, and identified items persist across town/mine scene changes during the current session.

## Directory Boundaries

- `scripts/core`: runtime state, catalog, wallet, hotbar, warehouse, transaction boundary, event bus, and noise system.
- `scripts/economy`: identification, shop, negotiation, and task rules.
- `scripts/items`: item database, gem pickup behavior, and hotbar compatibility.
- `scripts/player`: mine player state, stats, and movement.
- `scripts/mine`: mineable nodes, covers, and mine stats.
- `scripts/town`: generated town scene logic, town movement, NPC interaction, and mine return route.
- `scripts/enemies`: enemy AI.
- `scripts/ui`: health bar, hotbar, warehouse UI, NPC warehouse popups, and progress UI.
- `assets/mine`, `assets/town`, `assets/props`: current authored art assets.

## Known Architecture TODOs

- TODO: Document the intended save/load or persistence model. Current runtime state is session-local. The warehouse spec makes the question more urgent: warehouse is a perfect candidate for save/load, but cross-process persistence is explicitly out of scope for the first cut. Re-evaluate after the warehouse ships.
- TODO: Decide whether `addons/godot_mcp` is vendor-managed, manually maintained, or periodically refreshed.
- TODO: Clarify the long-term product/gameplay direction before adding large new systems.
- ~~TODO: Verify whether `CustomerShopService.list_customers()` should return customers instead of tasks before any feature relies on it.~~ **Fixed** by PR "[codex/fix-doc-scene-drift]" — see [decisions/0001](../decisions/0001-fix-doc-scene-drift.md).
- TODO: Document asset generation/source metadata if these assets will be regenerated or replaced.
- TODO: Add an `Enemy` (and `Enemy3`) instance under `EnemyCollection` in `scenes/mine/test_scene.tscn` so `_test_mine_scene_structure` passes again. Pre-existing on `origin/main`, tracked here so it does not get lost.
- TODO: Make `ItemDatabase` autoload order explicit: either move it after `GameRuntime` in `project.godot`, or eliminate the runtime dependency by injecting the catalog. See [decisions/0002](../decisions/0002-inventory-consistency.md).
