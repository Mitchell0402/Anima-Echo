extends Node2D

const ROOM_W: float = 1280.0
const ROOM_H: float = 720.0
const DOOR_SIZE: float = 96.0
const WALL_THICKNESS: float = 20.0

const DOOR_SCRIPT := preload("res://scripts/mine/room_door.gd")

const COLOR_START := Color(0.15, 0.25, 0.18)
const COLOR_COMBAT := Color(0.18, 0.15, 0.22)
const COLOR_BOSS := Color(0.28, 0.12, 0.12)
const COLOR_WALL := Color(0.25, 0.22, 0.18)
const COLOR_FLOOR := Color(0.12, 0.10, 0.14)

var _runtime: Node = null
var _near_exit: bool = false
var _door_cooldown: float = 0.0


func _ready() -> void:
	_runtime = get_node_or_null("/root/GameRuntime")
	if _runtime == null:
		push_error("[DungeonRoom] GameRuntime not found")
		return

	# 防御：布局未生成时自动创建
	if _runtime.dungeon_layout.is_empty() or not _runtime.dungeon_layout.has("rooms"):
		var diff: int = _runtime.dungeon_difficulty
		if diff < 1 or diff > 5:
			diff = 1
		var croom: int = 4
		if diff == 1:
			croom = 4
		elif diff == 2:
			croom = 4 if randi() % 2 == 0 else 5
		elif diff == 3:
			croom = 5
		elif diff == 4:
			croom = 5 if randi() % 2 == 0 else 6
		else:
			croom = 6
		_runtime.generate_dungeon_layout(croom)

	var cell: Vector2i = _runtime.dungeon_current_room
	var rooms: Dictionary = _runtime.dungeon_layout.get("rooms", {})
	var room_type: int = rooms.get(cell, -1)
	var entrance_dir: Vector2i = _runtime.dungeon_entrance_dir

	# 地板
	var floor_bg := ColorRect.new()
	floor_bg.name = "Floor"
	floor_bg.size = Vector2(ROOM_W, ROOM_H)
	floor_bg.position = -Vector2(ROOM_W / 2.0, ROOM_H / 2.0)
	floor_bg.color = COLOR_FLOOR
	add_child(floor_bg)

	# 房间底色
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.size = Vector2(ROOM_W - 32, ROOM_H - 32)
	bg.position = -Vector2((ROOM_W - 32) / 2.0, (ROOM_H - 32) / 2.0)
	if room_type == 0:
		bg.color = COLOR_START
	elif room_type == 1:
		bg.color = COLOR_COMBAT
	else:
		bg.color = COLOR_BOSS
	add_child(bg)

	# 标签
	var label := Label.new()
	label.name = "Label"
	var tnames := ["起始", "战斗", "Boss"]
	var tname: String = tnames[room_type] if room_type >= 0 and room_type <= 2 else "?"
	label.text = "%s (%d,%d)" % [tname, cell.x, cell.y]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-100, -ROOM_H / 2.0 + 12)
	label.size = Vector2(200, 30)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 12)
	add_child(label)

	# 墙壁 + 门
	var connections: Array = _runtime.get_dungeon_connections_for(cell)
	_make_walls(connections, room_type)

	# 矿车出口（仅起始房间）
	if room_type == 0:
		_make_exit()

	# 进门冷却：防止刚进入房间立刻被门弹回
	_door_cooldown = 0.35

	# 小地图
	_create_minimap(cell)

	# 战斗房间：刷怪 + 锁门
	var _enemy_alive_count: int = 0
	if room_type == 1 and not _runtime.is_dungeon_room_cleared(cell):
		_enemy_alive_count = _spawn_enemies(room_type)
		if _enemy_alive_count > 0:
			_lock_doors(true)
			set_meta("enemy_count", _enemy_alive_count)
			set_meta("room_cell", cell)
			set_meta("room_type", room_type)
		else:
			_runtime.mark_dungeon_room_cleared(cell)
			_spawn_ore_nodes()
	elif room_type == 2:
		set_meta("room_cell", cell)
		set_meta("room_type", room_type)
		if not _runtime.is_dungeon_room_cleared(cell):
			_enemy_alive_count = _spawn_enemies(room_type)
			set_meta("enemy_count", _enemy_alive_count)
	elif room_type == 0:
		set_meta("room_cell", cell)
		set_meta("room_type", room_type)

	# 生成玩家 — 必须在所有房间元素之后，确保相机在最上层
	_spawn_player(entrance_dir)


