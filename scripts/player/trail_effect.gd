extends Node2D
## 玩家移动拖尾特效：紫色雾气 + 紫色晶片（雪花飘落感）。
## 作为 MainCharacter 的子节点使用，由 MoveController 驱动 emitting。
class_name TrailEffect

var _mist_particles: GPUParticles2D
var _star_particles: GPUParticles2D


## 是否正在发射粒子（移动时为 true）
var emitting: bool = false:
	set(v):
		emitting = v
		if _mist_particles:
			_mist_particles.emitting = v
		if _star_particles:
			_star_particles.emitting = v


# =================== 雾气参数 ===================
@export_group("Mist", "mist_")

@export_subgroup("Emission")
@export var mist_amount: int = 20              ## 每帧最大雾气粒子数
@export var mist_lifetime: float = 0.45          ## 雾气生命周期（秒）
@export var mist_spread: float = 120.0           ## 发射散布角度

@export_subgroup("Velocity")
@export var mist_initial_velocity_min: float = 10.0  ## 初始速度下限
@export var mist_initial_velocity_max: float = 35.0  ## 初始速度上限
@export var mist_gravity: Vector3 = Vector3(0, -25.0, 0)  ## 重力（向上飘升）

@export_subgroup("Appearance")
@export var mist_size_min: float = 1.0          ## 粒子最小尺寸
@export var mist_size_max: float = 3.0          ## 粒子最大尺寸
@export var mist_color: Color = Color(0.55, 0.15, 0.85, 0.55)  ## 起始色（紫色半透明）
@export var mist_color_end: Color = Color(0.45, 0.08, 0.75, 0.0)  ## 结束色（淡出透明）


# =================== 晶片参数 ===================
@export_group("StarCrystals", "star_")

@export_subgroup("Emission")
@export var star_amount: int = 5                 ## 每帧最大晶片数
@export var star_lifetime: float = 0.3            ## 晶片生命周期（秒）
@export var star_spread: float = 0.0              ## 散布角度（0=原位出现）

@export_subgroup("Velocity")
@export var star_initial_velocity_min: float = 0.0   ## 初始速度下限（0=不弹射）
@export var star_initial_velocity_max: float = 0.0   ## 初始速度上限
@export var star_gravity: Vector3 = Vector3(0, 18.0, 0)    ## 重力（缓缓下落）
@export var star_radial_accel_min: float = 3.0     ## 径向加速度下限（轻微扩散）
@export var star_radial_accel_max: float = 10.0    ## 径向加速度上限
@export var star_tangential_accel_min: float = -12.0  ## 切向加速度下限（左右飘摆）
@export var star_tangential_accel_max: float = 12.0   ## 切向加速度上限
@export var star_damping_min: float = 2.0          ## 阻尼下限（防加速）
@export var star_damping_max: float = 4.0          ## 阻尼上限

@export_subgroup("Appearance")
@export var star_size_min: float = 1.0            ## 晶片最小尺寸
@export var star_size_max: float = 2.0            ## 晶片最大尺寸
@export var star_color: Color = Color(0.75, 0.3, 1.0, 0.95)    ## 起始色（亮紫色）
@export var star_color_end: Color = Color(0.6, 0.2, 0.9, 0.0)  ## 结束色（淡出透明）
@export var star_angular_vel_min: float = -60.0    ## 自旋速度下限（度/秒）
@export var star_angular_vel_max: float = 60.0     ## 自旋速度上限（度/秒）

@export_subgroup("Animation")
@export var star_anim_speed_min: float = 0.3       ## 动画播放速度下限
@export var star_anim_speed_max: float = 1.5       ## 动画播放速度上限
@export var star_anim_offset_min: float = 0.0       ## 动画起始偏移下限
@export var star_anim_offset_max: float = 1.0       ## 动画起始偏移上限


# =================== 初始化 ===================

func _ready() -> void:
	z_index = 1

	_create_mist_particles()
	_create_star_particles()

	emitting = false


func _create_mist_particles() -> void:
	_mist_particles = GPUParticles2D.new()
	_mist_particles.name = "MistParticles"
	_mist_particles.one_shot = false
	_mist_particles.explosiveness = 0.0
	_mist_particles.amount = mist_amount
	_mist_particles.lifetime = mist_lifetime
	_mist_particles.local_coords = false
	_mist_particles.process_material = _create_mist_material()
	_mist_particles.texture = _generate_mist_texture()
	_mist_particles.emitting = false
	add_child(_mist_particles)


