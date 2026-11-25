extends Node2D
class_name EnvironmentManager

## High-Performance Luminous Moonlit Forest Parallax Manager (Layers 2-4 + Volumetric Mist)
## Optimized for pure Godot 4 GDScript:
## - Typed SoA arrays for drifting petals & soaring birds (zero Dictionary lookups)
## - Reusable PackedVector2Array buffers (zero per-frame array allocations)
## - Smooth 8-band valley mist & frustum-culled trees

const WIND_SWAY_SHADER: Shader = preload("res://shaders/wind_sway.gdshader")

const PETAL_COUNT: int = 28
const BIRD_COUNT: int = 6

const COL_BIRD: Color = Color(0.24, 0.40, 0.56, 0.62)
const COL_CANOPY_BACK: Color = Color(0.075, 0.165, 0.235, 0.94)
const COL_CANOPY_HI: Color = Color(0.22, 0.44, 0.52, 0.45)
const COL_HILL: Color = Color(0.068, 0.155, 0.195, 0.94)
const COL_HILL_RIM: Color = Color(0.24, 0.56, 0.56, 0.36)
const COL_TRUNK: Color = Color(0.095, 0.118, 0.148, 0.96)
const COL_BARK_MID: Color = Color(0.168, 0.186, 0.212, 0.82)
const COL_TRUNK_RIM: Color = Color(0.46, 0.68, 0.82, 0.36)
const COL_LEAF_DARK: Color = Color(0.058, 0.152, 0.172, 0.92)
const COL_LEAF_MID: Color = Color(0.088, 0.218, 0.218, 0.86)
const COL_LEAF_RIM: Color = Color(0.28, 0.56, 0.54, 0.26)
const COL_MOSS: Color = Color(0.20, 0.48, 0.44, 0.48)
const COL_SHELF: Color = Color(0.28, 0.84, 0.74, 0.68)

var FIREFLY_COLS: PackedColorArray = PackedColorArray([
	Color(0.45, 1.0, 0.78, 1.0),
	Color(0.32, 0.94, 1.0, 1.0),
	Color(1.0, 0.88, 0.44, 1.0)
])

var camera_x: float = 0.0
var speed_px: float = 480.0
var flow_glow: float = 1.0
var lightning_flash: float = 0.0
var active_color: Color = Color(0.31, 1.0, 0.69, 1.0)

var _time: float = 0.0
var _sway_trees: Array[Polygon2D] = []
var _sway_mat: ShaderMaterial

# SoA petals
var _px: PackedFloat32Array = PackedFloat32Array()
var _py: PackedFloat32Array = PackedFloat32Array()
var _pvx: PackedFloat32Array = PackedFloat32Array()
var _pvy: PackedFloat32Array = PackedFloat32Array()
var _psz: PackedFloat32Array = PackedFloat32Array()
var _prot: PackedFloat32Array = PackedFloat32Array()
var _pspin: PackedFloat32Array = PackedFloat32Array()
var _pph: PackedFloat32Array = PackedFloat32Array()
var _pcol: PackedColorArray = PackedColorArray()

# SoA birds
var _bx: PackedFloat32Array = PackedFloat32Array()
var _by: PackedFloat32Array = PackedFloat32Array()
var _bvx: PackedFloat32Array = PackedFloat32Array()
var _bsc: PackedFloat32Array = PackedFloat32Array()
var _bph: PackedFloat32Array = PackedFloat32Array()

