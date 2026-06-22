extends Node

# 基础属性
@export var base_move_speed: float = 200.0
@export var z_axis_factor: float = 0.6  # 2.5D纵深减速系数

# 动态属性（后续由负重系统修改）
var current_speed_multiplier: float = 1.0

func get_effective_speed() -> float:  # ← 添加 -> float
	return base_move_speed * current_speed_multiplier
