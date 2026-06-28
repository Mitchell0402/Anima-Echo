# NPC 好感系统 & 委托任务

Status: Implemented  
Last updated: 2026-06-28

本文档记录 NPC 好感系统（v2.0）的完整设计和实现细节，供后续 agent 参考。

---

## 一、好感系统核心

### 文件

- `scripts/narrative/npc_affection.gd` — 核心引擎（RefCounted，由 GameRuntime 持有）
- `scripts/town/mining_town_scene.gd` — 送礼入口、对话语气、阈值 toast、HUD 面板
- `scripts/narrative/dialogue_ui.gd` — 对话 UI（无好感条，好感显示在城镇 HUD 右下角）
- `scripts/economy/task_service.gd` — NPC 委托任务刷新逻辑
- `data/game/catalog.json` — NPC 委托任务定义（12 个）

### 四个 NPC

| ID | 名称 | 关键文件 |
|----|------|---------|
| `elder` | 守夜老人 | 知识线 |
| `blacksmith` | 铁匠青年 | 装备线 |
| `florist` | 花店少女 | 情感线 |
| `buyer` | 商人 | 经济线（纯功能 NPC，局外人） |

### 数值参数

| 参数 | 值 |
|------|-----|
| 好感范围 | 0~100 |
| 普通矿送礼 | +1 |
| 稀有/偏好矿送礼 | +5 |
| 星辰矿送礼 | +5 |
| 每日送礼限制 | 每个 NPC 每天 1 次（`_gifted_today` 追踪，睡眠时 reset） |
| NPC 委托任务奖励 | +10 / +15 / +20（分别对应 tier 1/2/3） |

### 到 50 好感的天数预估

| 路径 | 天数 |
|------|------|
| 纯送普通矿 | 50 天 |
| 送偏好矿 (+5/day) | 10 天 |
| 偏好矿 + tier 1 委托 | ~8 天 |

---

## 二、送礼系统

### 所有 4 个 NPC 均支持送礼

`_open_popup()` 中每个 NPC 都有「赠送礼物」按钮。`_open_gift_picker()` 使用 `_popup_npc_id` 确定当前交互的 NPC。

### 送礼流程

```
玩家靠近 NPC → 按 E → _open_popup(npc_id) → 点击「赠送礼物」
  → _open_gift_picker() → 显示仓库中所有 mineral 类物品
  → 选择矿物 → _do_gift(item_id) → 检查 can_gift_today(npc_id)
  → _perform_gift(item_id) → warehouse.remove → affection.gift(npc_id, rarity)
  → toast "已赠送！xx好感度 xx/100"
```

### 特殊剧情：花店少女首颗星辰矿

仅当 `item_id == "star_crystal" && npc_id == "florist" && 首次` 时触发眼泪叙事对话（三行旁白），对话结束后才执行 `_perform_gift`。

### 花店少女装备回赠

仅当 `npc_id == "florist"` 且 `gifted_star_count >= 2 && affection >= 50` 时触发（`_check_florist_reward()`）。

---

## 三、好感度展示

### 城镇 HUD 右下角面板

固定显示四个 NPC 的好感值：

```
◆ 好感度
老人 32  铁匠 18
少女 45  商人 10
```

- 实现在 `_build_ui()` 中（紫色 VBoxContainer，`PRESET_BOTTOM_RIGHT`）
- 通过 `_update_affection_display()` 更新，`_refresh_hud()` 每次调用时自动刷新
- 涉及文件：`mining_town_scene.gd` 中 `_affection_label` 字段 + `_update_affection_display()` 方法

### 对话语气旁白

在 `_talk_npc()` 中，根据好感值在对话第一行插入语气旁白：

| 好感 | 旁白 |
|------|------|
| 0~19 | 无（陌生人） |
| 20~49 | （xx朝你点了点头。） |
| 50~79 | （xx微笑着开口。） |
| 80~100 | （xx看着你，眼中满是信任。） |

---

## 四、阈值信号与事件

### signal: `threshold_reached(npc_id, threshold)`

在 `npc_affection.gd` 中定义，由 `gift()` 和 `modify_affection()` 在突破 20/50/80 时发射。

### 连接点

`mining_town_scene._ready()` → `_connect_affection_signal()` → `affection.threshold_reached.connect(_on_affection_threshold)`

### 阈值处理

| 阈值 | 行为 |
|------|------|
| 20 | toast: 「xx对你的态度温和了一些。明天或许会有事找你帮忙。」 |
| 50 | toast: 「xx与你成为了挚友。」 + 发射 `affection_milestone_50` 事件（推进 story task） |
| 80 | 暂无特殊 toast（后续可扩展） |

---

## 五、NPC 委托任务

### 任务类型

第三类任务 flag `"npc"`，独立于 story/daily。

| 属性 | 行为 |
|------|------|
| 存活周期 | 持久不消失（直到完成） |
| 每日数量 | 每个 NPC 每天最多 1 个活跃 |
| 刷新时机 | `_end_night()` 调用 `task_service.refresh_npc_tasks(affection)` |
| 解锁条件 | 好感 >= `affection_required`，且该 NPC 当前无活跃委托，且所有更低 tier 已完成 |

### 12 个委托任务

#### 守夜老人 (elder)

