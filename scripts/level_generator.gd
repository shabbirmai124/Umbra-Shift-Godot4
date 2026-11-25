extends Node2D
class_name LevelGenerator

## High-Performance Chunk-Based Procedural Level Generator & Luminous Mossy Terrain Renderer
## Optimized for Godot 4 GDScript:
## - Pre-bakes ALL static terrain strata, turf caps, and river stones ONCE on chunk creation
## - Viewport frustum culling skips off-screen chunks, segments, flora, and obstacles
## - Batches all wind-swaying grass tufts into 3 draw_multiline() calls per frame instead of 180+ polylines

const PUDDLE_REFLECT_SHADER: Shader = preload("res://shaders/puddle_reflect.gdshader")

const COL_GAP_MIST: Color = Color(0.06, 0.24, 0.34, 0.44)
const COL_EARTH_BASE: Color = Color(0.068, 0.105, 0.148, 1.0)
const COL_EARTH_MID: Color = Color(0.105, 0.148, 0.195, 0.94)
const COL_EARTH_SUB: Color = Color(0.135, 0.195, 0.215, 0.96)
const COL_STONE_FILL: Color = Color(0.18, 0.235, 0.285, 0.92)
const COL_STONE_RIM: Color = Color(0.48, 0.68, 0.74, 0.55)
const COL_TURF: Color = Color(0.14, 0.44, 0.36, 1.0)
const COL_TURF_RIM: Color = Color(0.52, 0.96, 0.78, 0.92)
const COL_GRASS_A: Color = Color(0.24, 0.68, 0.50, 0.85)
const COL_GRASS_B: Color = Color(0.38, 0.86, 0.68, 0.86)
const COL_GRASS_C: Color = Color(0.56, 0.98, 0.82, 0.68)
const COL_PUDDLE_BASE: Color = Color(0.64, 0.90, 1.0, 0.58)

var chunks: Array[Dictionary] = []
var reactive_flora: ReactiveFlora = null

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _cursor_x: float = -600.0
var _cursor_y: float = 0.0
var _chunk_id: int = 0
var _time: float = 0.0
var _player_pos: Vector2 = Vector2.ZERO
var _active_color: Color = Color(0.31, 1.0, 0.69, 1.0)
var _flow_glow: float = 1.0
var _puddle_rects: Array[ColorRect] = []
var _hazard_lights: Array[PointLight2D] = []
var _occluders: Array[LightOccluder2D] = []

# Reusable batched grass line buffers
var _grass_lines_a: PackedVector2Array = PackedVector2Array()
var _grass_lines_b: PackedVector2Array = PackedVector2Array()
var _grass_lines_c: PackedVector2Array = PackedVector2Array()
var _gap_wave_pts: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	for _i in range(6):
		var rect: ColorRect = ColorRect.new()
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = PUDDLE_REFLECT_SHADER
		rect.material = mat
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.z_index = 2
		rect.visible = false
		add_child(rect)
		_puddle_rects.append(rect)

	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0.0)])
	var ltex: GradientTexture2D = GradientTexture2D.new()
	ltex.gradient = grad
	ltex.width = 128
	ltex.height = 128
	ltex.fill = GradientTexture2D.FILL_RADIAL
	ltex.fill_from = Vector2(0.5, 0.5)
	ltex.fill_to = Vector2(0.5, 0.0)
	for _i in range(4):
		var lt: PointLight2D = PointLight2D.new()
		lt.texture = ltex
		lt.energy = 0.0
		lt.enabled = false
		lt.range_item_cull_mask = 1
		add_child(lt)
		_hazard_lights.append(lt)

	for _i in range(4):
		var occ: LightOccluder2D = LightOccluder2D.new()
		occ.occluder = OccluderPolygon2D.new()
		occ.visible = false
		add_child(occ)
		_occluders.append(occ)

	if chunks.is_empty():
		reset_world(20261124)

