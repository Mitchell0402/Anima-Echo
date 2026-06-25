extends CanvasLayer
## Standalone warehouse UI. Opened by the I key in town. Shows a 6x8 grid
## of slots backed by GameRuntime.warehouse. Empty slots render as grey.
## Occupied slots show the item icon (best effort) and the stack quantity
## in the bottom-right corner. Hovering a slot shows a tooltip with the
## item name, description, and base_price. The UI is read-only: writes
## happen through NPC actions or the mine handoff.
##
## Slot and panel sizes scale with the viewport: the panel is always 80% of
## the shorter screen dimension, and slots are sized so 6 columns fit
## comfortably with breathing room. Slots are clamped to a sane minimum
## (32 px) and a sane maximum (80 px) so the panel is usable from 800x450
## to 1920x1080.

const COLS: int = 3
const ROWS: int = 4
const SLOT_GAP: float = 6.0
const PANEL_PADDING: float = 14.0
const TITLE_HEIGHT: float = 32.0
const FOOTER_HEIGHT: float = 22.0
const MIN_SLOT_SIZE: float = 32.0
const MAX_SLOT_SIZE: float = 80.0
const MIN_PANEL_W: float = 360.0
const MIN_PANEL_H: float = 280.0
# The panel aims for 80% of the shorter screen dimension so the UI is
# readable at any resolution. The clamp is what makes the minimum-size
# guarantee work: even at 800x450 the panel will still be at least 360x280.
const PANEL_SCALE: float = 0.8

var _panel: PanelContainer
var _grid: GridContainer
var _tooltip: PanelContainer
var _tooltip_name: Label
var _tooltip_desc: Label
var _tooltip_price: Label
var _overlay: ColorRect
var _is_open: bool = false
var _hovered_item_id: String = ""
var _slot_size: float = 64.0  # Recomputed in _build / _layout from viewport size.


func _ready() -> void:
	layer = 10
	_build()
	visible = false
	set_process_unhandled_input(true)
	# Re-layout when the viewport resizes. The warehouse is only on screen
	# in town, but the cost is negligible and it keeps the contract clean.
	get_viewport().size_changed.connect(_on_viewport_resized)


func _compute_slot_size() -> float:
	# The slot is sized to make 6 columns fit in 80% of the shorter
	# viewport dimension. This keeps the panel centered and readable
	# on a wide range of resolutions.
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var panel_w_target: float = maxf(vp.x * PANEL_SCALE, MIN_PANEL_W)
	# Solve: panel_w = COLS * slot + (COLS - 1) * SLOT_GAP + 2 * PANEL_PADDING
	var inner_w: float = panel_w_target - 2.0 * PANEL_PADDING - float(COLS - 1) * SLOT_GAP
	var raw: float = inner_w / float(COLS)
	return clampf(raw, MIN_SLOT_SIZE, MAX_SLOT_SIZE)


func _compute_panel_size() -> Vector2:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var panel_w: float = float(COLS) * _slot_size + float(COLS - 1) * SLOT_GAP + 2.0 * PANEL_PADDING
	var panel_h: float = TITLE_HEIGHT + float(ROWS) * _slot_size + float(ROWS - 1) * SLOT_GAP + FOOTER_HEIGHT + 2.0 * PANEL_PADDING
	# Clamp to viewport-derived min/max so the panel never goes off-screen.
	panel_w = clampf(panel_w, MIN_PANEL_W, vp.x)
	panel_h = clampf(panel_h, MIN_PANEL_H, vp.y)
	return Vector2(panel_w, panel_h)


func _on_viewport_resized() -> void:
	# Re-layout even if not currently visible so the next open is fresh.
	_slot_size = _compute_slot_size()
	if _panel != null:
		var panel_size: Vector2 = _compute_panel_size()
		_panel.custom_minimum_size = panel_size
		_panel.size = panel_size
		_rebuild_slot_sizes()


