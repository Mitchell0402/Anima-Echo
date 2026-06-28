# 剩余剧情开发清单

Status: Draft
Last updated: 2026-06-28

> 基于 `daily_content_design.md` 和已有代码的实际状态，
> 列出所有尚未实现的叙事相关功能，按依赖关系和优先级排列。

---

## 一、已完成（不需再开发）

| 系统 | 状态 |
|------|------|
| NPC Stage 0–3 全部对话 (`dialogues.json`) | ✅ |
| MoralityTracker (`has_touched_star` → `record_star_touched/sold/gifted` → `get_narrative_stage()`) | ✅ |
| 星辰矿鉴定弹窗 (`_open_star_identify_popup`：“这块石头，带着温热的呼吸。”) | ✅ |
| 星辰矿卖/送选择弹窗 (`_open_star_choice_popup`) | ✅ |
| 稳定度系统（卖-15、送+15、送普通+2、每日-3） | ✅ |
| 好感度系统（NpcAffection：0-100，每日每人限1次） | ✅ |
| 昼夜系统（DayNightCycle：2次下矿→夜晚） | ✅ |
| 门票系统（GameRuntime.mine_tickets，铁匠赠票+售票） | ✅ |
| 装备商店（基础+善恶过滤） | ✅ |
| 精炼站（消耗铜板×2售价/送礼） | ✅ |
| 自营小店/夜客 | ✅ |
| 每日任务（daily_pool随机3条） | ✅ |
| Intro 引导覆盖层（“大家怎么都如此沉默…和他们聊一聊吧。”） | ✅ |
| 床（白天休息→夜晚，夜晚睡觉→新一天） | ✅ |
| 矿洞入口独立物体（普通/深层选择面板） | ✅ |
| Stage 0→1→2→3 自动计算 | ✅ |
| 花店少女回赠装备检查 (≥2 star gift + affection ≥50) | ✅ |

---

## 二、待修复的 Bug

### B1: `first` / `first_evil` / `first_good` 对话重复显示

**现状**: `_talk_npc()` 中每次对话都会把 `stage_data["first"]` 加入 lines，没有追踪该 NPC 的 first 对话是否已经播放过。

**影响**: 玩家每次与 NPC 对话都会看到 "它感觉到了你。现在你也感觉到它了。" 等 first 台词。

**修复**: 
- `MoralityTracker` 新增 `Dictionary _shown_first_dialogues: Dictionary = {}`，记录 `{"elder_stage1": true, "blacksmith_stage2": true, ...}`
- 新增方法 `has_shown_first_dialogue(npc_id, stage_key)` 和 `mark_first_dialogue_shown(npc_id, stage_key)`
- `_talk_npc()` 中只在 `has_shown_first_dialogue` 返回 false 时才加入 first 行，然后 `mark_first_dialogue_shown`

**文件**: `scripts/core/morality_tracker.gd`、`scripts/town/mining_town_scene.gd`

### B2: Daily 对话无去重

**现状**: Daily 对话池中所有对话一次性全部 append，一次对话显示 5-6 条。

**预期**: 每次 talk 显示 1 条 daily + 1 条特殊对话（evil/good），让玩家每天都有新对话可看。

**修复**:
- 新增方法 `_get_daily_line(stage_data, npc_id, stage_key)` 返回随机一条未显示过的 daily
- 用 `_shown_daily_indices` 追踪，耗尽后重置

**文件**: `scripts/town/mining_town_scene.gd`

---

## 三、叙事功能：按优先级

### P0 — 阻塞玩家体验

#### P0-1: Stage 切换通知 toast

**描述**: 当 `get_narrative_stage()` 变化时，播放 toast 通知玩家叙事推进了。

| 触发条件 | Toast 文本 |
|----------|-----------|
| Stage 0→1（鉴定星辰矿后） | 「你触碰了不该触碰的东西。小镇感觉到了。」 |
| Stage 1→2（首次卖/送星辰矿后） | 「你做出了选择。小镇在看着你。」 |
| Stage 2→3（≥3次同类选择后） | 「真相如潮水般涌来。你终于明白了。」 |

**实现**:
- `mining_town_scene.gd` 中记录上次 stage，每次 `_refresh_hud` 时检测变化
- 或者 `MoralityTracker` 发射 `stage_changed(old, new)` signal，town scene 监听

**文件**: `scripts/core/morality_tracker.gd`、`scripts/town/mining_town_scene.gd`

