extends Node2D
class_name EnvironmentManager

## Luminous Moonlit Forest Parallax Manager (Layers 2-4 + Volumetric Mist)
## Designed with clear, realistic natural-fantasy twilight colors (light and easy to read!):
## - Volumetric diagonal moonlight shafts (god-rays) & distant gliding twilight birds
## - Smooth 48-point rolling blue-slate alpine peaks with silver moonlit ridges
## - Layered emerald-pine timberline & wind-swaying conifers (wind_sway.gdshader)
## - Painterly ancient woodland trees with warm moonlight bark rim-lights, drooping botanical leaf fronds,
##   glowing shelf mushrooms, swaying willow moss, drifting spirit petals, and warm golden/mint bokeh fireflies
## - 16-band undulating luminous valley mist with zero hard seams

const WIND_SWAY_SHADER: Shader = preload("res://shaders/wind_sway.gdshader")

var camera_x: float = 0.0
var speed_px: float = 480.0
var flow_glow: float = 1.0
var lightning_flash: float = 0.0
var active_color: Color = Color(0.31, 1.0, 0.69, 1.0)

var _time: float = 0.0
var _petals: Array[Dictionary] = []
var _birds: Array[Dictionary] = []
var _sway_trees: Array[Polygon2D] = []
var _sway_mat: ShaderMaterial

func _ready() -> void:
	_sway_mat = ShaderMaterial.new()
	_sway_mat.shader = WIND_SWAY_SHADER
	_sway_mat.set_shader_parameter("wind_strength", 6.0)
	_sway_mat.set_shader_parameter("wind_speed", 1.2)
	_sway_mat.set_shader_parameter("sway_height", 460.0)

	var pine_poly: PackedVector2Array = PackedVector2Array([
		Vector2(-9.0, 14.0),
		Vector2(-11.0, -72.0),
		Vector2(-40.0, -86.0),
		Vector2(-18.0, -132.0),
		Vector2(-46.0, -150.0),
		Vector2(-18.0, -200.0),
		Vector2(-38.0, -220.0),
		Vector2(-15.0, -274.0),
		Vector2(-30.0, -294.0),
		Vector2(-11.0, -346.0),
		Vector2(-18.0, -366.0),
		Vector2(0.0, -432.0),
		Vector2(18.0, -366.0),
		Vector2(11.0, -346.0),
		Vector2(30.0, -294.0),
		Vector2(15.0, -274.0),
		Vector2(38.0, -220.0),
		Vector2(18.0, -200.0),
		Vector2(46.0, -150.0),
		Vector2(18.0, -132.0),
		Vector2(40.0, -86.0),
		Vector2(11.0, -72.0),
		Vector2(9.0, 14.0)
	])
	for i in range(6):
		var canopy: Polygon2D = Polygon2D.new()
		canopy.material = _sway_mat
		canopy.color = Color(0.095, 0.195, 0.255, 0.34 + float(i % 2) * 0.08)
		canopy.polygon = pine_poly
		add_child(canopy)
		_sway_trees.append(canopy)

	var p_cols: Array[Color] = [
		Color(0.52, 1.0, 0.84, 0.78),
		Color(0.42, 0.94, 1.0, 0.72),
		Color(0.98, 0.84, 0.96, 0.68),
		Color(1.0, 0.88, 0.54, 0.72)
	]
	for p_i in range(32):
		_petals.append({
			"x": randf_range(0.0, 1920.0),
			"y": randf_range(80.0, 920.0),
			"vx": randf_range(-68.0, -28.0),
			"vy": randf_range(-12.0, 20.0),
			"size": randf_range(3.2, 6.4),
			"rot": randf_range(0.0, TAU),
			"spin": randf_range(-2.4, 2.4),
			"phase": randf_range(0.0, TAU),
			"color": p_cols[p_i % p_cols.size()]
		})

	for b_i in range(6):
		_birds.append({
			"x": randf_range(160.0, 1840.0),
			"y": randf_range(110.0, 340.0),
			"vx": randf_range(26.0, 52.0),
			"scale": randf_range(0.85, 1.45),
			"phase": randf_range(0.0, TAU)
		})

