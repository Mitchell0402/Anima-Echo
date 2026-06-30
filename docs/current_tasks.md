# Current Tasks

Last updated: 2026-06-28

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

NPC world sprites and default portraits use the generated visual candidate set:

| NPC | World sprite | Default portrait | Scene path |
|-----|--------------|------------------|------------|
| 守夜老人 (elder) | `res://assets/town/npcs/elder_idle.png` | `res://assets/ui/portraits/elder_neutral.png` | `scenes/town/npc_elder.tscn` |
| 铁匠青年 (blacksmith) | `res://assets/town/npcs/blacksmith_idle.png` | `res://assets/ui/portraits/blacksmith_neutral.png` | `scenes/town/npc_blacksmith.tscn` |
| 花店少女 (florist) | `res://assets/town/npcs/florist_idle.png` | `res://assets/ui/portraits/florist_neutral.png` | `scenes/town/npc_florist.tscn` |
| 商人 (buyer) | `res://assets/town/npcs/buyer_idle.png` | `res://assets/ui/portraits/buyer_neutral.png` | `scenes/town/npc_buyer.tscn` |

`data/narrative/dialogues.json` references the neutral portrait paths in each NPC's `"portrait"` field. Concerned portrait variants exist as placeholder candidates but are not wired to emotion-specific dialogue yet.

### Task System

`scripts/economy/task_service.gd` manages tasks with three objective types: `event_count`, `event_sum`, `deliver_item`. Progress tracked via `GameEventBus`.

**Task types** (via `flags` field in `catalog.json`):

| Type | Flag | Behavior |
|------|------|----------|
| 剧情 (Story) | `["story"]` | Persists across days until completed. Never wiped. |
| 每日 (Daily) | `["daily"]` | Wiped each morning. 3 new ones drawn from `daily_pool`. |

**Current tasks** (17 total: 12 story + 5 daily):

### 剧情任务链（12个，渐进解锁）

> 剧情任务不会立即解锁下一个。`claim_reward` 将后续任务放入队列，每天早上 `process_story_queue` 解除最多 **2 个** 新任务。
> 如果前一天的任务未完成，新任务不会解锁——顺延到下一天。

```
#1 小镇初识 → #3 第一桶金 → #4 善意初显
#2 初窥真相 → #5 矿工日常 → #6 精明商人
                              → #7 点石成金
                              → #8 深渊门票 → #9 星辰呼唤 → #10 命运抉择 → #11 坚定不移
                                                                              → #12 真心相待
```

**每日剧情任务节奏**: 每天最多解锁 2 个。如果前一天未做完的剧情任务顺延到当天，当天不会解锁新任务。

**做完当天剧情任务后**: HUD 任务面板显示「去挖挖矿吧，明天或许有新的任务」。

| # | ID | 名称 | 目标 | 事件 | 奖励 | 解锁 |
|---|-----|------|------|------|------|------|
| 1 | `task_talk_to_townspeople` | 小镇初识 | 与4位NPC交谈 | `npc_talked_*` ×4 | 2普通原石+30铜 | #3 |
| 2 | `task_first_identification` | 初窥真相 | 鉴定任意原石×1 | `item_identified` ×1 | 1精良原石+20铜 | #5 |
| 3 | `story_first_sell` | 第一桶金 | 出售任意矿物×1 | `item_sold` ×1 | 50铜 | #4 |
| 4 | `story_first_gift` | 善意初显 | 赠送礼物给NPC×1 | `item_gifted` ×1 | 1普通原石+30铜 | — |
| 5 | `story_mine_3_times` | 矿工日常 | 累计完成采矿×3 | `mine_run_completed` ×3 | 2精良原石+60铜 | #6, #7 |
| 6 | `story_earn_300` | 精明商人 | 出售收入达300铜 | `item_sold.total_price` sum≥300 | 1稀有原石+80铜 | — |
| 7 | `story_buy_deep_ticket` | 深渊门票 | 购买深层入场券 | `deep_ticket_bought` ×1 | 150铜 | #8 |
| 8 | `story_find_star` | 星辰呼唤 | 鉴定星辰矿×1 | `star_identified` ×1 | 1稀有原石+200铜 | #9 |
| 9 | `story_make_choice` | 命运抉择 | 做出第一次选择 | `star_choice_made` ×1 | 300铜 | #10, #11 |
| 10 | `story_three_choices` | 坚定不移 | 累计3次同方向选择 | `star_choice_made` ×3 | 1稀有原石+500铜 | — |
| 11 | `story_affection_50` | 真心相待 | 任意NPC好感度达50 | `affection_milestone_50` ×1 | 1稀有原石+200铜 | — |

**新增事件**（由 `_emit_story_event` 发射）: `item_gifted`, `mine_run_completed`, `deep_ticket_bought`, `star_identified`, `star_choice_made`, `affection_milestone_50`

### 每日任务（8个，daily_pool 随机抽 3个/天）

> UI 中每日任务名称后显示「（每日）」标签。

