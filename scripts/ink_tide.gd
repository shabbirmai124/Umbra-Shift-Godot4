extends Node2D
class_name InkTideController

## High-Performance Living Shadow Ink Tide Controller (Godot 4 GDScript)
## - Supports Easy / Normal / Hard aggression scaling
## - Typed SoA embers & cached ShaderMaterial (zero Dictionary lookups)

const EMBER_COUNT: int = 24

@onready var ink_rect: ColorRect = $InkRect

var proximity: float = 0.14
var surge_intensity: float = 0.0
var _time: float = 0.0
var _ink_mat: ShaderMaterial = null
var _last_vp: Vector2 = Vector2.ZERO

var _ey: PackedFloat32Array = PackedFloat32Array()
var _edx: PackedFloat32Array = PackedFloat32Array()
var _evy: PackedFloat32Array = PackedFloat32Array()
var _evx: PackedFloat32Array = PackedFloat32Array()
var _esz: PackedFloat32Array = PackedFloat32Array()
var _eph: PackedFloat32Array = PackedFloat32Array()
var _tendril_pts: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	if ink_rect != null:
		_ink_mat = ink_rect.material as ShaderMaterial
	_tendril_pts.resize(10)
	_ey.resize(EMBER_COUNT)
	_edx.resize(EMBER_COUNT)
	_evy.resize(EMBER_COUNT)
	_evx.resize(EMBER_COUNT)
	_esz.resize(EMBER_COUNT)
	_eph.resize(EMBER_COUNT)
	for i in range(EMBER_COUNT):
		_ey[i] = randf()
		_edx[i] = randf_range(-12.0, 56.0)
		_evy[i] = randf_range(0.05, 0.16)
		_evx[i] = randf_range(16.0, 58.0)
		_esz[i] = randf_range(2.0, 5.0)
		_eph[i] = randf_range(0.0, TAU)

func reset_tide() -> void:
	proximity = 0.14
	surge_intensity = 0.0
	_sync_shader()

func push_back(amount: float) -> void:
	proximity = maxf(0.05, proximity - amount)

func surge_forward(amount: float, aggression: float = 1.0) -> void:
	proximity = minf(1.05, proximity + amount * aggression)
	surge_intensity = 1.0

func update_tide(dt: float, player_vx: float, ref_pace: float, flow_multiplier: int, is_playing: bool, aggression: float = 1.0) -> void:
	_time += dt
	surge_intensity = maxf(0.0, surge_intensity - dt * 1.4)
	if is_playing:
		var pace_delta: float = (ref_pace - player_vx) / 900.0
		var flow_relief: float = float(flow_multiplier - 1) * 0.0045
		var rate: float = (pace_delta * 0.14 + 0.008) * aggression - flow_relief
		proximity = clampf(proximity + rate * dt, 0.05, 1.05)
	else:
		proximity = 0.12

	var max_dx: float = 115.0 + proximity * 85.0
	for i in range(EMBER_COUNT):
		var ey_norm: float = _ey[i] - _evy[i] * dt
		var edx: float = _edx[i] + _evx[i] * dt
		if ey_norm < -0.05 or edx > max_dx:
			ey_norm = randf_range(0.10, 1.02)
			edx = randf_range(-14.0, 16.0)
		_ey[i] = ey_norm
		_edx[i] = edx

	_sync_shader()
	queue_redraw()

func _sync_shader() -> void:
	if _ink_mat == null and ink_rect != null:
		_ink_mat = ink_rect.material as ShaderMaterial
	if _ink_mat != null:
		_ink_mat.set_shader_parameter("proximity", proximity)
		_ink_mat.set_shader_parameter("surge_intensity", surge_intensity)
		var vp: Vector2 = get_viewport_rect().size
		if vp.x > 1.0 and vp.y > 1.0 and vp != _last_vp:
			_last_vp = vp
			ink_rect.position = Vector2.ZERO
			ink_rect.size = vp

func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return
	var base_x: float = -18.0 + proximity * (vp.x * 0.34)

	if proximity > 0.38:
		var tendril_t: float = clampf((proximity - 0.38) / 0.62, 0.0, 1.0)
		var outer_col: Color = Color(0.56, 0.28, 0.94, 0.20 * tendril_t)
		var inner_col: Color = Color(0.024, 0.010, 0.056, 0.65 * tendril_t)
		for k in range(3):
			var fk: float = float(k)
			var y0: float = vp.y * (0.28 + fk * 0.22) + sin(_time * 1.7 + fk * 2.1) * 18.0
			var t_len: float = 52.0 + tendril_t * 105.0
			for st in range(10):
				var f: float = float(st) / 9.0
				_tendril_pts[st] = Vector2(
					base_x - 10.0 + f * t_len,
					y0 + sin(_time * 3.0 - f * 3.8 + fk * 1.8) * (18.0 * f)
				)
			draw_polyline(_tendril_pts, outer_col, 9.0, true)
			draw_polyline(_tendril_pts, inner_col, 4.8, true)

	var inv_max_dx: float = 1.0 / (115.0 + proximity * 85.0)
	for i in range(EMBER_COUNT):
		var edx: float = _edx[i]
		var esize: float = _esz[i]
		var ex: float = base_x + edx + sin(_time * 2.1 + _eph[i]) * 14.0
		var ey: float = _ey[i] * vp.y
		var fade: float = clampf(1.0 - maxf(0.0, edx) * inv_max_dx, 0.0, 1.0)
		draw_circle(Vector2(ex, ey), esize * 1.4, Color(0.64, 0.36, 1.0, (0.14 + proximity * 0.18) * fade))
		draw_circle(Vector2(ex, ey), esize * 0.45, Color(0.94, 0.84, 1.0, (0.56 + proximity * 0.36) * fade))
