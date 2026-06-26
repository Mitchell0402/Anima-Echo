extends Node
## 矿洞四周黑边雾效。
## 在场景根节点下作为一个子节点运行，自动创建 CanvasLayer + ColorRect，
## 用径向暗角 shader 覆盖世界层，但不遮挡 UI（HUD 层需设为 > vignette_layer）。
class_name MineVignette


@export_group("Layer")
@export var vignette_layer: int = 1              ## CanvasLayer 层级（世界=0，UI需>此值）

@export_group("Appearance")
@export var color: Color = Color(0.02, 0.0, 0.06, 1.0)  ## 暗角颜色（深紫黑）
@export var center_size: float = 0.5             ## 中心清晰区域半径（0~1，占屏幕比例）
@export var edge_softness: float = 0.35          ## 边缘羽化宽度（0~1）
@export var intensity: float = 1              ## 边缘暗度（0=全清，1=全黑）


func _ready() -> void:
	_create_vignette()


func _create_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.name = "VignetteLayer"
	layer.layer = vignette_layer
	add_child(layer)

	var rect := ColorRect.new()
	rect.name = "VignetteRect"
	rect.material = _create_vignette_material()
	# 铺满屏幕
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)


func _create_vignette_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = _vignette_shader_code()
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("c", color)
	mat.set_shader_parameter("center_size", center_size)
	mat.set_shader_parameter("edge_softness", edge_softness)
	mat.set_shader_parameter("intensity", intensity)
	return mat


func _vignette_shader_code() -> String:
	return """shader_type canvas_item;

uniform vec4 c : source_color;
uniform float center_size : hint_range(0.0, 1.0) = 0.5;
uniform float edge_softness : hint_range(0.01, 1.0) = 0.35;
uniform float intensity : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	float dist = distance(UV, vec2(0.5, 0.5));
	float vignette = smoothstep(center_size - edge_softness, center_size + edge_softness, dist);
	COLOR = vec4(c.rgb, vignette * intensity * c.a);
}
"""
