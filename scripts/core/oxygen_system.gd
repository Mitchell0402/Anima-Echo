extends Node

## 氧气系统（Autoload 单例：OxygenSystem）
## 随身氧气槽，在矿洞场景中实时消耗。
## 消耗率 = base_rate × state_multiplier × weight_multiplier。
## 氧气耗尽后渐进扣血，致死回城由 player.die() 处理。

@export var tank_capacity: float = 200.0
@export var base_rate: float = 0.7
@export var suffocation_dps: float = 8.0

const STATE_MULT := {
	"idle": 1.0,
	"walk": 1.0,
	"run": 1.8,
	"mining": 2.0,
	"hidden": 0.4,
	"hurt": 1.0,
	"dead": 0.0,
}

signal oxygen_changed(current: float, maximum: float)
signal oxygen_depleted

var current_oxygen: float = 100.0
var _player: CharacterBody2D = null
var _weight: Node = null
var _last_scene_path: String = ""
var _scene_active: bool = false
var _was_depleted: bool = false


func _ready() -> void:
	_weight = get_node_or_null("/root/WeightSystem")
	current_oxygen = tank_capacity


func _process(delta: float) -> void:
	_check_scene_transition()

	if not _scene_active:
		return

	_cache_player()
	if _player == null or not is_instance_valid(_player):
		_player = null
		return

	if _player.has_method("is_dead") and _player.is_dead():
		return

	# O₂ = 0 → 渐进扣血
	if current_oxygen <= 0.0:
		if not _was_depleted:
			_was_depleted = true
			oxygen_depleted.emit()
		if _player.has_method("take_damage"):
			_player.take_damage(suffocation_dps * delta)
		return

	_was_depleted = false

	# 正常消耗
	var state_mult: float = _resolve_state_multiplier()
	var weight_mult: float = _weight.get_oxygen_multiplier() if _weight else 1.0
	var rate: float = base_rate * state_mult * weight_mult

	current_oxygen = max(0.0, current_oxygen - rate * delta)
	oxygen_changed.emit(current_oxygen, tank_capacity)


func _cache_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D


func _resolve_state_multiplier() -> float:
	if _player == null:
		return STATE_MULT["idle"]
	if _player.has_method("is_mining") and _player.is_mining():
		return STATE_MULT["mining"]
	if _player.has_method("is_hidden") and _player.is_hidden():
		return STATE_MULT["hidden"]
	if _player.has_method("is_hurt") and _player.is_hurt():
		return STATE_MULT["hurt"]
	if _player.has_method("is_dead") and _player.is_dead():
		return STATE_MULT["dead"]
	if not _player.has_method("can_move") or not _player.can_move():
		return STATE_MULT["idle"]
	# FREE + can_move: 通过 velocity 和 walk 按键判断实际活动
	if _player.velocity.length() < 0.1:
		return STATE_MULT["idle"]
	if Input.is_action_pressed("walk"):
		return STATE_MULT["run"]  # walk action = Shift, now means run
	return STATE_MULT["walk"]


func _check_scene_transition() -> void:
	var current: Node = get_tree().current_scene
	if current == null:
		return
	var path: String = current.scene_file_path
	if path == _last_scene_path:
		return
	_last_scene_path = path
	var now_mine: bool = _is_mine_path(path)
	if now_mine and not _scene_active:
		reset_tank()
	_scene_active = now_mine


func _is_mine_path(path: String) -> bool:
	return path.ends_with("test_scene.tscn") or "/mine/" in path


func refill() -> void:
	current_oxygen = tank_capacity
	_was_depleted = false
	oxygen_changed.emit(current_oxygen, tank_capacity)


func reset_tank() -> void:
	current_oxygen = tank_capacity
	_was_depleted = false


func is_in_mine_scene() -> bool:
	return _scene_active


func get_oxygen_ratio() -> float:
	return current_oxygen / tank_capacity if tank_capacity > 0.0 else 0.0