# Reusable drawing buffers
var _quad_buf: PackedVector2Array = PackedVector2Array()
var _bird_buf: PackedVector2Array = PackedVector2Array()
var _ridge_crest: PackedVector2Array = PackedVector2Array()
var _ridge_poly: PackedVector2Array = PackedVector2Array()
var _hill_top: PackedVector2Array = PackedVector2Array()
var _hill_poly: PackedVector2Array = PackedVector2Array()
var _pine_buf: PackedVector2Array = PackedVector2Array()
var _pine_hi: PackedVector2Array = PackedVector2Array()
var _frond_pts: PackedVector2Array = PackedVector2Array()
var _frond_rim: PackedVector2Array = PackedVector2Array()
var _trunk_left: PackedVector2Array = PackedVector2Array()
var _trunk_right: PackedVector2Array = PackedVector2Array()
var _trunk_poly: PackedVector2Array = PackedVector2Array()
var _trunk_grain: PackedVector2Array = PackedVector2Array()
var _bough_poly: PackedVector2Array = PackedVector2Array()
var _moss_pts: PackedVector2Array = PackedVector2Array()
var _mist_strip: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	_quad_buf.resize(4)
	_bird_buf.resize(5)
	_ridge_crest.resize(37)
	_ridge_poly.resize(39)
	_hill_top.resize(29)
	_hill_poly.resize(31)
	_pine_buf.resize(17)
	_pine_hi.resize(3)
	_frond_pts.resize(10)
	_frond_rim.resize(3)
	_trunk_left.resize(9)
	_trunk_right.resize(9)
	_trunk_poly.resize(18)
	_trunk_grain.resize(7)
	_bough_poly.resize(7)
	_moss_pts.resize(3)
	_mist_strip.resize(11)

	_sway_mat = ShaderMaterial.new()
	_sway_mat.shader = WIND_SWAY_SHADER
	_sway_mat.set_shader_parameter("wind_strength", 6.0)
	_sway_mat.set_shader_parameter("wind_speed", 1.2)
	_sway_mat.set_shader_parameter("sway_height", 460.0)

	var pine_poly: PackedVector2Array = PackedVector2Array([
		Vector2(-9.0, 14.0), Vector2(-11.0, -72.0), Vector2(-40.0, -86.0),
		Vector2(-18.0, -132.0), Vector2(-46.0, -150.0), Vector2(-18.0, -200.0),
		Vector2(-38.0, -220.0), Vector2(-15.0, -274.0), Vector2(-30.0, -294.0),
		Vector2(-11.0, -346.0), Vector2(-18.0, -366.0), Vector2(0.0, -432.0),
		Vector2(18.0, -366.0), Vector2(11.0, -346.0), Vector2(30.0, -294.0),
		Vector2(15.0, -274.0), Vector2(38.0, -220.0), Vector2(18.0, -200.0),
		Vector2(46.0, -150.0), Vector2(18.0, -132.0), Vector2(40.0, -86.0),
		Vector2(11.0, -72.0), Vector2(9.0, 14.0)
	])
	for i in range(6):
		var canopy: Polygon2D = Polygon2D.new()
		canopy.material = _sway_mat
		canopy.color = Color(0.095, 0.195, 0.255, 0.34 + float(i % 2) * 0.08)
		canopy.polygon = pine_poly
		add_child(canopy)
		_sway_trees.append(canopy)

	var p_cols: PackedColorArray = PackedColorArray([
		Color(0.52, 1.0, 0.84, 0.78),
		Color(0.42, 0.94, 1.0, 0.72),
		Color(0.98, 0.84, 0.96, 0.68),
		Color(1.0, 0.88, 0.54, 0.72)
	])
	_px.resize(PETAL_COUNT)
	_py.resize(PETAL_COUNT)
	_pvx.resize(PETAL_COUNT)
	_pvy.resize(PETAL_COUNT)
	_psz.resize(PETAL_COUNT)
	_prot.resize(PETAL_COUNT)
	_pspin.resize(PETAL_COUNT)
	_pph.resize(PETAL_COUNT)
	_pcol.resize(PETAL_COUNT)
	for i in range(PETAL_COUNT):
		_px[i] = randf_range(0.0, 1340.0)
		_py[i] = randf_range(60.0, 650.0)
		_pvx[i] = randf_range(-68.0, -28.0)
		_pvy[i] = randf_range(-12.0, 20.0)
		_psz[i] = randf_range(3.2, 6.2)
		_prot[i] = randf_range(0.0, TAU)
		_pspin[i] = randf_range(-2.4, 2.4)
		_pph[i] = randf_range(0.0, TAU)
		_pcol[i] = p_cols[i % p_cols.size()]

	_bx.resize(BIRD_COUNT)
	_by.resize(BIRD_COUNT)
	_bvx.resize(BIRD_COUNT)
	_bsc.resize(BIRD_COUNT)
	_bph.resize(BIRD_COUNT)
	for i in range(BIRD_COUNT):
		_bx[i] = randf_range(120.0, 1240.0)
		_by[i] = randf_range(95.0, 260.0)
		_bvx[i] = randf_range(26.0, 52.0)
		_bsc[i] = randf_range(0.85, 1.45)
		_bph[i] = randf_range(0.0, TAU)

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

		var spd_drag: float = speed_px * 0.07
		for i in range(PETAL_COUNT):
			var px: float = _px[i] + (_pvx[i] - spd_drag) * dt
			var py: float = _py[i] + (_pvy[i] + sin(_time * 1.9 + _pph[i]) * 20.0) * dt
			if px < -50.0 or py > vp.y + 40.0 or py < -40.0:
				px = vp.x + randf_range(15.0, 200.0)
				py = randf_range(60.0, vp.y * 0.86)
			_px[i] = px
			_py[i] = py
			_prot[i] = _prot[i] + _pspin[i] * dt

		for i in range(BIRD_COUNT):
			var bx: float = _bx[i] + _bvx[i] * dt
			if bx > vp.x + 110.0:
				bx = -110.0
				_by[i] = randf_range(95.0, vp.y * 0.36)
			_bx[i] = bx

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
		_quad_buf[0] = moon_pos + Vector2(spread_x * 0.18 - top_w * 0.5, 28.0)
		_quad_buf[1] = moon_pos + Vector2(spread_x * 0.18 + top_w * 0.5, 28.0)
		_quad_buf[2] = Vector2(moon_pos.x + dir_x + bot_w * 0.5, vp.y + 12.0)
		_quad_buf[3] = Vector2(moon_pos.x + dir_x - bot_w * 0.5, vp.y + 12.0)
		draw_colored_polygon(_quad_buf, Color(0.68, 0.88, 1.0, ray_alpha))

