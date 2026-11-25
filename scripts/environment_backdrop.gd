extends Node2D
class_name EnvironmentBackdrop

## 6-Layer Procedural Parallax Twilight Forest & Dynamic Rain Weather
## Layers 1-4 (Back): Stormy Sky Shader, Distant Jagged Mountains, Far Ancient Canopy,
## Mid-Ground Living Woods (wind-swaying trunks, hanging moss, glowing mushrooms/spores).
## Layer 6 (Front): Fast dark silhouette foreground branches, 3-depth diagonal rain streaks,
## and raindrop splash ripples.

const TREE_SWAY_SHADER := preload("res://shaders/tree_sway.gdshader")

@export var is_foreground: bool = false

var camera_x: float = 0.0
var speed_px: float = 480.0
var flow_glow: float = 1.0
var lightning_flash: float = 0.0
var active_color: Color = Color(0.31, 1.0, 0.69, 1.0)
var _time: float = 0.0
var _rain: Array[Dictionary] = []
var _sway_trees: Array[Polygon2D] = []
var _sway_mat: ShaderMaterial

func _ready() -> void:
	if is_foreground:
		for i in range(120):
			var depth := i % 3
			_rain.append({
				"x": randf_range(0.0, 1600.0),
				"y": randf_range(0.0, 900.0),
				"speed": 520.0 if depth == 0 else (780.0 if depth == 1 else 1080.0),
				"len": 14.0 if depth == 0 else (22.0 if depth == 1 else 34.0),
				"depth": depth,
				"alpha": 0.14 if depth == 0 else (0.24 if depth == 1 else 0.36)
			})
	else:
		_sway_mat = ShaderMaterial.new()
		_sway_mat.shader = TREE_SWAY_SHADER
		_sway_mat.set_shader_parameter("wind_strength", 9.0)
		_sway_mat.set_shader_parameter("wind_speed", 1.55)
		_sway_mat.set_shader_parameter("sway_height", 340.0)
		for i in range(8):
			var canopy := Polygon2D.new()
			canopy.material = _sway_mat
			canopy.color = Color(0.018, 0.038, 0.076, 0.92)
			canopy.polygon = PackedVector2Array([
				Vector2(-24.0, 0.0),
				Vector2(-18.0, -140.0),
				Vector2(-58.0, -210.0),
				Vector2(-28.0, -245.0),
				Vector2(-42.0, -310.0),
				Vector2(0.0, -360.0),
				Vector2(44.0, -305.0),
				Vector2(26.0, -240.0),
				Vector2(62.0, -200.0),
				Vector2(18.0, -135.0),
				Vector2(26.0, 0.0)
			])
			add_child(canopy)
			_sway_trees.append(canopy)

func sync_backdrop(dt: float, p_cam_x: float, p_speed: float, p_flow: int, p_lightning: float, p_col: Color) -> void:
	_time += dt
	camera_x = p_cam_x
	speed_px = p_speed
	flow_glow = 1.0 + float(p_flow - 1) * 0.08
	lightning_flash = p_lightning
	active_color = p_col

	if is_foreground:
		var vp := get_viewport_rect().size
		var wind_x := -(180.0 + speed_px * 0.42)
		for r in _rain:
			var df := 0.65 if r["depth"] == 0 else (1.0 if r["depth"] == 1 else 1.4)
			r["x"] += wind_x * df * dt
			r["y"] += r["speed"] * dt
			if r["y"] > vp.y + 30.0 or r["x"] < -60.0:
				r["x"] = randf_range(0.0, vp.x + 260.0)
				r["y"] = randf_range(-120.0, -15.0)
	elif _sway_mat:
		var vp := get_viewport_rect().size
		if vp.x > 1.0 and vp.y > 1.0:
			_sway_mat.set_shader_parameter("wind_strength", clampf(7.0 + speed_px * 0.014, 7.0, 22.0))
			var spacing := 290.0
			var parallax := camera_x * 0.34
			var offset := fposmod(parallax, spacing)
			var base_y := vp.y * 0.88
			for i in range(_sway_trees.size()):
				var t_node := _sway_trees[i]
				t_node.position = Vector2(float(i) * spacing - offset - 60.0, base_y)
				var s := 0.85 + float(i % 3) * 0.18
				t_node.scale = Vector2(s, s)
	queue_redraw()