func reset_world(seed_val: int = 20261124) -> void:
	_rng.seed = seed_val
	chunks.clear()
	_cursor_x = -600.0
	_cursor_y = 0.0
	_chunk_id = 0
	for _i in range(5):
		chunks.append(_generate_chunk(0.0))
	queue_redraw()

func update_world(dt: float, horizon_x: float, cutoff_x: float, difficulty: float, player_pos: Vector2, active_col: Color, flow_mult: int) -> void:
	_time += dt
	_player_pos = player_pos
	_active_color = active_col
	_flow_glow = 1.0 + float(flow_mult - 1) * 0.08

	while chunks.is_empty() or float(chunks[chunks.size() - 1]["x_end"]) < horizon_x:
		var nxt: Dictionary = _generate_chunk(difficulty)
		if validate_chunk(nxt):
			chunks.append(nxt)
	while chunks.size() > 3 and float(chunks[0]["x_end"]) < cutoff_x:
		chunks.pop_front()
	_sync_puddle_shaders()
	_sync_hazard_lights()
	_sync_light_occluders()
	queue_redraw()

func _sync_light_occluders() -> void:
	var used: int = 0
	var min_x: float = _player_pos.x - 360.0
	var max_x: float = _player_pos.x + 720.0
	for chunk in chunks:
		if float(chunk["x_end"]) < min_x or float(chunk["x_start"]) > max_x:
			continue
		var obs_list: Array = chunk["obstacles"]
		for obs_item in obs_list:
			var obs: Dictionary = obs_item
			if used >= _occluders.size():
				break
			if not bool(obs["intact"]):
				continue
			var r: Rect2 = obs["rect"]
			var cx: float = r.get_center().x
			if cx < min_x or cx > max_x:
				continue
			var poly: PackedVector2Array = ObstacleRenderer.get_occluder_polygon(obs)
			if poly.size() < 3:
				continue
			var occ: LightOccluder2D = _occluders[used]
			used += 1
			occ.visible = true
			occ.occluder.polygon = poly
	for i in range(used, _occluders.size()):
		_occluders[i].visible = false

func _sync_hazard_lights() -> void:
	var used: int = 0
	var min_x: float = _player_pos.x - 420.0
	var max_x: float = _player_pos.x + 1100.0
	for chunk in chunks:
		if float(chunk["x_end"]) < min_x or float(chunk["x_start"]) > max_x:
			continue
		var obs_list: Array = chunk["obstacles"]
		for obs_item in obs_list:
			var obs: Dictionary = obs_item
			if used >= _hazard_lights.size():
				break
			if not bool(obs["intact"]):
				continue
			var k: String = String(obs["kind"])
			if k != "monolith" and k != "crystal_wall" and k != "spore_draft" and k != "root_tunnel":
				continue
			var r: Rect2 = obs["rect"]
			var cx: float = r.get_center().x
			if cx < min_x or cx > max_x:
				continue
			var lt: PointLight2D = _hazard_lights[used]
			used += 1
			lt.enabled = true
			lt.position = r.get_center()
			if k == "spore_draft":
				lt.color = Color(0.10, 0.92, 1.0, 1.0)
				lt.energy = 0.78 * clampf(_flow_glow, 0.85, 1.35)
				lt.texture_scale = 2.0
			elif k == "root_tunnel":
				lt.color = Color(0.36, 1.0, 0.74, 1.0)
				lt.energy = 0.62 * clampf(_flow_glow, 0.85, 1.3)
				lt.texture_scale = 1.45
			else:
				lt.color = Color(1.0, 0.62, 0.08, 1.0)
				lt.energy = 0.94 * clampf(_flow_glow, 0.85, 1.4)
				lt.texture_scale = 1.55
	for i in range(used, _hazard_lights.size()):
		_hazard_lights[i].enabled = false
		_hazard_lights[i].energy = 0.0

