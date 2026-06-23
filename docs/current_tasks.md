# Current Tasks

Last updated: 2026-06-23

## Current Baseline

- The repository is a single-root Godot project for a 2D mining prototype.
- The current main scene is `res://scenes/town/mining_town.tscn`.
- The current mine route is `res://scenes/mine/test_scene.tscn`.
- The current automated test entrypoint is `res://tests/project/run_all.gd`.
- The project has a normalized layout under `assets/`, `data/`, `docs/`, `scenes/`, `scripts/`, and `tests/`.
- The runtime economy core is already present under `scripts/core` and `scripts/economy`.

## Known Risks And TODOs

- TODO: Add a CI workflow if GitHub should enforce the Godot regression suite.
- TODO: Confirm how contributors should discover the Godot executable across machines.
- TODO: Decide the maintenance policy for `addons/godot_mcp`.
- TODO: Record asset source and license metadata for generated or third-party art.
- TODO: Define the next gameplay cleanup in a focused spec before implementation.
- TODO: Verify `CustomerShopService.list_customers()` behavior before building customer-selection UI.

## Next Cleanup Candidates

- Add a small CI check around `tests/project/run_all.gd`.
- Create a focused spec for the next gameplay or UX cleanup.
- Replace hardcoded town NPC placement with a scene-authored or data-authored source if town layout expands.
- Split generated town UI from scene orchestration if town interactions grow.
