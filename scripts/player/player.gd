extends CharacterBody2D

## 玩家根节点脚本：拥有玩家的高层状态。
## 所有「锁定移动」的需求都通过状态机表达，子系统（移动/挖矿/掩体）查询或修改状态，
## 不再用 set_physics_process(false) 或散落的 meta 标记来跨系统通信。

enum State { FREE, MINING, HIDDEN, HURT, DEAD, ATTACK }

var state: State = State.FREE

# 生命值
@export var max_health: float = 100.0
var current_health: float = 100.0

# 攻击
const ATTACK_COOLDOWN: float = 0.4
const ATTACK_DURATION: float = 0.25
const ATTACK_RANGE: float = 80.0
const ATTACK_ANGLE: float = 120.0
const ATTACK_DAMAGE: float = 12.0
const ATTACK_KNOCKBACK: float = 300.0
const ATTACK_DASH_SPEED: float = 150.0   # 攻击时的冲刺速度
var _attack_cooldown: float = 0.0
var _last_aim_direction: Vector2 = Vector2.DOWN
var _hit_enemies: Array = []  # 当前攻击已命中的敌人，防止重复扣血

# 受击击退 & 无敌
var _knockback: Vector2 = Vector2.ZERO
var _hurt_timer: float = 0.0
const INVINCIBLE_DURATION: float = 0.3
var _invincible_timer: float = 0.0

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
	# 配置攻击检测区域（scene 中已有的 attack_range Area2D）
	var ar: Area2D = get_node_or_null("attack_range")
	if ar:
		ar.collision_layer = 0
		ar.collision_mask = 2   # enemy layer
		ar.monitoring = false
		if not ar.body_entered.is_connected(_on_attack_body_entered):
			ar.body_entered.connect(_on_attack_body_entered)
	# 地牢模式：跨场景恢复血量
	var rt: Node = get_node_or_null("/root/GameRuntime")
	if rt and rt.get("dungeon_current_room") != null:
		current_health = rt.get("dungeon_player_health")
		health_changed.emit(current_health, max_health)

func can_move() -> bool:
	return state == State.FREE

func is_attacking() -> bool:
	return state == State.ATTACK

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
## 被攻击：躲藏/死亡/无敌中免疫；否则打断当前状态进入 HURT，存储击退向量并随机掉落一件物品。
func take_hit(source_pos: Vector2, force: float, duration: float = 0.35) -> void:
	if state == State.HIDDEN or state == State.DEAD:
		return
	if _invincible_timer > 0.0:
		return
	# 被攻击时清除攻击状态
	if state == State.ATTACK:
		_end_attack()
	state = State.HURT
	_hurt_timer = duration
	_invincible_timer = INVINCIBLE_DURATION
	var away: Vector2 = (global_position - source_pos)
	if away.length() < 0.01:
		away = Vector2.DOWN
	_knockback = away.normalized() * force * 1.5
	_drop_random_item()

## 扣血：无敌/死亡中免疫；归零触发 die()。
func take_damage(amount: float) -> void:
	if state == State.DEAD or _invincible_timer > 0.0:
		return
	current_health = max(0.0, current_health - amount)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	print("[Player] 受到伤害: %.0f | 剩余血量: %.0f/%.0f" % [amount, current_health, max_health])
	# 地牢模式：同步血量到 GameRuntime
	var rt: Node = get_node_or_null("/root/GameRuntime")
	if rt and rt.get("dungeon_current_room") != null:
		rt.set("dungeon_player_health", current_health)
	if current_health <= 0.0:
		die()

func die() -> void:
	if state == State.DEAD:
		return
	# 结束当前挖矿/攻击，再置死亡冻结
	if state == State.MINING or state == State.ATTACK:
		_end_attack()
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
	var scene_path: String = get_tree().current_scene.scene_file_path
	if scene_path.ends_with("test_scene.tscn") or scene_path.ends_with("dungeon_room.tscn"):
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


# ---- 攻击系统 ----

func _process(delta: float) -> void:
	# 攻击冷却（无论当前状态都递减）
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta

	# 无敌计时
	if _invincible_timer > 0.0:
		_invincible_timer -= delta

	# 记录瞄准方向（玩家最后移动方向）
	var input_dir := Input.get_vector("left", "right", "up", "down")
	if input_dir.length() > 0.1:
		_last_aim_direction = input_dir.normalized()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		if state == State.HIDDEN:
			exit_hidden()
		if state == State.FREE and _attack_cooldown <= 0.0:
			_start_attack()


func _start_attack() -> void:
	state = State.ATTACK
	_attack_cooldown = ATTACK_COOLDOWN
	velocity = _last_aim_direction * ATTACK_DASH_SPEED

	# 动画
	var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
	var has_anim: bool = false
	if sprite:
		var dir: String = "l"
		var angle := _last_aim_direction.angle()
		if angle >= -PI / 4 and angle < PI / 4: dir = "r"
		elif angle >= PI / 4 and angle < 3 * PI / 4: dir = "f"
		elif angle <= -PI / 4 and angle > -3 * PI / 4: dir = "b"
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("attack_" + dir):
			has_anim = true
			if sprite.animation_finished.is_connected(_on_attack_animation_finished):
				sprite.animation_finished.disconnect(_on_attack_animation_finished)
			sprite.animation_finished.connect(_on_attack_animation_finished, CONNECT_ONE_SHOT)
			sprite.play("attack_" + dir)
		else:
			sprite.modulate = Color(1.2, 1.0, 0.8)

	# 没有攻击动画时用 timer 兜底结束
	if not has_anim:
		get_tree().create_timer(ATTACK_DURATION).timeout.connect(_end_attack)

	# 攻击检测：持续整个攻击动画期间
	var ar: Area2D = get_node_or_null("attack_range")
	if ar:
		_hit_enemies.clear()
		ar.position = _last_aim_direction * (ATTACK_RANGE * 0.5)
		ar.monitoring = true


func _on_attack_animation_finished() -> void:
	_end_attack()


func _end_attack() -> void:
	velocity = Vector2.ZERO
	# 关闭攻击检测
	var ar: Area2D = get_node_or_null("attack_range")
	if ar:
		ar.monitoring = false

	var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.modulate = Color.WHITE
	if state == State.ATTACK:
		state = State.FREE
	# 通知移动控制器刷新动画状态
	var mc: Node = get_node_or_null("MoveController")
	if mc and mc.has_method("on_attack_ended"):
		mc.on_attack_ended()


## 攻击动画持续期间，任何敌人进入 attack_range 都会被命中（每刀每个敌人只命中一次）
func _on_attack_body_entered(body: Node2D) -> void:
	if state != State.ATTACK:
		return
	if body == self:
		return
	if _hit_enemies.has(body):
		return
	if not body.has_method("take_damage"):
		return

	# 扇形角度检查
	var to_enemy: Vector2 = (body.global_position - global_position).normalized()
	var angle_diff: float = _last_aim_direction.angle_to(to_enemy)
	if abs(angle_diff) < deg_to_rad(ATTACK_ANGLE / 2.0):
		_hit_enemies.append(body)
		body.take_damage(ATTACK_DAMAGE)
		if body.has_method("apply_knockback"):
			body.apply_knockback(to_enemy, ATTACK_KNOCKBACK)
