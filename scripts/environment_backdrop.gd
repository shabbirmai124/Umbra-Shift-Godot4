extends Node2D
class_name EnvironmentBackdrop

## Painterly 6-Layer Atmospheric Twilight Forest & Weather Backdrop
## Layers 1-4 (Back): Volumetric moonlight god-rays, smooth 48-point rolling mountain ranges,
## feathered layered conifer groves, shader-swayed slender pine silhouettes, painterly ancient trees
## with curved drooping foliage fronds (zero circular blobs) & glowing bokeh fireflies, plus 16-band valley mist.
## Layer 6 (Front): Arching botanical foreground ferns, drooping canopy fronds, and 3-depth diagonal rain.

const TREE_SWAY_SHADER: Shader = preload("res://shaders/tree_sway.gdshader")

@export var is_foreground: bool = false

var camera_x: float = 0.0
var speed_px: float = 480.0
var flow_glow: float = 1.0
var lightning_flash: float = 0.0
var active_color: Color = Color(0.31, 1.0, 0.69, 1.0)
var _time: float = 0.0
var _rain: Array[Dictionary] = []
var _petals: Array[Dictionary] = []
var _birds: Array[Dictionary] = []
var _sway_trees: Array[Polygon2D] = []
var _sway_mat: ShaderMaterial

func _ready() -> void:
	if is_foreground:
		for i in range(118):
			var depth: int = i % 3
			var r_spd: float = 520.0
			var r_len: float = 14.0
			var r_alp: float = 0.13
			if depth == 1:
				r_spd = 780.0
				r_len = 22.0
				r_alp = 0.22
			elif depth == 2:
				r_spd = 1080.0
				r_len = 34.0
				r_alp = 0.34
			_rain.append({
				"x": randf_range(0.0, 1600.0),
				"y": randf_range(0.0, 900.0),
				"speed": r_spd,
				"len": r_len,
				"depth": depth,
				"alpha": r_alp
			})
	else:
		_sway_mat = ShaderMaterial.new()
		_sway_mat.shader = TREE_SWAY_SHADER
		_sway_mat.set_shader_parameter("wind_strength", 5.5)
		_sway_mat.set_shader_parameter("wind_speed", 1.15)
		_sway_mat.set_shader_parameter("sway_height", 360.0)
		# Slender, graceful wind-swayed conifer silhouettes that blend softly into distant mist
		var pine_poly: PackedVector2Array = PackedVector2Array([
			Vector2(-7.0, 12.0),
			Vector2(-9.0, -56.0),
			Vector2(-32.0, -68.0),
			Vector2(-14.0, -104.0),
			Vector2(-36.0, -118.0),
			Vector2(-14.0, -158.0),
			Vector2(-30.0, -172.0),
			Vector2(-12.0, -214.0),
			Vector2(-24.0, -228.0),
			Vector2(-9.0, -270.0),
			Vector2(-15.0, -284.0),
			Vector2(0.0, -338.0),
			Vector2(15.0, -284.0),
			Vector2(9.0, -270.0),
			Vector2(24.0, -228.0),
			Vector2(12.0, -214.0),
			Vector2(30.0, -172.0),
			Vector2(14.0, -158.0),
			Vector2(36.0, -118.0),
			Vector2(14.0, -104.0),
			Vector2(32.0, -68.0),
			Vector2(9.0, -56.0),
			Vector2(7.0, 12.0)
		])
		for i in range(6):
			var canopy: Polygon2D = Polygon2D.new()
			canopy.material = _sway_mat
			canopy.color = Color(0.024, 0.062, 0.118, 0.36 + float(i % 2) * 0.1)
			canopy.polygon = pine_poly
			add_child(canopy)
			_sway_trees.append(canopy)
		# Drifting luminous twilight petals & spirit leaves across the sky/forest
		var p_cols: Array[Color] = [
			Color(0.45, 1.0, 0.82, 0.72),
			Color(0.38, 0.90, 1.0, 0.68),
			Color(0.95, 0.80, 0.98, 0.62),
			Color(1.0, 0.84, 0.48, 0.65)
		]
		for p_i in range(28):
			_petals.append({
				"x": randf_range(0.0, 1400.0),
				"y": randf_range(60.0, 640.0),
				"vx": randf_range(-58.0, -24.0),
				"vy": randf_range(-10.0, 18.0),
				"size": randf_range(2.6, 5.4),
				"rot": randf_range(0.0, TAU),
				"spin": randf_range(-2.4, 2.4),
				"phase": randf_range(0.0, TAU),
				"color": p_cols[p_i % p_cols.size()]
			})
		# Distant soaring twilight spirit birds gliding across the moonlit clouds
		for b_i in range(5):
			_birds.append({
				"x": randf_range(120.0, 1320.0),
				"y": randf_range(85.0, 250.0),
				"vx": randf_range(22.0, 42.0),
				"scale": randf_range(0.7, 1.25),
				"phase": randf_range(0.0, TAU)
			})

