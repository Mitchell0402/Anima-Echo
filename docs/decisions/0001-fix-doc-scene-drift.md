# 0001 — Fix Doc / Scene / Service Drift

Status: Accepted
Date: 2026-06-24

## Context

A pre-PR audit of the `inventory-system` worktree found three places where the
code, the project docs, and the runtime config did not agree. Each drift is
small on its own, but together they let bugs hide behind documentation that
looks current. None of them broke gameplay directly, but they made the project
harder to trust and easier to fork badly.

### Drift 1 — main scene pointed at the mine, not the town

`project.godot` had `run/main_scene = "uid://cq8hfusdbalf6"`. That uid belongs
to `res://scenes/mine/test_scene.tscn`, so launching the project dropped the
player straight into the mine with no town context. Every project doc
(`docs/PROJECT_CONTEXT.md`, `docs/architecture.md`, `docs/current_tasks.md`,
`AGENTS.md`, the PR template checklist) said the main scene is the town. The
existing test `_test_project_scene_routes` even asserted the town path, so the
test suite was already disagreeing with the runtime config — anyone who ran
the regression script in headless mode would see the test fail and assume it
was a test bug.

### Drift 2 — `mining_town.tscn` referenced a deleted script

`scenes/town/mining_town.tscn` had this ext_resource line:

```
[ext_resource type="Script" uid="uid://dieycncl74k6o" path="res://scripts/town/fused_mining_town_scene.gd" id="1"]
```

`scripts/town/fused_mining_town_scene.gd` was deleted in commit `9ddaaab`
("Clean project foundation"). The current town script is
`scripts/town/mining_town_scene.gd`, but the scene was never updated. As long
as the main scene was the mine, nobody noticed; the moment we restored the
town as the main scene, Godot would log a missing-script warning and the town
would render as an empty `Node2D`.

The uid `dieycncl74k6o` was the original uid of `fused_mining_town_scene.gd`.
After deletion, the `.uid` file in `scripts/town/` got renamed in lockstep, so
`mining_town_scene.gd.uid` now carries the fused script's old uid. Godot 4.6
recovers the uid from the import cache, so the same uid can stay valid for
the renamed script — we kept it rather than reshuffling every external
reference.

### Drift 3 — `CustomerShopService.list_customers()` returned tasks

`scripts/economy/customer_shop_service.gd::list_customers()` was implemented
as `return catalog.get_tasks()`. The method name promises a customer list; the
return value is a list of task definitions. The architecture doc already
flagged this as TODO #4. No caller existed yet, so the bug was silent, but
any UI that would have iterated customers to build a "who wants this gem"
menu would have shown tasks instead.

The deeper problem: `GameCatalog` did not expose `get_customers()` at all.
`get_customer(id)` was there for single lookups, but there was no bulk
accessor. So `list_customers()` could not be fixed without first adding the
catalog method.

## Decision

Fix all three drifts in one focused change, in one PR, with regression
tests so they cannot quietly come back.

### Concrete changes

- `project.godot`: `run/main_scene` → `uid://dxjbgwnb1j7cw` (town scene).
- `scenes/town/mining_town.tscn`: ext_resource `path` →
  `res://scripts/town/mining_town_scene.gd`. Keep uid `dieycncl74k6o` (stable
  via import cache).
- `scripts/core/game_catalog.gd`: add `get_customers()` that returns
  `_customers.values().duplicate(true)`, mirroring the existing `get_tasks()`
  shape.
- `scripts/economy/customer_shop_service.gd::list_customers()`: delegate to
  `catalog.get_customers()`.
- `tests/project/run_all.gd`: add four regression tests so the next cleanup
  that touches any of these will fail loudly:
  - `main scene points to mining town not the mine route` (uid + path +
    instantiate check)
  - `town scene script reference is not stale` (no `fused_` substring, correct
    `path`, file present, fused file gone)
  - `shop service list_customers returns customers not tasks` (positive
    `buyer_*` id, negative `task_*` id)
  - `catalog exposes get_customers matching data file` (count matches
    `data/game/catalog.json` `customers` array length)

## Out of scope

Two pre-existing test failures stay in scope of "later" work, not this PR:

- `_test_mine_scene_structure` fails because `scenes/mine/test_scene.tscn` has
  an empty `EnemyCollection` node and no `Enemy` / `Enemy3` instances under
  it. The test predates the missing children.
- `_test_project_scene_routes` compares the main scene setting against the
  literal `res://scenes/town/mining_town.tscn` string. With Godot 4.6 the
  setting is the uid form. The test was already failing on the baseline; we
  add a new uid-aware test instead of editing the old one.

Both are present on `origin/inventory-system` and `origin/main` before this
change, confirmed by running `run_all.gd` against the unmodified baseline.

## Verification

- `godot --headless --editor --quit --path .` — clean import refresh, only
  the expected "re-created from cache" notice for the restored `.uid` file.
- `godot --headless --path . -s res://tests/project/run_all.gd` — 411 PASS, 3
  pre-existing FAIL, 0 new FAIL.
- Smoke: `godot --headless --path . --quit-after 3` (town) and
  `godot --headless --path . res://scenes/mine/test_scene.tscn --quit-after 3`
  both exit cleanly without script errors.

## Consequences

- Anyone who bookmarked "launch the project" in their muscle memory will now
  start in the town, which matches every piece of documentation in the repo.
- `CustomerShopService.list_customers()` is now safe to call from UI code
  that needs to populate a buyer picker.
- The four new tests turn all three drifts into executable assertions. Any
  future rename that breaks a script reference, any future config flip that
  makes the mine the main scene, any future refactor that wires the shop
  service back to the task table — all of those will now fail CI instead of
  shipping silently.
