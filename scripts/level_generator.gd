extends Node2D
class_name LevelGenerator

## Chunk-based procedural level generator & organic mossy terrain renderer
## Pacing:
##   0m - 150m (Onboarding): Fox, Pangolin, Moth introduced cleanly with generous spacing.
##   150m - 500m (Flow State): Faster 2-form combos (Pangolin Smash -> Moth Glide, etc.).
##   500m+ (Mastery Speedrun): High-velocity 3-form combo sequences & downhill ramps.
## Includes clearability validation, reactive bending ferns, reflective puddles, and diegetic waystones.

const WATER_REFLECT_SHADER := preload("res://shaders/water_reflect.gdshader")

var chunks: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _cursor_x: float = -600.0
var _cursor_y: float = 0.0
var _chunk_id: int = 0
var _time: float = 0.0
var _player_pos: Vector2 = Vector2.ZERO
var _active_color: Color = Color(0.31, 1.0, 0.69, 1.0)
var _flow_glow: float = 1.0
var _puddle_rects: Array[ColorRect] = []

func _ready() -> void:
	for _i in range(6):
		var rect := ColorRect.new()
		var mat := ShaderMaterial.new()
		mat.shader = WATER_REFLECT_SHADER
		rect.material = mat
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.z_index = 2
		rect.visible = false
		add_child(rect)
		_puddle_rects.append(rect)

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

	while chunks.is_empty() or chunks[-1]["x_end"] < horizon_x:
		var nxt := _generate_chunk(difficulty)
		if validate_chunk(nxt):
			chunks.append(nxt)
	while chunks.size() > 3 and chunks[0]["x_end"] < cutoff_x:
		chunks.pop_front()
	_sync_puddle_shaders()
	queue_redraw()

func _sync_puddle_shaders() -> void:
	var used := 0
	for chunk in chunks:
		for seg in chunk["segments"]:
			if used >= _puddle_rects.size():
				break
			if not seg["has_puddle"] or seg["is_gap"]:
				continue
			var px0: float = seg["p_start"]
			var px1: float = seg["p_end"]
			if px1 < _player_pos.x - 650.0 or px0 > _player_pos.x + 1250.0:
				continue
			var py := lerpf(seg["y_start"], seg["y_end"], 0.5)
			var rect := _puddle_rects[used]
			used += 1
			rect.visible = true
			rect.position = Vector2(px0, py - 2.0)
			rect.size = Vector2(maxf(20.0, px1 - px0), 10.0)
			if rect.material is ShaderMaterial:
				var mat: ShaderMaterial = rect.material
				var span := maxf(1.0, px1 - px0)
				var u := (_player_pos.x - px0) / span
				var dist := absf(_player_pos.x - (px0 + px1) * 0.5)
				var prox := clampf(1.0 - dist / 320.0, 0.0, 1.0)
				mat.set_shader_parameter("glow_color", _active_color)
				mat.set_shader_parameter("player_u", clampf(u, -0.5, 1.5))
				mat.set_shader_parameter("proximity_glow", prox * clampf(_flow_glow * 0.72, 0.55, 1.0))
				mat.set_shader_parameter("rain_intensity", 0.78)
	for i in range(used, _puddle_rects.size()):
		_puddle_rects[i].visible = false

func sample_ground(x: float) -> Dictionary:
	for chunk in chunks:
		if x < chunk["x_start"] or x > chunk["x_end"]:
			continue
		for seg in chunk["segments"]:
			if x >= seg["x_start"] and x <= seg["x_end"]:
				if seg["is_gap"]:
					return {}
				var span := maxf(1.0, seg["x_end"] - seg["x_start"])
				var t := (x - seg["x_start"]) / span
				var st := 0.5 - 0.5 * cos(t * PI)
				var y := lerpf(seg["y_start"], seg["y_end"], st)
				var slope := (seg["y_end"] - seg["y_start"]) / span
				return {"y": y, "slope": slope}
	return {"y": 0.0, "slope": 0.0}