func _create_mist_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.particle_flag_align_y = false
	mat.spread = mist_spread
	mat.gravity = mist_gravity
	mat.initial_velocity_min = mist_initial_velocity_min
	mat.initial_velocity_max = mist_initial_velocity_max
	mat.scale_min = mist_size_max
	mat.scale_max = mist_size_min
	mat.scale_curve = _create_shrink_curve()
	mat.color = mist_color
	mat.color_ramp = _create_gradient(mist_color, mist_color_end)
	mat.alpha_curve = _create_fade_out_curve()
	return mat


func _create_star_particles() -> void:
	_star_particles = GPUParticles2D.new()
	_star_particles.name = "StarParticles"
	_star_particles.one_shot = false
	_star_particles.explosiveness = 0.0
	_star_particles.amount = star_amount
	_star_particles.lifetime = star_lifetime
	_star_particles.local_coords = false
	_star_particles.process_material = _create_star_material()
	_star_particles.texture = _generate_star_texture()
	_star_particles.emitting = false
	add_child(_star_particles)


func _create_star_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.particle_flag_align_y = false
	mat.spread = star_spread
	mat.gravity = star_gravity
	mat.initial_velocity_min = star_initial_velocity_min
	mat.initial_velocity_max = star_initial_velocity_max
	mat.radial_accel_min = star_radial_accel_min
	mat.radial_accel_max = star_radial_accel_max
	mat.tangential_accel_min = star_tangential_accel_min
	mat.tangential_accel_max = star_tangential_accel_max
	mat.damping_min = star_damping_min
	mat.damping_max = star_damping_max
	mat.angular_velocity_min = star_angular_vel_min
	mat.angular_velocity_max = star_angular_vel_max
	mat.scale_min = star_size_min
	mat.scale_max = star_size_max
	mat.scale_curve = _create_gentle_shrink_curve()
	mat.color = star_color
	mat.color_ramp = _create_gradient(star_color, star_color_end)
	mat.alpha_curve = _create_slow_fade_curve()
	mat.anim_speed_min = star_anim_speed_min
	mat.anim_speed_max = star_anim_speed_max
	mat.anim_offset_min = star_anim_offset_min
	mat.anim_offset_max = star_anim_offset_max
	return mat


# =================== 程序化纹理 ===================

func _generate_mist_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var max_dist := center.length()

	for y in size:
		for x in size:
			var dist := (Vector2(x, y) - center).length()
			var t := clampf(1.0 - dist / max_dist, 0.0, 1.0)
			t = ease(t, 2.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, t))

	return ImageTexture.create_from_image(img)


func _generate_star_texture() -> ImageTexture:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var max_dist := center.length()

	for y in size:
		for x in size:
			var p := Vector2(x, y) - center
			var dist := p.length()
			var angle := atan2(absf(p.y), absf(p.x))
			var pi_4 := PI * 0.25
			var angle_mod := fmod(angle, pi_4)
			var angle_factor := angle_mod / pi_4
			var star_intensity: float = 0.0
			if angle_factor < 0.5:
				star_intensity = 1.0 - angle_factor * 1.6
			else:
				star_intensity = (angle_factor - 0.5) * 1.6

			var t := 1.0 - dist / max_dist
			t = clampf(t * star_intensity, 0.0, 1.0)
			t = ease(t, 1.5)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, t))

	return ImageTexture.create_from_image(img)


# =================== 曲线/渐变工具 ===================

func _create_shrink_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0), 0, -2.0)
	curve.add_point(Vector2(1.0, 0.0), -2.0, 0)
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex


func _create_fade_out_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0), 0, -3.0)
	curve.add_point(Vector2(0.3, 0.4), -1.5, -1.5)
	curve.add_point(Vector2(1.0, 0.0), -2.0, 0)
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex


func _create_gentle_shrink_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0), 0, 0)
	curve.add_point(Vector2(0.6, 0.9), -0.5, -0.5)
	curve.add_point(Vector2(1.0, 0.3), -1.0, 0)
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex


func _create_slow_fade_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0), 0, 0)
	curve.add_point(Vector2(0.7, 0.9), -0.3, -0.8)
	curve.add_point(Vector2(0.9, 0.5), -2.0, -2.0)
	curve.add_point(Vector2(1.0, 0.0), -2.0, 0)
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex


func _create_gradient(from: Color, to: Color) -> GradientTexture1D:
	var grad := Gradient.new()
	grad.add_point(0.0, from)
	grad.add_point(0.3, from.lerp(to, 0.5))
	grad.add_point(1.0, to)
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	tex.width = 256
	return tex


# =================== 公共接口 ===================

func start_trail() -> void:
	emitting = true


func stop_trail() -> void:
	emitting = false
