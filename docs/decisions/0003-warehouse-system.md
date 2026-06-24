# 0003 — Warehouse System Architecture

Status: Accepted
Date: 2026-06-24

## Context

The original `GameRuntime` design has a single 18-slot `inventory` that both the player "in the mine" and the player "in town" share. Town NPC actions (sell, identify, deliver) read this single inventory. There is no notion of "what I brought back from the run" versus "what I have at home". The 12-slot hotbar drawn at the bottom of the screen is a cosmetic mirror of the first 12 entries, with 4 fake-locked slots that do not actually block anything.

We want to introduce a permanent, larger storage in town that holds the player's accumulation across the session. The hotbar becomes the temporary in-mine backpack. NPC actions in town read the warehouse, not the hotbar. This is the Tarkov / Minecraft / Stardew pattern.

The existing system is small enough that we can choose how to split it. The question is **what the split looks like at the data and module level**, because that decision shapes every later change.

## Decision

Adopt a clean two-collection split inside `GameRuntime`. The current `inventory` is renamed to `hotbar` and resized to 12. A new `warehouse` collection is added. A small set of `GameRuntime` methods (`begin_mine_run`, `end_mine_run`, `on_player_killed_in_mine`) owns the handoff so callers do not have to know the order of operations.

### Why not reuse `GameInventory` for both

A single 60-slot collection where the first 12 are "hotbar" and the last 48 are "warehouse" was considered. Rejected because:

- The two regions have different lifetimes. The hotbar clears on `begin_mine_run` and on death; the warehouse survives both. A single collection means callers must remember which range to clear.
- The two regions have different capacity semantics. The hotbar is bounded by `stack_size` (each stack holds up to 99) and never needs a separate item cap. The warehouse has a 48-slot cap **and** a 999-item soft cap. Conflating them in one model makes both harder to read.
- The two regions have different reads. `WeightSystem` reads only the hotbar (because town is weight-free). `CustomerShopService` reads only the warehouse. Forcing both through a single accessor pollutes the call sites.

Two small RefCounted models — one for each region — keep each honest.

### Why a soft 999-item cap on top of the 48-slot cap

A 48-slot grid where each slot holds up to 99 items gives an absolute maximum of 4752 items. The 999 cap is therefore not a physical limit; it is a soft guard against the warehouse becoming a meaningless blob. The designer's intent is "you should accumulate, but not absurdly", and a number in the 3-4 digit range is the right visual scale for that intent. A hard cap (e.g. raise `max_items = 4752` and call it a day) is technically true but does not communicate intent; a soft cap with a clear number in the UI does.