func sync_backdrop(dt: float, p_cam_x: float, p_speed: float, p_flow: int, p_lightning: float, p_col: Color) -> void:
	_time += dt
	camera_x = p_cam_x
	speed_px = p_speed
	flow_glow = 1.0 + float(p_flow - 1) * 0.08
	lightning_flash = p_lightning
	active_color = p_col

	if is_foreground:
		var vp: Vector2 = get_viewport_rect().size
		var wind_x: float = -(180.0 + speed_px * 0.42)
		for r in _rain:
			var rdepth: int = int(r["depth"])
			var df: float = 0.65
			if rdepth == 1:
				df = 1.0
			elif rdepth == 2:
				df = 1.4
			var rx: float = float(r["x"]) + wind_x * df * dt
			var ry: float = float(r["y"]) + float(r["speed"]) * dt
			if ry > vp.y + 30.0 or rx < -60.0:
				rx = randf_range(0.0, vp.x + 260.0)
				ry = randf_range(-120.0, -15.0)
			r["x"] = rx
			r["y"] = ry
	elif _sway_mat != null:
		var vp: Vector2 = get_viewport_rect().size
		if vp.x > 1.0 and vp.y > 1.0:
			_sway_mat.set_shader_parameter("wind_strength", clampf(5.0 + speed_px * 0.01, 5.0, 14.0))
			var spacing: float = 280.0
			var parallax: float = camera_x * 0.22
			var scroll_off: float = fposmod(parallax, spacing)
			var base_y: float = vp.y * 0.88
			for i in range(_sway_trees.size()):
				var t_node: Polygon2D = _sway_trees[i]
				var jitter: float = sin(float(i) * 2.4) * 34.0
				t_node.position = Vector2(float(i) * spacing - scroll_off - 30.0 + jitter, base_y)
				var s: float = 0.72 + float(i % 3) * 0.16
				t_node.scale = Vector2(s * 0.92, s)
			for p in _petals:
				var px: float = float(p["x"]) + (float(p["vx"]) - speed_px * 0.06) * dt
				var pphase: float = float(p["phase"])
				var py: float = float(p["y"]) + (float(p["vy"]) + sin(_time * 1.9 + pphase) * 18.0) * dt
				var prot: float = float(p["rot"]) + float(p["spin"]) * dt
				if px < -40.0 or py > vp.y + 30.0 or py < -30.0:
					px = vp.x + randf_range(10.0, 160.0)
					py = randf_range(40.0, vp.y * 0.86)
				p["x"] = px
				p["y"] = py
				p["rot"] = prot
			for bd in _birds:
				var bx: float = float(bd["x"]) + float(bd["vx"]) * dt
				if bx > vp.x + 80.0:
					bx = -80.0
					bd["y"] = randf_range(75.0, vp.y * 0.36)
				bd["x"] = bx
	queue_redraw()

