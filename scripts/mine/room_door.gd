extends Area2D

## 房间门 — 玩家碰到时触发场景切换到相邻房间。
##
## 碰撞形状始终开启（sensor），锁定时额外显示物理阻挡。
## 通过 direction 字段告知 DungeonRoom 目标方向。

enum DoorState { OPEN, CLOSED }

@export var direction: Vector2i = Vector2i.RIGHT

var door_state: DoorState = DoorState.OPEN

@onready var _col_shape: CollisionShape2D = $CollisionShape2D
@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# 碰撞始终开启（sensor），靠 body_entered 信号检测
	monitoring = true
	monitorable = false
	if _col_shape:
		_col_shape.disabled = false
	body_entered.connect(_on_body_entered)
	_update_visual()


func set_door_locked(locked: bool) -> void:
	door_state = DoorState.CLOSED if locked else DoorState.OPEN
	_update_visual()


func is_locked() -> bool:
	return door_state == DoorState.CLOSED


func _update_visual() -> void:
	if _sprite:
		if door_state == DoorState.CLOSED:
			_sprite.modulate = Color(0.8, 0.2, 0.2, 0.9)
		else:
			_sprite.modulate = Color(0.3, 0.7, 0.3, 0.5)


func _on_body_entered(body: Node2D) -> void:
	if door_state == DoorState.CLOSED:
		return
	if body.is_in_group("player"):
		var room: Node = get_parent()
		if room and room.has_method("_on_door_entered"):
			room._on_door_entered(direction)
