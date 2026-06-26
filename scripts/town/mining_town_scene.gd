extends Node2D

const TownWalkableMap = preload("res://scripts/town/town_walkable_map.gd")
const TownNpcInteractor = preload("res://scripts/town/town_npc_interactor.gd")
const TownPlayerController = preload("res://scripts/town/town_player_controller.gd")

const WAREHOUSE_UI_SCRIPT = preload("res://scripts/ui/warehouse_ui.gd")

const TOWN_MAP := "res://assets/town/map/town_map.png"
const PLAYER_SPRITE_FRAMES := "res://assets/mine/characters/player/main_char_sprite_frames.tres"
const TOWN_CHARACTER_SCALE := 1.25
# Vertical offset for the NPC name label. -40 places the label just
# above the sprite head (sprite is 80x80 at scale 1.25). Scaling the
# value with TOWN_CHARACTER_SCALE keeps the label glued to the head
# when the scale changes.
const TOWN_NPC_LABEL_VERTICAL_OFFSET := 40.0 * TOWN_CHARACTER_SCALE + 8.0
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
var _warehouse_ui = null  # WarehouseUI CanvasLayer. Exposed for freeze checks.
# Pending sell negotiation: the QTE-driven sell path stashes the item
# id here while the QTE is on screen. _on_sell_qte_finished reads it.
var _qte_pending_item_id: String = ""
var _qte_circle = null  # The QTE Control instance in town (null when no QTE active).


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_runtime = get_node_or_null("/root/GameRuntime")
	if _runtime != null and _runtime.get("catalog") == null:
		_runtime.initialize_for_new_game()
	_build_world()
	_build_ui()
	_build_warehouse_ui()
	_refresh_hud("靠近 NPC 后按 E 交谈。按 I 打开仓库。")


func get_town_walkable_config_for_test() -> Dictionary:
	return _town_walkable_config()


func _process(_delta: float) -> void:
	# Freeze the player whenever an overlay is on top: the warehouse UI, the
	# NPC popup, or a sell-negotiate QTE. Each of these is the single source
	# of truth for "should the player be able to move".
	var warehouse_open: bool = _warehouse_ui != null and _warehouse_ui.is_open()
	var qte_active: bool = _qte_circle != null and is_instance_valid(_qte_circle) and _qte_pending_item_id != ""
	if _popup.visible or warehouse_open or qte_active:
		_player.movement_paused = true
		return
	_player.movement_paused = false
	_nearby_npc_id = _npc_interactor.nearest_npc_id(_player.position, INTERACTION_RADIUS)
	if _nearby_npc_id.is_empty():
		_prompt_label.text = ""
	else:
		_prompt_label.text = "按 E 与%s交谈" % NPC_NAMES.get(_nearby_npc_id, _nearby_npc_id)


func _unhandled_input(event: InputEvent) -> void:
	# While the warehouse UI is open, swallow all input except Esc and the
	# I key (handled inside the warehouse UI itself). The I key is already
	# handled by the warehouse UI, so we just need to drop the rest so the
	# player cannot move, talk to NPCs, or open the NPC popup while in the
	# warehouse view. This is the "freeze" contract promised by the spec.
	if _warehouse_ui != null and _warehouse_ui.is_open():
		if not event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			return
	# While a sell QTE is active, Space (qte_action) is the only input that
	# matters. Drop everything else so the player cannot wander or open
	# the NPC popup while negotiating.
	if _qte_circle != null and is_instance_valid(_qte_circle) and _qte_pending_item_id != "":
		if event.is_action_pressed("qte_action"):
			# Resolve the QTE: success if the pointer is in the yellow zone.
			var success: bool = _qte_circle.is_pointer_in_success_zone()
			_qte_circle.stop_qte(success)
			get_viewport().set_input_as_handled()
		elif not event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
		return
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
	# Size matches the world bounds (1152x648). The camera handles
	# what is actually visible; the texture is the world background.
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
	player_sprite.name = "MineCharacterSprite"
	player_sprite.sprite_frames = load(PLAYER_SPRITE_FRAMES)
	player_sprite.position = Vector2(0, -18)
	player_sprite.scale = Vector2(TOWN_CHARACTER_SCALE, TOWN_CHARACTER_SCALE)
	player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player.add_child(player_sprite)
	_player.configure_animated_sprite(player_sprite)
	# Top-level game camera. Attached to the scene root (not to the
	# player) so the camera can pan independently when needed and so
	# the player subtree stays focused on movement, not camera state.
	# The camera's _ready defers the integer zoom fit so it has a
	# valid viewport.
	var GameCameraScript = load("res://scripts/camera_2d.gd")
	var camera: Camera2D = GameCameraScript.new()
	camera.name = "GameCamera"
	camera.world_bounds = Rect2(Vector2.ZERO, Vector2(1152, 648))
	camera.set_target(_player)
	add_child(camera)