func _sync_puddle_shaders() -> void:
	var used: int = 0
	var min_x: float = _player_pos.x - 650.0
	var max_x: float = _player_pos.x + 1250.0
	for chunk in chunks:
		if float(chunk["x_end"]) < min_x or float(chunk["x_start"]) > max_x:
			continue
		var seg_list: Array = chunk["segments"]
		for seg_item in seg_list:
			var seg: Dictionary = seg_item
			if used >= _puddle_rects.size():
				break
			if not bool(seg["has_puddle"]) or bool(seg["is_gap"]):
				continue
			var px0: float = float(seg["p_start"])
			var px1: float = float(seg["p_end"])
			if px1 < min_x or px0 > max_x:
				continue
			var py: float = lerpf(float(seg["y_start"]), float(seg["y_end"]), 0.5)
			var rect: ColorRect = _puddle_rects[used]
			used += 1
			rect.visible = true
			rect.position = Vector2(px0, py - 2.0)
			rect.size = Vector2(maxf(24.0, px1 - px0), 12.0)
			var mat: ShaderMaterial = rect.material as ShaderMaterial
			if mat != null:
				var span: float = maxf(1.0, px1 - px0)
				var u: float = (_player_pos.x - px0) / span
				var dist: float = absf(_player_pos.x - (px0 + px1) * 0.5)
				var prox: float = clampf(1.0 - dist / 340.0, 0.0, 1.0)
				mat.set_shader_parameter("glow_color", _active_color)
				mat.set_shader_parameter("player_u", clampf(u, -0.5, 1.5))
				mat.set_shader_parameter("proximity_glow", prox * clampf(_flow_glow * 0.76, 0.55, 1.0))
				mat.set_shader_parameter("rain_intensity", 0.78)
	for i in range(used, _puddle_rects.size()):
		_puddle_rects[i].visible = false

func sample_ground(x: float) -> Dictionary:
	for chunk in chunks:
		if x < float(chunk["x_start"]) or x > float(chunk["x_end"]):
			continue
		var seg_list: Array = chunk["segments"]
		for seg_item in seg_list:
			var seg: Dictionary = seg_item
			var sx0: float = float(seg["x_start"])
			var sx1: float = float(seg["x_end"])
			if x >= sx0 and x <= sx1:
				if bool(seg["is_gap"]):
					return {}
				var sy0: float = float(seg["y_start"])
				var sy1: float = float(seg["y_end"])
				var span: float = maxf(1.0, sx1 - sx0)
				var t: float = (x - sx0) / span
				var st: float = 0.5 - 0.5 * cos(t * PI)
				var y: float = lerpf(sy0, sy1, st)
				var slope: float = (sy1 - sy0) / span
				return {"y": y, "slope": slope}
	return {"y": 0.0, "slope": 0.0}

func sample_elevated_platform(x: float, prev_y: float, curr_y: float, vy: float) -> Dictionary:
	if vy < 0.0:
		return {}
	for chunk in chunks:
		if x + 28.0 < float(chunk["x_start"]) or x - 28.0 > float(chunk["x_end"]):
			continue
		var obs_list: Array = chunk["obstacles"]
		for obs_item in obs_list:
			var obs: Dictionary = obs_item
			var k: String = String(obs["kind"])
			if k != "high_platform" and k != "mossy_ledge":
				continue
			var r: Rect2 = obs["rect"]
			if x + 18.0 > r.position.x and x - 18.0 < r.end.x:
				if prev_y <= r.position.y + 18.0 and curr_y >= r.position.y - 4.0:
					return {"y": r.position.y, "obs": obs}
	return {}

func is_under_root_tunnel(x: float) -> bool:
	for chunk in chunks:
		if x + 36.0 < float(chunk["x_start"]) or x - 36.0 > float(chunk["x_end"]):
			continue
		var obs_list: Array = chunk["obstacles"]
		for obs_item in obs_list:
			var obs: Dictionary = obs_item
			if String(obs["kind"]) == "root_tunnel":
				var r: Rect2 = obs["rect"]
				if x + 18.0 > r.position.x and x - 18.0 < r.end.x:
					return true
	return false

