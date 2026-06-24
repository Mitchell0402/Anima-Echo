extends Camera2D
## Game camera for top-down 2D scenes.
##
## Follows a Node2D target with smooth lerp, clamps the camera inside
## the world bounds so the player never sees black edges, and supports
## a fixed zoom chosen to fit the world inside the viewport at any
## aspect ratio.
##
## Coordinate model (matches docs/decisions/0003-warehouse-system.md
## and the future 0004-display-system spec):
##
##   world space  : world_width x world_height, fixed (e.g. 1152x648).
##                  Sprite positions, NPC positions, and player movement
##                  all live here. Never changes.
##   view space   : the rectangle the camera shows of the world. Sized
##                  to viewport_size / zoom. Centre = camera global
##                  position.
##   screen space : pixel position on the actual window. The viewport
##                  renderer maps view -> screen through the stretch
##                  settings in project.godot.
##
## The camera is the bridge between world and view. UI on its own
## CanvasLayer lives directly in screen space and is independent of
## the camera.

## Smooth factor: how fast the camera catches up to the target.
## Higher = snappier. 8 feels good for a Stardew-like 145 px/s walk
## speed.
@export var smooth_speed: float = 8.0

## Optional look-ahead in world units. The camera offset shifts toward
## the player's facing direction so the player can see more of where
## they are going. 0 = no look-ahead.
@export var look_ahead_distance: float = 32.0

## World bounds. The camera cannot pan beyond this rectangle; instead
## it stops at the edge so the world is never letter-boxed.
@export var world_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1152, 648))


var _target: Node2D = null


func _ready() -> void:
	# We do our own lerp; turn off the built-in smoothing so the camera
	# does not double-smooth.
	position_smoothing_enabled = false
	make_current()
	# Defer the integer zoom computation until the camera is in the
	# tree and the viewport is reachable. fit_world_to_viewport_integer
	# calls get_viewport_rect(), which fails if the node has not been
	# added to the tree yet.
	call_deferred("_apply_initial_zoom")


func _apply_initial_zoom() -> void:
	if zoom == Vector2.ONE:
		zoom = fit_world_to_viewport_integer()
		# Re-clamp in case the new zoom made the world smaller than the view.
		_clamp_to_world()


func set_target(node: Node2D) -> void:
	_target = node


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	# Aim position is the target plus a look-ahead in the direction
	# the target is moving (if it has a `facing` string attribute, e.g.
	# "up" / "down" / "left" / "right"). NPCs do not expose `facing`,
	# so we only apply look-ahead when the target has the attribute.
	var aim := _target.global_position
	if "facing" in _target and look_ahead_distance > 0.0:
		match _target.facing:
			"up":
				aim.y -= look_ahead_distance
			"down":
				aim.y += look_ahead_distance
			"left":
				aim.x -= look_ahead_distance
			"right":
				aim.x += look_ahead_distance
	# Smooth lerp toward the aim. clampf keeps the factor in [0, 1].
	position = position.lerp(aim, clampf(delta * smooth_speed, 0.0, 1.0))
	# Clamp so the camera stays inside the world. The view rectangle is
	# viewport / zoom, so we keep the centre at least half a view away
	# from each world edge.
	_clamp_to_world()


# Keep the camera centred within the world so the player never sees
# the world edges (which would render as black bars). The math:
#
#   half_w = viewport.x / 2 / zoom
#   half_h = viewport.y / 2 / zoom
#   position.x in [world.min.x + half_w, world.max.x - half_w]
#
# When the viewport is larger than the world on an axis, we centre
# the camera on that axis instead of clamping (otherwise the camera
# would pin to one edge and the world would not be centred).
func _clamp_to_world() -> void:
	var vp := get_viewport_rect().size
	var view_size := vp / zoom
	var half_view := view_size * 0.5
	var world_min := world_bounds.position
	var world_max := world_bounds.position + world_bounds.size
	# X axis
	if view_size.x >= world_bounds.size.x:
		position.x = world_min.x + world_bounds.size.x * 0.5
	else:
		position.x = clampf(position.x,
			world_min.x + half_view.x,
			world_max.x - half_view.x)
	# Y axis
	if view_size.y >= world_bounds.size.y:
		position.y = world_min.y + world_bounds.size.y * 0.5
	else:
		position.y = clampf(position.y,
			world_min.y + half_view.y,
			world_max.y - half_view.y)


# Compute a zoom that fits the world inside the viewport. Used by the
# town scene to start with the right zoom. Integer scaling: only
# returns integers >= 1.
func fit_world_to_viewport_integer() -> Vector2:
	var vp := get_viewport_rect().size
	var sx := int(floor(vp.x / world_bounds.size.x))
	var sy := int(floor(vp.y / world_bounds.size.y))
	var scale: int = maxi(1, mini(sx, sy))
	return Vector2(scale, scale)