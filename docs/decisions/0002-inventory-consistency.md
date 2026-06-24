# 0002 — Inventory Consistency Between GameRuntime and InventoryManager

Status: Accepted
Date: 2026-06-24

## Context

The unified inventory core (`GameRuntime` → `GameInventory` / `GameTransactionService` / `GameCatalog`) is the documented source of truth. `scripts/items/inventory_manager.gd` is supposed to be a thin "hotbar compatibility view" that syncs from that source of truth.

In practice it is not a view. It carries its own slot array, its own `unlocked_slots` (8), its own `MAX_SLOTS` (12), and its own "is full" judgment that disagrees with runtime on two axes:

1. **Capacity mismatch.** `InventoryManager.is_full()` says the backpack is full when 8 stacks are at their per-stack limit, because the local view only counts `unlocked_slots` (8) slots. `GameInventory` is sized at 18 slots. Concretely: when the player has filled the 8 visible hotbar stacks to their `stack_size`, the runtime still has 10 free slots. `gem_controller` calls `InventoryManager.is_full()` before pickup, so the player is **refused gems they could legitimately carry**. No test catches this because the hotbar UI hides slots 9-12 and visually discourages the player from filling them.

2. **Stack-size source of truth duplication.** `ItemDatabase` exposes `get_stack_limit(type: String)` that reads a hard-coded `STACK_LIMITS = { "gem": 99 }` constant. `GameCatalog` also exposes `get_stack_size(item_id: String)` that reads `item.stack_size` from `data/game/catalog.json`. Both fallback to 99 by coincidence, and both are right today, but they are independent sources. Adding any new item type means remembering to edit both.

`docs/architecture.md` already names `InventoryManager` as a compatibility view. The docs are right about the intent; the code drifted.

## Decision

Make `InventoryManager` an actual view. Stop computing "full" and "stack limit" from local state — proxy to the unified runtime.

### 1. `is_full()` proxies to `GameRuntime.inventory`

Add a public `is_full() -> bool` to `GameInventory` that returns `get_used_slot_count() >= capacity`. Change `InventoryManager.is_full()` to delegate to that. Update `gem_controller` callers — they keep calling `InventoryManager.is_full()` because the InventoryManager node is the one on the player, but the answer now comes from the 18-slot runtime instead of the 8-slot view.

Bonus: the local `_sync_from_runtime` cycle already keeps `InventoryManager.slots` consistent with runtime for the first 12 entries. After this change, any disagreement between the local view and the runtime on "is full" is impossible by construction.

### 2. `get_stack_limit` proxies to `GameCatalog`

Remove the `STACK_LIMITS` constant and the `DEFAULT_STACK_LIMIT` constant from `ItemDatabase`. Change the signature from `get_stack_limit(type: String)` to `get_stack_limit(item_id: String)`. The new implementation:

```gdscript
func get_stack_limit(item_id: String) -> int:
    var runtime := get_node_or_null("/root/GameRuntime")
    if runtime != null and runtime.get("catalog") != null:
        return int(runtime.get("catalog").get_stack_size(item_id))
    return 99
```

This keeps the same `99` fallback behavior for the case where `ItemDatabase` is queried before `GameRuntime` finishes its `_ready` (defensive — not expected in normal flow, because autoload order in `project.godot` is `GameRuntime` before `ItemDatabase`, but the autoload order in the current file is actually reversed; see [consequences](#consequences)).

Update the one call site, `InventoryManager._stack_limit(type)`, to take `item_id` instead. Both call sites inside `InventoryManager` (`is_full` and `add_item` fallback) need to read the item id from the slot. The fallback `add_item` path also needs to record `item_id` in the slot it creates so the lookup works there too — today it does not, which is a separate latent bug.

## Out of scope

- `unlocked_slots` and the four locked hotbar slots: they are still fake. `InventoryManager.unlocked_slots` stays at 8, the hotbar still draws 4 lock icons. The visual fiction does not change in this PR; only the *judgment* of "is full" is corrected. Removing the fake locks needs a UX decision (do we want 12 hotbar slots? or 18?) and is tracked in `docs/current_tasks.md` as a follow-up.
- `InventoryManager.unlock_slot` and `InventoryManager.clear_inventory`: no callers in the codebase, kept for API stability.
- The fallback path inside `InventoryManager.add_item` (path B): this branch is dead code in normal play because the `GameRuntime` autoload always exists. It is preserved and patched to be consistent (records `item_id` in the slot), but the existing single-source-of-truth test is not extended to it because that branch never runs.
- The customer `budget` field: still unread. Separate decision.
- Pre-existing `_test_mine_scene_structure` and `_test_project_scene_routes` failures: untouched.

## Consequences

- Players can no longer be locked out of pickups by the hotbar's 8-slot fiction. Gems fly into the player as long as `GameRuntime.inventory` has free capacity, which is what the in-game HUD and the unified inventory already implied.
- Adding a new item type now needs `data/game/catalog.json` only. `ItemDatabase` no longer requires a parallel constant.
- `InventoryManager` becomes thinner: it carries `unlocked_slots` and the slot mirror for UI rendering, and it forwards "is full" and "stack limit" to the runtime. That is closer to the documented "hotbar compatibility view" role.
- `get_stack_limit` now touches `/root/GameRuntime` on every call. This is a 2-attribute dictionary lookup; the cost is negligible. The defensive fallback keeps the method safe even before `GameRuntime._ready` has fired.
- `ItemDatabase` reads from `GameRuntime` instead of holding its own constants. Autoload order in `project.godot` puts `ItemDatabase` before `GameRuntime` (`NoiseSystem` → `ItemDatabase` → `GameRuntime` → `WeightSystem`). `ItemDatabase.get_stack_limit` is only invoked from inventory mutation paths that run after the player has entered a scene, by which time both autoloads are ready. The `99` fallback covers the theoretical case where a future caller invokes it during `_init` of a script that loads before the scene. Tracked in `docs/current_tasks.md` so this dependency does not get forgotten when someone reorganizes the autoload list.

## Verification

- `tests/project/run_all.gd` adds two regression tests:
  - **`inventory manager is_full proxies to runtime capacity`**: seed `GameRuntime.inventory` past `unlocked_slots=8` but well below runtime capacity, assert `InventoryManager.is_full()` returns `false`. Seed past runtime capacity, assert `true`. Locks out the 8-slot fiction.
  - **`item database get_stack_limit reads from catalog source of truth`**: add a one-off item with `stack_size: 42` to the in-memory catalog state, assert `get_stack_limit(id)` returns 42, not 99. Locks out the constant-table drift.
- `godot --headless --path . -s res://tests/project/run_all.gd`: 413 PASS, 3 pre-existing FAIL (same as before), 0 new FAIL.
- Smoke `town` and `mine` still exit clean.