func sync_environment(dt: float, p_cam_x: float, p_speed: float, p_flow: int, p_lightning: float, p_col: Color) -> void:
	_time += dt
	camera_x = p_cam_x
	speed_px = p_speed
	flow_glow = 1.0 + float(p_flow - 1) * 0.08
	lightning_flash = p_lightning
	active_color = p_col

	var vp: Vector2 = get_viewport_rect().size
	if vp.x > 1.0 and vp.y > 1.0:
		if _sway_mat != null:
			_sway_mat.set_shader_parameter("wind_strength", clampf(6.0 + speed_px * 0.012, 6.0, 16.0))
			var spacing: float = 390.0
			var parallax: float = camera_x * 0.24
			var scroll_off: float = fposmod(parallax, spacing)
			var base_y: float = vp.y * 0.87
			for i in range(_sway_trees.size()):
				var t_node: Polygon2D = _sway_trees[i]
				var jitter: float = sin(float(i) * 2.4) * 44.0
				t_node.position = Vector2(float(i) * spacing - scroll_off - 40.0 + jitter, base_y)
				var s: float = 0.78 + float(i % 3) * 0.16
				t_node.scale = Vector2(s * 0.94, s)

		for p in _petals:
			var px: float = float(p["x"]) + (float(p["vx"]) - speed_px * 0.07) * dt
			var pphase: float = float(p["phase"])
			var py: float = float(p["y"]) + (float(p["vy"]) + sin(_time * 1.9 + pphase) * 20.0) * dt
			var prot: float = float(p["rot"]) + float(p["spin"]) * dt
			if px < -50.0 or py > vp.y + 40.0 or py < -40.0:
				px = vp.x + randf_range(15.0, 220.0)
				py = randf_range(60.0, vp.y * 0.86)
			p["x"] = px
			p["y"] = py
			p["rot"] = prot

		for bd in _birds:
			var bx: float = float(bd["x"]) + float(bd["vx"]) * dt
			if bx > vp.x + 110.0:
				bx = -110.0
				bd["y"] = randf_range(95.0, vp.y * 0.36)
			bd["x"] = bx

	queue_redraw()

func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return
	_draw_moonlight_shafts(vp)
	_draw_soaring_birds()
	_draw_mountains(vp)
	_draw_far_canopy(vp)
	_draw_midground_hills(vp)
	_draw_midground_woods(vp)
	_draw_drifting_petals()
	_draw_volumetric_valley_mist(vp)

func _draw_moonlight_shafts(vp: Vector2) -> void:
	var moon_pos: Vector2 = Vector2(vp.x * 0.76, vp.y * 0.19)
	for i in range(4):
		var fi: float = float(i)
		var pulse: float = 0.80 + 0.20 * sin(_time * 0.55 + fi * 1.4)
		var spread_x: float = (fi - 1.5) * 235.0 + sin(_time * 0.22 + fi) * 34.0
		var top_w: float = 38.0 + fi * 12.0
		var bot_w: float = 170.0 + fi * 30.0
		var dir_x: float = -480.0 + spread_x
		var ray_alpha: float = (0.044 + lightning_flash * 0.030) * pulse
		var ray_col: Color = Color(0.68, 0.88, 1.0, ray_alpha)
		var p0: Vector2 = moon_pos + Vector2(spread_x * 0.18 - top_w * 0.5, 28.0)
		var p1: Vector2 = moon_pos + Vector2(spread_x * 0.18 + top_w * 0.5, 28.0)
		var p2: Vector2 = Vector2(moon_pos.x + dir_x + bot_w * 0.5, vp.y + 12.0)
		var p3: Vector2 = Vector2(moon_pos.x + dir_x - bot_w * 0.5, vp.y + 12.0)
		draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), ray_col)

func _draw_soaring_birds() -> void:
	var bird_col: Color = Color(0.24, 0.40, 0.56, 0.62)
	for bd in _birds:
		var bx: float = float(bd["x"])
		var by: float = float(bd["y"]) + sin(_time * 1.4 + float(bd["phase"])) * 9.0
		var bs: float = float(bd["scale"])
		var flap: float = sin(_time * 5.2 + float(bd["phase"])) * 5.5 * bs
		draw_polyline(PackedVector2Array([
			Vector2(bx - 12.0 * bs, by - 2.4 * bs + flap),
			Vector2(bx - 5.2 * bs, by - 4.2 * bs + flap * 0.4),
			Vector2(bx, by),
			Vector2(bx + 5.2 * bs, by - 4.2 * bs + flap * 0.4),
			Vector2(bx + 12.0 * bs, by - 2.4 * bs + flap)
		]), bird_col, 1.8, true)