func _draw_soaring_birds() -> void:
	for i in range(BIRD_COUNT):
		var bx: float = _bx[i]
		var ph: float = _bph[i]
		var by: float = _by[i] + sin(_time * 1.4 + ph) * 9.0
		var bs: float = _bsc[i]
		var flap: float = sin(_time * 5.2 + ph) * 5.5 * bs
		_bird_buf[0] = Vector2(bx - 12.0 * bs, by - 2.4 * bs + flap)
		_bird_buf[1] = Vector2(bx - 5.2 * bs, by - 4.2 * bs + flap * 0.4)
		_bird_buf[2] = Vector2(bx, by)
		_bird_buf[3] = Vector2(bx + 5.2 * bs, by - 4.2 * bs + flap * 0.4)
		_bird_buf[4] = Vector2(bx + 12.0 * bs, by - 2.4 * bs + flap)
		draw_polyline(_bird_buf, COL_BIRD, 1.8, true)

func _draw_mountains(vp: Vector2) -> void:
	var c1: Color = Color(0.21, 0.32, 0.48, 0.94) if lightning_flash > 0.1 else Color(0.145, 0.235, 0.375, 0.94)
	var rim1: Color = Color(0.56, 0.76, 0.94, 0.38 + lightning_flash * 0.25)
	var c2: Color = Color(0.16, 0.26, 0.40, 0.97) if lightning_flash > 0.1 else Color(0.105, 0.195, 0.305, 0.97)
	var rim2: Color = Color(0.42, 0.66, 0.82, 0.32 + lightning_flash * 0.20)
	_draw_smooth_ridge(vp, 0.04, vp.y * 0.58, vp.y * 0.16, c1, rim1, 1.15)
	_draw_smooth_ridge(vp, 0.085, vp.y * 0.67, vp.y * 0.12, c2, rim2, 4.35)