func _draw() -> void:
	var vp := get_viewport_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return
	if is_foreground:
		_draw_foreground_silhouettes(vp)
		_draw_rain(vp)
	else:
		_draw_mountains(vp)
		_draw_far_canopy(vp)
		_draw_midground_woods(vp)
		_draw_mist_band(vp)

func _draw_mountains(vp: Vector2) -> void:
	_draw_ridge(vp, 0.05, vp.y * 0.63, vp.y * 0.18, Color(0.09, 0.16, 0.25) if lightning_flash > 0.1 else Color(0.047, 0.094, 0.172), 1.3)
	_draw_ridge(vp, 0.095, vp.y * 0.69, vp.y * 0.13, Color(0.07, 0.13, 0.22) if lightning_flash > 0.1 else Color(0.031, 0.071, 0.133), 4.7)

func _draw_ridge(vp: Vector2, speed: float, base_y: float, amp: float, col: Color, seed_v: float) -> void:
	var step := 95.0
	var parallax := camera_x * speed
	var offset := fposmod(parallax, step)
	var base_idx := int(floor(parallax / step))
	var poly := PackedVector2Array([Vector2(-step, vp.y)])
	var count := int(ceil(vp.x / step)) + 3
	for i in range(-1, count):
		var idx := base_idx + i
		var h1 := absf(sin(float(idx) * 1.71 + seed_v)) * amp
		var h2 := absf(cos(float(idx) * 0.63 + seed_v * 2.0)) * (amp * 0.55)
		poly.append(Vector2(float(i) * step - offset, base_y - h1 - h2))
	poly.append(Vector2(vp.x + step * 2.0, vp.y))
	draw_colored_polygon(poly, col)

func _draw_far_canopy(vp: Vector2) -> void:
	var spacing := 110.0
	var parallax := camera_x * 0.18
	var offset := fposmod(parallax, spacing)
	var first_idx := int(floor(parallax / spacing))
	var ground_base := vp.y * 0.78
	var col := Color(0.024, 0.055, 0.106, 1.0)
	var count := int(ceil(vp.x / spacing)) + 3
	for i in range(-2, count):
		var idx := first_idx + i
		var h := fposmod(absf(sin(float(idx) * 12.9898) * 43758.5453), 1.0)
		var tx := float(i) * spacing - offset + (h - 0.5) * 40.0
		var tree_h := 145.0 + h * 165.0
		var sway := sin(_time * 0.9 + float(idx) * 0.7) * 5.0
		var top_y := ground_base - tree_h
		var poly := PackedVector2Array([
			Vector2(tx + sway, top_y),
			Vector2(tx + 22.0 + sway * 0.7, top_y + tree_h * 0.34),
			Vector2(tx + 12.0 + sway * 0.6, top_y + tree_h * 0.34),
			Vector2(tx + 34.0 + sway * 0.4, top_y + tree_h * 0.68),
			Vector2(tx + 18.0 + sway * 0.3, top_y + tree_h * 0.68),
			Vector2(tx + 42.0, ground_base + 25.0),
			Vector2(tx - 42.0, ground_base + 25.0),
			Vector2(tx - 18.0 + sway * 0.3, top_y + tree_h * 0.68),
			Vector2(tx - 34.0 + sway * 0.4, top_y + tree_h * 0.68),
			Vector2(tx - 12.0 + sway * 0.6, top_y + tree_h * 0.34),
			Vector2(tx - 22.0 + sway * 0.7, top_y + tree_h * 0.34)
		])
		draw_colored_polygon(poly, col)