func _draw_mountains(vp: Vector2) -> void:
	# Light, atmospheric moonlit indigo-slate mountain peaks with silver-blue upper snow/mist crest
	var c1: Color = Color(0.21, 0.32, 0.48, 0.94) if lightning_flash > 0.1 else Color(0.145, 0.235, 0.375, 0.94)
	var rim1: Color = Color(0.56, 0.76, 0.94, 0.38 + lightning_flash * 0.25)
	var c2: Color = Color(0.16, 0.26, 0.40, 0.97) if lightning_flash > 0.1 else Color(0.105, 0.195, 0.305, 0.97)
	var rim2: Color = Color(0.42, 0.66, 0.82, 0.32 + lightning_flash * 0.20)
	_draw_smooth_ridge(vp, 0.04, vp.y * 0.58, vp.y * 0.16, c1, rim1, 1.15)
	_draw_smooth_ridge(vp, 0.085, vp.y * 0.67, vp.y * 0.12, c2, rim2, 4.35)

func _draw_smooth_ridge(vp: Vector2, speed: float, base_y: float, amp: float, col: Color, rim: Color, seed_v: float) -> void:
	var steps: int = 48
	var parallax: float = camera_x * speed
	var crest: PackedVector2Array = PackedVector2Array()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var x: float = t * (vp.x + 50.0) - 25.0
		var wx: float = (x + parallax) * 0.0021
		var h: float = (
			sin(wx * 1.1 + seed_v) * 0.46
			+ sin(wx * 2.35 + seed_v * 1.7) * 0.28
			+ cos(wx * 4.2 + seed_v * 2.3) * 0.14
			+ sin(wx * 7.6 + seed_v * 0.6) * 0.06
		)
		var y: float = base_y - (h * 0.5 + 0.5) * amp
		crest.append(Vector2(x, y))
	var poly: PackedVector2Array = crest.duplicate()
	poly.append(Vector2(vp.x + 30.0, vp.y + 16.0))
	poly.append(Vector2(-30.0, vp.y + 16.0))
	draw_colored_polygon(poly, col)
	draw_polyline(crest, rim, 2.4, true)

func _draw_far_canopy(vp: Vector2) -> void:
	# Feathered evergreen pine-and-cypress skyline in rich moonlit teal-forest tones
	var spacing: float = 112.0
	var parallax: float = camera_x * 0.18
	var scroll_off: float = fposmod(parallax, spacing)
	var first_idx: int = int(floor(parallax / spacing))
	var ground_base: float = vp.y * 0.85
	var col_back: Color = Color(0.075, 0.165, 0.235, 0.94)
	var col_hi: Color = Color(0.22, 0.44, 0.52, 0.45)
	var count: int = int(ceil(vp.x / spacing)) + 3
	for i in range(-2, count):
		var idx: int = first_idx + i
		var h: float = fposmod(absf(sin(float(idx) * 12.9898) * 43758.5453), 1.0)
		var h2: float = fposmod(absf(cos(float(idx) * 39.346) * 23421.63), 1.0)
		var tx: float = float(i) * spacing - scroll_off + (h - 0.5) * 50.0
		var tree_h: float = 175.0 + h * 225.0
		var lean: float = (h2 - 0.5) * 18.0
		var sway: float = sin(_time * 0.82 + float(idx) * 0.7) * 5.0
		var top_y: float = ground_base - tree_h
		var w_scale: float = 0.72 + h2 * 0.44
		var poly: PackedVector2Array = PackedVector2Array([
			Vector2(tx + lean + sway, top_y),
			Vector2(tx + lean * 0.82 + 16.0 * w_scale + sway * 0.82, top_y + tree_h * 0.18),
			Vector2(tx + lean * 0.76 + 8.0 * w_scale + sway * 0.76, top_y + tree_h * 0.20),
			Vector2(tx + lean * 0.62 + 28.0 * w_scale + sway * 0.62, top_y + tree_h * 0.40),
			Vector2(tx + lean * 0.54 + 14.0 * w_scale + sway * 0.54, top_y + tree_h * 0.42),
			Vector2(tx + lean * 0.40 + 38.0 * w_scale + sway * 0.40, top_y + tree_h * 0.62),
			Vector2(tx + lean * 0.32 + 22.0 * w_scale + sway * 0.32, top_y + tree_h * 0.65),
			Vector2(tx + lean * 0.18 + 48.0 * w_scale + sway * 0.18, top_y + tree_h * 0.84),
			Vector2(tx + 54.0 * w_scale, ground_base + 40.0),
			Vector2(tx - 54.0 * w_scale, ground_base + 40.0),
			Vector2(tx + lean * 0.18 - 46.0 * w_scale + sway * 0.18, top_y + tree_h * 0.84),
			Vector2(tx + lean * 0.32 - 20.0 * w_scale + sway * 0.32, top_y + tree_h * 0.65),
			Vector2(tx + lean * 0.40 - 36.0 * w_scale + sway * 0.40, top_y + tree_h * 0.62),
			Vector2(tx + lean * 0.54 - 13.0 * w_scale + sway * 0.54, top_y + tree_h * 0.42),
			Vector2(tx + lean * 0.62 - 27.0 * w_scale + sway * 0.62, top_y + tree_h * 0.40),
			Vector2(tx + lean * 0.76 - 8.0 * w_scale + sway * 0.76, top_y + tree_h * 0.20),
			Vector2(tx + lean * 0.82 - 16.0 * w_scale + sway * 0.82, top_y + tree_h * 0.18)
		])
		draw_colored_polygon(poly, col_back)
		draw_polyline(PackedVector2Array([
			Vector2(tx + lean + sway, top_y),
			Vector2(tx + lean * 0.62 + 28.0 * w_scale + sway * 0.62, top_y + tree_h * 0.40),
			Vector2(tx + lean * 0.40 + 38.0 * w_scale + sway * 0.40, top_y + tree_h * 0.62)
		]), col_hi, 1.6, true)

