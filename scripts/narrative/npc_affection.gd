extends RefCounted

## NPC 好感度追踪组件，由 GameRuntime 持有。
##
## 每个 NPC 独立 affection: 0~100。
## - 送礼增加好感（普通+1，偏好/稀有+5，星辰+5）。
## - 每晚最多向每个 NPC 送 1 次礼。
## - 阈值为未来阶段解锁和道具回赠提供判定。

const AFFECTION_MIN: int = 0
const AFFECTION_MAX: int = 100
const GIFT_COMMON: int = 1
const GIFT_RARE: int = 5
const GIFT_STAR: int = 5

const NPC_IDS: Array[String] = ["elder", "blacksmith", "florist", "buyer"]

var affection: Dictionary = {}
var _gifted_today: Dictionary = {}

signal affection_changed(npc_id: String, value: int)
signal threshold_reached(npc_id: String, threshold: int)

func get_affection(npc_id: String) -> int:
	return int(affection.get(npc_id, 0))

func can_gift_today(npc_id: String) -> bool:
	return not _gifted_today.get(npc_id, false)

func gift(npc_id: String, rarity: String) -> int:
	var gain: int = GIFT_COMMON
	match rarity:
		"rare": gain = GIFT_RARE
		"star": gain = GIFT_STAR
	var current: int = get_affection(npc_id)
	var new_val: int = mini(current + gain, AFFECTION_MAX)
	affection[npc_id] = new_val
	_gifted_today[npc_id] = true
	affection_changed.emit(npc_id, new_val)
	for threshold in [20, 50, 80]:
		if current < threshold and new_val >= threshold:
			threshold_reached.emit(npc_id, threshold)
	return new_val

func reset_daily() -> void:
	_gifted_today.clear()

func reset() -> void:
	affection.clear()
	for npc_id: String in NPC_IDS:
		affection[npc_id] = 0
	_gifted_today.clear()

func get_all() -> Dictionary:
	return affection.duplicate()


## Add/subtract a flat amount of affection (used by NPC quest rewards).
func modify_affection(npc_id: String, delta: int) -> int:
	var current: int = get_affection(npc_id)
	var new_val: int = clampi(current + delta, AFFECTION_MIN, AFFECTION_MAX)
	affection[npc_id] = new_val
	affection_changed.emit(npc_id, new_val)
	for threshold in [20, 50, 80]:
		if current < threshold and new_val >= threshold:
			threshold_reached.emit(npc_id, threshold)
	return new_val