func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return
	if is_foreground:
		_draw_foreground_silhouettes(vp)
		_draw_rain(vp)
	else:
		_draw_moonlight_shafts(vp)
		_draw_soaring_birds(vp)
		_draw_mountains(vp)
		_draw_far_canopy(vp)
		_draw_midground_hills(vp)
		_draw_midground_woods(vp)
		_draw_drifting_petals()
		_draw_volumetric_valley_mist(vp)

func _draw_moonlight_shafts(vp: Vector2) -> void:
	# Soft diagonal volumetric moonlight shafts streaming down-left across the twilight woods
	var moon_pos: Vector2 = Vector2(vp.x * 0.76, vp.y * 0.19)
	for i in range(4):
		var fi: float = float(i)
		var pulse: float = 0.78 + 0.22 * sin(_time * 0.55 + fi * 1.4)
		var spread_x: float = (fi - 1.5) * 165.0 + sin(_time * 0.22 + fi) * 26.0
		var top_w: float = 26.0 + fi * 8.0
		var bot_w: float = 115.0 + fi * 22.0
		var dir_x: float = -340.0 + spread_x
		var ray_alpha: float = (0.032 + lightning_flash * 0.025) * pulse
		var ray_col: Color = Color(0.56, 0.78, 0.96, ray_alpha)
		var p0: Vector2 = moon_pos + Vector2(spread_x * 0.18 - top_w * 0.5, 22.0)
		var p1: Vector2 = moon_pos + Vector2(spread_x * 0.18 + top_w * 0.5, 22.0)
		var p2: Vector2 = Vector2(moon_pos.x + dir_x + bot_w * 0.5, vp.y + 10.0)
		var p3: Vector2 = Vector2(moon_pos.x + dir_x - bot_w * 0.5, vp.y + 10.0)
		draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), ray_col)

func _draw_soaring_birds(_vp: Vector2) -> void:
	var bird_col: Color = Color(0.14, 0.24, 0.38, 0.55)
	for bd in _birds:
		var bx: float = float(bd["x"])
		var by: float = float(bd["y"]) + sin(_time * 1.4 + float(bd["phase"])) * 7.0
		var bs: float = float(bd["scale"])
		var flap: float = sin(_time * 5.2 + float(bd["phase"])) * 4.5 * bs
		var p_l: Vector2 = Vector2(bx - 10.0 * bs, by - 2.0 * bs + flap)
		var p_lm: Vector2 = Vector2(bx - 4.5 * bs, by - 3.5 * bs + flap * 0.4)
		var p_c: Vector2 = Vector2(bx, by)
		var p_rm: Vector2 = Vector2(bx + 4.5 * bs, by - 3.5 * bs + flap * 0.4)
		var p_r: Vector2 = Vector2(bx + 10.0 * bs, by - 2.0 * bs + flap)
		draw_polyline(PackedVector2Array([p_l, p_lm, p_c, p_rm, p_r]), bird_col, 1.5, true)

func _draw_drifting_petals() -> void:
	for p in _petals:
		var pos: Vector2 = Vector2(float(p["x"]), float(p["y"]))
		var sz: float = float(p["size"])
		var rot: float = float(p["rot"])
		var col: Color = p["color"]
		var glow: Color = Color(col.r, col.g, col.b, 0.14 * clampf(flow_glow, 0.8, 1.4))
		draw_circle(pos, sz * 2.1, glow)
		var dir: Vector2 = Vector2(cos(rot), sin(rot))
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		var poly: PackedVector2Array = PackedVector2Array([
			pos - dir * sz,
			pos + perp * (sz * 0.52),
			pos + dir * sz,
			pos - perp * (sz * 0.38)
		])
		draw_colored_polygon(poly, col)

