extends CanvasLayer

var _label: Label
var _line_index: int = 0
var _fade_tween: Tween

const _INTRO_LINES := [
	"你是一个流浪的矿工。",
	"口袋里的铜板，数了又数，只剩三枚。",
	"雾隐镇——这是你在地图上能找到的，",
	"最后一个还有矿脉传闻的地方。",
	"镇口的栅栏生了锈。",
	"推开时发出刺耳的呻吟。",
	"没有人来迎接你。",
	"没有人问你是谁。",
	"街上的人低着头走路，",
	"说话的声音压得比耳语还低。",
	"只有一个老人——",
	"坐在镇口的一把旧椅子上，",
	"盯着你看了很久，什么也没说。",
	"你推开了栅栏，走了进去。",
]

func _ready() -> void:
	layer = 12
	_build()
	_show_next_line()


func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = preload("res://assets/ui/screens/intro_background.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.68)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	# Text label — grow from center in both directions so content stays
	# centered regardless of line length.
	_label = Label.new()
	_label.anchor_left = 0.5
	_label.anchor_top = 0.5
	_label.anchor_right = 0.5
	_label.anchor_bottom = 0.5
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	_label.modulate.a = 0.0
	add_child(_label)

	# Hint at bottom
	var hint := Label.new()
	hint.text = "（点击鼠标左键继续）"
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_bottom = -40
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1.0))
	add_child(hint)


func _show_next_line() -> void:
	if _line_index >= _INTRO_LINES.size():
		_start_game()
		return

	_label.text = _INTRO_LINES[_line_index]
	_fade_in()


func _fade_in() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_label, "modulate:a", 1.0, 0.4)


func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/town/mining_town.tscn")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_line_index += 1
		if _label != null:
			_label.modulate.a = 0.0
		_show_next_line()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