#### P0-2: 花店少女首次收星辰矿的眼泪叙事

**描述**: 当玩家第一次将星辰矿赠予花店少女时，不只是简单的「已赠送！好感度 5/100」toast，而是一段特殊叙事。

**实现**:
- `_do_gift()` 中检测 `item_id == "star_crystal"` 时，弹出特殊对话面板：
  > 「你把它给了我。我可以再闻一闻春天了。」
  > （她的眼泪落了下来——全镇近十年来，第一滴眼泪。）
  > （花架上的枯枝中，似乎闪过一缕微不可见的绿色光点。）
- 使用已有的 DialogueUI 组件，无需新建 UI。
- 播放完自动关闭，然后正常 toast。

**文件**: `scripts/town/mining_town_scene.gd` (`_do_gift`)

#### P0-3: 铁匠首次劝阻后不再劝阻的变化

**描述**: Stage 2 evil 后，铁匠不再劝阻玩家，背对玩家打铁。这需要在交互上体现。

**当前状态**: Stage 2 evil 对话只有文本变化，没有行为变化。

**实现**:
- 铁匠 NPC 在 `current_alignment == "evil"` 且 `stage >= 2` 时：
  - 不再显示「购买矿洞门票」按钮（「不卖了。你自己去。」）
  - 深层入场券按钮灰显：「我不会再卖给你了。」
- 这个改动让恶人线玩家必须自己承担后果——铁匠不再提供门票。

**文件**: `scripts/town/mining_town_scene.gd` (`_open_popup("blacksmith")`)

---

### P1 — 核心叙事深度

#### P1-1: 深层矿场景（Day 5 内容）

**描述**: 全新的矿洞场景，替换/扩展 `test_scene.tscn`，支持星辰矿掉落的叙事环境。

**需要的子任务**:

1. **新建深层矿场景** `scenes/mine/deep_mine.tscn`
   - 更大的地图（相比浅层矿）。
   - 更暗的环境，带微红色调（靠近巨兽）。
   - 使用 `mine_wall_deep` loot table（更高概率的 fine/rare geode）。
   - `raw_star_geode`（Warm Geode）的掉落权重在深层更高。

2. **Warm Geode 掉落事件**
   - 首次挖到 `raw_star_geode` 时：
     - 屏幕微震 0.5 秒。
     - 播放低沉嗡鸣音效（如果有）。
     - Toast：「你感受到手中的石头……是温热的。」
   - 后续再挖到时无特效（只有第一次特殊）。

3. **深层矿入口**
   - `mine_entrance` popup 中「深层矿洞」按钮：
     - 需要检查 `_runtime` 是否有深层入场券。
     - `GameRuntime` 新增 `deep_mine_tickets: int`（初始 0）。
     - 铁匠的「购买深层入场券」改为实际消耗铜板并增加 `deep_mine_tickets`。
   - 进入深层矿消耗 1 张深层入场券。

4. **深层矿敌人**（可选，可先做无敌人版本）
   - 敌人 spawn rate 受 Stability 影响。
   - 敌人在深层矿比浅层矿更密集/更强。

**文件**: 新建 `scenes/mine/deep_mine.tscn`、`scripts/town/mining_town_scene.gd`、`scripts/core/game_runtime.gd`

#### P1-2: Stage 3 —— 真相大白

**描述**: 当 `get_narrative_stage()` 达到 3 时（≥3次同类选择），NPC 直接揭露真相。

**当前状态**: `dialogues.json` 中 stage.3 的 evil/good 对话已写好，`_talk_npc` 也已拼接 evil/good 行。但 Stage 3 首次触发时没有特殊的「真相揭示」叙事引导。

**实现**:
- Stage 进入 3 的第二天开始时（`end_night` 后），自动触发一段叙事覆盖层：

  **善人线**:
  > 「你归还的每一块星辰矿，都在逆向喂养那头沉睡在地底的巨兽。」
  > 「它不是被激怒的——而是被归还的灵魂碎片塞得太多，终于无法继续沉睡。」
  > 「守夜老人是对的：它在怕你。」
  > 「现在轮到它醒了。」

  **恶人线**:
  > 「你卖掉的每一块星辰矿，都是一条被抽走的灵魂。」
  > 「小镇已经空了。街上的人低着头，不是沉默——是已经没有东西可以表达了。」
  > 「守夜老人是对的：它在呼吸得更用力了。」
  > 「现在只差最后一步了。」