func validate_chunk(chunk: Dictionary) -> bool:
	var seg_list: Array = chunk["segments"]
	var obs_list: Array = chunk["obstacles"]
	for seg_item in seg_list:
		var seg: Dictionary = seg_item
		var seg_x0: float = float(seg["x_start"])
		var seg_x1: float = float(seg["x_end"])
		if bool(seg["is_gap"]) and (seg_x1 - seg_x0) > 260.0:
			var has_draft: bool = false
			for obs_item in obs_list:
				var obs: Dictionary = obs_item
				if String(obs["kind"]) == "spore_draft":
					var r: Rect2 = obs["rect"]
					if r.end.x > seg_x0 and r.position.x < seg_x1:
						has_draft = true
						break
			if not has_draft:
				return false
	return true

func _bake_segment_geometry(seg_x0: float, seg_x1: float, seg_y0: float, seg_y1: float, seg_seed: float) -> Dictionary:
	# Pre-bake all static geology polygons ONCE per segment (eliminates hundreds of per-frame allocations!)
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = maxi(8, int((seg_x1 - seg_x0) / 40.0))
	pts.resize(steps + 1)
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var x: float = lerpf(seg_x0, seg_x1, t)
		var y: float = lerpf(seg_y0, seg_y1, 0.5 - 0.5 * cos(t * PI)) + sin(x * 0.045 + seg_seed) * 3.0 * sin(t * PI)
		pts[i] = Vector2(x, y)

	var base_poly: PackedVector2Array = pts.duplicate()
	base_poly.append(Vector2(seg_x1, 480.0))
	base_poly.append(Vector2(seg_x0, 480.0))

	var n: int = pts.size()
	var mid_strata: PackedVector2Array = PackedVector2Array()
	mid_strata.resize(n * 2)
	var sub_poly: PackedVector2Array = PackedVector2Array()
	sub_poly.resize(n * 2)
	var turf_poly: PackedVector2Array = PackedVector2Array()
	turf_poly.resize(n * 2)
	for i in range(n):
		var sp: Vector2 = pts[i]
		mid_strata[i] = sp + Vector2(0.0, 34.0 + sin(sp.x * 0.024 + seg_seed) * 9.0)
		mid_strata[n * 2 - 1 - i] = sp + Vector2(0.0, 96.0 + cos(sp.x * 0.019 + seg_seed) * 12.0)
		sub_poly[i] = sp + Vector2(0.0, 10.0)
		sub_poly[n * 2 - 1 - i] = sp + Vector2(0.0, 44.0 + sin(sp.x * 0.038 + seg_seed) * 8.0)
		turf_poly[i] = sp + Vector2(0.0, -1.5)
		turf_poly[n * 2 - 1 - i] = sp + Vector2(0.0, 15.0 + sin(sp.x * 0.08 + seg_seed) * 3.5)

	var stone_polys: Array[PackedVector2Array] = []
	var stone_rims: Array[PackedVector2Array] = []
	for i in range(1, n - 1, 2):
		var rp: Vector2 = pts[i]
		var st_w: float = 15.0 + fposmod(absf(sin(rp.x * 0.17 + seg_seed) * 19.0), 10.0)
		var st_h: float = 8.0 + fposmod(absf(cos(rp.x * 0.13) * 11.0), 5.0)
		var st_y: float = 26.0 + float(i % 3) * 12.0
		stone_polys.append(PackedVector2Array([
			rp + Vector2(-st_w, st_y),
			rp + Vector2(-st_w * 0.55, st_y - st_h),
			rp + Vector2(st_w * 0.45, st_y - st_h * 0.9),
			rp + Vector2(st_w, st_y + 1.0),
			rp + Vector2(st_w * 0.45, st_y + st_h * 0.8),
			rp + Vector2(-st_w * 0.5, st_y + st_h * 0.7)
		]))
		stone_rims.append(PackedVector2Array([
			rp + Vector2(-st_w * 0.75, st_y - st_h * 0.4),
			rp + Vector2(0.0, st_y - st_h * 0.95),
			rp + Vector2(st_w * 0.65, st_y - st_h * 0.45)
		]))

	return {
		"pts": pts,
		"base_poly": base_poly,
		"mid_strata": mid_strata,
		"sub_poly": sub_poly,
		"turf_poly": turf_poly,
		"stone_polys": stone_polys,
		"stone_rims": stone_rims
	}