func _draw_midground_hills(vp: Vector2) -> void:
	var steps: int = 36
	var parallax: float = camera_x * 0.30
	var hill_top: PackedVector2Array = PackedVector2Array()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var x: float = t * (vp.x + 40.0) - 20.0
		var wx: float = (x + parallax) * 0.0026
		var y: float = vp.y * 0.79 + sin(wx * 1.3) * 34.0 + cos(wx * 2.7 + 1.2) * 16.0
		hill_top.append(Vector2(x, y))
	var poly: PackedVector2Array = hill_top.duplicate()
	poly.append(Vector2(vp.x + 28.0, vp.y + 16.0))
	poly.append(Vector2(-28.0, vp.y + 16.0))
	draw_colored_polygon(poly, Color(0.068, 0.155, 0.195, 0.94))
	draw_polyline(hill_top, Color(0.24, 0.56, 0.56, 0.36), 2.4, true)

func _draw_foliage_frond(origin: Vector2, dir: float, length: float, droop: float, col: Color, rim: Color) -> void:
	# Soft, painterly multi-lobed woodland leaf spray (no sharp wireframe outlines)
	var pts: PackedVector2Array = PackedVector2Array([
		origin + Vector2(0.0, 2.0),
		origin + Vector2(dir * length * 0.22, -droop * 0.48),
		origin + Vector2(dir * length * 0.45, -droop * 0.34),
		origin + Vector2(dir * length * 0.68, -droop * 0.16),
		origin + Vector2(dir * length * 0.90, droop * 0.22),
		origin + Vector2(dir * length, droop * 0.62),
		origin + Vector2(dir * length * 0.78, droop * 0.68),
		origin + Vector2(dir * length * 0.56, droop * 0.50),
		origin + Vector2(dir * length * 0.34, droop * 0.44),
		origin + Vector2(dir * length * 0.14, droop * 0.26)
	])
	draw_colored_polygon(pts, col)
	# Soft moonlit upper leaf sheen instead of bright wireframe rim
	draw_polyline(PackedVector2Array([
		origin + Vector2(dir * length * 0.16, -droop * 0.36),
		origin + Vector2(dir * length * 0.46, -droop * 0.28),
		origin + Vector2(dir * length * 0.74, -droop * 0.08)
	]), rim, 1.3, true)

