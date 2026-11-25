extends Node2D
class_name InkTideController

## Drives the Living Shadow Ink Tide shader uniforms and procedural writhing tendrils

@onready var ink_rect: ColorRect = $InkRect

var proximity: float = 0.16
var surge_intensity: float = 0.0
var _time: float = 0.0

func reset_tide() -> void:
	proximity = 0.16
	surge_intensity = 0.0
	_sync_shader()

func push_back(amount: float) -> void:
	proximity = maxf(0.05, proximity - amount)

func surge_forward(amount: float) -> void:
	proximity = minf(1.05, proximity + amount)
	surge_intensity = 1.0

func update_tide(dt: float, player_vx: float, ref_pace: float, flow_multiplier: int, is_playing: bool) -> void:
	_time += dt
	surge_intensity = maxf(0.0, surge_intensity - dt * 1.4)
	if is_playing:
		var pace_delta := (ref_pace - player_vx) / 900.0
		var flow_relief := float(flow_multiplier - 1) * 0.0045
		var rate := pace_delta * 0.14 + 0.008 - flow_relief
		proximity = clampf(proximity + rate * dt, 0.05, 1.05)
	else:
		proximity = 0.14
	_sync_shader()
	queue_redraw()

func _sync_shader() -> void:
	if ink_rect and ink_rect.material is ShaderMaterial:
		var mat: ShaderMaterial = ink_rect.material
		mat.set_shader_parameter("proximity", proximity)
		mat.set_shader_parameter("surge_intensity", surge_intensity)
		ink_rect.size = get_viewport_rect().size

func _draw() -> void:
	var vp := get_viewport_rect().size
	var base_x := -24.0 + proximity * (vp.x * 0.37)
	# Writhing shadowy tendrils reaching hungrily toward the runner
	for i in range(6):
		var ty := vp.y * (0.2 + float(i) * 0.13)
		var reach := 42.0 + proximity * 115.0 + sin(_time * 3.8 + float(i) * 1.7) * 28.0
		var curl := sin(_time * 5.2 + float(i) * 2.3) * 22.0
		var pts := PackedVector2Array([
			Vector2(base_x - 8.0, ty),
			Vector2(base_x + reach * 0.42, ty + curl),
			Vector2(base_x + reach * 0.78, ty - curl * 0.8),
			Vector2(base_x + reach, ty + curl * 0.45)
		])
		draw_polyline(pts, Color(0.03, 0.01, 0.07, 0.92), maxf(3.0, 8.0 - float(i) * 0.5), true)
		draw_circle(pts[-1], 2.4, Color(0.66, 0.33, 0.97, 0.32 + proximity * 0.35))
