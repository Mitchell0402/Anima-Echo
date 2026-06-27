extends RefCounted

const DEFAULT_DATA_PATH := "res://data/game/catalog.json"

var _items: Dictionary = {}
var _loot_tables: Dictionary = {}
var _identify_tables: Dictionary = {}
var _customers: Dictionary = {}
var _tasks: Dictionary = {}


func load_defaults() -> Dictionary:
	return load_from_path(DEFAULT_DATA_PATH)


func load_from_path(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("catalog_file_missing", "Catalog file is missing: %s" % path)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail("catalog_json_invalid", "Catalog JSON root must be an object.")
	_items.clear()
	_loot_tables.clear()
	_identify_tables.clear()
	_customers.clear()
	_tasks.clear()
	_index_by_id(parsed.get("items", []), _items)
	_index_entries(parsed.get("loot_tables", []), _loot_tables)
	_index_entries(parsed.get("identify_tables", []), _identify_tables)
	_index_by_id(parsed.get("customers", []), _customers)
	_index_by_id(parsed.get("night_customers", []), _customers)
	_index_by_id(parsed.get("tasks", []), _tasks)
	if _items.is_empty():
		return _fail("catalog_items_empty", "Catalog must define at least one item.")
	return {"ok": true}


func get_item(item_id: String) -> Dictionary:
	return _items.get(item_id, {}).duplicate(true)


func get_all_items() -> Array:
	return _items.values().duplicate(true)


func get_loot_table(table_id: String) -> Array:
	return _loot_tables.get(table_id, []).duplicate(true)


func get_identify_table(table_id: String) -> Array:
	return _identify_tables.get(table_id, []).duplicate(true)


func get_customer(customer_id: String) -> Dictionary:
	return _customers.get(customer_id, {}).duplicate(true)


func get_customers() -> Array:
	return _customers.values().duplicate(true)

func get_night_customers() -> Array:
	var result: Array = []
	for c in _customers.values():
		if str(c.get("id", "")).begins_with("night_"):
			result.append(c.duplicate(true))
	return result


func get_task(task_id: String) -> Dictionary:
	return _tasks.get(task_id, {}).duplicate(true)


func get_tasks() -> Array:
	return _tasks.values().duplicate(true)

func get_tasks_for_pool(pool_key: String) -> Array:
	var result: Array = []
	for task in _tasks.values():
		var pools: Array = task.get(pool_key, [])
		if not pools.is_empty():
			result.append(task.duplicate(true))
	return result


func has_item(item_id: String) -> bool:
	return _items.has(item_id)


func get_stack_size(item_id: String) -> int:
	var item := get_item(item_id)
	return int(item.get("stack_size", 99))


func roll_weighted(entries: Array, rng: Object) -> Dictionary:
	if entries.is_empty():
		return {}
	var total_weight := 0.0
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		total_weight += maxf(0.0, float(entry.get("weight", 0.0)))
	if total_weight <= 0.0:
		return Dictionary(entries[0]).duplicate(true)
	var roll := _rng_randf(rng) * total_weight
	var cursor := 0.0
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		cursor += maxf(0.0, float(entry.get("weight", 0.0)))
		if roll <= cursor:
			return entry.duplicate(true)
	return Dictionary(entries[entries.size() - 1]).duplicate(true)


func _index_by_id(entries: Array, target: Dictionary) -> void:
	for entry_variant in entries:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var entry_id := str(entry.get("id", ""))
		if entry_id.is_empty():
			continue
		target[entry_id] = entry.duplicate(true)


func _index_entries(entries: Array, target: Dictionary) -> void:
	for entry_variant in entries:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var entry_id := str(entry.get("id", ""))
		if entry_id.is_empty():
			continue
		target[entry_id] = entry.get("entries", []).duplicate(true)


func _rng_randf(rng: Object) -> float:
	if rng != null and rng.has_method("randf"):
		return clampf(float(rng.call("randf")), 0.0, 1.0)
	return randf()


func _fail(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": code,
		"message": message,
	}