func _draw_midground_woods(vp: Vector2) -> void:
	var spacing: float = 410.0
	var parallax: float = camera_x * 0.38
	var scroll_off: float = fposmod(parallax, spacing)
	var first_idx: int = int(floor(parallax / spacing))
	var base_y: float = vp.y * 0.94
	var count: int = int(ceil(vp.x / spacing)) + 2
	var firefly_cols: Array[Color] = [
		Color(0.45, 1.0, 0.78, 1.0),
		Color(0.32, 0.94, 1.0, 1.0),
		Color(1.0, 0.88, 0.44, 1.0)
	]
	# Realistic natural moonlit woodland bark & deep evergreen forest foliage
	var trunk_col: Color = Color(0.095, 0.118, 0.148, 0.96)
	var bark_mid: Color = Color(0.168, 0.186, 0.212, 0.82)
	var rim_col: Color = Color(0.46, 0.68, 0.82, 0.36)
	var leaf_dark: Color = Color(0.058, 0.152, 0.172, 0.92)
	var leaf_mid: Color = Color(0.088, 0.218, 0.218, 0.86)
	var leaf_rim: Color = Color(0.28, 0.56, 0.54, 0.26)

	for i in range(-1, count):
		var idx: int = first_idx + i
		var h: float = fposmod(absf(sin(float(idx) * 78.233) * 19234.12), 1.0)
		var h2: float = fposmod(absf(cos(float(idx) * 23.17) * 8192.4), 1.0)
		var tx: float = float(i) * spacing - scroll_off + (h - 0.5) * 90.0
		var tw: float = 18.0 + h * 15.0
		var bend_dir: float = 1.0 if idx % 2 == 0 else -1.0
		var curve_amp: float = (18.0 + h2 * 22.0) * bend_dir
		var sway: float = sin(_time * 1.15 + float(idx) * 1.1) * 7.0

		var left_pts: PackedVector2Array = PackedVector2Array()
		var right_pts: PackedVector2Array = PackedVector2Array()
		var rim_pts: PackedVector2Array = PackedVector2Array()
		var segs: int = 10
		for s in range(segs + 1):
			var t: float = float(s) / float(segs)
			var y: float = lerpf(base_y + 30.0, -28.0, t)
			var curve_x: float = sin(t * PI * 0.88) * curve_amp + t * t * sway
			var flare: float = pow(1.0 - t, 3.4) * (tw * 1.1)
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

		var grain_pts: PackedVector2Array = PackedVector2Array()
		for s in range(1, segs):
			grain_pts.append(left_pts[s].lerp(right_pts[s], 0.64))
		draw_polyline(grain_pts, bark_mid, 2.2, true)
		draw_polyline(rim_pts, rim_col, 1.8, true)

		# Bioluminescent shelf-mushrooms nestled on the lower trunk bark
		var sh_p: Vector2 = right_pts[3]
		draw_colored_polygon(PackedVector2Array([
			sh_p + Vector2(-4.0, 2.0),
			sh_p + Vector2(10.0, -3.5),
			sh_p + Vector2(14.0, 2.0),
			sh_p + Vector2(3.0, 4.5)
		]), Color(0.28, 0.84, 0.74, 0.68))

		# Arched woodland boughs + soft painterly leaf clusters + hanging moss
		for b_i in range(2):
			var b_dir: float = bend_dir if b_i == 0 else -bend_dir
			var bt: float = (0.58 + h * 0.16) if b_i == 0 else (0.74 + h2 * 0.12)
			var by: float = lerpf(base_y + 30.0, -28.0, bt)
			var bx0: float = tx + sin(bt * PI * 0.88) * curve_amp + bt * bt * sway
			var blen: float = 95.0 + (h if b_i == 0 else h2) * 62.0
			var b_sway: float = sin(_time * 1.4 + float(idx) + float(b_i) * 1.7) * 5.5
			var p0: Vector2 = Vector2(bx0, by)
			var p1: Vector2 = Vector2(bx0 + b_dir * blen * 0.36, by - 14.0 + b_sway * 0.3)
			var p2: Vector2 = Vector2(bx0 + b_dir * blen * 0.72, by - 22.0 + b_sway * 0.7)
			var p3: Vector2 = Vector2(bx0 + b_dir * blen, by - 8.0 + b_sway)

			draw_colored_polygon(PackedVector2Array([
				p0 + Vector2(0.0, -5.5),
				p1 + Vector2(0.0, -3.8),
				p2 + Vector2(0.0, -2.4),
				p3,
				p2 + Vector2(0.0, 2.6),
				p1 + Vector2(0.0, 4.4),
				p0 + Vector2(0.0, 5.8)
			]), trunk_col)

			_draw_foliage_frond(p1 + Vector2(0.0, -4.0), b_dir, 56.0 + h * 20.0, 22.0, leaf_dark, leaf_rim)
			_draw_foliage_frond(p2 + Vector2(0.0, -5.0), b_dir, 64.0 + h2 * 18.0, 24.0, leaf_mid, leaf_rim)
			_draw_foliage_frond(p2 + Vector2(0.0, -2.0), -b_dir, 44.0 + h * 14.0, 20.0, leaf_dark, leaf_rim)
			_draw_foliage_frond(p3 + Vector2(-b_dir * 6.0, -3.0), b_dir, 48.0 + h2 * 16.0, 24.0, leaf_mid, leaf_rim)

			if b_i == 0:
				for m in range(4):
					var mt: float = 0.24 + float(m) * 0.22
					var mp: Vector2 = p0.lerp(p2, mt) if mt < 0.7 else p2.lerp(p3, (mt - 0.7) / 0.3)
					var m_len: float = 34.0 + float((idx + m) % 3) * 16.0
					var m_sway: float = sin(_time * 1.9 + float(idx + m)) * 6.5
					var m_mid: Vector2 = Vector2(mp.x + m_sway * 0.45, mp.y + m_len * 0.55)
					var m_tip: Vector2 = Vector2(mp.x + m_sway, mp.y + m_len)
					draw_polyline(PackedVector2Array([mp, m_mid, m_tip]), Color(0.20, 0.48, 0.44, 0.48), 1.7, true)

		# Glowing warm bokeh twilight fireflies
		for f_i in range(2):
			var fi: float = float(f_i)
			var sx: float = tx + (fi - 0.5) * 130.0 + sin(_time * (0.7 + fi * 0.25) + float(idx) + fi * 2.1) * 44.0
			var sy: float = vp.y * (0.40 + (h - 0.5) * 0.28 + fi * 0.12) + cos(_time * (1.0 + fi * 0.3) + float(idx) * 1.4) * 22.0
			var sc: Color = firefly_cols[absi(idx + f_i) % firefly_cols.size()]
			var pulse: float = 0.72 + 0.28 * sin(_time * 2.6 + float(idx) + fi * 3.1)
			draw_circle(Vector2(sx, sy), 12.0 + h * 4.0, Color(sc.r, sc.g, sc.b, clampf(0.12 * flow_glow * pulse, 0.05, 0.26)))
			draw_circle(Vector2(sx, sy), 6.0 + h * 2.0, Color(sc.r, sc.g, sc.b, clampf(0.30 * flow_glow * pulse, 0.14, 0.56)))
			draw_circle(Vector2(sx, sy), 2.4 + h * 1.0, Color(0.98, 1.0, 0.96, clampf(0.84 * pulse, 0.42, 0.98)))

