extends RefCounted

## 装备系统，由 GameRuntime 持有。
##
## 4 个槽位：weapon / charm / bag / accessory
## 每个槽位最多一件装备。
## 暴露一系列 get_* 方法供其他系统查询当前生效的修正值。

const SLOTS: Array[String] = ["weapon", "charm", "bag", "accessory"]

var _equipped: Dictionary = {}
var _owned: Array[String] = []
var _equipment_data: Dictionary = {}
var _recall_used: bool = false

signal equipped(slot: String, equip_id: String)
signal unequipped(slot: String, equip_id: String)
signal bought(equip_id: String)
signal gift_received(equip_id: String, from_npc: String)

func load_data() -> Dictionary:
	var file := FileAccess.open("res://data/equipment/equipment.json", FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "equipment.json not found"}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return {"ok": false, "error": "equipment.json parse error"}
	var list: Array = json.data.get("equipment", [])
	_equipment_data.clear()
	for entry in list:
		var eid: String = str(entry.get("id", ""))
		if eid.is_empty():
			continue
		_equipment_data[eid] = entry
	return {"ok": true}

func get_all_equipment() -> Dictionary:
	if _equipment_data.is_empty():
		load_data()
	return _equipment_data.duplicate()

func get_equipment(eid: String) -> Dictionary:
	if _equipment_data.is_empty():
		load_data()
	return _equipment_data.get(eid, {})

func get_equip_name(eid: String) -> String:
	var e: Dictionary = get_equipment(eid)
	return str(e.get("name", eid))

func get_current_in_slot(slot: String) -> String:
	return str(_equipped.get(slot, ""))

func get_current_equip_in_slot(slot: String) -> Dictionary:
	var eid: String = get_current_in_slot(slot)
	if eid.is_empty():
		return {}
	return get_equipment(eid)

func owns(eid: String) -> bool:
	return eid in _owned

func can_buy(eid: String, wallet_balance: int) -> bool:
	if owns(eid):
		return false
	var e: Dictionary = get_equipment(eid)
	var cost: int = int(e.get("cost", 0))
	return wallet_balance >= cost

func buy(eid: String, wallet_balance: int) -> Dictionary:
	if not can_buy(eid, wallet_balance):
		return {"ok": false, "error": "cannot buy %s" % eid}
	var e: Dictionary = get_equipment(eid)
	if e.is_empty():
		return {"ok": false, "error": "unknown equipment %s" % eid}
	var cost: int = int(e.get("cost", 0))
	_owned.append(eid)
	# Auto-equip if slot is empty
	var slot: String = str(e.get("slot", ""))
	if not _equipped.has(slot) or str(_equipped.get(slot, "")).is_empty():
		_equipped[slot] = eid
	bought.emit(eid)
	return {"ok": true, "cost": cost, "auto_equipped": slot}

func receive_gift(eid: String, from_npc: String) -> Dictionary:
	if owns(eid):
		return {"ok": false, "error": "already owned %s" % eid}
	_owned.append(eid)
	var e: Dictionary = get_equipment(eid)
	var slot: String = str(e.get("slot", ""))
	if not _equipped.has(slot) or str(_equipped.get(slot, "")).is_empty():
		_equipped[slot] = eid
	gift_received.emit(eid, from_npc)
	return {"ok": true, "auto_equipped": slot}

func equip(eid: String) -> void:
	if not owns(eid):
		return
	var e: Dictionary = get_equipment(eid)
	var slot: String = str(e.get("slot", ""))
	if slot.is_empty():
		return
	var old: String = str(_equipped.get(slot, ""))
	_equipped[slot] = eid
	if not old.is_empty():
		unequipped.emit(slot, old)
	equipped.emit(slot, eid)

func unequip_slot(slot: String) -> void:
	if not _equipped.has(slot):
		return
	var old: String = str(_equipped.get(slot, ""))
	_equipped.erase(slot)
	if not old.is_empty():
		unequipped.emit(slot, old)

# --- Effect queries (aggregate across all equipped items) ---

func get_noise_reduction() -> float:
	return _sum_float_effect("noise_reduction")

func get_innate_noise_reduction() -> float:
	return _sum_float_effect("innate_noise_reduction")

func get_walk_noise_reduction() -> float:
	return _sum_float_effect("walk_noise_reduction")

func get_damage_reduction() -> float:
	return _sum_float_effect("damage_reduction")

func get_rare_drop_bonus() -> float:
	return _sum_float_effect("rare_drop_bonus")

func get_weight_penalty_reduction() -> float:
	return _sum_float_effect("weight_penalty_reduction")

func get_cover_deaggro_after() -> float:
	return _max_float_effect("cover_deaggro_after")

func get_hotbar_slot_bonus() -> int:
	var total: int = 0
	for slot in SLOTS:
		var eid: String = str(_equipped.get(slot, ""))
		if eid.is_empty():
			continue
		var e: Dictionary = get_equipment(eid)
		total += int(e.get("effects", {}).get("hotbar_slots", 0))
	return total

func get_qte_zone_bonus() -> int:
	var total: int = 0
	for slot in SLOTS:
		var eid: String = str(_equipped.get(slot, ""))
		if eid.is_empty():
			continue
		var e: Dictionary = get_equipment(eid)
		total += int(e.get("effects", {}).get("qte_zone_bonus", 0))
	return total

func has_death_keep_backpack() -> bool:
	if _recall_used:
		return false
	for slot in SLOTS:
		var eid: String = str(_equipped.get(slot, ""))
		if eid.is_empty():
			continue
		var e: Dictionary = get_equipment(eid)
		if bool(e.get("effects", {}).get("death_keep_backpack", false)):
			return true
	return false

func consume_recall_shard() -> void:
	for slot in SLOTS:
		var eid: String = str(_equipped.get(slot, ""))
		if eid.is_empty():
			continue
		var e: Dictionary = get_equipment(eid)
		if bool(e.get("effects", {}).get("one_shot", false)):
			_recall_used = true
			return

# --- Helpers ---

func _sum_float_effect(key: String) -> float:
	var total: float = 0.0
	for slot in SLOTS:
		var eid: String = str(_equipped.get(slot, ""))
		if eid.is_empty():
			continue
		var e: Dictionary = get_equipment(eid)
		total += float(e.get("effects", {}).get(key, 0.0))
	return total

func _max_float_effect(key: String) -> float:
	var best: float = 0.0
	for slot in SLOTS:
		var eid: String = str(_equipped.get(slot, ""))
		if eid.is_empty():
			continue
		var e: Dictionary = get_equipment(eid)
		var v: float = float(e.get("effects", {}).get(key, 0.0))
		if v > best:
			best = v
	return best

func get_owned_list() -> Array:
	return _owned.duplicate()

func get_equipped_slots() -> Dictionary:
	return _equipped.duplicate()

func is_recall_used() -> bool:
	return _recall_used

func reset() -> void:
	_equipped.clear()
	_owned.clear()
	_recall_used = false