func _make_walls(connections: Array, _room_type: int) -> void:
	var hw: float = ROOM_W / 2.0
	var hh: float = ROOM_H / 2.0
	var wt: float = WALL_THICKNESS
	var ds: float = DOOR_SIZE / 2.0

	var cdirs: Array = []
	for conn in connections:
		cdirs.append(conn["dir"])

	_do_wall(cdirs, Vector2i.UP,    Vector2(-hw, -hh),      Vector2(ROOM_W, wt))
	_do_wall(cdirs, Vector2i.DOWN,  Vector2(-hw, hh - wt),  Vector2(ROOM_W, wt))
	_do_wall(cdirs, Vector2i.LEFT,  Vector2(-hw, -hh),      Vector2(wt, ROOM_H))
	_do_wall(cdirs, Vector2i.RIGHT, Vector2(hw - wt, -hh),  Vector2(wt, ROOM_H))


func _do_wall(cdirs: Array, dir: Vector2i, full_pos: Vector2, full_size: Vector2) -> void:
	if not cdirs.has(dir):
		_add_wall(full_pos, full_size)
		return
	var hw: float = ROOM_W / 2.0
	var hh: float = ROOM_H / 2.0
	var wt: float = WALL_THICKNESS
	var ds: float = DOOR_SIZE / 2.0

	if dir == Vector2i.UP or dir == Vector2i.DOWN:
		_add_wall(Vector2(-hw, full_pos.y), Vector2(hw - ds, wt))
		_add_wall(Vector2(ds, full_pos.y), Vector2(hw - ds, wt))
	else:
		_add_wall(Vector2(full_pos.x, -hh), Vector2(wt, hh - ds))
		_add_wall(Vector2(full_pos.x, ds), Vector2(wt, hh - ds))
	_make_door(dir)


func _add_wall(pos: Vector2, size: Vector2) -> void:
	var seg := ColorRect.new()
	seg.position = pos
	seg.size = size
	seg.color = COLOR_WALL
	add_child(seg)

	var body := StaticBody2D.new()
	body.position = pos
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	body.add_child(col)
	add_child(body)


func _make_door(dir: Vector2i) -> void:
	var door := DOOR_SCRIPT.new()
	door.name = "Door_" + _dir_char(dir)
	door.position = _door_pos(dir)
	door.direction = dir

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = _door_tex()
	sprite.scale = Vector2(DOOR_SIZE / 32.0, DOOR_SIZE / 32.0)
	door.add_child(sprite)

	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var r := RectangleShape2D.new()
	r.size = Vector2(DOOR_SIZE, DOOR_SIZE)
	col.shape = r
	col.disabled = true
	door.add_child(col)

	add_child(door)


func _door_pos(dir: Vector2i) -> Vector2:
	if dir == Vector2i.UP:    return Vector2(0, -ROOM_H / 2.0)
	if dir == Vector2i.DOWN:  return Vector2(0, ROOM_H / 2.0)
	if dir == Vector2i.LEFT:  return Vector2(-ROOM_W / 2.0, 0)
	return Vector2(ROOM_W / 2.0, 0)


func _dir_char(dir: Vector2i) -> String:
	if dir == Vector2i.UP:    return "U"
	if dir == Vector2i.DOWN:  return "D"
	if dir == Vector2i.LEFT:  return "L"
	return "R"


func _door_tex() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.5, 0.3, 0.9))
	for x in range(6, 26):
		for y in range(2, 30):
			img.set_pixel(x, y, Color(0.2, 0.15, 0.1, 0.95))
	return ImageTexture.create_from_image(img)


