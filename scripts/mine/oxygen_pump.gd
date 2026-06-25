extends Area2D

## 氧气泵。玩家靠近按 E 交互，回满氧气后自毁。
## 默认一次性使用（one_shot=true）。

@export var one_shot: bool = true

var _player_in_range: CharacterBody2D = null
var _oxygen: Node = null


func _ready() -> void:
	_oxygen = get_node_or_null("/root/OxygenSystem")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("interactables")


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range == null:
		return
	if not event.is_action_pressed("interact"):
		return
	if event is InputEventKey and event.echo:
		return

	if _oxygen and _oxygen.has_method("refill"):
		_oxygen.refill()
		print("[OxygenPump] 氧气回满")

	if one_shot:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		_player_in_range = body as CharacterBody2D


func _on_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null
