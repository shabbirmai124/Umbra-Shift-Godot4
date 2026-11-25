extends RefCounted
class_name ObstacleRenderer

## Sculpted Organic Form-Cued Obstacle Renderer & LightOccluder2D Geometry Builder
## Renders zero raw boxes: every obstacle has layered natural-fantasy color, moonlight bevels,
## hanging moss/vines, and unmistakable form-cued bioluminescent telegraphing.

static func get_occluder_polygon(obs: Dictionary) -> PackedVector2Array:
	var r: Rect2 = obs["rect"]
	var k: String = String(obs["kind"])
	if k == "monolith":
		return PackedVector2Array([
			r.position + Vector2(6.0, r.size.y),
			r.position + Vector2(-2.0, r.size.y * 0.55),
			r.position + Vector2(r.size.x * 0.36, -4.0),
			r.position + Vector2(r.size.x * 0.82, 6.0),
			r.position + Vector2(r.size.x, r.size.y)
		])
	elif k == "crystal_wall":
		return PackedVector2Array([
			r.position + Vector2(2.0, r.size.y),
			r.position + Vector2(r.size.x * 0.50, -6.0),
			r.position + Vector2(r.size.x + 2.0, r.size.y)
		])
	elif k == "root_tunnel":
		return PackedVector2Array([
			r.position + Vector2(-6.0, -14.0),
			r.position + Vector2(r.size.x + 6.0, -10.0),
			r.position + Vector2(r.size.x + 2.0, r.size.y - 4.0),
			r.position + Vector2(-2.0, r.size.y - 6.0)
		])
	return PackedVector2Array()

static func draw_obstacle(canvas: CanvasItem, obs: Dictionary, time_val: float, flow_glow: float) -> void:
	if not bool(obs["intact"]):
		return
	var r: Rect2 = obs["rect"]
	var k: String = String(obs["kind"])
	if k == "spore_draft":
		_draw_spore_draft(canvas, r, time_val, flow_glow)
	elif k == "root_tunnel":
		_draw_root_tunnel(canvas, r, time_val)
	elif k == "thorn_bramble":
		_draw_thorn_bramble(canvas, r, int(obs["form"]))
	elif k == "monolith":
		_draw_monolith(canvas, r, time_val)
	elif k == "crystal_wall":
		_draw_crystal_wall(canvas, r, time_val)
	elif k == "fallen_log":
		_draw_fallen_log(canvas, r)
	elif k == "high_platform" or k == "mossy_ledge":
		_draw_elevated_sanctuary(canvas, r, k == "high_platform", time_val)

static func _draw_spore_draft(canvas: CanvasItem, r: Rect2, t: float, flow_glow: float) -> void:
	# Layered soft cyan updraft column with swirling ribbons & rising bioluminescent spores
	for b in range(3):
		var inset: float = float(b) * 18.0
		var alpha: float = (0.075 + float(b) * 0.035) * clampf(flow_glow, 0.85, 1.35)
		canvas.draw_rect(Rect2(r.position.x + inset, r.position.y, maxf(16.0, r.size.x - inset * 2.0), r.size.y), Color(0.08, 0.86, 1.0, alpha))
	for s in range(7):
		var sx: float = r.position.x + (float(s) + 0.5) * (r.size.x / 7.0)
		var sy: float = r.position.y + r.size.y - fposmod(t * (175.0 + float(s) * 20.0) + float(s) * 68.0, r.size.y)
		var sway: float = sin(t * 4.8 + float(s) * 1.5) * 10.0
		var p0: Vector2 = Vector2(sx - sway * 0.3, sy + 36.0)
		var p1: Vector2 = Vector2(sx + sway * 0.5, sy + 18.0)
		var p2: Vector2 = Vector2(sx + sway, sy)
		canvas.draw_polyline(PackedVector2Array([p0, p1, p2]), Color(0.55, 0.96, 1.0, 0.52), 1.8, true)
		canvas.draw_circle(p2, 6.0, Color(0.18, 0.92, 1.0, 0.20))
		canvas.draw_circle(p2, 2.6, Color(0.84, 0.99, 1.0, 0.92))

