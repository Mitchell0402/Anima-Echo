extends RigidBody2D

@export var gem_value: int = 1
@export var lifetime: float = 30.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(_fade_out)
	
	_spawn_animation()
	
	# ✅ 横板物理设置
	gravity_scale = 0.5           # 降低重力，不会掉太快
	linear_damp = 0.2             # 空气阻力
	angular_damp = 1.0
	freeze = true                 # 先冻结，等launch时解冻

func launch(initial_velocity: Vector2) -> void:
	freeze = false               # ✅ 解冻，开始物理模拟
	linear_velocity = initial_velocity
	angular_velocity = randf_range(-2, 2)
	print("[Gem] 💎 原石弹出！速度: ", linear_velocity)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_collect()
	elif body.is_in_group("ground"):  # ✅ 碰到地面就停住
		linear_velocity = Vector2.ZERO
		angular_velocity = 0
		freeze = true

func _collect() -> void:
	print("[Gem] 💎 原石被收集！价值: ", gem_value)
	queue_free()

func _spawn_animation() -> void:
	scale = Vector2(0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0, 0.5)
	tween.tween_callback(queue_free)