func sample_elevated_platform(x: float, prev_y: float, curr_y: float, vy: float) -> Dictionary:
	if vy < 0.0:
		return {}
	for chunk in chunks:
		if x + 24.0 < chunk["x_start"] or x - 24.0 > chunk["x_end"]:
			continue
		for obs in chunk["obstacles"]:
			var k: String = obs["kind"]
			if k != "high_platform" and k != "mossy_ledge":
				continue
			var r: Rect2 = obs["rect"]
			if x + 16.0 > r.position.x and x - 16.0 < r.end.x:
				if prev_y <= r.position.y + 14.0 and curr_y >= r.position.y:
					return {"y": r.position.y, "obs": obs}
	return {}

func is_under_root_tunnel(x: float) -> bool:
	for chunk in chunks:
		if x + 36.0 < chunk["x_start"] or x - 36.0 > chunk["x_end"]:
			continue
		for obs in chunk["obstacles"]:
			if obs["kind"] == "root_tunnel":
				var r: Rect2 = obs["rect"]
				if x + 18.0 > r.position.x and x - 18.0 < r.end.x:
					return true
	return false

func validate_chunk(chunk: Dictionary) -> bool:
	# Verify wide chasms (> 260px) always contain a Moth spore-draft
	for seg in chunk["segments"]:
		if seg["is_gap"] and (seg["x_end"] - seg["x_start"]) > 260.0:
			var has_draft := false
			for obs in chunk["obstacles"]:
				if obs["kind"] == "spore_draft":
					var r: Rect2 = obs["rect"]
					if r.end.x > seg["x_start"] and r.position.x < seg["x_end"]:
						has_draft = true
						break
			if not has_draft:
				return false
	return true

func _push_ground(segs: Array, decs: Array, length: float, end_y: float) -> Dictionary:
	var x0 := _cursor_x
	var x1 := x0 + length
	var y0 := _cursor_y
	var y1 := clampf(end_y, -72.0, 48.0)
	var has_puddle := absf(y1 - y0) < 16.0 and length >= 240.0 and _rng.randf() < 0.58
	var p_len := _rng.randf_range(90.0, 165.0) if has_puddle else 0.0
	var p_start := x0 + _rng.randf_range(40.0, maxf(45.0, length - p_len - 40.0)) if has_puddle else 0.0
	segs.append({
		"x_start": x0, "x_end": x1, "y_start": y0, "y_end": y1,
		"is_gap": false, "has_puddle": has_puddle, "p_start": p_start, "p_end": p_start + p_len,
		"seed": _rng.randf() * 100.0
	})
	var flora_colors := [Color(0.31, 1.0, 0.69), Color(0.0, 0.9, 1.0), Color(1.0, 0.62, 0.0)]
	for _i in range(maxi(1, int(length / 180.0))):
		var fx := x0 + _rng.randf_range(35.0, maxf(40.0, length - 35.0))
		var t := (fx - x0) / maxf(1.0, length)
		var fy := lerpf(y0, y1, 0.5 - 0.5 * cos(t * PI))
		decs.append({"kind": "fern" if _rng.randf() < 0.7 else "mushroom", "x": fx, "y": fy, "scale": _rng.randf_range(0.75, 1.3), "color": flora_colors[_rng.randi() % 3], "phase": _rng.randf() * TAU})
	_cursor_x = x1
	_cursor_y = y1
	return {"x0": x0, "x1": x1, "y0": y0, "y1": y1}

func _push_gap(segs: Array, width: float) -> Dictionary:
	var x0 := _cursor_x
	var x1 := x0 + width
	segs.append({"x_start": x0, "x_end": x1, "y_start": _cursor_y, "y_end": _cursor_y, "is_gap": true, "has_puddle": false, "p_start": 0.0, "p_end": 0.0, "seed": 0.0})
	_cursor_x = x1
	return {"x0": x0, "x1": x1}

