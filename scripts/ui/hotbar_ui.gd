extends Control

## 屏幕底部热栏：展示背包 12 格，前 unlocked_slots 格可用，其余锁定。
## 同类物品堆叠时在右下角显示数量。跟随 InventoryManager.inventory_changed 刷新。

const SLOT_COUNT: int = 12
const SLOT_EMPTY_TEXTURE := preload("res://assets/ui/slots/slot_empty.png")
const SLOT_FILLED_TEXTURE := preload("res://assets/ui/slots/slot_filled.png")
const SLOT_DISABLED_TEXTURE := preload("res://assets/ui/slots/slot_disabled.png")
@export var slot_size: float = 64.0
@export var slot_gap: float = 6.0
@export var bottom_margin: float = 24.0
@export var locked_modulate: Color = Color(0.35, 0.35, 0.35, 1.0)

var _inv: Node
var _db: Node
var _slots: Array = []

func _ready() -> void:
	_db = get_node_or_null("/root/ItemDatabase")
	var player: Node = get_tree().get_first_node_in_group("player")
	if player:
		_inv = player.get_node_or_null("InventoryManager")
	_build_slots()
	if _inv and _inv.has_signal("inventory_changed"):
		_inv.inventory_changed.connect(_refresh)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh()

func _build_slots() -> void:
	for i in range(SLOT_COUNT):
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(slot_size, slot_size)
		panel.size = Vector2(slot_size, slot_size)
		panel.add_theme_stylebox_override("panel", _slot_style(SLOT_EMPTY_TEXTURE))

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)

		var count := Label.new()
		count.name = "Count"
		count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.offset_left = -slot_size
		count.offset_top = -22.0
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(count)

		var lock := Label.new()
		lock.name = "Lock"
		lock.text = "🔒"
		lock.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(lock)

		add_child(panel)
		_slots.append(panel)


func _slot_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 6
	style.texture_margin_right = 6
	style.texture_margin_top = 6
	style.texture_margin_bottom = 6
	return style


func _layout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var total_w: float = SLOT_COUNT * slot_size + (SLOT_COUNT - 1) * slot_gap
	var start_x: float = (vp.x - total_w) / 2.0
	var y: float = vp.y - slot_size - bottom_margin
	for i in range(_slots.size()):
		_slots[i].position = Vector2(start_x + i * (slot_size + slot_gap), y)

func _refresh() -> void:
	if _inv == null:
		return
	if _db == null:
		_db = get_node_or_null("/root/ItemDatabase")
	var unlocked: int = _inv.unlocked_slots
	for i in range(SLOT_COUNT):
		var panel: Panel = _slots[i]
		var icon: TextureRect = panel.get_node("Icon")
		var count: Label = panel.get_node("Count")
		var lock: Label = panel.get_node("Lock")

		var locked: bool = i >= unlocked
		lock.visible = locked
		panel.modulate = locked_modulate if locked else Color.WHITE

		var item: Dictionary = _inv.get_item(i)
		if locked:
			panel.add_theme_stylebox_override("panel", _slot_style(SLOT_DISABLED_TEXTURE))
			icon.texture = null
			count.text = ""
			continue
		if item.is_empty():
			panel.add_theme_stylebox_override("panel", _slot_style(SLOT_EMPTY_TEXTURE))
			icon.texture = null
			count.text = ""
			continue

		panel.add_theme_stylebox_override("panel", _slot_style(SLOT_FILLED_TEXTURE))
		if _db:
			icon.texture = _db.get_icon(item["type"], item["data"])
		var c: int = int(item.get("count", 1))
		count.text = str(c) if c > 1 else ""
