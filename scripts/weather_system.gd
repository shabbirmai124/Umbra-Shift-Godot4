extends Node2D
class_name WeatherSystem

## Layer 6 & 7: Batched 3-Depth Parallax Rain, Rain Surface Splashes, Foreground Botanical Silhouettes
## Optimized for Godot 4:
## - Typed Structure-of-Arrays (SoA) rain & splash state (zero Dictionary lookups)
## - Draws all rain streaks in 4 batched draw_multiline() calls instead of 130 draw_line() calls

const RAIN_COUNT: int = 120
const MAX_SPLASHES: int = 20

const COL_FG_DARK: Color = Color(0.032, 0.068, 0.088, 0.88)
const COL_FG_RIM: Color = Color(0.18, 0.44, 0.44, 0.34)
const COL_RAIN_FAR: Color = Color(0.78, 0.90, 0.98, 0.14)
const COL_RAIN_MID: Color = Color(0.78, 0.90, 0.98, 0.24)
const COL_RAIN_NEAR: Color = Color(0.78, 0.90, 0.98, 0.36)

var camera_x: float = 0.0
var speed_px: float = 480.0
var active_color: Color = Color(0.31, 1.0, 0.69, 1.0)
var _time: float = 0.0

var _rx: PackedFloat32Array = PackedFloat32Array()
var _ry: PackedFloat32Array = PackedFloat32Array()
var _rspd: PackedFloat32Array = PackedFloat32Array()
var _rlen: PackedFloat32Array = PackedFloat32Array()
var _rdepth: PackedInt32Array = PackedInt32Array()

var _sp_count: int = 0
var _sp_x: PackedFloat32Array = PackedFloat32Array()
var _sp_y: PackedFloat32Array = PackedFloat32Array()
var _sp_t: PackedFloat32Array = PackedFloat32Array()

# Reusable batched line buffers (zero per-frame heap churn)
var _lines_far: PackedVector2Array = PackedVector2Array()
var _lines_mid: PackedVector2Array = PackedVector2Array()
var _lines_near: PackedVector2Array = PackedVector2Array()
var _lines_aura: PackedVector2Array = PackedVector2Array()
var _frond_poly: PackedVector2Array = PackedVector2Array()
var _frond_rim: PackedVector2Array = PackedVector2Array()
var _fern_poly: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	_rx.resize(RAIN_COUNT)
	_ry.resize(RAIN_COUNT)
	_rspd.resize(RAIN_COUNT)
	_rlen.resize(RAIN_COUNT)
	_rdepth.resize(RAIN_COUNT)
	for i in range(RAIN_COUNT):
		var depth: int = i % 3
		_rx[i] = randf_range(0.0, 1400.0)
		_ry[i] = randf_range(0.0, 760.0)
		_rdepth[i] = depth
		if depth == 0:
			_rspd[i] = 540.0
			_rlen[i] = 16.0
		elif depth == 1:
			_rspd[i] = 820.0
			_rlen[i] = 25.0
		else:
			_rspd[i] = 1140.0
			_rlen[i] = 38.0

	_sp_x.resize(MAX_SPLASHES)
	_sp_y.resize(MAX_SPLASHES)
	_sp_t.resize(MAX_SPLASHES)
	_frond_poly.resize(6)
	_frond_rim.resize(4)
	_fern_poly.resize(5)

func sync_weather(dt: float, p_cam_x: float, p_speed: float, p_col: Color) -> void:
	_time += dt
	camera_x = p_cam_x
	speed_px = p_speed
	active_color = p_col
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return

	var wind_x: float = -(200.0 + speed_px * 0.44)
	var vp_y_limit: float = vp.y + 36.0
	var splash_y_min: float = vp.y * 0.72
	for i in range(RAIN_COUNT):
		var rdepth: int = _rdepth[i]
		var df: float = 0.65 if rdepth == 0 else (1.0 if rdepth == 1 else 1.4)
		var rx: float = _rx[i] + wind_x * df * dt
		var ry: float = _ry[i] + _rspd[i] * dt
		if ry > vp_y_limit or rx < -80.0:
			if rdepth == 2 and ry > splash_y_min and _sp_count < MAX_SPLASHES:
				var si: int = _sp_count
				_sp_count += 1
				_sp_x[si] = clampf(rx, 40.0, vp.x - 40.0)
				_sp_y[si] = randf_range(vp.y * 0.70, vp.y * 0.86)
				_sp_t[si] = 0.0
			rx = randf_range(0.0, vp.x + 340.0)
			ry = randf_range(-140.0, -18.0)
		_rx[i] = rx
		_ry[i] = ry

	var si: int = _sp_count - 1
	while si >= 0:
		var st: float = _sp_t[si] + dt
		if st >= 0.28:
			var last: int = _sp_count - 1
			if si != last:
				_sp_x[si] = _sp_x[last]
				_sp_y[si] = _sp_y[last]
				_sp_t[si] = _sp_t[last]
			_sp_count = last
		else:
			_sp_t[si] = st
		si -= 1

	queue_redraw()

