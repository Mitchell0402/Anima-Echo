extends Control

## QTE圆形指示器 — 纯视觉组件，由 mine_interaction 驱动。
## 绘制暗色背景圆、灰色外环、黄色成功区弧、红色旋转指针。

@export var circle_radius: float = 55.0
@export var ring_width: float = 5.0
@export var pointer_length_ratio: float = 0.82

var _current_angle_deg: float = 0.0
var _success_zone_start_deg: float = 90.0
var _success_zone_size_deg: float = 65.0
var _is_active: bool = false
var _center: Vector2


func _ready() -> void:
	visible = false
	_center = size / 2.0


func show_qte(success_start: float, success_size: float) -> void:
	_success_zone_start_deg = success_start
	_success_zone_size_deg = success_size
	_is_active = true

	visible = true
	modulate.a = 0.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.12)


func hide_qte() -> void:
	_is_active = false
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.tween_callback(func(): visible = false)


func update_pointer(angle_deg: float) -> void:
	_current_angle_deg = fmod(angle_deg, 360.0)
	queue_redraw()


func _draw() -> void:
	if not _is_active and modulate.a < 0.01:
		return

	_center = size / 2.0

	# 1. 背景暗色圆盘
	var bg_radius := circle_radius + ring_width + 8.0
	draw_circle(_center, bg_radius, Color(0.0, 0.0, 0.0, 0.45))

	# 2. 灰色外环
	draw_arc(_center, circle_radius + ring_width * 0.5, 0.0, TAU, 64,
		Color(0.35, 0.35, 0.35, 0.8), ring_width, true)

	# 3. 黄色成功区
	var zone_start := deg_to_rad(_success_zone_start_deg - 90.0)
	var zone_end := deg_to_rad(_success_zone_start_deg + _success_zone_size_deg - 90.0)
	draw_arc(_center, circle_radius, zone_start, zone_end, 32,
		Color(1.0, 0.82, 0.08, 0.92), ring_width + 3.0, true)

	# 4. 成功区两端标记线
	var mark_length := 7.0
	for mark_angle: float in [zone_start, zone_end]:
		var mark_dir := Vector2(cos(mark_angle), sin(mark_angle))
		var inner := _center + mark_dir * (circle_radius - ring_width)
		var outer := _center + mark_dir * (circle_radius + ring_width + mark_length)
		draw_line(inner, outer, Color(1.0, 0.82, 0.08, 0.92), 2.0, true)

	# 5. 红色指针（仅QTE激活时绘制）
	if _is_active:
		var pointer_angle := deg_to_rad(_current_angle_deg - 90.0)
		var pointer_dir := Vector2(cos(pointer_angle), sin(pointer_angle))
		var pointer_end := _center + pointer_dir * (circle_radius * pointer_length_ratio)
		draw_line(_center, pointer_end, Color(1.0, 0.15, 0.15, 0.92), 3.0, true)
		draw_circle(pointer_end, 4.5, Color(1.0, 0.15, 0.15, 0.95))