func _build_ui() -> void:
	# UI lives on its own CanvasLayer so it is independent of camera zoom
	# and world bounds. All positions are anchor-based so the layout
	# stays correct when the viewport rescales.
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	# Top bar: prompt (left) + status (right). Stretches across the
	# viewport with a 16 px margin.
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_top = 10
	top.offset_right = -16
	top.offset_bottom = 42
	top.add_theme_constant_override("separation", 16)
	layer.add_child(top)
	_prompt_label = Label.new()
	_prompt_label.custom_minimum_size = Vector2(360, 26)
	top.add_child(_prompt_label)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_status_label)
	# Bottom-left warehouse label, anchored to the top-left corner of
	# the viewport. The old hard-coded position (16, 48) only worked
	# at 1280x720; with anchor it tracks any viewport size.
	_inventory_label = Label.new()
	_inventory_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_inventory_label.offset_left = 16
	_inventory_label.offset_top = 48
	_inventory_label.custom_minimum_size = Vector2(520, 120)
	layer.add_child(_inventory_label)
	# NPC popup. Centred via anchor instead of a hard-coded position so
	# it does not drift off-screen when the viewport rescales.
	_popup = PanelContainer.new()
	_popup.visible = false
	_popup.set_anchors_preset(Control.PRESET_CENTER)
	_popup.custom_minimum_size = Vector2(420, 280)
	_popup.size = Vector2(420, 280)
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
	# Local offset relative to the NPC node. The label is a child of
	# the NPC Node2D, so its position is in world coordinates
	# relative to the NPC origin. -28 puts the left edge of the
	# label near the left side of the sprite (sprite is 80 px wide
	# at scale 1.25 so the label centres naturally above it).
	# -TOWN_NPC_LABEL_VERTICAL_OFFSET places the label just above
	# the sprite head; the constant scales with the sprite so that
	# if TOWN_CHARACTER_SCALE changes the label tracks the sprite.
	label.position = Vector2(-28, -TOWN_NPC_LABEL_VERTICAL_OFFSET)


func _open_popup(npc_id: String) -> void:
	for child in _popup_body.get_children():
		child.queue_free()
	_popup.visible = true
	_popup_title.text = str(NPC_NAMES.get(npc_id, npc_id))
	match npc_id:
		"miner":
			_add_button("进入矿洞", Callable(self, "_enter_mine"))
		"identifier":
			_open_warehouse_picker(
				"鉴定原石",
				"raw_stone",
				Callable(self, "_identify_item"),
			)
		"buyer":
			_open_warehouse_picker(
				"出售矿物",
				"mineral",
				Callable(self, "_open_sell_mode_picker"),
			)
		"task_clerk":
			_open_task_picker()
	_add_button("离开", Callable(self, "_close_popup"))


# Build the symmetric warehouse picker popup used by the identifier and
# buyer NPCs. `category_filter` ("raw_stone" or "mineral") narrows the grid
# to the items that are valid for this NPC; `on_pick` is the callable that
# receives the chosen item id and runs the actual transaction.
func _open_warehouse_picker(title: String, category_filter: String, on_pick: Callable) -> void:
	_popup_title.text = "%s — %s" % [_popup_title.text, title]
	# Show a small status line above the grid so the player knows the picker
	# is reading the warehouse, not the hotbar.
	var hint: Label = Label.new()
	hint.text = "从仓库中选择（按 E 取消）"
	_popup_body.add_child(hint)
	# Build the grid from the live warehouse state. Each row is a clickable
	# button showing icon + name + quantity + base_price (for sellable items).
	var warehouse: Object = _runtime.get("warehouse")
	var catalog: Object = _runtime.get("catalog")
	if warehouse == null or catalog == null:
		_add_button("仓库不可用", Callable())
		return
	for stack_variant in warehouse.get_stacks():
		var stack: Dictionary = stack_variant
		var item_id: String = str(stack.get("item_id", ""))
		var item: Dictionary = catalog.get_item(item_id)
		if str(item.get("category", "")) != category_filter:
			continue
		var label_text: String = "%s x%d" % [str(item.get("name", item_id)), int(stack.get("quantity", 0))]
		# Only sellable categories show a price tag. Raw stones are
		# identified, not sold, so a price tag would mislead the player.
		if item.get("category", "") == "mineral" and item.has("base_price"):
			label_text += "  [底价 %d]" % int(item.get("base_price", 0))
		# Bind a single argument (item_id) into the call.
		var bound: Callable = on_pick.bind(item_id)
		_add_button(label_text, bound)


