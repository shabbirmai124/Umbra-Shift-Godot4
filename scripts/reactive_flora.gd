extends Node2D
class_name ReactiveFlora

## Interactive Spring-Damper Reactive Forest Foliage & Waystones
## - Botanical ferns, glowing reeds, and capped bioluminescent mushrooms physically bend away
##   from the player's velocity vector and recoil smoothly with spring-damper oscillation
## - Reacts to impact shockwaves (Pangolin slams, dashes, morph bursts)

var _time: float = 0.0
var _shock_x: float = -99999.0
var _shock_strength: float = 0.0

func trigger_shockwave(world_x: float, strength: float = 1.0) -> void:
	_shock_x = world_x
	_shock_strength = maxf(_shock_strength, strength)

func update_flora(dt: float, chunks: Array[Dictionary], player_pos: Vector2, player_vx: float) -> void:
	_time += dt
	_shock_strength = maxf(0.0, _shock_strength - dt * 2.8)
	var push_scale: float = clampf(player_vx / 520.0, 0.7, 1.6)
	for chunk in chunks:
		var dec_list: Array = chunk["decorations"]
		for dec_item in dec_list:
			var dec: Dictionary = dec_item
			var dk: String = String(dec["kind"])
			if dk == "totem":
				continue
			var fx: float = float(dec["x"])
			var fy: float = float(dec["y"])
			var angle: float = float(dec.get("bend_ang", 0.0))
			var ang_vel: float = float(dec.get("bend_vel", 0.0))
			var phase: float = float(dec["phase"])

			var wind_target: float = sin(_time * 2.3 + phase) * 0.14
			var dx: float = player_pos.x - fx
			var dy: float = absf(player_pos.y - fy)
			if absf(dx) < 96.0 and dy < 84.0:
				var proximity: float = 1.0 - absf(dx) / 96.0
				var dir_sign: float = 1.0 if dx < 0.0 else -1.0
				ang_vel += dir_sign * proximity * 26.0 * push_scale * dt
			if _shock_strength > 0.05:
				var sdx: float = fx - _shock_x
				if absf(sdx) < 220.0:
					var s_prox: float = (1.0 - absf(sdx) / 220.0) * _shock_strength
					ang_vel += (1.0 if sdx >= 0.0 else -1.0) * s_prox * 34.0 * dt

			# Lightweight spring-damper recoil physics
			var spring_k: float = 52.0
			var damping: float = 6.2
			var acc: float = (wind_target - angle) * spring_k - ang_vel * damping
			ang_vel += acc * dt
			angle = clampf(angle + ang_vel * dt, -1.15, 1.15)
			dec["bend_ang"] = angle
			dec["bend_vel"] = ang_vel

func draw_chunk_decorations(canvas: CanvasItem, chunk: Dictionary, flow_glow: float) -> void:
	var dec_list: Array = chunk["decorations"]
	for dec_item in dec_list:
		var dec: Dictionary = dec_item
		var fx: float = float(dec["x"])
		var fy: float = float(dec["y"])
		var dscale: float = float(dec["scale"])
		var dcol: Color = dec["color"]
		var dk: String = String(dec["kind"])
		var bend: float = float(dec.get("bend_ang", 0.0))

		if dk == "totem":
			var stone: PackedVector2Array = PackedVector2Array([
				Vector2(fx - 11.0, fy + 4.0),
				Vector2(fx - 8.0, fy - 36.0),
				Vector2(fx, fy - 48.0),
				Vector2(fx + 8.0, fy - 36.0),
				Vector2(fx + 11.0, fy + 4.0)
			])
			canvas.draw_colored_polygon(stone, Color(0.09, 0.145, 0.215, 1.0))
			canvas.draw_polyline(stone, Color(0.54, 0.78, 0.90, 0.50), 1.4, true)
			canvas.draw_circle(Vector2(fx, fy - 24.0), 15.0, Color(dcol.r, dcol.g, dcol.b, 0.15 * flow_glow))
			var rune: PackedVector2Array = PackedVector2Array([
				Vector2(fx, fy - 35.0),
				Vector2(fx - 4.8, fy - 24.0),
				Vector2(fx, fy - 14.0),
				Vector2(fx + 4.8, fy - 24.0),
				Vector2(fx, fy - 35.0)
			])
			canvas.draw_polyline(rune, Color(dcol.r * 1.15, dcol.g * 1.15, dcol.b * 1.15, 0.95), 2.4, true)
		elif dk == "mushroom":
			var mh: float = 13.5 * dscale
			var stem_mid: Vector2 = Vector2(fx - 1.5 * dscale + bend * 4.0, fy - mh * 0.5)
			var cap_c: Vector2 = Vector2(fx + bend * 8.0, fy - mh)
			canvas.draw_polyline(PackedVector2Array([Vector2(fx, fy + 2.0), stem_mid, cap_c]), Color(0.76, 0.86, 0.90, 0.90), 2.8 * dscale, true)
			canvas.draw_circle(cap_c, 14.0 * dscale, Color(dcol.r, dcol.g, dcol.b, 0.16 * flow_glow))
			var cap_poly: PackedVector2Array = PackedVector2Array([
				cap_c + Vector2(-9.5, 1.5) * dscale,
				cap_c + Vector2(-7.0, -4.5) * dscale,
				cap_c + Vector2(0.0, -7.4) * dscale,
				cap_c + Vector2(7.0, -4.5) * dscale,
				cap_c + Vector2(9.5, 1.5) * dscale
			])
			canvas.draw_colored_polygon(cap_poly, dcol.lerp(Color(0.18, 0.28, 0.36), 0.22))
			canvas.draw_polyline(PackedVector2Array([
				cap_c + Vector2(-6.0, -4.0) * dscale,
				cap_c + Vector2(0.0, -7.0) * dscale,
				cap_c + Vector2(6.0, -4.0) * dscale
			]), Color(0.96, 1.0, 0.98, 0.78), 1.4, true)
		else:
			var base_p: Vector2 = Vector2(fx, fy + 2.0)
			for f_i in range(-1, 2):
				var f_ang: float = bend + float(f_i) * 0.38
				var flen: float = (23.0 if f_i == 0 else 16.5) * dscale
				var mid_p: Vector2 = base_p + Vector2(sin(f_ang * 0.7) * flen * 0.55, -cos(f_ang * 0.7) * flen * 0.55)
				var tip: Vector2 = base_p + Vector2(sin(f_ang) * flen, -cos(f_ang) * flen)
				var f_col: Color = Color(0.15, 0.48, 0.44, 0.96) if f_i == 0 else Color(0.10, 0.36, 0.38, 0.88)
				canvas.draw_polyline(PackedVector2Array([base_p, mid_p, tip]), f_col, 2.5 if f_i == 0 else 1.8, true)
				if f_i == 0:
					canvas.draw_circle(tip, 5.5, Color(dcol.r, dcol.g, dcol.b, 0.22 * flow_glow))
					canvas.draw_circle(tip, 2.3, Color(dcol.r * 1.15, dcol.g * 1.15, dcol.b * 1.15, 0.95))
