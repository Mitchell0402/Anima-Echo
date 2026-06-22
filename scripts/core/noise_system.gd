extends Node

## 事件式全局噪音系统（Autoload 单例：NoiseSystem）
## 每次发声都是一个独立的噪音事件，带位置、响度、来源、存活时间。
## 巡逻听觉查询任意最响事件；可疑听觉只查来自玩家的噪音。

const NOISE_LIFETIME: float = 0.4

const WALK: float = 5.0
const RUN: float = 15.0
const COLLECT: float = 3.0
const MINE: float = 30.0

var _events: Array = []  # {position, loudness, time_left, source}

func _process(delta: float) -> void:
	if _events.is_empty():
		return
	var alive: Array = []
	for e in _events:
		e["time_left"] -= delta
		if e["time_left"] > 0.0:
			alive.append(e)
	_events = alive

## 发出噪音。source 为发声者（玩家移动时传玩家节点）；环境音（矿点）可省略。
func emit_noise(position: Vector2, loudness: float, source: Node = null) -> void:
	if loudness <= 0.0:
		return
	_events.append({
		"position": position,
		"loudness": loudness,
		"time_left": NOISE_LIFETIME,
		"source": source,
	})

## 巡逻听觉：返回 listener 范围内最响的任意噪音事件。
func get_audible_noise(listener_pos: Vector2, max_range: float) -> Dictionary:
	var best: Dictionary = {}
	var best_loudness: float = 0.0
	for e in _events:
		var dist: float = listener_pos.distance_to(e["position"])
		if dist > max_range:
			continue
		if e["loudness"] > best_loudness:
			best_loudness = e["loudness"]
			best = {
				"position": e["position"],
				"loudness": e["loudness"],
				"distance": dist,
			}
	return best

## 可疑听觉：只统计来自 source 的噪音，返回范围内最大响度（找不到返回 0）。
func get_loudest_from_source(listener_pos: Vector2, source: Node, max_range: float) -> float:
	if source == null:
		return 0.0
	var best: float = 0.0
	for e in _events:
		if e.get("source") != source:
			continue
		var dist: float = listener_pos.distance_to(e["position"])
		if dist > max_range:
			continue
		best = max(best, e["loudness"])
	return best