func _push_ground(segs: Array, decs: Array, length: float, end_y: float) -> Dictionary:
	var x0: float = _cursor_x
	var x1: float = x0 + length
	var y0: float = _cursor_y
	var y1: float = clampf(end_y, -72.0, 48.0)
	var has_puddle: bool = absf(y1 - y0) < 16.0 and length >= 240.0 and _rng.randf() < 0.62
	var p_len: float = 0.0
	var p_start: float = 0.0
	if has_puddle:
		p_len = _rng.randf_range(95.0, 175.0)
		p_start = x0 + _rng.randf_range(40.0, maxf(45.0, length - p_len - 40.0))
	var seg_seed: float = _rng.randf() * 100.0
	var baked: Dictionary = _bake_segment_geometry(x0, x1, y0, y1, seg_seed)
	segs.append({
		"x_start": x0, "x_end": x1, "y_start": y0, "y_end": y1,
		"is_gap": false, "has_puddle": has_puddle, "p_start": p_start, "p_end": p_start + p_len,
		"seed": seg_seed,
		"baked": baked
	})
	var flora_colors: Array[Color] = [Color(0.36, 1.0, 0.74), Color(0.14, 0.92, 1.0), Color(1.0, 0.68, 0.14)]
	for _i in range(maxi(2, int(length / 155.0))):
		var fx: float = x0 + _rng.randf_range(32.0, maxf(38.0, length - 32.0))
		var t: float = (fx - x0) / maxf(1.0, length)
		var fy: float = lerpf(y0, y1, 0.5 - 0.5 * cos(t * PI))
		var fkind: String = "fern" if _rng.randf() < 0.72 else "mushroom"
		decs.append({
			"kind": fkind,
			"x": fx,
			"y": fy,
			"scale": _rng.randf_range(0.80, 1.32),
			"color": flora_colors[_rng.randi() % 3],
			"phase": _rng.randf() * TAU,
			"bend": 0.0,
			"bend_v": 0.0
		})
	_cursor_x = x1
	_cursor_y = y1
	return {"x0": x0, "x1": x1, "y0": y0, "y1": y1}

func _push_gap(segs: Array, width: float) -> Dictionary:
	var x0: float = _cursor_x
	var x1: float = x0 + width
	segs.append({"x_start": x0, "x_end": x1, "y_start": _cursor_y, "y_end": _cursor_y, "is_gap": true, "has_puddle": false, "p_start": 0.0, "p_end": 0.0, "seed": 0.0})
	_cursor_x = x1
	return {"x0": x0, "x1": x1}

func _add_totem(decs: Array, x: float, y: float, form_id: int) -> void:
	var cols: Array[Color] = [Color(0.36, 1.0, 0.74), Color(0.14, 0.92, 1.0), Color(1.0, 0.66, 0.12)]
	decs.append({"kind": "totem", "x": x, "y": y, "scale": 1.0, "color": cols[clampi(form_id, 0, 2)], "phase": 0.0, "bend": 0.0, "bend_v": 0.0})