func _draw_mountains(vp: Vector2) -> void:
	# Smooth 48-point atmospheric rolling alpine ridges with subtle moonlit upper mist edge
	var c1: Color = Color(0.11, 0.17, 0.29, 0.92) if lightning_flash > 0.1 else Color(0.062, 0.105, 0.198, 0.92)
	var rim1: Color = Color(0.32, 0.48, 0.70, 0.22 + lightning_flash * 0.22)
	var c2: Color = Color(0.085, 0.142, 0.242, 0.96) if lightning_flash > 0.1 else Color(0.042, 0.082, 0.158, 0.96)
	var rim2: Color = Color(0.22, 0.40, 0.58, 0.18 + lightning_flash * 0.18)
	_draw_smooth_ridge(vp, 0.038, vp.y * 0.58, vp.y * 0.155, c1, rim1, 1.15)
	_draw_smooth_ridge(vp, 0.082, vp.y * 0.67, vp.y * 0.115, c2, rim2, 4.35)

func _draw_smooth_ridge(vp: Vector2, speed: float, base_y: float, amp: float, col: Color, rim: Color, seed_v: float) -> void:
	var steps: int = 48
	var parallax: float = camera_x * speed
	var crest: PackedVector2Array = PackedVector2Array()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var x: float = t * (vp.x + 40.0) - 20.0
		var wx: float = (x + parallax) * 0.0028
		var h: float = (
			sin(wx * 1.1 + seed_v) * 0.46
			+ sin(wx * 2.35 + seed_v * 1.7) * 0.28
			+ cos(wx * 4.2 + seed_v * 2.3) * 0.14
			+ sin(wx * 7.6 + seed_v * 0.6) * 0.06
		)
		var y: float = base_y - (h * 0.5 + 0.5) * amp
		crest.append(Vector2(x, y))
	var poly: PackedVector2Array = crest.duplicate()
	poly.append(Vector2(vp.x + 24.0, vp.y + 12.0))
	poly.append(Vector2(-24.0, vp.y + 12.0))
	draw_colored_polygon(poly, col)
	draw_polyline(crest, rim, 2.0, true)

func _draw_far_canopy(vp: Vector2) -> void:
	# Feathered atmospheric twilight conifer treeline fading softly into indigo-teal valley haze
	var spacing: float = 82.0
	var parallax: float = camera_x * 0.16
	var scroll_off: float = fposmod(parallax, spacing)
	var first_idx: int = int(floor(parallax / spacing))
	var ground_base: float = vp.y * 0.85
	var col_back: Color = Color(0.028, 0.066, 0.128, 0.92)
	var col_hi: Color = Color(0.062, 0.138, 0.215, 0.34)
	var count: int = int(ceil(vp.x / spacing)) + 3
	for i in range(-2, count):
		var idx: int = first_idx + i
		var h: float = fposmod(absf(sin(float(idx) * 12.9898) * 43758.5453), 1.0)
		var h2: float = fposmod(absf(cos(float(idx) * 39.346) * 23421.63), 1.0)
		var tx: float = float(i) * spacing - scroll_off + (h - 0.5) * 38.0
		var tree_h: float = 118.0 + h * 155.0
		var lean: float = (h2 - 0.5) * 14.0
		var sway: float = sin(_time * 0.82 + float(idx) * 0.7) * 3.8
		var top_y: float = ground_base - tree_h
		var w_scale: float = 0.66 + h2 * 0.42
		var poly: PackedVector2Array = PackedVector2Array([
			Vector2(tx + lean + sway, top_y),
			Vector2(tx + lean * 0.82 + 12.0 * w_scale + sway * 0.82, top_y + tree_h * 0.18),
			Vector2(tx + lean * 0.76 + 6.0 * w_scale + sway * 0.76, top_y + tree_h * 0.20),
			Vector2(tx + lean * 0.62 + 21.0 * w_scale + sway * 0.62, top_y + tree_h * 0.40),
			Vector2(tx + lean * 0.54 + 11.0 * w_scale + sway * 0.54, top_y + tree_h * 0.42),
			Vector2(tx + lean * 0.40 + 29.0 * w_scale + sway * 0.40, top_y + tree_h * 0.62),
			Vector2(tx + lean * 0.32 + 16.0 * w_scale + sway * 0.32, top_y + tree_h * 0.65),
			Vector2(tx + lean * 0.18 + 36.0 * w_scale + sway * 0.18, top_y + tree_h * 0.84),
			Vector2(tx + 40.0 * w_scale, ground_base + 30.0),
			Vector2(tx - 40.0 * w_scale, ground_base + 30.0),
			Vector2(tx + lean * 0.18 - 34.0 * w_scale + sway * 0.18, top_y + tree_h * 0.84),
			Vector2(tx + lean * 0.32 - 15.0 * w_scale + sway * 0.32, top_y + tree_h * 0.65),
			Vector2(tx + lean * 0.40 - 28.0 * w_scale + sway * 0.40, top_y + tree_h * 0.62),
			Vector2(tx + lean * 0.54 - 10.0 * w_scale + sway * 0.54, top_y + tree_h * 0.42),
			Vector2(tx + lean * 0.62 - 20.0 * w_scale + sway * 0.62, top_y + tree_h * 0.40),
			Vector2(tx + lean * 0.76 - 6.0 * w_scale + sway * 0.76, top_y + tree_h * 0.20),
			Vector2(tx + lean * 0.82 - 12.0 * w_scale + sway * 0.82, top_y + tree_h * 0.18)
		])
		draw_colored_polygon(poly, col_back)
		# Delicate moonlight rim along right (moon-facing) conifer boughs
		draw_polyline(PackedVector2Array([
			Vector2(tx + lean + sway, top_y),
			Vector2(tx + lean * 0.62 + 21.0 * w_scale + sway * 0.62, top_y + tree_h * 0.40),
			Vector2(tx + lean * 0.40 + 29.0 * w_scale + sway * 0.40, top_y + tree_h * 0.62)
		]), col_hi, 1.3, true)

