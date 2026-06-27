# 「别按那个键」Day 1-4 开发功能总结

> 开发周期：2026-06-27
> 项目：别按那个键 (Don't Press That Key) — Godot 4.x 2D 挖矿叙事游戏

---

## Day 1：星辰矿系统 + 善恶追踪基础

**目标**：实现核心物品星尘矿（Star Crystal）的特殊掉落机制与道德选择追踪器。

### 完成功能

| 序号 | 功能 | 详情 |
|------|------|------|
| 1.1 | 星辰矿原石 | `raw_star_geode`（温暖原石），独立 3% 爆率从任何挖矿中掉落，不受矿石等级影响 |
| 1.2 | 星尘水晶 | `star_crystal`，鉴定星辰原石后获得。描述为「散发着微弱温热的晶体，仿佛有生命在其中呼吸」 |
| 1.3 | L4 原石移除 | 删除 `raw_anomalous_geode`（异常原石），只保留 3 级原石 + 星辰原石独立掉落 |
| 1.4 | 道德追踪器 | `scripts/core/morality_tracker.gd` — 记录 `sold_star_count` / `gifted_star_count`，判定 `current_alignment`（evil / good / neutral），计算 `get_narrative_stage()`（0-3） |
| 1.5 | 鉴定表更新 | 所有鉴定表（common/fine/rare/star）支持正确概率出货星尘水晶 |
| 1.6 | 场景更新 | `gem_star.tscn` 新场景（星尘矿视觉）；`small_mine.tscn` / `deep_mine.tscn` 移除 L4、加入星尘矿 |

### 关键文件

| 文件 | 类型 | 说明 |
|------|------|------|
| `scripts/core/morality_tracker.gd` | 新增 | 道德追踪 RefCounted |
| `data/game/catalog.json` | 修改 | +star_crystal/+raw_star_geode/-raw_anomalous_geode |
| `scripts/mine/mine_stats.gd` | 修改 | 星尘原石 3% 掉落逻辑 |
| `scripts/items/gem_controller.gd` | 修改 | gem_level=4 → raw_star_geode 映射 |
| `scenes/mine/gems/gem_star.tscn` | 新增 | 星尘矿场景 |
| `scripts/core/game_runtime.gd` | 修改 | 注册 morality_tracker |

---

## Day 2：小镇稳定度 + 昼夜循环 + HUD

**目标**：稳定度成为全游戏压力源；昼夜循环成为每日节奏控制器。

### 完成功能

| 序号 | 功能 | 详情 |
|------|------|------|
| 2.1 | 稳定度系统 | `scripts/core/stability_system.gd` 注册为 autoload。stability 0-100，初始 70。每日自然衰减 3。卖出星辰矿 -15，赠予星辰矿 +15，赠予普通矿 +2 |
| 2.2 | 稳定度影响敌人 | `enemy_ai.gd` 通过 `get_detection_range_multiplier()` / `get_noise_threshold_multiplier()` 动态修改敌人探测范围与噪声阈值 |
| 2.3 | 昼夜循环 | `scripts/core/day_night_cycle.gd` 注册为 autoload。每次矿洞返回 → 夜晚。夜晚结束后 → 新天（稳定度衰减触发）。夜晚矿洞入口关闭 |
| 2.4 | 每日下矿限制 | 每天最多下矿 **3 次**。剩余次数在 HUD 显示。配额用完才强制入夜 |
| 2.5 | HUD 面板 | 左侧中面板：稳定度彩色条（红→黄→绿）+ 数值标签 + 善恶追踪（售出/赠予星辰矿计数） |
| 2.6 | 夜晚效果 | `_night_overlay`（ColorRect）黑色半透明遮罩覆盖全屏，白天与夜晚视觉差异明显 |
| 2.7 | 小镇色调 | `_apply_town_tint()` 根据稳定度调整场景 modulate（低→暗沉偏冷，高→暖亮） |

### 关键文件

| 文件 | 类型 | 说明 |
|------|------|------|
| `scripts/core/stability_system.gd` | 新增 | 稳定度 autoload |
| `scripts/core/day_night_cycle.gd` | 新增 | 昼夜循环 autoload |
| `scripts/town/mining_town_scene.gd` | 大规模重写 | HUD 重构 + 夜晚逻辑 + 稳定度显示 + 善恶显示 |
| `scripts/enemies/enemy_ai.gd` | 修改 | 读取稳定度系数调整行为 |
| `project.godot` | 修改 | 注册 StabilitySystem / DayNightCycle autoload |

---

## Day 3：叙事 NPC + 好感度 + 对话系统

**目标**：功能性 NPC 升级为有血有肉的叙事角色，建立好感度与阶段对话推进系统。

### 完成功能

| 序号 | 功能 | 详情 |
|------|------|------|
| 3.1 | 叙事 NPC 替换 | 4 个 NPC 从 miner/buyer/identifier/task_clerk → 「铁匠青年」「花店少女」「商人」「守夜老人」。每个 NPC 保留原有功能 |
| 3.2 | 好感度系统 | `scripts/narrative/npc_affection.gd`（RefCounted）。每个 NPC affection 0-100。送礼 +1/+3/+5（普通/稀有/星辰）。每人每日限 1 次，夜晚重置 |
| 3.3 | 阶段对话表 | `data/narrative/dialogues.json`：4 个 NPC × 4 个叙事阶段（0-3），每阶段含 first / daily / evil / good 对话行 |
| 3.4 | 对话 UI | `scripts/narrative/dialogue_ui.gd`（CanvasLayer）。NPC 立绘 + 名称 + 逐字打字效果。按 E 前进，最后一条按 E 或 Esc 关闭 |
| 3.5 | 深层入场券 | 铁匠在累计浅层挖矿 ≥5 次后解锁「购买深层入场券」（500 铜板）按钮 |
| 3.6 | 送礼系统 | 花店少女「赠送礼物」按钮：从仓库选矿物赠送，触发好感度+稳定度变化 |
| 3.7 | 星尘矿善恶处理 | 出售星辰矿调用 `stability.penalize_sell()`，赠予星辰矿调用 `stability.reward_gift_star()` |

### 关键文件

| 文件 | 类型 | 说明 |
|------|------|------|
| `scripts/narrative/npc_affection.gd` | 新增 | 好感度 RefCounted |
| `scripts/narrative/dialogue_ui.gd` | 新增 | 对话 UI CanvasLayer |
| `data/narrative/dialogues.json` | 新增 | NPC 阶段对话数据 |
| `scripts/town/town_npc_interactor.gd` | 修改 | NPC ID 重命名 + 守夜老人新增 |
| `scripts/town/mining_town_scene.gd` | 大规模修改 | NPC 交互重构、对话触发、送礼、独立公告板 |
| `scripts/core/game_runtime.gd` | 修改 | 注册 npc_affection |

---

## Day 4：善恶双线深度 + 经济系统补完

**目标**：专属装备区分路线体验，精炼、夜店、每日任务补完经济深度。

### 完成功能

| 序号 | 功能 | 详情 |
|------|------|------|
| 4.1 | 善恶专属装备 | **恶人线**（售出星辰矿 ≥2 后铁匠商店解锁）：贪欲镐（降噪 20% + 稀有掉落 +15%）、血肉护符（减伤 25%）、负重囊（负重惩罚减半）。**善人线**（赠予星辰矿 ≥2 且好感度 ≥50 后花店少女回赠）：静心石（掩体 2s 自动清仇恨）、回溯碎片（矿洞死亡保留背包，一次性消耗）、共情光环（天生降噪 10% + 行走噪声减半） |
| 4.2 | 基础装备升级 | 降噪镐 L1/L2/L3（-15/30/50% 挖矿噪声）、扩容背包 L1/L2/L3（+4/8/12 热栏格）、精准护符 L1/L2/L3（QTE 成功区 +8/16/25°） |
| 4.3 | 每日任务刷新 | `catalog.json` 新增 6 条每日任务模板（铜矿订单、铁匠急单、银链、水晶收藏、杂货单、贪欲荣光）。`task_service.refresh_daily_tasks()` 每次夜晚结束随机抽 3 条启用 |
| 4.4 | 矿石精炼系统 | `scripts/town/refine_workstation.gd` — 独立可交互物体（坐标 900,500）。消耗铜板（30/80/200）精炼矿物 → 售价 ×2 + 送礼效果 ×2 |
| 4.5 | 自营小店 | 商人 NPC 夜晚弹出「开店」按钮，随机刷 1 位夜客（Lux / Ven / Iria），匹配偏好标签溢价卖出（1.35-1.55x） |
| 4.6 | 装备效果接入 | `enemy_ai.gd` 读取装备伤害减免；`move_controller.gd` 读取装备降噪 + 行走降噪。花店少女自动赠予检查 |
| 4.7 | 精灵占位策略 | 所有无 PNG 精灵的装备/物体以文字标签（如「贪欲镐」「精炼台」）代替，不依赖美术资源 |

### 关键文件

| 文件 | 类型 | 说明 |
|------|------|------|
| `data/equipment/equipment.json` | 新增 | 15 件装备数据定义 |
| `scripts/player/equipment_system.gd` | 新增 | 装备管理 RefCounted |
| `scripts/town/refine_workstation.gd` | 新增 | 精炼台交互物体 |
| `data/game/catalog.json` | 修改 | +6 条每日任务 + 3 位夜客 |
| `scripts/core/game_catalog.gd` | 修改 | `get_tasks_for_pool()` + `get_night_customers()` |
| `scripts/economy/task_service.gd` | 修改 | `refresh_daily_tasks()` 方法 |
| `scripts/town/mining_town_scene.gd` | 大规模修改 | 装备商店 + 精炼台 + 夜店 + 花店回赠 |
| `scripts/enemies/enemy_ai.gd` | 修改 | 装备伤害减免接入 |
| `scripts/player/move_controller.gd` | 修改 | 装备降噪系数接入 |

---

## 文件变更统计

### 按 Day 分布

| Day | 新增文件 | 修改文件 | 核心产出 |
|-----|---------|---------|---------|
| 1 | 2 | 6 | 星尘矿掉落 + 善恶追踪器 |
| 2 | 2 | 3 | 稳定度 + 昼夜循环 + HUD |
| 3 | 3 | 4 | 叙事 NPC + 好感度 + 对话 UI |
| 4 | 3 | 8 | 装备系统 + 精炼 + 夜店 + 每日任务 |

### 总计

- **新增文件**：10 个
- **修改文件**：21 个
- **测试用例**：11 个（Day 1: 4 / Day 2: 4 / Day 3: 3 / Day 4: 4）

---

## 当前全局系统一览

### Autoload 单例（9 个）

| Autoload | 文件 | 职责 |
|----------|------|------|
| `GameRuntime` | `scripts/core/game_runtime.gd` | 全局运行时：目录、钱包、热栏、仓库、交易服务、道德追踪、好感度、装备 |
| `NoiseSystem` | `scripts/core/noise_system.gd` | 噪声事件广播 |
| `OxygenSystem` | `scripts/core/oxygen_system.gd` | 矿洞氧气消耗 |
| `WeightSystem` | `scripts/core/weight_system.gd` | 负重层级与惩罚 |
| `ItemDatabase` | `scripts/items/item_database.gd` | 物品图标/堆叠/名称查询 |
| `StabilitySystem` | `scripts/core/stability_system.gd` | 小镇稳定度 0-100 |
| `DayNightCycle` | `scripts/core/day_night_cycle.gd` | 昼夜循环 + 每日下矿限制 |
| `MCPScreenshot` / `MCPInputService` / `MCPGameInspector` | `addons/godot_mcp/` | MCP 编辑器辅助 |

---

## 下一阶段 (Day 5-6)

| Day | 目标 |
|-----|------|
| Day 5 | 三结局（恶人/善人 Boss 战/中立）+ 通关统计面板 |
| Day 6 | 打磨：矿鉴、NPC 神态、音效、UI 动效、平衡、测试全覆盖 |

---

*文档生成日期：2026-06-27*