func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return
	_draw_foreground_silhouettes(vp)
	_draw_rain_batched(vp)
	_draw_surface_splashes()

func _draw_foliage_frond(origin: Vector2, dir: float, length: float, droop: float) -> void:
	var p1: Vector2 = origin + Vector2(dir * length * 0.35, -droop * 0.42)
	var p2: Vector2 = origin + Vector2(dir * length * 0.72, -droop * 0.14)
	var p3: Vector2 = origin + Vector2(dir * length, droop * 0.65)
	_frond_poly[0] = origin
	_frond_poly[1] = p1
	_frond_poly[2] = p2
	_frond_poly[3] = p3
	_frond_poly[4] = origin + Vector2(dir * length * 0.64, droop * 0.54)
	_frond_poly[5] = origin + Vector2(dir * length * 0.28, droop * 0.32)
	draw_colored_polygon(_frond_poly, COL_FG_DARK)
	_frond_rim[0] = origin
	_frond_rim[1] = p1
	_frond_rim[2] = p2
	_frond_rim[3] = p3
	draw_polyline(_frond_rim, COL_FG_RIM, 1.4, true)

func _draw_foreground_silhouettes(vp: Vector2) -> void:
	var spacing: float = 780.0
	var parallax: float = camera_x * 1.35
	var scroll_off: float = fposmod(parallax, spacing)
	var first_idx: int = int(floor(parallax / spacing))
	var count: int = int(ceil(vp.x / spacing)) + 2
	for i in range(-1, count):
		var idx: int = first_idx + i
		var fx: float = float(i) * spacing - scroll_off
		var sway: float = sin(_time * 2.0 + float(idx) * 1.3) * 8.0
		for f_i in range(3):
			var spread: float = (float(f_i) - 1.0) * 46.0
			var fh: float = 52.0 if f_i != 1 else 74.0
			var root_p: Vector2 = Vector2(fx + spread * 0.35, vp.y + 12.0)
			var mid_p: Vector2 = Vector2(fx + spread * 0.95 + sway * 0.5, vp.y - fh * 0.62)
			var tip_p: Vector2 = Vector2(fx + spread * 1.55 + sway, vp.y - fh)
			_fern_poly[0] = root_p + Vector2(-8.0, 0.0)
			_fern_poly[1] = mid_p + Vector2(-6.0, -3.0)
			_fern_poly[2] = tip_p
			_fern_poly[3] = mid_p + Vector2(6.0, 4.0)
			_fern_poly[4] = root_p + Vector2(8.0, 0.0)
			draw_colored_polygon(_fern_poly, COL_FG_DARK)
		if idx % 2 == 0:
			var bx: float = fx + 280.0
			_draw_foliage_frond(Vector2(bx + sway * 0.3, -8.0), 1.0, 96.0, 32.0)
			_draw_foliage_frond(Vector2(bx + sway * 0.2, -4.0), -1.0, 82.0, 28.0)

func _draw_rain_batched(vp: Vector2) -> void:
	var slant: float = -0.22 - minf(0.28, speed_px / 2600.0)
	var player_screen_x: float = vp.x * 0.34
	_lines_far.clear()
	_lines_mid.clear()
	_lines_near.clear()
	_lines_aura.clear()

	for i in range(RAIN_COUNT):
		var rx: float = _rx[i]
		var ry: float = _ry[i]
		var rlen: float = _rlen[i]
		var rdepth: int = _rdepth[i]
		var p0: Vector2 = Vector2(rx, ry)
		var p1: Vector2 = Vector2(rx + rlen * slant, ry + rlen)
		if rdepth == 0:
			_lines_far.append(p0)
			_lines_far.append(p1)
		elif rdepth == 1:
			_lines_mid.append(p0)
			_lines_mid.append(p1)
		elif absf(rx - player_screen_x) < 220.0:
			_lines_aura.append(p0)
			_lines_aura.append(p1)
		else:
			_lines_near.append(p0)
			_lines_near.append(p1)

	if not _lines_far.is_empty():
		draw_multiline(_lines_far, COL_RAIN_FAR, 1.1)
	if not _lines_mid.is_empty():
		draw_multiline(_lines_mid, COL_RAIN_MID, 1.1)
	if not _lines_near.is_empty():
		draw_multiline(_lines_near, COL_RAIN_NEAR, 1.6)
	if not _lines_aura.is_empty():
		draw_multiline(_lines_aura, Color(active_color.r, active_color.g, active_color.b, 0.28), 1.6)

func _draw_surface_splashes() -> void:
	for i in range(_sp_count):
		var prog: float = _sp_t[i] / 0.28
		var rad: float = 3.0 + prog * 14.0
		draw_arc(Vector2(_sp_x[i], _sp_y[i]), rad, PI, TAU, 8, Color(0.76, 0.92, 1.0, (1.0 - prog) * 0.38), 1.2, true)
