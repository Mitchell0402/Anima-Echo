extends "res://scripts/mine/enemies/enemy.gd"

## 爆裂晶：追踪玩家 + 近身自爆（1秒前摇）

var _state: int = 0           # 0=追踪, 1=自爆前摇
var _explode_timer: float = 0.0
var _explode_radius: float = 80.0
var _explode_damage: float = 20.0


func _ready() -> void:
	max_health = 15.0
	contact_damage = 0.0       # 不自爆时无接触伤害
	move_speed = 180.0
	knockback_resistance = 0.1
	enemy_color = Color(1.0, 0.15, 0.35)   # 品红 — 爆裂晶
	enemy_size = Vector2(30, 30)
	super._ready()


func _update_ai(delta: float) -> void:
	var player := _find_player()
	if player == null:
		return

	var d := _distance_to_player()

	match _state:
		0:  # 追踪玩家
			_move_toward(player.global_position, move_speed)

			if d < 50.0:
				# 进入自爆前摇
				_state = 1
				_explode_timer = 1.0
				modulate = Color(1.5, 0.3, 0.3)
				velocity = Vector2.ZERO

		1:  # 自爆前摇（闪烁越来越快）
			_explode_timer -= delta
			var t := Time.get_ticks_msec() * 0.01
			modulate = Color(1.0 + sin(t * 1.5) * 0.6, 0.3, 0.2)

			if _explode_timer <= 0.0:
				_explode()


func _explode() -> void:
	# AOE 爆炸
	var player := _find_player()
	if player and global_position.distance_to(player.global_position) < _explode_radius:
		if player.has_method("take_damage"):
			player.take_damage(_explode_damage)
		if player.has_method("take_hit"):
			player.take_hit(global_position, 300.0)

	# 视觉特效
	var fx := ColorRect.new()
	fx.name = "BoomFX"
	fx.size = Vector2(_explode_radius * 2, _explode_radius * 2)
	fx.position = global_position - Vector2(_explode_radius, _explode_radius)
	fx.color = Color(1.0, 0.4, 0.1, 0.7)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(fx)

	var tw := create_tween()
	tw.tween_property(fx, "color:a", 0.0, 0.3)
	tw.tween_callback(fx.queue_free)

	# 爆炸自身即死——不触发正常 die（避免二次掉落）
	set_physics_process(false)
	remove_from_group("enemy")
	died.emit()

	var tw2 := create_tween()
	tw2.tween_property(self, "modulate:a", 0.0, 0.15)
	tw2.tween_callback(queue_free)

	_spawn_coin_drop()


func take_damage(amount: float) -> void:
	# 被玩家攻击杀 → 不爆炸，正常死亡
	super.take_damage(amount)


func _get_coin_drop() -> int:
	return randi_range(2, 4)
