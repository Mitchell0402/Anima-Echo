# Current Tasks

Last updated: 2026-06-27

## Current Baseline

- The repository is a single-root Godot project for a 2D mining prototype ("别按那个键" / Anima Echo).
- **Entry scene**: `res://scenes/ui/title_menu.tscn` → `res://scenes/ui/intro.tscn` (narration) → `res://scenes/town/mining_town.tscn`.
  - Title screen: START (new game), CONTINUE (disabled, no save yet), SETTING (stub), EXIT, TEST (skip intro → town directly).
  - Intro: 14-line black-screen narrative, left-click to advance, auto-transitions to town.
- **Town gameplay scene**: `res://scenes/town/mining_town.tscn`.
- **Mine route**: `res://scenes/mine/test_scene.tscn`.
- **Test entrypoint**: `res://tests/project/run_all.gd`.
- **Project layout**: `assets/`, `data/`, `docs/`, `scenes/`, `scripts/`, `tests/`.
- Runtime economy core at `scripts/core` and `scripts/economy`.

### Player Movement

Both town and mine use the same convention: **default WALK, hold Shift to RUN**.

| Scene | Script | Walk speed | Run speed | Animation |
|-------|--------|------------|-----------|-----------|
| Town | `scripts/town/town_player_controller.gd` | `@export var speed := 145.0` | `@export var run_speed := 290.0` | `walk_fblr` / `run_fblr` |
| Mine | `scripts/player/move_controller.gd` | `stats.get_effective_speed() * 0.5` | `stats.get_effective_speed()` | `walk_fblr` / `run_fblr` |

`project.godot` defines `walk` action bound to Shift (physical_keycode 4194325). Oxygen system drain rate flips: walk=1.0×, run=2.0×.

### NPC & Portrait Assets

All NPC portrait images live under `res://assets/props/`:

| NPC | Portrait path | Scene path |
|-----|---------------|------------|
| 守夜老人 (elder) | `res://assets/props/npc_task_clerk_sprites_alpha.png` | `scenes/town/npc_elder.tscn` |
| 铁匠青年 (blacksmith) | `res://assets/props/npc_miner_alpha.png` | `scenes/town/npc_blacksmith.tscn` |
| 花店少女 (florist) | `res://assets/props/npc_identifier_sprites_alpha.png` | `scenes/town/npc_florist.tscn` |
| 商人 (buyer) | `res://assets/props/npc_buyer_sprites_alpha.png` | `scenes/town/npc_buyer.tscn` |

`data/narrative/dialogues.json` references these portrait paths in each NPC's `"portrait"` field.

### Task System

`scripts/economy/task_service.gd` manages tasks with three objective types: `event_count`, `event_sum`, `deliver_item`. Progress tracked via `GameEventBus`.

**Auto-accepted on new game** (in `GameRuntime.initialize_for_new_game()`):

| Task ID | Name | Objectives | Reward |
|---------|------|------------|--------|
| `task_talk_to_townspeople` | 小镇初识 | Talk to all 4 NPCs (event: `npc_talked_<id>`) | 2× raw_common_geode + 30 coins |
| `task_first_identification` | First Reveal | Identify any geode (event: `item_identified`) | 1× raw_fine_geode + 20 coins |

**Task UI**: Right-side panel in town HUD (`◆ 当前任务`) shows all active tasks with per-objective progress (○ 0/1 → ✓).

**Event emission**: `mining_town_scene._on_dialogue_close()` emits `npc_talked_<npc_id>` via `event_bus.game_event.emit()`.

### Town HUD Layout

| Position | Content |
|----------|---------|
| Top bar | Prompt label (left) + status/coins (right) |
| Left-middle | Stability bar + value + morality tracker |
| Right-middle | Active task panel (任務名 + ○/✓ progress) |
| Bottom-left | Warehouse summary |
| Center | NPC popup / task board picker / refine picker |
| Center-top | Task board interaction hint |

### Title Menu

`scripts/ui/title_menu.gd` — CanvasLayer, layer 11. Dark purple background, centered gold title "别按那个键", 5 buttons:

- **START** → `intro.tscn` (new game)
- **CONTINUE** — disabled (no save system yet)
- **SETTING** — stub AcceptDialog
- **EXIT** → `get_tree().quit()`
- **TEST** — small, dim yellow, skips intro, goes directly to `mining_town.tscn`

### Intro Narration

`scripts/ui/intro.gd` — CanvasLayer, layer 12. Pure black background, centered white text, fade-in per line, left-click to advance. 14 lines total. Last line auto-transitions to town.

### Visual Assets

- New asset: `assets/props/task_board.png` (48×48 pixel-art wooden bulletin board). Sidecar at `assets/props/task_board.png.meta.md`.
- Old `assets/town/npcs/*.png` files still exist on disk but appear replaced in current scene/data references by `assets/props/` equivalents; audit them as likely obsolete before deletion.
- Full audit and batch-generation plan lives in [`docs/specs/visual_asset_audit_generation_plan.md`](specs/visual_asset_audit_generation_plan.md). It records 128 current PNGs, 1 current sidecar, the `imagegen` raster-only default, UI/dialogue/warehouse/shop coverage, and the town TileMap replacement requirement.

---

## Narrative Design

The full narrative/worldbuilding design lives in [`docs/specs/narrative_design.md`](specs/narrative_design.md). Every agent must read it before editing gameplay, NPC, or town-scene files.