| # | ID | 名称 | 类型 | 目标 | 奖励 |
|---|-----|------|------|------|------|
| 1 | `daily_copper_run` | 铜矿订单 | 交付 | 铜块 ×5 | 1普通原石+80铜 |
| 2 | `daily_iron_forge` | 铁匠的急单 | 交付 | 铁片 ×3 | 1精良原石+120铜 |
| 3 | `daily_silver_chain` | 珠宝匠的银链 | 交付 | 银脉 ×2 | 1稀有原石+150铜 |
| 4 | `daily_gold_smelt` | 金匠的委托 | 交付 | 金脉 ×1 | 1稀有原石+200铜 |
| 5 | `daily_crystal_order` | 收藏家的水晶 | 交付 | 水晶花 ×2 | 1精良原石+130铜 |
| 6 | `daily_moonlit_delivery` | 月光石的订单 | 交付 | 月光水晶 ×1 | 1稀有原石+180铜 |
| 7 | `daily_quick_sell` | 快速出货 | 事件 | 出售矿物 3 次 | 60铜 |
| 8 | `daily_identify_batch` | 鉴定清单 | 事件 | 鉴定原石 2 次 | 2普通原石+50铜 |

### NPC 委托任务（12个，按好感阈值解锁，每个 NPC 每天最多 1 个活跃）

> UI 中 NPC 委托任务名称后显示「（委托）」标签。
> 任务持久不消失，完成当前 tier 后次日解锁下一 tier。

#### 守夜老人 (elder)

| ID | 好感要求 | 名称 | 目标 | 奖励 |
|---|---------|------|------|------|
| `npc_elder_light` | 20 | 夜灯 | 交付月光水晶 x1 | 好感 +10，铜板 +100 |
| `npc_elder_tale` | 50 | 往事 | 交付星辰碎片 x1 | 好感 +15，铜板 +200，稀有原石 x1 |
| `npc_elder_name` | 80 | 真名 | 交付星辰矿 x1 | 好感 +20，铜板 +500 |

#### 铁匠青年 (blacksmith)

| ID | 好感要求 | 名称 | 目标 | 奖励 |
|---|---------|------|------|------|
| `npc_smith_rush` | 20 | 急单 | 交付铜块 x5 + 铁片 x3 | 好感 +10，铜板 +120 |
| `npc_smith_debt` | 50 | 舍与得 | 交付银脉 x2 + 金脉 x1 | 好感 +15，铜板 +300，精良原石 x1 |
| `npc_smith_closure` | 80 | 诀别 | 交付星辰矿 x1 | 好感 +20，铜板 +500 |

#### 花店少女 (florist)

| ID | 好感要求 | 名称 | 目标 | 奖励 |
|---|---------|------|------|------|
| `npc_florist_soil` | 20 | 新土 | 交付水晶花 x3 | 好感 +10，铜板 +80 |
| `npc_florist_color` | 50 | 颜色 | 交付星辰碎片 x1 + 月光水晶 x1 | 好感 +15，铜板 +150，精良原石 x1 |
| `npc_florist_bloom` | 80 | 花开 | 交付星辰矿 x1 | 好感 +20，铜板 +600 |

#### 商人 (buyer)

| ID | 好感要求 | 名称 | 目标 | 奖励 |
|---|---------|------|------|------|
| `npc_buyer_sample` | 20 | 样品 | 交付水晶花 x1 + 月光水晶 x1 | 好感 +10，铜板 +150 |
| `npc_buyer_rare` | 50 | 珍品 | 交付金脉 x2 + 银脉 x3 | 好感 +15，铜板 +300，稀有原石 x1 |
| `npc_buyer_honor` | 80 | 荣誉 | 交付星辰矿 x1 | 好感 +20，铜板 +800 |

### 实现机制

- `task_service.claim_reward()` 成功后读取任务的 `unlocks` 数组，**推入 `_story_unlock_queue` 队列**（不立即接取）。
- `task_service.process_story_queue(day_count)` 每天早上被 `_end_night()` 调用，从队列取出最多 `STORY_TASKS_PER_DAY`（默认 2）个任务接取。
- 如果当天仍有未完成的剧情任务（`get_active_story_task_count() > 0`），不会解锁新任务。
- `_last_queue_day` 防止同一天内重复处理。
- 所有剧情任务做完：HUD 显示「去挖挖矿吧，明天或许有新的任务」。
- 新事件通过 `mining_town_scene._emit_story_event()` → `GameEventBus.emit_game_event()` → `TaskService._on_game_event()` 更新进度。
- `refresh_daily_tasks()` 只清除 `flags: ["daily"]` 的任务，剧情任务和 NPC 委托任务跨天保留。
- NPC 委托任务通过 `refresh_npc_tasks(affection)` 每天早上解锁：好感 >= `affection_required` 且该 NPC 无活跃委托时，按 tier 顺序接取。已完成的任务不会重复出现。
- NPC 委托任务完成后在 `_deliver_task()` 中通过 `affection.modify_affection()` 发放好感奖励，并触发 `threshold_reached` 信号。  

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
| Center | NPC popup / task board picker |
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

