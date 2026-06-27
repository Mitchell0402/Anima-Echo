extends CharacterBody2D

## 敌人 AI（ghost 移动，无视地形碰撞）
##
## 五态：巡逻 → 调查 → 搜索 → 回归
##              ↘ 猎杀 ↗
##
## 三套检测（按状态开关，互不干扰）：
##   暴露检测   — PATROL / RETURN：玩家在 exposure_range 内可见 ≥0.2s → 猎杀
##   巡逻听觉   — PATROL / RETURN：detection_range 内噪音超距离阈值 → 调查
##   可疑听觉   — INVESTIGATE / SEARCH：suspect_range 内玩家跑步声 ≥15 持续 ≥0.2s → 猎杀

enum State { PATROL, INVESTIGATE, CHASE, SEARCH, RETURN, ATTACK }

# --- 速度 ---
@export var patrol_speed: float = 200.0
@export var investigate_speed: float = 250.0
@export var chase_speed: float = 550.0
@export var search_move_speed: float = 125.0
@export var return_speed: float = 150.0

# --- 范围 ---
@export var exposure_range: float = 200.0
@export var detection_range: float = 500.0
@export var suspect_range: float = 250.0
@export var chase_lose_distance: float = 500.0

# --- 噪音阈值 ---
@export var min_noise_threshold: float = 1.0
@export var max_noise_threshold: float = 30.0
@export var suspect_noise_floor: float = 15.0

# --- 时间 ---
@export var exposure_confirm_time: float = 0.2
@export var suspect_confirm_time: float = 0.2
@export var search_duration: float = 1.0
@export var exposure_linger_decay: float = 1.0
@export var patrol_detection_cooldown_time: float = 2.0

# --- 搜索 / 调查 ---
@export var search_stop_distance: float = 120.0
@export var hidden_approach_cap: float = 80.0
@export var investigate_arrive_distance: float = 15.0
@export var noise_origin_cooldown: float = 5.0

# --- 巡逻随机停顿（原地东张西望，表现"调查"）---
@export var patrol_pause_min_interval: float = 3.0
@export var patrol_pause_max_interval: float = 7.0
@export var patrol_pause_min_duration: float = 1.0
@export var patrol_pause_max_duration: float = 2.5
@export var patrol_look_interval: float = 0.5

# --- 攻击 ---
@export var attack_range: float = 90.0       # 进入攻击的距离
@export var attack_windup: float = 0.25       # 出手前摇
@export var attack_duration: float = 0.6      # 单次攻击总时长
@export var attack_cooldown: float = 0.8      # 攻击后冷却
@export var attack_lunge_distance: float = 60.0  # 出手时前冲位移
@export var attack_hit_radius: float = 110.0  # 出手帧判定命中半径
@export var knockback_force: float = 600.0    # 对玩家的击退力度
@export var attack_damage: float = 25.0        # 每次命中扣血（四次致死）

# --- 调试 ---
@export var show_debug_ranges: bool = true

# --- 巡逻路径 ---
@export var path: Path2D
var path_follow: PathFollow2D
var path_index: float = 0.0

var current_state: State = State.PATROL
var investigate_target: Vector2 = Vector2.ZERO
var last_known_position: Vector2 = Vector2.ZERO
var player: CharacterBody2D = null

var _exposure_timer: float = 0.0
var _suspect_timer: float = 0.0
var _search_timer: float = 0.0
var _patrol_detection_cooldown: float = 0.0
var _noise_poll: float = 0.0
var _noise_origin_block_timer: float = 0.0
var _blocked_noise_origin: Vector2 = Vector2.ZERO

# 巡逻停顿
var _patrol_pause_timer: float = 0.0
var _patrol_pausing: bool = false
var _patrol_pause_remaining: float = 0.0
var _patrol_look_timer: float = 0.0

# 攻击
var _attack_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _attack_has_hit: bool = false
var _attack_dir: Vector2 = Vector2.DOWN

# 动画
var facing_dir: String = "f"
const FACE_THRESHOLD: float = 1.0

const NOISE_POLL_INTERVAL: float = 0.1

@onready var sprite: AnimatedSprite2D = _resolve_sprite()
@onready var _noise: Node = get_node_or_null("/root/NoiseSystem")
@onready var _stability: Node = get_node_or_null("/root/StabilitySystem")

func _resolve_sprite() -> AnimatedSprite2D:
	if has_node("AnimatedSprite2D"):
		return $AnimatedSprite2D
	return null

