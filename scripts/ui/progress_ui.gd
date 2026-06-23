extends Control

## 矿山开采进度条：玩家按 E 交互时显示，松手隐藏。
## 使用 ColorRect 实现平滑填充，细 ColorRect 子节点绘制段分隔线。
## 分割线作为子节点放置在 fill 上方，确保始终可见。

@export var bar_size: Vector2 = Vector2(200.0, 20.0)
@export var border: float = 2.0
@export var bg_color: Color = Color(0.64, 0.0, 0.0, 1.0)
@export var fill_color: Color = Color(0.6, 1.0, 0.78, 1.0)
@export var divider_color: Color = Color(0.0, 0.0, 0.0, 0.75)
@export var divider_width: float = 2.0

var total_segments: int = 3
var _current_ratio: float = 0.0
var _fill: ColorRect
var _bg: ColorRect
var _dividers: Array = []

func _ready() -> void:
	_build()
	visible = false

func _build() -> void:
	# Remove any existing children (handles old scene nodes or cache)
	for c in get_children():
		c.queue_free()

	_bg = ColorRect.new()
	_bg.color = bg_color
	_bg.size = bar_size
	_bg.position = Vector2.ZERO
	add_child(_bg)

	_fill = ColorRect.new()
	_fill.color = fill_color
	var inner: Vector2 = bar_size - Vector2(border, border) * 2.0
	_fill.size = Vector2(0.0, inner.y)
	_fill.position = Vector2(border, border)
	add_child(_fill)

func setup(num_segments: int) -> void:
	total_segments = maxi(num_segments, 1)
	_update_dividers()

func update_progress(current: float, max_val: float) -> void:
	var ratio: float = clampf(current / max_val, 0.0, 1.0) if max_val > 0.0 else 0.0
	_current_ratio = ratio
	var inner_w: float = bar_size.x - border * 2.0
	_fill.size.x = inner_w * ratio

func show_bar() -> void:
	visible = true

func hide_bar() -> void:
	visible = false

func _update_dividers() -> void:
	for d in _dividers:
		if is_instance_valid(d):
			d.queue_free()
	_dividers.clear()

	if total_segments <= 1:
		return

	for i in range(1, total_segments):
		var div := ColorRect.new()
		div.color = divider_color
		div.size = Vector2(divider_width, bar_size.y)
		div.position = Vector2(bar_size.x * float(i) / float(total_segments) - divider_width * 0.5, 0.0)
		add_child(div)
		_dividers.append(div)