func _make_exit() -> void:
	var area := Area2D.new()
	area.name = "MinecartExit"
	area.position = Vector2(0, ROOM_H / 2.0 - 48)

	var col := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 48.0
	col.shape = c
	area.add_child(col)

	var spr := Sprite2D.new()
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.5, 0.2, 0.9))
	spr.texture = ImageTexture.create_from_image(img)
	area.add_child(spr)

	var lbl := Label.new()
	lbl.text = "按E返回城镇"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-60, 36)
	lbl.size = Vector2(120, 20)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", 10)
	area.add_child(lbl)

	area.body_entered.connect(_on_exit_entered)
	area.body_exited.connect(_on_exit_exited)
	add_child(area)


func _on_exit_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near_exit = true


func _on_exit_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near_exit = false


func _unhandled_input(event: InputEvent) -> void:
	if _near_exit and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		var rt: Node = get_node_or_null("/root/GameRuntime")
		if rt and rt.has_method("end_mine_run"):
			rt.end_mine_run()
		get_tree().change_scene_to_file("res://scenes/town/mining_town.tscn")


func _spawn_player(entrance_dir: Vector2i) -> void:
	var player: CharacterBody2D = _find_player()
	if player == null:
		var pscene: PackedScene = load("res://scenes/mine/main_character_stats.tscn")
		if pscene:
			player = pscene.instantiate()
			player.name = "Player"
			add_child(player)

	if player:
		if entrance_dir == Vector2i.ZERO:
			player.global_position = Vector2.ZERO
		else:
			player.global_position = _door_pos(-entrance_dir) + Vector2(entrance_dir) * 50.0

	# 用玩家自带的 Camera2D（跟随玩家），调整 zoom 让 1280x720 房间填满视口
	var cam: Camera2D = null
	for child in player.get_children():
		if child is Camera2D:
			cam = child
			break
	if cam == null:
		cam = Camera2D.new()
		player.add_child(cam)
	cam.enabled = true
	cam.zoom = Vector2.ONE
	cam.position_smoothing_enabled = false


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		return players[0] as CharacterBody2D
	return null


func _process(delta: float) -> void:
	if _door_cooldown > 0.0:
		_door_cooldown -= delta
	if _minimap != null:
		_update_player_dot()


func _lock_doors(locked: bool) -> void:
	for child in get_children():
		if child.has_method("set_door_locked"):
			child.set_door_locked(locked)


## ---- 小地图 ----

const MINIMAP_W: float = 200.0
const MINIMAP_H: float = 150.0
const MINIMAP_MARGIN: float = 16.0
const MINIMAP_CELL: float = 24.0
const MINIMAP_BG := Color(0.05, 0.05, 0.08, 0.75)
const MINIMAP_BORDER := Color(0.3, 0.3, 0.35, 0.9)
const MINIMAP_LINE := Color(0.3, 0.3, 0.35, 0.6)
const MINIMAP_CURRENT_BORDER := Color(1.0, 0.85, 0.2, 0.95)

var _minimap: Control = null