func _draw_smooth_ridge(vp: Vector2, speed: float, base_y: float, amp: float, col: Color, rim: Color, seed_v: float) -> void:
	var steps: int = 36
	var inv_steps: float = 1.0 / float(steps)
	var parallax: float = camera_x * speed
	var span_x: float = vp.x + 50.0
	for i in range(steps + 1):
		var x: float = float(i) * inv_steps * span_x - 25.0
		var wx: float = (x + parallax) * 0.0021
		var h: float = (
			sin(wx * 1.1 + seed_v) * 0.46
			+ sin(wx * 2.35 + seed_v * 1.7) * 0.28
			+ cos(wx * 4.2 + seed_v * 2.3) * 0.14
		)
		var pt: Vector2 = Vector2(x, base_y - (h * 0.5 + 0.5) * amp)
		_ridge_crest[i] = pt
		_ridge_poly[i] = pt
	_ridge_poly[steps + 1] = Vector2(vp.x + 30.0, vp.y + 16.0)
	_ridge_poly[steps + 2] = Vector2(-30.0, vp.y + 16.0)
	draw_colored_polygon(_ridge_poly, col)
	draw_polyline(_ridge_crest, rim, 2.4, true)

func _draw_far_canopy(vp: Vector2) -> void:
	var spacing: float = 112.0
	var parallax: float = camera_x * 0.18
	var scroll_off: float = fposmod(parallax, spacing)
	var first_idx: int = int(floor(parallax / spacing))
	var ground_base: float = vp.y * 0.85
	var count: int = int(ceil(vp.x / spacing)) + 2
	for i in range(-1, count):
		var idx: int = first_idx + i
		var h: float = fposmod(absf(sin(float(idx) * 12.9898) * 43758.5453), 1.0)
		var h2: float = fposmod(absf(cos(float(idx) * 39.346) * 23421.63), 1.0)
		var tx: float = float(i) * spacing - scroll_off + (h - 0.5) * 50.0
		if tx < -90.0 or tx > vp.x + 90.0:
			continue
		var tree_h: float = 175.0 + h * 225.0
		var lean: float = (h2 - 0.5) * 18.0
		var sway: float = sin(_time * 0.82 + float(idx) * 0.7) * 5.0
		var top_y: float = ground_base - tree_h
		var w_scale: float = 0.72 + h2 * 0.44
		_pine_buf[0] = Vector2(tx + lean + sway, top_y)
		_pine_buf[1] = Vector2(tx + lean * 0.82 + 16.0 * w_scale + sway * 0.82, top_y + tree_h * 0.18)
		_pine_buf[2] = Vector2(tx + lean * 0.76 + 8.0 * w_scale + sway * 0.76, top_y + tree_h * 0.20)
		_pine_buf[3] = Vector2(tx + lean * 0.62 + 28.0 * w_scale + sway * 0.62, top_y + tree_h * 0.40)
		_pine_buf[4] = Vector2(tx + lean * 0.54 + 14.0 * w_scale + sway * 0.54, top_y + tree_h * 0.42)
		_pine_buf[5] = Vector2(tx + lean * 0.40 + 38.0 * w_scale + sway * 0.40, top_y + tree_h * 0.62)
		_pine_buf[6] = Vector2(tx + lean * 0.32 + 22.0 * w_scale + sway * 0.32, top_y + tree_h * 0.65)
		_pine_buf[7] = Vector2(tx + lean * 0.18 + 48.0 * w_scale + sway * 0.18, top_y + tree_h * 0.84)
		_pine_buf[8] = Vector2(tx + 54.0 * w_scale, ground_base + 40.0)
		_pine_buf[9] = Vector2(tx - 54.0 * w_scale, ground_base + 40.0)
		_pine_buf[10] = Vector2(tx + lean * 0.18 - 46.0 * w_scale + sway * 0.18, top_y + tree_h * 0.84)
		_pine_buf[11] = Vector2(tx + lean * 0.32 - 20.0 * w_scale + sway * 0.32, top_y + tree_h * 0.65)
		_pine_buf[12] = Vector2(tx + lean * 0.40 - 36.0 * w_scale + sway * 0.40, top_y + tree_h * 0.62)
		_pine_buf[13] = Vector2(tx + lean * 0.54 - 13.0 * w_scale + sway * 0.54, top_y + tree_h * 0.42)
		_pine_buf[14] = Vector2(tx + lean * 0.62 - 27.0 * w_scale + sway * 0.62, top_y + tree_h * 0.40)
		_pine_buf[15] = Vector2(tx + lean * 0.76 - 8.0 * w_scale + sway * 0.76, top_y + tree_h * 0.20)
		_pine_buf[16] = Vector2(tx + lean * 0.82 - 16.0 * w_scale + sway * 0.82, top_y + tree_h * 0.18)
		draw_colored_polygon(_pine_buf, COL_CANOPY_BACK)
		_pine_hi[0] = _pine_buf[0]
		_pine_hi[1] = _pine_buf[3]
		_pine_hi[2] = _pine_buf[5]
		draw_polyline(_pine_hi, COL_CANOPY_HI, 1.6, true)

