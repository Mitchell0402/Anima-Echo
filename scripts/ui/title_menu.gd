extends CanvasLayer

const BUTTON_NORMAL_TEXTURE := preload("res://assets/ui/buttons/button_normal.png")
const BUTTON_HOVER_TEXTURE := preload("res://assets/ui/buttons/button_hover.png")
const BUTTON_DISABLED_TEXTURE := preload("res://assets/ui/buttons/button_disabled.png")

var _btn_start: Button
var _btn_continue: Button
var _btn_setting: Button
var _btn_exit: Button

func _ready() -> void:
	layer = 11
	_build()

func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = preload("res://assets/ui/screens/title_background.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.04, 0.48)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	# Center container — anchors at (0.5,0.5), grows outward in both directions
	var center := VBoxContainer.new()
	center.anchor_left = 0.5
	center.anchor_top = 0.5
	center.anchor_right = 0.5
	center.anchor_bottom = 0.5
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.add_theme_constant_override("separation", 12)
	add_child(center)

	# Title
	var title := Label.new()
	title.text = "别按那个键"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.15, 1.0))
	center.add_child(title)

	# Spacer
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 30)
	center.add_child(spacer1)

	# Start
	_btn_start = _make_button("START")
	_btn_start.pressed.connect(_on_start)
	center.add_child(_btn_start)

	# Continue (no save yet — disabled)
	_btn_continue = _make_button("CONTINUE")
	_btn_continue.disabled = true
	_btn_continue.pressed.connect(_on_continue)
	center.add_child(_btn_continue)

	# Setting
	_btn_setting = _make_button("SETTING")
	_btn_setting.pressed.connect(_on_setting)
	center.add_child(_btn_setting)

	# Exit
	_btn_exit = _make_button("EXIT")
	_btn_exit.pressed.connect(_on_exit)
	center.add_child(_btn_exit)

	# Version / hint
	var hint := Label.new()
	hint.text = "v0.1 · GameJam"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1.0))
	hint.modulate = Color(1, 1, 1, 0.5)
	center.add_child(hint)

	# Small spacer before test button
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 16)
	center.add_child(spacer2)

	# Test — skip intro, go directly to town
	var btn_test := Button.new()
	btn_test.text = "TEST"
	btn_test.custom_minimum_size = Vector2(160, 32)
	btn_test.add_theme_font_size_override("font_size", 13)
	btn_test.add_theme_color_override("font_color", Color(0.6, 0.6, 0.3, 1.0))
	btn_test.pressed.connect(_on_test)
	center.add_child(btn_test)


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 44)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_stylebox_override("normal", _button_style(BUTTON_NORMAL_TEXTURE))
	btn.add_theme_stylebox_override("hover", _button_style(BUTTON_HOVER_TEXTURE))
	btn.add_theme_stylebox_override("pressed", _button_style(BUTTON_HOVER_TEXTURE))
	btn.add_theme_stylebox_override("disabled", _button_style(BUTTON_DISABLED_TEXTURE))
	return btn


func _button_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 8
	style.texture_margin_right = 8
	style.texture_margin_top = 8
	style.texture_margin_bottom = 8
	return style


func _on_start() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
	get_tree().change_scene_to_file("res://scenes/ui/intro.tscn")


func _on_continue() -> void:
	# No save system yet — this button is disabled.
	pass


func _on_setting() -> void:
	var popup := AcceptDialog.new()
	popup.title = "设置"
	popup.dialog_text = "设置功能尚未开放。\n\n按 Esc 返回。"
	popup.popup_centered()


func _on_exit() -> void:
	get_tree().quit()


func _on_test() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
	get_tree().change_scene_to_file("res://scenes/town/mining_town.tscn")
