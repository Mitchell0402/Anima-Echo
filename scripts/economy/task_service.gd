extends RefCounted

var catalog: Object
var transactions: Object
var event_bus: Object
var source_collection: Object
var source_name: String = "warehouse"
var _states: Dictionary = {}

## Daily story task pacing. Tasks are queued on claim_reward() and
## unlocked on day start, up to STORY_TASKS_PER_DAY at a time.
const STORY_TASKS_PER_DAY: int = 2
var _story_unlock_queue: Array[String] = []  # pending story task IDs waiting to be unlocked
var _last_queue_day: int = -1                 # day_count when queue was last processed


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
				"objective_id": str(objective.get("id", "")),
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
		# Store progress under the objective id so the task panel
		# and _is_task_complete_for_source can read it.
		var obj_id: String = str(requirement.get("objective_id", ""))
		if obj_id != "":
			progress[obj_id] = int(requirement.get("quantity", 0))
		# Keep the legacy key as well for backward compatibility.
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
	# Queue the next story tasks instead of auto-accepting them.
	# They will be unlocked on the next day start.
	var unlocks: Array = task.get("unlocks", [])
	for next_id in unlocks:
		var next_tid: String = str(next_id)
		if not _states.has(next_tid) and next_tid not in _story_unlock_queue:
			_story_unlock_queue.append(next_tid)
	return {"ok": true, "task_id": task_id}


## Called by the town scene on every day start (sleep_to_morning).
## Unlocks up to STORY_TASKS_PER_DAY new story tasks, but only if
## all previously unlocked story tasks have been completed.
func process_story_queue(day_count: int) -> void:
	# Prevent double-processing within the same day.
	if _last_queue_day == day_count:
		return
	_last_queue_day = day_count

	# If there are any incomplete story tasks, don't unlock new ones.
	# Player must finish yesterday's tasks first.
	if get_active_story_task_count() > 0:
		return

	# Dequeue up to the daily limit.
	var unlocked := 0
	while unlocked < STORY_TASKS_PER_DAY and not _story_unlock_queue.is_empty():
		var next_id: String = _story_unlock_queue[0] as String
		_story_unlock_queue.remove_at(0)
		accept_task(next_id)
		unlocked += 1


## Returns how many story tasks are currently active (not completed).
func get_active_story_task_count() -> int:
	var count := 0
	for task_id in _states.keys():
		var s: Dictionary = _states[task_id]
		if s.get("state", "") == "active" and _is_story_task(task_id):
			count += 1
	return count


## Returns true when no story tasks are active and the unlock queue is empty.
## Used by the town scene to show the "go mining" hint.
func is_story_content_exhausted() -> bool:
	return get_active_story_task_count() == 0 and _story_unlock_queue.is_empty()


# ---- Internal helpers ----

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


func _is_task_complete_for_source(task_id: String, task: Dictionary) -> bool:
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
				var item_id: String = str(objective.get("item_id", ""))
				var required: int = int(objective.get("count", 1))
				# Check recorded progress first (set by deliver_items
				# before claim_reward is called), then fall back to
				# warehouse check for list_deliverable_tasks.
				var obj_id: String = str(objective.get("id", ""))
				if obj_id != "" and int(progress.get(obj_id, 0)) >= required:
					continue
				if int(progress.get("deliver_%s" % item_id, 0)) >= required:
					continue
				if source_collection != null and source_collection.has_method("has_item"):
					if not source_collection.has_item(item_id, required):
						return false
	return true


func _is_daily_task(task_id: String) -> bool:
	var task: Dictionary = catalog.get_task(task_id)
	if task.is_empty():
		return false
	var flags: Array = task.get("flags", [])
	return "daily" in flags


func _is_story_task(task_id: String) -> bool:
	var task: Dictionary = catalog.get_task(task_id)
	if task.is_empty():
		return false
	var flags: Array = task.get("flags", [])
	return "story" in flags


func _is_npc_task(task_id: String) -> bool:
	var task: Dictionary = catalog.get_task(task_id)
	if task.is_empty():
		return false
	var flags: Array = task.get("flags", [])
	return "npc" in flags


func refresh_daily_tasks() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var to_erase: Array = []
	for task_id in _states.keys():
		var s: Dictionary = _states[task_id]
		if s.get("state", "") == "active" and _is_daily_task(task_id):
			to_erase.append(task_id)
	for task_id in to_erase:
		_states.erase(task_id)
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


## Called by the town scene on every day start.
## Scans all NPC tasks and accepts the first uncompleted tier
## whose affection_required <= current affection for that NPC,
## provided the NPC does not already have an active NPC task.
## Takes an affection object to read current values.
func refresh_npc_tasks(affection: Object) -> void:
	if affection == null:
		return
	# Find which NPCs already have an active NPC task.
	var busy_npcs: Array[String] = []
	for task_id in _states.keys():
		var s: Dictionary = _states[task_id]
		if s.get("state", "") == "active" and _is_npc_task(task_id):
			var task: Dictionary = catalog.get_task(task_id)
			var npc: String = str(task.get("npc_id", ""))
			if npc != "":
				busy_npcs.append(npc)
	# Scan all NPC tasks from the catalog and accept one per NPC.
	for task_variant in catalog.get_tasks():
		var task: Dictionary = task_variant
		if not _is_npc_task(str(task.get("id", ""))):
			continue
		var npc_id: String = str(task.get("npc_id", ""))
		if npc_id in busy_npcs:
			continue
		var required: int = int(task.get("affection_required", 0))
		var tier: int = int(task.get("tier", 1))
		var current_aff: int = affection.get_affection(npc_id) if affection.has_method("get_affection") else 0
		if current_aff < required:
			continue
		# Check if any earlier tier for this NPC is not yet completed.
		if tier > 1:
			var earlier_completed: bool = true
			for other_variant in catalog.get_tasks():
				var other: Dictionary = other_variant
				if str(other.get("npc_id", "")) != npc_id:
					continue
				if not _is_npc_task(str(other.get("id", ""))):
					continue
				var other_tier: int = int(other.get("tier", 1))
				if other_tier >= tier:
					continue
				var other_state: Dictionary = _states.get(str(other.get("id", "")), {})
				if str(other_state.get("state", "")) != "completed":
					earlier_completed = false
					break
			if not earlier_completed:
				continue
		accept_task(str(task.get("id", "")))
		busy_npcs.append(npc_id)


func _fail(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": code, "message": message}
