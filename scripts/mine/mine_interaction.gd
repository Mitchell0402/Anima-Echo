extends Node

## 矿山交互。玩家进入范围后按住 interact(E) 开采，松手停止并回退当前段。
## 通过玩家状态机锁定移动（player.enter_mining / exit_mining），
## 不再使用 set_physics_process(false) 或 meta 标记。

@export var mining_speed: float = 0.5

@onready var stats: Node = $"../MineStats"
@onready var area: Area2D = get_parent() as Area2D
@onready var progress_ui: Control = $"../ProgressUI"
@onready var _noise: Node = get_node_or_null("/root/NoiseSystem")

const MINE_NOISE_INTERVAL: float = 0.1

enum State { IDLE, MINING }
var current_state: State = State.IDLE
var player_in_range: bool = false
var cached_player_body: CharacterBody2D = null

var mine_noise_timer: float = 0.0

signal mining_started
signal mining_stopped(rollback: bool)

func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	stats.mining_completed.connect(_on_mining_completed)

func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range or not event.is_action_pressed("interact"):
		return
	if event is InputEventKey and event.echo:
		return

	match current_state:
		State.IDLE:
			_start_mining()
		State.MINING:
			# 挖矿中再次按下不处理（松手才停止）
			pass

func _process(delta: float) -> void:
	if current_state != State.MINING:
		return

	# 玩家状态被外部打断（死亡 / 受击等）时干净结束挖矿
	if cached_player_body and cached_player_body.has_method("is_mining") and not cached_player_body.is_mining():
		_stop_mining(true)
		return

	# 挖矿噪音（事件式全局）
	mine_noise_timer += delta
	if mine_noise_timer >= MINE_NOISE_INTERVAL:
		mine_noise_timer = 0.0
		if _noise:
			_noise.emit_noise(get_parent().global_position, _noise.MINE)

	if Input.is_action_pressed("interact"):
		stats.add_progress(mining_speed * delta)
		progress_ui.update_progress(stats.current_progress, stats.get_max_progress())
	else:
		_stop_mining(true)

func _start_mining() -> void:
	if cached_player_body == null:
		return
	# 只有玩家处于自由状态时才能开始挖矿
	if cached_player_body.has_method("enter_mining") and not cached_player_body.enter_mining():
		return
	current_state = State.MINING
	mine_noise_timer = 0.0
	print("[Mine] 开始开采 | 进度: %.2f/%.2f" % [stats.current_progress, stats.get_max_progress()])
	mining_started.emit()

func _stop_mining(should_rollback: bool) -> void:
	current_state = State.IDLE
	mine_noise_timer = 0.0
	if should_rollback and stats.has_method("rollback_to_previous_segment"):
		stats.rollback_to_previous_segment()
	progress_ui.update_progress(stats.current_progress, stats.get_max_progress())
	_release_player()
	mining_stopped.emit(should_rollback)

func _release_player() -> void:
	if cached_player_body and cached_player_body.has_method("exit_mining"):
		cached_player_body.exit_mining()

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_in_range = true
		cached_player_body = body as CharacterBody2D
		print("[Mine] 玩家进入交互范围 | ", get_parent().name)

func _on_body_exited(body: Node2D) -> void:
	if body == cached_player_body:
		player_in_range = false
		print("[Mine] 玩家离开交互范围 | ", get_parent().name)
		if current_state == State.MINING:
			_stop_mining(true)
		cached_player_body = null

func _on_mining_completed() -> void:
	current_state = State.IDLE
	mine_noise_timer = 0.0
	_release_player()
	if progress_ui:
		progress_ui.visible = false
	get_parent().call_deferred("queue_free")
