extends Node2D
class_name PangolinRenderer

## Ultra-Detailed Realistic Armored Bronze-Keratin & Molten Amber Pangolin Renderer
## Hand-crafted natural-wildlife coloration & dual-state morphing animation:
## - Natural burnished bronze-chestnut, umber, and sunlit ochre-tan imbricated diamond scales
## - Warm earthy tan soft belly, articulated conical snout, natural periodic blink, curved ivory digging claws
## - Velocity-reactive glowing molten amber fissures shining between every overlapping scale row

const COL_SCALE_DARK: Color = Color(0.30, 0.22, 0.18, 1.0)
const COL_SCALE_MID: Color = Color(0.50, 0.37, 0.28, 1.0)
const COL_SCALE_LIGHT: Color = Color(0.72, 0.56, 0.42, 1.0)
const COL_SKIN_WARM: Color = Color(0.58, 0.46, 0.38, 1.0)
const COL_COPPER_RIM: Color = Color(0.95, 0.88, 0.76, 0.82)
const COL_CLAW: Color = Color(0.95, 0.90, 0.78, 0.98)

var gait_phase: float = 0.0
var is_curled: bool = false
var is_slamming: bool = false
var roll_angle: float = 0.0
var heat: float = 0.4
var morph_ratio: float = 0.0
var curl_blend: float = 0.0
var _time: float = 0.0

func sync_state(p_gait: float, p_curled: bool, p_slam: bool, p_roll: float, p_heat: float, p_morph: float, dt: float) -> void:
	_time += dt
	gait_phase = p_gait
	is_curled = p_curled
	is_slamming = p_slam
	roll_angle = p_roll
	heat = clampf(p_heat, 0.3, 1.0)
	morph_ratio = p_morph
	var target_curl: float = 1.0 if (is_curled or is_slamming) else 0.0
	curl_blend = lerpf(curl_blend, target_curl, minf(1.0, dt * 16.0))
	queue_redraw()

func _draw_soft_ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(16):
		var ang: float = (float(i) / 16.0) * TAU
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_colored_polygon(pts, col)