func _draw_midground_woods(vp: Vector2) -> void:
	var spacing := 240.0
	var parallax := camera_x * 0.42
	var offset := fposmod(parallax, spacing)
	var first_idx := int(floor(parallax / spacing))
	var base_y := vp.y * 0.86
	var count := int(ceil(vp.x / spacing)) + 2
	var spore_cols := [Color(0.31, 1.0, 0.69), Color(0.0, 0.9, 1.0), Color(1.0, 0.62, 0.0)]

	for i in range(-1, count):
		var idx := first_idx + i
		var h := fposmod(absf(sin(float(idx) * 78.233) * 19234.12), 1.0)
		var tx := float(i) * spacing - offset + (h - 0.5) * 65.0
		var tw := 16.0 + h * 22.0
		var sway := sin(_time * 1.35 + float(idx) * 1.1) * 9.0

		var trunk := PackedVector2Array([
			Vector2(tx - tw * 0.7, base_y + 40.0),
			Vector2(tx - tw * 0.45 + sway * 0.35, vp.y * 0.45),
			Vector2(tx - tw * 0.25 + sway, -20.0),
			Vector2(tx + tw * 0.3 + sway, -20.0),
			Vector2(tx + tw * 0.48 + sway * 0.35, vp.y * 0.45),
			Vector2(tx + tw * 0.8, base_y + 40.0)
		])
		draw_colored_polygon(trunk, Color(0.02, 0.039, 0.078, 1.0))

		# Twisted branches & hanging willow moss strands
		var dir := 1.0 if idx % 2 == 0 else -1.0
		var by := vp.y * (0.24 + h * 0.22)
		var b_end := Vector2(tx + dir * (78.0 + h * 50.0) + sway * 1.15, by - 22.0 + sin(_time * 1.6 + float(idx)) * 6.0)
		draw_line(Vector2(tx + sway * 0.55, by), b_end, Color(0.024, 0.047, 0.094, 1.0), 6.0, true)

		for m in range(4):
			var mx := tx + dir * (22.0 + float(m) * 18.0) + sway * 0.8
			var my := by - 6.0 - float(m) * 3.0
			var m_len := 34.0 + float((idx + m) % 3) * 18.0
			var m_sway := sin(_time * 2.2 + float(idx + m)) * 7.0
			draw_line(Vector2(mx, my), Vector2(mx + m_sway, my + m_len), Color(0.07, 0.17, 0.23, 0.68), 2.0, true)

		# Drifting twilight bioluminescent forest spores
		var sx := tx + sin(_time * 0.8 + float(idx)) * 28.0
		var sy := vp.y * (0.5 + (h - 0.5) * 0.26) + cos(_time * 1.1 + float(idx)) * 14.0
		var sc: Color = spore_cols[absi(idx) % 3]
		sc.a = clampf(0.42 * flow_glow, 0.2, 0.85)
		draw_circle(Vector2(sx, sy), 2.4 + h * 1.5, sc)

func _draw_mist_band(vp: Vector2) -> void:
	draw_rect(Rect2(0.0, vp.y * 0.58, vp.x, vp.y * 0.42), Color(0.075, 0.19, 0.27, 0.22 + lightning_flash * 0.08))

func _draw_foreground_silhouettes(vp: Vector2) -> void:
	var spacing := 520.0
	var parallax := camera_x * 1.38
	var offset := fposmod(parallax, spacing)
	var first_idx := int(floor(parallax / spacing))
	var col := Color(0.008, 0.016, 0.039, 0.96)
	var count := int(ceil(vp.x / spacing)) + 2
	for i in range(-1, count):
		var idx := first_idx + i
		var fx := float(i) * spacing - offset
		var sway := sin(_time * 2.5 + float(idx)) * 6.0
		var reed := PackedVector2Array([
			Vector2(fx - 45.0, vp.y + 10.0),
			Vector2(fx - 12.0 + sway, vp.y - 64.0),
			Vector2(fx + 8.0 + sway, vp.y - 84.0),
			Vector2(fx + 52.0, vp.y + 10.0)
		])
		draw_colored_polygon(reed, col)
		if idx % 2 == 0:
			var top_b := PackedVector2Array([
				Vector2(fx + 140.0, -10.0),
				Vector2(fx + 185.0 + sway, 46.0),
				Vector2(fx + 235.0 + sway, 62.0),
				Vector2(fx + 215.0, -10.0)
			])
			draw_colored_polygon(top_b, col)

func _draw_rain(vp: Vector2) -> void:
	var slant := -0.22 - minf(0.28, speed_px / 2600.0)
	var player_screen_x := vp.x * 0.34
	for r in _rain:
		var near_player: bool = r["depth"] == 2 and absf(r["x"] - player_screen_x) < 165.0
		var col := active_color if near_player else Color(0.72, 0.84, 0.94, 1.0)
		col.a = r["alpha"] * (0.72 if near_player else 1.0)
		var p0 := Vector2(r["x"], r["y"])
		var p1 := p0 + Vector2(r["len"] * slant, r["len"])
		draw_line(p0, p1, col, 1.4 if r["depth"] == 2 else 1.0, true)