func _draw_midground_hills(vp: Vector2) -> void:
	# Soft rolling misty forest hill silhouette grounding the mid-ground trunks
	var steps: int = 36
	var parallax: float = camera_x * 0.30
	var hill_top: PackedVector2Array = PackedVector2Array()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var x: float = t * (vp.x + 30.0) - 15.0
		var wx: float = (x + parallax) * 0.0036
		var y: float = vp.y * 0.79 + sin(wx * 1.3) * 26.0 + cos(wx * 2.7 + 1.2) * 12.0
		hill_top.append(Vector2(x, y))
	var poly: PackedVector2Array = hill_top.duplicate()
	poly.append(Vector2(vp.x + 20.0, vp.y + 12.0))
	poly.append(Vector2(-20.0, vp.y + 12.0))
	draw_colored_polygon(poly, Color(0.022, 0.056, 0.106, 0.92))
	draw_polyline(hill_top, Color(0.14, 0.34, 0.42, 0.26), 2.0, true)

func _draw_foliage_frond(origin: Vector2, dir: float, length: float, droop: float, col: Color, rim: Color) -> void:
	# Painterly drooping curved botanical leaf frond (zero geometric circles!)
	var p0: Vector2 = origin
	var p1: Vector2 = origin + Vector2(dir * length * 0.35, -droop * 0.42)
	var p2: Vector2 = origin + Vector2(dir * length * 0.72, -droop * 0.14)
	var p3: Vector2 = origin + Vector2(dir * length, droop * 0.65)
	var b2: Vector2 = origin + Vector2(dir * length * 0.64, droop * 0.54)
	var b1: Vector2 = origin + Vector2(dir * length * 0.28, droop * 0.32)
	var poly: PackedVector2Array = PackedVector2Array([p0, p1, p2, p3, b2, b1])
	draw_colored_polygon(poly, col)
	draw_polyline(PackedVector2Array([p0, p1, p2, p3]), rim, 1.2, true)

