extends RefCounted

var catalog: Object
var transactions: Object
var event_bus: Object
var _states: Dictionary = {}


func _init(game_catalog: Object = null, transaction_service: Object = null, game_event_bus: Object = null) -> void:
	catalog = game_catalog
	transactions = transaction_service
	event_bus = game_event_bus
	if event_bus != null:
		event_bus.game_event.connect(_on_game_event)


func accept_task(task_id: String) -> Dictionary:
	var task: Dictionary = catalog.get_task(task_id)
	if task.is_empty():
		return _fail("task_unknown", "Unknown task: %s" % task_id)
	var existing: Dictionary = _states.get(task_id, {})
	if existing.get("state", "") == "completed":
		return _fail("task_completed", "Task already completed.")
	_states[task_id] = {
		"state": "active",
		"progress": {},
	}
	return {"ok": true, "task_id": task_id}


func get_task_state(task_id: String) -> Dictionary:
	return _states.get(task_id, {"state": "available", "progress": {}}).duplicate(true)


func list_tasks() -> Array:
	return catalog.get_tasks()


func dispose() -> void:
	if event_bus != null and event_bus.game_event.is_connected(_on_game_event):
		event_bus.game_event.disconnect(_on_game_event)


func deliver_items(task_id: String) -> Dictionary:
	var task: Dictionary = catalog.get_task(task_id)
	if task.is_empty():
		return _fail("task_unknown", "Unknown task: %s" % task_id)
	var requirements: Array = []
	for objective_variant in task.get("objectives", []):
		var objective: Dictionary = objective_variant
		if str(objective.get("type", "")) == "deliver_item":
			requirements.append({
				"item_id": str(objective.get("item_id", "")),
				"quantity": int(objective.get("count", 1)),
			})
	var result: Dictionary = transactions.apply({
		"type": "deliver_task_items",
		"task_id": task_id,
		"requirements": requirements,
	})
	if not result.get("ok", false):
		return result
	var state: Dictionary = _states.get(task_id, {"state": "active", "progress": {}})
	var progress: Dictionary = state.get("progress", {})
	for requirement_variant in requirements:
		var requirement: Dictionary = requirement_variant
		progress["deliver_%s" % requirement.get("item_id")] = int(requirement.get("quantity", 0))
	state["progress"] = progress
	_states[task_id] = state
	return {"ok": true}


func claim_reward(task_id: String) -> Dictionary:
	var task: Dictionary = catalog.get_task(task_id)
	if task.is_empty():
		return _fail("task_unknown", "Unknown task: %s" % task_id)
	if not _is_task_complete(task_id, task):
		return _fail("task_incomplete", "Task is incomplete.")
	var result: Dictionary = transactions.apply({
		"type": "grant_task_rewards",
		"task_id": task_id,
		"rewards": task.get("rewards", []),
		"currency_reward": int(task.get("currency_reward", 0)),
	})
	if not result.get("ok", false):
		return result
	var state: Dictionary = _states.get(task_id, {})
	state["state"] = "completed"
	_states[task_id] = state
	return {"ok": true, "task_id": task_id}


func _on_game_event(event_name: String, payload: Dictionary) -> void:
	for task_id in _states.keys():
		var state: Dictionary = _states.get(task_id, {})
		if str(state.get("state", "")) != "active":
			continue
		var task: Dictionary = catalog.get_task(str(task_id))
		var progress: Dictionary = state.get("progress", {})
		for objective_variant in task.get("objectives", []):
			var objective: Dictionary = objective_variant
			match str(objective.get("type", "")):
				"event_count":
					if str(objective.get("event", "")) == event_name:
						var key: String = str(objective.get("id", event_name))
						progress[key] = int(progress.get(key, 0)) + int(payload.get("quantity", 1))
				"event_sum":
					if str(objective.get("event", "")) == event_name:
						var key: String = str(objective.get("id", event_name))
						progress[key] = int(progress.get(key, 0)) + int(payload.get(str(objective.get("field", "")), 0))
		state["progress"] = progress
		_states[task_id] = state


func _is_task_complete(task_id: String, task: Dictionary) -> bool:
	var state: Dictionary = _states.get(task_id, {})
	if str(state.get("state", "")) != "active":
		return false
	var progress: Dictionary = state.get("progress", {})
	for objective_variant in task.get("objectives", []):
		var objective: Dictionary = objective_variant
		match str(objective.get("type", "")):
			"event_count":
				if int(progress.get(str(objective.get("id", "")), 0)) < int(objective.get("count", 1)):
					return false
			"event_sum":
				if int(progress.get(str(objective.get("id", "")), 0)) < int(objective.get("target", 1)):
					return false
			"deliver_item":
				var key: String = "deliver_%s" % str(objective.get("item_id", ""))
				if int(progress.get(key, 0)) < int(objective.get("count", 1)):
					return false
	return true


func _fail(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": code,
		"message": message,
	}