func _rebuild_slot_sizes() -> void:
	if _grid == null:
		return
	# Update the slot children to match the new size.
	for slot in _grid.get_children():
		if slot is Control:
			slot.custom_minimum_size = Vector2(_slot_size, _slot_size)
			slot.size = Vector2(_slot_size, _slot_size)
			# Reposition the count label inside the slot.
			var count: Label = slot.get_node_or_null("Count")
			if count != null:
				count.position = Vector2(0, _slot_size - 18)
				count.size = Vector2(_slot_size, 18)


func _build() -> void:
	# Dimming overlay covers the whole screen and is independent of the
	# panel. The town scene still renders behind it.
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	# Compute the slot size for the current viewport before laying out.
	_slot_size = _compute_slot_size()
	# Panel
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	var panel_size: Vector2 = _compute_panel_size()
	_panel.custom_minimum_size = panel_size
	_panel.size = panel_size
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	# Title + grid + footer layout.
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", PANEL_PADDING)
	_panel.add_child(root)
	var title: Label = Label.new()
	title.text = "仓库"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	root.add_child(title)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", int(SLOT_GAP))
	_grid.add_theme_constant_override("v_separation", int(SLOT_GAP))
	# Force the grid to its expected minimum width so the panel does not
	# collapse to a narrower size when the GridContainer auto-fits.
	_grid.custom_minimum_size = Vector2(panel_size.x - 2.0 * PANEL_PADDING,
		TITLE_HEIGHT + float(ROWS) * _slot_size + float(ROWS - 1) * SLOT_GAP + FOOTER_HEIGHT)
	root.add_child(_grid)
	for i in range(COLS * ROWS):
		_grid.add_child(_build_slot())
	# Tooltip (initially hidden). Built once; toggled visible on hover.
	_tooltip = PanelContainer.new()
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tooltip)
	var tip_root: VBoxContainer = VBoxContainer.new()
	_tooltip.add_child(tip_root)
	_tooltip_name = Label.new()
	_tooltip_name.add_theme_font_size_override("font_size", 14)
	tip_root.add_child(_tooltip_name)
	_tooltip_desc = Label.new()
	_tooltip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_desc.custom_minimum_size = Vector2(280, 0)
	tip_root.add_child(_tooltip_desc)
	_tooltip_price = Label.new()
	tip_root.add_child(_tooltip_price)


func _build_slot() -> Panel:
	var slot: Panel = Panel.new()
	slot.custom_minimum_size = Vector2(_slot_size, _slot_size)
	slot.size = Vector2(_slot_size, _slot_size)
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	var icon: TextureRect = TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	var count: Label = Label.new()
	count.name = "Count"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.position = Vector2(0, _slot_size - 18)
	count.size = Vector2(_slot_size, 18)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.add_theme_font_size_override("font_size", 12)
	slot.add_child(count)
	slot.mouse_entered.connect(_on_slot_hover.bind(slot))
	slot.mouse_exited.connect(_on_slot_unhover)
	return slot


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	# Open / close via I or Esc.
	var is_toggle: bool = event.is_action_pressed("toggle_warehouse")
	var is_cancel: bool = event.is_action_pressed("ui_cancel")
	if not is_toggle and not is_cancel:
		return
	if _is_open:
		hide_warehouse()
	else:
		# Open only in town (or any non-mine scene).
		var runtime: Node = get_node_or_null("/root/GameRuntime")
		if runtime != null and runtime.has_method("is_in_mine_scene") and runtime.is_in_mine_scene():
			return
		show_warehouse()
	get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _is_open


func show_warehouse() -> void:
	# Re-layout on every open in case the viewport has changed since the
	# last open. _compute_slot_size is cheap (one division + clamp).
	_slot_size = _compute_slot_size()
	if _panel != null:
		var panel_size: Vector2 = _compute_panel_size()
		_panel.custom_minimum_size = panel_size
		_panel.size = panel_size
		_rebuild_slot_sizes()
	_refresh_slots()
	visible = true
	_is_open = true


