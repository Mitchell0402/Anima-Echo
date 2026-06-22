extends RefCounted

signal game_event(event_name: String, payload: Dictionary)

var history: Array[Dictionary] = []


func emit_game_event(event_name: String, payload: Dictionary = {}) -> void:
	var event := {
		"name": event_name,
		"payload": payload.duplicate(true),
	}
	history.append(event)
	game_event.emit(event_name, payload.duplicate(true))


func get_events(event_name: String = "") -> Array:
	if event_name.is_empty():
		return history.duplicate(true)
	var matches: Array = []
	for event_variant in history:
		var event: Dictionary = event_variant
		if str(event.get("name", "")) == event_name:
			matches.append(event.duplicate(true))
	return matches
