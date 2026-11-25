extends Node2D
class_name ReactiveFlora

## Spring-Damper Physics Interactive Forest Flora
## Renders lush botanical ferns, glowing reeds, capped bioluminescent mushrooms,
## and carved waystone totems that bend physically away from player velocity and shockwaves.

var _time: float = 0.0
var _shockwave_x: float = -99999.0
var _shockwave_power: float = 0.0

func trigger_shockwave(world_x: float, power: float = 1.2) -> void:
	_shockwave_x = world_x
	_shockwave_power = power

func step_flora(dt: float, chunks: Array[Dictionary], player_pos: Vector2, player_vx: float) -> void:
	_time += dt
	_shockwave_power = maxf(0.0, _shockwave_power - dt * 2.8)
	var wind_speed: float = clampf(player_vx / 520.0, 0.6, 1.8)
	for chunk in chunks:
		var decs: Array = chunk["decorations"]
		for item in decs:
			var d: Dictionary = item
			var dk: String = String(d["kind"])
			if dk != "fern" and dk != "reed":
				continue
			var fx: float = float(d["x"])
			var fy: float = float(d["y"])
			var bend: float = float(d.get("bend", 0.0))
			var bend_v: float = float(d.get("bend_v", 0.0))
			var target: float = sin(_time * 2.3 + float(d["phase"])) * 0.14
			var dx: float = player_pos.x - fx
			var dy: float = absf(player_pos.y - fy)
			if absf(dx) < 105.0 and dy < 88.0:
				var prox: float = 1.0 - absf(dx) / 105.0
				var push_dir: float = -1.0 if dx >= 0.0 else 1.0
				target += push_dir * prox * 0.92 * wind_speed
			if _shockwave_power > 0.02:
				var sdx: float = fx - _shockwave_x
				if absf(sdx) < 220.0:
					var sp: float = (1.0 - absf(sdx) / 220.0) * _shockwave_power
					target += (1.0 if sdx >= 0.0 else -1.0) * sp * 0.85
			# Spring-damper integration
			var spring_f: float = (target - bend) * 44.0 - bend_v * 7.5
			bend_v += spring_f * dt
			bend = clampf(bend + bend_v * dt, -1.25, 1.25)
			d["bend"] = bend
			d["bend_v"] = bend_v

func draw_chunk_flora(canvas: CanvasItem, chunk: Dictionary) -> void:
	var decs: Array = chunk["decorations"]
	for item in decs:
		var dec: Dictionary = item
		var fx: float = float(dec["x"])
		var fy: float = float(dec["y"])
		var dscale: float = float(dec["scale"])
		var dcol: Color = dec["color"]
		var dk: String = String(dec["kind"])
		if dk == "totem":
			var stone: PackedVector2Array = PackedVector2Array([
				Vector2(fx - 12.0, fy + 4.0),
				Vector2(fx - 9.0, fy - 38.0),
				Vector2(fx, fy - 52.0),
				Vector2(fx + 9.0, fy - 38.0),
				Vector2(fx + 12.0, fy + 4.0)
			])
			canvas.draw_colored_polygon(stone, Color(0.20, 0.26, 0.33, 1.0))
			canvas.draw_polyline(stone, Color(0.62, 0.82, 0.92, 0.56), 1.6, true)
			canvas.draw_circle(Vector2(fx, fy - 25.0), 16.0, Color(dcol.r, dcol.g, dcol.b, 0.16))
			var rune: PackedVector2Array = PackedVector2Array([
				Vector2(fx, fy - 38.0),
				Vector2(fx - 5.2, fy - 25.0),
				Vector2(fx, fy - 14.0),
				Vector2(fx + 5.2, fy - 25.0),
				Vector2(fx, fy - 38.0)
			])
			canvas.draw_polyline(rune, dcol, 2.5, true)
		elif dk == "mushroom":
			var mh: float = 14.0 * dscale
			var stem_mid: Vector2 = Vector2(fx - 1.8 * dscale, fy - mh * 0.5)
			var cap_c: Vector2 = Vector2(fx, fy - mh)
			canvas.draw_polyline(PackedVector2Array([Vector2(fx, fy + 2.0), stem_mid, cap_c]), Color(0.86, 0.88, 0.84, 0.95), 3.0 * dscale, true)
			canvas.draw_circle(cap_c, 14.0 * dscale, Color(dcol.r, dcol.g, dcol.b, 0.16))
			var cap_poly: PackedVector2Array = PackedVector2Array([
				cap_c + Vector2(-10.5, 1.8) * dscale,
				cap_c + Vector2(-7.5, -4.8) * dscale,
				cap_c + Vector2(0.0, -7.8) * dscale,
				cap_c + Vector2(7.5, -4.8) * dscale,
				cap_c + Vector2(10.5, 1.8) * dscale
			])
			canvas.draw_colored_polygon(cap_poly, dcol.lerp(Color(0.22, 0.34, 0.38), 0.18))
			canvas.draw_polyline(PackedVector2Array([
				cap_c + Vector2(-6.5, -4.2) * dscale,
				cap_c + Vector2(0.0, -7.2) * dscale,
				cap_c + Vector2(6.5, -4.2) * dscale
			]), Color(0.98, 1.0, 0.96, 0.82), 1.6, true)
		else:
			var bend: float = float(dec.get("bend", 0.0))
			var base_p: Vector2 = Vector2(fx, fy + 2.0)
			for f_i in range(-1, 2):
				var f_ang: float = bend + float(f_i) * 0.38
				var flen: float = (24.0 if f_i == 0 else 17.0) * dscale
				var mid_p: Vector2 = base_p + Vector2(sin(f_ang * 0.68) * flen * 0.54, -cos(f_ang * 0.68) * flen * 0.54)
				var tip: Vector2 = base_p + Vector2(sin(f_ang) * flen, -cos(f_ang) * flen)
				var f_col: Color = Color(0.20, 0.58, 0.44, 0.98) if f_i == 0 else Color(0.14, 0.46, 0.38, 0.92)
				canvas.draw_polyline(PackedVector2Array([base_p, mid_p, tip]), f_col, 2.6 if f_i == 0 else 2.0, true)
				if f_i == 0:
					canvas.draw_circle(tip, 5.6, Color(dcol.r, dcol.g, dcol.b, 0.22))
					canvas.draw_circle(tip, 2.4, dcol)