func _add_totem(decs: Array, x: float, y: float, form_id: int) -> void:
	var cols := [Color(0.31, 1.0, 0.69), Color(0.0, 0.9, 1.0), Color(1.0, 0.62, 0.0)]
	decs.append({"kind": "totem", "x": x, "y": y, "scale": 1.0, "color": cols[clampi(form_id, 0, 2)], "phase": 0.0})

func _generate_chunk(difficulty: float) -> Dictionary:
	var id := _chunk_id
	_chunk_id += 1
	var x_start := _cursor_x
	var segs: Array = []
	var obs: Array = []
	var decs: Array = []

	if id == 0:
		# Opening runway: peaceful rain-drenched run (~4s safe without input)
		_push_ground(segs, decs, 950.0, 0.0)
		_push_ground(segs, decs, 620.0, -14.0)
		_push_ground(segs, decs, 680.0, 0.0)
	elif id == 1:
		# Fox Onboarding (Mint): Low root tunnel + thorn jump + mossy cliff ledge
		var g1 := _push_ground(segs, decs, 620.0, 0.0)
		_add_totem(decs, g1["x0"] + 85.0, 0.0, 0)
		obs.append({"kind": "root_tunnel", "rect": Rect2(g1["x0"] + 270.0, -122.0, 165.0, 92.0), "intact": true, "cleared": false, "form": 0})
		var g2 := _push_ground(segs, decs, 540.0, -10.0)
		obs.append({"kind": "thorn_bramble", "rect": Rect2(g2["x0"] + 190.0, g2["y1"] - 34.0, 92.0, 34.0), "intact": true, "cleared": false, "form": 0})
		obs.append({"kind": "mossy_ledge", "rect": Rect2(g2["x0"] + 175.0, g2["y1"] - 92.0, 145.0, 20.0), "intact": true, "cleared": false, "form": 0})
	elif id == 2:
		# Pangolin Onboarding (Amber): Downhill ramp + cracked obsidian monolith
		var g1 := _push_ground(segs, decs, 420.0, 24.0)
		_add_totem(decs, g1["x0"] + 90.0, g1["y0"], 2)
		var g2 := _push_ground(segs, decs, 600.0, 14.0)
		obs.append({"kind": "monolith", "rect": Rect2(g2["x0"] + 150.0, g2["y1"] - 110.0, 64.0, 110.0), "intact": true, "cleared": false, "form": 2})
	elif id == 3:
		# Moth Onboarding (Cyan): Wide misty canyon + glowing spore-draft + elevated branch sanctuary
		var g1 := _push_ground(segs, decs, 360.0, -8.0)
		_add_totem(decs, g1["x0"] + 100.0, g1["y0"], 1)
		var gap := _push_gap(segs, 390.0)
		obs.append({"kind": "spore_draft", "rect": Rect2(gap["x0"] + 100.0, _cursor_y - 300.0, 180.0, 380.0), "intact": true, "cleared": false, "form": 1})
		obs.append({"kind": "high_platform", "rect": Rect2(gap["x0"] + 235.0, _cursor_y - 130.0, 185.0, 20.0), "intact": true, "cleared": false, "form": 1})
		_push_ground(segs, decs, 540.0, 0.0)
	else:
		# Progressive multi-form combos
		var pick := _rng.randi() % 4
		if pick == 0:
			# 3-Form Combo: Pangolin Smash -> Fox Leap -> Moth Spore-Draft Glide
			var g1 := _push_ground(segs, decs, 520.0, 22.0)
			_add_totem(decs, g1["x0"] + 75.0, g1["y0"], 2)
			obs.append({"kind": "monolith", "rect": Rect2(g1["x0"] + 250.0, g1["y1"] - 112.0, 64.0, 112.0), "intact": true, "cleared": false, "form": 2})
			var g2 := _push_ground(segs, decs, 420.0, -6.0)
			obs.append({"kind": "thorn_bramble", "rect": Rect2(g2["x0"] + 165.0, g2["y1"] - 36.0, 96.0, 36.0), "intact": true, "cleared": false, "form": 0})
			var gap := _push_gap(segs, 420.0 + difficulty * 115.0)
			obs.append({"kind": "spore_draft", "rect": Rect2(gap["x0"] + 115.0, _cursor_y - 300.0, 180.0, 380.0), "intact": true, "cleared": false, "form": 1})
			_push_ground(segs, decs, 460.0, 0.0)
		elif pick == 1:
			# Pangolin Bramble Carpet & Crystal Barricade Chute
			var g1 := _push_ground(segs, decs, 780.0, 26.0)
			_add_totem(decs, g1["x0"] + 75.0, g1["y0"], 2)
			obs.append({"kind": "thorn_bramble", "rect": Rect2(g1["x0"] + 180.0, g1["y1"] - 38.0, 150.0, 38.0), "intact": true, "cleared": false, "form": 2})
			obs.append({"kind": "crystal_wall", "rect": Rect2(g1["x0"] + 470.0, g1["y1"] - 124.0, 62.0, 124.0), "intact": true, "cleared": false, "form": 2})
			obs.append({"kind": "fallen_log", "rect": Rect2(g1["x0"] + 650.0, g1["y1"] - 68.0, 74.0, 68.0), "intact": true, "cleared": false, "form": 2})
			_push_ground(segs, decs, 360.0, 0.0)
		elif pick == 2:
			# Moth Dual-Draft Canyon -> Elevated Sanctuary -> Fox Root Tunnel
			var g1 := _push_ground(segs, decs, 340.0, -10.0)
			_add_totem(decs, g1["x0"] + 85.0, g1["y0"], 1)
			var gap := _push_gap(segs, 480.0 + difficulty * 130.0)
			obs.append({"kind": "spore_draft", "rect": Rect2(gap["x0"] + 85.0, _cursor_y - 310.0, 175.0, 390.0), "intact": true, "cleared": false, "form": 1})
			obs.append({"kind": "high_platform", "rect": Rect2(gap["x0"] + 215.0, _cursor_y - 148.0, 180.0, 20.0), "intact": true, "cleared": false, "form": 1})
			obs.append({"kind": "spore_draft", "rect": Rect2(gap["x1"] - 215.0, _cursor_y - 310.0, 165.0, 390.0), "intact": true, "cleared": false, "form": 1})
			var g2 := _push_ground(segs, decs, 680.0, 0.0)
			obs.append({"kind": "root_tunnel", "rect": Rect2(g2["x0"] + 275.0, g2["y1"] - 122.0, 180.0, 92.0), "intact": true, "cleared": false, "form": 0})
		else:
			# Fox Agility Gauntlet: Staggered Ledges + Jump Gap + Tunnel
			var g1 := _push_ground(segs, decs, 460.0, 0.0)
			_add_totem(decs, g1["x0"] + 80.0, g1["y0"], 0)
			obs.append({"kind": "thorn_bramble", "rect": Rect2(g1["x0"] + 210.0, g1["y1"] - 36.0, 115.0, 36.0), "intact": true, "cleared": false, "form": 0})
			obs.append({"kind": "mossy_ledge", "rect": Rect2(g1["x0"] + 195.0, g1["y1"] - 92.0, 165.0, 20.0), "intact": true, "cleared": false, "form": 0})
			_push_gap(segs, 180.0 + difficulty * 35.0)
			var g2 := _push_ground(segs, decs, 600.0, -12.0)
			obs.append({"kind": "root_tunnel", "rect": Rect2(g2["x0"] + 235.0, g2["y1"] - 124.0, 180.0, 94.0), "intact": true, "cleared": false, "form": 0})

	return {"id": id, "x_start": x_start, "x_end": _cursor_x, "segments": segs, "obstacles": obs, "decorations": decs}

