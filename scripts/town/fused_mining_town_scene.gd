extends Node2D

const TownWalkableMap = preload("res://scripts/town/town_walkable_map.gd")
const TownNpcInteractor = preload("res://scripts/town/town_npc_interactor.gd")
const TownPlayerController = preload("res://scripts/town/town_player_controller.gd")

const TOWN_MAP := "res://assets/town/map/town_map.png"
const GJ_PLAYER_SPRITE_FRAMES := "res://assets/gj/characters/player/main_char_sprite_frames.tres"
const NPC_SPRITES := {
	"miner": "res://assets/town/npcs/npc_miner_sprites.png",
	"buyer": "res://assets/town/npcs/npc_buyer_sprites.png",
	"identifier": "res://assets/town/npcs/npc_identifier_sprites.png",
	"task_clerk": "res://assets/town/npcs/npc_task_clerk_sprites.png",
}
const NPC_NAMES := {
	"miner": "矿工",
	"buyer": "商人",
	"identifier": "鉴定师",
	"task_clerk": "公告板",
}
const MINE_SCENE := "res://scenes/mine/test_scene.tscn"
const INTERACTION_RADIUS := 86.0
const TOWN_CHARACTER_SCALE := 1.25

var _runtime: Node
var _walkable_map
var _npc_interactor
var _player
var _prompt_label: Label
var _status_label: Label
var _inventory_label: Label
var _popup: PanelContainer
var _popup_title: Label
var _popup_body: VBoxContainer
var _nearby_npc_id := ""


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_runtime = get_node_or_null("/root/GameRuntime")
	if _runtime != null and _runtime.get("catalog") == null:
		_runtime.initialize_for_new_game()
	_build_world()
	_build_ui()
	_refresh_hud("靠近 NPC 后按 E 交谈。")


func get_town_walkable_config_for_test() -> Dictionary:
	return _town_walkable_config()


func _process(_delta: float) -> void:
	if _popup.visible:
		_player.movement_paused = true
		return
	_player.movement_paused = false
	_nearby_npc_id = _npc_interactor.nearest_npc_id(_player.position, INTERACTION_RADIUS)
	if _nearby_npc_id.is_empty():
		_prompt_label.text = ""
	else:
		_prompt_label.text = "按 E 与%s交谈" % NPC_NAMES.get(_nearby_npc_id, _nearby_npc_id)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_popup()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if _popup.visible:
			return
		if not _nearby_npc_id.is_empty():
			_open_popup(_nearby_npc_id)
			get_viewport().set_input_as_handled()


func _build_world() -> void:
	var map := TextureRect.new()
	map.texture = load(TOWN_MAP)
	map.size = Vector2(1152, 648)
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(map)
	_walkable_map = TownWalkableMap.new()
	_walkable_map.configure(_town_walkable_config())
	_npc_interactor = TownNpcInteractor.new()
	add_child(_npc_interactor)
	for npc_id in _npc_interactor.get_npc_ids():
		_add_npc(npc_id)
	_player = TownPlayerController.new()
	_player.name = "TownPlayer"
	_player.configure(Vector2(572, 344), _walkable_map)
	add_child(_player)
	var player_sprite := AnimatedSprite2D.new()
	player_sprite.name = "GJMineCharacterSprite"
	player_sprite.sprite_frames = load(GJ_PLAYER_SPRITE_FRAMES)
	player_sprite.position = Vector2(0, -18)
	player_sprite.scale = Vector2(TOWN_CHARACTER_SCALE, TOWN_CHARACTER_SCALE)
	player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player.add_child(player_sprite)
	_player.configure_animated_sprite(player_sprite)
	var camera := Camera2D.new()
	camera.enabled = true
	camera.zoom = Vector2(1.0, 1.0)
	_player.add_child(camera)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_top = 10
	top.offset_right = -16
	top.offset_bottom = 42
	layer.add_child(top)
	_prompt_label = Label.new()
	_prompt_label.custom_minimum_size = Vector2(360, 26)
	top.add_child(_prompt_label)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_status_label)
	_inventory_label = Label.new()
	_inventory_label.position = Vector2(16, 48)
	_inventory_label.custom_minimum_size = Vector2(520, 120)
	layer.add_child(_inventory_label)
	_popup = PanelContainer.new()
	_popup.visible = false
	_popup.position = Vector2(690, 328)
	_popup.custom_minimum_size = Vector2(420, 280)
	layer.add_child(_popup)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_popup.add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)
	_popup_title = Label.new()
	root.add_child(_popup_title)
	_popup_body = VBoxContainer.new()
	root.add_child(_popup_body)