static func _draw_root_tunnel(canvas: CanvasItem, r: Rect2, t: float) -> void:
	# Gnarled moss-draped ancient redwood/oak root arch with warm brown bark & glowing mint under-rim
	var arch: PackedVector2Array = PackedVector2Array([
		r.position + Vector2(-10.0, -14.0),
		r.position + Vector2(r.size.x * 0.26, -24.0),
		r.position + Vector2(r.size.x * 0.72, -20.0),
		r.position + Vector2(r.size.x + 10.0, -10.0),
		r.position + Vector2(r.size.x + 6.0, r.size.y - 6.0),
		r.position + Vector2(r.size.x * 0.82, r.size.y),
		r.position + Vector2(r.size.x * 0.50, r.size.y - 4.0),
		r.position + Vector2(r.size.x * 0.18, r.size.y),
		r.position + Vector2(-6.0, r.size.y - 8.0)
	])
	canvas.draw_colored_polygon(arch, Color(0.17, 0.14, 0.13, 1.0))
	# Mossy emerald cap on top of root arch
	var moss_cap: PackedVector2Array = PackedVector2Array([
		r.position + Vector2(-8.0, -14.0),
		r.position + Vector2(r.size.x * 0.26, -24.0),
		r.position + Vector2(r.size.x * 0.72, -20.0),
		r.position + Vector2(r.size.x + 8.0, -10.0),
		r.position + Vector2(r.size.x * 0.78, -2.0),
		r.position + Vector2(r.size.x * 0.30, -5.0)
	])
	canvas.draw_colored_polygon(moss_cap, Color(0.14, 0.42, 0.34, 0.95))
	# Rich bark grain ridges
	canvas.draw_polyline(PackedVector2Array([
		r.position + Vector2(10.0, 16.0),
		r.position + Vector2(r.size.x * 0.44, 34.0),
		r.position + Vector2(r.size.x - 14.0, 22.0)
	]), Color(0.28, 0.23, 0.20, 0.82), 3.2, true)
	canvas.draw_polyline(PackedVector2Array([
		r.position + Vector2(16.0, 52.0),
		r.position + Vector2(r.size.x * 0.56, 44.0),
		r.position + Vector2(r.size.x - 10.0, 58.0)
	]), Color(0.11, 0.09, 0.09, 0.78), 2.6, true)
	# Swaying hanging moss vines
	for v in range(5):
		var vx: float = r.position.x + 16.0 + float(v) * (r.size.x - 32.0) / 4.0
		var vsway: float = sin(t * 2.4 + float(v) * 1.3) * 4.0
		canvas.draw_polyline(PackedVector2Array([
			Vector2(vx, r.end.y - 2.0),
			Vector2(vx + vsway * 0.5, r.end.y + 6.0),
			Vector2(vx + vsway, r.end.y + 13.0)
		]), Color(0.20, 0.62, 0.48, 0.78), 1.8, true)
	# Luminous mint dash-cue underside rim
	canvas.draw_polyline(PackedVector2Array([
		r.position + Vector2(4.0, r.size.y - 2.0),
		r.position + Vector2(r.size.x * 0.5, r.size.y - 4.0),
		r.position + Vector2(r.size.x - 4.0, r.size.y - 2.0)
	]), Color(0.38, 1.0, 0.74, 0.94), 3.2, true)

static func _draw_thorn_bramble(canvas: CanvasItem, r: Rect2, form_id: int) -> void:
	var col: Color = Color(1.0, 0.64, 0.12) if form_id == 2 else Color(0.36, 1.0, 0.72)
	var spikes: int = maxi(5, int(r.size.x / 16.0))
	var step: float = r.size.x / float(spikes)
	for s in range(spikes):
		var sx: float = r.position.x + float(s) * step
		var lean: float = -3.5 if s % 2 == 0 else 3.5
		var tri: PackedVector2Array = PackedVector2Array([
			Vector2(sx - 1.0, r.end.y + 3.0),
			Vector2(sx + step * 0.5 + lean, r.position.y),
			Vector2(sx + step + 1.0, r.end.y + 3.0)
		])
		canvas.draw_colored_polygon(tri, Color(0.16, 0.12, 0.18, 1.0))
		canvas.draw_polyline(PackedVector2Array([
			Vector2(sx + step * 0.22, r.position.y + r.size.y * 0.52),
			Vector2(sx + step * 0.5 + lean, r.position.y),
			Vector2(sx + step * 0.78, r.position.y + r.size.y * 0.52)
		]), col, 2.0, true)

