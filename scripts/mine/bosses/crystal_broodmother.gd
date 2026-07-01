extends "res://scripts/mine/enemies/enemy.gd"

## Boss 2: 水晶巢母（Crystal Broodmother）— Lv3-4
## 产卵 / 8方向弹幕 / 跳跃 / 虫群冲锋

var _state: int = 0  # 0=idle, 1=laying_egg, 2=leaping
var _state_timer: float = 0.0
var _egg_cd: float = 0.0
var _scatter_cd: float = 0.0
var _leap_cd: float = 0.0
var _swarm_cd: float = 0.0
var _eggs: Array = []  # 追踪活的卵


func _ready() -> void:
	max_health = 60.0
	move_speed = 80.0
	contact_damage = 12.0
	knockback_resistance = 0.4
	enemy_color = Color(0.2, 0.55, 0.55)
	enemy_size = Vector2(44, 44)
	super._ready()


func take_damage(amount: float) -> void:
	super.take_damage(amount)
	# Boss 受击不眩晕太久
	_stun_timer = 0.08


func _update_ai(delta: float) -> void:
	if _state != 0:
		_state_timer -= delta
		if _state == 1:
			velocity = Vector2.ZERO
			if _state_timer <= 0.0:
				_spawn_egg()
				_state = 0
		elif _state == 2:
			# 跳跃中：抛物线
			var progress := 0.5 - _state_timer / 0.5
			if progress < 1.0:
				velocity.y = -sin(progress * PI) * 120.0
			move_and_slide()
			if _state_timer <= 0.0:
				_do_land()
			return
		return

	var player := _find_player()
	if player == null:
		return
	_move_toward(player.global_position, move_speed)

	_egg_cd -= delta
	_scatter_cd -= delta
	_leap_cd -= delta

	if current_health < max_health * 0.3:
		_swarm_cd -= delta

	if _egg_cd <= 0.0:
		_egg_cd = 6.0
		_state = 1
		_state_timer = 0.5
		modulate = Color(0.3, 0.8, 0.8)
		return

	if _scatter_cd <= 0.0:
		_scatter_cd = 3.0
		_shoot_scatter()

	if _leap_cd <= 0.0:
		_leap_cd = 4.0
		if player:
			_start_leap(player.global_position)
			return

	if current_health < max_health * 0.3 and _swarm_cd <= 0.0:
		_swarm_cd = 8.0
		_command_swarm()


func _spawn_egg() -> void:
	modulate = Color.WHITE
	var egg := StaticBody2D.new()
	egg.name = "CrystalEgg"
	egg.collision_layer = 2
	egg.collision_mask = 1
	egg.add_to_group("enemy")

	var col := CollisionShape2D.new()
	var s := CircleShape2D.new()
	s.radius = 14.0
	col.shape = s
	egg.add_child(col)

	egg.global_position = global_position + Vector2(randf_range(-50, 50), randf_range(-30, 30))
	var parent := get_parent()
	parent.add_child(egg)

	_eggs.append(egg)

	# 30 秒后孵化
	get_tree().create_timer(30.0).timeout.connect(func() -> void:
		if not is_instance_valid(egg):
			return
		var pos := egg.global_position
		egg.queue_free()
		_eggs.erase(egg)
		var trite_scene: PackedScene = load("res://scenes/mine/enemies/crystal_trite.tscn")
		if trite_scene:
			var trite: Node = trite_scene.instantiate()
			trite.global_position = pos
			parent.add_child(trite)
	)


func _shoot_scatter() -> void:
	var dirs := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
		Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(),
		Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]
	for dir in dirs:
		_spawn_projectile(dir, 150.0, 10.0, Color(0.3, 0.8, 1.0))


func _start_leap(target: Vector2) -> void:
	_state = 2
	_state_timer = 0.5
	var dir: Vector2 = global_position.direction_to(target)
	velocity = dir * 220.0


func _do_land() -> void:
	velocity = Vector2.ZERO
	_state = 0
	modulate = Color.WHITE

	# 落地冲击波
	var player := _find_player()
	if player and global_position.distance_to(player.global_position) < 100.0:
		if player.has_method("take_damage"):
			player.take_damage(14.0)
		if player.has_method("take_hit"):
			player.take_hit(global_position, 200.0)

	# 落地震屏一小下
	_create_burst_effect()

	_leap_cd = 4.0


func _command_swarm() -> void:
	# 让在场所有水晶蛛冲刺玩家
	var player := _find_player()
	if player == null:
		return
	for child in get_parent().get_children():
		if child.has_method("_find_player") and child != self:
			if child.is_in_group("enemy"):
				var dir: Vector2 = child.global_position.direction_to(player.global_position)
				child.velocity = dir * 250.0
				get_tree().create_timer(0.3).timeout.connect(func() -> void:
					if is_instance_valid(child):
						child.velocity = Vector2.ZERO
				)


func _spawn_projectile(dir: Vector2, speed: float, damage: float, color: Color) -> void:
	var proj := Area2D.new()
	proj.collision_layer = 0
	proj.collision_mask = 1
	proj.add_to_group("boss_projectile")

	var col := CollisionShape2D.new()
	var s := CircleShape2D.new()
	s.radius = 6.0
	col.shape = s
	proj.add_child(col)

	# 视觉：小方块
	var vc := ColorRect.new()
	vc.size = Vector2(8, 8)
	vc.position = Vector2(-4, -4)
	vc.color = color
	proj.add_child(vc)

	proj.global_position = global_position
	get_parent().add_child(proj)

	var tw := proj.create_tween()
	tw.tween_property(proj, "global_position", global_position + dir * 400.0, 400.0 / speed)
	tw.tween_callback(proj.queue_free)

	proj.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage(damage)
			if body.has_method("take_hit"):
				body.take_hit(global_position, 150.0)
	)


func _create_burst_effect() -> void:
	# 简单的圆形扩展特效
	var ring := ColorRect.new()
	ring.color = Color(1.0, 0.8, 0.2, 0.6)
	ring.size = Vector2(20, 20)
	ring.position = -Vector2(10, 10)
	ring.global_position = global_position - Vector2(10, 10)
	get_parent().add_child(ring)

	var tw := ring.create_tween()
	tw.tween_property(ring, "size", Vector2(200, 200), 0.3)
	tw.parallel().tween_property(ring, "position", -Vector2(100, 100), 0.3)
	tw.parallel().tween_property(ring, "color:a", 0.0, 0.3)
	tw.tween_callback(ring.queue_free)


func _get_coin_drop() -> int:
	return randi_range(15, 20)


func die() -> void:
	# 清理卵
	for egg in _eggs:
		if is_instance_valid(egg):
			egg.call_deferred("queue_free")
	_eggs.clear()
	super.die()