func _add_npc(npc_id: String) -> void:
	var npc := Node2D.new()
	npc.name = "NPC_%s" % npc_id
	npc.position = _npc_interactor.get_npc_position(npc_id)
	add_child(npc)
	var sprite := Sprite2D.new()
	sprite.texture = load(str(NPC_SPRITES.get(npc_id, "")))
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, Vector2(64, 64))
	sprite.scale = Vector2(TOWN_CHARACTER_SCALE, TOWN_CHARACTER_SCALE)
	npc.add_child(sprite)
	var label := Label.new()
	label.text = str(NPC_NAMES.get(npc_id, npc_id))
	label.position = Vector2(-28, -52)
	npc.add_child(label)


func _open_popup(npc_id: String) -> void:
	for child in _popup_body.get_children():
		child.queue_free()
	_popup.visible = true
	_popup_title.text = str(NPC_NAMES.get(npc_id, npc_id))
	match npc_id:
		"miner":
			_add_button("进入矿洞", Callable(self, "_enter_mine"))
		"identifier":
			_add_button("鉴定一个原石", Callable(self, "_identify_first_raw"))
		"buyer":
			_add_button("出售一个矿物", Callable(self, "_sell_first_mineral"))
		"task_clerk":
			_add_button("接取/领取鉴定任务", Callable(self, "_handle_task"))
	_add_button("离开", Callable(self, "_close_popup"))


func _add_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	_popup_body.add_child(button)


func _enter_mine() -> void:
	_close_popup()
	call_deferred("_change_to_mine")


func _change_to_mine() -> void:
	get_tree().change_scene_to_file(MINE_SCENE)


func _identify_first_raw() -> void:
	var inventory = _runtime.get("inventory")
	for stack_variant in inventory.get_stacks():
		var stack: Dictionary = stack_variant
		var item_id := str(stack.get("item_id", ""))
		var item: Dictionary = _runtime.get("catalog").get_item(item_id)
		if str(item.get("category", "")) == "raw_stone":
			var result: Dictionary = _runtime.get("identification_service").identify(item_id, {"station": "town_identifier"})
			_refresh_hud(_result_text(result, "已鉴定"))
			return
	_refresh_hud("没有可鉴定原石。")


func _sell_first_mineral() -> void:
	var inventory = _runtime.get("inventory")
	for stack_variant in inventory.get_stacks():
		var stack: Dictionary = stack_variant
		var item_id := str(stack.get("item_id", ""))
		var item: Dictionary = _runtime.get("catalog").get_item(item_id)
		if str(item.get("category", "")) == "mineral":
			var result: Dictionary = _runtime.get("shop_service").sell_to_customer("buyer_blacksmith", item_id, 1, {"timing": "good"})
			_refresh_hud(_result_text(result, "已出售"))
			return
	_refresh_hud("没有可出售矿物。")


func _handle_task() -> void:
	_runtime.get("task_service").accept_task("task_first_identification")
	var result: Dictionary = _runtime.get("task_service").claim_reward("task_first_identification")
	if result.get("ok", false):
		_refresh_hud("任务奖励已领取。")
	else:
		_refresh_hud("任务已接取：鉴定一个原石。")


func _close_popup() -> void:
	_popup.visible = false


func _refresh_hud(message: String) -> void:
	if _runtime == null or _runtime.get("wallet") == null:
		return
	_status_label.text = "%s | Coins %d" % [message, int(_runtime.get("wallet").get_balance())]
	var rows: Array[String] = []
	for stack_variant in _runtime.get("inventory").get_stacks():
		var stack: Dictionary = stack_variant
		var item_id := str(stack.get("item_id", ""))
		var item: Dictionary = _runtime.get("catalog").get_item(item_id)
		rows.append("%s x%d" % [str(item.get("name", item_id)), int(stack.get("quantity", 0))])
	_inventory_label.text = "背包：\n%s" % ("\n".join(rows) if not rows.is_empty() else "空")


func _result_text(result: Dictionary, success_text: String) -> String:
	if result.get("ok", false):
		return "%s %s" % [success_text, str(result.get("item_id", ""))]
	return str(result.get("message", result.get("error", "操作失败")))


func _town_walkable_config() -> Dictionary:
	return {
		"map_size": Vector2(1152, 648),
		"default_walkable": true,
		"blocked_polygons": []
	}
