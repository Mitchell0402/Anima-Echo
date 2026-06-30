extends "res://scripts/mine/enemies/enemy.gd"

## 水晶蛛：跳跃移动 + 落地时发射 4 方向弹幕

const PROJECTILE_SPEED: float = 300.0
const PROJECTILE_DAMAGE: float = 12.0
const PROJECTILE_LIFETIME: float = 2.0

var _state: int = 0           # 0=跳跃中, 1=落地/冷却
var _state_timer: float = 0.0
var _jump_target: Vector2 = Vector2.ZERO
var _jump_start: Vector2 = Vector2.ZERO
var _jump_duration: float = 0.5
var _projectile_scene: PackedScene = null


func _ready() -> void:
	max_health = 2.0
	contact_damage = 0.0
	move_speed = 0.0
	knockback_resistance = 0.2
	enemy_color = Color(0.15, 0.75, 0.85)   # 青色 — 水晶蛛
	enemy_size = Vector2(26, 26)
	super._ready()
	_state_timer = randf_range(0.5, 1.5)


func _update_ai(delta: float) -> void:
	var player := _find_player()
	if player == null:
		return

	_state_timer -= delta

	match _state:
		0:  # 跳跃中
			var t := 1.0 - (_state_timer / _jump_duration)
			t = clamp(t, 0.0, 1.0)
			# 抛物线跳跃
			global_position = _jump_start.lerp(_jump_target, t) + Vector2(0, -sin(t * PI) * 60.0)

			if _state_timer <= 0.0:
				# 落地 → 发射弹幕 + 冷却
				_state = 1
				_state_timer = randf_range(1.0, 2.0)
				_shoot_4_directions()

		1:  # 冷却
			velocity = Vector2.ZERO
			if _state_timer <= 0.0:
				# 准备下一次跳跃
				_state = 0
				_jump_duration = randf_range(0.4, 0.7)
				_state_timer = _jump_duration
				_jump_start = global_position

				var toward_player: Vector2 = player.global_position - global_position
				var jump_dist: float = minf(toward_player.length(), 120.0)
				_jump_target = global_position + toward_player.normalized() * jump_dist


func _shoot_4_directions() -> void:
	var dirs := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	for dir in dirs:
		_spawn_projectile(global_position, dir, PROJECTILE_SPEED, PROJECTILE_DAMAGE)


func _spawn_projectile(pos: Vector2, dir: Vector2, speed: float, damage: float) -> void:
	var proj := Area2D.new()
	proj.name = "CrystalBolt"
	proj.collision_layer = 0
	proj.collision_mask = 1 | 2  # walls + player

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 6.0
	col.shape = shape
	proj.add_child(col)

	var spr := Sprite2D.new()
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.3, 0.9, 0.9))
	spr.texture = ImageTexture.create_from_image(img)
	proj.add_child(spr)

	proj.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage)
			if body.has_method("take_hit"):
				body.take_hit(proj.global_position, 200.0)
		proj.queue_free()
	)

	get_parent().add_child(proj)
	proj.global_position = pos

	# 弹幕移动
	var tween := create_tween()
	var end_pos := pos + dir * speed * PROJECTILE_LIFETIME * 0.5
	tween.tween_property(proj, "global_position", end_pos, PROJECTILE_LIFETIME)
	tween.tween_callback(proj.queue_free)


func _get_coin_drop() -> int:
	return randi_range(3, 4)
