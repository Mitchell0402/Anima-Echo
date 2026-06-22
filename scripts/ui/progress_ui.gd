extends Control

@onready var fill_bar: ProgressBar = $FillBar

var total_segments: int = 3 # 默认值，会被外部覆盖

# ✅ 由 MineStats 或 Interaction 调用，初始化分段数
func setup(max_segments: int) -> void:
	total_segments = max_segments

# ✅ 每帧更新进度
func update_progress(current: float, max_val: float) -> void:
	fill_bar.max_value = max_val
	fill_bar.value = current
	visible = true
