extends CharacterBody2D

## 玩家根节点脚本：拥有玩家的高层状态。
## 所有「锁定移动」的需求都通过状态机表达，子系统（移动/挖矿/掩体）查询或修改状态，
## 不再用 set_physics_process(false) 或散落的 meta 标记来跨系统通信。

enum State { FREE, MINING, HIDDEN, HURT, DEAD }

var state: State = State.FREE

# 生命值
@export var max_health: float = 100.0
var current_health: float = 100.0

# 受击击退
var _knockback: Vector2 = Vector2.ZERO
var _hurt_timer: float = 0.0

# 掉落用宝石场景（按等级）
const GEM_SCENES := {
	1: preload("res://scenes/mine/gems/gem_l1.tscn"),
	2: preload("res://scenes/mine/gems/gem_l2.tscn"),
	3: preload("res://scenes/mine/gems/gem_l3.tscn"),
}
const DROP_PICKUP_DELAY: float = 0.9  # 掉落物的免拾取时间，避免立刻飞回

signal damaged(amount: float)
signal health_changed(current: float, maximum: float)
signal died

func _ready() -> void:
	current_health = max_health

func can_move() -> bool:
	return state == State.FREE

func is_mining() -> bool:
	return state == State.MINING

func is_hidden() -> bool:
	return state == State.HIDDEN

func is_hurt() -> bool:
	return state == State.HURT

func is_dead() -> bool:
	return state == State.DEAD

# ---- 挖矿 ----
func enter_mining() -> bool:
	if state != State.FREE:
		return false
	state = State.MINING
	velocity = Vector2.ZERO
	return true

func exit_mining() -> void:
	if state == State.MINING:
		state = State.FREE

# ---- 躲藏 ----
func enter_hidden() -> bool:
	if state != State.FREE:
		return false
	state = State.HIDDEN
	velocity = Vector2.ZERO
	return true

func exit_hidden() -> void:
	if state == State.HIDDEN:
		state = State.FREE

# ---- 受击 / 击退 ----
## 被攻击：躲藏/死亡中免疫；否则打断当前状态进入 HURT，存储击退向量并随机掉落一件物品。
func take_hit(source_pos: Vector2, force: float, duration: float = 0.35) -> void:
	if state == State.HIDDEN or state == State.DEAD:
		return
	state = State.HURT
	_hurt_timer = duration
	var away: Vector2 = (global_position - source_pos)
	if away.length() < 0.01:
		away = Vector2.DOWN
	_knockback = away.normalized() * force
	_drop_random_item()

## 扣血：死亡后免疫；归零触发 die()。
func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return
	current_health = max(0.0, current_health - amount)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	print("[Player] 受到伤害: %.0f | 剩余血量: %.0f/%.0f" % [amount, current_health, max_health])
	if current_health <= 0.0:
		die()

func die() -> void:
	if state == State.DEAD:
		return
	# 结束当前挖矿，再置死亡冻结
	if state == State.MINING:
		state = State.FREE
	state = State.DEAD
	velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	# Drop the hotbar on death. The warehouse is untouched — only the
	# in-mine backpack is lost, matching the Tarkov-style "you take it
	# back to town or you lose it" rule.
	var runtime: Node = get_node_or_null("/root/GameRuntime")
	if runtime != null and runtime.has_method("on_player_killed_in_mine"):
		runtime.on_player_killed_in_mine()
	died.emit()
	print("[Player] 💀 死亡")

	# 播放死亡动画，延迟后回城
	_play_death_animation()
	get_tree().create_timer(1.8).timeout.connect(_on_death_transition)


func _play_death_animation() -> void:
	var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
	if sprite == null or sprite.sprite_frames == null:
		return
	var dir: String = "f"
	var current: String = sprite.animation
	var parts: PackedStringArray = current.split("_")
	if parts.size() >= 2:
		dir = parts[-1]
	var death_anim: String = "death_" + dir
	if sprite.sprite_frames.has_animation(death_anim):
		sprite.play(death_anim)


func _on_death_transition() -> void:
	var oxygen: Node = get_node_or_null("/root/OxygenSystem")
	if oxygen and oxygen.has_method("is_in_mine_scene") and oxygen.is_in_mine_scene():
		var runtime: Node = get_node_or_null("/root/GameRuntime")
		if runtime and runtime.get("inventory") and runtime.get("inventory").has_method("clear"):
			runtime.get("inventory").clear()
			print("[Player] 背包已清空，返回城镇")
		get_tree().change_scene_to_file("res://scenes/town/mining_town.tscn")

## 由移动控制器每帧驱动：返回当前击退速度；衰减并在计时结束后回到 FREE。
## 返回 true 表示仍在受击中。死亡时立即结束受击驱动。
func tick_hurt(delta: float, decel: float) -> bool:
	if state == State.DEAD:
		_knockback = Vector2.ZERO
		return false
	_knockback = _knockback.move_toward(Vector2.ZERO, decel * delta)
	_hurt_timer -= delta
	if _hurt_timer <= 0.0:
		_knockback = Vector2.ZERO
		if state == State.HURT:
			state = State.FREE
		return false
	return true

# ---- 受击随机掉落（惩罚）----
func _drop_random_item() -> void:
	var inv: Node = get_node_or_null("InventoryManager")
	if inv == null or not inv.has_method("take_random_item_for_drop"):
		return
	var item: Dictionary = inv.take_random_item_for_drop()
	if item.is_empty():
		return
	var type: String = item.get("type", "")
	var data: Dictionary = (item.get("data", {}) as Dictionary).duplicate()
	_spawn_dropped_item(type, data)

func _spawn_dropped_item(type: String, data: Dictionary) -> void:
	if type != "gem":
		return
	var level: int = int(data.get("level", 1))
	var scene: PackedScene = GEM_SCENES.get(level, GEM_SCENES[1])
	if scene == null:
		return
	var gem: Node = scene.instantiate()
	# 必须在 add_child（触发 _ready）之前设置，pickup_delay 才能生效
	if "gem_value" in gem:
		gem.gem_value = int(data.get("value", 1))
	if "pickup_delay" in gem:
		gem.pickup_delay = DROP_PICKUP_DELAY
	get_parent().add_child(gem)
	gem.global_position = global_position + Vector2(0, -20)
	if gem.has_method("launch"):
		gem.launch(Vector2(randf_range(-120, 120), randf_range(-60, -20)))
	print("[Player] 掉落物品: %s L%d" % [type, level])

func hurt_velocity() -> Vector2:
	return _knockback

## 兜底：任何情况下强制解除锁定（例如异常恢复）
func force_free() -> void:
	state = State.FREE
	_knockback = Vector2.ZERO