| ID | Tier | 好感要求 | 名称 | 目标 | 好感奖励 | 铜板奖励 |
|----|------|---------|------|------|---------|----------|
| `npc_elder_light` | 1 | 20 | 夜灯 | 交付月光水晶 x1 | +10 | 100 |
| `npc_elder_tale` | 2 | 50 | 往事 | 交付星辰碎片 x1 | +15 | 200 |
| `npc_elder_name` | 3 | 80 | 真名 | 交付星辰矿 x1 | +20 | 500 |

#### 铁匠青年 (blacksmith)

| ID | Tier | 好感要求 | 名称 | 目标 | 好感奖励 | 铜板奖励 |
|----|------|---------|------|------|---------|----------|
| `npc_smith_rush` | 1 | 20 | 急单 | 交付铜块 x5 + 铁片 x3 | +10 | 120 |
| `npc_smith_debt` | 2 | 50 | 舍与得 | 交付银脉 x2 + 金脉 x1 | +15 | 300 |
| `npc_smith_closure` | 3 | 80 | 诀别 | 交付星辰矿 x1 | +20 | 500 |

#### 花店少女 (florist)

| ID | Tier | 好感要求 | 名称 | 目标 | 好感奖励 | 铜板奖励 |
|----|------|---------|------|------|---------|----------|
| `npc_florist_soil` | 1 | 20 | 新土 | 交付水晶花 x3 | +10 | 80 |
| `npc_florist_color` | 2 | 50 | 颜色 | 交付星辰碎片 x1 + 月光水晶 x1 | +15 | 150 |
| `npc_florist_bloom` | 3 | 80 | 花开 | 交付星辰矿 x1 | +20 | 600 |

#### 商人 (buyer)

| ID | Tier | 好感要求 | 名称 | 目标 | 好感奖励 | 铜板奖励 |
|----|------|---------|------|------|---------|----------|
| `npc_buyer_sample` | 1 | 20 | 样品 | 交付水晶花 x1 + 月光水晶 x1 | +10 | 150 |
| `npc_buyer_rare` | 2 | 50 | 珍品 | 交付金脉 x2 + 银脉 x3 | +15 | 300 |
| `npc_buyer_honor` | 3 | 80 | 荣誉 | 交付星辰矿 x1 | +20 | 800 |

### catalog.json 任务结构

每个 NPC 委托任务在 catalog.json 中具有以下额外字段：

```json
{
  "id": "npc_elder_light",
  "name": "夜灯",
  "description": "...",
  "flags": ["npc"],
  "npc_id": "elder",
  "affection_required": 20,
  "tier": 1,
  "objectives": [...],
  "rewards": [...],
  "currency_reward": 100,
  "affection_reward": 10
}
```

### 任务刷新逻辑

`task_service.refresh_npc_tasks(affection)` 在 `_end_night()` 中调用：

1. 扫描所有 `flags: ["npc"]` 任务
2. 跳过该 NPC 已有活跃委托的
3. 跳过好感未达标的
4. 跳过更低 tier 未完成的
5. 对符合条件的任务调用 `accept_task()`

### 任务完成奖励发放

`_deliver_task()` 中，如果任务 flag 包含 `"npc"`：
- 读取 `npc_id` 和 `affection_reward`
- 调用 `affection.modify_affection(npc_id, affection_reward)`
- toast: 「委托完成！xx好感度 +10（当前 xx/100）」

### UI 标签

任务面板中，NPC 委托任务名称后显示 `（委托）`：
- `_refresh_task_panel()` 中通过 `elif "npc" in task_flags: display_name += "（委托）"`
- `_task_objective_label()` 中新增 18 个 NPC 委托 objective ID 的中文映射

---

## 六、近期相关改动（2026-06-28）

### 删除的精炼系统

- `scripts/town/refine_workstation.gd` — 已删除
- `scenes/town/mining_town.tscn` — 删除 RefineStation 节点
- `data/game/catalog.json` — 删除 `story_refine_one` 任务
- `assets/town/buildings/refine_station.png*` — 已删除
- `assets/ui/icons/items/refined_badge.png*` — 已删除

### 已修复的 Bug

- **铜矿任务无法完成**: `deliver_items()` 与 `claim_reward()` 之间 progress key 不一致 + 先扣后查仓库的竞态问题
- **星辰矿无法卖出**: `buyer_jeweler` 预算不足（650 → 已改为 999999，所有 buyer 预算均为 999999）

### 好感系统参数变更

- `GIFT_RARE`: 3 → 5
- 新增 `modify_affection(npc_id, delta)` 方法（用于委托任务奖励）

---

## 七、文件索引

| 文件 | 职责 |
|------|------|
| `scripts/narrative/npc_affection.gd` | 好感核心引擎：gift、modify_affection、信号 |
| `scripts/town/mining_town_scene.gd` | 送礼 UI、对话语气、阈值 toast、好感面板 `_update_affection_display()` |
| `scripts/economy/task_service.gd` | `_is_npc_task()`、`refresh_npc_tasks(affection)` |
| `data/game/catalog.json` | 12 个 NPC 委托任务 + 相关物品定义 |
| `data/narrative/dialogues.json` | 4 个 NPC × 4 个叙事阶段的对话数据 |
| `tests/project/run_all.gd` | `_test_catalog_npc_tasks`、`_test_npc_affection_modify` |
| `docs/current_tasks.md` | 当前所有任务（story/daily/npc）的汇总表 |
| `docs/specs/narrative_design.md` | 完整剧情/世界观设计 |