- Current generated candidates are tracked in [`docs/visual_assets/inventory.md`](visual_assets/inventory.md). Wired-but-not-final art remains `placeholder` until a later visual review approves final quality.
- First-pass generated candidates already wired: item icons, NPC world sprites, neutral NPC portraits, title/intro backgrounds.
- Second-pass generated candidates wired on 2026-06-28: mine gem pickups, mine wall nodes, cover crate, minecart return, oxygen pump, mine gate, refine station, town building/decor/prop/tree overlay layer, dialogue/warehouse/hotbar/popup/button UI skin assets.
- Old `assets/props/task_board.png` is obsolete; `assets/town/props/task_board.png` is now used by `scenes/town/mining_town.tscn`.
- Generated town and mine tilesets remain placeholder assets until a focused TileMap migration can preserve collision, traversal, camera framing, and NPC/task-board interaction ranges.
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
- **Day/Night Cycle**: `DayNightCycle` autoload. Three time periods: 上午→下午→傍晚. Mine→town return advances time. 2 mine entries/day. 傍晚 mine closed. Sleep→next morning resets.
- **NPC Affection**: `scripts/narrative/npc_affection.gd`. 0–100, gift +1/+3/+5. 1 gift per NPC per day.
- **Morality Tracker**: `scripts/core/morality_tracker.gd`. Tracks star crystals sold vs gifted.
- **Equipment System**: `scripts/player/equipment_system.gd`. 4 slots, good/evil exclusive items, basic upgrades (pickaxe, backpack, talisman).

## MCP Development Baseline

Godot MCP Pro is part of the expected local development loop. See [testing.md](testing.md) for the full MCP health check and acceptance workflow.

Last verified: 2026-06-28 through in-thread MCP tools.

- `get_project_info`: connected to `Mine Platform V2`, Godot `4.6.3-stable`, main scene `res://scenes/ui/title_menu.tscn`, renderer `forward_plus`, viewport `1152x720`.
- MCP autoloads present: `MCPScreenshot`, `MCPInputService`, `MCPGameInspector`.
- `get_scene_tree`: current edited scene is `res://scenes/ui/title_menu.tscn`, root `TitleMenu`, script `res://scripts/ui/title_menu.gd`.
- `get_output_log` filtered by `MCP`: addon started on ports `6505-6514` and registered 171 commands.
- `get_editor_errors`: currently reports repeated `Condition "!is_inside_tree()" is true.` errors. Treat these as current editor noise unless a task changes tree/lifecycle behavior, then compare before/after.

For development and review, use MCP evidence when a change affects scenes, visuals, UI, input, runtime behavior, or acceptance criteria. Headless tests still provide the regression gate; MCP proves the editor/runtime behavior that tests do not cover.

## Known Risks And TODOs

- TODO: Add a CI workflow if GitHub should enforce the Godot regression suite.
- TODO: Confirm how contributors should discover the Godot executable across machines.
- TODO: Decide the maintenance policy for `addons/godot_mcp`; keep it tooling-only until that decision is made.
- TODO: Record asset source and license metadata for generated or third-party art.
- TODO: Define the next gameplay cleanup in a focused spec before implementation.
- TODO: Complete end-to-end testing of the weight system (speed/noise/UI) in Godot editor.
- TODO: Migrate `_test_project_scene_routes` to compare the main scene uid instead of `res://` path.
- TODO: Re-evaluate autoload order in `project.godot`. `ItemDatabase` depends on `GameRuntime`.
- TODO: Wire every catalog item to a texture resource so the warehouse UI can show real icons.
- DONE 2026-06-30: **Direct-sell price mismatch** fixed. Town direct-sell and star-crystal sell now pass `price_mode: "base"` so the actual wallet/budget transaction matches the displayed `base_price`; QTE negotiation still uses offer multipliers.
- TODO: Audit every existing `assets/**/*.png` and add `<name>.png.meta.md` sidecar.
- TODO: Populate `docs/visual_assets/inventory.md` with the full asset list.
- TODO: Generate missing UI icons using external image-generation AI.
- DONE 2026-06-28: Generated current-playable visual candidates listed in `docs/specs/visual_asset_audit_generation_plan.md`, including the three-level mine tileset set (`shallow_cave_tileset.png`, `mid_cave_tileset.png`, `deep_cave_tileset.png`). Player/enemy animation, good/evil-specific variants, ending screens, and other future-only assets remain deferred.
- DONE 2026-06-28: Wired first-pass generated placeholder candidates for item icons, NPC world sprites, NPC dialogue portraits, title background, and intro background. The candidates remain `placeholder` art until a later visual review approves final quality.
- DONE 2026-06-28: Wired the remaining direct-match generated visual candidates into current scenes/UI: mine pickups/nodes/props, town building/decor/prop/tree overlay, mine gate/refine station/task board, and generated UI button/panel/slot/overlay skin assets.
- TODO: Migrate generated town and mine tilesets in a focused TileMap pass with collision/pathing validation.
- TODO: Wire context-specific UI icons that need real UI semantics first (`coin`, `day`, `night`, `health`, `oxygen`, `weight`, equipment icons, `settings_panel`, `toast`, `refined_badge`).
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
