# Warehouse System

Status: Draft
Last updated: 2026-06-24

## Goal

Introduce a permanent warehouse storage in town that holds the player's identified minerals and unspent raw geodes across the entire session. The hotbar (the 12-slot in-mine inventory) becomes a temporary container that the player fills while mining, dumps on the way back to town, and never sees while in town. NPC sell / identify / deliver actions in town read the warehouse directly, not the hotbar.

This separates "what I took into the mine" from "what I have at home", which is the pattern used by Minecraft (hotbar + chest), Stardew Valley (toolbar + chest), and Tarkov (backpack + secure container). For Anima Echo the metaphor is closest to Tarkov: the warehouse is the player's accumulation, the hotbar is what survives the run.

## Scope

- In scope: 48-slot warehouse grid, soft 999-item cap, hotbar <-> warehouse transfer on town return, NPC sell/identify/deliver against the warehouse, dedicated warehouse UI, weight system disabled in town, NPC customer budget consumed per sale, new `description` field on every catalog item.
- Out of scope: save/load across processes (warehouse is session-local, same as today's runtime state), multiple players, drag-to-reorder inside the warehouse, player-curated transfer on the way out of the mine, in-mine warehouse access, in-mine storage of any kind, the catalog `budget` field's UI display.

## Acceptance Criteria

### Warehouse data model

- [ ] `GameRuntime` exposes a new `warehouse` object with the same RefCounted shape as the current `GameInventory` (add_item / remove_item / has_item / has_requirements / count_item / get_stacks / get_used_slot_count / is_full / snapshot / restore / clear) and a public `capacity: int = 48`.
- [ ] `GameRuntime.warehouse.total_items() -> int` returns the sum of every stack's `quantity` (not the slot count). This is what the 999 cap reads.
- [ ] Warehouse respects the 48-slot limit: `add_item` returns `{"ok": false, "error": "warehouse_full"}` when `get_used_slot_count() >= 48` would be the result.
- [ ] Warehouse respects the 999-item soft cap: `add_item` returns `{"ok": false, "error": "warehouse_item_cap"}` when `total_items() + quantity > 999` would be the result. The existing stack is not partially written.
- [ ] Selling / delivering reduces the total. If a player has 999 items and picks up 5 more, then sells 3, they end at 996. The cap is `total_items()`, not slot count, not transaction count.

### Hotbar <-> Warehouse handoff

- [ ] `GameRuntime` exposes a new `hotbar` object (the renamed, capacity-12 version of the current `GameRuntime.inventory`).
- [ ] `scripts/items/inventory_manager.gd` connects to `GameRuntime.hotbar.changed` instead of `GameRuntime.inventory.changed`. The `scripts/items/inventory_manager.gd::unlocked_slots` cosmetic behavior is preserved (8 visible, 4 lock-icon).
- [ ] On entering the mine scene (`scenes/mine/test_scene.tscn`), the mine entrance code calls `GameRuntime.begin_mine_run()` which explicitly calls `GameRuntime.hotbar.clear()` and emits `mine_run_started`.
- [ ] On returning to town (`scenes/town/mining_town.tscn`), the `MinecartExit` "press interact" handler calls `GameRuntime.end_mine_run()` which (a) dumps every hotbar stack into the warehouse via `GameTransactionService.apply({type: "collect_item_into_warehouse", ...})`, (b) clears the hotbar, (c) emits `mine_run_ended`. The two transactions are wrapped so that a dump failure does not lose the hotbar contents (snapshot/restore).
- [ ] If the warehouse is full (either 48 slots or 999 items) and the player tries to return to town, the dump is partial: the hotbar keeps the items that did not fit, the player is shown a toast `"仓库已满,剩余 N 件原石丢失"`, and `mine_run_ended` still fires (so the player is not trapped in the mine).
- [ ] If the player dies in the mine, `GameRuntime.on_player_killed_in_mine()` clears the hotbar without touching the warehouse. No toast.

### NPC interactions in town

- [ ] `mining_town_scene.gd` no longer iterates the hotbar looking for a raw_stone or a mineral. Every NPC action goes through a new `WarehouseNpcService` or directly through `GameRuntime` services.
- [ ] **Miner NPC** popup: button "进入矿洞" — behavior unchanged.
- [ ] **Identifier NPC** popup shows a symmetric small warehouse window (see "Warehouse UI"):
  - Title: "鉴定原石".
  - Body: same 6x8 grid the warehouse uses, but the grid only contains the raw stones from the warehouse. Clicking a stack calls `IdentificationService.identify(stack.item_id, 1)`. After success the grid refreshes (the raw stone is gone, a new mineral may appear).
  - The popup can be closed with the existing "离开" button.
- [ ] **Buyer NPC** popup shows the same symmetric warehouse window:
  - Title: "出售矿物".
  - Body: same grid, filtered to items the buyer's `preferred_tags` and `rejected_tags` accept.
  - Hover tooltip shows `base_price` (from catalog). On click, the picker advances to a sell-mode popup with two options:
    1. **直接卖** — sell at the exact catalog `base_price`. No QTE, no risk, no customer multiplier, no preferred-tag bonus, no random variance.
    2. **讨价还价（QTE）** — pop a QTE circle (same visuals as the mine mining QTE). On success the sale closes with `timing = perfect` (+18% over the negotiated customer offer); on failure `timing = bad` (-15% under the negotiated customer offer). The QTE result feeds straight into `CustomerShopService.sell_to_customer(buyer_id, item_id, 1, {timing: ...})`.
  - Pressing **直接卖** applies `CustomerShopService.sell_to_customer(buyer_id, item_id, 1, {"price_mode": "base"})`. The toast reports the final amount, which must match the displayed base price.
  - If the buyer has no remaining budget, every item in the grid is greyed out with the tooltip `"商人已无预算"`. The click does nothing.
  - The direct-sell price must be exactly `base_price`; QTE success should beat direct sell, QTE failure should be worse than direct sell, and budget checks must consume or reject based on the final transaction total.
- [ ] **Task Clerk NPC** popup lists only the active tasks whose `requirements` are currently satisfied by the warehouse. Each task is a focusable row: name, brief description, and a `交付` button (or Enter on the focused row).
  - Pressing Enter or clicking `交付` calls `TaskService.deliver_items(task_id)` then `TaskService.claim_reward(task_id)`. On success a toast appears `"获得 ... +N 铜板"` and the row disappears from the popup.
  - Tasks that are not currently deliverable are still visible but greyed. They can be focused (so the player can read the tooltip explaining what is missing) but Enter on them does nothing. They do not show a `交付` button.
  - Tasks that are already `completed` are hidden from the popup entirely.

### Customer budget

- [ ] `GameRuntime` exposes `customer_remaining_budget: Dictionary` keyed by customer id. Each entry is initialized to `catalog.get_customer(id).budget` at `initialize_for_new_game`.
- [ ] `CustomerShopService.sell_to_customer` decrements `remaining_budget[customer_id]` by the negotiated total price after a successful transaction. If the buyer's remaining budget is below the offered total, the sale is rejected before any inventory change.
- [ ] Budget does not regenerate during a session. New sessions reset budget to the catalog value.

### Weight system in town

- [ ] `WeightSystem._process` (or whichever function updates the bar) early-returns when `get_tree().current_scene.name != "testScene"`. The weight bar is hidden in town and any other future scene. The hotbar size in town is zero (see acceptance "Hotbar <-> Warehouse handoff"), so the weight would be zero anyway, but the check makes the intent explicit.
- [ ] A regression test locks the current_scene check by name. Renaming the mine scene in the future requires updating both the test and the weight system.

### Catalog

- [ ] Every entry in `data/game/catalog.json` items array gains a `description` field (string, plain text, no markup). The descriptions are written once in this PR and live with the data. New items added later must also carry a description.
- [ ] The `weight` field on raw geodes is not displayed in the warehouse tooltip while the player is in town. It is still used by the weight system while in the mine.
- [ ] `ItemDatabase.get_display_name` stays as-is (returns the Chinese "原石 L%d" string for gems). A new method `get_description(item_id)` returns the new field, or empty string if the item has no description.

### Warehouse UI

- [ ] Triggered by a single key (default `I`, configurable in `project.godot` input map). The same key closes the UI when it is open.
- [ ] Esc also closes the UI. (Both keys are required; the explicit close is for accessibility.)
- [ ] The key is a no-op while in the mine scene — the warehouse UI never appears during a mine run.
- [ ] While the warehouse UI is open, player input (movement, mining, NPC interaction, hotbar use) is frozen. Scene ticks (`_process` / `_physics_process`) on player nodes still run, but no input is consumed.
- [ ] Layout: 6 columns x 8 rows = 48 slots. Centered on screen, occupying roughly 80% of the viewport height. Empty slots render as light grey squares.
- [ ] Each occupied slot shows the item icon (via `ItemDatabase.get_icon` when applicable, otherwise the default stack icon) and the stack's `quantity` in the bottom-right corner of the slot.
- [ ] Tooltip on hover: item display name (first line), description (second line, may wrap), and `base_price` (third line, prefixed with a coin glyph) if the item has a `base_price` field. Tooltip disappears when hover ends.
- [ ] The background is the live town scene with a darkening overlay (alpha 0.4 to 0.5, configurable). Not a black screen. Not a frozen screenshot.
- [ ] Slot order in the grid follows `data/game/catalog.json` items array order, which already groups raw geodes first then minerals. Empty slots appear after the last occupied slot.
- [ ] Items are not draggable. Clicking a slot in the standalone warehouse UI does nothing (the warehouse UI is read-only in this design; all writes happen through NPC actions or the mine handoff).

### File and module changes

The work will land across these areas. Each is sketched briefly so reviewers can match the spec to the eventual PR.

- `scripts/core/`: rename `game_inventory.gd` to `game_hotbar.gd` (or keep the file name and rename the class), introduce `game_warehouse.gd` as a new RefCounted model, add `total_items()` to both, expose `hotbar` and `warehouse` (and `customer_remaining_budget`) on `GameRuntime`. Add `begin_mine_run` and `end_mine_run` and `on_player_killed_in_mine` methods.
- `scripts/core/game_transaction_service.gd`: add `collect_item_into_warehouse` and `move_stack_from_hotbar_to_warehouse` transaction types. The latter wraps the dump in a single snapshot/restore so partial-failure leaves the hotbar intact.
- `scripts/economy/customer_shop_service.gd`: read and decrement `runtime.customer_remaining_budget` before applying the transaction; reject if insufficient.
- `scripts/economy/task_service.gd`: keep the existing `deliver_items` / `claim_reward` methods; the new UI just calls them in sequence. Add a helper `list_deliverable_tasks() -> Array` that filters `_states` by `_is_task_complete(...)` for the popup.
- `scripts/items/inventory_manager.gd`: switch from `GameRuntime.inventory` to `GameRuntime.hotbar`. Cosmetic `unlocked_slots` / MAX_SLOTS behavior is preserved.
- `scripts/town/mining_town_scene.gd`: replace the four popup actions with calls to the new warehouse-aware paths. The new popups are built from a shared `WarehouseNpcPopup` control.
- `scripts/town/mine_exit.gd`: call `GameRuntime.end_mine_run()` before `change_scene_to_file`.
- `scripts/mine/mine_interaction.gd` (or wherever player death is detected, likely `scripts/player/player.gd::die`): call `GameRuntime.on_player_killed_in_mine()` so the hotbar clears.
- `scripts/core/weight_system.gd`: skip updates when `current_scene.name != "testScene"`.
- `scripts/items/item_database.gd`: add `get_description(item_id) -> String`.
- `scripts/ui/warehouse_ui.gd` and `scripts/ui/warehouse_ui.tscn`: the standalone warehouse view.
- `scripts/ui/warehouse_npc_popup.gd` and `scripts/ui/warehouse_npc_popup.tscn`: the reusable embeddable warehouse grid used by identifier and buyer NPC popups. Symmetric to the standalone UI in look and interaction; the only differences are the title text and the click handler.
- `data/game/catalog.json`: add `description` to all 12 items.
- `project.godot`: register a new `toggle_warehouse` input action bound to `I`.
- `tests/project/run_all.gd`: regression tests for warehouse capacity, cap, handoff, weight system gating, customer budget consumption, deliverable task listing, and a static check that the catalog descriptions are all populated.

## Risks

- The `GameInventory` rename touches every file that references `GameRuntime.inventory` or `GameInventory` directly. The change is mechanical but the surface is wide (`mining_town_scene.gd`, `weight_system.gd`, `inventory_manager.gd`, `gem_controller.gd`, all economy services, all transaction tests). A `git grep` pass before merge is mandatory.
- The 999-item cap is soft: the warehouse can hold 48 slots * 99 quantity = 4752 items in the absolute maximum. The 999 cap is therefore mostly an early warning, not a hard physical limit. The spec keeps it because the designer's intent is "you should not stockpile absurd amounts", not "the warehouse runs out of space". If the cap is ever raised, only the soft cap constant needs to change.
- NPC popup embeddings are visually identical to the standalone warehouse UI but the click handlers are different. The risk is that someone copies the standalone UI and forgets to wire the action. The symmetric `WarehouseNpcPopup` control is the mitigation: both NPCs use the same scene with different `action` and `filter` parameters.
- Customer budget is consumed by `total_price`, not `unit_price`. Direct sell uses exact `base_price`, so the grid label, sell-mode button, wallet delta, and buyer budget delta match. Negotiated sales still apply customer multipliers, preferred/timing bonuses, and variance; only those paths may differ from the displayed base price, and the toast reports the final transaction amount.
- The current `_test_mine_scene_structure` and `_test_project_scene_routes` failures stay pre-existing. The new tests for the warehouse do not interact with them.

## Verification

### Automated

- `godot --headless --path . -s res://tests/project/run_all.gd` — runs the full regression suite plus the new warehouse tests.
- New tests target:
  - `warehouse 48-slot capacity enforced`
  - `warehouse 999-item soft cap enforced`
  - `hotbar reset on entering mine`
  - `hotbar dump on returning to town`
  - `warehouse stays intact on mine death`
  - `warehouse stays intact on partial dump overflow`
  - `weight system is a no-op outside the mine scene`
  - `customer budget decrements on sale`
  - `customer budget exhaustion blocks further sales`
  - `deliverable tasks are filtered to those currently satisfied`
  - `catalog descriptions are present on every item` (static check)

### Manual

- Launch town. Press `I`. Warehouse UI opens over the dimmed town. Press `I` or `Esc`. Closes.
- In town, no matter how the player tries, the warehouse is empty on first launch.
- Press `I` while in the mine. Nothing happens. The input is swallowed.
- Mine a couple of geodes, return to town via the minecart. Hotbar is now empty. Warehouse contains the geodes.
- Die in the mine. Hotbar is empty after respawn. Warehouse is unchanged.
- Talk to the identifier. Pick a raw stone. Confirm. The stone is gone from the warehouse grid, a new mineral is there.
- Talk to the buyer. Hover a mineral. Tooltip shows name, description, base price. Click. Confirm dialog. Sale completes. Wallet balance increases. Buyer budget decreases.
- Talk to the buyer again, repeatedly, until budget is exhausted. Grid is now greyed out with "商人已无预算".
- Talk to the task clerk. Only the task that is currently deliverable is shown. Hit Enter on it. Toast. Task disappears from popup.
- Restart the game. Warehouse is empty again. Budgets reset to catalog values.

## Out of Scope (explicit)

These are intentionally deferred. Each is captured in `docs/current_tasks.md` so it does not get lost.

- Save/load across processes. Warehouse state is session-local, like the rest of the runtime.
- Multiple players / shared warehouse. Single-player only.
- Player-curated transfer on the way out of the mine. The dump is automatic and all-or-nothing (or partial on overflow, with a toast).
- Drag-to-reorder inside the warehouse.
- An in-mine warehouse UI or any in-mine storage besides the hotbar.
- A separate "off-spec" customer who buys at a different rate than catalog budget allows (e.g. dynamic pricing).
- A "warehouse sort" UI affordance. The catalog-order sort is fixed for this iteration.
- A "delivery preview" modal that lists every item the delivery would consume before confirming. The current design treats delivery as one keystroke.
- The buyer budget field is implemented and consumed; it is not yet surfaced in any UI other than the greyed-out grid. Adding a "remaining budget" indicator on the buyer popup is a separate task.
