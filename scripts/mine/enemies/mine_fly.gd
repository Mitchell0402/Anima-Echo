extends "res://scripts/mine/enemies/enemy.gd"

## 矿蝇：围绕玩家转圈 + 周期性冲刺

var _orbit_angle: float = 0.0
var _orbit_radius: float = 140.0
var _orbit_direction: int = 1      # 1=顺时针, -1=逆时针
var _orbit_speed: float = 2.0       # 弧度/秒
var _state: int = 0                 # 0=环绕, 1=冲刺
var _state_timer: float = 0.0
var _charge_dir: Vector2 = Vector2.ZERO


func _ready() -> void:
	max_health = 24.0
	contact_damage = 10.0
	move_speed = 120.0
	knockback_resistance = 0.0
	enemy_color = Color(1.0, 0.75, 0.1)   # 黄橙色 — 矿蝇
	enemy_size = Vector2(22, 22)
	super._ready()
	_orbit_direction = 1 if randi() % 2 == 0 else -1
	_orbit_radius = randf_range(100.0, 160.0)
	_orbit_angle = randf_range(0.0, TAU)


func _update_ai(delta: float) -> void:
	var player := _find_player()
	if player == null:
		return

	_state_timer -= delta

	match _state:
		0:  # 环绕
			_orbit_angle += _orbit_speed * _orbit_direction * delta

			var target_pos := player.global_position + Vector2(
				cos(_orbit_angle) * _orbit_radius,
				sin(_orbit_angle) * _orbit_radius
			)

			# 判断是否需要冲刺（每 2-3 圈后随机冲刺）
			if _state_timer <= 0.0:
				_state_timer = randf_range(0.8, 1.5)
				if randi() % 3 == 0:
					_state = 1
					_state_timer = 0.4
					_charge_dir = (player.global_position - global_position).normalized()
					return

			_move_toward(target_pos, move_speed)

		1:  # 冲刺
			velocity = _charge_dir * 300.0
			if _state_timer <= 0.0:
				_state = 0
				_state_timer = randf_range(1.5, 3.0)


func _get_coin_drop() -> int:
	return randi_range(1, 2)
