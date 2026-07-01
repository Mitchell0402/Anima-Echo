extends Node2D

signal moved(position: Vector2)

@export var speed := 145.0
@export var run_speed := 290.0
@export var animation_frame_time := 0.12

var walkable_map: RefCounted
var movement_paused := false
var facing := "down"
var _sprite: Sprite2D
var _animated_sprite: AnimatedSprite2D
var _frame_size := Vector2(64, 64)
var _animation_frame := 0
var _animation_elapsed := 0.0
var _sprite_layout := "grid"
var _grid_columns := 3
var _grid_rows := {
	"down": 0,
	"right": 1,
	"up": 2,
	"left": 3
}

const _FRAMES_BY_FACING := {
	"down": [0, 1],
	"up": [2],
	"right": [3, 4],
	"left": [5, 6]
}
const _GRID_ROW_BY_FACING := {
	"down": 0,
	"right": 1,
	"up": 2,
	"left": 3
}
const _ANIMATION_SUFFIX_BY_FACING := {
	"down": "f",
	"right": "r",
	"up": "b",
	"left": "l"
}


func configure(initial_position: Vector2, map: RefCounted) -> void:
	position = initial_position
	walkable_map = map


func configure_sprite(sprite: Sprite2D, frame_size: Vector2 = Vector2.ZERO, layout: Dictionary = {}) -> void:
	_sprite = sprite
	_animated_sprite = null
	if frame_size != Vector2.ZERO:
		_frame_size = frame_size
		_sprite_layout = String(layout.get("layout", "grid"))
	elif _sprite.texture != null:
		_frame_size = Vector2(_sprite.texture.get_width(), maxf(1.0, float(_sprite.texture.get_height()) / 7.0))
		_sprite_layout = String(layout.get("layout", "vertical"))
	if _sprite_layout == "grid":
		_grid_columns = maxi(1, int(layout.get("columns", _grid_columns)))
		var rows: Dictionary = layout.get("rows", _grid_rows)
		_grid_rows = {
			"down": int(rows.get("down", _grid_rows["down"])),
			"right": int(rows.get("right", _grid_rows["right"])),
			"up": int(rows.get("up", _grid_rows["up"])),
			"left": int(rows.get("left", _grid_rows["left"]))
		}
	_sprite.region_enabled = true
	_apply_sprite_frame()


func configure_animated_sprite(sprite: AnimatedSprite2D) -> void:
	_animated_sprite = sprite
	_sprite = null
	_play_animated_state("idle")


func get_animation_frame() -> int:
	return _animation_frame


func preview_move(direction: Vector2, delta: float, is_running: bool = false) -> bool:
	if movement_paused:
		return false
	direction = _to_cardinal_direction(direction)
	if direction == Vector2.ZERO:
		_set_idle_frame()
		SfxSystem.stop_walk()
		return false
	facing = _direction_to_facing(direction)
	_advance_move_animation(delta, is_running)
	var current_speed: float = run_speed if is_running else speed
	var target := position + direction * current_speed * delta
	if walkable_map != null and not walkable_map.is_walkable(target):
		SfxSystem.stop_walk()
		return false
	SfxSystem.play_walk(is_running)
	position = target
	moved.emit(position)
	return true


func _process(delta: float) -> void:
	if movement_paused:
		_set_idle_frame()
		return
	var is_running: bool = Input.is_key_pressed(KEY_SHIFT)
	preview_move(_read_direction(), delta, is_running)


func _read_direction() -> Vector2:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	return direction


func _direction_to_facing(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "right" if direction.x > 0.0 else "left"
	if direction.y < 0.0:
		return "up"
	return "down"


func _to_cardinal_direction(direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO:
		return Vector2.ZERO
	if absf(direction.x) > absf(direction.y):
		return Vector2(signf(direction.x), 0.0)
	return Vector2(0.0, signf(direction.y))


func _advance_move_animation(delta: float, is_running: bool) -> void:
	if _animated_sprite != null:
		_play_animated_state("run" if is_running else "walk")
		return
	if _sprite_layout == "grid":
		_animation_elapsed += delta
		if _animation_frame == 0 or _animation_elapsed >= animation_frame_time:
			_animation_elapsed = fmod(_animation_elapsed, animation_frame_time)
			_animation_frame = 1 if _animation_frame != 1 else mini(2, _grid_columns - 1)
	else:
		var frames: Array = _FRAMES_BY_FACING.get(facing, [0])
		if frames.size() <= 1:
			_animation_frame = 0
		else:
			_animation_elapsed += delta
			if _animation_elapsed >= animation_frame_time:
				_animation_elapsed = fmod(_animation_elapsed, animation_frame_time)
				_animation_frame = (_animation_frame + 1) % frames.size()
	_apply_sprite_frame()


func _set_idle_frame() -> void:
	_animation_elapsed = 0.0
	_animation_frame = 0
	SfxSystem.stop_walk()
	if _animated_sprite != null:
		_play_animated_state("idle")
		return
	_apply_sprite_frame()


func _apply_sprite_frame() -> void:
	if _sprite == null:
		return
	var region_position := Vector2.ZERO
	if _sprite_layout == "vertical":
		var frames: Array = _FRAMES_BY_FACING.get(facing, [0])
		var frame_index := int(frames[mini(_animation_frame, frames.size() - 1)])
		region_position = Vector2(0, frame_index * _frame_size.y)
	else:
		var row := int(_grid_rows.get(facing, int(_GRID_ROW_BY_FACING.get(facing, 0))))
		var column := clampi(_animation_frame, 0, _grid_columns - 1)
		region_position = Vector2(column * _frame_size.x, row * _frame_size.y)
	_sprite.region_rect = Rect2(region_position, _frame_size)
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _play_animated_state(state: String) -> void:
	if _animated_sprite == null:
		return
	var suffix := str(_ANIMATION_SUFFIX_BY_FACING.get(facing, "f"))
	var animation_name := "%s_%s" % [state, suffix]
	if _animated_sprite.sprite_frames == null or not _animated_sprite.sprite_frames.has_animation(animation_name):
		return
	if _animated_sprite.animation != animation_name:
		_animated_sprite.play(animation_name)
