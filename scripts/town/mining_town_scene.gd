extends Node2D

const WAREHOUSE_UI_SCRIPT = preload("res://scripts/ui/warehouse_ui.gd")

const NPC_NAMES := {
	"blacksmith": "铁匠青年",
	"buyer": "商人",
	"elder": "守夜老人",
	"florist": "花店少女",
}
const MINE_SCENE := "res://scenes/mine/test_scene.tscn"
const INTERACTION_RADIUS := 86.0

var _runtime: Node
var _npc_info: Dictionary = {}  # npc_id -> { "name": String, "position": Vector2, "node": Node }
var _player
var _prompt_label: Label
var _status_label: Label
var _inventory_label: Label
var _popup: PanelContainer
var _popup_title: Label
var _popup_body: VBoxContainer
var _nearby_npc_id := ""
var _warehouse_ui = null  # WarehouseUI CanvasLayer. Exposed for freeze checks.
var _dialogue_ui = null   # DialogueUI CanvasLayer
var _dialogue_npc_id := ""  # NPC id whose dialogue is currently open
var _dialogues_cache: Dictionary = {}
var _task_board: Node2D
var _board_prompt: Label
var _refine_station: Node
var _task_panel: PanelContainer
var _task_body: VBoxContainer
var _shop_night_customer_id: String = ""
# Pending sell negotiation: the QTE-driven sell path stashes the item
# id here while the QTE is on screen. _on_sell_qte_finished reads it.
var _qte_pending_item_id: String = ""
var _qte_circle = null  # The QTE Control instance in town (null when no QTE active).
var _stability: Node
var _day_cycle: Node
var _stability_bar: ColorRect
var _stability_value_label: Label
var _morality_label: Label
var _day_info_label: Label
var _night_overlay: ColorRect


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_runtime = get_node_or_null("/root/GameRuntime")
	if _runtime != null and _runtime.get("catalog") == null:
		_runtime.initialize_for_new_game()
	_stability = get_node_or_null("/root/StabilitySystem")
	_day_cycle = get_node_or_null("/root/DayNightCycle")
	_setup_scene_refs()
	_build_ui()
	_build_warehouse_ui()
	_check_mine_return()
	_apply_town_tint()
	_refresh_hud("靠近 NPC 后按 E 交谈。按 I 打开仓库。")


func _process(_delta: float) -> void:
	# Freeze the player whenever an overlay is on top: the warehouse UI, the
	# NPC popup, or a sell-negotiate QTE. Each of these is the single source
	# of truth for "should the player be able to move".
	var warehouse_open: bool = _warehouse_ui != null and _warehouse_ui.is_open()
	var qte_active: bool = _qte_circle != null and is_instance_valid(_qte_circle) and _qte_pending_item_id != ""
	var dialogue_open: bool = _dialogue_ui != null and is_instance_valid(_dialogue_ui) and _dialogue_ui.visible
	if _popup.visible or warehouse_open or qte_active or dialogue_open:
		_player.movement_paused = true
		return
	_player.movement_paused = false
	_nearby_npc_id = _nearest_scene_npc_id(_player.position, INTERACTION_RADIUS)
	var board_nearby := _is_nearby_board()
	if not _nearby_npc_id.is_empty():
		_prompt_label.text = "按 E 与%s交谈" % NPC_NAMES.get(_nearby_npc_id, _nearby_npc_id)
		_board_prompt.text = ""
	elif board_nearby:
		_prompt_label.text = ""
		_board_prompt.text = "按 E 查看公告板"
	elif _refine_station and _refine_station.is_nearby(_player.position):
		_prompt_label.text = "按 E 使用精炼台"
		_board_prompt.text = ""
	else:
		_prompt_label.text = ""
		_board_prompt.text = ""


func _unhandled_input(event: InputEvent) -> void:
	# Dialogue UI takes priority over all interaction. It handles its own
	# input (left-click advance, Esc to close and return to popup).
	if _dialogue_ui != null and is_instance_valid(_dialogue_ui) and _dialogue_ui.visible:
		return
	# While the warehouse UI is open, swallow all movement/interaction input
	# so the player can't wander or talk to NPCs. Esc passes through
	# (reserved for future settings menu). The I key is handled by the
	# warehouse UI itself.
	if _warehouse_ui != null and _warehouse_ui.is_open():
		if event.is_action_pressed("ui_cancel"):
			return  # let Esc through for settings
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
			return
		if _is_nearby_board():
			_open_task_picker_direct()
			get_viewport().set_input_as_handled()
			return
		if _refine_station and _refine_station.is_nearby(_player.position):
			_open_refine_picker()
			get_viewport().set_input_as_handled()
			return


