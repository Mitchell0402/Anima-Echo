extends RefCounted

signal changed

var capacity: int = 12
var _slots: Array[Dictionary] = []


func _init(slot_capacity: int = 12) -> void:
	capacity = max(1, slot_capacity)


func add_item(item_id: String, quantity: int = 1, metadata: Dictionary = {}) -> Dictionary:
	if item_id.is_empty():
		return _fail("item_id_missing", "Item id is required.")
	if quantity <= 0:
		return _fail("quantity_invalid", "Quantity must be positive.")
	var remaining := quantity
	for index in range(_slots.size()):
		var slot := _slots[index]
		if str(slot.get("item_id", "")) == item_id and _metadata_matches(slot.get("metadata", {}), metadata):
			slot["quantity"] = int(slot.get("quantity", 0)) + remaining
			_slots[index] = slot
			changed.emit()
			return {"ok": true, "added": quantity}
	if _slots.size() >= capacity:
		return _fail("inventory_full", "Inventory is full.")
	_slots.append({
		"slot_id": _make_slot_id(),
		"item_id": item_id,
		"quantity": quantity,
		"metadata": metadata.duplicate(true),
	})
	changed.emit()
	return {"ok": true, "added": quantity}


func remove_item(item_id: String, quantity: int = 1, metadata: Dictionary = {}) -> Dictionary:
	if quantity <= 0:
		return _fail("quantity_invalid", "Quantity must be positive.")
	if count_item(item_id, metadata) < quantity:
		return _fail("insufficient_item", "Not enough %s." % item_id)
	var remaining := quantity
	for index in range(_slots.size() - 1, -1, -1):
		var slot := _slots[index]
		if str(slot.get("item_id", "")) != item_id:
			continue
		if not metadata.is_empty() and not _metadata_matches(slot.get("metadata", {}), metadata):
			continue
		var available := int(slot.get("quantity", 0))
		var take := mini(available, remaining)
		slot["quantity"] = available - take
		remaining -= take
		if int(slot.get("quantity", 0)) <= 0:
			_slots.remove_at(index)
		else:
			_slots[index] = slot
		if remaining <= 0:
			break
	changed.emit()
	return {"ok": true, "removed": quantity}


func count_item(item_id: String, metadata: Dictionary = {}) -> int:
	var total := 0
	for slot in _slots:
		if str(slot.get("item_id", "")) != item_id:
			continue
		if not metadata.is_empty() and not _metadata_matches(slot.get("metadata", {}), metadata):
			continue
		total += int(slot.get("quantity", 0))
	return total


func has_item(item_id: String, quantity: int = 1, metadata: Dictionary = {}) -> bool:
	return count_item(item_id, metadata) >= quantity


func has_requirements(requirements: Array) -> bool:
	for requirement_variant in requirements:
		var requirement: Dictionary = requirement_variant
		if not has_item(str(requirement.get("item_id", "")), int(requirement.get("quantity", requirement.get("count", 1)))):
			return false
	return true


func get_used_slot_count() -> int:
	return _slots.size()


func is_full() -> bool:
	return get_used_slot_count() >= capacity


func get_stacks() -> Array:
	return _slots.duplicate(true)


func snapshot() -> Array:
	return _slots.duplicate(true)


func restore(snapshot_slots: Array) -> void:
	_slots = snapshot_slots.duplicate(true)
	changed.emit()


func clear() -> void:
	_slots.clear()
	changed.emit()


func _metadata_matches(a: Dictionary, b: Dictionary) -> bool:
	return JSON.stringify(a) == JSON.stringify(b)


func _make_slot_id() -> String:
	return "slot_%04d" % (_slots.size() + 1)


func _fail(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": code,
		"message": message,
	}