- 这段叙事可以在玩家首次进入 Stage 3 时，在夜晚结束/新一天开始时自动弹出（类似 Intro 覆盖层）。

**文件**: `scripts/town/mining_town_scene.gd`

---

### P2 — 结局系统

#### P2-1: 恶人结局（Stability = 0 → 小镇崩溃）

**触发条件**: `stability == 0`（大量卖星辰矿 + 自然衰减）

**实现**:
1. 在 `_update_stability_display()` 或 `_apply_town_tint()` 中检测 `stability <= 0`。
2. 不再等待玩家操作——直接触发结局覆盖层。
3. 结局覆盖层（CanvasLayer, layer 14，最高层级）：
   - 全屏黑色背景逐渐淡入（3秒）。
   - 文字逐行淡入：
     > 「小镇彻底沉默了。」
     > 「铁匠铺的锤子声停了。」
     > 「花店的水壶落在地上，没有人捡。」
     > 「守夜老人的椅子，空了。」
     > 「你变得极其富有。」
     > 「但这条街上，再也没有人看你一眼。」
   - 最后一行显示后，出现「返回主菜单」按钮。
   - 点击 → `get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn")`
4. 结局前不再允许任何交互（`player.movement_paused = true`，覆盖层吞噬所有输入）。

**文件**: `scripts/town/mining_town_scene.gd`（新增 `_check_evil_ending` 在 `_process` 或 `_refresh_hud` 中）

#### P2-2: 善人结局（Stability = 100 → Boss 战）

**触发条件**: `stability == 100`

**实现**:
1. 检测 `stability >= 100` 时，触发「巨兽苏醒」叙事覆盖层。
2. 覆盖层：
   > 「地底深处传来一声沉闷的咆哮。」
   > 「不是愤怒——是痛苦。」
   > 「你归还的每一块星辰矿，都在撕扯它的意识。」
   > 「铁匠青年背起锤子，走向你。」
   > 「『我等这一刻等了一辈子。带路。』」
   > 「深渊在呼唤。你准备好了。」
   - 点击确认 → 进入 Boss 战场景。

3. **Boss 战场景** `scenes/mine/boss_arena.tscn`（Day 5 重点工作）：
   - Boss: 巨兽（以意识为食的能量体），抽象形态（黑色/紫色蠕动光团）。
   - 战斗机制（简化版）：
     - Boss 周期性发射意识波（圆形冲击波）→ 玩家躲避。
     - Boss 召唤「矿脉突刺」（地面尖刺）→ 玩家跳跃/移位。
     - Boss 在攻击间隙暴露弱点（中央核心发光）→ 玩家靠近按 E 攻击。
     - 3 轮弱点暴露后，Boss 被击败。
   - 击败后触发善人结局覆盖层。
4. 善人结局覆盖层：
   > 「巨兽在一声长长的叹息中碎裂。」
   > 「那些被吞噬的灵魂碎片，像星光一样从地面升起。」
   > 「花店少女的枯枝中，冒出了第一抹绿色。」
   > 「铁匠青年放下锤子，笑了——这是你第一次见他笑。」
   > 「守夜老人从椅子上站起来。他不再等了。」
   > 「你做到了他们没有做到的事。」
   - 「返回主菜单」按钮。

**文件**: 新建 `scenes/mine/boss_arena.tscn`、`scripts/mine/boss_battle.gd`、`scripts/town/mining_town_scene.gd`

#### P2-3: 中立结局（30+天未碰星辰矿）

**触发条件**: `day_count >= 30` 且 `has_touched_star == false`

**实现**:
1. 第 30 天夜晚结束时触发。
2. 覆盖层：
   > 「三十天过去了。」
   > 「你始终没有靠近那条通往深处的矿道。」
   > 「小镇没有变好，也没有变坏。」
   > 「铁匠青年照旧打铁，花店少女照旧浇枯花，守夜老人照旧坐在镇口。」
   > 「他们不会记得你——但也不会恨你。」
   > 「你只是在这个被遗忘的镇子上，安静地挖了一段时间的矿。」
   > 「然后离开了。」
   > 「这或许也是一种选择。」
   - 「返回主菜单」按钮。

**文件**: `scripts/town/mining_town_scene.gd`

#### P2-4: 通关统计面板

**描述**: 结局后显示统计界面。