func _draw_midground_woods(vp: Vector2) -> void:
	var spacing: float = 315.0
	var parallax: float = camera_x * 0.42
	var scroll_off: float = fposmod(parallax, spacing)
	var first_idx: int = int(floor(parallax / spacing))
	var base_y: float = vp.y * 0.94
	var count: int = int(ceil(vp.x / spacing)) + 2
	var firefly_cols: Array[Color] = [
		Color(0.38, 1.0, 0.74, 1.0),
		Color(0.28, 0.92, 1.0, 1.0),
		Color(1.0, 0.82, 0.36, 1.0)
	]
	var trunk_col: Color = Color(0.020, 0.044, 0.082, 1.0)
	var bark_mid: Color = Color(0.036, 0.075, 0.125, 0.85)
	var rim_col: Color = Color(0.28, 0.56, 0.72, 0.34)
	var leaf_dark: Color = Color(0.018, 0.054, 0.095, 0.94)
	var leaf_mid: Color = Color(0.032, 0.094, 0.138, 0.88)
	var leaf_rim: Color = Color(0.18, 0.44, 0.52, 0.32)

	for i in range(-1, count):
		var idx: int = first_idx + i
		var h: float = fposmod(absf(sin(float(idx) * 78.233) * 19234.12), 1.0)
		var h2: float = fposmod(absf(cos(float(idx) * 23.17) * 8192.4), 1.0)
		var tx: float = float(i) * spacing - scroll_off + (h - 0.5) * 76.0
		var tw: float = 16.0 + h * 15.0
		var bend_dir: float = 1.0 if idx % 2 == 0 else -1.0
		var curve_amp: float = (14.0 + h2 * 16.0) * bend_dir
		var sway: float = sin(_time * 1.15 + float(idx) * 1.1) * 6.5

		# Gently curved organic ancient tree trunk with flared mossy buttress roots
		var left_pts: PackedVector2Array = PackedVector2Array()
		var right_pts: PackedVector2Array = PackedVector2Array()
		var rim_pts: PackedVector2Array = PackedVector2Array()
		var segs: int = 10
		for s in range(segs + 1):
			var t: float = float(s) / float(segs)
			var y: float = lerpf(base_y + 28.0, -28.0, t)
			var curve_x: float = sin(t * PI * 0.88) * curve_amp + t * t * sway
			var flare: float = pow(1.0 - t, 3.4) * (tw * 1.05)
			var half_w: float = lerpf(tw * 0.58, tw * 0.22, t) + flare
			var cx: float = tx + curve_x
			left_pts.append(Vector2(cx - half_w, y))
			right_pts.append(Vector2(cx + half_w, y))
			rim_pts.append(Vector2(cx + half_w - 1.5, y))

		var trunk_poly: PackedVector2Array = PackedVector2Array()
		for lp in left_pts:
			trunk_poly.append(lp)
		for k in range(right_pts.size() - 1, -1, -1):
			trunk_poly.append(right_pts[k])
		draw_colored_polygon(trunk_poly, trunk_col)
		# Soft bark grain contour + moonlight edge on right side
		var grain_pts: PackedVector2Array = PackedVector2Array()
		for s in range(1, segs):
			var lp: Vector2 = left_pts[s]
			var rp: Vector2 = right_pts[s]
			grain_pts.append(lp.lerp(rp, 0.64))
		draw_polyline(grain_pts, bark_mid, 2.0, true)
		draw_polyline(rim_pts, rim_col, 1.8, true)

		# Organic arched boughs + painterly drooping leaf fronds + swaying willow moss
		for b_i in range(2):
			var b_dir: float = bend_dir if b_i == 0 else -bend_dir
			var bt: float = (0.56 + h * 0.18) if b_i == 0 else (0.72 + h2 * 0.14)
			var by: float = lerpf(base_y + 28.0, -28.0, bt)
			var bx0: float = tx + sin(bt * PI * 0.88) * curve_amp + bt * bt * sway
			var blen: float = 84.0 + (h if b_i == 0 else h2) * 56.0
			var b_sway: float = sin(_time * 1.4 + float(idx) + float(b_i) * 1.7) * 5.0
			var p0: Vector2 = Vector2(bx0, by)
			var p1: Vector2 = Vector2(bx0 + b_dir * blen * 0.36, by - 14.0 + b_sway * 0.3)
			var p2: Vector2 = Vector2(bx0 + b_dir * blen * 0.72, by - 22.0 + b_sway * 0.7)
			var p3: Vector2 = Vector2(bx0 + b_dir * blen, by - 8.0 + b_sway)

			var bough: PackedVector2Array = PackedVector2Array([
				p0 + Vector2(0.0, -5.0),
				p1 + Vector2(0.0, -3.6),
				p2 + Vector2(0.0, -2.2),
				p3,
				p2 + Vector2(0.0, 2.4),
				p1 + Vector2(0.0, 4.2),
				p0 + Vector2(0.0, 5.5)
			])
			draw_colored_polygon(bough, trunk_col)

			# Layered drooping botanical leaf fronds along bough (painterly, zero circle blobs!)
			_draw_foliage_frond(p1 + Vector2(0.0, -4.0), b_dir, 46.0 + h * 18.0, 18.0, leaf_dark, leaf_rim)
			_draw_foliage_frond(p2 + Vector2(0.0, -5.0), b_dir, 54.0 + h2 * 16.0, 20.0, leaf_mid, leaf_rim)
			_draw_foliage_frond(p2 + Vector2(0.0, -2.0), -b_dir, 36.0 + h * 12.0, 16.0, leaf_dark, leaf_rim)
			_draw_foliage_frond(p3 + Vector2(-b_dir * 6.0, -3.0), b_dir, 40.0 + h2 * 14.0, 22.0, leaf_mid, leaf_rim)

			# Delicate bioluminescent-tinted hanging willow moss curtains
			if b_i == 0:
				for m in range(4):
					var mt: float = 0.24 + float(m) * 0.22
					var mp: Vector2 = p0.lerp(p2, mt) if mt < 0.7 else p2.lerp(p3, (mt - 0.7) / 0.3)
					var m_len: float = 30.0 + float((idx + m) % 3) * 16.0
					var m_sway: float = sin(_time * 1.9 + float(idx + m)) * 6.5
					var m_mid: Vector2 = Vector2(mp.x + m_sway * 0.45, mp.y + m_len * 0.55)
					var m_tip: Vector2 = Vector2(mp.x + m_sway, mp.y + m_len)
					draw_polyline(PackedVector2Array([mp, m_mid, m_tip]), Color(0.11, 0.32, 0.36, 0.56), 1.6, true)

		# Soft glowing bokeh twilight fireflies (2 per tree depth)
		for f_i in range(2):
			var fi: float = float(f_i)
			var sx: float = tx + (fi - 0.5) * 95.0 + sin(_time * (0.7 + fi * 0.25) + float(idx) + fi * 2.1) * 34.0
			var sy: float = vp.y * (0.42 + (h - 0.5) * 0.28 + fi * 0.12) + cos(_time * (1.0 + fi * 0.3) + float(idx) * 1.4) * 18.0
			var sc: Color = firefly_cols[absi(idx + f_i) % firefly_cols.size()]
			var pulse: float = 0.7 + 0.3 * sin(_time * 2.6 + float(idx) + fi * 3.1)
			draw_circle(Vector2(sx, sy), 9.0 + h * 3.0, Color(sc.r, sc.g, sc.b, clampf(0.09 * flow_glow * pulse, 0.04, 0.22)))
			draw_circle(Vector2(sx, sy), 4.6 + h * 1.6, Color(sc.r, sc.g, sc.b, clampf(0.24 * flow_glow * pulse, 0.12, 0.48)))
			draw_circle(Vector2(sx, sy), 1.9 + h * 0.8, Color(0.95, 1.0, 0.96, clampf(0.75 * pulse, 0.35, 0.95)))