func _setup_scene_refs() -> void:
	# Find all pre-placed NPC scene instances by their TownNPC script.
	_npc_info.clear()
	for child in get_children():
		if child is TownNPC:
			var town_npc: TownNPC = child as TownNPC
			if not town_npc.npc_id.is_empty():
				_npc_info[town_npc.npc_id] = {
					"name": town_npc.npc_display_name if not town_npc.npc_display_name.is_empty() else town_npc.npc_id,
					"position": town_npc.position,
					"node": town_npc,
				}
	# Find pre-placed TaskBoard and RefineStation from the scene.
	_task_board = get_node_or_null("TaskBoard")
	_refine_station = get_node_or_null("RefineStation")
	# Player is pre-placed as a scene instance; wire up the pre-placed
	# AnimatedSprite2D child (collision is scene-authored, not code-driven).
	_player = get_node_or_null("TownPlayer")
	if _player != null:
		if _player.has_method("configure_animated_sprite"):
			var sprite: AnimatedSprite2D = _player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if sprite != null:
				_player.configure_animated_sprite(sprite)
	# Camera is a child of the player scene; its _ready auto-detects the
	# parent as the follow target.


func _nearest_scene_npc_id(world_position: Vector2, radius: float) -> String:
	var best_id := ""
	var best_distance := radius
	for npc_id: String in _npc_info:
		var pos: Vector2 = _npc_info[npc_id]["position"] as Vector2
		var distance := world_position.distance_to(pos)
		if distance <= best_distance:
			best_distance = distance
			best_id = npc_id
	return best_id


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	# Night overlay (full-screen black, initially hidden)
	_night_overlay = ColorRect.new()
	_night_overlay.name = "NightOverlay"
	_night_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_night_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_night_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_night_overlay)

	# Top bar: prompt (left) + status (right).
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

	# Day info row (below top bar, right-aligned)
	_day_info_label = Label.new()
	_day_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_day_info_label.offset_left = 16
	_day_info_label.offset_top = 44
	_day_info_label.offset_right = -16
	_day_info_label.offset_bottom = 64
	_day_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(_day_info_label)

	# Left-middle panel: stability bar + numeric value + morality tracker
	var left_panel := VBoxContainer.new()
	left_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	left_panel.offset_left = 20
	left_panel.offset_top = -140
	left_panel.offset_right = 200
	left_panel.offset_bottom = 140
	left_panel.add_theme_constant_override("separation", 4)
	layer.add_child(left_panel)

	var stab_header := Label.new()
	stab_header.text = "◆ 稳定度"
	stab_header.add_theme_font_size_override("font_size", 15)
	left_panel.add_child(stab_header)

	_stability_bar = ColorRect.new()
	_stability_bar.custom_minimum_size = Vector2(160, 20)
	_stability_bar.size = Vector2(160, 20)
	left_panel.add_child(_stability_bar)

	_stability_value_label = Label.new()
	_stability_value_label.text = "70/100"
	_stability_value_label.add_theme_font_size_override("font_size", 14)
	left_panel.add_child(_stability_value_label)

	var moral_header := Label.new()
	moral_header.text = "◆ 善恶"
	moral_header.add_theme_font_size_override("font_size", 15)
	moral_header.offset_top = 8
	left_panel.add_child(moral_header)

	_morality_label = Label.new()
	_morality_label.text = "出售 0  赠予 0"
	_morality_label.add_theme_font_size_override("font_size", 14)
	left_panel.add_child(_morality_label)

	# Right-middle panel: active tasks
	_task_panel = PanelContainer.new()
	_task_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_task_panel.offset_left = -240
	_task_panel.offset_top = -140
	_task_panel.offset_right = -20
	_task_panel.offset_bottom = 140
	_task_panel.custom_minimum_size = Vector2(220, 0)
	layer.add_child(_task_panel)

	var task_vbox := VBoxContainer.new()
	task_vbox.add_theme_constant_override("separation", 6)
	var task_margin := MarginContainer.new()
	task_margin.add_theme_constant_override("margin_left", 10)
	task_margin.add_theme_constant_override("margin_right", 10)
	task_margin.add_theme_constant_override("margin_top", 8)
	task_margin.add_theme_constant_override("margin_bottom", 8)
	task_margin.add_child(task_vbox)
	_task_panel.add_child(task_margin)

	var task_header := Label.new()
	task_header.text = "◆ 当前任务"
	task_header.add_theme_font_size_override("font_size", 15)
	task_vbox.add_child(task_header)

	_task_body = VBoxContainer.new()
	_task_body.add_theme_constant_override("separation", 4)
	task_vbox.add_child(_task_body)

	# Bottom-left warehouse label
	_inventory_label = Label.new()
	_inventory_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_inventory_label.offset_left = 16
	_inventory_label.offset_top = 70
	_inventory_label.custom_minimum_size = Vector2(520, 120)
	layer.add_child(_inventory_label)

	# Task board interaction hint (shown when nearby)
	_board_prompt = Label.new()
	_board_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_board_prompt.offset_top = 50
	_board_prompt.text = ""
	_board_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_prompt.add_theme_font_size_override("font_size", 14)
	layer.add_child(_board_prompt)

	# NPC popup
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