func _ready() -> void:
	add_to_group("enemy")
	player = get_tree().get_first_node_in_group("player")
	if sprite:
		sprite.flip_h = false
	_schedule_next_pause()
	if path:
		path_follow = PathFollow2D.new()
		path.add_child(path_follow)
		path_follow.loop = true

func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if _patrol_detection_cooldown > 0.0:
		_patrol_detection_cooldown = max(0.0, _patrol_detection_cooldown - delta)
	if _noise_origin_block_timer > 0.0:
		_noise_origin_block_timer = max(0.0, _noise_origin_block_timer - delta)
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer = max(0.0, _attack_cooldown_timer - delta)

	_update_detection(delta)

	match current_state:
		State.PATROL:
			_patrol(delta)
		State.INVESTIGATE:
			_investigate(delta)
		State.CHASE:
			_chase(delta)
		State.SEARCH:
			_search(delta)
		State.RETURN:
			_return_to_path(delta)
		State.ATTACK:
			_attack(delta)

	global_position += velocity * delta
	_update_animation()

# ============ 检测（按状态分发）============

func _update_detection(delta: float) -> void:
	if current_state == State.CHASE or current_state == State.ATTACK:
		return

	# 暴露检测：绝对最高优先级，任何非猎杀状态只要玩家暴露就立即升级猎杀
	if _update_exposure(delta):
		return

	match current_state:
		State.PATROL, State.RETURN:
			_update_patrol_auditory(delta)
		State.INVESTIGATE, State.SEARCH:
			_update_suspect(delta)

## 返回 true 表示本帧已触发猎杀，调用方应停止后续检测。
func _update_exposure(delta: float) -> bool:
	if player == null or _is_player_hidden():
		_decay_exposure(delta)
		return false

	var dist: float = global_position.distance_to(player.global_position)
	if dist <= _effective_exposure_range():
		_exposure_timer += delta
		if _exposure_timer >= exposure_confirm_time:
			print("[Enemy] ⚡ 暴露确认，开始猎杀")
			_enter_chase()
			return true
	else:
		_decay_exposure(delta)
	return false

func _decay_exposure(delta: float) -> void:
	_exposure_timer = max(0.0, _exposure_timer - delta * exposure_linger_decay)

func _update_patrol_auditory(delta: float) -> void:
	# 冷却仅限制巡逻态，防止丢失后在边缘低分贝反复横跳；
	# 回归路上玩家站到面前或挖矿仍应能触发。
	if current_state == State.PATROL and _patrol_detection_cooldown > 0.0:
		return
	if _noise == null:
		return

	_noise_poll += delta
	if _noise_poll < NOISE_POLL_INTERVAL:
		return
	_noise_poll = 0.0

	var noise: Dictionary = _noise.get_audible_noise(global_position, _effective_detection_range())
	if noise.is_empty():
		return

	var origin: Vector2 = noise["position"]
	if _noise_origin_block_timer > 0.0 and origin.distance_to(_blocked_noise_origin) < 30.0:
		return

	var threshold: float = _effective_noise_threshold(noise["distance"])
	if noise["loudness"] < threshold:
		return

	investigate_target = origin
	last_known_position = origin
	_blocked_noise_origin = origin
	_noise_origin_block_timer = noise_origin_cooldown
	print("[Enemy] 🔍 听到噪音，前往调查: ", investigate_target)
	_change_state(State.INVESTIGATE)

func _update_suspect(delta: float) -> void:
	if player == null or _is_player_hidden():
		_suspect_timer = 0.0
		return

	var dist: float = global_position.distance_to(player.global_position)
	if dist > _effective_suspect_range():
		_suspect_timer = 0.0
		return

	if _noise == null:
		return

	# 玩家跑步声（来自玩家本体）
	var loudness: float = _noise.get_loudest_from_source(global_position, player, _effective_suspect_range())
	# 挖矿是高噪音的暴露行为：调查/搜索阶段范围内挖矿直接视作可疑信号
	if player.has_method("is_mining") and player.is_mining():
		loudness = max(loudness, _noise.MINE)

	if loudness >= suspect_noise_floor:
		_suspect_timer += delta
		if _suspect_timer >= suspect_confirm_time:
			print("[Enemy] 👂 可疑声音确认，开始猎杀")
			_enter_chase()
	else:
		_suspect_timer = 0.0

func _patrol_noise_threshold(distance: float) -> float:
	if distance >= detection_range:
		return max_noise_threshold
	var t: float = clamp(distance / detection_range, 0.0, 1.0)
	return min_noise_threshold + (max_noise_threshold - min_noise_threshold) * t

