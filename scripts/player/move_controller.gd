extends Node

## 玩家移动控制器。读取输入、移动玩家、播放动画、发出移动噪音。
## 被挖矿/躲藏锁定时（player.can_move() == false）不接受移动输入，
## 但脚本本身始终运行，避免出现「禁用脚本后永久卡死」的问题。

@onready var body: CharacterBody2D = $".."
@onready var stats: Node = $"../Stats"
@onready var animated_sprite: AnimatedSprite2D = $"../AnimatedSprite2D"
@onready var _noise: Node = get_node_or_null("/root/NoiseSystem")
## 负重系统已禁用
## @onready var _weight: Node = get_node_or_null("/root/WeightSystem")
@onready var _trail: Node = $"../TrailEffect"

const WALK_SPEED_FACTOR: float = 0.5  # 默认步行速度相对于全速的比例
const HURT_DECEL: float = 300.0          # 击退速度衰减

var current_direction: String = "f"  # f, b, l, r
var current_state: String = "idle"   # idle, walk, run, hurt

func _ready() -> void:
	update_animation()

func _physics_process(delta: float) -> void:
	if not body or not stats:
		return

	# 受击：以击退速度滑行、播放受击动画，衰减结束后自动恢复 FREE
	if body.has_method("is_hurt") and body.is_hurt():
		body.velocity = body.hurt_velocity()
		body.move_and_slide()
		_play_hurt_animation(body.hurt_velocity())
		body.tick_hurt(delta, HURT_DECEL)
		_stop_trail()
		SfxSystem.stop_walk()
		return

	# 死亡：停止移动、不覆盖动画（保留 death 动画播放）
	if body.has_method("is_dead") and body.is_dead():
		body.velocity = Vector2.ZERO
		_stop_trail()
		SfxSystem.stop_walk()
		return

	# 攻击中：只执行冲刺速度，不接受输入，动画由 player.gd 控制
	if body.has_method("is_attacking") and body.is_attacking():
		body.move_and_slide()
		_stop_trail()
		SfxSystem.stop_walk()
		return

	# 被锁定（挖矿/躲藏）时停止移动，但仍保持脚本运行
	if body.has_method("can_move") and not body.can_move():
		body.velocity = Vector2.ZERO
		handle_animation(Vector2.ZERO, false)
		_stop_trail()
		SfxSystem.stop_walk()
		return

	var input_dir := _to_cardinal_direction(Input.get_vector("left", "right", "up", "down"))

	var is_running := Input.is_action_pressed("walk")  # walk action = Shift, now means run
	var effective_speed: float = stats.get_effective_speed()
	if not is_running:
		effective_speed *= WALK_SPEED_FACTOR

	body.velocity.x = input_dir.x * effective_speed
	body.velocity.y = input_dir.y * effective_speed * stats.z_axis_factor

	if input_dir == Vector2.ZERO:
		body.velocity = body.velocity.move_toward(Vector2.ZERO, effective_speed * 10.0 * delta)

	body.move_and_slide()
	handle_animation(input_dir, is_running)

	# 行走音效
	if input_dir != Vector2.ZERO:
		SfxSystem.play_walk(is_running)
	else:
		SfxSystem.stop_walk()

	# 拖尾特效：移动时发射粒子，静止时停止
	if input_dir != Vector2.ZERO:
		_start_trail()
	else:
		_stop_trail()

	# 慢走 2.5 / 跑步 15；躲藏或挖矿时不发声（can_move 已在上方 return）
	if input_dir != Vector2.ZERO and _noise:
		var loudness: float = _noise.WALK * 0.5 if not is_running else _noise.RUN
		## 负重噪音增益已禁用
		## if _weight:
		## 	loudness *= _weight.get_noise_multiplier()
		var eq: Object = get_node_or_null("/root/GameRuntime")
		if eq:
			var esys: Object = eq.get("equipment_system")
			if esys:
				loudness *= (1.0 - float(esys.get_innate_noise_reduction()))
				if not is_running:
					loudness *= (1.0 - float(esys.get_walk_noise_reduction()))
		_noise.emit_noise(body.global_position, loudness, body)

func handle_animation(input_dir: Vector2, is_running: bool) -> void:
	if not animated_sprite:
		return

	var is_moving := input_dir.length() > 0.1
	if not is_moving:
		if current_state != "idle":
			current_state = "idle"
			update_animation()
		return

	var new_state := "run" if is_running else "walk"
	var new_direction := get_direction(input_dir)
	var changed := false

	if new_direction != current_direction:
		current_direction = new_direction
		changed = true
	if new_state != current_state:
		current_state = new_state
		changed = true

	if changed:
		update_animation()

func _play_hurt_animation(knockback: Vector2) -> void:
	if not animated_sprite:
		return
	# 面向攻击来源（与击退方向相反）
	var face: Vector2 = -knockback
	var dir: String = get_direction(face) if face.length() > 0.01 else current_direction
	current_state = "hurt"
	current_direction = dir
	var anim_name: String = "hurt_" + dir
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)

func get_direction(input_dir: Vector2) -> String:
	if abs(input_dir.x) > abs(input_dir.y):
		return "r" if input_dir.x > 0 else "l"
	else:
		return "f" if input_dir.y > 0 else "b"


func _to_cardinal_direction(input_dir: Vector2) -> Vector2:
	if input_dir == Vector2.ZERO:
		return Vector2.ZERO
	if absf(input_dir.x) > absf(input_dir.y):
		return Vector2(signf(input_dir.x), 0.0)
	return Vector2(0.0, signf(input_dir.y))

func update_animation() -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	var animation_name := current_state + "_" + current_direction
	if animated_sprite.sprite_frames.has_animation(animation_name):
		if animated_sprite.animation != animation_name:
			animated_sprite.play(animation_name)
	else:
		print("动画不存在: ", animation_name)

## 强制要求下一帧刷新动画（攻击/受击结束后调用）
func on_attack_ended() -> void:
	current_state = ""

## 启动拖尾粒子发射
func _start_trail() -> void:
	if _trail and _trail.has_method("start_trail"):
		_trail.start_trail()

## 停止拖尾粒子发射
func _stop_trail() -> void:
	if _trail and _trail.has_method("stop_trail"):
		_trail.stop_trail()
