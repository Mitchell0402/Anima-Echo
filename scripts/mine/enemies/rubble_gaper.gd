extends "res://scripts/mine/enemies/enemy.gd"

## 碎石怪：缓慢接近 + 周期性加速冲撞（预告闪烁）

var _state: int = 0           # 0=漫步, 1=冲撞
var _state_timer: float = 0.0
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_speed: float = 300.0
var _warn_timer: float = 0.0


func _ready() -> void:
	max_health = 30.0
	contact_damage = 15.0
	move_speed = 80.0
	knockback_resistance = 0.5
	enemy_color = Color(0.55, 0.35, 0.15)   # 棕色 — 碎石怪
	enemy_size = Vector2(28, 36)
	super._ready()
	_state_timer = randf_range(2.0, 4.0)


func _update_ai(delta: float) -> void:
	var player := _find_player()
	if player == null:
		return

	_state_timer -= delta

	match _state:
		0:  # 漫步接近
			_move_toward(player.global_position, move_speed)

			var d := _distance_to_player()
			if _state_timer <= 0.0 and d < 300.0:
				# 开始冲撞预告
				_state = 1
				_warn_timer = 0.5
				modulate = Color(1.3, 0.8, 0.3)
				_charge_dir = (player.global_position - global_position).normalized()

		1:  # 冲撞预告
			_warn_timer -= delta
			modulate = Color(1.0 + sin(Time.get_ticks_msec() * 0.02) * 0.5, 0.6, 0.3)

			if _warn_timer <= 0.0:
				_state = 2
				_state_timer = 0.8
				modulate = Color(2.0, 0.3, 0.2)

		2:  # 冲撞
			velocity = _charge_dir * _charge_speed

			# 碰到墙或时间到 → 恢复
			if _state_timer <= 0.0 or (is_on_wall() and get_slide_collision_count() > 0):
				_state = 0
				_state_timer = randf_range(2.0, 4.0)
				modulate = Color.WHITE
				velocity = Vector2.ZERO


func _get_coin_drop() -> int:
	return randi_range(2, 3)
