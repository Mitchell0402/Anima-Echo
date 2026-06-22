extends Node2D

## 玩家头顶悬浮血条：满血绿、空血红，宽度随血量缩放。
## 挂在玩家（MainCharacter）下的 HealthBar(Node2D) 上，自动跟随。

@export var bar_size: Vector2 = Vector2(120.0, 14.0)
@export var border: float = 2.0
@export var bg_color: Color = Color(0.0, 0.0, 0.0, 0.6)
@export var full_color: Color = Color(0.2, 0.9, 0.2)
@export var empty_color: Color = Color(0.9, 0.2, 0.2)
@export var hide_when_full: bool = false

var _bg: ColorRect
var _fill: ColorRect
var _player: Node

func _ready() -> void:
	_player = get_parent()
	_build()
	if _player and _player.has_signal("health_changed"):
		_player.health_changed.connect(_on_health_changed)
	if _player and "current_health" in _player and "max_health" in _player:
		_on_health_changed(_player.current_health, _player.max_health)

func _build() -> void:
	_bg = ColorRect.new()
	_bg.color = bg_color
	_bg.size = bar_size
	_bg.position = -bar_size / 2.0
	add_child(_bg)

	_fill = ColorRect.new()
	_fill.color = full_color
	var inner: Vector2 = bar_size - Vector2(border, border) * 2.0
	_fill.size = inner
	_fill.position = -bar_size / 2.0 + Vector2(border, border)
	add_child(_fill)

func _on_health_changed(current: float, maximum: float) -> void:
	var ratio: float = clamp(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0
	var inner_w: float = bar_size.x - border * 2.0
	_fill.size = Vector2(inner_w * ratio, _fill.size.y)
	_fill.color = empty_color.lerp(full_color, ratio)
	if hide_when_full:
		visible = ratio < 1.0
