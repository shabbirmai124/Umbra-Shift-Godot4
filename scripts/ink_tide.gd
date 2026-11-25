extends Node2D
class_name InkTideController

## Drives the Living Shadow Ink Tide shader uniforms, smooth tapered writhing tendrils,
## and rising dark curling smoke / violet ash ember particles.

@onready var ink_rect: ColorRect = $InkRect

var proximity: float = 0.16
var surge_intensity: float = 0.0
var _time: float = 0.0
var _embers: Array[Dictionary] = []

func _ready() -> void:
	for i in range(32):
		_embers.append({
			"y": randf(),
			"dx": randf_range(-18.0, 58.0),
			"vy": randf_range(0.06, 0.18),
			"vx": randf_range(16.0, 62.0),
			"size": randf_range(2.2, 7.2),
			"phase": randf_range(0.0, TAU),
			"is_smoke": i % 2 == 0
		})

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
		var pace_delta: float = (ref_pace - player_vx) / 900.0
		var flow_relief: float = float(flow_multiplier - 1) * 0.0045
		var rate: float = pace_delta * 0.14 + 0.008 - flow_relief
		proximity = clampf(proximity + rate * dt, 0.05, 1.05)
	else:
		proximity = 0.14

	for e in _embers:
		var ey_norm: float = float(e["y"]) - float(e["vy"]) * dt
		var edx: float = float(e["dx"]) + float(e["vx"]) * dt
		if ey_norm < -0.05 or edx > 130.0 + proximity * 90.0:
			ey_norm = randf_range(0.12, 1.02)
			edx = randf_range(-16.0, 18.0)
		e["y"] = ey_norm
		e["dx"] = edx

	_sync_shader()
	queue_redraw()

func _sync_shader() -> void:
	if ink_rect != null and ink_rect.material is ShaderMaterial:
		var mat: ShaderMaterial = ink_rect.material as ShaderMaterial
		mat.set_shader_parameter("proximity", proximity)
		mat.set_shader_parameter("surge_intensity", surge_intensity)
		ink_rect.size = get_viewport_rect().size

func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return
	var base_x: float = -24.0 + proximity * (vp.x * 0.35)

	# Billowing shadowed ink-cloud plumes anchored cleanly into the boiling ink tide wall
	for i in range(7):
		var fi: float = float(i)
		var ty: float = vp.y * (0.08 + fi * 0.145) + sin(_time * 1.4 + fi * 1.9) * 14.0
		var reach: float = 34.0 + proximity * 96.0 + sin(_time * 2.2 + fi * 2.3) * 18.0
		var segs: int = 5
		for s in range(segs):
			var frac: float = float(s) / float(segs - 1)
			var cx: float = base_x - 36.0 + frac * reach
			var cy: float = ty + sin(_time * 2.8 - frac * 3.2 + fi * 1.7) * (16.0 * frac)
			var rad: float = lerpf(42.0, 14.0, frac) * (0.88 + 0.14 * sin(_time * 2.0 + fi + float(s)))
			var glow_a: float = (0.14 + proximity * 0.16) * (1.0 - frac * 0.4)
			draw_circle(Vector2(cx + 6.0, cy), rad * 1.18, Color(0.56, 0.28, 0.92, glow_a))
			draw_circle(Vector2(cx, cy), rad, Color(0.018, 0.008, 0.044, 0.88 * (1.0 - frac * 0.35)))

	# Rising dark curling ink smoke wisps & glowing amethyst ash embers
	for e in _embers:
		var edx: float = float(e["dx"])
		var ephase: float = float(e["phase"])
		var esize: float = float(e["size"])
		var ex: float = base_x + edx + sin(_time * 2.2 + ephase) * 16.0
		var ey: float = float(e["y"]) * vp.y
		var fade: float = clampf(1.0 - maxf(0.0, edx) / (135.0 + proximity * 90.0), 0.0, 1.0)
		if bool(e["is_smoke"]):
			draw_circle(Vector2(ex, ey), esize * (1.9 + proximity * 0.7), Color(0.025, 0.012, 0.055, 0.34 * fade))
		else:
			draw_circle(Vector2(ex, ey), esize * 1.15, Color(0.68, 0.36, 1.0, (0.16 + proximity * 0.2) * fade))
			draw_circle(Vector2(ex, ey), esize * 0.42, Color(0.92, 0.76, 1.0, (0.52 + proximity * 0.38) * fade))