The cap is checked on `add_item` only, by `total_items()` (sum of every stack's `quantity`). Selling or delivering decrements naturally because they go through `remove_item` first. The spec test `warehouse 999-item soft cap enforced` is the executable lock on this.

### Why a dedicated warehouse UI, not extending the hotbar UI

The hotbar UI is 12 fixed slots in a row, designed for the "I am in the mine, I see my stuff at a glance" use case. The warehouse UI is 6×8 grid, designed for the "I am in town, I want to look at everything" use case. They render different data, take up different screen real estate, and have different interaction models (hotbar is read-only during gameplay; warehouse is read-only in the standalone UI but clickable when embedded in an NPC popup).

A shared `WarehouseNpcPopup` control is the symmetric embeddable form used by the identifier and buyer NPCs. It is built from the same icon-and-tooltip components as the standalone warehouse UI, but its click handler is parameterised by the NPC action (identify vs sell). This avoids duplicating the rendering code while keeping the two UIs visually identical.

### Why `description` is added to the catalog now

Every tooltip in the new warehouse UI is a "name + description + price" triplet. The catalog today has only `name`, no `description`. Adding a `description` field is cheap (12 string literals) and makes the warehouse UI actually useful — a wall of items with no description is a wall of "L1 Geode", which is exactly the wall the player already has on the hotbar in the mine. The field is plain text, no markup, because the project has no rich text rendering wired up and adding it for one tooltip is out of scope.

### Why the weight system gates on the mine scene name

`WeightSystem` listens to `GameRuntime.inventory.changed` today. After this change the inventory is the hotbar, and the hotbar is empty in town. The cleanest gate is the one that matches the design intent: "weight only matters in the mine". Gating on `current_scene.name == "testScene"` is one line and has an executable test. The alternative (gating on whether the hotbar has items) is fragile — a future feature that puts a non-zero hotbar in town would silently break the gate.

The trade-off is the literal scene name in code. A future rename of the mine scene requires updating both `WeightSystem` and the test. That coupling is acceptable because the mine scene name is a stable part of the project, documented in `docs/PROJECT_CONTEXT.md`, and the test makes the dependency explicit.

### Why customer budget is consumed per session, not per day

The catalog defines a `budget` per buyer (400, 520, 650). Today nothing reads it. Adding consumption now is in scope because the warehouse spec changes the sell flow into "browse warehouse, click, confirm" which makes a per-NPC budget the natural place to gate sales.

`budget` resets to the catalog value at `GameRuntime.initialize_for_new_game`. It does not regenerate during the session. This matches the design: a session is the meaningful unit of time for a single-player 2D prototype, and the warehouse is session-local per the no-save-load decision. A "per day" or "per week" budget would require a calendar system, which the project does not have and which would have to be invented.

### Why a single key (`I`) toggles the warehouse UI

Two keys (`I` and `Esc`) close it. The `I` toggle is for muscle memory. `Esc` is for accessibility and for players who do not remember the toggle. The key is a no-op in the mine because showing the warehouse there would be confusing (the hotbar is full, the warehouse is what the player will see in a moment, and the UI overlay would block the action they are taking).

## Alternatives Considered

- **Single collection, two regions (front 12 = hotbar, back 48 = warehouse).** Rejected; see "Why not reuse `GameInventory` for both" above.
- **Hard 999-item cap that actually refuses at 1000.** Considered, but the soft cap is a guardrail, not a wall. The spec is explicit that the cap can be raised later by changing one constant; a hard cap would force a UI / data refactor when the cap is relaxed.
- **Per-day or per-week budget regeneration.** Rejected; no calendar exists, and the design is session-local.
- **Player-curated transfer on the way out of the mine ("press E to transfer each stack").** Considered, deferred. The current design is "automatic on town return", which is faster to ship and easier to test. A "pick what to bring back" UI is a meaningful follow-up, not a v1 requirement.
- **Tooltip weight display in town.** Rejected. The weight system does not run in town, so the number is a constant per item. Showing it would imply it matters; it does not.
- **Item rarity color coding on slots.** Rejected for v1. The catalog has a `rarity` field on every item but the spec does not introduce color coding. A later cosmetic pass can add it.

## Consequences

- Every file that references `GameRuntime.inventory` or `GameInventory` directly has to be updated. The grep list is: `mining_town_scene.gd`, `weight_system.gd`, `inventory_manager.gd`, `gem_controller.gd`, all economy services, all transaction tests. Mechanical change, but the surface is wide. A pre-merge `git grep` is mandatory.
- `GameRuntime.inventory` is gone. Any future code that wants "the player's stuff" must ask explicitly: hotbar or warehouse? This is a feature, not a bug — the old single collection encouraged cross-cutting reads.
- The 999 cap is a number in the spec, a number in `GameWarehouse`, and a number in a test. If a designer wants to change it, they change it in one place and the test catches any caller that depended on the old value.
- NPC popups get a new shape. The four existing `mining_town_scene.gd` popup actions are replaced by a shared `WarehouseNpcPopup` plus a small task-clerk popup. The existing popup strings and labels move with them.
- The `description` field on every catalog item is now load-bearing for the UI. Removing it later is a breaking change. Adding new items without a `description` will fail the static catalog test.
- The weight system becomes mine-scoped. A future feature that wants weight in town (e.g. an over-encumbered warning before a future dungeon) has to revisit the scene-name check.

## Verification

- Spec: `docs/specs/warehouse-system.md` is the source of truth for the feature. This decision record is the source of truth for the *shape*; the spec owns the *behavior*.
- Tests: the spec lists 11 new regression tests. They cover warehouse capacity (slot and item), hotbar lifecycle (mine entry reset, town return dump, mine death clear, partial overflow), weight gating, customer budget consumption and exhaustion, deliverable task filtering, and the static catalog description check.
- Manual: see the spec's "Manual" section. The end-to-end flow (mine -> return -> talk to NPC -> see warehouse -> transact) is the primary acceptance walk.
