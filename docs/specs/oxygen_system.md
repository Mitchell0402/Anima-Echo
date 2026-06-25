# Oxygen System

Status: Draft / Planning
Last updated: 2026-06-25

## Goal

引入随身氧气槽（tank），让玩家在矿洞中的每一个决策——挖矿、探索、躲藏、逃命——都付出氧气代价。氧气耗尽后渐进扣血，致死则结束当前矿洞 run，清空背包并强制回城。

## Scope

- In scope:
  - `OxygenSystem` autoload：固定容量槽（可配置），实时消耗/恢复速率由 BaseRate × StateMultiplier × WeightMultiplier 计算。
  - 消耗因子：静止/慢走=基数，跑步=加速消耗，挖矿=最大消耗，躲藏=减缓消耗但非零。
  - `WeightSystem.get_oxygen_multiplier()` 已预留接口，直接接入：Light=1.0, Heavy=1.3, Overload=1.7。
  - 氧气耗尽后渐进扣血：O₂=0 时每秒扣除可配置的 HP，直到 O₂ 恢复 > 0 或死亡。
  - 致死回城：`player.die()` 触发时 → 如果当前场景是矿洞 → 清空 `GameRuntime.inventory` → 切回 `mining_town.tscn`。
  - `OxygenPump` 交互场景节点：可互动、一次性、按 E 恢复满氧气。当前默认在 `test_scene.tscn` 中放置 1 个。
  - `OxygenBar` UI 控件：进度条 + 百分比文字 + 颜色渐变（蓝→黄→红）+ 低氧气警告特效（闪烁/边缘红晕）。
  - `OxygenSystem` 注册为 autoload，紧接 `WeightSystem` 之后。
- Out of scope:
  - 矿洞内多个氧气泵的生成算法或随机分布逻辑。
  - 不同矿洞地图的氧气容量差异化配置。
  - 氧气恢复宝石/果实（备用物品）。
  - 多人/联机氧气机制。
  - 回城时背包物品保留或部分保留——本次一律全部清空。

## Acceptance Criteria

- [ ] 进入矿洞时氧气槽满格，退出矿洞时氧气系统重置。
- [ ] 挖矿时氧气消耗速度为跑步的约 1.5×，静止/慢走为基数 1×，躲藏中为基数 0.5×。
- [ ] 背包重量 Heavy/Overload 时氧气消耗正确乘以 1.3/1.7。
- [ ] 挖矿全程氧气按最大倍率消耗，QTE 成功不提供氧气奖励。
- [ ] 氧气归零后每秒扣血（默认 8 HP/s），直至死亡或氧气恢复。
- [ ] 死亡后 `GameRuntime.inventory.clear()`，场景切换到 `mining_town.tscn`。
- [ ] OxygenPump 靠近后按 E 交互，氧气回满、泵消失，仅可用一次。
- [ ] OxygenBar 在矿洞内显示于玩家头顶（或 HUD 角落），实时反映氧气状态。
- [ ] 低氧气（<25%）时 UI 颜色变红并闪烁。
- [ ] 现有玩法路线（town/mine 切换、enemy AI、挖矿 QTE、Cover 躲藏）不受破坏。
- [ ] `WeightSystem.get_oxygen_multiplier()` 已有接口工作正常。

## Relevant Files

| File | Change |
|------|--------|
| `project.godot` | 新增 `OxygenSystem` autoload，排在 `WeightSystem` 之后 |
| `scripts/core/oxygen_system.gd` | **新建**：氧气消耗/恢复核心逻辑、tank 容量管理、扣血驱动 |
| `scripts/core/weight_system.gd` | 零改动（`get_oxygen_multiplier()` 已存在即可） |
| `scripts/player/player.gd` | 新增 `State.SUFFOCATING`（O₂=0 扣血时的中间状态），`die()` 触发回城逻辑 |
| `scripts/player/move_controller.gd` | 每帧告知 OxygenSystem 当前活动类型（idle/walk/run/mining/hidden） |
| `scripts/player/player_stats.gd` | 零改动（已有 speed_multiplier 模式，氧气不需要在此处理） |
| `scripts/mine/mine_interaction.gd` | 零改动（挖矿状态已通过 player state 反映给 OxygenSystem） |
| `scripts/mine/cover.gd` | 零改动（HIDDEN 状态已通过 player state 反映） |
| `scripts/town/mine_exit.gd` | 零改动（现有 exit 逻辑不涉及氧气，正常回城保留背包；仅死亡路径清空背包） |
| `scenes/mine/oxygen_pump.tscn` | **新建**：氧气泵场景节点 |
| `scripts/mine/oxygen_pump.gd` | **新建**：氧气泵交互逻辑（Area2D + interact 恢复氧气 + 自毁） |
| `scenes/mine/test_scene.tscn` | 放置 1 个 OxygenPump 实例 |
| `scripts/ui/oxygen_bar.gd` | **新建**：氧气条 UI 控件 |
| `scenes/mine/main_character_stats.tscn` | 添加 OxygenBar 子节点 |
| `scripts/core/game_runtime.gd` | 可能需要暴露 `inventory.clear()` 方法（当前已是 public member，直接调即可） |
| `data/game/catalog.json` | 零改动（氧气不依赖 catalog） |
| `tests/project/run_all.gd` | 新增氧气系统的回归测试 |
| `docs/current_tasks.md` | 更新任务状态 |
| `docs/architecture.md` | 更新 autoload 列表和氧气模块说明 |
| `docs/glossary.md` | 新增 `OxygenSystem`、`OxygenPump`、`OxygenBar` 术语 |