**Current content status**:
- Title → Intro → Town entry flow: implemented
- 4 NPCs with stage 0–3 dialogues: implemented in `data/narrative/dialogues.json`
- Stage transitions gated by behavior milestones (first star crystal touch, first sell/gift, multiple choices): not yet wired
- Opening task "talk to all NPCs": implemented (guidance for first-time players)
- Daily content design (Day 1–20, ~2 hr): spec at [`docs/specs/daily_content_design.md`](specs/daily_content_design.md). 20 game days, 2 mine entries/day, ~6 min/day. 7 narrative phases (引导→积累→深渊→抉择→固化→真相→结局). Stability parameters will need tuning around Day 10.
- Remaining narrative work: catalogued at [`docs/specs/narrative_remaining.md`](specs/narrative_remaining.md). 2 bugs + 11 features across 6 phases, with dependency ordering. Priority: fix dialogue deduplication (B1/B2) → stage transition toasts (P0-1) → flower-girl tears (P0-2) → blacksmith evil-path lockout (P0-3).

## Existing Systems (from previous baseline)

- **Weight System**: 3-tier encumbrance (Light/Heavy/Overload) based on raw geode weight, with speed and noise penalties. Gated to mine scene. [Spec](specs/weight_system.md)
- **Oxygen System**: Carry-on oxygen tank consumed in mine scenes. 3.0× drain while mining, 2.0× while running, 0.5× while hidden. Depletion → HP drain → mine death → inventory clear + return to town. [Spec](specs/oxygen_system.md)
- **Warehouse System**: 12-slot in-mine hotbar + 48-slot in-town warehouse (999-item soft cap). Hotbar resets on mine entry, dumps to warehouse on town return, clears on mine death. [Spec](specs/warehouse-system.md)
- **Display System**: Three-layer world/camera/UI model. World 1152x648, integer zoom, anchor-based UI. [Decision](../decisions/0004-display-system.md)
- **Economy**: `GameRuntime` autoload owns catalog, event bus, hotbar, warehouse, wallet, RNG, transaction service, identification, negotiation, shop, and task services.
- **Stability System**: `StabilitySystem` autoload (0–100). Selling star crystal = -15, gifting = +15, gifting normal = +2. Daily decay 3. Affects enemy spawn/detection. Town tint changes with stability.
- **Day/Night Cycle**: `DayNightCycle` autoload. Mine→town return triggers night. Night ends → new day. 2 mine entries per day.
- **NPC Affection**: `scripts/narrative/npc_affection.gd`. 0–100, gift +1/+3/+5. 1 gift per NPC per day.
- **Morality Tracker**: `scripts/core/morality_tracker.gd`. Tracks star crystals sold vs gifted.
- **Equipment System**: `scripts/player/equipment_system.gd`. 4 slots, good/evil exclusive items, basic upgrades (pickaxe, backpack, talisman).

## Known Risks And TODOs

- TODO: Add a CI workflow if GitHub should enforce the Godot regression suite.
- TODO: Confirm how contributors should discover the Godot executable across machines.
- TODO: Decide the maintenance policy for `addons/godot_mcp`.
- TODO: Record asset source and license metadata for generated or third-party art.
- TODO: Define the next gameplay cleanup in a focused spec before implementation.
- TODO: Complete end-to-end testing of the weight system (speed/noise/UI) in Godot editor.
- TODO: Migrate `_test_project_scene_routes` to compare the main scene uid instead of `res://` path.
- TODO: Re-evaluate autoload order in `project.godot`. `ItemDatabase` depends on `GameRuntime`.
- TODO: Wire every catalog item to a texture resource so the warehouse UI can show real icons.
- TODO: **Direct-sell price mismatch**: tooltip shows `base_price` but actual price includes `price_multiplier` and `preferred_bonus`. Pick: (a) fix sell path to match tooltip, or (b) extend tooltip to show range.
- TODO: Audit every existing `assets/**/*.png` and add `<name>.png.meta.md` sidecar.
- TODO: Populate `docs/visual_assets/inventory.md` with the full asset list.
- TODO: Generate missing UI icons using external image-generation AI.
- DONE 2026-06-28: Generated current-playable visual candidates listed in `docs/specs/visual_asset_audit_generation_plan.md`, including the three-level mine tileset set (`shallow_cave_tileset.png`, `mid_cave_tileset.png`, `deep_cave_tileset.png`). Player/enemy animation, good/evil-specific variants, ending screens, and other future-only assets remain deferred.
- TODO: Review generated visual candidates and wire approved assets into scenes/resources without replacing player/enemy animation.
- TODO: Apply the three-layer display model to the mine scene.
- TODO: Add buyer remaining budget indicator to buyer NPC popup.
- TODO: Add 7 per-concern warehouse regression tests.
- TODO: Resolve `InventoryManager` node name in mine player scene.

## Next Steps (Day 5: Endings + Boss)

See [`docs/specs/development_plan.md`](specs/development_plan.md) for the full plan. Day 5 includes:
- 5.1 Evil ending (stability=0 → town collapse)
- 5.2 Good ending (stability=100 → boss fight)
- 5.3 Boss fight mechanics
- 5.4 Neutral ending (30+ days, never touched star crystal)
- 5.5 End-game statistics panel

## Next Cleanup Candidates

- Add a small CI check around `tests/project/run_all.gd`.
- Create a focused spec for the next gameplay or UX cleanup.
- Save / load the warehouse across processes (currently session-local).
- Wire stage transition triggers (first star crystal, first sell/gift) to NPC dialogue stages.
