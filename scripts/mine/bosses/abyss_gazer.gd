extends "res://scripts/mine/enemies/enemy.gd"

## Boss 3: 深渊凝视者（Abyss Gazer）— Lv5
## 两阶段：激光扫射 / 追踪暗影球 / 传送 / 矿脉突刺 / 分裂小眼

var _state: int = 0  # 0=idle, 1=lasing, 2=teleporting
var _state_timer: float = 0.0
var _gaze_cd: float = 0.0
var _orb_cd: float = 0.0
var _teleport_cd: float = 0.0
var _spike_cd: float = 3.0
var _split_cd: float = 5.0
var _phase2: bool = false
var _laser_node: Node2D = null
var _laser_timer: float = 0.0
var _laser_tick: float = 0.0


func _ready() -> void:
	max_health = 75.0
	move_speed = 40.0
	contact_damage = 20.0
	knockback_resistance = 0.7
	enemy_color = Color(0.3, 0.1, 0.5)
	enemy_size = Vector2(40, 40)
	super._ready()


func take_damage(amount: float) -> void:
	super.take_damage(amount)
	_stun_timer = 0.06
	if not _phase2 and current_health <= max_health * 0.4:
		_phase2 = true
		_spike_cd = 3.0
		_split_cd = 5.0
		_do_teleport()


func _update_ai(delta: float) -> void:
	if _state == 1:
		# 激光持续中
		_laser_timer -= delta
		_update_laser(delta)
		if _laser_timer <= 0.0:
			_end_laser()
			_state = 0
		return
	elif _state == 2:
		# 传送中
		_state_timer -= delta
		if _state_timer <= 0.0:
			_appear()
			_state = 0
		return

	# 空闲
	var player := _find_player()
	if player:
		_move_toward(player.global_position, move_speed)

	_gaze_cd -= delta
	_orb_cd -= delta
	_teleport_cd -= delta
	if _phase2:
		_spike_cd -= delta
		_split_cd -= delta

	var mult := 0.75 if _phase2 else 1.0

	if _gaze_cd <= 0.0:
		_gaze_cd = 2.5 * mult
		_start_laser()
		return
	if _orb_cd <= 0.0:
		_orb_cd = 4.0 * mult
		_shoot_orb_volley()
		return
	if _teleport_cd <= 0.0:
		_teleport_cd = 6.0 * mult
		_start_teleport()
		return
	if _phase2 and _spike_cd <= 0.0:
		_spike_cd = 5.0
		_cast_vein_spikes()
		return
	if _phase2 and _split_cd <= 0.0:
		_split_cd = 8.0
		_summon_mini_gazers()


# ——— 激光 ———
func _start_laser() -> void:
	_state = 1
	_laser_timer = 1.5
	velocity = Vector2.ZERO
	modulate = Color(1.2, 0.3, 1.2)

	var laser := Area2D.new()
	laser.name = "GazeLaser"
	laser.collision_layer = 0
	laser.collision_mask = 1

	var col := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = Vector2.ZERO
	seg.b = Vector2(0, 400)
	col.shape = seg
	laser.add_child(col)

	var beam := ColorRect.new()
	beam.color = Color(1.0, 0.2, 1.0, 0.6)
	beam.size = Vector2(6, 400)
	beam.position = Vector2(-3, 0)
	laser.add_child(beam)

	laser.global_position = global_position
	get_parent().add_child(laser)
	_laser_node = laser
	_laser_tick = 0.25


func _update_laser(delta: float) -> void:
	if not _laser_node or not is_instance_valid(_laser_node):
		return

	var player := _find_player()
	if player:
		var desired := _laser_node.global_position.angle_to_point(player.global_position)
		_laser_node.global_rotation = lerp_angle(_laser_node.global_rotation, desired, delta * 4.0)

	_laser_tick -= delta
	if _laser_tick <= 0.0:
		_laser_tick = 0.25
		for body in _laser_node.get_overlapping_bodies():
			if body.is_in_group("player"):
				if body.has_method("take_damage"):
					body.take_damage(8.0)
				if body.has_method("take_hit"):
					body.take_hit(global_position, 100.0)


func _end_laser() -> void:
	modulate = Color.WHITE
	if _laser_node and is_instance_valid(_laser_node):
		_laser_node.call_deferred("queue_free")
	_laser_node = null
	_stun_timer = 0.8
	_state = 0


# ——— 暗影球（追踪弹） ———
func _shoot_orb_volley() -> void:
	var player := _find_player()
	var base_dir := global_position.direction_to(player.global_position) if player else Vector2.RIGHT
	for i in range(3):
		var spread := deg_to_rad(-15 + i * 15)
		_make_homing_orb(base_dir.rotated(spread))


func _make_homing_orb(dir: Vector2) -> void:
	var orb := Area2D.new()
	orb.collision_layer = 0
	orb.collision_mask = 1
	orb.add_to_group("boss_projectile")

	var col := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 8.0
	col.shape = c
	orb.add_child(col)

	var visual := ColorRect.new()
	visual.size = Vector2(10, 10)
	visual.position = Vector2(-5, -5)
	visual.color = Color(0.6, 0.1, 0.8, 0.9)
	orb.add_child(visual)

	orb.global_position = global_position
	get_parent().add_child(orb)

	orb.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage(15.0)
			if body.has_method("take_hit"):
				body.take_hit(orb.global_position, 180.0)
		orb.call_deferred("queue_free")
	)

	_update_orb_step(orb, dir, 2.0, 4.0, 120.0)


