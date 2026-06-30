extends "res://scripts/mine/enemies/enemy.gd"

## 幽魂矿工：保持距离 + 直线弹幕 + 受伤传送

const PROJECTILE_SPEED: float = 250.0
const PROJECTILE_DAMAGE: float = 18.0
const PREFERRED_DISTANCE: float = 200.0

var _shoot_timer: float = 0.0
var _shoot_interval: float = 2.0


func _ready() -> void:
	max_health = 3.0
	contact_damage = 0.0          # 无接触伤害
	move_speed = 100.0
	knockback_resistance = 0.3
	enemy_color = Color(0.5, 0.35, 0.9)   # 紫色 — 幽魂矿工
	enemy_size = Vector2(22, 28)
	super._ready()
	_shoot_timer = 1.0


func _update_ai(delta: float) -> void:
	var player := _find_player()
	if player == null:
		return

	var d := _distance_to_player()
	var to_player: Vector2 = player.global_position - global_position

	# 保持距离：太近就退，太远就追
	if d < PREFERRED_DISTANCE - 40:
		velocity = -to_player.normalized() * move_speed
	elif d > PREFERRED_DISTANCE + 60:
		velocity = to_player.normalized() * move_speed
	else:
		velocity = Vector2.ZERO

	# 周期性射击
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = _shoot_interval
		_shoot_at_player(player, to_player.normalized())


func _shoot_at_player(_player: CharacterBody2D, dir: Vector2) -> void:
	var proj := Area2D.new()
	proj.name = "GhostBolt"
	proj.collision_layer = 0
	proj.collision_mask = 1 | 2

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	col.shape = shape
	proj.add_child(col)

	var spr := Sprite2D.new()
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.6, 0.9, 0.7))
	spr.texture = ImageTexture.create_from_image(img)
	proj.add_child(spr)

	proj.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(PROJECTILE_DAMAGE)
			if body.has_method("take_hit"):
				body.take_hit(proj.global_position, 150.0)
		proj.queue_free()
	)

	get_parent().add_child(proj)
	proj.global_position = global_position

	# 移动弹幕
	var tween := create_tween()
	var end_pos := global_position + dir * PROJECTILE_SPEED * 3.0
	tween.tween_property(proj, "global_position", end_pos, 3.0)
	tween.tween_callback(proj.queue_free)


func take_damage(amount: float) -> void:
	super.take_damage(amount)
	# 受伤传送：闪现到随机位置
	if current_health > 0.0 and randi() % 3 == 0:
		var parent := get_parent()
		if parent:
			var hw := 640.0
			var hh := 360.0
			global_position = Vector2(
				randf_range(-hw / 2.0 + 50, hw / 2.0 - 50),
				randf_range(-hh / 2.0 + 50, hh / 2.0 - 50)
			)


func _get_coin_drop() -> int:
	return randi_range(3, 5)
