extends RefCounted

## 道德选择追踪器。记录玩家对星辰矿的每一次买入/赠予选择，
## 并判断当前善恶路线。

var sold_star_count: int = 0
var gifted_star_count: int = 0
var current_alignment: String = "neutral"  # "neutral" | "good" | "evil"

# 第一次触碰星辰矿（挖到/鉴定出）
var has_touched_star: bool = false

# 第一次做出选择（卖或送）
var has_made_first_choice: bool = false

const EVIL_THRESHOLD: int = 3
const GOOD_THRESHOLD: int = 3

# Tracks which NPC+stage first/first_evil/first_good dialogues have been shown.
# Keys: "npc_id_stage" (e.g. "elder_1")
var _shown_first_dialogues: Dictionary = {}

var _last_stage: int = 0  # Detect stage changes for toast notifications

signal star_touched
signal star_sold(count: int)
signal star_gifted(count: int)
signal alignment_changed(old_alignment: String, new_alignment: String)
signal narrative_stage_changed(old_stage: int, new_stage: int)

func record_star_touched() -> void:
	if has_touched_star:
		return
	has_touched_star = true
	star_touched.emit()

func record_star_sold() -> void:
	sold_star_count += 1
	if not has_made_first_choice:
		has_made_first_choice = true
	star_sold.emit(sold_star_count)
	_recalculate_alignment()

func record_star_gifted() -> void:
	gifted_star_count += 1
	if not has_made_first_choice:
		has_made_first_choice = true
	star_gifted.emit(gifted_star_count)
	_recalculate_alignment()

func _recalculate_alignment() -> void:
	var old: String = current_alignment
	if sold_star_count >= EVIL_THRESHOLD and sold_star_count > gifted_star_count:
		current_alignment = "evil"
	elif gifted_star_count >= GOOD_THRESHOLD and gifted_star_count > sold_star_count:
		current_alignment = "good"
	else:
		current_alignment = "neutral"
	if old != current_alignment:
		alignment_changed.emit(old, current_alignment)

func has_shown_first_dialogue(npc_id: String, stage_key: String) -> bool:
	return _shown_first_dialogues.get("%s_%s" % [npc_id, stage_key], false)


func mark_first_dialogue_shown(npc_id: String, stage_key: String) -> void:
	_shown_first_dialogues["%s_%s" % [npc_id, stage_key]] = true


func get_narrative_stage() -> int:
	# 0: 未接触星辰矿
	# 1: 已接触，未选择
	# 2: 已做出首次选择
	# 3: 多次选择后（阈值达标）
	var stage: int = 0
	if not has_touched_star:
		stage = 0
	elif not has_made_first_choice:
		stage = 1
	elif current_alignment != "neutral":
		stage = 3
	else:
		stage = 2
	if stage != _last_stage:
		narrative_stage_changed.emit(_last_stage, stage)
		_last_stage = stage
	return stage

func reset() -> void:
	sold_star_count = 0
	gifted_star_count = 0
	current_alignment = "neutral"
	has_touched_star = false
	has_made_first_choice = false
	_shown_first_dialogues.clear()
	_last_stage = 0