## Architecture Design

### 消耗率模型

```
effective_rate = base_rate × state_multiplier × weight_multiplier
```

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `tank_capacity` | 100.0 | 满槽氧气量 |
| `base_rate` | 3.0 /s | 静止时的基准消耗 |
| `state_multiplier` | 见下表 | 根据玩家状态动态切换 |
| `weight_multiplier` | 1.0 / 1.3 / 1.7 | 来自 `WeightSystem.get_oxygen_multiplier()` |

| 玩家状态 | multiplier | 设计意图 |
|----------|-----------|---------|
| IDLE / WALK (free, 未移动) | 1.0× | 什么都不做也在消耗——创造紧迫感 |
| RUN (free, 跑步) | 2.0× | 逃跑有代价，不能无限风筝敌人 |
| MINING | 3.0× | 核心 tradeoff——挖矿最贵，每块矿都在烧氧 |
| HIDDEN | 0.5× | 掩体提供"喘气"窗口，但仍然在消耗，不能无限躲 |
| SUFFOCATING (O₂=0) | 0× | 已耗尽就不继续扣氧气了，改为扣血 |

### 渐进扣血

- O₂ 归零后进入 SUFFOCATING 阶段。
- 每秒扣除 `suffocation_dps`（默认 8 HP），由 `OxygenSystem._process` 驱动。
- O₂ 恢复 > 0（例如碰触氧气泵）→ 立即停止扣血，回到正常消耗。
- HP 归零 → 触发 `player.die()`。

### 致死回城

`player.die()` 新增逻辑：

```
if current scene is mine scene:
    GameRuntime.inventory.clear()   # 清空背包
    get_tree().change_scene_to_file("mining_town.tscn")
```

玩家状态在回城后 `_ready()` 会 reset health 到 max，进入 FREE 状态。

### 氧气泵 (OxygenPump)

- Area2D + Sprite2D + 交互脚本。
- 放入 `"interactables"` group（或用 player group 检测）。
- 按 E → `tank = tank_capacity`（回满）→ `queue_free()`。
- `@export var one_shot: bool = true`，可配置是否为一次性。

### UI: OxygenBar

- 挂在 `main_character_stats.tscn` 下，类似 HealthBar/WeightBar 的 Node2D 控件。
- 进度条：
  - > 50%：蓝色渐变
  - 25-50%：黄色
  - < 25%：红色 + 闪烁（通过 modulate alpha 脉冲）
- 文本：`"O₂: 73%"`。

### Autoload 注册顺序

```
NoiseSystem → ItemDatabase → GameRuntime → WeightSystem → OxygenSystem → MCP*
```

`OxygenSystem` 在 `_ready()` 中获取 `WeightSystem`，不依赖 `GameRuntime` 直接初始化（只通过 `WeightSystem` 间接获取重量倍率，重量变化通过信号通知）。

状态感知：`OxygenSystem` 通过每帧由 `move_controller`、`mine_interaction`、`cover` 调用 `set_player_state(state)` 方法获知当前状态。

### 状态传递方案

不采用 `OxygenSystem` 直接轮询 player 状态的方案（会产生依赖顺序耦合）。改为**推送式**：

- `OxygenSystem.set_player_activity(activity: String)` — 由各子系统在状态变化时调用。
- 也可由 `move_controller._physics_process` 每帧调用，类似噪音系统的模式。
- 简单方案：`OxygenSystem` 读取 player 的 `state` 枚举值，因为 `player.gd` 的 state 已是公开变量。`OxygenSystem` 在 `_process` 中自己轮询 player state 变化。
  - 这需要缓存 player 引用（`get_tree().get_first_node_in_group("player")`），只读不写，安全。

## Risks

1. **Autoload 顺序**：`OxygenSystem` 必须在 `WeightSystem` 之后、`GameRuntime` 之后（因为死亡回城需要 `GameRuntime.inventory.clear()`）。当前顺序已满足。
2. **SUFFOCATING 状态与 HURT 状态的关系**：两者可能同时触发（敌人攻击 + O₂ 耗尽）。`player.take_hit()` 和 `player.take_damage()` 已处理 HURT/DEAD 状态保护。SUFFOCATING 由 `OxygenSystem` 调用 `player.take_damage()`，走现有伤害路径，不会冲突。
3. **场景切换时 OxygenSystem 状态重置**：`OxygenSystem` 需要判断当前场景是否为矿洞（通过 `is_mine_scene()` 方法，检查 scene path 或 scene group）。进入矿洞时重置 tank，离开时停止消耗。
4. **现有 test 兼容**：`tests/project/run_all.gd` 中有 mine scene structure 检查、economy loop 检查。氧气系统新增后需要补充测试，但不应破坏已有测试。

## Verification

- Automated: 在 `tests/project/run_all.gd` 中新增氧气系统的 unit test（autoload 存在性、capacity 正确、消耗率计算、clear 逻辑）。
- Manual:
  1. 进入矿洞，站着不动 10s，观察氧气条缓慢下降。
  2. 跑动数秒，观察下降加速。
  3. 挖矿过程中观察氧气快速消耗，QTE 期间同等速度持续消耗。
  4. 进入掩体，观察消耗减缓。
  5. 耗尽氧气后观察 HP 开始下降。
  6. HP 归零后确认回城、背包清空。
  7. 使用氧气泵，确认回满且泵消失。
  8. 正常通过 MinecartExit 回城，确认背包保留。
