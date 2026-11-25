extends RefCounted
class_name ObstacleRenderer

## Sculpted organic renderer & LightOccluder2D silhouette builder for color-coded
## form obstacles: Mint Root Tunnels & Mossy Ledges (Fox), Cyan Spore-Drafts & Canopy Perches (Moth),
## and Molten-Amber Obsidian Monoliths, Crystal Walls, Fallen Logs & Thorn Brambles (Pangolin).

static func get_occluder_polygon(obs: Dictionary) -> PackedVector2Array:
	var r: Rect2 = obs["rect"]
	var k: String = String(obs["kind"])
	if k == "monolith":
		return PackedVector2Array([
			r.position + Vector2(6.0, r.size.y),
			r.position + Vector2(2.0, r.size.y * 0.25),
			r.position + Vector2(r.size.x * 0.38, -4.0),
			r.position + Vector2(r.size.x * 0.80, 6.0),
			r.position + Vector2(r.size.x - 2.0, r.size.y)
		])
	elif k == "crystal_wall":
		return PackedVector2Array([
			r.position + Vector2(2.0, r.size.y),
			r.position + Vector2(r.size.x * 0.5, -6.0),
			r.position + Vector2(r.size.x, r.size.y)
		])
	elif k == "root_tunnel":
		return PackedVector2Array([
			r.position + Vector2(-4.0, -10.0),
			r.position + Vector2(r.size.x + 4.0, -10.0),
			r.position + Vector2(r.size.x, r.size.y - 4.0),
			r.position + Vector2(0.0, r.size.y - 4.0)
		])
	elif k == "fallen_log":
		return PackedVector2Array([
			r.position + Vector2(0.0, r.size.y),
			r.position + Vector2(6.0, 10.0),
			r.position + Vector2(r.size.x - 4.0, 12.0),
			r.position + Vector2(r.size.x, r.size.y)
		])
	return PackedVector2Array()

