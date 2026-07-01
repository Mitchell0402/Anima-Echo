extends Node

## 音效系统 (Autoload: SfxSystem)
## 管理所有游戏音效的播放，包括采矿、行走、怪物吼叫、场景背景、原石掉落等。
## 作为 Autoload 跨场景持久存在，自动检测场景切换以管理背景音效。

# ---- 预加载音效资源 ----
const SFX_MINING := preload("res://assets/sfx/Mining.wav")
const SFX_WALK := preload("res://assets/sfx/Walk.wav")
const SFX_STONE_L1 := preload("res://assets/sfx/原石Level 1.wav")
const SFX_STONE_L2 := preload("res://assets/sfx/原石Level 2.wav")
const SFX_STONE_L3 := preload("res://assets/sfx/原石Level 3.wav")
const SFX_MONSTER_GROWL := preload("res://assets/sfx/Monster growl.wav")
const SFX_SCENE_BG := preload("res://assets/sfx/Scene background.wav")

# ---- 音量配置 (dB) ----
const VOLUME_MINING := -10.0
const VOLUME_WALK := 0.0
const VOLUME_STONE := 0.0
const VOLUME_MONSTER_GROWL := 0.0
const VOLUME_SCENE_BG := 4.0

# ---- 播放器节点 ----
var _mining_player: AudioStreamPlayer
var _walk_player: AudioStreamPlayer
var _bg_player: AudioStreamPlayer
var _growl_player: AudioStreamPlayer
var _stone_players: Array[AudioStreamPlayer] = []

# ---- 状态 ----
var _growl_timer: float = -1.0
var _stone_round_robin: int = 0

const MINE_SCENE_MARKERS := [
	"test_scene.tscn",
	"dungeon_room.tscn",
]


func _ready() -> void:
	_create_players()
	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_check_scene")


func _create_players() -> void:
	_mining_player = _make_player(VOLUME_MINING)
	_walk_player = _make_player(VOLUME_WALK)
	_bg_player = _make_player(VOLUME_SCENE_BG)
	_growl_player = _make_player(VOLUME_MONSTER_GROWL)

	for _i in range(4):
		var p := _make_player(VOLUME_STONE)
		_stone_players.append(p)


func _make_player(volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	p.volume_db = volume_db
	add_child(p)
	return p


# ---- 公共 API ----

## 开始循环播放采矿音效
func play_mining() -> void:
	if _mining_player.playing:
		return
	if not _mining_player.finished.is_connected(_on_mining_looped):
		_mining_player.finished.connect(_on_mining_looped)
	_mining_player.stream = SFX_MINING
	_mining_player.play()


func _on_mining_looped() -> void:
	_mining_player.play()


## 停止采矿音效
func stop_mining() -> void:
	if not _mining_player.playing:
		return
	if _mining_player.finished.is_connected(_on_mining_looped):
		_mining_player.finished.disconnect(_on_mining_looped)
	_mining_player.stop()


## 播放/更新行走音效。running=true 时加速播放（提高 pitch）。
func play_walk(running: bool = false) -> void:
	var target_pitch := 1.5 if running else 1.0
	if not _walk_player.finished.is_connected(_on_walk_looped):
		_walk_player.finished.connect(_on_walk_looped)

	if _walk_player.playing:
		if not is_equal_approx(_walk_player.pitch_scale, target_pitch):
			_walk_player.pitch_scale = target_pitch
		return
	_walk_player.stream = SFX_WALK
	_walk_player.pitch_scale = target_pitch
	_walk_player.play()


func _on_walk_looped() -> void:
	_walk_player.play()


## 停止行走音效
func stop_walk() -> void:
	if not _walk_player.playing:
		return
	if _walk_player.finished.is_connected(_on_walk_looped):
		_walk_player.finished.disconnect(_on_walk_looped)
	_walk_player.stop()


## 播放原石等级音效（一次性播放，使用轮转池避免同帧互斥）
func play_stone_level(level: int) -> void:
	var stream: AudioStream
	match level:
		1:
			stream = SFX_STONE_L1
		2:
			stream = SFX_STONE_L2
		3:
			stream = SFX_STONE_L3
		_:
			return

	var p := _stone_players[_stone_round_robin]
	_stone_round_robin = (_stone_round_robin + 1) % _stone_players.size()
	p.stream = stream
	p.play()


# ---- 内部逻辑 ----

func _process(delta: float) -> void:
	if _growl_timer > 0.0:
		_growl_timer -= delta
		if _growl_timer <= 0.0:
			_play_growl()
			_growl_timer = randf_range(15.0, 30.0)


func _play_growl() -> void:
	if _growl_player.playing:
		return
	_growl_player.stream = SFX_MONSTER_GROWL
	_growl_player.play()


func _start_scene_bg() -> void:
	if _bg_player.playing:
		return
	if not _bg_player.finished.is_connected(_on_bg_looped):
		_bg_player.finished.connect(_on_bg_looped)
	_bg_player.stream = SFX_SCENE_BG
	_bg_player.play()


func _on_bg_looped() -> void:
	_bg_player.play()


func _stop_scene_bg() -> void:
	if not _bg_player.playing:
		return
	if _bg_player.finished.is_connected(_on_bg_looped):
		_bg_player.finished.disconnect(_on_bg_looped)
	_bg_player.stop()


func _start_growl_timer() -> void:
	_growl_timer = randf_range(15.0, 30.0)


func _stop_growl() -> void:
	_growl_timer = -1.0
	if _growl_player.playing:
		_growl_player.stop()


# ---- 场景切换检测 ----

func _on_scene_changed() -> void:
	_check_scene()


func _check_scene() -> void:
	var current := get_tree().current_scene
	if current == null:
		return
	var path: String = current.scene_file_path
	var in_mine := false
	for marker in MINE_SCENE_MARKERS:
		if path.ends_with(marker):
			in_mine = true
			break

	if in_mine:
		_start_scene_bg()
		_start_growl_timer()
	else:
		_stop_scene_bg()
		_stop_growl()