func _create_minimap(current_cell: Vector2i) -> void:
	var rt: Node = get_node_or_null("/root/GameRuntime")
	if rt == null:
		return

	var rooms: Dictionary = rt.dungeon_layout.get("rooms", {})
	var connections: Array = rt.dungeon_layout.get("connections", [])
	if rooms.is_empty():
		return

	# 计算包围盒
	var min_x := 9999
	var min_y := 9999
	var max_x := -9999
	var max_y := -9999
	for cell_key in rooms:
		var c: Vector2i = cell_key
		min_x = mini(min_x, c.x); min_y = mini(min_y, c.y)
		max_x = maxi(max_x, c.x); max_y = maxi(max_y, c.y)

	var map_cols := max_x - min_x + 1
	var map_rows := max_y - min_y + 1
	var total_w := map_cols * MINIMAP_CELL
	var total_h := map_rows * MINIMAP_CELL
	var scale := minf(MINIMAP_W / total_w, MINIMAP_H / total_h)
	var draw_w := total_w * scale
	var draw_h := total_h * scale
	var cell_sz := MINIMAP_CELL * scale

	# CanvasLayer 让地图不被相机移动影响
	var cl := CanvasLayer.new()
	cl.name = "MinimapLayer"
	cl.layer = 100
	add_child(cl)

	var panel := Control.new()
	panel.name = "Minimap"
	cl.add_child(panel)

	var bg_panel := Panel.new()
	bg_panel.name = "MinimapBg"
	bg_panel.position = Vector2(MINIMAP_MARGIN - 4, MINIMAP_MARGIN - 4)
	bg_panel.size = Vector2(MINIMAP_W + 8, MINIMAP_H + 28)  # 加空间放标题
	bg_panel.add_theme_stylebox_override("panel", _make_panel_stylebox(MINIMAP_BG, MINIMAP_BORDER))
	panel.add_child(bg_panel)

	# 标题
	var title := Label.new()
	title.name = "MinimapTitle"
	title.text = "地牢地图"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(MINIMAP_MARGIN, MINIMAP_MARGIN + 4)
	title.size = Vector2(MINIMAP_W, 16)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.9))
	title.add_theme_font_size_override("font_size", 10)
	panel.add_child(title)

	# 绘制区域
	var draw_area := Control.new()
	draw_area.name = "MinimapDraw"
	draw_area.position = Vector2(MINIMAP_MARGIN + (MINIMAP_W - draw_w) / 2.0, MINIMAP_MARGIN + 24)
	draw_area.size = Vector2(draw_w, draw_h)

	var draw_data := {
		"rooms": rooms,
		"connections": connections,
		"current_cell": current_cell,
		"min_x": min_x, "min_y": min_y,
		"cell_sz": cell_sz,
		"scale": scale,
		"draw_w": draw_w,
		"draw_h": draw_h,
	}

	draw_area.set_meta("draw_data", draw_data)
	draw_area.draw.connect(_draw_minimap.bind(draw_area))
	panel.add_child(draw_area)

	# 玩家点（独立节点，方便闪烁）
	var dot := ColorRect.new()
	dot.name = "PlayerDot"
	dot.size = Vector2(6, 6)
	dot.color = Color(1.0, 0.85, 0.2, 0.95)
	dot.set_meta("draw_data", draw_data)
	panel.add_child(dot)

	# 当前房间名标签
	var room_label := Label.new()
	room_label.name = "RoomLabel"
	room_label.text = ""
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_label.position = Vector2(MINIMAP_MARGIN, MINIMAP_MARGIN + 22 + draw_h + 4)
	room_label.size = Vector2(MINIMAP_W, 14)
	room_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 0.9))
	room_label.add_theme_font_size_override("font_size", 10)
	room_label.set_meta("draw_data", draw_data)
	panel.add_child(room_label)

	_minimap = panel
	_update_player_dot()