func hide_warehouse() -> void:
	visible = false
	_is_open = false
	_tooltip.visible = false


func _refresh_slots() -> void:
	# Slot order: catalog.json items array order, then empty slots.
	# Empty slots render as light grey. Occupied slots show the item icon
	# (best effort) and the stack quantity in the bottom-right.
	var runtime: Node = get_node_or_null("/root/GameRuntime")
	var warehouse: Object = runtime.get("warehouse") if runtime != null else null
	var catalog: Object = runtime.get("catalog") if runtime != null else null
	# Build a list of stacks in catalog order so the player can see items
	# the same way the catalog declares them.
	var ordered: Array = []
	if warehouse != null and catalog != null:
		for item in catalog.get_all_items():
			var item_id: String = str(item.get("id", ""))
			if warehouse.has_item(item_id, 1):
				var qty: int = int(warehouse.count_item(item_id))
				ordered.append({"item_id": item_id, "quantity": qty})
	# Fill slots.
	for i in range(_grid.get_child_count()):
		var slot: Panel = _grid.get_child(i)
		var icon: TextureRect = slot.get_node("Icon")
		var count: Label = slot.get_node("Count")
		var data: Dictionary = ordered[i] if i < ordered.size() else {}
		var item_id: String = str(data.get("item_id", ""))
		var quantity: int = int(data.get("quantity", 0))
		if item_id.is_empty():
			icon.texture = null
			count.text = ""
			slot.modulate = Color(0.85, 0.85, 0.85, 1.0)
		else:
			# No per-item texture yet (catalog has no icon mapping); show a
			# visible placeholder so the player can tell the slot is occupied.
			# White background with a small color bar at the bottom hinting
			# at the item's category. This makes the warehouse read as
			# "stuff is here" even before icon assets exist.
			var placeholder := ColorRect.new()
			placeholder.color = Color(0.95, 0.85, 0.45, 1.0)  # warm gold
			placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
			placeholder.size = Vector2(0, 0)
			icon.add_child(placeholder)
			count.text = str(quantity) if quantity > 1 else ""
			slot.modulate = Color.WHITE
			# Stash on the slot for later refreshes so we don't pile up
			# placeholder children.
			slot.set_meta("placeholder", placeholder)
		# Bind the item id onto the slot for hover lookup.
		slot.set_meta("item_id", item_id)


func _on_slot_hover(slot: Panel) -> void:
	_hovered_item_id = String(slot.get_meta("item_id", ""))
	if _hovered_item_id.is_empty():
		_tooltip.visible = false
		return
	var runtime: Node = get_node_or_null("/root/GameRuntime")
	if runtime == null:
		return
	var item: Dictionary = runtime.get("catalog").get_item(_hovered_item_id)
	var db: Node = get_node_or_null("/root/ItemDatabase")
	var name: String = str(item.get("name", _hovered_item_id))
	var description: String = ""
	if db != null and db.has_method("get_description"):
		description = db.get_description(_hovered_item_id)
	_tooltip_name.text = name
	_tooltip_desc.text = description
	# Only sellable categories (mineral) show a base_price. Raw stones
	# are not sold by any customer, so showing a price would be
	# misleading. The price is the catalog base_price, before any
	# negotiation or preferred-tag multiplier.
	if item.get("category", "") == "mineral" and item.has("base_price"):
		_tooltip_price.text = "底价: %d 铜板" % int(item.get("base_price", 0))
	else:
		_tooltip_price.text = ""
	_tooltip.visible = true
	# Position the tooltip near the cursor.
	_tooltip.position = get_viewport().get_mouse_position() + Vector2(16, 16)


func _on_slot_unhover() -> void:
	_hovered_item_id = ""
	_tooltip.visible = false
