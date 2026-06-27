extends Node

## 背包：12 格，前 unlocked_slots 格可用，其余锁定（局外解锁）。
## 槽位结构：null 或 { "type": String, "data": Dictionary, "count": int }
## 堆叠：按 ItemDatabase 的 stack_key（gem 按等级），未达上限则合并计数。

const MAX_SLOTS: int = 12
@export var unlocked_slots: int = 8

var slots: Array = []

signal inventory_changed

@onready var _db: Node = get_node_or_null("/root/ItemDatabase")
@onready var _runtime: Node = get_node_or_null("/root/GameRuntime")

func _ready() -> void:
	_initialize_inventory()
	if _runtime != null and _runtime.get("catalog") == null and _runtime.has_method("initialize_for_new_game"):
		_runtime.initialize_for_new_game()
	if _runtime != null and _runtime.get("hotbar") != null:
		_runtime.get("hotbar").changed.connect(_sync_from_runtime)
	_sync_from_runtime()

func _initialize_inventory() -> void:
	slots.clear()
	for i in range(MAX_SLOTS):
		slots.append(null)
	print("[背包] 初始化完成，容量: %d（解锁 %d）" % [MAX_SLOTS, unlocked_slots])

func _stack_key(type: String, data: Dictionary) -> String:
	if _db:
		return _db.get_stack_key(type, data)
	return type

func _stack_limit(item_id: String) -> int:
	if _db:
		return _db.get_stack_limit(item_id)
	return 99

# 添加物品（自动堆叠 / 找空格），返回是否成功
func add_item(item_type: String, item_data: Dictionary = {}) -> bool:
	if _runtime != null and _runtime.get("transactions") != null:
		if is_full():
			print("[背包] ❌ 背包已满，无法添加物品")
			return false
		var item_id := _to_runtime_item_id(item_type, item_data)
		var result: Dictionary = _runtime.get("transactions").apply({
			"type": "collect_item",
			"source": "gj_inventory_compat",
			"item_id": item_id,
			"quantity": 1,
			"metadata": item_data.duplicate(true),
		})
		if result.get("ok", false):
			_sync_from_runtime()
			print("[背包] ✅ 收集到统一背包 | %s" % item_id)
			return true
		print("[背包] ❌ 统一背包拒绝添加: %s" % str(result.get("message", result.get("error", ""))))
		return false
	var key: String = _stack_key(item_type, item_data)
	var limit: int = _stack_limit(item_type)

	# 1) 合并到已有同类未满栈
	for i in range(unlocked_slots):
		var s = slots[i]
		if s != null and _stack_key(s["type"], s["data"]) == key and s["count"] < limit:
			s["count"] += 1
			print("[背包] ➕ 堆叠到格子 %d | %s | 数量: %d" % [i, key, s["count"]])
			inventory_changed.emit()
			return true

	# 2) 放入空的已解锁槽
	for i in range(unlocked_slots):
		if slots[i] == null:
			slots[i] = {"type": item_type, "data": item_data, "count": 1}
			print("[背包] ✅ 新增到格子 %d | 类型: %s" % [i, item_type])
			inventory_changed.emit()
			return true

	print("[背包] ❌ 背包已满，无法添加物品")
	return false

