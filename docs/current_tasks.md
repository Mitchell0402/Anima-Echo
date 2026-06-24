# Current Tasks

Last updated: 2026-06-24

## Current Baseline

- The repository is a single-root Godot project for a 2D mining prototype.
- The current main scene is `res://scenes/town/mining_town.tscn` (uid `uid://dxjbgwnb1j7cw`).
- The current mine route is `res://scenes/mine/test_scene.tscn`.
- The current automated test entrypoint is `res://tests/project/run_all.gd`.
- The project has a normalized layout under `assets/`, `data/`, `docs/`, `scenes/`, `scripts/`, and `tests/`.
- The runtime economy core is already present under `scripts/core` and `scripts/economy`.
- **Weight System**: 3-tier encumbrance (Light/Heavy/Overload) based on raw geode weight, with speed and noise penalties. [Spec](specs/weight_system.md)
- **Doc/Scene/Service Drift**: Three silent inconsistencies (main scene, town scene script reference, `CustomerShopService.list_customers()`) are fixed by the `[codex/fix-doc-scene-drift]` branch and locked down with four new regression tests. [Decision](../decisions/0001-fix-doc-scene-drift.md)
- **Inventory Consistency**: `InventoryManager.is_full()` and `ItemDatabase.get_stack_limit` now proxy through to `GameRuntime.inventory` and `GameRuntime.catalog` instead of holding a local 8-slot fiction or a parallel constant table. See [Decision](../decisions/0002-inventory-consistency.md).
- **Warehouse System**: A 48-slot in-town warehouse splits the existing 18-slot inventory into a 12-slot in-mine hotbar plus a 48-slot (999-item soft cap) at-home warehouse. Hotbar resets on mine entry, dumps to warehouse on town return, and clears on mine death. Town NPC sell/identify/deliver actions read the warehouse directly through a symmetric warehouse UI. [Spec](specs/warehouse-system.md) / [Decision](../decisions/0003-warehouse-system.md). **In drafting — spec and decision are written, implementation is the next PR.**
## Known Risks And TODOs

- TODO: Add a CI workflow if GitHub should enforce the Godot regression suite.
- TODO: Confirm how contributors should discover the Godot executable across machines.
- TODO: Decide the maintenance policy for `addons/godot_mcp`.
- TODO: Record asset source and license metadata for generated or third-party art.
- TODO: Define the next gameplay cleanup in a focused spec before implementation.
- TODO: Complete end-to-end testing of the weight system (speed/noise/UI) in Godot editor.
- TODO: Restore the missing `Enemy` / `Enemy3` instances under `EnemyCollection` in `scenes/mine/test_scene.tscn` so the pre-existing `_test_mine_scene_structure` failure is cleared. Same baseline state on `origin/main`; not part of the drift-fix PR.
- TODO: Migrate `_test_project_scene_routes` to compare the main scene uid (`uid://dxjbgwnb1j7cw`) instead of the `res://` path string, so the test passes under Godot 4.6. Pre-existing on `origin/main`; the drift-fix PR adds a new uid-aware test instead.
- TODO: Re-evaluate autoload order in `project.godot`. `ItemDatabase` now reads from `GameRuntime.catalog` and so depends on `GameRuntime` being initialized. Current order (`NoiseSystem` → `ItemDatabase` → `GameRuntime` → `WeightSystem`) is safe today because `get_stack_limit` is only called after the player enters a scene, but the dependency should be made explicit (move `ItemDatabase` after `GameRuntime`) or eliminated (pass the catalog in via a setter) to keep the contract clear. See [decisions/0002](../decisions/0002-inventory-consistency.md).
- TODO: Implement the [warehouse system](specs/warehouse-system.md). Spec and [decision record](decisions/0003-warehouse-system.md) are written; the next PR introduces `GameWarehouse`, splits `GameInventory` into `GameHotbar`, and rewires the town NPC popups to read the warehouse. Out of scope (per the spec) but worth re-evaluating later: save/load across processes, player-curated transfer on town return, drag-to-reorder inside the warehouse, multi-day budget regeneration, an in-mine warehouse read-only view.
## Next Cleanup Candidates

- Add a small CI check around `tests/project/run_all.gd`.
- Create a focused spec for the next gameplay or UX cleanup.
- Replace hardcoded town NPC placement with a scene-authored or data-authored source if town layout expands.
- Split generated town UI from scene orchestration if town interactions grow.
