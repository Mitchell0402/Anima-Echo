extends Node

## 矿山交互。玩家进入范围后按住 interact(E) 开采，松手停止并回退当前段。
## 新增QTE机制：挖矿中随机弹出圆形指针QTE，按空格命中成功区获得进度加速，
## 失败则回退到上一段起点。

@export var mining_speed: float = 0.2

# ---- QTE 配置 ----
@export var qte_min_interval: float = 1.2       # QTE最短间隔（秒）
@export var qte_max_interval: float = 2.5       # QTE最长间隔（秒）
@export var first_qte_delay: float = 1.0        # 首次QTE延迟（秒）
@export var rotation_speed: float = 240.0       # 指针转速（度/秒）
@export var success_zone_start: float = 90.0    # 成功区起始角度默认值（0=12点，顺时针）
@export var success_zone_size: float = 65.0     # 成功区宽度（度）
@export var qte_bonus_progress: float = 0.5     # QTE成功奖励进度量
@export var qte_cooldown: float = 0.6           # QTE失败后冷却（秒）

@onready var stats: Node = $"../MineStats"
@onready var area: Area2D = get_parent() as Area2D
@onready var progress_ui: Control = $"../ProgressUI"
@onready var qte_ui: Control = $"../QteCircle"
@onready var _noise: Node = get_node_or_null("/root/NoiseSystem")

const MINE_NOISE_INTERVAL: float = 0.1

enum State { IDLE, MINING, QTE_ACTIVE }
var current_state: State = State.IDLE
var player_in_range: bool = false
var cached_player_body: CharacterBody2D = null

var mine_noise_timer: float = 0.0

# QTE 运行时变量
var qte_trigger_timer: float = 0.0
var qte_rotation_accumulated: float = 0.0
var qte_current_angle: float = 0.0
var qte_current_zone_start: float = 90.0
var qte_in_cooldown: bool = false
var qte_first_triggered: bool = false

signal mining_started
signal mining_stopped(rollback: bool)


func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	stats.mining_completed.connect(_on_mining_completed)


func _unhandled_input(event: InputEvent) -> void:
	# E键 — 启动挖矿
	if player_in_range and event.is_action_pressed("interact"):
		if event is InputEventKey and event.echo:
			return
		if current_state == State.IDLE:
			_start_mining()

	# 空格键 — QTE响应
	if event.is_action_pressed("qte_action"):
		if current_state == State.QTE_ACTIVE:
			_on_qte_space_pressed()


func _process(delta: float) -> void:
	match current_state:
		State.IDLE:
			return
		State.MINING:
			_process_mining(delta)
		State.QTE_ACTIVE:
			_process_qte(delta)


# ---- MINING 状态处理 ----

func _process_mining(delta: float) -> void:
	# 玩家状态被外部打断（死亡/受击）
	if cached_player_body and cached_player_body.has_method("is_mining") and not cached_player_body.is_mining():
		_stop_mining(true)
		return

	# 挖矿噪音
	mine_noise_timer += delta
	if mine_noise_timer >= MINE_NOISE_INTERVAL:
		mine_noise_timer = 0.0
		if _noise:
			_noise.emit_noise(get_parent().global_position, _noise.MINE)

	# 检查E键是否按住
	if Input.is_action_pressed("interact"):
		stats.add_progress(mining_speed * delta)
		progress_ui.update_progress(stats.current_progress, stats.get_max_progress())
	else:
		_stop_mining(true)
		return

	# QTE触发计时
	if not qte_in_cooldown:
		qte_trigger_timer -= delta
		if qte_trigger_timer <= 0.0:
			_trigger_qte()


# ---- QTE_ACTIVE 状态处理 ----

func _process_qte(delta: float) -> void:
	# 玩家状态检查
	if cached_player_body and cached_player_body.has_method("is_mining") and not cached_player_body.is_mining():
		_cancel_qte()
		_stop_mining(true)
		return

	# 噪音（QTE期间继续）
	mine_noise_timer += delta
	if mine_noise_timer >= MINE_NOISE_INTERVAL:
		mine_noise_timer = 0.0
		if _noise:
			_noise.emit_noise(get_parent().global_position, _noise.MINE)

	# E键松手 = 停止挖矿
	if not Input.is_action_pressed("interact"):
		_cancel_qte()
		_stop_mining(true)
		return

	# 基础进度仍然累积（方案A：挖矿不暂停）
	stats.add_progress(mining_speed * delta)
	progress_ui.update_progress(stats.current_progress, stats.get_max_progress())

	# 指针旋转
	var prev_angle := qte_current_angle
	var angle_delta := rotation_speed * delta
	qte_current_angle = fmod(qte_current_angle + angle_delta, 360.0)
	qte_rotation_accumulated += angle_delta
	if qte_ui and qte_ui.has_method("update_pointer"):
		qte_ui.update_pointer(qte_current_angle)

	# 指针刚越过成功区末尾 → 立即判定失败
	var zone_end := fmod(qte_current_zone_start + success_zone_size, 360.0)
	if prev_angle <= zone_end and qte_current_angle > zone_end:
		_on_qte_failed()
		return


