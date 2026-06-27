extends Node

## 小镇稳定度系统（Autoload 单例：StabilitySystem）
##
## 稳定度范围 0~100。
## - 每日自然衰减 DECAY_PER_DAY。
## - 卖出星辰矿：-SELL_PENALTY。
## - 赠予星辰矿：+GIFT_BONUS。
## - 赠予普通矿物/礼物：+GENEROUS_BONUS。
## - 0 → 恶人结局触发条件；100 → 善人结局触发条件。
##
## 对外暴露敌人难度系数：
## - enemy_spawn_multiplier：怪物刷新数量倍率（稳定性越低怪物越多）。
## - detection_range_multiplier：索敌范围倍率。
## - noise_threshold_multiplier：噪音判定阈值倍率（稳定性越低越容易被发现）。

const MIN_STABILITY: float = 0.0
const MAX_STABILITY: float = 100.0
const DECAY_PER_DAY: float = 3.0
const SELL_PENALTY: float = 15.0
const GIFT_BONUS: float = 15.0
const GENEROUS_BONUS: float = 2.0

var stability: float = 70.0

signal stability_changed(current: float, previous: float)
signal stability_critical   # ≤ 15
signal stability_thriving   # ≥ 85

func get_enemy_spawn_multiplier() -> float:
	return lerpf(2.0, 1.0, stability / MAX_STABILITY)

func get_detection_range_multiplier() -> float:
	return lerpf(1.6, 0.8, stability / MAX_STABILITY)

func get_noise_threshold_multiplier() -> float:
	return lerpf(0.4, 1.2, stability / MAX_STABILITY)

func apply_daily_decay() -> void:
	_modify(-DECAY_PER_DAY, "daily_decay")

func penalize_sell() -> void:
	_modify(-SELL_PENALTY, "star_sold")

func reward_gift_star() -> void:
	_modify(GIFT_BONUS, "star_gifted")

func reward_gift_normal() -> void:
	_modify(GENEROUS_BONUS, "normal_gift")

func _modify(delta: float, reason: String) -> void:
	var previous: float = stability
	stability = clampf(previous + delta, MIN_STABILITY, MAX_STABILITY)
	if stability != previous:
		stability_changed.emit(stability, previous)
		if stability <= 15.0 and previous > 15.0:
			stability_critical.emit()
		if stability >= 85.0 and previous < 85.0:
			stability_thriving.emit()

func reset() -> void:
	stability = 70.0
