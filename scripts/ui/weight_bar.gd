extends Control

## 屏幕右下角负重 HUD：方形容器，纵向进度条从下往上填充
## 挂在 HUD CanvasLayer 下

@export var container_size: float = 80.0
@export var border: float = 3.0
@export var margin_right: float = 24.0
@export var margin_bottom: float = 100.0

const LIGHT_MAX: float = 65.0
const HEAVY_MAX: float = 100.0
const OVERLOAD_MAX: float = 180.0

var _bg: ColorRect
var _fill: ColorRect
var _label: Label


func _ready() -> void:
	## 负重系统已禁用 — HUD 不显示
	## _weight = get_node_or_null("/root/WeightSystem")
	## _build()
	## if _weight:
	## 	if not _weight.weight_changed.is_connected(_on_weight_changed):
	## 		_weight.weight_changed.connect(_on_weight_changed)
	## 	_on_weight_changed(_weight.current_weight, HEAVY_MAX)
	pass


func _build() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var x: float = vp_size.x - container_size - margin_right
	var y: float = vp_size.y - container_size - margin_bottom

	# 背景方框
	_bg = ColorRect.new()
	_bg.color = Color(0.0, 0.0, 0.0, 0.5)
	_bg.size = Vector2(container_size, container_size)
	_bg.position = Vector2(x, y)
	add_child(_bg)

	# 填充条（从底部向上）
	var inner_size: float = container_size - border * 2.0
	_fill = ColorRect.new()
	_fill.size = Vector2(inner_size, 0.0)
	_fill.position = Vector2(x + border, y + container_size - border)
	add_child(_fill)

	# 标签
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.position = Vector2(x, y)
	_label.size = Vector2(container_size, container_size)
	add_child(_label)


func _on_weight_changed(current: float, _maximum: float) -> void:
	var ratio: float = clamp(current / OVERLOAD_MAX, 0.0, 1.0) if OVERLOAD_MAX > 0.0 else 0.0
	var inner_size: float = container_size - border * 2.0
	var fill_h: float = inner_size * ratio
	_fill.size = Vector2(inner_size, fill_h)
	_fill.position.y = _bg.position.y + container_size - border - fill_h
	_fill.color = _bar_color(current)
	_label.text = "%d/%d" % [int(current), int(HEAVY_MAX)]


func _bar_color(weight: float) -> Color:
	var green := Color(0.2, 0.9, 0.2)
	var yellow := Color(0.9, 0.85, 0.2)
	var orange := Color(0.95, 0.35, 0.15)

	if weight <= LIGHT_MAX:
		var t: float = clamp(weight / LIGHT_MAX, 0.0, 1.0)
		return green.lerp(Color(0.55, 0.88, 0.2), t)
	elif weight <= HEAVY_MAX:
		var t: float = clamp((weight - LIGHT_MAX) / (HEAVY_MAX - LIGHT_MAX), 0.0, 1.0)
		return yellow.lerp(Color(1.0, 0.65, 0.1), t)
	else:
		var t: float = clamp((weight - HEAVY_MAX) / (OVERLOAD_MAX - HEAVY_MAX), 0.0, 1.0)
		return orange.lerp(Color(0.9, 0.15, 0.1), t)
