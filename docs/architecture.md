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

- `GameRuntime`: creates and owns the live catalog, event bus, inventory, wallet, RNG, transaction service, identification service, negotiation service, shop service, and task service.
- `NoiseSystem`: shared noise event system used by movement, mining, and enemy detection.
- `ItemDatabase`: compatibility item icon, stack limit, display-name, and stack-key helper for the hotbar/inventory UI.
- `MCPScreenshot`, `MCPInputService`, `MCPGameInspector`: Godot MCP helper autoloads from `addons/godot_mcp`.

## Runtime Data Flow

`data/game/catalog.json` is the current runtime data source for items, loot tables, identification tables, customers, and tasks.

`GameRuntime` initializes:

1. `GameCatalog` from `data/game/catalog.json`.
2. `GameEventBus`.
3. `GameInventory` and `GameWallet`.
4. `GameTransactionService`.
5. Economy services for identification, negotiation, shops, and tasks.

Inventory and currency changes should go through `GameTransactionService`. `scripts/items/inventory_manager.gd` remains as a hotbar compatibility view that syncs from `GameRuntime.inventory`.

## Scene Flow

1. The game starts in the town.
2. The miner NPC opens `res://scenes/mine/test_scene.tscn`.
3. Mine interactions collect raw geodes into the runtime inventory.
4. `MinecartExit` returns the player to the town.
5. Town NPC actions identify raw stones, sell minerals, and claim task rewards through `GameRuntime` services.

Because `GameRuntime` is an autoload, wallet, inventory, event history, task progress, and identified items persist across town/mine scene changes during the current session.

## Directory Boundaries

- `scripts/core`: runtime state, catalog, wallet, inventory, transaction boundary, event bus, and noise system.
- `scripts/economy`: identification, shop, negotiation, and task rules.
- `scripts/items`: item database, gem pickup behavior, and hotbar inventory compatibility.
- `scripts/player`: mine player state, stats, and movement.
- `scripts/mine`: mineable nodes, covers, and mine stats.
- `scripts/town`: generated town scene logic, town movement, NPC interaction, and mine return route.
- `scripts/enemies`: enemy AI.
- `scripts/ui`: health bar, hotbar, and progress UI.
- `assets/mine`, `assets/town`, `assets/props`: current authored art assets.

## Known Architecture TODOs

- TODO: Document the intended save/load or persistence model. Current runtime state is session-local.
- TODO: Decide whether `addons/godot_mcp` is vendor-managed, manually maintained, or periodically refreshed.
- TODO: Clarify the long-term product/gameplay direction before adding large new systems.
- ~~TODO: Verify whether `CustomerShopService.list_customers()` should return customers instead of tasks before any feature relies on it.~~ **Fixed** by PR "[codex/fix-doc-scene-drift]" — see [decisions/0001](../decisions/0001-fix-doc-scene-drift.md).
- TODO: Document asset generation/source metadata if these assets will be regenerated or replaced.
- TODO: Add an `Enemy` (and `Enemy3`) instance under `EnemyCollection` in `scenes/mine/test_scene.tscn` so `_test_mine_scene_structure` passes again. Pre-existing on `main`, tracked here so it does not get lost.
