## 按鼠标左键前进到下一条，按 Esc 结束对话返回交互面板。
extends CanvasLayer
class_name DialogueUI

var _box: PanelContainer
var _portrait: TextureRect
var _name_label: Label
var _text_label: Label
var _lines: Array[String] = []
var _line_index: int = 0
var _on_done: Callable

const CHARS_PER_SECOND := 60.0
var _display_timer: float = 0.0
var _display_index: int = 0
var _full_text: String = ""
var _showing_full: bool = false

func _ready() -> void:
	layer = 12
	_build()
	visible = false

func _build() -> void:
	# Full-screen dark background (click-through)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Bottom dialogue box
	_box = PanelContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_box.offset_left = 40
	_box.offset_right = -40
	_box.offset_top = -180
	_box.offset_bottom = -20
	add_child(_box)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	_box.add_child(hbox)

	# Portrait area
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(96, 96)
	_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(_portrait)

	# Text area
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 17)
	vbox.add_child(_name_label)

	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 15)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_text_label)


func open(npc_name: String, portrait_path: String, lines: Array[String], on_done: Callable) -> void:
	_name_label.text = npc_name
	var tex: Texture2D = load(portrait_path) if portrait_path else null
	if tex:
		_portrait.texture = tex
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_lines = lines
	_line_index = 0
	_on_done = on_done
	visible = true
	_show_current_line()


func _process(delta: float) -> void:
	if not visible or _text_label == null:
		return
	if not _showing_full:
		_display_timer += delta
		var char_count := int(_display_timer * CHARS_PER_SECOND)
		if char_count > _display_index:
			_display_index = mini(char_count, _full_text.length())
			_text_label.visible_characters = _display_index
			if _display_index >= _full_text.length():
				_showing_full = true


func _show_current_line() -> void:
	if _line_index >= _lines.size():
		_close()
		return
	_full_text = _lines[_line_index]
	_text_label.text = _full_text
	_text_label.visible_characters = 0
	_display_index = 0
	_display_timer = 0.0
	_showing_full = false

	# Show a hint at the end of the text area
	if _line_index < _lines.size() - 1:
		_text_label.text += "\n\n(鼠标左键下一页)"
	else:
		_text_label.text += "\n\n(Esc 结束对话)"


func advance() -> void:
	if not _showing_full:
		# Skip typewriter: show all text immediately
		_text_label.visible_characters = -1
		_showing_full = true
		return
	_line_index += 1
	_show_current_line()


func _close() -> void:
	visible = false
	if _on_done.is_valid():
		_on_done.call()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