static func _draw_monolith(canvas: CanvasItem, r: Rect2, t: float) -> void:
	# Weathered natural basalt monolith spire with moonlit slate facets & pulsing molten amber fissures
	var pulse: float = 0.82 + 0.18 * sin(t * 4.5 + r.position.x * 0.02)
	var spire: PackedVector2Array = PackedVector2Array([
		r.position + Vector2(6.0, r.size.y + 4.0),
		r.position + Vector2(-4.0, r.size.y * 0.62),
		r.position + Vector2(4.0, r.size.y * 0.22),
		r.position + Vector2(r.size.x * 0.36, -6.0),
		r.position + Vector2(r.size.x * 0.78, 4.0),
		r.position + Vector2(r.size.x + 3.0, r.size.y * 0.38),
		r.position + Vector2(r.size.x - 2.0, r.size.y + 4.0)
	])
	canvas.draw_colored_polygon(spire, Color(0.18, 0.20, 0.26, 1.0))
	var facet: PackedVector2Array = PackedVector2Array([
		r.position + Vector2(4.0, r.size.y * 0.22),
		r.position + Vector2(r.size.x * 0.36, -6.0),
		r.position + Vector2(r.size.x * 0.50, r.size.y * 0.54),
		r.position + Vector2(-4.0, r.size.y * 0.62)
	])
	canvas.draw_colored_polygon(facet, Color(0.28, 0.31, 0.39, 1.0))
	canvas.draw_polyline(PackedVector2Array([
		r.position + Vector2(4.0, r.size.y * 0.22),
		r.position + Vector2(r.size.x * 0.36, -6.0),
		r.position + Vector2(r.size.x * 0.78, 4.0)
	]), Color(0.76, 0.86, 0.96, 0.56), 1.8, true)
	# Pulsing molten magma fissures signaling Pangolin Smash
	var crack: PackedVector2Array = PackedVector2Array([
		r.position + Vector2(r.size.x * 0.40, 6.0),
		r.position + Vector2(r.size.x * 0.64, r.size.y * 0.34),
		r.position + Vector2(r.size.x * 0.28, r.size.y * 0.64),
		r.position + Vector2(r.size.x * 0.54, r.size.y - 4.0)
	])
	canvas.draw_polyline(crack, Color(1.0, 0.48, 0.04, 0.42 * pulse), 7.5, true)
	canvas.draw_polyline(crack, Color(1.0, 0.66, 0.08, 0.98 * pulse), 3.2, true)
	canvas.draw_polyline(crack, Color(1.0, 0.92, 0.62, 0.85 * pulse), 1.2, true)
	canvas.draw_line(r.position + Vector2(r.size.x * 0.64, r.size.y * 0.34), r.position + Vector2(r.size.x * 0.86, r.size.y * 0.46), Color(1.0, 0.52, 0.05, 0.92 * pulse), 2.2, true)