func _draw() -> void:
	for chunk in chunks:
		for seg in chunk["segments"]:
			if seg["is_gap"]:
				# Toxic low-lying cyan mist rising from bottomless ravine
				draw_rect(Rect2(seg["x_start"], seg["y_start"] + 10.0, seg["x_end"] - seg["x_start"], 280.0), Color(0.03, 0.16, 0.25, 0.48))
				continue
			var pts := PackedVector2Array()
			var steps := maxi(8, int((seg["x_end"] - seg["x_start"]) / 38.0))
			for i in range(steps + 1):
				var t := float(i) / float(steps)
				var x := lerpf(seg["x_start"], seg["x_end"], t)
				var y := lerpf(seg["y_start"], seg["y_end"], 0.5 - 0.5 * cos(t * PI)) + sin(x * 0.045 + seg["seed"]) * 3.0 * sin(t * PI)
				pts.append(Vector2(x, y))
			var poly := pts.duplicate()
			poly.append(Vector2(seg["x_end"], 380.0))
			poly.append(Vector2(seg["x_start"], 380.0))
			draw_colored_polygon(poly, Color(0.045, 0.085, 0.135, 1.0))

			# Tangled roots & stone strata carved into cliff face
			for i in range(1, pts.size() - 1, 2):
				var rp := pts[i]
				draw_line(rp + Vector2(0.0, 8.0), rp + Vector2(-6.0, 58.0), Color(0.11, 0.19, 0.26, 0.34), 2.0, true)

			# Wet mossy cliff highlight catching moonlight
			draw_polyline(pts, Color(0.45, 0.72, 0.82, 0.44), 2.8, true)

			# Shallow rain puddle reflecting moonlight & the active creature's bioluminescent glow
			if seg["has_puddle"]:
				var px0: float = seg["p_start"]
				var px1: float = seg["p_end"]
				var py := lerpf(seg["y_start"], seg["y_end"], 0.5)
				draw_line(Vector2(px0, py + 2.0), Vector2(px1, py + 2.0), Color(0.55, 0.8, 0.96, 0.36), 4.0, true)
				var dist := absf(_player_pos.x - (px0 + px1) * 0.5)
				if dist < 230.0:
					var refl := _active_color
					refl.a = (1.0 - dist / 230.0) * 0.65
					var rx := clampf(_player_pos.x, px0 + 14.0, px1 - 14.0)
					draw_line(Vector2(rx - 26.0, py + 2.5), Vector2(rx + 26.0, py + 2.5), refl, 4.6, true)

		# Reactive Flora & Diegetic Waystone Totems
		for dec in chunk["decorations"]:
			var fx: float = dec["x"]
			var fy: float = dec["y"]
			var dk: String = dec["kind"]
			if dk == "totem":
				var stone := PackedVector2Array([Vector2(fx - 9, fy + 4), Vector2(fx - 6, fy - 34), Vector2(fx, fy - 42), Vector2(fx + 6, fy - 34), Vector2(fx + 9, fy + 4)])
				draw_colored_polygon(stone, Color(0.06, 0.11, 0.16, 1.0))
				var rune := PackedVector2Array([Vector2(fx, fy - 32), Vector2(fx - 4, fy - 23), Vector2(fx, fy - 14), Vector2(fx + 4, fy - 23), Vector2(fx, fy - 32)])
				draw_polyline(rune, dec["color"], 2.0, true)
			elif dk == "mushroom":
				draw_line(Vector2(fx, fy + 2.0), Vector2(fx, fy - 10.0 * dec["scale"]), Color(0.12, 0.2, 0.26), 2.2, true)
				draw_circle(Vector2(fx, fy - 10.0 * dec["scale"]), 5.2 * dec["scale"], dec["color"])
			else:
				# Reactive glowing fern physically bends aside as player runs past!
				var dx := _player_pos.x - fx
				var dy := absf(_player_pos.y - fy)
				var bend := sin(_time * 2.4 + dec["phase"]) * 0.14
				if absf(dx) < 88.0 and dy < 75.0:
					bend += (1.0 - absf(dx) / 88.0) * (-0.95 if dx >= 0.0 else 0.95)
				var tip := Vector2(fx, fy) + Vector2(sin(bend) * 18.0, -cos(bend) * 18.0) * dec["scale"]
				draw_line(Vector2(fx, fy + 2.0), tip, Color(0.08, 0.22, 0.26, 1.0), 2.2, true)
				draw_circle(tip, 2.5, dec["color"])

		# Form-Cued Obstacles
		for obs in chunk["obstacles"]:
			if not obs["intact"]:
				continue
			var r: Rect2 = obs["rect"]
			var k: String = obs["kind"]
			if k == "spore_draft":
				draw_rect(r, Color(0.0, 0.9, 1.0, 0.14 * _flow_glow))
				for s in range(4):
					var sx := r.position.x + (float(s) + 0.5) * r.size.x * 0.25
					var sy := r.position.y + r.size.y - fmod(_time * 185.0 + float(s) * 90.0, r.size.y)
					draw_line(Vector2(sx, sy + 28.0), Vector2(sx + sin(_time * 5.0 + float(s)) * 6.0, sy), Color(0.5, 0.96, 1.0, 0.45), 1.6, true)
					draw_circle(Vector2(sx, sy), 2.8, Color(0.68, 0.98, 1.0, 0.8))
			elif k == "root_tunnel":
				draw_rect(r, Color(0.035, 0.067, 0.11, 1.0))
				draw_line(Vector2(r.position.x + 6.0, r.end.y), Vector2(r.end.x - 6.0, r.end.y), Color(0.31, 1.0, 0.69, 0.8), 2.6, true)
			elif k == "thorn_bramble":
				var col := Color(1.0, 0.62, 0.0) if obs["form"] == 2 else Color(0.31, 1.0, 0.69)
				var spikes := maxi(5, int(r.size.x / 16.0))
				var step := r.size.x / float(spikes)
				for s in range(spikes):
					var sx := r.position.x + float(s) * step
					var tri := PackedVector2Array([Vector2(sx, r.end.y + 3.0), Vector2(sx + step * 0.5, r.position.y), Vector2(sx + step, r.end.y + 3.0)])
					draw_colored_polygon(tri, Color(0.07, 0.05, 0.11, 1.0))
					draw_polyline(PackedVector2Array([Vector2(sx + step * 0.25, r.position.y + r.size.y * 0.45), Vector2(sx + step * 0.5, r.position.y), Vector2(sx + step * 0.75, r.position.y + r.size.y * 0.45)]), col, 1.6, true)
			elif k == "monolith" or k == "crystal_wall":
				var body_col := Color(0.09, 0.10, 0.15, 1.0) if k == "monolith" else Color(0.24, 0.12, 0.06, 0.92)
				draw_rect(r, body_col)
				draw_polyline(PackedVector2Array([
					r.position + Vector2(r.size.x * 0.42, 8.0),
					r.position + Vector2(r.size.x * 0.60, r.size.y * 0.35),
					r.position + Vector2(r.size.x * 0.30, r.size.y * 0.65),
					r.position + Vector2(r.size.x * 0.55, r.size.y - 6.0)
				]), Color(1.0, 0.62, 0.0, 0.95), 2.8, true)
			elif k == "fallen_log":
				draw_rect(r, Color(0.11, 0.08, 0.08, 1.0))
				draw_line(r.position + Vector2(10, 14), r.end - Vector2(12, 12), Color(1.0, 0.62, 0.0, 0.9), 2.2, true)
			elif k == "high_platform" or k == "mossy_ledge":
				var rim := Color(0.0, 0.9, 1.0) if k == "high_platform" else Color(0.31, 1.0, 0.69)
				draw_rect(r, Color(0.05, 0.10, 0.15, 1.0))
				draw_line(r.position, Vector2(r.end.x, r.position.y), rim, 2.8, true)
