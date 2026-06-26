extends Node

const SEGMENT_HP: float = 1.0
const MIN_SEGMENTS: int = 2
const MAX_SEGMENTS: int = 4

# 原石场景路径（编辑器中可拖入 .tscn 文件）
@export var gem_l1_scene: PackedScene
@export var gem_l2_scene: PackedScene
@export var gem_l3_scene: PackedScene
@export var gem_l4_scene: PackedScene

# 爆率配置（在编辑器中可调，加起来建议等于100）
@export var drop_rate_l1: float = 70.0
@export var drop_rate_l2: float = 20.0
@export var drop_rate_l3: float = 10.0
@export var drop_rate_l4: float = 0.0

# ✅ 幸运值：每个段完成后额外爆出一个原石的概率
@export var luck: float = 0.0  # 0.0~1.0，例如 0.1 = 10% 概率额外爆一个

var total_segments: int = 0
var current_progress: float = 0.0
var is_completed: bool = false

signal segment_completed(segment_index: int)
signal mining_completed

func _ready() -> void:
	total_segments = randi_range(MIN_SEGMENTS, MAX_SEGMENTS)

func get_max_progress() -> float:
	return total_segments * SEGMENT_HP

func add_progress(amount: float) -> void:
	if is_completed:
		return
		
	var old_progress := current_progress
	current_progress = minf(current_progress + amount, get_max_progress())
	
	var old_seg := int(old_progress / SEGMENT_HP)
	var new_seg := int(current_progress / SEGMENT_HP)
	for i in range(old_seg + 1, new_seg + 1):
		print("[Mine Debug] 💎 区间 %d 完成 | 生成原石 | 总进度: %.2f/%.2f" % [
			i, current_progress, get_max_progress()
		])
		segment_completed.emit(i)
		_spawn_gems_for_segment(i)
	
	if not is_completed and current_progress >= get_max_progress():
		is_completed = true
		print("[Mine Debug] ✅ 矿山开采完毕 | 即将销毁节点")
		mining_completed.emit()

func rollback_to_previous_segment() -> void:
	if is_completed:
		return
	var completed_segments := int(current_progress / SEGMENT_HP)
	current_progress = completed_segments * SEGMENT_HP
	print("[Mine Debug] ↩ 回退至段 %d | 进度: %.2f" % [completed_segments, current_progress])

func _roll_gem_level() -> int:
	var roll = randf_range(0, 100)
	
	if roll < drop_rate_l1:
		return 1
	elif roll < drop_rate_l1 + drop_rate_l2:
		return 2
	elif roll < drop_rate_l1 + drop_rate_l2 + drop_rate_l3:
		return 3
	else:
		return 4

func _get_gem_scene(level: int) -> PackedScene:
	match level:
		1:
			return gem_l1_scene
		2:
			return gem_l2_scene
		3:
			return gem_l3_scene
		4:
			return gem_l4_scene
		_:
			return gem_l1_scene

func _calculate_gem_count() -> int:
	if randf() < luck:
		print("[Mine Debug] 🍀 幸运触发！额外多爆一个原石")
		return 2
	return 1

func _spawn_gems_for_segment(segment_index: int) -> void:
	var gem_count = _calculate_gem_count()
	
	print("[Mine Debug] 🎲 段 %d 共爆出 %d 个原石" % [segment_index, gem_count])
	
	for j in range(gem_count):
		_spawn_single_gem(segment_index, j + 1)

func _spawn_single_gem(segment_index: int, gem_index: int) -> void:
	var gem_level = _roll_gem_level()
	var gem_scene = _get_gem_scene(gem_level)
	
	if not gem_scene:
		print("[Mine Debug] ❌ L%d 原石场景未配置" % gem_level)
		return
	
	var gem_instance = gem_scene.instantiate()
	var mine_node = get_parent()
	var world = mine_node.get_parent()
	if world == null:
		world = get_tree().current_scene
	
	world.add_child(gem_instance)
	
	var spawn_pos = mine_node.global_position
	spawn_pos.x += randf_range(-10, 10)
	spawn_pos.y += randf_range(-5, 5)
	
	gem_instance.global_position = spawn_pos
	
	print("[Mine Debug] 💎 原石 #%d (L%d) 已生成 | 位置: %s" % [gem_index, gem_level, spawn_pos])
	
	if gem_instance.has_method("launch"):
		var horizontal_vel = randf_range(-80, 80)
		var vertical_vel = randf_range(-50, -20)
		var velocity = Vector2(horizontal_vel, vertical_vel)
		gem_instance.launch(velocity)