func _effective_exposure_range() -> float:
	if _stability and _stability.has_method("get_detection_range_multiplier"):
		return exposure_range * _stability.get_detection_range_multiplier()
	return exposure_range

func _effective_detection_range() -> float:
	if _stability and _stability.has_method("get_detection_range_multiplier"):
		return detection_range * _stability.get_detection_range_multiplier()
	return detection_range

func _effective_suspect_range() -> float:
	if _stability and _stability.has_method("get_detection_range_multiplier"):
		return suspect_range * _stability.get_detection_range_multiplier()
	return suspect_range

func _effective_noise_threshold(distance: float) -> float:
	if _stability and _stability.has_method("get_noise_threshold_multiplier"):
		return _patrol_noise_threshold(distance) * _stability.get_noise_threshold_multiplier()
	return _patrol_noise_threshold(distance)

# ============ 状态行为 ============

func _patrol(delta: float) -> void:
	# 随机停顿：原地东张西望，表现"调查"
	if _patrol_pausing:
		velocity = Vector2.ZERO
		_patrol_pause_remaining -= delta
		_patrol_look_timer -= delta
		if _patrol_look_timer <= 0.0:
			_patrol_look_timer = patrol_look_interval
			facing_dir = ["f", "b", "l", "r"][randi() % 4]
		if _patrol_pause_remaining <= 0.0:
			_patrol_pausing = false
			_schedule_next_pause()
		return

	_patrol_pause_timer -= delta
	if _patrol_pause_timer <= 0.0:
		_patrol_pausing = true
		_patrol_pause_remaining = randf_range(patrol_pause_min_duration, patrol_pause_max_duration)
		_patrol_look_timer = 0.0
		velocity = Vector2.ZERO
		return

	if not path_follow:
		velocity = Vector2.ZERO
		return
	path_index += patrol_speed * delta / max(path.curve.get_baked_length(), 1.0)
	path_follow.progress_ratio = fmod(path_index, 1.0)
	var target_pos: Vector2 = path_follow.global_position
	var direction: Vector2 = (target_pos - global_position).normalized()
	velocity = direction * patrol_speed
	_face(direction)

func _schedule_next_pause() -> void:
	_patrol_pause_timer = randf_range(patrol_pause_min_interval, patrol_pause_max_interval)

func _investigate(_delta: float) -> void:
	var distance: float = global_position.distance_to(investigate_target)
	if distance <= investigate_arrive_distance:
		print("[Enemy] 🔍 到达噪音点，开始搜索")
		last_known_position = investigate_target
		_begin_search()
		return

	var direction: Vector2 = (investigate_target - global_position).normalized()
	velocity = direction * investigate_speed
	_face(direction)

func _chase(_delta: float) -> void:
	if player == null:
		_begin_search()
		return

	if _is_player_hidden():
		print("[Enemy] 玩家躲藏，丢失目标")
		last_known_position = player.global_position
		_begin_search()
		return

	var distance: float = global_position.distance_to(player.global_position)
	if distance > chase_lose_distance:
		print("[Enemy] 🏃 玩家脱离猎杀范围")
		last_known_position = player.global_position
		_begin_search()
		return

	# 贴近且冷却结束 → 发起攻击
	if distance <= attack_range and _attack_cooldown_timer <= 0.0:
		_begin_attack()
		return

	var direction: Vector2 = (player.global_position - global_position).normalized()
	velocity = direction * chase_speed
	_face(direction)

func _begin_attack() -> void:
	_attack_timer = 0.0
	_attack_has_hit = false
	if player:
		_attack_dir = (player.global_position - global_position).normalized()
	_change_state(State.ATTACK)

func _attack(delta: float) -> void:
	_attack_timer += delta

	# 出手窗口内沿锁定方向前冲，前后静止
	var lunge_end: float = attack_windup + 0.15
	if _attack_timer >= attack_windup and _attack_timer < lunge_end:
		var lunge_speed: float = attack_lunge_distance / 0.15
		velocity = _attack_dir * lunge_speed
	else:
		velocity = Vector2.ZERO

	# 出手帧结算命中
	if not _attack_has_hit and _attack_timer >= attack_windup:
		_attack_has_hit = true
		_resolve_attack_hit()

	# 攻击结束 → 进入冷却并回到猎杀
	if _attack_timer >= attack_duration:
		_attack_cooldown_timer = attack_cooldown
		velocity = Vector2.ZERO
		_change_state(State.CHASE)

