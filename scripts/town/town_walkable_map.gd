extends RefCounted

var _map_size := Vector2(1152, 648)
var _polygons: Array[PackedVector2Array] = []
var _blocked_polygons: Array[PackedVector2Array] = []
var _default_walkable := false


func configure(config: Dictionary) -> void:
	_map_size = config.get("map_size", _map_size)
	_default_walkable = bool(config.get("default_walkable", false))
	_polygons.clear()
	for polygon in config.get("polygons", []):
		_polygons.append(PackedVector2Array(polygon))
	_blocked_polygons.clear()
	for polygon in config.get("blocked_polygons", []):
		_blocked_polygons.append(PackedVector2Array(polygon))


func is_walkable(world_position: Vector2) -> bool:
	if world_position.x < 0.0 or world_position.y < 0.0:
		return false
	if world_position.x > _map_size.x or world_position.y > _map_size.y:
		return false
	for polygon: PackedVector2Array in _blocked_polygons:
		if Geometry2D.is_point_in_polygon(world_position, polygon):
			return false
	if _default_walkable:
		return true
	for polygon: PackedVector2Array in _polygons:
		if Geometry2D.is_point_in_polygon(world_position, polygon):
			return true
	return false
