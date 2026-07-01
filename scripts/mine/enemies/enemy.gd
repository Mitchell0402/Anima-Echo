extends CharacterBody2D

## 敌人基类 — 所有 5 种小怪 + Boss 的公共基础。
## 子类覆写 _update_ai(delta) 定义行为。

@export var max_health: float = 24.0
@export var move_speed: float = 100.0
@export var contact_damage: float = 10.0
@export var knockback_resistance: float = 0.3
@export var enemy_color: Color = Color.RED
@export var enemy_size: Vector2 = Vector2(32, 32)

var current_health: float = 24.0
var _knockback: Vector2 = Vector2.ZERO
var _flash_timer: float = 0.0
var _stun_timer: float = 0.0

signal died


func _draw() -> void:
	var half: Vector2 = enemy_size / 2.0
	var rect := Rect2(-half, enemy_size)
	draw_rect(rect, enemy_color, true)
	draw_rect(rect, enemy_color.darkened(0.3), false, 2.0)


func _ready() -> void:
	current_health = max_health
	collision_layer = 2   # enemies layer
	collision_mask = 1    # walls layer
	add_to_group("enemy")


func _physics_process(delta: float) -> void:
	# 击退衰减
	if _knockback.length() > 0.1:
		_knockback = _knockback.move_toward(Vector2.ZERO, 200.0 * delta)
		velocity = _knockback
		move_and_slide()
		return

	# 受创暂时/死亡冻结
	if _stun_timer > 0.0 or current_health <= 0.0:
		_stun_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
		move_and_slide()
		return

	# 闪白计时
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			modulate = Color.WHITE

	_update_ai(delta)
	move_and_slide()

	# 玩家接触伤害
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other != null and other.is_in_group("player"):
			if other.has_method("take_damage"):
				other.take_damage(contact_damage)
			if other.has_method("take_hit"):
				other.take_hit(global_position, 200.0)


func take_damage(amount: float) -> void:
	current_health -= amount
	_flash_timer = 0.1
	modulate = Color(2.0, 0.3, 0.3)
	_stun_timer = 0.15

	if current_health <= 0.0:
		die()


func apply_knockback(dir: Vector2, force: float) -> void:
	_knockback = dir * force * (1.0 - knockback_resistance)


func die() -> void:
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	remove_from_group("enemy")
	died.emit()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

	# 掉落铜板（子类可覆写 _get_coin_drop()）
	_spawn_coin_drop()


func _get_coin_drop() -> int:
	return 0


func _spawn_coin_drop() -> void:
	var coins := _get_coin_drop()
	if coins <= 0:
		return
	var rt: Node = get_node_or_null("/root/GameRuntime")
	if rt and rt.has_method("add_mine_tickets"):
		pass
	# 直接加铜板到 wallet
	if rt and rt.wallet:
		rt.wallet.add_currency(coins)


func _update_ai(_delta: float) -> void:
	pass


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		return players[0] as CharacterBody2D
	return null


func _move_toward(target: Vector2, speed: float) -> void:
	var dir: Vector2 = global_position.direction_to(target)
	velocity = dir * speed


func _distance_to_player() -> float:
	var player := _find_player()
	if player == null:
		return INF
	return global_position.distance_to(player.global_position)