static func _draw_crystal_wall(canvas: CanvasItem, r: Rect2, t: float) -> void:
	var pulse: float = 0.84 + 0.16 * sin(t * 5.0 + r.position.x * 0.03)
	var shards: Array[PackedVector2Array] = [
		PackedVector2Array([r.position + Vector2(0.0, r.size.y + 2.0), r.position + Vector2(8.0, r.size.y * 0.24), r.position + Vector2(22.0, r.size.y * 0.42), r.position + Vector2(20.0, r.size.y + 2.0)]),
		PackedVector2Array([r.position + Vector2(14.0, r.size.y + 2.0), r.position + Vector2(r.size.x * 0.50, -8.0), r.position + Vector2(r.size.x * 0.76, r.size.y * 0.28), r.position + Vector2(r.size.x * 0.68, r.size.y + 2.0)]),
		PackedVector2Array([r.position + Vector2(r.size.x * 0.56, r.size.y + 2.0), r.position + Vector2(r.size.x + 4.0, r.size.y * 0.32), r.position + Vector2(r.size.x + 2.0, r.size.y + 2.0)])
	]
	for sh in shards:
		canvas.draw_colored_polygon(sh, Color(0.48, 0.24, 0.07, 0.90))
		canvas.draw_polyline(sh, Color(1.0, 0.72, 0.18, 0.95 * pulse), 2.0, true)
	canvas.draw_line(r.position + Vector2(r.size.x * 0.50, -4.0), r.position + Vector2(r.size.x * 0.46, r.size.y * 0.88), Color(1.0, 0.92, 0.62, 0.88), 2.0, true)

static func _draw_fallen_log(canvas: CanvasItem, r: Rect2) -> void:
	var log_poly: PackedVector2Array = PackedVector2Array([
		r.position + Vector2(-4.0, r.size.y + 2.0),
		r.position + Vector2(4.0, 12.0),
		r.position + Vector2(r.size.x * 0.35, 2.0),
		r.position + Vector2(r.size.x * 0.78, 6.0),
		r.position + Vector2(r.size.x + 6.0, 18.0),
		r.position + Vector2(r.size.x - 2.0, r.size.y + 2.0)
	])
	canvas.draw_colored_polygon(log_poly, Color(0.24, 0.17, 0.13, 1.0))
	canvas.draw_polyline(PackedVector2Array([
		r.position + Vector2(6.0, 14.0),
		r.position + Vector2(r.size.x * 0.45, 5.0),
		r.position + Vector2(r.size.x * 0.82, 10.0)
	]), Color(0.26, 0.62, 0.44, 0.85), 3.0, true)
	canvas.draw_polyline(PackedVector2Array([
		r.position + Vector2(12.0, 16.0),
		r.position + Vector2(r.size.x * 0.52, r.size.y * 0.56),
		r.end - Vector2(12.0, 10.0)
	]), Color(1.0, 0.66, 0.10, 0.96), 2.8, true)

static func _draw_elevated_sanctuary(canvas: CanvasItem, r: Rect2, is_high: bool, t: float) -> void:
	var rim: Color = Color(0.20, 0.94, 1.0) if is_high else Color(0.38, 1.0, 0.74)
	var bough: PackedVector2Array = PackedVector2Array([
		r.position + Vector2(-6.0, 4.0),
		r.position + Vector2(8.0, 0.0),
		r.position + Vector2(r.size.x - 8.0, 0.0),
		r.position + Vector2(r.size.x + 6.0, 5.0),
		r.position + Vector2(r.size.x - 10.0, r.size.y + 4.0),
		r.position + Vector2(r.size.x * 0.5, r.size.y + 7.0),
		r.position + Vector2(12.0, r.size.y + 3.0)
	])
	canvas.draw_colored_polygon(bough, Color(0.16, 0.22, 0.26, 1.0))
	for m in range(5):
		var mx: float = r.position.x + 16.0 + float(m) * (r.size.x - 32.0) / 4.0
		var mlen: float = 12.0 + float(m % 2) * 8.0
		canvas.draw_line(Vector2(mx, r.end.y + 2.0), Vector2(mx + sin(t * 2.2 + float(m)) * 3.5, r.end.y + 2.0 + mlen), Color(0.20, 0.58, 0.48, 0.74), 2.0, true)
	canvas.draw_polyline(PackedVector2Array([
		r.position + Vector2(2.0, 1.0),
		Vector2(r.position.x + r.size.x * 0.5, r.position.y - 1.0),
		Vector2(r.end.x - 2.0, r.position.y + 1.0)
	]), rim, 3.4, true)