**统计内容**:
- 总天数
- 总采矿次数
- 星辰矿卖出/赠予数
- 每位 NPC 最终好感度
- 小镇稳定度最终值
- 善恶路线标签（善人/恶人/中立）

**实现**: 新建 `scripts/ui/ending_stats.gd` + `scenes/ui/ending_stats.tscn`

**文件**: 新建

---

### P3 — 氛围增强（可选，非阻塞）

#### P3-1: 星辰矿仓库脉动效果

**描述**: 仓库中存在 `star_crystal` 且尚未做出卖/送选择时，HUD 仓库标签或星辰矿图标有微弱的呼吸式透明度脉冲。

**文件**: `scripts/town/mining_town_scene.gd`

#### P3-2: 稳定度剧烈变化特效

**描述**: 稳定度 -15（卖出星辰矿）时，屏幕边缘短暂暗红闪烁 0.5 秒。

**文件**: `scripts/town/mining_town_scene.gd`

#### P3-3: 花店少女眼泪特效

**描述**: P0-2 泪滴叙事时，配合简单的蓝色粒子下落（用 Godot 粒子系统，1-2个粒子即可）。

**文件**: `scripts/town/mining_town_scene.gd`

#### P3-4: 首次送礼教学提示

**描述**: 玩家第一次打开送礼面板时（`_open_gift_picker`），弹出一个简短教程覆盖层：
> 「将矿物赠予 NPC 可以提升好感度。每人每天限送一次。」

**文件**: `scripts/town/mining_town_scene.gd`

---

## 四、实现顺序建议

```
Phase 1: Bug 修复（阻塞叙事体验）
  └── B1: first 对话重复修复           (30 min)
  └── B2: daily 对话去重               (20 min)
  └── P0-1: Stage 切换通知 toast        (20 min)

Phase 2: Day 1-4 叙事深度
  └── P0-2: 花店少女眼泪叙事            (30 min)
  └── P0-3: 铁匠恶人线不再售票          (20 min)

Phase 3: Day 5 深层矿
  └── P1-1: 深层矿场景                  (2-3 hr)
  │   ├── 深层矿地图
  │   ├── Warm Geode 掉落+首次特效
  │   └── 深层入场券消耗逻辑
  └── P3-2: 稳定度剧烈变化特效          (15 min)

Phase 4: Stage 3 + 结局
  └── P1-2: Stage 3 真相揭示覆盖层      (30 min)
  └── P2-1: 恶人结局                    (45 min)
  └── P2-3: 中立结局                    (30 min)
  └── P2-4: 通关统计面板                (45 min)

Phase 5: Boss 战（最大的独立工作）
  └── P2-2: 善人结局 + Boss 战场景      (3-4 hr)
  │   ├── 巨兽苏醒叙事覆盖层
  │   ├── Boss 战斗逻辑
  │   └── 善人结局覆盖层

Phase 6: 氛围增强（可选）
  └── P3-1: 星辰矿脉动效果              (20 min)
  └── P3-3: 花店眼泪特效                (15 min)
  └── P3-4: 送礼教学                    (15 min)
```

---

## 五、需要新增的文件清单

| 文件路径 | 用途 | Phase |
|---------|------|-------|
| `scenes/mine/deep_mine.tscn` | 深层矿场景 | Phase 3 |
| `scenes/mine/boss_arena.tscn` | Boss 战场景 | Phase 5 |
| `scripts/mine/boss_battle.gd` | Boss 战斗逻辑 | Phase 5 |
| `scripts/ui/ending_stats.gd` | 通关统计面板脚本 | Phase 4 |
| `scenes/ui/ending_stats.tscn` | 通关统计面板场景 | Phase 4 |

---

## 六、需要修改的现有文件清单

| 文件路径 | 改动 | Phase |
|---------|------|-------|
| `scripts/core/morality_tracker.gd` | 新增 `_shown_first_dialogues` + `has_shown_first_dialogue` + `mark_first_dialogue_shown` + `stage_changed` signal | Phase 1 |
| `scripts/core/game_runtime.gd` | 新增 `deep_mine_tickets` 计数器 | Phase 3 |
| `scripts/town/mining_town_scene.gd` | B1/B2 对话修复、P0-1 stage通知、P0-2 花店眼泪、P0-3 铁匠锁票、P1-2 真相揭示、P2-1/2/3 结局、P3 氛围 | All phases |