func _draw_volumetric_valley_mist(vp: Vector2) -> void:
	# Ultra-smooth 16-band undulating atmospheric teal-indigo valley fog (zero hard seam)
	var bands: int = 16
	var mist_top: float = vp.y * 0.42
	var mist_bottom: float = vp.y + 14.0
	var fog_tint: Color = Color(0.10, 0.24, 0.36, 1.0)
	if lightning_flash > 0.08:
		fog_tint = fog_tint.lerp(Color(0.32, 0.46, 0.62, 1.0), lightning_flash * 0.4)

	for b in range(bands):
		var t0: float = float(b) / float(bands)
		var t1: float = float(b + 1) / float(bands)
		var y0: float = lerpf(mist_top, mist_bottom, t0)
		var y1: float = lerpf(mist_top, mist_bottom, t1)
		var density: float = pow(t0, 2.0) * (0.042 + lightning_flash * 0.012)
		var c: Color = Color(fog_tint.r, fog_tint.g, fog_tint.b, density)
		var strip: PackedVector2Array = PackedVector2Array()
		var x_steps: int = 12
		for xs in range(x_steps + 1):
			var xt: float = float(xs) / float(x_steps)
			var x: float = xt * vp.x
			var wave: float = sin(xt * TAU * 1.4 + _time * 0.32 + float(b) * 0.5 + camera_x * 0.00045) * (11.0 * (1.0 - t0 * 0.45))
			strip.append(Vector2(x, y0 + wave))
		strip.append(Vector2(vp.x, y1 + 4.0))
		strip.append(Vector2(0.0, y1 + 4.0))
		draw_colored_polygon(strip, c)

