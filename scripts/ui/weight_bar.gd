extends Node2D

## 玩家头顶负重条：轻载绿、负重黄、超载橙红
## 挂在玩家节点下，自动订阅 WeightSystem 信号更新

@export var bar_size: Vector2 = Vector2(120.0, 14.0)
@export var border: float = 2.0
@export var offset_y: float = -18.0
@export var bg_color: Color = Color(0.0, 0.0, 0.0, 0.6)

const OVERLOAD_MAX: float = 180.0
const LIGHT_MAX: float = 65.0
const HEAVY_MAX: float = 100.0

var _bg: ColorRect
var _fill: ColorRect
var _label: Label
var _weight: Node


func _ready() -> void:
	_weight = get_node_or_null("/root/WeightSystem")
	_build()
	if _weight:
		if not _weight.weight_changed.is_connected(_on_weight_changed):
			_weight.weight_changed.connect(_on_weight_changed)
		_on_weight_changed(_weight.current_weight, HEAVY_MAX)


func _build() -> void:
	_bg = ColorRect.new()
	_bg.color = bg_color
	_bg.size = bar_size
	_bg.position = Vector2(-bar_size.x / 2.0, offset_y)
	add_child(_bg)

	_fill = ColorRect.new()
	var inner: Vector2 = bar_size - Vector2(border, border) * 2.0
	_fill.size = inner
	_fill.position = Vector2(-bar_size.x / 2.0 + border, offset_y + border)
	add_child(_fill)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 9)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.position = Vector2(-bar_size.x / 2.0, offset_y - 12.0)
	_label.size = Vector2(bar_size.x, 14.0)
	add_child(_label)


func _on_weight_changed(current: float, _maximum: float) -> void:
	var ratio: float = clamp(current / OVERLOAD_MAX, 0.0, 1.0) if OVERLOAD_MAX > 0.0 else 0.0
	var inner_w: float = bar_size.x - border * 2.0
	_fill.size = Vector2(inner_w * ratio, _fill.size.y)
	_fill.color = _bar_color(current)
	_label.text = "%d / %d" % [int(current), int(HEAVY_MAX)]


func _bar_color(weight: float) -> Color:
	var green := Color(0.2, 0.9, 0.2)
	var yellow := Color(0.9, 0.85, 0.2)
	var orange := Color(0.95, 0.35, 0.15)

	if weight <= LIGHT_MAX:
		# 纯绿 → 接近黄：在 0–65 之间绿到黄绿渐变
		var t: float = clamp(weight / LIGHT_MAX, 0.0, 1.0)
		return green.lerp(Color(0.55, 0.88, 0.2), t)
	elif weight <= HEAVY_MAX:
		# 黄色渐变
		var t: float = clamp((weight - LIGHT_MAX) / (HEAVY_MAX - LIGHT_MAX), 0.0, 1.0)
		return yellow.lerp(Color(1.0, 0.65, 0.1), t)
	else:
		# 橙色到红
		var t: float = clamp((weight - HEAVY_MAX) / (OVERLOAD_MAX - HEAVY_MAX), 0.0, 1.0)
		return orange.lerp(Color(0.9, 0.15, 0.1), t)