func _draw_midground_hills(vp: Vector2) -> void:
	var steps: int = 28
	var inv_steps: float = 1.0 / float(steps)
	var parallax: float = camera_x * 0.30
	var span_x: float = vp.x + 40.0
	var base_y: float = vp.y * 0.79
	for i in range(steps + 1):
		var x: float = float(i) * inv_steps * span_x - 20.0
		var wx: float = (x + parallax) * 0.0026
		var pt: Vector2 = Vector2(x, base_y + sin(wx * 1.3) * 34.0 + cos(wx * 2.7 + 1.2) * 16.0)
		_hill_top[i] = pt
		_hill_poly[i] = pt
	_hill_poly[steps + 1] = Vector2(vp.x + 28.0, vp.y + 16.0)
	_hill_poly[steps + 2] = Vector2(-28.0, vp.y + 16.0)
	draw_colored_polygon(_hill_poly, COL_HILL)
	draw_polyline(_hill_top, COL_HILL_RIM, 2.4, true)

func _draw_foliage_frond(origin: Vector2, dir: float, length: float, droop: float, col: Color) -> void:
	var dl: float = dir * length
	_frond_pts[0] = origin + Vector2(0.0, 2.0)
	_frond_pts[1] = origin + Vector2(dl * 0.22, -droop * 0.48)
	_frond_pts[2] = origin + Vector2(dl * 0.45, -droop * 0.34)
	_frond_pts[3] = origin + Vector2(dl * 0.68, -droop * 0.16)
	_frond_pts[4] = origin + Vector2(dl * 0.90, droop * 0.22)
	_frond_pts[5] = origin + Vector2(dl, droop * 0.62)
	_frond_pts[6] = origin + Vector2(dl * 0.78, droop * 0.68)
	_frond_pts[7] = origin + Vector2(dl * 0.56, droop * 0.50)
	_frond_pts[8] = origin + Vector2(dl * 0.34, droop * 0.44)
	_frond_pts[9] = origin + Vector2(dl * 0.14, droop * 0.26)
	draw_colored_polygon(_frond_pts, col)
	_frond_rim[0] = origin + Vector2(dl * 0.16, -droop * 0.36)
	_frond_rim[1] = origin + Vector2(dl * 0.46, -droop * 0.28)
	_frond_rim[2] = origin + Vector2(dl * 0.74, -droop * 0.08)
	draw_polyline(_frond_rim, COL_LEAF_RIM, 1.3, true)

