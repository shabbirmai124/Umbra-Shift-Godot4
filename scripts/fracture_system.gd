extends Node2D
class_name FractureSystem

## Voronoi-Style Procedural Fracture & Ground Fissure System
## - Shatters monoliths, crystal walls, and fallen logs into 16 jagged spinning polygon shards
## - Shards simulate gravity, rotational inertia, ground bounce damping, and cooling magma-amber edges (1.8s)
## - Stamps glowing cooling magma fissure decals onto the mossy terrain on Meteor Slams and high-speed rolls

const MAX_SHARDS: int = 96
const MAX_FISSURES: int = 28

var _shards: Array[Dictionary] = []
var _fissures: Array[Dictionary] = []

func reset_fractures() -> void:
	_shards.clear()
	_fissures.clear()
	queue_redraw()

func shatter_obstacle(center: Vector2, ground_y: float, kind: String = "monolith") -> void:
	var count: int = 18 if kind != "thorn_bramble" else 12
	var is_crystal: bool = kind == "crystal_wall"
	var base_fill: Color = Color(0.28, 0.13, 0.04, 0.94) if is_crystal else Color(0.11, 0.125, 0.175, 1.0)
	for i in range(count):
		if _shards.size() >= MAX_SHARDS:
			_shards.pop_front()
		var sides: int = 4 + (i % 3)
		var rad: float = randf_range(7.0, 17.0)
		var pts: PackedVector2Array = PackedVector2Array()
		for s in range(sides):
			var ang: float = (float(s) / float(sides)) * TAU + randf_range(-0.28, 0.28)
			var r_s: float = rad * randf_range(0.62, 1.22)
			pts.append(Vector2(cos(ang) * r_s, sin(ang) * r_s))
		var vx: float = randf_range(120.0, 620.0)
		var vy: float = randf_range(-520.0, -90.0)
		_shards.append({
			"pos": center + Vector2(randf_range(-24.0, 24.0), randf_range(-44.0, 16.0)),
			"vel": Vector2(vx, vy),
			"rot": randf_range(0.0, TAU),
			"rot_v": randf_range(-13.0, 13.0),
			"pts": pts,
			"fill": base_fill,
			"life": 0.0,
			"max_life": randf_range(1.45, 2.05),
			"ground_y": ground_y,
			"bounces": 0
		})
	stamp_ground_fissure(Vector2(center.x, ground_y), 1.25)
	queue_redraw()

func stamp_ground_fissure(world_pos: Vector2, intensity: float = 1.0) -> void:
	if _fissures.size() >= MAX_FISSURES:
		_fissures.pop_front()
	var w: float = randf_range(38.0, 64.0) * intensity
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(-w * 0.5, 2.0),
		Vector2(-w * 0.22, -2.5),
		Vector2(0.0, 3.5),
		Vector2(w * 0.24, -1.8),
		Vector2(w * 0.5, 2.0)
	])
	var branch: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 3.5),
		Vector2(w * 0.12, 11.0 * intensity),
		Vector2(w * 0.24, 18.0 * intensity)
	])
	_fissures.append({
		"pos": world_pos,
		"pts": pts,
		"branch": branch,
		"life": 0.0,
		"max_life": 2.4,
		"intensity": intensity
	})

func update_fractures(dt: float) -> void:
	for i in range(_shards.size() - 1, -1, -1):
		var sh: Dictionary = _shards[i]
		var life: float = float(sh["life"]) + dt
		var ml: float = float(sh["max_life"])
		if life >= ml:
			_shards.remove_at(i)
			continue
		var vel: Vector2 = sh["vel"]
		vel.y += 1720.0 * dt
		var pos: Vector2 = sh["pos"] + vel * dt
		var gy: float = float(sh["ground_y"])
		if pos.y > gy - 3.0:
			pos.y = gy - 3.0
			vel.y = -absf(vel.y) * 0.42
			vel.x *= 0.74
			sh["rot_v"] = float(sh["rot_v"]) * 0.72
			sh["bounces"] = int(sh["bounces"]) + 1
		sh["pos"] = pos
		sh["vel"] = vel
		sh["rot"] = float(sh["rot"]) + float(sh["rot_v"]) * dt
		sh["life"] = life

	for i in range(_fissures.size() - 1, -1, -1):
		var f: Dictionary = _fissures[i]
		var life: float = float(f["life"]) + dt
		if life >= float(f["max_life"]):
			_fissures.remove_at(i)
		else:
			f["life"] = life

	if _shards.size() > 0 or _fissures.size() > 0:
		queue_redraw()

func _draw() -> void:
	# Glowing magma ground fissures cooling smoothly to dark ash
	for f in _fissures:
		var prog: float = float(f["life"]) / maxf(0.01, float(f["max_life"]))
		var heat: float = pow(1.0 - prog, 1.45)
		var pos: Vector2 = f["pos"]
		var pts: PackedVector2Array = f["pts"]
		var branch: PackedVector2Array = f["branch"]
		var world_pts: PackedVector2Array = PackedVector2Array()
		for p in pts:
			world_pts.append(pos + p)
		var world_br: PackedVector2Array = PackedVector2Array()
		for bp in branch:
			world_br.append(pos + bp)
		var glow_col: Color = Color(1.0, 0.36, 0.0, heat * 0.42)
		var core_col: Color = Color(1.35, 0.82, 0.16, heat * 0.96).lerp(Color(0.24, 0.12, 0.10, heat * 0.5), prog)
		draw_polyline(world_pts, glow_col, 7.5, true)
		draw_polyline(world_pts, core_col, 2.6, true)
		draw_polyline(world_br, core_col, 1.8, true)

	# Spinning fractured rock/crystal shards with cooling molten edges (1.8s)
	for sh in _shards:
		var prog: float = float(sh["life"]) / maxf(0.01, float(sh["max_life"]))
		var alpha: float = clampf(1.0 - smoothstep_f(0.70, 1.0, prog), 0.0, 1.0)
		var cool: float = clampf(1.0 - prog * 1.15, 0.0, 1.0)
		var pos: Vector2 = sh["pos"]
		var rot: float = float(sh["rot"])
		var fill: Color = sh["fill"]
		fill.a *= alpha
		var edge_col: Color = Color(1.25, 0.64, 0.08, alpha * cool).lerp(Color(0.26, 0.30, 0.38, alpha * 0.65), 1.0 - cool)
		var raw_pts: PackedVector2Array = sh["pts"]
		var xform_pts: PackedVector2Array = PackedVector2Array()
		for p in raw_pts:
			xform_pts.append(pos + p.rotated(rot))
		draw_colored_polygon(xform_pts, fill)
		if xform_pts.size() >= 3:
			var closed: PackedVector2Array = xform_pts.duplicate()
			closed.append(xform_pts[0])
			draw_polyline(closed, edge_col, 1.8, true)

func smoothstep_f(edge0: float, edge1: float, x: float) -> float:
	var t: float = clampf((x - edge0) / maxf(0.0001, edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