# 从某格移除一个（堆叠减一，归零清空）
func remove_one(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return false
	var s = slots[slot_index]
	if s == null:
		return false
	if _runtime != null and _runtime.get("transactions") != null:
		var item_id := str(s.get("item_id", _to_runtime_item_id(str(s.get("type", "")), s.get("data", {}))))
		var result: Dictionary = _runtime.get("transactions").apply({
			"type": "deliver_task_items",
			"task_id": "gj_drop_penalty",
			"requirements": [{"item_id": item_id, "quantity": 1}],
		})
		if result.get("ok", false):
			_sync_from_runtime()
			return true
		return false
	s["count"] -= 1
	if s["count"] <= 0:
		slots[slot_index] = null
	inventory_changed.emit()
	return true

# 清空整格
func remove_item(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return false
	if slots[slot_index] == null:
		return false
	slots[slot_index] = null
	inventory_changed.emit()
	return true

func _find_empty_slot() -> int:
	for i in range(unlocked_slots):
		if slots[i] == null:
			return i
	return -1

# 真正满：无空解锁槽且所有解锁栈都达上限
func is_full() -> bool:
	# Source of truth is the unified runtime inventory. The local slot mirror
	# (synced from GameRuntime.hotbar) only covers the first MAX_SLOTS
	# entries, so it cannot be used to answer "is the backpack full" on its
	# own — GameRuntime.hotbar.capacity is 12, MAX_SLOTS is 12.
	if _runtime != null and _runtime.get("hotbar") != null and _runtime.get("hotbar").has_method("is_full"):
		return bool(_runtime.get("hotbar").is_full())
	# Fallback when runtime is unavailable: local view is best-effort
	for i in range(unlocked_slots):
		var s = slots[i]
		if s == null:
			return false
		if s["count"] < _stack_limit(str(s.get("item_id", s.get("type", "")))):
			return false
	return true

func is_empty() -> bool:
	for i in range(MAX_SLOTS):
		if slots[i] != null:
			return false
	return true

# 返回所有非空格子索引
func get_occupied_slots() -> Array:
	var result: Array = []
	for i in range(MAX_SLOTS):
		if slots[i] != null:
			result.append(i)
	return result

func get_item_count() -> int:
	var count: int = 0
	for i in range(MAX_SLOTS):
		if slots[i] != null:
			count += 1
	return count

func get_item(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return {}
	return slots[slot_index] if slots[slot_index] != null else {}

func take_random_item_for_drop() -> Dictionary:
	var occupied := get_occupied_slots()
	if occupied.is_empty():
		return {}
	var slot_idx: int = occupied[randi() % occupied.size()]
	var item := get_item(slot_idx)
	if item.is_empty():
		return {}
	if not remove_one(slot_idx):
		return {}
	return item

# 解锁到第 i 格（含），局外进度用
func unlock_slot(i: int) -> void:
	if i >= unlocked_slots and i < MAX_SLOTS:
		unlocked_slots = i + 1
		inventory_changed.emit()

func clear_inventory() -> void:
	_initialize_inventory()
	inventory_changed.emit()
	print("[背包] 🗑 背包已清空")

func _sync_from_runtime() -> void:
	if _runtime == null or _runtime.get("hotbar") == null:
		return
	_initialize_inventory()
	var index := 0
	for stack_variant in _runtime.get("hotbar").get_stacks():
		if index >= MAX_SLOTS:
			break
		var stack: Dictionary = stack_variant
		var item_id := str(stack.get("item_id", ""))
		var gj_item := _from_runtime_item_id(item_id, stack.get("metadata", {}))
		gj_item["count"] = int(stack.get("quantity", 0))
		gj_item["item_id"] = item_id
		slots[index] = gj_item
		index += 1
	inventory_changed.emit()

func _to_runtime_item_id(item_type: String, item_data: Dictionary) -> String:
	if item_type == "gem":
		match int(item_data.get("level", 1)):
			1:
				return "raw_common_geode"
			2:
				return "raw_fine_geode"
			3:
				return "raw_rare_geode"
	return item_type

func _from_runtime_item_id(item_id: String, metadata: Dictionary = {}) -> Dictionary:
	match item_id:
		"raw_common_geode":
			return {"type": "gem", "data": {"level": 1, "value": int(metadata.get("value", 1))}}
		"raw_fine_geode":
			return {"type": "gem", "data": {"level": 2, "value": int(metadata.get("value", 2))}}
		"raw_rare_geode":
			return {"type": "gem", "data": {"level": 3, "value": int(metadata.get("value", 3))}}
		"raw_star_geode":
			return {"type": "gem", "data": {"level": 4, "value": int(metadata.get("value", 4))}}
		_:
			return {"type": item_id, "data": metadata.duplicate(true)}
