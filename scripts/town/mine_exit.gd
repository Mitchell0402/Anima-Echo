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
	# End the mine run before leaving the scene. This dumps the hotbar into
	# the warehouse. If the warehouse is full, the untransferred items
	# remain in the hotbar and the player will see them on the next town
	# visit (the hotbar is the in-mine collection, which the town scene
	# does not show, so a toast is the right channel for the warning).
	var runtime: Node = get_node_or_null("/root/GameRuntime")
	if runtime != null and runtime.has_method("end_mine_run"):
		var leftover: int = int(runtime.end_mine_run())
		if leftover > 0:
			print("[Minecart] %d item(s) could not be transferred to the warehouse and remain in the hotbar." % leftover)
	get_tree().change_scene_to_file(target_scene)
