extends Node

## 昼夜循环系统（Autoload 单例：DayNightCycle）
##
## 每日流程：
## 1. 上午 → 玩家可进入矿洞（每日最多 2 次）
## 2. 第一次矿洞返回 → 进入下午
## 3. 第二次矿洞返回 → 进入傍晚（矿洞关闭，仅 NPC 交互可用）
## 4. 睡觉 → 新的一天上午，矿洞次数重置，稳定度自然衰减
##
## 床逻辑：
## 上午 → 下午 → 傍晚 → 第二天上午

enum TimePeriod {
	MORNING,    # 上午
	AFTERNOON,  # 下午
	EVENING,    # 傍晚
}

const MAX_MINE_ENTRIES: int = 2

var time_period: int = TimePeriod.MORNING
var day_count: int = 1
var mine_entries_today: int = 0
var total_mine_runs: int = 0
var _pending_return: bool = false

## Backward-compat: true when time_period == EVENING
var is_night: bool:
	get:
		return time_period == TimePeriod.EVENING

signal day_started(day: int)
signal afternoon_fell
signal evening_fell
signal night_ended
signal night_fell
signal mine_entry_used(remaining: int)


func can_enter_mine() -> bool:
	return time_period != TimePeriod.EVENING and mine_entries_today < MAX_MINE_ENTRIES


func get_remaining_entries() -> int:
	return maxi(0, MAX_MINE_ENTRIES - mine_entries_today)


func get_time_period_name() -> String:
	match time_period:
		TimePeriod.MORNING:
			return "上午"
		TimePeriod.AFTERNOON:
			return "下午"
		TimePeriod.EVENING:
			return "傍晚"
	return "上午"


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
	match time_period:
		TimePeriod.MORNING:
			time_period = TimePeriod.AFTERNOON
			afternoon_fell.emit()
		TimePeriod.AFTERNOON:
			time_period = TimePeriod.EVENING
			night_fell.emit()
			evening_fell.emit()
			night_ended.emit()


## Advance time by one period (used by bed during morning/afternoon).
func advance_time() -> void:
	match time_period:
		TimePeriod.MORNING:
			time_period = TimePeriod.AFTERNOON
			afternoon_fell.emit()
		TimePeriod.AFTERNOON:
			time_period = TimePeriod.EVENING
			night_fell.emit()
			evening_fell.emit()
			night_ended.emit()


## Sleep from evening to next morning. Resets daily quotas.
func sleep_to_morning() -> void:
	time_period = TimePeriod.MORNING
	day_count += 1
	mine_entries_today = 0
	night_ended.emit()
	day_started.emit(day_count)


func end_night() -> void:
	sleep_to_morning()


func get_total_mine_runs() -> int:
	return total_mine_runs


func reset() -> void:
	time_period = TimePeriod.MORNING
	day_count = 1
	mine_entries_today = 0
	total_mine_runs = 0
