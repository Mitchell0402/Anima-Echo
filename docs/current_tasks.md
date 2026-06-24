# Current Tasks

Last updated: 2026-06-24

## Current Baseline

- The repository is a single-root Godot project for a 2D mining prototype.
- The current main scene is `res://scenes/town/mining_town.tscn` (uid `uid://dxjbgwnb1j7cw`).
- The current mine route is `res://scenes/mine/test_scene.tscn`.
- The current automated test entrypoint is `res://tests/project/run_all.gd`.
- The project has a normalized layout under `assets/`, `data/`, `docs/`, `scenes/`, `scripts/`, and `tests/`.
- The runtime economy core is already present under `scripts/core` and `scripts/economy`.
- **Weight System**: 3-tier encumbrance (Light/Heavy/Overload) based on raw geode weight, with speed and noise penalties. The system is gated to the mine scene; the warehouse does not contribute to weight. [Spec](specs/weight_system.md)
- **Oxygen System**: Carry-on oxygen tank consumed in mine scenes. 3.0× drain while mining, 2.0× while running, 0.5× while hidden. Weight multiplier 1.3/1.7 from WeightSystem. Depletion → HP drain → mine death → inventory clear + return to town. OxygenPump interactable placed in test scene. [Spec](specs/oxygen_system.md)
- **Doc/Scene/Service Drift**: Three silent inconsistencies (main scene, town scene script reference, `CustomerShopService.list_customers()`) are fixed and locked down with regression tests. [Decision](../decisions/0001-fix-doc-scene-drift.md)
- **Inventory Consistency**: `InventoryManager.is_full()` and `ItemDatabase.get_stack_limit` / `get_description` now proxy through to `GameRuntime.hotbar` / `catalog` instead of holding a local 8-slot fiction or a parallel constant table. [Decision](../decisions/0002-inventory-consistency.md)
- **Warehouse System**: The 18-slot single inventory is split into a 12-slot in-mine hotbar and a 48-slot, 999-item-soft-cap in-town warehouse. Hotbar resets on mine entry, dumps to warehouse on town return, and clears on mine death. Town NPC sell/identify/deliver actions read the warehouse directly through a symmetric warehouse popup. Customer `budget` is decremented on every sale. [Spec](specs/warehouse-system.md) / [Decision](../decisions/0003-warehouse-system.md). **Implementation: complete; 4 regression tests added in this PR; 7 more are follow-up.**
- **Display System**: The town uses a three-layer world/camera/UI model. World is fixed at 1152x648. GameCamera (`scripts/camera_2d.gd`) follows the player with smooth lerp, clamps inside the world bounds, and picks an integer zoom that fits the world inside the viewport. UI uses anchor presets on its own CanvasLayer. `project.godot` declares `window/stretch/mode="viewport"`, `aspect="keep"`, and `scale_mode="integer"` so pixel art stays sharp at any window size. [Decision](../decisions/0004-display-system.md). **Implementation: complete for town; mine scene still uses the old pattern (see follow-up).**

## Known Risks And TODOs

- TODO: Add a CI workflow if GitHub should enforce the Godot regression suite.
- TODO: Confirm how contributors should discover the Godot executable across machines.
- TODO: Decide the maintenance policy for `addons/godot_mcp`.
- TODO: Record asset source and license metadata for generated or third-party art.
- TODO: Define the next gameplay cleanup in a focused spec before implementation.
- TODO: Complete end-to-end testing of the weight system (speed/noise/UI) in Godot editor.
- TODO: Migrate `_test_project_scene_routes` to compare the main scene uid (`uid://dxjbgwnb1j7cw`) instead of the `res://` path string, so the test passes under Godot 4.6. Pre-existing on `origin/main`; the drift-fix PR adds a new uid-aware test instead.
- TODO: Re-evaluate autoload order in `project.godot`. `ItemDatabase` now reads from `GameRuntime.catalog` and so depends on `GameRuntime` being initialized. Current order (`NoiseSystem` → `ItemDatabase` → `GameRuntime` → `WeightSystem`) is safe today because `get_stack_limit` / `get_description` are only called after the player enters a scene, but the dependency should be made explicit (move `ItemDatabase` after `GameRuntime`) or eliminated (pass the catalog in via a setter) to keep the contract clear. See [decisions/0002](../decisions/0002-inventory-consistency.md).
- TODO: Wire every catalog item to a texture resource so the warehouse UI can show real icons. The catalog has item names and descriptions but no per-item icon mapping today; the warehouse UI shows a placeholder.
- TODO: **Direct-sell price is not what the tooltip shows.** When the player clicks "直接卖" on a mineral in the buyer popup, the price the customer pays is `base_price * customer.price_multiplier * preferred_bonus * timing * variance`. The buyer's `price_multiplier` (1.10 to 1.25) and the buyer's `preferred_tags` (a +8% bonus on tag match) are applied silently. The tooltip displays `base_price` only, so the player sees e.g. "Copper Nugget x1 底价 10" and the toast then reads "已出售 copper_nugget +12 铜板" for what they thought was a flat-price sell. Known example: buyer_blacksmith sells a Copper Nugget (`base_price=10`, `tags=[metal, ...]`, matches `preferred=[metal, blacksmith]`) for `10 * 1.10 * 1.08 * 1.00 * 1.04 ≈ 12.4`, rounded to 12. The previous fix (commit `17e130b`) only changed `timing` from `good` (1.08x) to `normal` (1.0x), which removed one source of inflation but left `price_multiplier` and `preferred_bonus` still active. The spec (`docs/specs/warehouse-system.md`) currently says the direct-sell price is `base_price * variance`, which is what the player expects. Pick one of: (a) make the direct-sell path pass flags that disable the buyer-specific multiplier and preferred bonus and clamp variance to 1.0, so the toast matches the tooltip exactly; (b) extend the spec so the tooltip shows the actual range (base × multiplier × preferred_bonus × [0.96, 1.04]) and the player can plan around it. Option (a) matches the player's mental model; option (b) is more honest. Defer the call until the team has a preference.
- TODO: Apply the three-layer display model to the mine scene. The mine currently has a hard-coded TileMap size and a Camera2D attached to the player; bring it into the world/camera/UI model so mine world bounds are explicit and the camera clamps cleanly.
- TODO: Add a "buyer remaining budget" indicator to the buyer NPC popup so the player can see how much each customer is willing to spend before clicking. Today the budget is enforced silently — the grid greys out only when budget is exhausted.
- TODO: Add the seven per-concern warehouse regression tests spelled out in the [warehouse spec](specs/warehouse-system.md) (warehouse 48-slot cap, 999-item cap, hotbar reset on mine entry, hotbar dump on town return, warehouse intact on mine death, weight system gating, customer budget consumption and exhaustion, deliverable-task filtering). The first cut landed the data model and rewrote `_test_core_economy_loop` to cover the end-to-end flow; the per-concern tests are still pending.
- TODO: Resolve `[node name="InventoryManager"]` in `scenes/mine/main_character_stats.tscn` referencing the renamed / `class_name` of the InventoryManager script. The script does not have a `class_name` declared, which means the scene file's path-based reference works but the editor is harder to use.

## Next Cleanup Candidates

- Add a small CI check around `tests/project/run_all.gd`.
- Create a focused spec for the next gameplay or UX cleanup.
- Replace hardcoded town NPC placement with a scene-authored or data-authored source if town layout expands.
- Split generated town UI from scene orchestration if town interactions grow.
- Save / load the warehouse across processes (currently session-local).
