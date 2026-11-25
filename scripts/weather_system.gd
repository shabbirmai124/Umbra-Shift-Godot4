extends Node2D
class_name WeatherSystem

## Layer 6 & 7: 3-Depth Parallax Rain, Rain Surface Splashes, Foreground Botanical Speed Silhouettes
## Near rain streaks catch the player's bioluminescent light as they pass through the active aura.

var camera_x: float = 0.0
var speed_px: float = 480.0
var active_color: Color = Color(0.31, 1.0, 0.69, 1.0)
var _time: float = 0.0
var _rain: Array[Dictionary] = []
var _splashes: Array[Dictionary] = []

func _ready() -> void:
	for i in range(130):
		var depth: int = i % 3
		var r_spd: float = 540.0
		var r_len: float = 16.0
		var r_alp: float = 0.14
		if depth == 1:
			r_spd = 820.0
			r_len = 25.0
			r_alp = 0.24
		elif depth == 2:
			r_spd = 1140.0
			r_len = 38.0
			r_alp = 0.36
		_rain.append({
			"x": randf_range(0.0, 1920.0),
			"y": randf_range(0.0, 1080.0),
			"speed": r_spd,
			"len": r_len,
			"depth": depth,
			"alpha": r_alp
		})

func sync_weather(dt: float, p_cam_x: float, p_speed: float, p_col: Color) -> void:
	_time += dt
	camera_x = p_cam_x
	speed_px = p_speed
	active_color = p_col
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return

	var wind_x: float = -(200.0 + speed_px * 0.44)
	for r in _rain:
		var rdepth: int = int(r["depth"])
		var df: float = 0.65 if rdepth == 0 else (1.0 if rdepth == 1 else 1.4)
		var rx: float = float(r["x"]) + wind_x * df * dt
		var ry: float = float(r["y"]) + float(r["speed"]) * dt
		if ry > vp.y + 36.0 or rx < -80.0:
			if rdepth == 2 and ry > vp.y * 0.72 and _splashes.size() < 24:
				_splashes.append({
					"x": clampf(rx, 40.0, vp.x - 40.0),
					"y": randf_range(vp.y * 0.70, vp.y * 0.86),
					"t": 0.0,
					"dur": 0.28
				})
			rx = randf_range(0.0, vp.x + 340.0)
			ry = randf_range(-140.0, -18.0)
		r["x"] = rx
		r["y"] = ry

	for i in range(_splashes.size() - 1, -1, -1):
		var sp: Dictionary = _splashes[i]
		var st: float = float(sp["t"]) + dt
		sp["t"] = st
		if st >= float(sp["dur"]):
			_splashes.remove_at(i)

	queue_redraw()

func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return
	_draw_foreground_silhouettes(vp)
	_draw_rain(vp)
	_draw_surface_splashes()

func _draw_foliage_frond(origin: Vector2, dir: float, length: float, droop: float, col: Color, rim: Color) -> void:
	var p0: Vector2 = origin
	var p1: Vector2 = origin + Vector2(dir * length * 0.35, -droop * 0.42)
	var p2: Vector2 = origin + Vector2(dir * length * 0.72, -droop * 0.14)
	var p3: Vector2 = origin + Vector2(dir * length, droop * 0.65)
	var b2: Vector2 = origin + Vector2(dir * length * 0.64, droop * 0.54)
	var b1: Vector2 = origin + Vector2(dir * length * 0.28, droop * 0.32)
	draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3, b2, b1]), col)
	draw_polyline(PackedVector2Array([p0, p1, p2, p3]), rim, 1.4, true)

func _draw_foreground_silhouettes(vp: Vector2) -> void:
	# Layer 7: Rapid framing foreground botanical ferns & drooping top canopy fronds
	var spacing: float = 780.0
	var parallax: float = camera_x * 1.35
	var scroll_off: float = fposmod(parallax, spacing)
	var first_idx: int = int(floor(parallax / spacing))
	var col: Color = Color(0.032, 0.068, 0.088, 0.88)
	var rim: Color = Color(0.18, 0.44, 0.44, 0.34)
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
			draw_colored_polygon(PackedVector2Array([
				root_p + Vector2(-8.0, 0.0),
				mid_p + Vector2(-6.0, -3.0),
				tip_p,
				mid_p + Vector2(6.0, 4.0),
				root_p + Vector2(8.0, 0.0)
			]), col)
		if idx % 2 == 0:
			var bx: float = fx + 280.0
			_draw_foliage_frond(Vector2(bx + sway * 0.3, -8.0), 1.0, 96.0, 32.0, col, rim)
			_draw_foliage_frond(Vector2(bx + sway * 0.2, -4.0), -1.0, 82.0, 28.0, col, rim)

func _draw_rain(vp: Vector2) -> void:
	var slant: float = -0.22 - minf(0.28, speed_px / 2600.0)
	var player_screen_x: float = vp.x * 0.34
	for r in _rain:
		var rx: float = float(r["x"])
		var ry: float = float(r["y"])
		var rlen: float = float(r["len"])
		var rdepth: int = int(r["depth"])
		var ralpha: float = float(r["alpha"])
		var near_player: bool = rdepth == 2 and absf(rx - player_screen_x) < 220.0
		var col: Color = active_color if near_player else Color(0.78, 0.90, 0.98, 1.0)
		col.a = ralpha * (0.76 if near_player else 1.0)
		var p0: Vector2 = Vector2(rx, ry)
		var p1: Vector2 = p0 + Vector2(rlen * slant, rlen)
		draw_line(p0, p1, col, 1.6 if rdepth == 2 else 1.1, true)

func _draw_surface_splashes() -> void:
	for sp in _splashes:
		var prog: float = float(sp["t"]) / float(sp["dur"])
		var x: float = float(sp["x"])
		var y: float = float(sp["y"])
		var rad: float = 3.0 + prog * 14.0
		var col: Color = Color(0.76, 0.92, 1.0, (1.0 - prog) * 0.38)
		draw_arc(Vector2(x, y), rad, PI, TAU, 10, col, 1.2, true)