func _draw_midground_woods(vp: Vector2) -> void:
	var spacing: float = 410.0
	var parallax: float = camera_x * 0.38
	var scroll_off: float = fposmod(parallax, spacing)
	var first_idx: int = int(floor(parallax / spacing))
	var base_y: float = vp.y * 0.94
	var count: int = int(ceil(vp.x / spacing)) + 2

	for i in range(-1, count):
		var idx: int = first_idx + i
		var h: float = fposmod(absf(sin(float(idx) * 78.233) * 19234.12), 1.0)
		var h2: float = fposmod(absf(cos(float(idx) * 23.17) * 8192.4), 1.0)
		var tx: float = float(i) * spacing - scroll_off + (h - 0.5) * 90.0
		if tx < -220.0 or tx > vp.x + 220.0:
			continue
		var tw: float = 18.0 + h * 15.0
		var bend_dir: float = 1.0 if idx % 2 == 0 else -1.0
		var curve_amp: float = (18.0 + h2 * 22.0) * bend_dir
		var sway: float = sin(_time * 1.15 + float(idx) * 1.1) * 7.0

		var segs: int = 8
		for s in range(segs + 1):
			var t: float = float(s) / float(segs)
			var y: float = lerpf(base_y + 30.0, -28.0, t)
			var curve_x: float = sin(t * PI * 0.88) * curve_amp + t * t * sway
			var one_m_t: float = 1.0 - t
			var flare: float = one_m_t * one_m_t * one_m_t * (tw * 1.1)
			var half_w: float = lerpf(tw * 0.58, tw * 0.22, t) + flare
			var cx: float = tx + curve_x
			_trunk_left[s] = Vector2(cx - half_w, y)
			_trunk_right[s] = Vector2(cx + half_w, y)

		for s in range(segs + 1):
			_trunk_poly[s] = _trunk_left[s]
			_trunk_poly[segs + 1 + s] = _trunk_right[segs - s]
		draw_colored_polygon(_trunk_poly, COL_TRUNK)

		for s in range(1, segs):
			_trunk_grain[s - 1] = _trunk_left[s].lerp(_trunk_right[s], 0.64)
		draw_polyline(_trunk_grain, COL_BARK_MID, 2.2, true)
		draw_polyline(_trunk_right, COL_TRUNK_RIM, 1.8, true)

		var sh_p: Vector2 = _trunk_right[2]
		_quad_buf[0] = sh_p + Vector2(-4.0, 2.0)
		_quad_buf[1] = sh_p + Vector2(10.0, -3.5)
		_quad_buf[2] = sh_p + Vector2(14.0, 2.0)
		_quad_buf[3] = sh_p + Vector2(3.0, 4.5)
		draw_colored_polygon(_quad_buf, COL_SHELF)

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

			_bough_poly[0] = p0 + Vector2(0.0, -5.5)
			_bough_poly[1] = p1 + Vector2(0.0, -3.8)
			_bough_poly[2] = p2 + Vector2(0.0, -2.4)
			_bough_poly[3] = p3
			_bough_poly[4] = p2 + Vector2(0.0, 2.6)
			_bough_poly[5] = p1 + Vector2(0.0, 4.4)
			_bough_poly[6] = p0 + Vector2(0.0, 5.8)
			draw_colored_polygon(_bough_poly, COL_TRUNK)

			_draw_foliage_frond(p1 + Vector2(0.0, -4.0), b_dir, 56.0 + h * 20.0, 22.0, COL_LEAF_DARK)
			_draw_foliage_frond(p2 + Vector2(0.0, -5.0), b_dir, 64.0 + h2 * 18.0, 24.0, COL_LEAF_MID)
			_draw_foliage_frond(p2 + Vector2(0.0, -2.0), -b_dir, 44.0 + h * 14.0, 20.0, COL_LEAF_DARK)
			_draw_foliage_frond(p3 + Vector2(-b_dir * 6.0, -3.0), b_dir, 48.0 + h2 * 16.0, 24.0, COL_LEAF_MID)

			if b_i == 0:
				for m in range(4):
					var mt: float = 0.24 + float(m) * 0.22
					var mp: Vector2 = p0.lerp(p2, mt) if mt < 0.7 else p2.lerp(p3, (mt - 0.7) / 0.3)
					var m_len: float = 34.0 + float((idx + m) % 3) * 16.0
					var m_sway: float = sin(_time * 1.9 + float(idx + m)) * 6.5
					_moss_pts[0] = mp
					_moss_pts[1] = Vector2(mp.x + m_sway * 0.45, mp.y + m_len * 0.55)
					_moss_pts[2] = Vector2(mp.x + m_sway, mp.y + m_len)
					draw_polyline(_moss_pts, COL_MOSS, 1.7, true)

		for f_i in range(2):
			var fi: float = float(f_i)
			var sx: float = tx + (fi - 0.5) * 130.0 + sin(_time * (0.7 + fi * 0.25) + float(idx) + fi * 2.1) * 44.0
			var sy: float = vp.y * (0.40 + (h - 0.5) * 0.28 + fi * 0.12) + cos(_time * (1.0 + fi * 0.3) + float(idx) * 1.4) * 22.0
			var sc: Color = FIREFLY_COLS[absi(idx + f_i) % FIREFLY_COLS.size()]
			var pulse: float = 0.72 + 0.28 * sin(_time * 2.6 + float(idx) + fi * 3.1)
			draw_circle(Vector2(sx, sy), 12.0 + h * 4.0, Color(sc.r, sc.g, sc.b, clampf(0.12 * flow_glow * pulse, 0.05, 0.26)))
			draw_circle(Vector2(sx, sy), 6.0 + h * 2.0, Color(sc.r, sc.g, sc.b, clampf(0.30 * flow_glow * pulse, 0.14, 0.56)))
			draw_circle(Vector2(sx, sy), 2.4 + h * 1.0, Color(0.98, 1.0, 0.96, clampf(0.84 * pulse, 0.42, 0.98)))