# Second-stage picker shown after the player clicks a mineral in the
# warehouse grid. The player chooses how to sell it: direct (no risk,
# base price), negotiate (QTE, +20% on success / -15% on failure), or
# cancel back to the grid. The label is built from the catalog entry
# directly so the caller (the warehouse picker) only needs to pass the
# item id.
func _open_sell_mode_picker(item_id: String) -> void:
	# Reset the popup body so the sell-mode options replace the grid.
	for child in _popup_body.get_children():
		child.queue_free()
	var catalog: Object = _runtime.get("catalog")
	var warehouse: Object = _runtime.get("warehouse")
	var base_price: int = 0
	var label_text: String = item_id
	if catalog != null:
		var item: Dictionary = catalog.get_item(item_id)
		base_price = int(item.get("base_price", 0))
		var qty: int = 0
		if warehouse != null:
			qty = int(warehouse.count_item(item_id))
		label_text = "%s x%d" % [str(item.get("name", item_id)), qty]
	_popup_title.text = "出售 %s — 选择方式" % label_text
	var hint: Label = Label.new()
	hint.text = "基准价 %d 铜板。直接卖稳妥，讨价还价有 20%% 提升或 15%% 折扣。" % base_price
	_popup_body.add_child(hint)
	_add_button("直接卖 (%d)" % base_price, Callable(self, "_sell_item_direct").bind(item_id))
	_add_button("讨价还价（QTE）", Callable(self, "_sell_item_negotiate").bind(item_id))
	_add_button("返回", Callable(self, "_open_popup").bind("buyer"))


func _open_task_picker() -> void:
	# Per spec: only tasks currently satisfied by the warehouse are shown as
	# clickable rows. Other active tasks are shown greyed. Completed tasks
	# are hidden.
	var task_service: Object = _runtime.get("task_service")
	if task_service == null:
		return
	# List deliverable tasks first (clickable), then pending (greyed).
	var deliverable: Array = task_service.list_deliverable_tasks() if task_service.has_method("list_deliverable_tasks") else []
	for task in deliverable:
		var name: String = str(task.get("name", ""))
		var description: String = str(task.get("description", ""))
		var label: String = "[交付] %s — %s" % [name, description]
		var bound: Callable = Callable(self, "_deliver_task").bind(str(task.get("id", "")))
		_add_button(label, bound)
	var pending: Array = task_service.list_pending_tasks() if task_service.has_method("list_pending_tasks") else []
	for task in pending:
		var name: String = str(task.get("name", ""))
		var label: String = "[未满足] %s" % name
		var greyed: Button = _add_button(label, Callable())
		greyed.disabled = true


func _build_warehouse_ui() -> void:
	# The warehouse UI is a CanvasLayer. It listens to the toggle_warehouse
	# action (default I, see project.godot). It is a no-op in the mine.
	_warehouse_ui = WAREHOUSE_UI_SCRIPT.new()
	_warehouse_ui.name = "WarehouseUI"
	add_child(_warehouse_ui)


# Lazy-build a free-floating QTE Control for the sell-negotiate flow.
# The mine scene already has a QteCircle as part of the SmallMine scene
# tree; the town does not, so we instantiate a generic one and add it
# directly to the town root. Returns null if the script cannot be loaded
# (which should never happen in normal play).
func _ensure_town_qte() -> Control:
	if _qte_circle != null and is_instance_valid(_qte_circle):
		return _qte_circle
	var QteScript = load("res://scripts/ui/qte_circle_ui.gd")
	if QteScript == null:
		return null
	var qte: Control = QteScript.new()
	qte.name = "SellQte"
	# Square QTE sized to a reasonable chunk of the screen. The QTE draws
	# circles around its own center, so the size is the bounding box.
	var qte_size: int = 220
	qte.custom_minimum_size = Vector2(qte_size, qte_size)
	qte.size = Vector2(qte_size, qte_size)
	# Center the QTE in the viewport.
	qte.set_anchors_preset(Control.PRESET_CENTER)
	add_child(qte)
	_qte_circle = qte
	return qte