func _open_popup(npc_id: String) -> void:
	for child in _popup_body.get_children():
		child.queue_free()
	_popup.visible = true
	_popup_title.text = str(NPC_NAMES.get(npc_id, npc_id))
	match npc_id:
		"blacksmith":
			var is_night_now: bool = _day_cycle != null and _day_cycle.get("is_night")
			if is_night_now:
				_add_button("结束夜晚，迎来新的一天", Callable(self, "_end_night"))
			else:
				var remaining: int = _day_cycle.get_remaining_entries() if _day_cycle and _day_cycle.has_method("get_remaining_entries") else 0
				_add_button("进入矿洞（剩余 %d 次）" % remaining, Callable(self, "_enter_mine"))
				var total_runs: int = _day_cycle.get_total_mine_runs() if _day_cycle else 0
				if total_runs >= 5:
					_add_button("购买深层入场券（500 铜板）", Callable(self, "_buy_deep_ticket"))
				else:
					var greyed: Button = _add_button("深层入场券（需累计挖矿 5 次，当前 %d）" % total_runs, Callable())
					greyed.disabled = true
			_add_button("装备商店", Callable(self, "_open_equipment_shop"))
			_add_button("聊聊", Callable(self, "_talk_npc").bind(npc_id))
		"florist":
			_open_warehouse_picker(
				"鉴定原石",
				"raw_stone",
				Callable(self, "_identify_item"),
			)
			_add_button("赠送礼物", Callable(self, "_open_gift_picker"))
			_add_button("聊聊", Callable(self, "_talk_npc").bind(npc_id))
		"buyer":
			_open_warehouse_picker(
				"出售矿物",
				"mineral",
				Callable(self, "_open_sell_mode_picker"),
			)
			var night_now: bool = _day_cycle != null and _day_cycle.get("is_night")
			if night_now:
				_add_button("开店（吸引流动客商）", Callable(self, "_open_night_shop"))
			_add_button("聊聊", Callable(self, "_talk_npc").bind(npc_id))
		"elder":
			_add_button("聊聊", Callable(self, "_talk_npc").bind(npc_id))
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
	# Star crystal triggers the moral choice popup instead of normal sell.
	if item_id == "star_crystal":
		_open_star_choice_popup()
		return
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
	_get_task_service_and_build()

# Reusable: shows tasks via a popup. Called both from the old popup path
# and from the task board interaction.
func _get_task_service_and_build() -> void:
	_popup.visible = true
	_popup_title.text = "公告板"
	for child in _popup_body.get_children():
		child.queue_free()
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
	if _day_cycle == null or not _day_cycle.has_method("can_enter_mine"):
		_show_toast("无法进入矿洞。")
		return
	if not _day_cycle.can_enter_mine():
		if _day_cycle.get("is_night"):
			_show_toast("夜晚矿洞已关闭，请先结束夜晚。")
		else:
			_show_toast("今日下矿次数已用完（%d/%d）。" % [_day_cycle.get("mine_entries_today"), _day_cycle.MAX_MINE_ENTRIES])
		_close_popup()
		return
	_day_cycle.use_mine_entry()
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
		if mineral_id == "star_crystal":
			# Record first touch in morality tracker
			var tracker: Object = _runtime.get("morality_tracker")
			if tracker and tracker.has_method("record_star_touched"):
				tracker.record_star_touched()
			_open_star_identify_popup()
		else:
			_show_toast("已鉴定 %s" % mineral_id)
	else:
		_show_toast(str(result.get("message", result.get("error", "鉴定失败"))))
	# Refresh the bottom-left warehouse label so the player can see the
	# new stack (or the missing raw stone) without reopening the popup.
	_refresh_hud("")
	if not (result.get("ok", false) and str(result.get("item_id", "")) == "star_crystal"):
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
	_get_task_service_and_build()
	_add_button("离开", Callable(self, "_close_popup"))


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
	_update_stability_display()
	_update_morality_display()
	_update_day_display()
	_refresh_task_panel()
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


