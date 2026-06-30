extends RefCounted

const GRID_WIDTH: int = 7
const GRID_HEIGHT: int = 5
const START_CELL: Vector2i = Vector2i(3, 2)

enum RoomType { START, COMBAT, BOSS }

class DungeonLayout:
	var rooms: Dictionary = {}
	var connections: Array = []
	var boss_cell: Vector2i = Vector2i.ZERO
	var start_cell: Vector2i = START_CELL

	func get_room_count() -> int:
		return rooms.size()

	func get_neighbors(cell: Vector2i) -> Array:
		var result: Array = []
		for conn in connections:
			var d: Dictionary = conn
			if d["from"] == cell:
				result.append(d["to"])
			elif d["to"] == cell:
				result.append(d["from"])
		return result


static func generate(combat_rooms: int, seed: int = -1) -> DungeonLayout:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()

	var target_rooms: int = 1 + combat_rooms + 1
	var max_retries: int = 100

	for _attempt in range(max_retries):
		var result: DungeonLayout = _try_generate(target_rooms, rng)
		if result != null:
			return result

	push_error("[DungeonGenerator] Failed after %d retries" % max_retries)
	return _generate_fallback(combat_rooms)


static func _try_generate(target_rooms: int, rng: RandomNumberGenerator) -> DungeonLayout:
	var layout: DungeonLayout = DungeonLayout.new()
	layout.rooms[START_CELL] = RoomType.START

	var queue: Array = [START_CELL]
	var room_count: int = 1
	var dead_ends: Array = []

	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		var added_any: bool = false

		var dirs: Array = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		_shuffle_array(dirs, rng)

		for dir_v in dirs:
			var dir: Vector2i = dir_v
			var neighbor: Vector2i = cell + dir

			if not _in_bounds(neighbor):
				continue
			if layout.rooms.has(neighbor):
				continue
			if _count_occupied_neighbors(neighbor, layout.rooms) >= 2:
				continue
			if room_count >= target_rooms:
				continue
			if rng.randf() < 0.3:
				continue

			layout.rooms[neighbor] = RoomType.COMBAT
			var conn: Dictionary = {}
			conn["from"] = cell
			conn["to"] = neighbor
			layout.connections.append(conn)
			queue.append(neighbor)
			room_count += 1
			added_any = true

		if not added_any and cell != START_CELL:
			dead_ends.append(cell)

	if room_count < target_rooms:
		return null
	if dead_ends.is_empty():
		return null

	var boss_cell: Vector2i = _pick_farthest(dead_ends, START_CELL)
	layout.rooms[boss_cell] = RoomType.BOSS
	layout.boss_cell = boss_cell

	var check_dirs: Array = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for d in check_dirs:
		var dd: Vector2i = d
		if START_CELL + dd == boss_cell:
			return null

	return layout


static func _generate_fallback(combat_rooms: int) -> DungeonLayout:
	var layout: DungeonLayout = DungeonLayout.new()
	layout.rooms[START_CELL] = RoomType.START

	var current: Vector2i = START_CELL
	var dir: Vector2i = Vector2i.RIGHT

	for _i in range(combat_rooms):
		current += dir
		layout.rooms[current] = RoomType.COMBAT
		var conn: Dictionary = {}
		conn["from"] = current - dir
		conn["to"] = current
		layout.connections.append(conn)

	current += dir
	layout.rooms[current] = RoomType.BOSS
	var conn2: Dictionary = {}
	conn2["from"] = current - dir
	conn2["to"] = current
	layout.connections.append(conn2)
	layout.boss_cell = current

	push_warning("[DungeonGenerator] Using fallback linear layout")
	return layout


static func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT


static func _count_occupied_neighbors(cell: Vector2i, occupied: Dictionary) -> int:
	var count: int = 0
	var check_dirs: Array = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for d in check_dirs:
		var dd: Vector2i = d
		if occupied.has(cell + dd):
			count += 1
	return count


static func _shuffle_array(arr: Array, rng: RandomNumberGenerator) -> void:
	var n: int = arr.size()
	for i: int in range(n - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		if i != j:
			var a = arr[i]
			var b = arr[j]
			arr[i] = b
			arr[j] = a


static func _pick_farthest(candidates: Array, origin: Vector2i) -> Vector2i:
	var first = candidates[0]
	var best: Vector2i = first
	var best_dist: float = origin.distance_squared_to(best)
	for i in range(1, candidates.size()):
		var cell_v = candidates[i]
		var cell: Vector2i = cell_v
		var dist: float = origin.distance_squared_to(cell)
		if dist > best_dist:
			best_dist = dist
			best = cell
	return best


static func get_room_type_name(type: int) -> String:
	if type == RoomType.START:
		return "起始"
	elif type == RoomType.COMBAT:
		return "战斗"
	elif type == RoomType.BOSS:
		return "Boss"
	return "未知"
