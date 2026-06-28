# Architecture

## Engine And Entry Points

Anima Echo is a Godot 4.x project. `project.godot` sets `res://scenes/ui/title_menu.tscn` as the entry scene, which flows through `res://scenes/ui/intro.tscn` (opening narration) into `res://scenes/town/mining_town.tscn`.

Important scenes:

- `res://scenes/ui/title_menu.tscn`: title screen (Start/Continue/Setting/Exit).
- `res://scenes/ui/intro.tscn`: black-screen opening narration before town.
- `res://scenes/town/mining_town.tscn`: town gameplay scene.
- `res://scenes/mine/test_scene.tscn`: mine route scene.
- `res://scenes/mine/main_character_stats.tscn`: mine player scene.
- `res://scenes/mine/small_mine.tscn`: mineable node scene.
- `res://scenes/mine/cover.tscn`, `enemy.tscn`, and `gems/*.tscn`: reusable mine interaction pieces.

## Display System

The display system is a strict three-layer model. See [decisions/0004-display-system.md](../decisions/0004-display-system.md) for the rationale.

- **World** is fixed at 1152x648 in the town. Sprite positions, NPC positions, and player movement live here. The town map texture covers the full world.
- **GameCamera** (`scripts/camera_2d.gd`) follows the player with a smooth lerp, clamps inside the world bounds so the player never sees black edges, and picks an integer zoom that fits the world inside the viewport. The camera is attached to the scene root, not to the player.
- **UI** lives on its own CanvasLayer (layer 10) and uses anchor presets (`PRESET_TOP_WIDE` for the top bar, `PRESET_CENTER` for the NPC popup, `PRESET_TOP_LEFT` for the warehouse label). No absolute positions for UI.
- `project.godot` declares `window/stretch/mode="viewport"`, `aspect="keep"`, and `scale_mode="integer"`. Combined with `TEXTURE_FILTER_NEAREST` this keeps pixel art sharp at 1x, 2x, 3x, ... scaling.

## Autoloads

