extends Node2D
class_name PangolinRenderer

## High-Detail Procedural Armored Pangolin Renderer (#FF9E00 to #FF4500 Magma Amber)
## 100% pure Godot 4 _draw() anatomy:
## - Running form: heavy 6-plate armored counterbalance tail, 3 staggered overlapping rows of
##   faceted weathered-basalt diamond keratin scales with moonlight bevels & blazing magma fissures,
##   armored conical snout, glowing slit eye, and stout digging limbs with 3 curved claws
## - Curled sphere form: 12 interlocking saw-tooth volcanic armor plates spinning around a
##   magma core with concentric curled inner tail hub, trailing ember arcs, and Meteor Slam flames

const COLOR_BASALT := Color(0.132, 0.146, 0.204, 1.0)
const COLOR_BASALT_LIGHT := Color(0.185, 0.205, 0.278, 1.0)
const COLOR_BASALT_DARK := Color(0.078, 0.086, 0.126, 1.0)
const COLOR_BEVEL := Color(0.86, 0.91, 0.98, 0.52)
const COLOR_CLAW := Color(1.0, 0.78, 0.42, 0.96)

var gait_phase: float = 0.0
var is_curled: bool = false
var is_slamming: bool = false
var roll_angle: float = 0.0
var heat: float = 0.4
var morph_ratio: float = 0.0
var _time: float = 0.0

func sync_state(p_gait: float, p_curled: bool, p_slam: bool, p_roll: float, p_heat: float, p_morph: float, dt: float) -> void:
	_time += dt
	gait_phase = p_gait
	is_curled = p_curled
	is_slamming = p_slam
	roll_angle = p_roll
	heat = clampf(p_heat, 0.28, 1.0)
	morph_ratio = p_morph
	queue_redraw()

