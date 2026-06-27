extends RefCounted

var catalog: Object
var transactions: Object
var event_bus: Object
var source_collection: Object  # GameInventory instance used to satisfy delivery requirements.
                                # In town this is the warehouse; in mine it is the hotbar. Set by
                                # the caller (GameRuntime / town scene / task popup) before
                                # calling deliver_items or list_deliverable_tasks.
var source_name: String = "warehouse"  # String the transaction service uses to pick the right
                                        # collection ("warehouse" or "inventory" or "hotbar").
var _states: Dictionary = {}


func _init(game_catalog: Object = null, transaction_service: Object = null, game_event_bus: Object = null) -> void:
	catalog = game_catalog
	transactions = transaction_service
	event_bus = game_event_bus
	if event_bus != null:
		event_bus.game_event.connect(_on_game_event)


func set_source_collection(collection: Object, name: String = "warehouse") -> void:
	source_collection = collection
	source_name = name


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


# Returns the subset of active tasks that can be delivered right now, i.e.
# the player has the required items in the configured source_collection
# (warehouse in town, hotbar in mine). Used by the task_clerk NPC popup.
func list_deliverable_tasks() -> Array:
	var result: Array = []
	for task_id in _states.keys():
		var state: Dictionary = _states.get(task_id, {})
		if str(state.get("state", "")) != "active":
			continue
		var task: Dictionary = catalog.get_task(str(task_id))
		if task.is_empty():
			continue
		if _is_task_complete_for_source(task_id, task):
			result.append(task.duplicate(true))
	return result


# Returns the subset of active tasks that are NOT deliverable right now.
# Used by the task_clerk NPC popup to show "needs more" rows in grey.
func list_pending_tasks() -> Array:
	var result: Array = []
	for task_id in _states.keys():
		var state: Dictionary = _states.get(task_id, {})
		if str(state.get("state", "")) != "active":
			continue
		var task: Dictionary = catalog.get_task(str(task_id))
		if task.is_empty():
			continue
		if not _is_task_complete_for_source(task_id, task):
			result.append(task.duplicate(true))
	return result


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
	var request: Dictionary = {
		"type": "deliver_task_items",
		"task_id": task_id,
		"requirements": requirements,
	}
	if source_collection != null:
		request["source"] = source_name
	var result: Dictionary = transactions.apply(request)
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
	if not _is_task_complete_for_source(task_id, task):
		return _fail("task_incomplete", "Task is incomplete.")
	var request: Dictionary = {
		"type": "grant_task_rewards",
		"task_id": task_id,
		"rewards": task.get("rewards", []),
		"currency_reward": int(task.get("currency_reward", 0)),
	}
	if source_collection != null:
		request["destination"] = source_name
	var result: Dictionary = transactions.apply(request)
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
						progress[key] = int(progress.get(key, 0)) + int(str(objective.get("field", "")) if false else payload.get(str(objective.get("field", "")), 0))
		state["progress"] = progress
		_states[task_id] = state


func _is_task_complete(task_id: String, task: Dictionary) -> bool:
	return _is_task_complete_for_source(task_id, task)


# Returns true if the active task's requirements are all satisfied by
# the current source_collection (warehouse in town, hotbar in mine).
func _is_task_complete_for_source(task_id: String, task: Dictionary) -> bool:
	var state: Dictionary = _states.get(task_id, {})
	if str(state.get("state", "")) != "active":
		return false
	# For event-driven objectives, the in-state progress is authoritative.
	# For deliver_item objectives, check both the recorded progress and the
	# source_collection so the player can deliver immediately without first
	# having to call a "claim" hook that records the delivery in advance.
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
				var item_id: String = str(objective.get("item_id", ""))
				var required: int = int(objective.get("count", 1))
				if source_collection != null and source_collection.has_method("has_item"):
					if not source_collection.has_item(item_id, required):
						return false
				elif int(progress.get("deliver_%s" % item_id, 0)) < required:
					return false
	return true


func refresh_daily_tasks() -> Dictionary:
	# Wipe old active tasks, draw 3 new ones from the random pool.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Cancel all active tasks
	for task_id in _states.keys():
		var s: Dictionary = _states[task_id]
		if s.get("state", "") == "active":
			_states.erase(task_id)
	# Draw from "daily_task" pool
	var pool: Array = catalog.get_tasks_for_pool("daily_pool")
	if pool.is_empty():
		return {"ok": true, "drawn": 0}
	var drawn: Array = []
	for _i in range(3):
		if pool.is_empty():
			break
		var idx: int = rng.randi() % pool.size()
		var task: Dictionary = pool[idx]
		var tid: String = str(task.get("id", ""))
		accept_task(tid)
		drawn.append(tid)
		pool.remove_at(idx)
	return {"ok": true, "drawn": drawn}


func _source_name() -> String:
	return source_name


func _fail(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": code, "message": message}