- `GameRuntime`: creates and owns the live catalog, event bus, **hotbar** (12-slot in-mine backpack), **warehouse** (48-slot at-home storage, soft 999-item cap), wallet, RNG, transaction service, identification service, negotiation service, shop service, and task service. Also owns the `customer_remaining_budget` map (initialized from each catalog customer's `budget` field, decremented on every successful sell) and the mine-run lifecycle methods (`begin_mine_run`, `end_mine_run`, `on_player_killed_in_mine`). See [decisions/0003](../decisions/0003-warehouse-system.md).
- `NoiseSystem`: shared noise event system used by movement, mining, and enemy detection.
- `OxygenSystem`: carry-on oxygen tank consumed in mine scenes. Consumption rate is base_rate × state_multiplier × weight_multiplier. Depletion triggers HP drain; mine death clears inventory and returns to town.
- `WeightSystem`: tiered encumbrance system (Light/Heavy/Overload) that updates only while the current scene is the mine (`testScene`). In town the bar is dormant; the warehouse does not contribute to weight.
- `ItemDatabase`: compatibility item icon, stack limit, display-name, description, and stack-key helper for the hotbar/inventory UI. Stack limits and descriptions are read from `GameRuntime.catalog` (not held locally).
- `StabilitySystem`: town stability 0–100. Selling star crystal → -15, gifting → +15, gifting normal → +2. Daily decay 3. Affects enemy spawn/detection range and town visual tint.
- `DayNightCycle`: day counter + time period (上午/下午/傍晚). Mine→town return advances time: 上午→下午→傍晚. 2 mine entries per day. 傍晚 closes mine. Sleep→next morning resets entries and refreshes daily tasks.
- `MCPScreenshot`, `MCPInputService`, `MCPGameInspector`: Godot MCP helper autoloads from `addons/godot_mcp`.

## Godot MCP Tooling Boundary

`addons/godot_mcp` is editor/runtime tooling, not gameplay logic. Game systems must not depend on MCP-only services to run. The addon is used by development agents to inspect the live editor, adjust scene properties, run the game, simulate input, capture screenshots, and collect acceptance evidence.

MCP should be the first choice for Godot-owned state because it talks through the editor and avoids broad text rewrites:

- Project settings and input map changes should go through MCP tools such as `set_project_setting` or `set_input_action`.
- Scene visual changes should prefer `update_property`, `batch_set_property`, and `save_scene` over unrelated `.tscn` rewrites.
- Runtime validation should start with `play_scene` and end with `stop_scene`; runtime inspection or input tools are invalid before the scene is running.
- Screenshots saved through MCP are verification artifacts, not source assets, unless a task explicitly promotes them into `assets/` with inventory metadata.

If MCP is unavailable, use the Godot MCP Pro CLI bridge as a temporary fallback and document that fallback in the task report. The long-term maintenance policy for the addon is still undecided.

### Runtime Narrative Systems (RefCounted, owned by GameRuntime)

- **TaskService** (`scripts/economy/task_service.gd`): `event_count`/`event_sum`/`deliver_item` objectives, progress via `GameEventBus`. Auto-accepts `task_talk_to_townspeople` and `task_first_identification` on new game. Right-side task panel in town HUD. Tasks are classified by `flags` field: `["story"]` persists across days until completed; `["daily"]` is wiped each morning and 3 new ones are drawn from the daily pool. Story tasks form a 12-task progressive chain: completing one auto-accepts the next via the `unlocks` field.
- **NpcAffection** (`scripts/narrative/npc_affection.gd`): 0–100 per NPC, +1/+3/+5 by rarity, 1 gift/day/NPC.
- **MoralityTracker** (`scripts/core/morality_tracker.gd`): star crystals sold vs gifted.
- **EquipmentSystem** (`scripts/player/equipment_system.gd`): 4 slots, good/evil exclusive, basic upgrades. Data at `data/equipment/equipment.json`.

### Narrative Data

- `data/narrative/dialogues.json`: 4 NPCs × 4 stages, multiple dialogue variants per stage.
- `docs/specs/narrative_design.md`: **must-read** for all agents before editing gameplay/NPC/town files.

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

1. The game starts at the **title screen** (`res://scenes/ui/title_menu.tscn`).
2. Clicking **START** opens the **intro narration** (`res://scenes/ui/intro.tscn`): 14 lines of black-screen text, left-click to advance. The last line auto-transitions to town. A **TEST** button on the title screen skips intro and goes directly to town.
3. The town (`res://scenes/town/mining_town.tscn`) is the central hub. Players move freely, talk to NPCs (E key), check the task board, and access the warehouse (I key).
4. The blacksmith NPC (after 5+ shallow mine runs) sells deep mine tickets. Entering the mine calls `GameRuntime.begin_mine_run()` (clears hotbar) and opens `res://scenes/mine/test_scene.tscn`.
5. Mine interactions collect raw geodes into the hotbar.
6. `MinecartExit` calls `GameRuntime.end_mine_run()` (dumps hotbar into warehouse) and returns the player to town.
7. Town NPC actions (identifier, buyer, task clerk) read the warehouse directly. Task rewards land in the warehouse.

Because `GameRuntime` is an autoload, hotbar state, warehouse state, wallet balance, event history, task progress, identified items, and customer budgets all persist across town/mine scene changes during the current session. The hotbar is reset to empty when a mine run starts and when the player dies in the mine; the warehouse is never touched by mine-scoped events.

## Directory Boundaries

- `scripts/core`: runtime state, catalog, wallet, hotbar, warehouse, transaction boundary, event bus, weight system, oxygen system, and noise system.
- `scripts/economy`: identification, shop, negotiation, and task rules.
- `scripts/items`: item database, gem pickup behavior, and hotbar compatibility.
- `scripts/player`: mine player state, stats, movement, and death handling.
- `scripts/mine`: mineable nodes, covers, mine stats, and oxygen pump interactable.
- `scripts/town`: town scene logic, town player controller, town movement, NPC interaction, mine return route, and warehouse UI host.
- `scripts/narrative`: dialogue UI, NPC affection, morality tracker.
- `scripts/enemies`: enemy AI.
- `scripts/ui`: title menu, intro narration, health bar, hotbar, warehouse UI, NPC warehouse popups, dialogue UI, weight bar, oxygen bar, QTE circle, and progress UI.
- `assets/mine`, `assets/town`, `assets/props`: current authored art assets.

## Input Map

`project.godot` defines these actions:
- `left` / `right` / `up` / `down`: WASD + arrow keys for movement.
- `interact`: E key (talk to NPCs, mine, use cover, etc.).
- `walk`: Shift key. Hold to **run** in both town and mine (the action name is legacy; behavior is now "run while held").
- `qte_action`: Space (QTE during mining/negotiation).
- `toggle_warehouse`: I key (open/close warehouse UI in town).
- `ui_cancel`: Esc (close popups, exit dialogue).

**Movement convention** (both scenes): default = WALK (0.5× speed in mine, 145 in town). Hold Shift = RUN (full speed in mine, 290 in town). Oxygen drain rate: walk = 1.0×, run = 2.0×. Noise: walk = low, run = high.

## Known Architecture TODOs

- [x] **Oxygen System**: Added `OxygenSystem` autoload, `OxygenBar` UI, and `OxygenPump` interactable. See [specs/oxygen_system.md](specs/oxygen_system.md).
- TODO: Document the intended save/load or persistence model. Current runtime state is session-local. The warehouse makes this question more urgent — cross-process persistence is the natural next step after the warehouse ships.
- TODO: Decide whether `addons/godot_mcp` is vendor-managed, manually maintained, or periodically refreshed. Until then, treat it as tooling-only and verify it with the MCP health check in [testing.md](testing.md).
- TODO: Clarify the long-term product/gameplay direction before adding large new systems.
- ~~TODO: Verify whether `CustomerShopService.list_customers()` should return customers instead of tasks before any feature relies on it.~~ **Fixed** by PR "[codex/fix-doc-scene-drift]" — see [decisions/0001](../decisions/0001-fix-doc-scene-drift.md).
- TODO: Document asset generation/source metadata if these assets will be regenerated or replaced.
- TODO: Add an `Enemy` (and `Enemy3`) instance under `EnemyCollection` in `scenes/mine/test_scene.tscn` so `_test_mine_scene_structure` passes again. Pre-existing on `origin/main`, tracked here so it does not get lost.