func _draw_drifting_petals() -> void:
	var halo_a: float = 0.16 * clampf(flow_glow, 0.85, 1.4)
	for i in range(PETAL_COUNT):
		var pos: Vector2 = Vector2(_px[i], _py[i])
		var sz: float = _psz[i]
		var rot: float = _prot[i]
		var col: Color = _pcol[i]
		draw_circle(pos, sz * 2.2, Color(col.r, col.g, col.b, halo_a))
		var dir: Vector2 = Vector2(cos(rot), sin(rot))
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		_quad_buf[0] = pos - dir * sz
		_quad_buf[1] = pos + perp * (sz * 0.54)
		_quad_buf[2] = pos + dir * sz
		_quad_buf[3] = pos - perp * (sz * 0.40)
		draw_colored_polygon(_quad_buf, col)

func _draw_volumetric_valley_mist(vp: Vector2) -> void:
	var bands: int = 8
	var inv_bands: float = 1.0 / float(bands)
	var mist_top: float = vp.y * 0.46
	var mist_bottom: float = vp.y + 18.0
	var fog_tint: Color = Color(0.24, 0.48, 0.58, 1.0)
	if lightning_flash > 0.08:
		fog_tint = fog_tint.lerp(Color(0.50, 0.68, 0.82, 1.0), lightning_flash * 0.4)

	var x_steps: int = 8
	var inv_x: float = 1.0 / float(x_steps)
	var base_phase: float = _time * 0.32 + camera_x * 0.00045
	for b in range(bands):
		var t0: float = float(b) * inv_bands
		var t1: float = float(b + 1) * inv_bands
		var y0: float = lerpf(mist_top, mist_bottom, t0)
		var y1: float = lerpf(mist_top, mist_bottom, t1)
		var density: float = t0 * t0 * (0.072 + lightning_flash * 0.020)
		var amp: float = 14.0 * (1.0 - t0 * 0.45)
		var b_ph: float = base_phase + float(b) * 0.5
		for xs in range(x_steps + 1):
			var xt: float = float(xs) * inv_x
			_mist_strip[xs] = Vector2(xt * vp.x, y0 + sin(xt * TAU * 1.4 + b_ph) * amp)
		_mist_strip[x_steps + 1] = Vector2(vp.x, y1 + 6.0)
		_mist_strip[x_steps + 2] = Vector2(0.0, y1 + 6.0)
		draw_colored_polygon(_mist_strip, Color(fog_tint.r, fog_tint.g, fog_tint.b, density))