func _draw_minimap(ctrl: Control) -> void:
	var dd = ctrl.get_meta("draw_data")
	if dd == null:
		return

	var rooms: Dictionary = dd["rooms"]
	var connections: Array = dd["connections"]
	var current_cell: Vector2i = dd["current_cell"]
	var min_x: int = dd["min_x"]
	var min_y: int = dd["min_y"]
	var cell_sz: float = dd["cell_sz"]

	# 连线
	for conn in connections:
		var d: Dictionary = conn
		var from_v: Vector2i = d["from"]
		var to_v: Vector2i = d["to"]
		var fx: float = (from_v.x - min_x) * cell_sz + cell_sz / 2.0
		var fy: float = (from_v.y - min_y) * cell_sz + cell_sz / 2.0
		var tx: float = (to_v.x - min_x) * cell_sz + cell_sz / 2.0
		var ty: float = (to_v.y - min_y) * cell_sz + cell_sz / 2.0
		ctrl.draw_line(Vector2(fx, fy), Vector2(tx, ty), MINIMAP_LINE, 1.5, true)

	# 房间方块
	for cell_key in rooms:
		var c: Vector2i = cell_key
		var rt: int = rooms[c]
		var rx: float = (c.x - min_x) * cell_sz + 1
		var ry: float = (c.y - min_y) * cell_sz + 1
		var rs: float = cell_sz - 2

		var col := Color(0.12, 0.10, 0.14, 0.8)
		match rt:
			0: col = Color(0.15, 0.40, 0.18, 0.85)
			1: col = Color(0.28, 0.18, 0.32, 0.85)
			2: col = Color(0.45, 0.15, 0.15, 0.85)

		ctrl.draw_rect(Rect2(rx, ry, rs, rs), col, true)

		# 当前房间高亮边框
		if c == current_cell:
			ctrl.draw_rect(Rect2(rx - 1, ry - 1, rs + 2, rs + 2), MINIMAP_CURRENT_BORDER, false, 1.5)

	# 房间标签文字（draw_string）
	for cell_key in rooms:
		var c: Vector2i = cell_key
		var rt: int = rooms[c]
		var rx: float = (c.x - min_x) * cell_sz + 1
		var ry: float = (c.y - min_y) * cell_sz + 1
		var rs: float = cell_sz - 2

		var abbr := ""
		match rt:
			0: abbr = "S"
			1: abbr = "C"
			2: abbr = "B"

		if cell_sz >= 16:
			var fs := int(cell_sz * 0.4)
			var tx := rx + rs / 2.0 - fs * 0.3
			var ty := ry + rs / 2.0 + fs * 0.3
			ctrl.draw_string(ThemeDB.fallback_font, Vector2(tx, ty), abbr, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _update_player_dot() -> void:
	if _minimap == null:
		return

	var dot: ColorRect = _minimap.get_node_or_null("PlayerDot")
	var room_label: Label = _minimap.get_node_or_null("RoomLabel")
	if dot == null or room_label == null:
		return

	var dd = dot.get_meta("draw_data")
	if dd == null:
		return

	var rt: Node = get_node_or_null("/root/GameRuntime")
	if rt == null:
		return

	var current_cell: Vector2i = rt.dungeon_current_room
	var min_x: int = dd["min_x"]
	var min_y: int = dd["min_y"]
	var cell_sz: float = dd["cell_sz"]
	var rooms: Dictionary = dd["rooms"]
	var rt_type: int = rooms.get(current_cell, -1)

	# 玩家点位置：当前房间中心
	var draw_w: float = dd.get("draw_w", MINIMAP_W)
	var cx := (current_cell.x - min_x) * cell_sz + cell_sz / 2.0 - 3
	var cy := (current_cell.y - min_y) * cell_sz + cell_sz / 2.0 - 3
	dot.position = Vector2(MINIMAP_MARGIN + (MINIMAP_W - draw_w) / 2.0 + cx, MINIMAP_MARGIN + 24 + cy)

	# 闪烁
	var t := Time.get_ticks_msec() / 500.0
	dot.visible = fmod(t, 1.0) < 0.7
	dot.color = Color(1.0, 0.85, 0.2, 0.95)

	# 当前房间名
	var tnames := ["起始", "战斗", "Boss"]
	var tname: String = tnames[rt_type] if rt_type >= 0 and rt_type <= 2 else "?"
	room_label.text = "当前: %s (%d,%d)" % [tname, current_cell.x, current_cell.y]


func _make_panel_stylebox(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = border_color
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb


## ---- 房间清除 & 刷怪 ----

const ENEMY_SCENES := {
	1: {
		"scenes": [
			"res://scenes/mine/enemies/mine_fly.tscn",
			"res://scenes/mine/enemies/rubble_gaper.tscn",
		],
		"count": [3, 5],
	},
	2: {
		"scenes": [
			"res://scenes/mine/enemies/mine_fly.tscn",
			"res://scenes/mine/enemies/rubble_gaper.tscn",
			"res://scenes/mine/enemies/blast_crystal.tscn",
		],
		"count": [4, 6],
	},
	3: {
		"scenes": [
			"res://scenes/mine/enemies/mine_fly.tscn",
			"res://scenes/mine/enemies/rubble_gaper.tscn",
			"res://scenes/mine/enemies/blast_crystal.tscn",
			"res://scenes/mine/enemies/crystal_trite.tscn",
		],
		"count": [4, 7],
	},
	4: {
		"scenes": [
			"res://scenes/mine/enemies/mine_fly.tscn",
			"res://scenes/mine/enemies/rubble_gaper.tscn",
			"res://scenes/mine/enemies/blast_crystal.tscn",
			"res://scenes/mine/enemies/crystal_trite.tscn",
			"res://scenes/mine/enemies/specter_miner.tscn",
		],
		"count": [5, 8],
	},
	5: {
		"scenes": [
			"res://scenes/mine/enemies/mine_fly.tscn",
			"res://scenes/mine/enemies/rubble_gaper.tscn",
			"res://scenes/mine/enemies/blast_crystal.tscn",
			"res://scenes/mine/enemies/crystal_trite.tscn",
			"res://scenes/mine/enemies/specter_miner.tscn",
		],
		"count": [5, 10],
	},
}

const ORE_SCENES := {
	"small": "res://scenes/mine/small_mine.tscn",
	"deep": "res://scenes/mine/deep_mine.tscn",
}


func _spawn_enemies(room_type: int) -> int:
	var diff: int = _runtime.dungeon_difficulty
	var cfg: Dictionary = ENEMY_SCENES.get(diff, ENEMY_SCENES[1])
	var pool: Array = cfg["scenes"]
	var crange: Array = cfg["count"]
	var count: int = randi_range(crange[0], crange[1])

	var spawned: int = 0
	var hw: float = ROOM_W * 0.35
	var hh: float = ROOM_H * 0.35

	for _i in range(count):
		if pool.is_empty():
			break
		var scene_path: String = pool[randi() % pool.size()]
		var scene: PackedScene = load(scene_path)
		if scene == null:
			continue
		var enemy: Node = scene.instantiate()
		enemy.global_position = Vector2(randf_range(-hw, hw), randf_range(-hh, hh))
		if enemy.has_signal("died"):
			enemy.died.connect(_on_enemy_died)
		add_child(enemy)
		spawned += 1

	return spawned


func _on_enemy_died() -> void:
	var count: int = get_meta("enemy_count", 0) - 1
	set_meta("enemy_count", count)

	if count <= 0:
		_on_room_cleared()


func _on_room_cleared() -> void:
	var cell: Vector2i = get_meta("room_cell", Vector2i.ZERO)
	var rt: Node = get_node_or_null("/root/GameRuntime")
	if rt and cell != Vector2i.ZERO:
		rt.mark_dungeon_room_cleared(cell)

	_lock_doors(false)
	_spawn_ore_nodes()

	print("[DungeonRoom] 房间已清除: ", cell)


func _spawn_ore_nodes() -> void:
	var count: int = randi_range(1, 3)
	var center := Vector2.ZERO

	for _i in range(count):
		var pos: Vector2 = center + Vector2(randf_range(-120, 120), randf_range(-80, 80))

		var diff: int = _runtime.dungeon_difficulty
		var use_deep: bool = false
		if diff == 1:
			use_deep = false
		elif diff == 2:
			use_deep = randi() % 5 == 0
		elif diff == 3:
			use_deep = randi() % 5 < 2
		elif diff == 4:
			use_deep = randi() % 5 < 3
		else:
			use_deep = true

		var ore_path: String = ORE_SCENES["deep"] if use_deep else ORE_SCENES["small"]
		var scene: PackedScene = load(ore_path)
		if scene == null:
			continue

		var ore: Node = scene.instantiate()
		ore.global_position = pos
		add_child(ore)


func _on_door_entered(target_dir: Vector2i) -> void:
	# 冷却期内不触发切换（防止刚进入房间立刻被门弹回）
	if _door_cooldown > 0.0:
		return

	var rt: Node = get_node_or_null("/root/GameRuntime")
	if rt == null:
		return
	var cur: Vector2i = rt.dungeon_current_room
	var target: Vector2i = cur + target_dir

	if not rt.dungeon_layout.get("rooms", {}).has(target):
		return

	rt.dungeon_current_room = target
	rt.dungeon_entrance_dir = target_dir
	get_tree().change_scene_to_file("res://scenes/mine/dungeon_room.tscn")