func _update_orb_step(orb: Area2D, dir: Vector2, track_left: float, life: float, speed: float) -> void:
	if not is_instance_valid(orb) or life <= 0.0:
		if orb and is_instance_valid(orb):
			orb.queue_free()
		return

	var d := dir.normalized()
	if track_left > 0.0:
		var player := _find_player()
		if player:
			var desired := orb.global_position.direction_to(player.global_position)
			d = d.lerp(desired, 0.03).normalized()

	var dt := 0.05
	orb.global_position += d * speed * dt
	life -= dt
	track_left -= dt

	if life > 0.0:
		get_tree().create_timer(dt).timeout.connect(
			_update_orb_step.bind(orb, d, track_left, life, speed)
		)


# ——— 传送 ———
func _start_teleport() -> void:
	_state = 2
	_state_timer = 0.5
	velocity = Vector2.ZERO
	visible = false
	modulate.a = 0.3


func _appear() -> void:
	global_position = get_parent().global_position + Vector2(randf_range(-350, 350), randf_range(-200, 200))
	visible = true
	modulate.a = 1.0


func _do_teleport() -> void:
	visible = false
	modulate.a = 0.3
	var t := get_tree().create_timer(0.5)
	await t.timeout
	_appear()
	_stun_timer = 0.5


# ——— 矿脉突刺 ———
func _cast_vein_spikes() -> void:
	var player := _find_player()
	var center: Vector2 = player.global_position if player else global_position
	var parent := get_parent()

	for i in range(5):
		var spike_pos := center + Vector2(randf_range(-180, 180), randf_range(-120, 120))

		var marker := ColorRect.new()
		marker.color = Color(1.0, 0.2, 0.2, 0.5)
		marker.size = Vector2(24, 6)
		marker.position = spike_pos - Vector2(12, 3)
		parent.add_child(marker)

		get_tree().create_timer(0.6).timeout.connect(func() -> void:
			if not is_instance_valid(marker):
				return
			marker.queue_free()

			var spike := Area2D.new()
			spike.collision_layer = 0
			spike.collision_mask = 1
			spike.global_position = spike_pos

			var sc := CollisionShape2D.new()
			var cc := CircleShape2D.new()
			cc.radius = 24.0
			sc.shape = cc
			spike.add_child(sc)

			var v := ColorRect.new()
			v.size = Vector2(16, 48)
			v.position = Vector2(-8, -24)
			v.color = Color(1.0, 0.3, 0.3, 0.8)
			spike.add_child(v)

			parent.add_child(spike)

			spike.body_entered.connect(func(body: Node2D) -> void:
				if body.is_in_group("player"):
					if body.has_method("take_damage"):
						body.take_damage(20.0)
					if body.has_method("take_hit"):
						body.take_hit(spike_pos, 300.0)
			)
			get_tree().create_timer(0.3).timeout.connect(spike.queue_free)
		)


# ——— 分裂小眼 ———
func _summon_mini_gazers() -> void:
	for _i in range(2):
		_spawn_mini_gazer()


func _spawn_mini_gazer() -> void:
	var parent := get_parent()

	var mini := CharacterBody2D.new()
	mini.name = "MiniGazer" + str(randi())
	mini.collision_layer = 2
	mini.collision_mask = 1
	mini.add_to_group("enemy")
	mini.global_position = global_position + Vector2(randf_range(-80, 80), randf_range(-60, 60))

	var col := CollisionShape2D.new()
	var cc := CircleShape2D.new()
	cc.radius = 10.0
	col.shape = cc
	mini.add_child(col)

	parent.add_child(mini)

	mini.set_meta("hp", 2.0)
	mini.set_meta("shoot_cd", 0.0)

	_process_mini_gazer(mini)


func _process_mini_gazer(mini: CharacterBody2D) -> void:
	if not is_instance_valid(mini):
		return

	var hp: float = mini.get_meta("hp")
	if hp <= 0.0:
		mini.call_deferred("queue_free")
		return

	var player := _find_player()
	if player:
		var to_player := mini.global_position.direction_to(player.global_position) * 30.0
		mini.velocity = to_player
		mini.move_and_slide()

		var cd: float = mini.get_meta("shoot_cd")
		cd -= 0.1
		if cd <= 0.0:
			cd = 3.0
			_shoot_mini_orb(mini)
		mini.set_meta("shoot_cd", cd)

		for c_idx in range(mini.get_slide_collision_count()):
			var col_node := mini.get_slide_collision(c_idx)
			var other := col_node.get_collider()
			if other != null and other.is_in_group("player"):
				if other.has_method("take_damage"):
					other.take_damage(5.0)

	get_tree().create_timer(0.1).timeout.connect(_process_mini_gazer.bind(mini))

	if not mini.has_meta("born"):
		mini.set_meta("born", 1.0)
		get_tree().create_timer(15.0).timeout.connect(func() -> void:
			if is_instance_valid(mini):
				mini.call_deferred("queue_free")
		)


func _shoot_mini_orb(mini: CharacterBody2D) -> void:
	var player := _find_player()
	if player == null:
		return
	var dir := mini.global_position.direction_to(player.global_position)
	var orb := Area2D.new()
	orb.collision_layer = 0
	orb.collision_mask = 1
	var sc := CollisionShape2D.new()
	var cc := CircleShape2D.new()
	cc.radius = 5.0
	sc.shape = cc
	orb.add_child(sc)
	orb.global_position = mini.global_position
	get_parent().add_child(orb)

	var tw := orb.create_tween()
	tw.tween_property(orb, "global_position", mini.global_position + dir * 300.0, 1.0)
	tw.tween_callback(orb.queue_free)

	orb.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(8.0)
		orb.call_deferred("queue_free")
	)


func _get_coin_drop() -> int:
	return randi_range(15, 20)


func die() -> void:
	if _laser_node and is_instance_valid(_laser_node):
		_laser_node.call_deferred("queue_free")
	super.die()
