extends Node

## 昼夜循环系统（Autoload 单例：DayNightCycle）
##
## 每日流程：
## 1. 白天 → 玩家可进入矿洞（每日最多 3 次）
## 2. 每次矿洞返回 → 进入夜晚阶段
## 3. 夜晚阶段 → 矿洞入口关闭，仅 NPC 交互可用
## 4. 玩家结束夜晚 → 新的一天，矿洞次数重置，稳定度自然衰减

const MAX_MINE_ENTRIES: int = 3

var is_night: bool = false
var day_count: int = 1
var mine_entries_today: int = 0
var total_mine_runs: int = 0  # 累计浅层挖矿次数（用于深层入场券门控）
var _pending_return: bool = false  # 矿洞返回标记，由 use_mine_entry 设置，on_mine_return 清除

signal day_started(day: int)
signal night_fell
signal night_ended
signal mine_entry_used(remaining: int)

func can_enter_mine() -> bool:
	return not is_night and mine_entries_today < MAX_MINE_ENTRIES

func get_remaining_entries() -> int:
	return maxi(0, MAX_MINE_ENTRIES - mine_entries_today)

func use_mine_entry() -> void:
	if not can_enter_mine():
		return
	mine_entries_today += 1
	total_mine_runs += 1
	_pending_return = true
	mine_entry_used.emit(get_remaining_entries())

func has_pending_return() -> bool:
	return _pending_return

func clear_pending_return() -> void:
	_pending_return = false

func on_mine_return() -> void:
	_pending_return = false
	is_night = true
	night_fell.emit()

func end_night() -> void:
	is_night = false
	day_count += 1
	mine_entries_today = 0
	night_ended.emit()
	day_started.emit(day_count)

func get_total_mine_runs() -> int:
	return total_mine_runs

func reset() -> void:
	is_night = false
	day_count = 1
	mine_entries_today = 0
	total_mine_runs = 0
