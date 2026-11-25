extends Node2D
class_name InkTideController

## Drives the Living Shadow Ink Tide watercolor/ink-wash shader uniforms,
## rising violet-amethyst ash embers, and smooth organic shadow wisps
## (zero harsh circles or zig-zag lines).

@onready var ink_rect: ColorRect = $InkRect

var proximity: float = 0.14
var surge_intensity: float = 0.0
var _time: float = 0.0
var _embers: Array[Dictionary] = []

func _ready() -> void:
	for i in range(28):
		_embers.append({
			"y": randf(),
			"dx": randf_range(-12.0, 56.0),
			"vy": randf_range(0.05, 0.16),
			"vx": randf_range(16.0, 58.0),
			"size": randf_range(2.0, 5.2),
			"phase": randf_range(0.0, TAU)
		})

func reset_tide() -> void:
	proximity = 0.14
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
		var pace_delta: float = (ref_pace - player_vx) / 900.0
		var flow_relief: float = float(flow_multiplier - 1) * 0.0045
		var rate: float = pace_delta * 0.14 + 0.008 - flow_relief
		proximity = clampf(proximity + rate * dt, 0.05, 1.05)
	else:
		proximity = 0.12

	for e in _embers:
		var ey_norm: float = float(e["y"]) - float(e["vy"]) * dt
		var edx: float = float(e["dx"]) + float(e["vx"]) * dt
		if ey_norm < -0.05 or edx > 115.0 + proximity * 85.0:
			ey_norm = randf_range(0.10, 1.02)
			edx = randf_range(-14.0, 16.0)
		e["y"] = ey_norm
		e["dx"] = edx

	_sync_shader()
	queue_redraw()

func _sync_shader() -> void:
	if ink_rect != null and ink_rect.material is ShaderMaterial:
		var mat: ShaderMaterial = ink_rect.material as ShaderMaterial
		mat.set_shader_parameter("proximity", proximity)
		mat.set_shader_parameter("surge_intensity", surge_intensity)
		var vp: Vector2 = get_viewport_rect().size
		if vp.x > 1.0 and vp.y > 1.0:
			ink_rect.position = Vector2.ZERO
			ink_rect.size = vp

func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return
	var base_x: float = -18.0 + proximity * (vp.x * 0.34)

	# Smooth curved shadowy ink tendrils ONLY when danger is high (proximity > 0.38)
	if proximity > 0.38:
		var tendril_t: float = clampf((proximity - 0.38) / 0.62, 0.0, 1.0)
		for k in range(3):
			var fk: float = float(k)
			var y0: float = vp.y * (0.28 + fk * 0.22) + sin(_time * 1.7 + fk * 2.1) * 18.0
			var t_len: float = 52.0 + tendril_t * 105.0
			var pts: PackedVector2Array = PackedVector2Array()
			for st in range(10):
				var f: float = float(st) / 9.0
				var tx: float = base_x - 10.0 + f * t_len
				var ty: float = y0 + sin(_time * 3.0 - f * 3.8 + fk * 1.8) * (18.0 * f)
				pts.append(Vector2(tx, ty))
			draw_polyline(pts, Color(0.56, 0.28, 0.94, 0.20 * tendril_t), 9.0, true)
			draw_polyline(pts, Color(0.024, 0.010, 0.056, 0.65 * tendril_t), 4.8, true)

	# Delicate rising luminous amethyst-cyan ash embers along the silky ink edge
	for e in _embers:
		var edx: float = float(e["dx"])
		var ephase: float = float(e["phase"])
		var esize: float = float(e["size"])
		var ex: float = base_x + edx + sin(_time * 2.1 + ephase) * 14.0
		var ey: float = float(e["y"]) * vp.y
		var fade: float = clampf(1.0 - maxf(0.0, edx) / (115.0 + proximity * 85.0), 0.0, 1.0)
		draw_circle(Vector2(ex, ey), esize * 1.4, Color(0.64, 0.36, 1.0, (0.14 + proximity * 0.18) * fade))
		draw_circle(Vector2(ex, ey), esize * 0.45, Color(0.94, 0.84, 1.0, (0.56 + proximity * 0.36) * fade))