func _draw_foreground_silhouettes(vp: Vector2) -> void:
	# Graceful curving botanical foreground ferns along bottom & sweeping willow fronds at top
	var spacing: float = 560.0
	var parallax: float = camera_x * 1.32
	var scroll_off: float = fposmod(parallax, spacing)
	var first_idx: int = int(floor(parallax / spacing))
	var col: Color = Color(0.008, 0.020, 0.042, 0.92)
	var rim: Color = Color(0.08, 0.22, 0.28, 0.26)
	var count: int = int(ceil(vp.x / spacing)) + 2
	for i in range(-1, count):
		var idx: int = first_idx + i
		var fx: float = float(i) * spacing - scroll_off
		var sway: float = sin(_time * 2.0 + float(idx) * 1.3) * 6.5
		for f_i in range(3):
			var spread: float = (float(f_i) - 1.0) * 36.0
			var fh: float = 42.0 if f_i != 1 else 58.0
			var root_p: Vector2 = Vector2(fx + spread * 0.35, vp.y + 10.0)
			var mid_p: Vector2 = Vector2(fx + spread * 0.95 + sway * 0.5, vp.y - fh * 0.62)
			var tip_p: Vector2 = Vector2(fx + spread * 1.55 + sway, vp.y - fh)
			var frond: PackedVector2Array = PackedVector2Array([
				root_p + Vector2(-6.5, 0.0),
				mid_p + Vector2(-5.0, -2.5),
				tip_p,
				mid_p + Vector2(5.0, 3.5),
				root_p + Vector2(6.5, 0.0)
			])
			draw_colored_polygon(frond, col)
		if idx % 2 == 0:
			var bx: float = fx + 210.0
			_draw_foliage_frond(Vector2(bx + sway * 0.3, -6.0), 1.0, 74.0, 26.0, col, rim)
			_draw_foliage_frond(Vector2(bx + sway * 0.2, -4.0), -1.0, 62.0, 24.0, col, rim)

func _draw_rain(vp: Vector2) -> void:
	var slant: float = -0.22 - minf(0.28, speed_px / 2600.0)
	var player_screen_x: float = vp.x * 0.34
	for r in _rain:
		var rx: float = float(r["x"])
		var ry: float = float(r["y"])
		var rlen: float = float(r["len"])
		var rdepth: int = int(r["depth"])
		var ralpha: float = float(r["alpha"])
		var near_player: bool = rdepth == 2 and absf(rx - player_screen_x) < 165.0
		var col: Color = active_color if near_player else Color(0.74, 0.86, 0.96, 1.0)
		col.a = ralpha * (0.70 if near_player else 1.0)
		var p0: Vector2 = Vector2(rx, ry)
		var p1: Vector2 = p0 + Vector2(rlen * slant, rlen)
		draw_line(p0, p1, col, 1.4 if rdepth == 2 else 1.0, true)