func _generate_chunk(difficulty: float) -> Dictionary:
	var id: int = _chunk_id
	_chunk_id += 1
	var x_start: float = _cursor_x
	var segs: Array = []
	var obs: Array = []
	var decs: Array = []

	if id == 0:
		_push_ground(segs, decs, 950.0, 0.0)
		_push_ground(segs, decs, 620.0, -14.0)
		_push_ground(segs, decs, 680.0, 0.0)
	elif id == 1:
		var g1: Dictionary = _push_ground(segs, decs, 620.0, 0.0)
		var g1_x0: float = float(g1["x0"])
		_add_totem(decs, g1_x0 + 85.0, 0.0, 0)
		obs.append({"kind": "root_tunnel", "rect": Rect2(g1_x0 + 270.0, -122.0, 165.0, 92.0), "intact": true, "cleared": false, "form": 0})
		var g2: Dictionary = _push_ground(segs, decs, 540.0, -10.0)
		var g2_x0: float = float(g2["x0"])
		var g2_y1: float = float(g2["y1"])
		obs.append({"kind": "thorn_bramble", "rect": Rect2(g2_x0 + 190.0, g2_y1 - 34.0, 92.0, 34.0), "intact": true, "cleared": false, "form": 0})
		obs.append({"kind": "mossy_ledge", "rect": Rect2(g2_x0 + 175.0, g2_y1 - 92.0, 145.0, 20.0), "intact": true, "cleared": false, "form": 0})
	elif id == 2:
		var g1: Dictionary = _push_ground(segs, decs, 420.0, 24.0)
		_add_totem(decs, float(g1["x0"]) + 90.0, float(g1["y0"]), 2)
		var g2: Dictionary = _push_ground(segs, decs, 600.0, 14.0)
		obs.append({"kind": "monolith", "rect": Rect2(float(g2["x0"]) + 150.0, float(g2["y1"]) - 110.0, 64.0, 110.0), "intact": true, "cleared": false, "form": 2})
	elif id == 3:
		var g1: Dictionary = _push_ground(segs, decs, 360.0, -8.0)
		_add_totem(decs, float(g1["x0"]) + 100.0, float(g1["y0"]), 1)
		var gap: Dictionary = _push_gap(segs, 390.0)
		var gap_x0: float = float(gap["x0"])
		obs.append({"kind": "spore_draft", "rect": Rect2(gap_x0 + 100.0, _cursor_y - 300.0, 180.0, 380.0), "intact": true, "cleared": false, "form": 1})
		obs.append({"kind": "high_platform", "rect": Rect2(gap_x0 + 235.0, _cursor_y - 130.0, 185.0, 20.0), "intact": true, "cleared": false, "form": 1})
		_push_ground(segs, decs, 540.0, 0.0)
	else:
		var pick: int = _rng.randi() % 4
		if pick == 0:
			var g1: Dictionary = _push_ground(segs, decs, 520.0, 22.0)
			var g1_x0: float = float(g1["x0"])
			_add_totem(decs, g1_x0 + 75.0, float(g1["y0"]), 2)
			obs.append({"kind": "monolith", "rect": Rect2(g1_x0 + 250.0, float(g1["y1"]) - 112.0, 64.0, 112.0), "intact": true, "cleared": false, "form": 2})
			var g2: Dictionary = _push_ground(segs, decs, 420.0, -6.0)
			obs.append({"kind": "thorn_bramble", "rect": Rect2(float(g2["x0"]) + 165.0, float(g2["y1"]) - 36.0, 96.0, 36.0), "intact": true, "cleared": false, "form": 0})
			var gap: Dictionary = _push_gap(segs, 420.0 + difficulty * 115.0)
			obs.append({"kind": "spore_draft", "rect": Rect2(float(gap["x0"]) + 115.0, _cursor_y - 300.0, 180.0, 380.0), "intact": true, "cleared": false, "form": 1})
			_push_ground(segs, decs, 460.0, 0.0)
		elif pick == 1:
			var g1: Dictionary = _push_ground(segs, decs, 780.0, 26.0)
			var g1_x0: float = float(g1["x0"])
			var g1_y1: float = float(g1["y1"])
			_add_totem(decs, g1_x0 + 75.0, float(g1["y0"]), 2)
			obs.append({"kind": "thorn_bramble", "rect": Rect2(g1_x0 + 180.0, g1_y1 - 38.0, 150.0, 38.0), "intact": true, "cleared": false, "form": 2})
			obs.append({"kind": "crystal_wall", "rect": Rect2(g1_x0 + 470.0, g1_y1 - 124.0, 62.0, 124.0), "intact": true, "cleared": false, "form": 2})
			obs.append({"kind": "fallen_log", "rect": Rect2(g1_x0 + 650.0, g1_y1 - 68.0, 74.0, 68.0), "intact": true, "cleared": false, "form": 2})
			_push_ground(segs, decs, 360.0, 0.0)
		elif pick == 2:
			var g1: Dictionary = _push_ground(segs, decs, 340.0, -10.0)
			_add_totem(decs, float(g1["x0"]) + 85.0, float(g1["y0"]), 1)
			var gap: Dictionary = _push_gap(segs, 480.0 + difficulty * 130.0)
			var gap_x0: float = float(gap["x0"])
			var gap_x1: float = float(gap["x1"])
			obs.append({"kind": "spore_draft", "rect": Rect2(gap_x0 + 85.0, _cursor_y - 310.0, 175.0, 390.0), "intact": true, "cleared": false, "form": 1})
			obs.append({"kind": "high_platform", "rect": Rect2(gap_x0 + 215.0, _cursor_y - 148.0, 180.0, 20.0), "intact": true, "cleared": false, "form": 1})
			obs.append({"kind": "spore_draft", "rect": Rect2(gap_x1 - 215.0, _cursor_y - 310.0, 165.0, 390.0), "intact": true, "cleared": false, "form": 1})
			var g2: Dictionary = _push_ground(segs, decs, 680.0, 0.0)
			obs.append({"kind": "root_tunnel", "rect": Rect2(float(g2["x0"]) + 275.0, float(g2["y1"]) - 122.0, 180.0, 92.0), "intact": true, "cleared": false, "form": 0})
		else:
			var g1: Dictionary = _push_ground(segs, decs, 460.0, 0.0)
			var g1_x0: float = float(g1["x0"])
			var g1_y1: float = float(g1["y1"])
			_add_totem(decs, g1_x0 + 80.0, float(g1["y0"]), 0)
			obs.append({"kind": "thorn_bramble", "rect": Rect2(g1_x0 + 210.0, g1_y1 - 36.0, 115.0, 36.0), "intact": true, "cleared": false, "form": 0})
			obs.append({"kind": "mossy_ledge", "rect": Rect2(g1_x0 + 195.0, g1_y1 - 92.0, 165.0, 20.0), "intact": true, "cleared": false, "form": 0})
			_push_gap(segs, 180.0 + difficulty * 35.0)
			var g2: Dictionary = _push_ground(segs, decs, 600.0, -12.0)
			obs.append({"kind": "root_tunnel", "rect": Rect2(float(g2["x0"]) + 235.0, float(g2["y1"]) - 124.0, 180.0, 94.0), "intact": true, "cleared": false, "form": 0})

	return {"id": id, "x_start": x_start, "x_end": _cursor_x, "segments": segs, "obstacles": obs, "decorations": decs}