func _refresh_task_panel() -> void:
	if _task_body == null:
		return
	for child in _task_body.get_children():
		child.queue_free()

	var task_service: Object = _runtime.get("task_service") if _runtime else null
	var catalog: Object = _runtime.get("catalog") if _runtime else null
	if task_service == null or catalog == null:
		return

	var has_any := false
	for task_variant in task_service.list_tasks():
		var task: Dictionary = task_variant
		var task_id: String = str(task.get("id", ""))
		var state: Dictionary = task_service.get_task_state(task_id)
		if str(state.get("state", "")) != "active":
			continue
		has_any = true

		# Task name
		var name_label := Label.new()
		name_label.text = str(task.get("name", task_id))
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_task_body.add_child(name_label)

		# Progress per objective
		var progress: Dictionary = state.get("progress", {})
		var objectives: Array = task.get("objectives", [])
		for obj_variant in objectives:
			var obj: Dictionary = obj_variant
			var obj_type: String = str(obj.get("type", ""))
			var obj_id: String = str(obj.get("id", obj.get("event", "")))
			var target: int = int(obj.get("count", obj.get("target", 1)))
			var current: int = int(progress.get(obj_id, 0))
			var done := current >= target

			var prog_label := Label.new()
			if done:
				prog_label.text = "  ✓ %s" % _task_objective_label(obj_id)
			else:
				prog_label.text = "  ○ %s  (%d/%d)" % [_task_objective_label(obj_id), current, target]
			prog_label.add_theme_font_size_override("font_size", 12)
			prog_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.4, 1.0) if done else Color(0.7, 0.7, 0.7, 1.0))
			prog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_task_body.add_child(prog_label)

	if not has_any:
		var empty := Label.new()
		empty.text = "暂无任务"
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
		_task_body.add_child(empty)


func _task_objective_label(obj_id: String) -> String:
	match obj_id:
		"elder": return "守夜老人"
		"blacksmith": return "铁匠青年"
		"florist": return "花店少女"
		"buyer": return "商人"
		"identified_any": return "鉴定矿石"
		"deliver_iron": return "交付铁片"
		"earn_sales": return "出售收入"
		"deliver_copper5": return "交付铜块"
		"deliver_iron3": return "交付铁片"
		"deliver_silver2": return "交付银脉"
	return obj_id


func _result_text(result: Dictionary, success_text: String) -> String:
	if result.get("ok", false):
		return "%s %s" % [success_text, str(result.get("item_id", ""))]
	return str(result.get("message", result.get("error", "操作失败")))


# ---- Star Crystal Identification Popup ----
func _open_star_identify_popup() -> void:
	for child in _popup_body.get_children():
		child.queue_free()
	_popup_title.text = "鉴定结果"
	var desc := Label.new()
	desc.text = "这块石头，带着温热的呼吸。"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 18)
	_popup_body.add_child(desc)
	_add_button("……", Callable(self, "_close_popup"))


# ---- Star Crystal Moral Choice Popup ----
func _open_star_choice_popup() -> void:
	for child in _popup_body.get_children():
		child.queue_free()
	_popup_title.text = "星辰矿"
	var desc := Label.new()
	desc.text = "你想如何处理这块星辰矿？"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_body.add_child(desc)
	_add_button("卖给商人（+%d 铜板）" % 500, Callable(self, "_sell_star_crystal"))
	_add_button("赠予小镇居民", Callable(self, "_gift_star_crystal"))
	_add_button("返回", Callable(self, "_open_popup").bind("buyer"))


func _sell_star_crystal() -> void:
	if _runtime == null:
		return
	var result: Dictionary = _runtime.get("shop_service").sell_to_customer("buyer_jeweler", "star_crystal", 1, {"timing": "normal"})
	if result.get("ok", false):
		var total: int = int(result.get("total_price", 0))
		_show_toast("已出售星辰矿 +%d 铜板。稳定度暴跌……" % total)
	else:
		_show_toast(str(result.get("message", result.get("error", "出售失败"))))
		_refresh_hud("")
		_close_popup()
		return
	# Penalize stability
	if _stability and _stability.has_method("penalize_sell"):
		_stability.penalize_sell()
	# Record in morality tracker
	var tracker: Object = _runtime.get("morality_tracker")
	if tracker and tracker.has_method("record_star_sold"):
		tracker.record_star_sold()
	_apply_town_tint()
	_refresh_hud("")
	_close_popup()


func _gift_star_crystal() -> void:
	if _runtime == null:
		return
	var warehouse: Object = _runtime.get("warehouse")
	if warehouse == null:
		return
	var removed: Dictionary = warehouse.remove_item("star_crystal", 1)
	if removed.get("ok", false):
		_show_toast("已将星辰矿赠予小镇。稳定度回升。")
	else:
		_show_toast(str(removed.get("message", removed.get("error", "赠予失败"))))
		_refresh_hud("")
		_close_popup()
		return
	# Update stability
	if _stability and _stability.has_method("reward_gift_star"):
		_stability.reward_gift_star()
	# Record in morality tracker
	var tracker: Object = _runtime.get("morality_tracker")
	if tracker and tracker.has_method("record_star_gifted"):
		tracker.record_star_gifted()
	_refresh_hud("")
	_close_popup()