func _draw_drifting_petals() -> void:
	for p in _petals:
		var pos: Vector2 = Vector2(float(p["x"]), float(p["y"]))
		var sz: float = float(p["size"])
		var rot: float = float(p["rot"])
		var col: Color = p["color"]
		draw_circle(pos, sz * 2.2, Color(col.r, col.g, col.b, 0.16 * clampf(flow_glow, 0.85, 1.4)))
		var dir: Vector2 = Vector2(cos(rot), sin(rot))
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([
			pos - dir * sz,
			pos + perp * (sz * 0.54),
			pos + dir * sz,
			pos - perp * (sz * 0.40)
		]), col)

func _draw_volumetric_valley_mist(vp: Vector2) -> void:
	var bands: int = 16
	var mist_top: float = vp.y * 0.44
	var mist_bottom: float = vp.y + 18.0
	var fog_tint: Color = Color(0.24, 0.48, 0.58, 1.0)
	if lightning_flash > 0.08:
		fog_tint = fog_tint.lerp(Color(0.50, 0.68, 0.82, 1.0), lightning_flash * 0.4)

	for b in range(bands):
		var t0: float = float(b) / float(bands)
		var t1: float = float(b + 1) / float(bands)
		var y0: float = lerpf(mist_top, mist_bottom, t0)
		var y1: float = lerpf(mist_top, mist_bottom, t1)
		var density: float = pow(t0, 2.0) * (0.044 + lightning_flash * 0.014)
		var c: Color = Color(fog_tint.r, fog_tint.g, fog_tint.b, density)
		var strip: PackedVector2Array = PackedVector2Array()
		var x_steps: int = 12
		for xs in range(x_steps + 1):
			var xt: float = float(xs) / float(x_steps)
			var x: float = xt * vp.x
			var wave: float = sin(xt * TAU * 1.4 + _time * 0.32 + float(b) * 0.5 + camera_x * 0.00045) * (14.0 * (1.0 - t0 * 0.45))
			strip.append(Vector2(x, y0 + wave))
		strip.append(Vector2(vp.x, y1 + 6.0))
		strip.append(Vector2(0.0, y1 + 6.0))
		draw_colored_polygon(strip, c)