func _draw() -> void:
	var pulse := 0.86 + sin(_time * 13.0) * 0.14
	var amber := Color(1.0, lerpf(0.64, 0.28, heat), 0.0, clampf(heat * pulse, 0.4, 1.0))
	var magma_hot := Color(1.0, lerpf(0.84, 0.56, heat), 0.24, clampf(heat * 0.95, 0.45, 1.0))

	if is_curled or is_slamming:
		_draw_curled_sphere(amber, magma_hot)
		return

	var bob := absf(sin(gait_phase * 0.72)) * -2.4
	var stride := gait_phase * 0.72
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)

	# Warm magma ground-bounce aura
	draw_circle(Vector2(2.0, -14.0), 26.0, Color(1.0, 0.52, 0.0, 0.08 * heat))

	# Heavy counterbalancing armored tail with 6 overlapping beveled plates
	var tail_sway := sin(stride) * 2.2
	var tail_base := PackedVector2Array([
		Vector2(-13.0, -15.5),
		Vector2(-26.0, -16.5 + tail_sway * 0.4),
		Vector2(-41.0, -11.5 + tail_sway * 0.8),
		Vector2(-48.5, -6.5 + tail_sway),
		Vector2(-39.0, -3.5 + tail_sway * 0.8),
		Vector2(-24.0, -4.5 + tail_sway * 0.4),
		Vector2(-13.0, -7.0)
	])
	draw_colored_polygon(tail_base, COLOR_BASALT_DARK)
	draw_polyline(PackedVector2Array([
		Vector2(-15.0, -11.0), Vector2(-28.0, -10.5 + tail_sway * 0.5), Vector2(-43.0, -7.2 + tail_sway * 0.85)
	]), amber * Color(1, 1, 1, 0.65), 1.8, true)
	for t in range(6):
		var frac := float(t) / 5.0
		var tx := lerpf(-17.0, -44.0, frac)
		var ty := lerpf(-13.2, -7.4 + tail_sway, frac)
		_draw_scale_plate(Vector2(tx, ty), lerpf(8.8, 4.6, frac), lerpf(6.0, 3.4, frac), -0.22 + frac * 0.12, amber, magma_hot)

	# Far stout digging limbs with curved claws
	_draw_armored_limb(-10.5, stride + PI, false, true, amber)
	_draw_armored_limb(10.5, stride, true, true, amber)

	# Molten under-fissure core peeking between carapace plates
	var magma_core := PackedVector2Array([
		Vector2(-18.0, -12.5), Vector2(-11.0, -25.0), Vector2(3.5, -31.0),
		Vector2(18.5, -22.5), Vector2(28.0, -12.5), Vector2(22.0, -7.5), Vector2(-17.5, -9.5)
	])
	draw_colored_polygon(magma_core, Color(1.0, 0.46, 0.0, 0.78 * amber.a))

	# Weathered basalt arched carapace body & downward-sloping conical snout
	var body := PackedVector2Array([
		Vector2(-17.0, -11.5), Vector2(-10.0, -23.5), Vector2(3.5, -29.0),
		Vector2(17.5, -20.8), Vector2(24.0, -15.6), Vector2(29.2, -11.2),
		Vector2(26.2, -8.5), Vector2(18.5, -8.0), Vector2(-16.5, -9.5)
	])
	draw_colored_polygon(body, COLOR_BASALT_DARK)

	# 3 staggered overlapping rows of faceted diamond keratin scales (15 body plates)
	var dorsal_scales := [
		[Vector2(-14.5, -18.5), -0.44], [Vector2(-8.2, -23.8), -0.26], [Vector2(-0.5, -26.8), -0.05],
		[Vector2(7.5, -25.8), 0.16], [Vector2(14.5, -22.0), 0.36], [Vector2(20.2, -17.2), 0.52]
	]
	for sc in dorsal_scales:
		_draw_scale_plate(sc[0], 9.8, 6.8, sc[1], amber, magma_hot)

	var mid_scales := [
		[Vector2(-13.0, -14.2), -0.34], [Vector2(-5.5, -18.8), -0.14], [Vector2(2.5, -20.6), 0.06],
		[Vector2(10.5, -19.2), 0.24], [Vector2(17.2, -15.5), 0.42]
	]
	for sc in mid_scales:
		_draw_scale_plate(sc[0], 9.4, 6.4, sc[1], amber, magma_hot)

	var flank_scales := [
		[Vector2(-10.0, -11.0), -0.20], [Vector2(-1.8, -13.6), -0.02],
		[Vector2(6.5, -13.6), 0.14], [Vector2(14.0, -11.6), 0.30]
	]
	for sc in flank_scales:
		_draw_scale_plate(sc[0], 8.8, 5.8, sc[1], amber, magma_hot)

	# Tight cephalic head scales, armored brow ridge & magma slit eye
	_draw_scale_plate(Vector2(23.5, -13.2), 6.2, 4.4, 0.56, amber, magma_hot)
	draw_polyline(PackedVector2Array([Vector2(18.0, -16.8), Vector2(23.5, -15.2), Vector2(28.8, -11.2)]), COLOR_BEVEL, 1.3, true)
	draw_circle(Vector2(27.5, -10.8), 1.1, Color(1.0, 0.62, 0.12, 0.75))

	var eye := Vector2(21.2, -13.2)
	draw_circle(eye, 5.0, Color(1.0, 0.56, 0.0, 0.34))
	var eye_slit := PackedVector2Array([
		eye + Vector2(-2.4, -0.8), eye + Vector2(1.0, -1.6), eye + Vector2(2.8, 0.5), eye + Vector2(-0.8, 1.2)
	])
	draw_colored_polygon(eye_slit, Color(1.0, 0.68, 0.12, 1.0))
	draw_circle(eye + Vector2(0.4, -0.2), 0.95, Color(1.0, 0.96, 0.78, 1.0))

	# Near armored digging limbs with 3 gleaming curved claws
	_draw_armored_limb(-11.5, stride, false, false, amber)
	_draw_armored_limb(9.5, stride + PI, true, false, amber)

	if morph_ratio > 0.01:
		draw_arc(Vector2(2.0, -16.0), 27.0 + (1.0 - morph_ratio) * 8.0, 0.0, TAU, 32, Color(1.0, 0.62, 0.0, morph_ratio * 0.9), 2.8, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_armored_limb(lx: float, phase: float, is_front: bool, is_far: bool, amber: Color) -> void:
	var swing := sin(phase) * 5.8
	var lift := maxf(0.0, -cos(phase)) * 4.4
	var ox := lx + swing * 0.45
	var oy := -lift * 0.55

	# Upper armored forearm & lower foot
	var limb := PackedVector2Array([
		Vector2(ox - 4.8, -13.5 + oy),
		Vector2(ox + 4.4, -13.0 + oy),
		Vector2(ox + 5.2, -2.5 + oy),
		Vector2(ox - 3.6, -1.5 + oy)
	])
	draw_colored_polygon(limb, COLOR_BASALT_DARK if is_far else COLOR_BASALT)
	if not is_far:
		draw_line(Vector2(ox - 3.5, -12.5 + oy), Vector2(ox + 3.5, -12.2 + oy), COLOR_BEVEL * Color(1, 1, 1, 0.7), 1.1, true)
		draw_line(Vector2(ox - 3.2, -7.2 + oy), Vector2(ox + 4.2, -6.8 + oy), amber * Color(1, 1, 1, 0.75), 1.2, true)

	# 3 long curved metallic-amber digging claws (prominent on forelimbs)
	var claw_col := Color(COLOR_CLAW.r, COLOR_CLAW.g, COLOR_CLAW.b, 0.52 if is_far else 0.96)
	var claw_len := 6.6 if is_front else 4.6
	for c in range(3):
		var cy := -3.6 + float(c) * 1.4 + oy
		var c0 := Vector2(ox + 3.8, cy)
		var c1 := Vector2(ox + 3.8 + claw_len * 0.62, cy + 0.5)
		var c2 := Vector2(ox + 3.8 + claw_len, cy + 2.4)
		draw_polyline(PackedVector2Array([c0, c1, c2]), claw_col, 1.5 if c == 1 else 1.15, true)

func _draw_scale_plate(pos: Vector2, w: float, h: float, angle: float, amber: Color, hot: Color) -> void:
	draw_set_transform(pos, angle, Vector2.ONE)
	# Glowing molten magma fissure peeking under overlapping plate edge
	draw_polyline(PackedVector2Array([Vector2(-w * 0.56, 1.0), Vector2(0.0, h * 0.66), Vector2(w * 0.56, 0.6)]), amber, 1.9, true)
	draw_line(Vector2(-w * 0.25, h * 0.42), Vector2(w * 0.25, h * 0.42), hot * Color(1, 1, 1, 0.72), 1.0, true)

	# Faceted weathered-basalt diamond keratin scale
	var plate := PackedVector2Array([
		Vector2(-w * 0.54, 0.0), Vector2(0.0, -h * 0.58), Vector2(w * 0.54, 0.0), Vector2(0.0, h * 0.48)
	])
	draw_colored_polygon(plate, COLOR_BASALT)

	# Upper facet catchlight & center keel ridge for sculpted 3D relief
	var upper_facet := PackedVector2Array([
		Vector2(-w * 0.50, -0.2), Vector2(0.0, -h * 0.54), Vector2(w * 0.50, -0.2), Vector2(0.0, -h * 0.08)
	])
	draw_colored_polygon(upper_facet, COLOR_BASALT_LIGHT)
	draw_line(Vector2(0.0, -h * 0.52), Vector2(0.0, h * 0.36), COLOR_BASALT_DARK * Color(1, 1, 1, 0.65), 0.9, true)

	# Crisp moonlight bevel rim along leading top crest
	draw_polyline(PackedVector2Array([Vector2(-w * 0.48, -0.4), Vector2(0.0, -h * 0.54), Vector2(w * 0.48, -0.4)]), COLOR_BEVEL, 1.15, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_curled_sphere(amber: Color, magma_hot: Color) -> void:
	var r := 20.5
	var center := Vector2(0.0, -r)

	# Ambient volcanic heat glow halo
	draw_circle(center, r + 11.0, Color(1.0, 0.48, 0.0, 0.14 * heat))

	# Meteor Slam downward blazing comet streaks
	if is_slamming:
		for s in range(5):
			var sx := -14.0 + float(s) * 7.0
			var h_flame := 34.0 + (12.0 if s == 2 else 0.0)
			draw_line(Vector2(sx, center.y - 6.0), Vector2(sx * 0.7, center.y - r - h_flame), Color(1.0, 0.58, 0.08, 0.62), 3.4, true)
	else:
		# Rotational magma-amber speed streaks behind high-speed rolling boulder
		for s in range(4):
			var sy := center.y - 12.0 + float(s) * 8.0
			var slen := 34.0 + heat * 24.0 + float(s % 2) * 8.0
			draw_line(Vector2(-slen, sy), Vector2(-6.0, sy), Color(1.0, 0.54, 0.0, 0.42 * heat), 2.8, true)

	draw_set_transform(center, roll_angle, Vector2.ONE)

	# Blazing inner magma core visible through plate seams
	draw_circle(Vector2.ZERO, r - 0.6, amber)
	draw_circle(Vector2.ZERO, r - 4.2, magma_hot * Color(1, 1, 1, 0.85))

	# 12 interlocking saw-tooth basalt keratin plates forming the armored rolling sphere
	var plates := 12
	for i in range(plates):
		var ang := (float(i) / float(plates)) * TAU
		var c := cos(ang)
		var s := sin(ang)
		var rot := func(v: Vector2) -> Vector2:
			return Vector2(v.x * c - v.y * s, v.x * s + v.y * c)
		var poly := PackedVector2Array([
			rot.call(Vector2(5.5, -5.2)),
			rot.call(Vector2(r + 2.6, -1.6)),
			rot.call(Vector2(r + 0.4, 4.4)),
			rot.call(Vector2(6.0, 4.8))
		])
		draw_colored_polygon(poly, COLOR_BASALT if i % 2 == 0 else COLOR_BASALT_DARK)

		# Faceted bevel highlight & fiery glowing seam vent
		draw_line(rot.call(Vector2(7.0, -4.6)), rot.call(Vector2(r + 2.2, -1.6)), COLOR_BEVEL, 1.15, true)
		draw_line(rot.call(Vector2(6.2, 4.4)), rot.call(Vector2(r - 1.2, 3.8)), amber, 1.6, true)

	# Concentric tucked inner spiral hub showing the curled tail/snout core
	draw_circle(Vector2.ZERO, 8.8, COLOR_BASALT_DARK)
	draw_arc(Vector2.ZERO, 8.6, 0.25, PI * 1.72, 20, amber, 1.9, true)
	draw_arc(Vector2.ZERO, 5.0, 1.1, PI * 2.1, 14, magma_hot, 1.4, true)
	draw_circle(Vector2.ZERO, 2.4, COLOR_BASALT)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