func _resolve_attack_hit() -> void:
	if player == null or _is_player_hidden():
		return
	if global_position.distance_to(player.global_position) > attack_hit_radius:
		return
	if player.has_method("take_hit"):
		player.take_hit(global_position, knockback_force)
	if player.has_method("take_damage"):
		var dmg: float = attack_damage
		var rt: Node = get_node_or_null("/root/GameRuntime")
		if rt:
			var esys: Object = rt.get("equipment_system")
			if esys:
				dmg *= (1.0 - float(esys.get_damage_reduction()))
		player.take_damage(maxf(1.0, dmg))
	print("[Enemy] 🗡️ 命中玩家")

func _search(delta: float) -> void:
	_search_timer += delta

	var to_target: Vector2 = last_known_position - global_position
	var dist: float = to_target.length()
	var stop_dist: float = search_stop_distance
	if _is_player_hidden():
		stop_dist = max(stop_dist, hidden_approach_cap)

	if dist > stop_dist:
		var direction: Vector2 = to_target.normalized()
		velocity = direction * search_move_speed
		_face(direction)
	else:
		velocity = Vector2.ZERO

	if _search_timer >= search_duration:
		print("[Enemy] 🔎 搜索结束，回归路线")
		_change_state(State.RETURN)

func _return_to_path(_delta: float) -> void:
	if not path_follow:
		_change_state(State.PATROL)
		return
	path_follow.progress_ratio = fmod(path_index, 1.0)
	var target_pos: Vector2 = path_follow.global_position
	var distance: float = global_position.distance_to(target_pos)
	if distance < 10.0:
		_change_state(State.PATROL)
		return
	var direction: Vector2 = (target_pos - global_position).normalized()
	velocity = direction * return_speed
	_face(direction)

# ============ 辅助 ============

func _is_player_hidden() -> bool:
	return player != null and player.has_method("is_hidden") and player.is_hidden()

func _enter_chase() -> void:
	if player:
		last_known_position = player.global_position
	_change_state(State.CHASE)

func _begin_search() -> void:
	_search_timer = 0.0
	_patrol_detection_cooldown = patrol_detection_cooldown_time
	_change_state(State.SEARCH)

func _face(direction: Vector2) -> void:
	if direction.length() > 0.01:
		facing_dir = _dir_suffix(direction)

func _dir_suffix(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "r" if v.x > 0 else "l"
	return "f" if v.y > 0 else "b"

# ============ 调试绘制 ============

func _process(_delta: float) -> void:
	if show_debug_ranges:
		queue_redraw()

func _draw() -> void:
	if not show_debug_ranges:
		return

	# 听觉检测范围 — 黄色虚线大圈
	draw_arc(Vector2.ZERO, detection_range, 0, TAU, 64, Color(1.0, 0.9, 0.0, 0.3), 1.5)

	# 暴露检测范围 — 红色半透明小圈（视线/贴身暴露）
	draw_circle(Vector2.ZERO, exposure_range, Color(0.9, 0.15, 0.1, 0.12))
	draw_arc(Vector2.ZERO, exposure_range, 0, TAU, 32, Color(0.9, 0.15, 0.1, 0.5), 1.5)

# ============ 动画 ============
func _update_animation() -> void:
	if sprite == null:
		return
	# 攻击锁定出手方向；否则速度足够大时由速度更新朝向，静止保留上一朝向
	if current_state == State.ATTACK:
		facing_dir = _dir_suffix(_attack_dir)
	elif velocity.length() > FACE_THRESHOLD:
		facing_dir = _dir_suffix(velocity)

	var anim_name: String = _anim_category() + "_" + facing_dir
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim_name):
		return
	if sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)

func _anim_category() -> String:
	match current_state:
		State.ATTACK:
			return "attack"
		State.CHASE:
			return "chase"
		State.PATROL:
			return "idle" if _patrol_pausing or velocity.length() <= FACE_THRESHOLD else "patrol"
		State.INVESTIGATE, State.SEARCH, State.RETURN:
			return "patrol" if velocity.length() > FACE_THRESHOLD else "idle"
	return "idle"

func _change_state(new_state: State) -> void:
	if new_state == current_state:
		return
	print("[Enemy] 🔄 状态: ", _state_name(current_state), " → ", _state_name(new_state))
	current_state = new_state

func _state_name(state: State) -> String:
	match state:
		State.PATROL: return "巡逻"
		State.INVESTIGATE: return "调查"
		State.CHASE: return "猎杀"
		State.SEARCH: return "搜索"
		State.RETURN: return "回归"
		State.ATTACK: return "攻击"
	return "未知"
