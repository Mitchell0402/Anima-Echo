extends Node2D

@export_file("*.tscn") var target_scene := "res://scenes/town/mining_town.tscn"
@export var interact_radius := 96.0

var _player: Node2D


func _unhandled_input(event: InputEvent) -> void:
	if not _is_player_in_range():
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		call_deferred("_return_to_town")


func _is_player_in_range() -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return false
	return global_position.distance_to(_player.global_position) <= interact_radius


func _return_to_town() -> void:
	get_tree().change_scene_to_file(target_scene)