func _draw() -> void:
	# Frustum bounds centered around player/camera (generous margin for zoomed-out Moth flight)
	var min_x: float = _player_pos.x - 860.0
	var max_x: float = _player_pos.x + 1320.0

	_grass_lines_a.clear()
	_grass_lines_b.clear()
	_grass_lines_c.clear()

	for chunk in chunks:
		if float(chunk["x_end"]) < min_x or float(chunk["x_start"]) > max_x:
			continue
		var seg_list: Array = chunk["segments"]
		for seg_item in seg_list:
			var seg: Dictionary = seg_item
			var seg_x0: float = float(seg["x_start"])
			var seg_x1: float = float(seg["x_end"])
			if seg_x1 < min_x or seg_x0 > max_x:
				continue

			if bool(seg["is_gap"]):
				var gy: float = float(seg["y_start"])
				draw_rect(Rect2(seg_x0, gy + 16.0, seg_x1 - seg_x0, 290.0), COL_GAP_MIST)
				var wsteps: int = maxi(6, int((seg_x1 - seg_x0) / 48.0))
				_gap_wave_pts.resize(wsteps + 1)
				for wi in range(wsteps + 1):
					var wt: float = float(wi) / float(wsteps)
					var wx: float = lerpf(seg_x0, seg_x1, wt)
					_gap_wave_pts[wi] = Vector2(wx, gy + 16.0 + sin(_time * 2.8 + wx * 0.03) * 6.0)
				draw_polyline(_gap_wave_pts, Color(0.16, 0.92, 1.0, 0.34 * _flow_glow), 3.4, true)
				continue

			# Draw pre-baked static geology polygons directly (zero geometry rebuild per frame!)
			var baked: Dictionary = seg["baked"]
			var pts: PackedVector2Array = baked["pts"]
			draw_colored_polygon(baked["base_poly"], COL_EARTH_BASE)
			draw_colored_polygon(baked["mid_strata"], COL_EARTH_MID)
			draw_colored_polygon(baked["sub_poly"], COL_EARTH_SUB)

			var stone_polys: Array[PackedVector2Array] = baked["stone_polys"]
			var stone_rims: Array[PackedVector2Array] = baked["stone_rims"]
			for si in range(stone_polys.size()):
				draw_colored_polygon(stone_polys[si], COL_STONE_FILL)
				draw_polyline(stone_rims[si], COL_STONE_RIM, 1.6, true)

			draw_colored_polygon(baked["turf_poly"], COL_TURF)
			draw_polyline(pts, COL_TURF_RIM, 3.4, true)

			# Collect visible swaying grass tufts for single batched draw_multiline() pass
			var t_sway: float = _time * 2.8
			for i in range(pts.size()):
				var gp: Vector2 = pts[i]
				if gp.x < min_x or gp.x > max_x:
					continue
				var gsway: float = sin(t_sway + gp.x * 0.05) * 3.4
				_grass_lines_a.append(gp + Vector2(-5.0, 1.0))
				_grass_lines_a.append(gp + Vector2(-8.2 + gsway, -10.0))
				_grass_lines_b.append(gp + Vector2(1.0, 1.0))
				_grass_lines_b.append(gp + Vector2(3.6 + gsway * 1.1, -11.5))
				if i % 2 == 0:
					_grass_lines_c.append(gp + Vector2(7.0, 1.5))
					_grass_lines_c.append(gp + Vector2(11.5 + gsway * 0.8, -7.2))

			if bool(seg["has_puddle"]):
				var px0: float = float(seg["p_start"])
				var px1: float = float(seg["p_end"])
				var py: float = lerpf(float(seg["y_start"]), float(seg["y_end"]), 0.5)
				draw_line(Vector2(px0, py + 2.0), Vector2(px1, py + 2.0), COL_PUDDLE_BASE, 4.4, true)

		if reactive_flora != null:
			reactive_flora.draw_chunk_flora(self, chunk, min_x, max_x)

		var obs_list: Array = chunk["obstacles"]
		for obs_item in obs_list:
			var obs: Dictionary = obs_item
			var r: Rect2 = obs["rect"]
			if r.end.x < min_x or r.position.x > max_x:
				continue
			ObstacleRenderer.draw_obstacle(self, obs, _time, _flow_glow)

	if not _grass_lines_a.is_empty():
		draw_multiline(_grass_lines_a, COL_GRASS_A, 1.8)
	if not _grass_lines_b.is_empty():
		draw_multiline(_grass_lines_b, COL_GRASS_B, 1.6)
	if not _grass_lines_c.is_empty():
		draw_multiline(_grass_lines_c, COL_GRASS_C, 1.3)