func _add_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	if action.is_valid():
		button.pressed.connect(action)
	_popup_body.add_child(button)
	return button


func _enter_mine() -> void:
	# Reset the hotbar before entering the mine. This is idempotent if
	# GameRuntime.begin_mine_run is also called from the mine entrance, but
	# the town scene runs first and the reset is cheap.
	if _runtime != null and _runtime.has_method("begin_mine_run"):
		_runtime.begin_mine_run()
	_close_popup()
	call_deferred("_change_to_mine")


func _change_to_mine() -> void:
	get_tree().change_scene_to_file(MINE_SCENE)


# Called when the player picks a raw stone from the warehouse picker.
# Performs one identify transaction. The identified mineral lands in the
# warehouse (default destination).
func _identify_item(item_id: String) -> void:
	if _runtime == null:
		return
	var result: Dictionary = _runtime.get("identification_service").identify(item_id, {"station": "town_identifier"})
	if result.get("ok", false):
		var mineral_id: String = str(result.get("item_id", ""))
		_show_toast("已鉴定 %s" % mineral_id)
	else:
		_show_toast(str(result.get("message", result.get("error", "鉴定失败"))))
	# Refresh the bottom-left warehouse label so the player can see the
	# new stack (or the missing raw stone) without reopening the popup.
	_refresh_hud("")
	_close_popup()


# Called when the player picks a mineral from the warehouse picker.
# Routes through CustomerShopService so the budget is consumed and the
# negotiation result is returned.
func _sell_item(item_id: String) -> void:
	if _runtime == null:
		return
	var result: Dictionary = _runtime.get("shop_service").sell_to_customer("buyer_blacksmith", item_id, 1, {"timing": "normal"})
	if result.get("ok", false):
		var total: int = int(result.get("total_price", 0))
		_show_toast("已出售 %s +%d 铜板" % [item_id, total])
	else:
		_show_toast(str(result.get("message", result.get("error", "出售失败"))))
	# Refresh the warehouse label so the mineral disappears (or the
	# failure toast stays visible without the old stack still showing).
	_refresh_hud("")
	_close_popup()


# Direct-sell path: skip the QTE, sell at the catalog base_price plus the
# standard variance (~0.96-1.04). "normal" timing maps to 1.0x in
# NegotiationService._timing_bonus; the variance alone produces the
# final price.
func _sell_item_direct(item_id: String) -> void:
	if _runtime == null:
		return
	var result: Dictionary = _runtime.get("shop_service").sell_to_customer("buyer_blacksmith", item_id, 1, {"timing": "normal"})
	_apply_sell_result(item_id, result)


# Negotiate path: pop a QTE circle. On success the sale runs with
# "perfect" timing (1.18x); on failure "bad" (0.85x). The QTE is owned by
# the mine's QteCircle scene which we instantiate as a free-floating
# overlay so it works in town too.
func _sell_item_negotiate(item_id: String) -> void:
	# Lazy-build a free-floating QTE if the town does not have one. The
	# mine scene already has a QteCircle Control; here we create a
	# generic one and add it to the town scene root.
	var qte := _ensure_town_qte()
	if qte == null:
		# Fallback: sell at base price if we cannot build a QTE.
		_sell_item_direct(item_id)
		return
	# Pop the popup so the QTE is the only thing on screen.
	_close_popup()
	# Run the QTE. The result is delivered via _on_sell_qte_finished.
	_qte_pending_item_id = item_id
	_qte_circle = qte
	# Reuse the mine-style QTE parameters: 90-deg zone, 65-deg wide,
	# random start angle. The visual is the same as the mine QTE.
	var start_angle: float = randf_range(20.0, 340.0 - 65.0)
	qte.start_qte(start_angle, 65.0, Callable(self, "_on_sell_qte_finished"))