# ---- Dialogue System ----

func _load_dialogues() -> Dictionary:
	if not _dialogues_cache.is_empty():
		return _dialogues_cache
	var file := FileAccess.open("res://data/narrative/dialogues.json", FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return {}
	_dialogues_cache = json.data
	return _dialogues_cache


func _talk_npc(npc_id: String) -> void:
	_close_popup()
	var dialogues: Dictionary = _load_dialogues()
	if dialogues.is_empty():
		_show_toast("对话数据加载失败。")
		return

	var data: Dictionary = dialogues.get(npc_id, {})
	if data.is_empty():
		_show_toast("该角色暂无对话。")
		return

	var tracker: Object = _runtime.get("morality_tracker")
	var stage: int = tracker.get_narrative_stage() if tracker and tracker.has_method("get_narrative_stage") else 0
	var stage_key := str(stage)
	var stages: Dictionary = data.get("stages", {})
	var stage_data: Dictionary = stages.get(stage_key, {})

	# Determine which dialogue to show: first-time, daily, or special
	var is_evil: bool = tracker and tracker.get("current_alignment") == "evil"
	var lines: Array[String] = []
	var has_first: bool = stage_data.has("first")
	var has_first_evil: bool = stage_data.has("first_evil")
	var has_first_good: bool = stage_data.has("first_good")

	if stage == 1 and has_first:
		lines.append(stage_data["first"])
	elif has_first_evil and is_evil:
		lines.append(stage_data["first_evil"])
	elif has_first_good and not is_evil:
		lines.append(stage_data["first_good"])

	# Add daily lines
	var daily: Array = stage_data.get("daily", [])
	if not daily.is_empty():
		lines.append_array(daily)

	# Add evil/good specific lines for stage 3
	if stage >= 3:
		var extra: Array = stage_data.get("evil" if is_evil else "good", [])
		lines.append_array(extra)

	if lines.is_empty():
		_show_toast("%s没有说话。" % NPC_NAMES.get(npc_id, npc_id))
		return

	_dialogue_npc_id = npc_id
	_ensure_dialogue_ui()
	if _dialogue_ui:
		_dialogue_ui.open(NPC_NAMES.get(npc_id, npc_id), str(data.get("portrait", "")), lines, Callable(self, "_on_dialogue_close"))


func _ensure_dialogue_ui() -> void:
	if _dialogue_ui != null and is_instance_valid(_dialogue_ui):
		return
	var script: GDScript = load("res://scripts/narrative/dialogue_ui.gd")
	if script == null:
		return
	_dialogue_ui = script.new()
	_dialogue_ui.name = "DialogueUI"
	add_child(_dialogue_ui)


func _on_dialogue_close() -> void:
	if not _dialogue_npc_id.is_empty():
		var npc_id: String = _dialogue_npc_id
		_dialogue_npc_id = ""
		# Emit event for task progress tracking (e.g. "talk to NPCs")
		if _runtime != null:
			var event_bus: Object = _runtime.get("event_bus")
			if event_bus != null and event_bus.has_signal("game_event"):
				event_bus.game_event.emit("npc_talked_%s" % npc_id, {"quantity": 1, "npc_id": npc_id})
		_refresh_task_panel()
		_open_popup(npc_id)


# ---- Gift System ----

func _open_gift_picker() -> void:
	var catalog: Object = _runtime.get("catalog")
	var warehouse: Object = _runtime.get("warehouse")
	if warehouse == null or catalog == null:
		_show_toast("仓库不可用。")
		return
	for child in _popup_body.get_children():
		child.queue_free()
	_popup_title.text = "赠送礼物给 %s" % NPC_NAMES.get("florist", "花店少女")
	var hint := Label.new()
	hint.text = "从仓库选择矿物赠送给花店少女。好感度有上限。"
	_popup_body.add_child(hint)
	var found := false
	for stack_variant in warehouse.get_stacks():
		var stack: Dictionary = stack_variant
		var item_id: String = str(stack.get("item_id", ""))
		var item: Dictionary = catalog.get_item(item_id)
		if str(item.get("category", "")) != "mineral":
			continue
		var qty: int = int(stack.get("quantity", 0))
		if qty <= 0:
			continue
		found = true
		var label_text: String = "%s x%d" % [str(item.get("name", item_id)), qty]
		_add_button("赠送 %s" % label_text, Callable(self, "_do_gift").bind(item_id))
	if not found:
		_add_button("仓库里没有可赠送的矿物", Callable())
	_add_button("返回", Callable(self, "_open_popup").bind("florist"))


func _do_gift(item_id: String) -> void:
	if _runtime == null:
		return
	var affection: Object = _runtime.get("npc_affection")
	if affection == null:
		_show_toast("好感系统未初始化。")
		return
	if not affection.can_gift_today("florist"):
		_show_toast("今天已经赠送给花店少女了，明天再来吧。")
		_refresh_hud("")
		_close_popup()
		return
	# Determine rarity from item category
	var catalog: Object = _runtime.get("catalog")
	var rarity: String = "common"
	if catalog != null:
		var item: Dictionary = catalog.get_item(item_id)
		var r: String = str(item.get("rarity", ""))
		if r in ["rare", "legendary"]:
			rarity = "rare" if r == "rare" else "star"
	# Remove the item from warehouse and gift it
	var warehouse: Object = _runtime.get("warehouse")
	var removed: Dictionary = warehouse.remove_item(item_id, 1)
	if not removed.get("ok", false):
		_show_toast(str(removed.get("message", removed.get("error", "赠送失败"))))
		_refresh_hud("")
		_close_popup()
		return
	var new_val: int = affection.gift("florist", rarity)
	# Small stability reward for any gift
	if _stability and _stability.has_method("reward_gift_normal"):
		_stability.reward_gift_normal()
	# Check if equipment reward should trigger
	_check_florist_reward()
	_show_toast("已赠送！好感度 %d/100" % new_val)
	_refresh_hud("")
	_close_popup()


# ---- Deep Mine Ticket ----

func _buy_deep_ticket() -> void:
	if _runtime == null:
		return
	var wallet: Object = _runtime.get("wallet")
	var cost: int = 500
	if wallet and wallet.get_balance() < cost:
		_show_toast("铜板不足（需要 %d）。" % cost)
		_refresh_hud("")
		_close_popup()
		return
	# Deduct cost - note: deep mine scene loading is future work (Day 5)
	if wallet:
		wallet.spend(cost)
	_show_toast("购买了深层入场券！深层矿洞入口已开放（功能开发中，Day 5）。")
	_refresh_hud("")
	_close_popup()


# ---- Task Board (pre-placed in scene) ----

const TASK_BOARD_INTERACT_RADIUS := 60.0

func _is_nearby_board() -> bool:
	if _task_board == null or not is_instance_valid(_task_board):
		return false
	var dist: float = _player.position.distance_to(_task_board.position)
	return dist <= TASK_BOARD_INTERACT_RADIUS


func _open_task_picker_direct() -> void:
	_get_task_service_and_build()
	_add_button("离开", Callable(self, "_close_popup"))

func _check_mine_return() -> void:
	if _day_cycle == null or not _day_cycle.has_method("has_pending_return"):
		return
	if not _day_cycle.has_pending_return():
		return
	# Only force night when all daily entries are used.
	var remaining: int = _day_cycle.get_remaining_entries() if _day_cycle.has_method("get_remaining_entries") else 0
	if remaining > 0:
		_day_cycle.clear_pending_return()
		_show_toast("回到小镇。今日剩余下矿 %d 次。" % remaining)
		return
	_day_cycle.on_mine_return()
	if _stability and _stability.has_method("apply_daily_decay"):
		_stability.apply_daily_decay()
	_show_toast("夜幕降临……矿洞已关闭。")


func _end_night() -> void:
	if _day_cycle == null or not _day_cycle.has_method("end_night"):
		return
	_day_cycle.end_night()
	# Reset daily gift limits
	var affection: Object = _runtime.get("npc_affection") if _runtime else null
	if affection and affection.has_method("reset_daily"):
		affection.reset_daily()
	# Refresh daily tasks
	var ts: Object = _runtime.get("task_service") if _runtime else null
	if ts and ts.has_method("refresh_daily_tasks"):
		ts.refresh_daily_tasks()
	_apply_town_tint()
	_refresh_hud("")
	_close_popup()
	_show_toast("第 %d 天开始了！" % _day_cycle.get("day_count"))


func _apply_town_tint() -> void:
	var is_night_now: bool = _day_cycle != null and _day_cycle.get("is_night")

	# Night overlay: darken the screen significantly
	if _night_overlay:
		if is_night_now:
			_night_overlay.color = Color(0.0, 0.0, 0.03, 0.55)
		else:
			_night_overlay.color = Color(0.0, 0.0, 0.0, 0.0)

	# Town modulate: based on stability
	if _stability == null:
		return
	var st: float = _stability.get("stability")
	var t: float = clampf(st / 100.0, 0.0, 1.0)
	var r: float = lerpf(0.4, 1.0, t)
	var g: float = lerpf(0.35, 0.95, t)
	var b: float = lerpf(0.3, 0.9, t)
	# Slightly darker overall at night
	var night_mul: float = 0.55 if is_night_now else 1.0
	modulate = Color(r * night_mul, g * night_mul, b * night_mul, 1.0)


func _update_stability_display() -> void:
	if _stability == null or _stability_bar == null:
		return
	var st: float = _stability.get("stability")
	var ratio: float = clampf(st / 100.0, 0.0, 1.0)
	_stability_bar.size.x = 160.0 * ratio
	if ratio < 0.5:
		_stability_bar.color = Color(0.85, lerpf(0.15, 0.85, ratio * 2.0), 0.15, 0.9)
	else:
		_stability_bar.color = Color(lerpf(0.85, 0.15, (ratio - 0.5) * 2.0), 0.85, 0.15, 0.9)
	if _stability_value_label:
		_stability_value_label.text = "%.0f / 100" % st


func _update_morality_display() -> void:
	if _morality_label == null or _runtime == null:
		return
	var tracker: Object = _runtime.get("morality_tracker")
	var sold: int = 0
	var gifted: int = 0
	if tracker:
		sold = int(tracker.get("sold_star_count"))
		gifted = int(tracker.get("gifted_star_count"))
	_morality_label.text = "出售 %d  赠予 %d" % [sold, gifted]


func _update_day_display() -> void:
	if _day_cycle == null or _day_info_label == null:
		return
	var day: int = _day_cycle.get("day_count")
	var is_night_now: bool = _day_cycle.get("is_night")
	var remaining: int = _day_cycle.get_remaining_entries() if _day_cycle.has_method("get_remaining_entries") else 0
	if is_night_now:
		_day_info_label.text = "第 %d 天 | 夜晚" % day
	else:
		_day_info_label.text = "第 %d 天 | 剩余下矿 %d 次" % [day, remaining]


# ---- Equipment Shop ----

func _open_equipment_shop() -> void:
	if _runtime == null:
		return
	var eq: Object = _runtime.get("equipment_system")
	if eq == null:
		_show_toast("装备系统未初始化。")
		return
	for child in _popup_body.get_children():
		child.queue_free()
	_popup_title.text = "铁匠青年 — 装备商店"
	var wallet: Object = _runtime.get("wallet")
	var balance: int = wallet.get_balance() if wallet else 0
	var hint := Label.new()
	hint.text = "当前铜板: %d | 已拥有槽位: %s" % [balance, str(eq.get_equipped_slots())]
	_popup_body.add_child(hint)

	var tracker: Object = _runtime.get("morality_tracker")
	var evil_unlocked: bool = tracker and tracker.get("sold_star_count") >= 2
	var good_unlocked: bool = tracker and tracker.get("gifted_star_count") >= 2

	var all: Dictionary = eq.get_all_equipment()
	for eid in all:
		var e: Dictionary = all[eid]
		var alignment: String = str(e.get("alignment", "neutral"))
		var obtain: String = str(e.get("obtain", ""))

		# Only show buyable items
		if obtain != "buy":
			continue
		# Filter by alignment unlock
		if alignment == "evil" and not evil_unlocked:
			continue
		if alignment == "good" and not good_unlocked:
			continue

		var cost: int = int(e.get("cost", 0))
		var owned: bool = eq.owns(eid)
		var label_text: String = "(%s) %s - %d 铜" % [str(e.get("name", eid)), str(e.get("description", "")), cost]
		if owned:
			label_text = "✓ 已拥有 | " + label_text
			var greyed: Button = _add_button(label_text, Callable())
			greyed.disabled = true
		elif balance < cost:
			label_text = "铜板不足 | " + label_text
			var greyed2: Button = _add_button(label_text, Callable())
			greyed2.disabled = true
		else:
			var btn: Button = _add_button("购买 > " + label_text, Callable(self, "_buy_equipment").bind(eid, cost))
	if all.is_empty():
		_add_button("（暂无可用装备）", Callable())
	_add_button("返回", Callable(self, "_open_popup").bind("blacksmith"))


func _buy_equipment(eid: String, cost: int) -> void:
	if _runtime == null:
		return
	var eq: Object = _runtime.get("equipment_system")
	var wallet: Object = _runtime.get("wallet")
	if eq == null or wallet == null:
		return
	var result: Dictionary = eq.buy(eid, wallet.get_balance())
	if not result.get("ok", false):
		_show_toast(str(result.get("error", "购买失败")))
		return
	wallet.spend_currency(cost)
	var name: String = str(eq.get_equip_name(eid))
	_show_toast("购买了（%s）！已自动装备。" % name)
	_refresh_hud("")
	_open_equipment_shop()


# ---- Refine Workstation (pre-placed in scene) ----


func _open_refine_picker() -> void:
	if _runtime == null:
		return
	var warehouse: Object = _runtime.get("warehouse")
	var catalog: Object = _runtime.get("catalog")
	if warehouse == null or catalog == null:
		return
	for child in _popup_body.get_children():
		child.queue_free()
	_popup.visible = true
	_popup_title.text = "精炼台 — 矿物升格"
	var hint := Label.new()
	hint.text = "消耗铜板将矿物精炼为高价值版本（售价×2，送礼×2）。"
	_popup_body.add_child(hint)
	for stack_variant in warehouse.get_stacks():
		var stack: Dictionary = stack_variant
		var item_id: String = str(stack.get("item_id", ""))
		var item: Dictionary = catalog.get_item(item_id)
		if str(item.get("category", "")) != "mineral":
			continue
		var cost: int = _refine_station.get_refine_cost(str(item.get("rarity", "common")))
		var name: String = str(item.get("name", item_id))
		var qty: int = int(stack.get("quantity", 0))
		_add_button("精炼 %s x%d（需 %d 铜）" % [name, qty, cost], Callable(self, "_do_refine").bind(item_id))
	_add_button("离开", Callable(self, "_close_popup"))


func _do_refine(item_id: String) -> void:
	if _refine_station == null:
		return
	var result: Dictionary = _refine_station.refine(item_id)
	if result.get("ok", false):
		_show_toast("已精炼为 %s！" % str(result.get("name", "")))
	else:
		_show_toast(str(result.get("error", "精炼失败")))
	_refresh_hud("")
	_open_refine_picker()


# ---- Night Shop ----

func _open_night_shop() -> void:
	if _runtime == null:
		return
	for child in _popup_body.get_children():
		child.queue_free()
	_popup_title.text = "商人 — 夜店"

	# Generate a random night customer
	var catalog: Object = _runtime.get("catalog")
	var warehouse: Object = _runtime.get("warehouse")
	var customers: Array = catalog.get_night_customers()
	if customers.is_empty():
		_add_button("今晚没有客商路过。", Callable())
		_add_button("返回", Callable(self, "_open_popup").bind("buyer"))
		return

	var c: Dictionary = customers[randi() % customers.size()]
	_shop_night_customer_id = str(c.get("id", ""))
	var prefs: Array = c.get("preferred_tags", [])
	var hint := Label.new()
	hint.text = "一位客商路过……偏好: %s | 溢价: %.0f%%" % [str(prefs), float(c.get("price_multiplier", 1.3)) * 100.0 - 100.0]
	_popup_body.add_child(hint)

	if warehouse == null:
		_add_button("返回", Callable(self, "_open_popup").bind("buyer"))
		return
	for stack_variant in warehouse.get_stacks():
		var stack: Dictionary = stack_variant
		var item_id: String = str(stack.get("item_id", ""))
		var item: Dictionary = catalog.get_item(item_id)
		if str(item.get("category", "")) != "mineral":
			continue
		var qty: int = int(stack.get("quantity", 0))
		if qty <= 0:
			continue
		var is_pref: bool = false
		for tag in prefs:
			var item_tags: Array = item.get("tags", [])
			if tag in item_tags:
				is_pref = true
				break
		var label_text: String = "%s x%d" % [str(item.get("name", item_id)), qty]
		if is_pref:
			label_text += " ★偏好"
		_add_button("出售 %s" % label_text, Callable(self, "_do_night_sell").bind(item_id, is_pref))
	_add_button("打烊", Callable(self, "_open_popup").bind("buyer"))


func _do_night_sell(item_id: String, is_preferred: bool) -> void:
	if _runtime == null:
		return
	var customer_id: String = _shop_night_customer_id
	if customer_id.is_empty():
		return
	var timing: String = "perfect" if is_preferred else "normal"
	var result: Dictionary = _runtime.get("shop_service").sell_to_customer(customer_id, item_id, 1, {"timing": timing})
	if result.get("ok", false):
		var total: int = int(result.get("total_price", 0))
		_show_toast("夜店卖出 +%d 铜板" % total)
	else:
		_show_toast(str(result.get("message", result.get("error", "交易失败"))))
	_refresh_hud("")
	_open_night_shop()


# ---- Florist Equipment Reward Check ----

func _check_florist_reward() -> void:
	var tracker: Object = _runtime.get("morality_tracker") if _runtime else null
	var affection: Object = _runtime.get("npc_affection") if _runtime else null
	var eq: Object = _runtime.get("equipment_system") if _runtime else null
	if tracker == null or affection == null or eq == null:
		return
	if tracker.get("gifted_star_count") >= 2 and affection.get_affection("florist") >= 50:
		var reward_eids: Array = ["calm_stone", "recall_shard", "empathy_aura"]
		for eid in reward_eids:
			if not eq.owns(eid):
				eq.receive_gift(eid, "florist")
				_show_toast("花店少女赠送了（%s）！" % str(eq.get_equip_name(eid)))
		return