static func draw_obstacle(canvas: CanvasItem, obs: Dictionary, time: float, flow_glow: float) -> void:
	if not bool(obs["intact"]):
		return
	var r: Rect2 = obs["rect"]
	var k: String = String(obs["kind"])
	var pulse: float = 0.85 + 0.15 * sin(time * 3.8 + r.position.x * 0.02)

	if k == "spore_draft":
		# Vertical rising cyan spore-draft column with layered luminous air currents
		var inner_col: Color = Color(0.0, 0.88, 1.0, 0.11 * flow_glow)
		var core_col: Color = Color(0.24, 0.96, 1.0, 0.08 * flow_glow)
		canvas.draw_rect(Rect2(r.position.x + 10.0, r.position.y, r.size.x - 20.0, r.size.y), inner_col)
		canvas.draw_rect(Rect2(r.position.x + r.size.x * 0.25, r.position.y, r.size.x * 0.5, r.size.y), core_col)
		for s in range(6):
			var sx: float = r.position.x + (float(s) + 0.5) * r.size.x / 6.0
			var sy: float = r.position.y + r.size.y - fposmod(time * (185.0 + float(s) * 20.0) + float(s) * 72.0, r.size.y)
			var sway: float = sin(time * 5.0 + float(s) * 1.45) * 9.0
			canvas.draw_line(Vector2(sx, sy + 36.0), Vector2(sx + sway, sy), Color(0.55, 0.98, 1.0, 0.48), 1.8, true)
			canvas.draw_circle(Vector2(sx + sway, sy), 5.4, Color(0.0, 0.92, 1.0, 0.18))
			canvas.draw_circle(Vector2(sx + sway, sy), 2.5, Color(0.84, 1.0, 1.0, 0.92))
	elif k == "root_tunnel":
		# Gnarled twisted ancient root arch with bark texture, hanging moss vines & HDR mint cue
		var arch: PackedVector2Array = PackedVector2Array([
			r.position + Vector2(-10.0, -14.0),
			r.position + Vector2(r.size.x * 0.26, -24.0),
			r.position + Vector2(r.size.x * 0.74, -20.0),
			r.position + Vector2(r.size.x + 10.0, -10.0),
			r.position + Vector2(r.size.x + 6.0, r.size.y - 6.0),
			r.position + Vector2(r.size.x * 0.80, r.size.y + 1.0),
			r.position + Vector2(r.size.x * 0.50, r.size.y - 4.0),
			r.position + Vector2(r.size.x * 0.20, r.size.y + 1.0),
			r.position + Vector2(-6.0, r.size.y - 8.0)
		])
		canvas.draw_colored_polygon(arch, Color(0.036, 0.068, 0.112, 1.0))
		canvas.draw_polyline(PackedVector2Array([
			r.position + Vector2(6.0, 18.0),
			r.position + Vector2(r.size.x * 0.44, 38.0),
			r.position + Vector2(r.size.x - 10.0, 24.0)
		]), Color(0.11, 0.20, 0.28, 0.78), 3.4, true)
		canvas.draw_polyline(PackedVector2Array([
			r.position + Vector2(-6.0, -12.0),
			r.position + Vector2(r.size.x * 0.26, -24.0),
			r.position + Vector2(r.size.x * 0.74, -20.0),
			r.position + Vector2(r.size.x + 8.0, -10.0)
		]), Color(0.32, 0.56, 0.68, 0.45), 2.0, true)
		for v in range(5):
			var vx: float = r.position.x + 14.0 + float(v) * (r.size.x - 28.0) / 4.0
			var vsway: float = sin(time * 2.6 + float(v) * 1.2) * 4.0
			canvas.draw_line(Vector2(vx, r.end.y - 2.0), Vector2(vx + vsway, r.end.y + 12.0), Color(0.16, 0.56, 0.46, 0.72), 1.8, true)
		canvas.draw_polyline(PackedVector2Array([
			r.position + Vector2(4.0, r.size.y - 2.0),
			r.position + Vector2(r.size.x * 0.5, r.size.y - 4.0),
			r.position + Vector2(r.size.x - 4.0, r.size.y - 2.0)
		]), Color(0.31, 1.15, 0.78, 0.94 * pulse), 3.2, true)
	elif k == "thorn_bramble":
		var col: Color = Color(1.15, 0.68, 0.04, 0.95) if int(obs["form"]) == 2 else Color(0.34, 1.12, 0.76, 0.95)
		var spikes: int = maxi(5, int(r.size.x / 16.0))
		var step: float = r.size.x / float(spikes)
		for s in range(spikes):
			var sx: float = r.position.x + float(s) * step
			var lean: float = -3.5 if s % 2 == 0 else 3.5
			var tri: PackedVector2Array = PackedVector2Array([
				Vector2(sx, r.end.y + 3.0),
				Vector2(sx + step * 0.5 + lean, r.position.y),
				Vector2(sx + step, r.end.y + 3.0)
			])
			canvas.draw_colored_polygon(tri, Color(0.068, 0.052, 0.112, 1.0))
			canvas.draw_polyline(PackedVector2Array([
				Vector2(sx + step * 0.22, r.position.y + r.size.y * 0.48),
				Vector2(sx + step * 0.5 + lean, r.position.y),
				Vector2(sx + step * 0.78, r.position.y + r.size.y * 0.48)
			]), col, 1.9, true)
	elif k == "monolith":
		# Cracked obsidian monolith spire with moonlight bevel & pulsing HDR magma-amber fault lines
		var spire: PackedVector2Array = PackedVector2Array([
			r.position + Vector2(6.0, r.size.y + 4.0),
			r.position + Vector2(-4.0, r.size.y * 0.62),
			r.position + Vector2(4.0, r.size.y * 0.20),
			r.position + Vector2(r.size.x * 0.36, -7.0),
			r.position + Vector2(r.size.x * 0.80, 4.0),
			r.position + Vector2(r.size.x + 3.0, r.size.y * 0.38),
			r.position + Vector2(r.size.x - 2.0, r.size.y + 4.0)
		])
		canvas.draw_colored_polygon(spire, Color(0.082, 0.094, 0.145, 1.0))
		var facet: PackedVector2Array = PackedVector2Array([
			r.position + Vector2(4.0, r.size.y * 0.20),
			r.position + Vector2(r.size.x * 0.36, -7.0),
			r.position + Vector2(r.size.x * 0.48, r.size.y * 0.52),
			r.position + Vector2(-4.0, r.size.y * 0.62)
		])
		canvas.draw_colored_polygon(facet, Color(0.135, 0.155, 0.225, 1.0))
		canvas.draw_polyline(PackedVector2Array([
			r.position + Vector2(4.0, r.size.y * 0.20),
			r.position + Vector2(r.size.x * 0.36, -7.0),
			r.position + Vector2(r.size.x * 0.80, 4.0)
		]), Color(0.76, 0.88, 0.98, 0.48), 1.6, true)
		var fault: PackedVector2Array = PackedVector2Array([
			r.position + Vector2(r.size.x * 0.40, 6.0),
			r.position + Vector2(r.size.x * 0.62, r.size.y * 0.34),
			r.position + Vector2(r.size.x * 0.28, r.size.y * 0.64),
			r.position + Vector2(r.size.x * 0.54, r.size.y - 4.0)
		])
		canvas.draw_polyline(fault, Color(1.0, 0.38, 0.0, 0.45 * pulse), 7.5, true)
		canvas.draw_polyline(fault, Color(1.25, 0.72, 0.08, 0.98 * pulse), 3.0, true)
		canvas.draw_line(r.position + Vector2(r.size.x * 0.62, r.size.y * 0.34), r.position + Vector2(r.size.x * 0.86, r.size.y * 0.48), Color(1.15, 0.54, 0.04, 0.92 * pulse), 2.0, true)
	elif k == "crystal_wall":
		var shards: Array[PackedVector2Array] = [
			PackedVector2Array([r.position + Vector2(0.0, r.size.y + 2.0), r.position + Vector2(8.0, r.size.y * 0.22), r.position + Vector2(22.0, r.size.y * 0.42), r.position + Vector2(20.0, r.size.y + 2.0)]),
			PackedVector2Array([r.position + Vector2(14.0, r.size.y + 2.0), r.position + Vector2(r.size.x * 0.50, -9.0), r.position + Vector2(r.size.x * 0.76, r.size.y * 0.26), r.position + Vector2(r.size.x * 0.68, r.size.y + 2.0)]),
			PackedVector2Array([r.position + Vector2(r.size.x * 0.56, r.size.y + 2.0), r.position + Vector2(r.size.x + 4.0, r.size.y * 0.30), r.position + Vector2(r.size.x + 2.0, r.size.y + 2.0)])
		]
		for sh in shards:
			canvas.draw_colored_polygon(sh, Color(0.32, 0.14, 0.04, 0.90))
			canvas.draw_polyline(sh, Color(1.25, 0.76, 0.14, 0.95 * pulse), 2.0, true)
		canvas.draw_line(r.position + Vector2(r.size.x * 0.50, -5.0), r.position + Vector2(r.size.x * 0.46, r.size.y * 0.88), Color(1.3, 0.92, 0.48, 0.88), 2.2, true)
	elif k == "fallen_log":
		var log_poly: PackedVector2Array = PackedVector2Array([
			r.position + Vector2(-4.0, r.size.y + 2.0),
			r.position + Vector2(4.0, 12.0),
			r.position + Vector2(r.size.x * 0.35, 2.0),
			r.position + Vector2(r.size.x * 0.78, 6.0),
			r.position + Vector2(r.size.x + 6.0, 18.0),
			r.position + Vector2(r.size.x - 2.0, r.size.y + 2.0)
		])
		canvas.draw_colored_polygon(log_poly, Color(0.115, 0.082, 0.080, 1.0))
		canvas.draw_polyline(PackedVector2Array([
			r.position + Vector2(6.0, 14.0),
			r.position + Vector2(r.size.x * 0.45, 6.0),
			r.position + Vector2(r.size.x * 0.82, 10.0)
		]), Color(0.24, 0.56, 0.44, 0.72), 2.8, true)
		canvas.draw_polyline(PackedVector2Array([
			r.position + Vector2(12.0, 16.0),
			r.position + Vector2(r.size.x * 0.52, r.size.y * 0.56),
			r.end - Vector2(12.0, 10.0)
		]), Color(1.2, 0.68, 0.04, 0.96 * pulse), 2.6, true)
	elif k == "high_platform" or k == "mossy_ledge":
		var rim: Color = Color(0.0, 1.08, 1.20, 0.95) if k == "high_platform" else Color(0.35, 1.15, 0.78, 0.95)
		var bough: PackedVector2Array = PackedVector2Array([
			r.position + Vector2(-6.0, 4.0),
			r.position + Vector2(8.0, 0.0),
			r.position + Vector2(r.size.x - 8.0, 0.0),
			r.position + Vector2(r.size.x + 6.0, 5.0),
			r.position + Vector2(r.size.x - 10.0, r.size.y + 4.0),
			r.position + Vector2(r.size.x * 0.5, r.size.y + 7.0),
			r.position + Vector2(12.0, r.size.y + 3.0)
		])
		canvas.draw_colored_polygon(bough, Color(0.048, 0.105, 0.160, 1.0))
		for m in range(4):
			var mx: float = r.position.x + 18.0 + float(m) * (r.size.x - 36.0) / 3.0
			var mlen: float = 11.0 + float(m % 2) * 8.0
			canvas.draw_line(Vector2(mx, r.end.y + 2.0), Vector2(mx + sin(time * 2.2 + float(m)) * 3.2, r.end.y + 2.0 + mlen), Color(0.12, 0.34, 0.38, 0.64), 1.8, true)
		canvas.draw_polyline(PackedVector2Array([
			r.position + Vector2(2.0, 1.0),
			Vector2(r.position.x + r.size.x * 0.5, r.position.y - 1.0),
			Vector2(r.end.x - 2.0, r.position.y + 1.0)
		]), rim, 3.2, true)