# Single place that converts a sell result dict into toast + HUD refresh.
# Used by both the direct and the negotiate paths so the player sees a
# consistent message regardless of the route.
func _apply_sell_result(item_id: String, result: Dictionary) -> void:
	if result.get("ok", false):
		var total: int = int(result.get("total_price", 0))
		_show_toast("已出售 %s +%d 铜板" % [item_id, total])
	else:
		_show_toast(str(result.get("message", result.get("error", "出售失败"))))
	_refresh_hud("")
	_close_popup()


# QTE result callback for the sell-negotiate flow. Called by the QTE
# circle when the player either hits the success zone or misses.
func _on_sell_qte_finished(success: bool) -> void:
	var item_id: String = _qte_pending_item_id
	_qte_pending_item_id = ""
	# stop_qte already called this callback and has already performed the
	# teardown.  Avoid re-entrant calls; just release the reference.
	_qte_circle = null
	if item_id.is_empty() or _runtime == null:
		return
	var timing: String = "perfect" if success else "bad"
	var flavor: String = "完美" if success else "失败"
	var result: Dictionary = _runtime.get("shop_service").sell_to_customer("buyer_blacksmith", item_id, 1, {"timing": timing})
	if result.get("ok", false):
		var total: int = int(result.get("total_price", 0))
		_show_toast("讨价还价% s!已出售 %s +%d 铜板" % [flavor, item_id, total])
	else:
		_show_toast("讨价还价%s：%s" % [flavor, str(result.get("message", result.get("error", "出售失败")))])
	_refresh_hud("")


# Called when the player clicks a deliverable task in the task_clerk popup.
# Delivers and claims in sequence; shows a single toast for the result.
func _deliver_task(task_id: String) -> void:
	if _runtime == null:
		return
	var task_service: Object = _runtime.get("task_service")
	var deliver: Dictionary = task_service.deliver_items(task_id)
	if not deliver.get("ok", false):
		_show_toast(str(deliver.get("message", deliver.get("error", "提交失败"))))
		_close_popup()
		return
	var claim: Dictionary = task_service.claim_reward(task_id)
	if not claim.get("ok", false):
		_show_toast(str(claim.get("message", claim.get("error", "领取失败"))))
		_refresh_hud("")
		_close_popup()
		return
	# Success toast mirrors the in-game reward line.
	_show_toast("任务奖励已领取。")
	# Refresh the warehouse label so the new reward stack shows up.
	_refresh_hud("")
	# Rebuild the popup so the now-completed task disappears from the
	# deliverable list. (Pending -> deliverable will refresh on its own
	# when warehouse content changes.)
	_open_popup("task_clerk")


# Lightweight toast: replace the bottom-left inventory label with a single
# line that auto-clears after a few seconds. The town scene does not have a
# dedicated toast widget; this is the smallest change that gives the player
# feedback without a new UI scene.
var _toast_timer = null  # SceneTreeTimer from get_tree().create_timer()
func _show_toast(message: String) -> void:
	if _status_label == null:
		return
	_status_label.text = message
	if _toast_timer != null:
		_toast_timer = null  # SceneTreeTimer cleans up after timeout
	_toast_timer = get_tree().create_timer(3.0)
	_toast_timer.timeout.connect(func() -> void:
		if is_instance_valid(_status_label):
			_status_label.text = "%s | Coins %d" % ["", int(_runtime.get("wallet").get_balance())] if _runtime else "")


func _close_popup() -> void:
	_popup.visible = false


func _refresh_hud(message: String) -> void:
	if _runtime == null or _runtime.get("wallet") == null:
		return
	_status_label.text = "%s | Coins %d" % [message, int(_runtime.get("wallet").get_balance())]
	var rows: Array[String] = []
	# Town HUD shows the warehouse contents. The hotbar is the in-mine
	# backpack and is empty in town by design.
	var warehouse: Object = _runtime.get("warehouse")
	if warehouse != null:
		for stack_variant in warehouse.get_stacks():
			var stack: Dictionary = stack_variant
			var item_id := str(stack.get("item_id", ""))
			var item: Dictionary = _runtime.get("catalog").get_item(item_id)
			rows.append("%s x%d" % [str(item.get("name", item_id)), int(stack.get("quantity", 0))])
	_inventory_label.text = "仓库：\n%s" % ("\n".join(rows) if not rows.is_empty() else "空")


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
