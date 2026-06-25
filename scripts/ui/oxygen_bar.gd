extends Control

## 屏幕顶部氧气条 HUD：蓝→黄→红渐变 + 低氧闪烁
## 挂在 HUD CanvasLayer 下

@export var bar_width: float = 400.0
@export var bar_height: float = 24.0
@export var border: float = 2.0
@export var margin_top: float = 12.0

const LOW_THRESHOLD: float = 0.25
const MID_THRESHOLD: float = 0.5
const FLASH_SPEED: float = 6.0

var _bg: ColorRect
var _fill: ColorRect
var _label: Label
var _oxygen: Node
var _flash_timer: float = 0.0


func _ready() -> void:
	_oxygen = get_node_or_null("/root/OxygenSystem")
	_build()
	if _oxygen:
		if not _oxygen.oxygen_changed.is_connected(_on_oxygen_changed):
			_oxygen.oxygen_changed.connect(_on_oxygen_changed)
		_on_oxygen_changed(_oxygen.current_oxygen, _oxygen.tank_capacity)


func _process(delta: float) -> void:
	_flash_timer += delta
	var ratio: float = _oxygen.get_oxygen_ratio() if _oxygen else 1.0
	if ratio <= LOW_THRESHOLD:
		modulate.a = 0.4 + 0.6 * abs(sin(_flash_timer * FLASH_SPEED))
	else:
		modulate.a = 1.0


func _build() -> void:
	var center_x: float = (get_viewport_rect().size.x - bar_width) / 2.0

	_bg = ColorRect.new()
	_bg.color = Color(0.0, 0.0, 0.0, 0.5)
	_bg.size = Vector2(bar_width, bar_height)
	_bg.position = Vector2(center_x, margin_top)
	add_child(_bg)

	var inner: Vector2 = Vector2(bar_width - border * 2.0, bar_height - border * 2.0)
	_fill = ColorRect.new()
	_fill.size = inner
	_fill.position = Vector2(center_x + border, margin_top + border)
	add_child(_fill)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.position = Vector2(center_x, margin_top)
	_label.size = Vector2(bar_width, bar_height)
	add_child(_label)


func _on_oxygen_changed(current: float, maximum: float) -> void:
	var ratio: float = clamp(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	var inner_w: float = bar_width - border * 2.0
	_fill.size = Vector2(inner_w * ratio, _fill.size.y)
	_fill.color = _bar_color(ratio)
	_label.text = "O₂  %d%%" % int(ratio * 100.0)


func _bar_color(ratio: float) -> Color:
	var blue := Color(0.2, 0.4, 0.9)
	var yellow := Color(0.9, 0.85, 0.2)
	var red := Color(0.9, 0.2, 0.15)

	if ratio > MID_THRESHOLD:
		var t: float = clamp((ratio - MID_THRESHOLD) / (1.0 - MID_THRESHOLD), 0.0, 1.0)
		return yellow.lerp(blue, t)
	elif ratio > LOW_THRESHOLD:
		var t: float = clamp((ratio - LOW_THRESHOLD) / (MID_THRESHOLD - LOW_THRESHOLD), 0.0, 1.0)
		return red.lerp(yellow, t)
	else:
		var t: float = clamp(ratio / LOW_THRESHOLD, 0.0, 1.0)
		return Color(0.6, 0.1, 0.1).lerp(red, t)