func _draw() -> void:
	var pulse: float = 0.86 + sin(_time * 13.0) * 0.14
	var amber: Color = Color(1.0, lerpf(0.62, 0.30, heat), 0.06, clampf(heat * pulse, 0.56, 1.0))
	var magma_hot: Color = Color(1.0, lerpf(0.90, 0.66, heat), 0.34, clampf(heat * 0.96, 0.60, 1.0))

	if curl_blend >= 0.52 or is_slamming:
		_draw_curled_sphere(amber, magma_hot)
		return

	var bob: float = absf(sin(gait_phase * 0.72)) * -2.8
	var stride: float = gait_phase * 0.72
	var tuck_x: float = lerpf(1.0, 0.78, curl_blend * 1.9)
	var tuck_y: float = lerpf(1.0, 1.16, curl_blend * 1.9)

	_draw_soft_ellipse(Vector2(0.0, 1.6), 25.5, 3.8, Color(0.02, 0.04, 0.06, 0.44))
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2(tuck_x, tuck_y))

	# Heavy counterbalancing armored tail with 6 beveled bronze scales
	var tail_sway: float = sin(stride) * 2.4
	var tail_base: PackedVector2Array = PackedVector2Array([
		Vector2(-13.0, -15.5),
		Vector2(-26.0, -16.5 + tail_sway * 0.4),
		Vector2(-41.0, -11.5 + tail_sway * 0.8),
		Vector2(-48.5, -6.5 + tail_sway),
		Vector2(-39.0, -3.5 + tail_sway * 0.8),
		Vector2(-24.0, -4.5 + tail_sway * 0.4),
		Vector2(-13.0, -7.0)
	])
	draw_colored_polygon(tail_base, COL_SCALE_DARK)
	draw_polyline(PackedVector2Array([
		Vector2(-15.0, -11.0), Vector2(-28.0, -10.5 + tail_sway * 0.5), Vector2(-43.0, -7.2 + tail_sway * 0.85)
	]), amber * Color(1, 1, 1, 0.72), 1.8, true)
	for t in range(6):
		var frac: float = float(t) / 5.0
		var tx: float = lerpf(-17.0, -44.0, frac)
		var ty: float = lerpf(-13.2, -7.4 + tail_sway, frac)
		_draw_scale_plate(Vector2(tx, ty), lerpf(8.8, 4.6, frac), lerpf(6.0, 3.4, frac), -0.22 + frac * 0.12, amber, magma_hot)

	# Far stout digging limbs
	_draw_armored_limb(-10.5, stride + PI, false, true, amber)
	_draw_armored_limb(10.5, stride, true, true, amber)

	# Molten amber core gleaming softly beneath overlapping keratin plates
	var magma_core: PackedVector2Array = PackedVector2Array([
		Vector2(-18.0, -12.5), Vector2(-11.0, -25.0), Vector2(3.5, -31.0),
		Vector2(18.5, -22.5), Vector2(28.0, -12.5), Vector2(22.0, -7.5), Vector2(-17.5, -9.5)
	])
	draw_colored_polygon(magma_core, Color(1.0, 0.48, 0.04, 0.76 * amber.a))

	# Warm earthy soft underbelly & conical pangolin snout
	var body: PackedVector2Array = PackedVector2Array([
		Vector2(-17.0, -11.5), Vector2(-10.0, -23.5), Vector2(3.5, -29.0),
		Vector2(17.5, -20.8), Vector2(24.0, -15.6), Vector2(29.8, -11.0),
		Vector2(26.6, -8.2), Vector2(18.5, -7.8), Vector2(-16.5, -9.2)
	])
	draw_colored_polygon(body, COL_SKIN_WARM)

	# 3 staggered overlapping rows of realistic diamond keratin scales
	var dorsal_pos: PackedVector2Array = PackedVector2Array([
		Vector2(-14.5, -18.5), Vector2(-8.2, -23.8), Vector2(-0.5, -26.8),
		Vector2(7.5, -25.8), Vector2(14.5, -22.0), Vector2(20.2, -17.2)
	])
	var dorsal_ang: PackedFloat32Array = PackedFloat32Array([-0.44, -0.26, -0.05, 0.16, 0.36, 0.52])
	for i in range(dorsal_pos.size()):
		_draw_scale_plate(dorsal_pos[i], 9.8, 6.8, dorsal_ang[i], amber, magma_hot)

	var mid_pos: PackedVector2Array = PackedVector2Array([
		Vector2(-13.0, -14.2), Vector2(-5.5, -18.8), Vector2(2.5, -20.6),
		Vector2(10.5, -19.2), Vector2(17.2, -15.5)
	])
	var mid_ang: PackedFloat32Array = PackedFloat32Array([-0.34, -0.14, 0.06, 0.24, 0.42])
	for i in range(mid_pos.size()):
		_draw_scale_plate(mid_pos[i], 9.4, 6.4, mid_ang[i], amber, magma_hot)

	var flank_pos: PackedVector2Array = PackedVector2Array([
		Vector2(-10.0, -11.0), Vector2(-1.8, -13.6),
		Vector2(6.5, -13.6), Vector2(14.0, -11.6)
	])
	var flank_ang: PackedFloat32Array = PackedFloat32Array([-0.20, -0.02, 0.14, 0.30])
	for i in range(flank_pos.size()):
		_draw_scale_plate(flank_pos[i], 8.8, 5.8, flank_ang[i], amber, magma_hot)

	# Armored brow scale, dark nose tip, rounded ear & natural blinking eye
	_draw_scale_plate(Vector2(23.2, -13.4), 6.2, 4.4, 0.56, amber, magma_hot)
	draw_circle(Vector2(19.0, -14.8), 2.2, COL_SCALE_DARK)
	draw_circle(Vector2(29.2, -10.6), 1.4, Color(0.14, 0.10, 0.10, 1.0))
	draw_polyline(PackedVector2Array([Vector2(18.0, -16.8), Vector2(23.5, -15.2), Vector2(29.2, -11.0)]), COL_COPPER_RIM, 1.4, true)

	var eye: Vector2 = Vector2(21.4, -13.2)
	var blink_cycle: float = fposmod(_time + 1.2, 4.1)
	if blink_cycle > 3.98:
		draw_line(eye + Vector2(-2.2, 0.2), eye + Vector2(2.4, 0.3), COL_SCALE_DARK, 1.5, true)
	else:
		var eye_slit: PackedVector2Array = PackedVector2Array([
			eye + Vector2(-2.4, -0.8), eye + Vector2(1.0, -1.6), eye + Vector2(2.8, 0.5), eye + Vector2(-0.8, 1.2)
		])
		draw_colored_polygon(eye_slit, Color(1.0, 0.76, 0.18, 1.0))
		draw_circle(eye + Vector2(0.5, -0.2), 1.0, Color(1.0, 0.98, 0.84, 1.0))

	# Near armored digging limbs with 3 curved ivory claws
	_draw_armored_limb(-11.5, stride, false, false, amber)
	_draw_armored_limb(9.5, stride + PI, true, false, amber)

	if morph_ratio > 0.02:
		draw_arc(Vector2(2.0, -16.0), 26.0 + (1.0 - morph_ratio) * 12.0, 0.0, TAU, 32, Color(1.0, 0.62, 0.0, morph_ratio * 0.85), 2.2, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_armored_limb(lx: float, phase: float, is_front: bool, is_far: bool, amber: Color) -> void:
	var swing: float = sin(phase) * 5.8
	var lift: float = maxf(0.0, -cos(phase)) * 4.4
	var ox: float = lx + swing * 0.45
	var oy: float = -lift * 0.55

	var limb: PackedVector2Array = PackedVector2Array([
		Vector2(ox - 4.8, -13.5 + oy),
		Vector2(ox + 4.4, -13.0 + oy),
		Vector2(ox + 5.2, -2.5 + oy),
		Vector2(ox - 3.6, -1.5 + oy)
	])
	draw_colored_polygon(limb, COL_SCALE_DARK if is_far else COL_SCALE_MID)
	if not is_far:
		draw_line(Vector2(ox - 3.5, -12.5 + oy), Vector2(ox + 3.5, -12.2 + oy), COL_COPPER_RIM, 1.2, true)
		draw_line(Vector2(ox - 3.2, -7.2 + oy), Vector2(ox + 4.2, -6.8 + oy), amber * Color(1, 1, 1, 0.78), 1.3, true)

	var claw_a: float = 0.58 if is_far else 0.98
	var claw_col: Color = Color(COL_CLAW.r, COL_CLAW.g, COL_CLAW.b, claw_a)
	var claw_len: float = 6.8 if is_front else 4.8
	for c in range(3):
		var cy: float = -3.6 + float(c) * 1.4 + oy
		var c0: Vector2 = Vector2(ox + 3.8, cy)
		var c1: Vector2 = Vector2(ox + 3.8 + claw_len * 0.62, cy + 0.5)
		var c2: Vector2 = Vector2(ox + 3.8 + claw_len, cy + 2.4)
		draw_polyline(PackedVector2Array([c0, c1, c2]), claw_col, 1.6 if c == 1 else 1.2, true)

func _draw_scale_plate(pos: Vector2, w: float, h: float, angle: float, amber: Color, hot: Color) -> void:
	draw_set_transform(pos, angle, Vector2.ONE)
	draw_polyline(PackedVector2Array([Vector2(-w * 0.54, 1.0), Vector2(0.0, h * 0.62), Vector2(w * 0.54, 0.6)]), amber, 1.9, true)
	draw_line(Vector2(-w * 0.24, h * 0.40), Vector2(w * 0.24, h * 0.40), hot * Color(1, 1, 1, 0.72), 1.0, true)

	var plate: PackedVector2Array = PackedVector2Array([
		Vector2(-w * 0.54, 0.0), Vector2(0.0, -h * 0.58), Vector2(w * 0.54, 0.0), Vector2(0.0, h * 0.48)
	])
	draw_colored_polygon(plate, COL_SCALE_MID)

	var upper_facet: PackedVector2Array = PackedVector2Array([
		Vector2(-w * 0.48, -0.2), Vector2(0.0, -h * 0.52), Vector2(w * 0.48, -0.2), Vector2(0.0, -h * 0.08)
	])
	draw_colored_polygon(upper_facet, COL_SCALE_LIGHT)
	draw_line(Vector2(0.0, -h * 0.50), Vector2(0.0, h * 0.34), COL_SCALE_DARK * Color(1, 1, 1, 0.65), 1.0, true)
	draw_polyline(PackedVector2Array([Vector2(-w * 0.46, -0.4), Vector2(0.0, -h * 0.52), Vector2(w * 0.46, -0.4)]), COL_COPPER_RIM, 1.25, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_curled_sphere(amber: Color, magma_hot: Color) -> void:
	var r: float = 20.5
	var center: Vector2 = Vector2(0.0, -r)

	_draw_soft_ellipse(Vector2(0.0, 1.6), 22.5, 3.8, Color(0.02, 0.04, 0.06, 0.44))

	if is_slamming:
		for s in range(5):
			var sx: float = -14.0 + float(s) * 7.0
			var h_flame: float = 36.0 + (12.0 if s == 2 else 0.0)
			draw_line(Vector2(sx, center.y - 6.0), Vector2(sx * 0.7, center.y - r - h_flame), Color(1.0, 0.62, 0.10, 0.72), 3.4, true)
	else:
		for s in range(4):
			var sy: float = center.y - 12.0 + float(s) * 8.0
			var slen: float = 34.0 + heat * 24.0 + float(s % 2) * 8.0
			draw_line(Vector2(-slen, sy), Vector2(-6.0, sy), Color(1.0, 0.56, 0.06, 0.48 * heat), 2.8, true)

	draw_set_transform(center, roll_angle, Vector2.ONE)

	draw_circle(Vector2.ZERO, r - 0.6, amber)
	draw_circle(Vector2.ZERO, r - 4.2, magma_hot * Color(1, 1, 1, 0.85))

	var plates: int = 12
	for i in range(plates):
		var ang: float = (float(i) / float(plates)) * TAU
		var c: float = cos(ang)
		var s: float = sin(ang)
		var poly: PackedVector2Array = PackedVector2Array([
			_rot2(Vector2(5.5, -5.2), c, s),
			_rot2(Vector2(r + 2.4, -1.6), c, s),
			_rot2(Vector2(r + 0.4, 4.4), c, s),
			_rot2(Vector2(6.0, 4.8), c, s)
		])
		draw_colored_polygon(poly, COL_SCALE_LIGHT if i % 2 == 0 else COL_SCALE_MID)
		draw_line(_rot2(Vector2(7.0, -4.6), c, s), _rot2(Vector2(r + 2.0, -1.6), c, s), COL_COPPER_RIM, 1.25, true)
		draw_line(_rot2(Vector2(6.2, 4.4), c, s), _rot2(Vector2(r - 1.2, 3.8), c, s), amber, 1.6, true)

	draw_circle(Vector2.ZERO, 8.8, COL_SCALE_DARK)
	draw_arc(Vector2.ZERO, 8.6, 0.25, PI * 1.72, 20, amber, 2.0, true)
	draw_arc(Vector2.ZERO, 5.0, 1.1, PI * 2.1, 14, magma_hot, 1.5, true)
	draw_circle(Vector2.ZERO, 2.4, COL_SCALE_MID)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _rot2(v: Vector2, c: float, s: float) -> Vector2:
	return Vector2(v.x * c - v.y * s, v.x * s + v.y * c)
