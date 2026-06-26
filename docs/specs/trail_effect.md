# Trail Effect — 角色移动拖尾特效

**状态：** 已实现  
**创建日期：** 2026-06-26

## 目标

在矿洞场景（test_scene）中，为角色移动添加由紫色小星星和紫色雾气组成的拖尾特效。角色移动时产生特效，停止移动时特效消失。

## 范围

- 为 MainCharacter 添加可复用的 `TrailEffect` 节点
- 特效由两套 GPU 粒子系统组成：雾气（mist）和星星（star）
- 粒子纹理在代码中程序化生成，不依赖外部图片文件
- 通过 `MoveController` 根据玩家输入状态驱动粒子的启停

## 非目标

- 不涉及矿洞以外场景的特效（但设计为可复用）
- 不涉及其他角色的拖尾（敌人、NPC 等）
- 不涉及受伤、挖矿状态的特效变化
- 不涉及粒子纹理的外部图片资产

## 验收标准

1. 在矿洞场景中按住方向键移动角色时，角色身后出现紫色拖尾
   - 可见半透明的紫色圆形雾气粒子（大而软，向上飘升后快速消散）
   - 可见亮紫色的小星星粒子（四角星形，带旋转闪烁效果）
2. 松开方向键时，拖尾立即停止发射；已发射的粒子自然消散
3. 角色被击退（HURT 状态）、死亡（DEAD）、挖矿（MINING）、躲藏（HIDDEN）时不产生拖尾
4. 在 Godot 编辑器中运行 `test_scene` 可直观验证效果

## 受影响文件

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `scripts/player/trail_effect.gd` | 新建 | TrailEffect 节点脚本，程序化生成纹理并创建两个 GPUParticles2D |
| `scripts/player/move_controller.gd` | 修改 | 添加 `_trail` 引用和 `_start_trail()`/`_stop_trail()` 调用 |
| `scenes/mine/main_character_stats.tscn` | 修改 | 将 TrailEffect 节点添加为 MainCharacter 的子节点 |

## 粒子参数

### 雾气（Mist Particles）

| 参数 | 值 | 说明 |
|------|----|------|
| amount | 20 | 每帧最大粒子数 |
| lifetime | 0.45s | 生命周期 |
| size | 4–14 px | 尺寸范围（从大缩小到小，营造消散感） |
| spread | 120° | 全向散布 |
| gravity | (0, -25) | 向上飘升 |
| initial velocity | 10–35 | 初始速度 |
| color | Color(0.55, 0.15, 0.85, 0.55) → 透明 | 紫色半透明快速淡出 |
| texture | 64×64 径向渐变圆 | 程序化生成，软边缘 |

### 星星（Star Particles）

| 参数 | 值 | 说明 |
|------|----|------|
| amount | 6 | 每帧最大粒子数 |
| lifetime | 0.55s | 生命周期 |
| size | 2–6 px | 尺寸范围 |
| spread | 150° | 全向散布 |
| gravity | (0, -15) | 轻微上飘 |
| initial velocity | 20–50 | 初始速度 |
| color | Color(0.8, 0.35, 1.0, 0.9) → 亮白透明 | 紫色闪烁淡出 |
| texture | 32×32 四角星形 | 程序化生成 |
| animation | min 0.5, max 2.0 | 随机旋转速度 |
| anim initial velocity | 0–1 | 初始旋转相位随机 |

## 设计决策

### 使用 GPUParticles2D 而非 CPUParticles2D

GPU 粒子可以利用 GPU 并行渲染，对性能影响更小。在粒子数量适中（总量 < 30）的情况下，GPU 粒子是 Godot 4 的推荐方案。

### 程序化纹理生成

雾气和星星的纹理在 `TrailEffect._ready()` 中通过 `Image.create()` 程序化生成，无需外部 PNG 文件。原因：

1. 纹理简单（径向渐变、星形图案），不需要复杂的设计软件
2. 避免引入额外的资产管理和元数据维护负担
3. 参数（颜色、形状）可以在脚本中通过 `@export` 变量调整

### local_coords = false

粒子在世界空间中发射，不跟随角色移动。这样当角色走过一条路径时，之前发射的粒子留在原地，自然形成拖尾效果。

### MoveController 集成点

拖尾启停逻辑放在 `MoveController._physics_process()` 中：

- **FREE + 有输入**：启动拖尾
- **FREE + 无输入**：停止拖尾
- **HURT / DEAD / MINING / HIDDEN**：停止拖尾

不使用物理速度（`body.velocity`）判断，因为减速滑动时仍可能残留速度，不符合「松手即停」的用户预期。

## 风险

- **低**：场景文件中 `ext_resource` 缺少 UID。新创建的 `trail_effect.gd` 文件尚未被 Godot 编辑器打开，因此没有分配 UID。场景引用使用路径 `res://scripts/player/trail_effect.gd`，编辑器首次打开时会自动分配 UID。不影响功能，但首次打开后编辑器会修改场景文件（添加 UID）。
- **极低**：`class_name TrailEffect` 依赖于脚本被 Godot 解析后才能被 `add_node` MCP 工具识别。由于直接编辑了 `.tscn` 文件，该依赖不构成问题。