# ---- 挖矿启动/停止 ----

func _start_mining() -> void:
	if cached_player_body == null:
		return
	if cached_player_body.has_method("enter_mining") and not cached_player_body.enter_mining():
		return
	current_state = State.MINING
	mine_noise_timer = 0.0
	qte_first_triggered = false
	qte_in_cooldown = false
	_reset_qte_timer()
	print("[Mine] 开始开采 | 进度: %.2f/%.2f" % [stats.current_progress, stats.get_max_progress()])
	mining_started.emit()


func _stop_mining(should_rollback: bool) -> void:
	current_state = State.IDLE
	mine_noise_timer = 0.0
	if qte_ui and qte_ui.has_method("hide_qte"):
		qte_ui.hide_qte()
	if should_rollback and stats.has_method("rollback_to_previous_segment"):
		stats.rollback_to_previous_segment()
	progress_ui.update_progress(stats.current_progress, stats.get_max_progress())
	_release_player()
	mining_stopped.emit(should_rollback)


# ---- QTE 流程控制 ----

func _trigger_qte() -> void:
	current_state = State.QTE_ACTIVE
	qte_current_angle = 0.0
	qte_rotation_accumulated = 0.0
	qte_first_triggered = true
	# 成功区位置随机（避开 0°=12点起始位置，让玩家有反应时间离开起点后进入）
	qte_current_zone_start = randf_range(20.0, 340.0 - success_zone_size)
	if qte_ui and qte_ui.has_method("show_qte"):
		qte_ui.show_qte(qte_current_zone_start, success_zone_size)
	print("[Mine QTE] ⭕ QTE触发！按空格命中黄色区域 (起始=%d°)" % int(qte_current_zone_start))


func _on_qte_space_pressed() -> void:
	var angle := qte_current_angle
	var zone_end := fmod(qte_current_zone_start + success_zone_size, 360.0)

	var in_zone: bool
	if qte_current_zone_start <= zone_end:
		in_zone = angle >= qte_current_zone_start and angle <= zone_end
	else:
		# 跨越 0° 边界的情况
		in_zone = angle >= qte_current_zone_start or angle <= zone_end

	if in_zone:
		_on_qte_success()
	else:
		_on_qte_failed()


func _on_qte_success() -> void:
	print("[Mine QTE] ✅ QTE成功！奖励进度 +%.2f" % qte_bonus_progress)
	stats.add_progress(qte_bonus_progress)
	progress_ui.update_progress(stats.current_progress, stats.get_max_progress())
	_exit_qte()


func _on_qte_failed() -> void:
	print("[Mine QTE] ❌ QTE失败！回退到上一段")
	if stats.has_method("rollback_to_previous_segment"):
		stats.rollback_to_previous_segment()
	progress_ui.update_progress(stats.current_progress, stats.get_max_progress())
	_exit_qte()
	# 失败冷却（使用信号回调，避免 async 上下文冲突）
	qte_in_cooldown = true
	get_tree().create_timer(qte_cooldown).timeout.connect(_on_qte_cooldown_end)


func _on_qte_cooldown_end() -> void:
	qte_in_cooldown = false


func _cancel_qte() -> void:
	if qte_ui and qte_ui.has_method("hide_qte"):
		qte_ui.hide_qte()


func _exit_qte() -> void:
	current_state = State.MINING
	if qte_ui and qte_ui.has_method("hide_qte"):
		qte_ui.hide_qte()
	_reset_qte_timer()


func _reset_qte_timer() -> void:
	if not qte_first_triggered:
		qte_trigger_timer = first_qte_delay
	else:
		qte_trigger_timer = randf_range(qte_min_interval, qte_max_interval)


func _release_player() -> void:
	if cached_player_body and cached_player_body.has_method("exit_mining"):
		cached_player_body.exit_mining()


# ---- 范围检测 ----

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_in_range = true
		cached_player_body = body as CharacterBody2D
		print("[Mine] 玩家进入交互范围 | ", get_parent().name)


func _on_body_exited(body: Node2D) -> void:
	if body == cached_player_body:
		player_in_range = false
		print("[Mine] 玩家离开交互范围 | ", get_parent().name)
		if current_state == State.MINING or current_state == State.QTE_ACTIVE:
			_cancel_qte()
			_stop_mining(true)
		cached_player_body = null


func _on_mining_completed() -> void:
	current_state = State.IDLE
	mine_noise_timer = 0.0
	if qte_ui and qte_ui.has_method("hide_qte"):
		qte_ui.hide_qte()
	_release_player()
	if progress_ui:
		progress_ui.visible = false
	get_parent().call_deferred("queue_free")
