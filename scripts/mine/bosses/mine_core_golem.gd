extends "res://scripts/mine/enemies/enemy.gd"

## Boss 1: 矿核巨像（Mine Core Golem）— Lv1-2
## 锤击→冲击波 / 召唤碎石怪 / 冲撞

const SHOCKWAVE_SPEED: float = 200.0
const SHOCKWAVE_RANGE: float = 300.0
const CHARGE_SPEED: float = 350.0

var _state: int = 0  # 0=idle, 1=hammering, 2=charging
var _state_timer: float = 0.0
var _hammer_cd: float = 0.0
var _summon_cd: float = 0.0
var _charge_cd: float = 0.0

## Boss 被攻击时眩晕时间更短（不卡顿感）
func take_damage(amount: float) -> void:
	current_health -= amount
	_flash_timer = 0.08
	modulate = Color(2.0, 0.3, 0.3)
	_stun_timer = 0.08
	if current_health <= 0.0:
		die()


func _ready() -> void:
	max_health = 45.0
	move_speed = 60.0
	contact_damage = 15.0
	knockback_resistance = 0.6
	enemy_color = Color(0.6, 0.35, 0.15)
	enemy_size = Vector2(48, 56)
	super._ready()


func _update_ai(delta: float) -> void:
	if _state != 0:
		_state_timer -= delta
		if _state == 1:
			if _state_timer <= 0.0:
				_do_hammer()
		elif _state == 2:
			move_and_slide()
			if _state_timer <= 0.0:
				velocity = Vector2.ZERO
				modulate = Color.WHITE
				_state = 0
			return
		return

	# 空闲状态：靠近玩家
	var player := _find_player()
	if player == null:
		return
	_move_toward(player.global_position, move_speed)

	_hammer_cd -= delta
	_summon_cd -= delta
	_charge_cd -= delta

	if _hammer_cd <= 0.0:
		_start_hammer()
		return

	if current_health < max_health * 0.7 and _charge_cd <= 0.0:
		_charge_cd = 4.0
		_start_charge(player.global_position)
		return

	if current_health < max_health * 0.5 and _summon_cd <= 0.0:
		_summon_cd = 5.0
		_summon_minions()


func _start_hammer() -> void:
	_state = 1
	_state_timer = 0.8
	velocity = Vector2.ZERO
	modulate = Color(1.3, 0.8, 0.5)


func _do_hammer() -> void:
	modulate = Color.WHITE
	_hammer_cd = 3.0

	var player := _find_player()
	if player == null:
		_state = 0
		return

	var player_dir: Vector2 = global_position.direction_to(player.global_position)

	var wave := Area2D.new()
	wave.collision_layer = 0
	wave.collision_mask = 1
	wave.add_to_group("boss_projectile")

	var col := CollisionShape2D.new()
	var s := CircleShape2D.new()
	s.radius = 20.0
	col.shape = s
	wave.add_child(col)

	wave.global_position = global_position
	get_parent().add_child(wave)

	var tw := wave.create_tween()
	var travel_time: float = SHOCKWAVE_RANGE / SHOCKWAVE_SPEED
	tw.tween_property(wave, "global_position", global_position + player_dir * SHOCKWAVE_RANGE, travel_time)
	tw.tween_callback(wave.queue_free)

	wave.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage(18.0)
			if body.has_method("take_hit"):
				body.take_hit(global_position, 250.0)
	)

	_state = 0


func _start_charge(target: Vector2) -> void:
	_state = 2
	_state_timer = CHARGE_SPEED / 350.0 * 0.8  # 冲一段距离就停
	var dir: Vector2 = global_position.direction_to(target)
	velocity = dir * CHARGE_SPEED
	modulate = Color(1.5, 0.3, 0.3)


func _summon_minions() -> void:
	for _i in range(2):
		var rubble_scene: PackedScene = load("res://scenes/mine/enemies/rubble_gaper.tscn")
		if rubble_scene == null:
			return
		var minion: Node = rubble_scene.instantiate()
		minion.global_position = global_position + Vector2(randf_range(-80, 80), randf_range(-60, 60))
		get_parent().add_child(minion)


func _get_coin_drop() -> int:
	return randi_range(10, 15)
