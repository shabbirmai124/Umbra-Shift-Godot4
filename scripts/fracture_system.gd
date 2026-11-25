extends Node2D
class_name FractureSystem

## Voronoi-Style Procedural Fracture Debris & Cooling Ground Fissure Decals
## Shatters monoliths, crystal walls, and logs into 14-20 jagged spinning polygon shards
## with gravity, rotational inertia, ground bounce damping, and cooling magma-amber rims.

var _shards: Array[Dictionary] = []
var _fissures: Array[Dictionary] = []

func reset_fractures() -> void:
	_shards.clear()
	_fissures.clear()
	queue_redraw()

func shatter_obstacle(center: Vector2, ground_y: float, is_crystal: bool = false) -> void:
	var count: int = 18
	for i in range(count):
		var ang: float = randf_range(-PI * 0.92, -0.08)
		var spd: float = randf_range(220.0, 640.0)
		var sz: float = randf_range(6.5, 16.5)
		# Jagged Voronoi-like irregular 5-vertex shard polygon
		var local_poly: PackedVector2Array = PackedVector2Array()
		for v in range(5):
			var va: float = (float(v) / 5.0) * TAU + randf_range(-0.22, 0.22)
			var vr: float = sz * randf_range(0.55, 1.15)
			local_poly.append(Vector2(cos(va) * vr, sin(va) * vr))
		_shards.append({
			"pos": center + Vector2(randf_range(-20.0, 20.0), randf_range(-34.0, 16.0)),
			"vel": Vector2(cos(ang) * spd + 190.0, sin(ang) * spd - 90.0),
			"rot": randf_range(0.0, TAU),
			"rot_v": randf_range(-13.0, 13.0),
			"poly": local_poly,
			"ground_y": ground_y,
			"is_crystal": is_crystal,
			"life": 0.0,
			"max_life": randf_range(1.4, 2.0)
		})
	stamp_ground_fissure(Vector2(center.x, ground_y), 1.15)
	queue_redraw()

func stamp_ground_fissure(world_pos: Vector2, scale_v: float = 1.0) -> void:
	_fissures.append({
		"pos": world_pos,
		"scale": scale_v,
		"life": 0.0,
		"max_life": 2.4
	})
	if _fissures.size() > 16:
		_fissures.pop_front()
	queue_redraw()

func step_fractures(dt: float) -> void:
	var dirty: bool = false
	for i in range(_shards.size() - 1, -1, -1):
		dirty = true
		var s: Dictionary = _shards[i]
		var life: float = float(s["life"]) + dt
		s["life"] = life
		if life >= float(s["max_life"]):
			_shards.remove_at(i)
			continue
		var vel: Vector2 = s["vel"]
		var pos: Vector2 = s["pos"]
		vel.y += 1480.0 * dt
		pos += vel * dt
		var gy: float = float(s["ground_y"])
		if pos.y > gy - 3.0 and vel.y > 0.0:
			pos.y = gy - 3.0
			vel.y *= -0.36
			vel.x *= 0.72
			s["rot_v"] = float(s["rot_v"]) * 0.65
		s["pos"] = pos
		s["vel"] = vel
		s["rot"] = float(s["rot"]) + float(s["rot_v"]) * dt

	for i in range(_fissures.size() - 1, -1, -1):
		dirty = true
		var f: Dictionary = _fissures[i]
		var fl: float = float(f["life"]) + dt
		f["life"] = fl
		if fl >= float(f["max_life"]):
			_fissures.remove_at(i)

	if dirty:
		queue_redraw()

func _draw() -> void:
	# Cooling glowing magma ground fissures
	for f in _fissures:
		var pos: Vector2 = f["pos"]
		var sc: float = float(f["scale"])
		var ratio: float = clampf(1.0 - float(f["life"]) / float(f["max_life"]), 0.0, 1.0)
		var heat_col: Color = Color(1.0, 0.56, 0.06, ratio * 0.88).lerp(Color(0.32, 0.14, 0.08, ratio * 0.5), 1.0 - ratio)
		var core_col: Color = Color(1.0, 0.90, 0.54, ratio * ratio * 0.85)
		var crack: PackedVector2Array = PackedVector2Array([
			pos + Vector2(-34.0 * sc, 2.0),
			pos + Vector2(-14.0 * sc, 6.0),
			pos + Vector2(2.0 * sc, 2.0),
			pos + Vector2(18.0 * sc, 7.0),
			pos + Vector2(36.0 * sc, 2.0)
		])
		draw_polyline(crack, Color(1.0, 0.42, 0.02, ratio * 0.32), 7.0, true)
		draw_polyline(crack, heat_col, 3.0, true)
		draw_polyline(crack, core_col, 1.2, true)

	# Spinning Voronoi shards with molten-amber edges cooling to dark basalt ash
	for s in _shards:
		var pos: Vector2 = s["pos"]
		var rot: float = float(s["rot"])
		var life_t: float = clampf(float(s["life"]) / float(s["max_life"]), 0.0, 1.0)
		var fade: float = clampf((1.0 - life_t) * 1.4, 0.0, 1.0)
		var heat: float = clampf(1.0 - life_t * 1.25, 0.0, 1.0)
		var local_poly: PackedVector2Array = s["poly"]
		var world_poly: PackedVector2Array = PackedVector2Array()
		var c: float = cos(rot)
		var sn: float = sin(rot)
		for pt in local_poly:
			world_poly.append(pos + Vector2(pt.x * c - pt.y * sn, pt.x * sn + pt.y * c))
		var base_col: Color = Color(0.46, 0.24, 0.10, fade) if bool(s["is_crystal"]) else Color(0.20, 0.22, 0.28, fade)
		draw_colored_polygon(world_poly, base_col)
		var rim_col: Color = Color(0.32, 0.36, 0.44, fade * 0.5).lerp(Color(1.0, 0.68, 0.12, fade), heat)
		world_poly.append(world_poly[0])
		draw_polyline(world_poly, rim_col, 1.8, true)
