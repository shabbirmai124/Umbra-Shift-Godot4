extends Node2D
class_name MothRenderer

## Ultra-Detailed Realistic Luminous Actias Luna Moth Renderer
## Hand-crafted natural-wildlife coloration & graceful aerodynamic animation:
## - Authentic celadon-jade & luminous seafoam-aqua wings with dusty rose-plum costal leading edge
## - Plush snowy cream-white fuzzy thorax & segmented abdomen with fine fur strokes
## - Honey-gold feathered bipectinate spring antennae & realistic multi-ringed ocelli eye-spots
## - Safe affine pseudo-3D wingbeat projection (clamped absf(sy) >= 0.18, zero triangulation errors!)

const COL_CELADON: Color = Color(0.34, 0.80, 0.68, 0.96)
const COL_AQUA_MID: Color = Color(0.24, 0.68, 0.84, 0.94)
const COL_SEAFOAM_RIM: Color = Color(0.72, 0.98, 0.94, 0.76)
const COL_COSTAL_PLUM: Color = Color(0.56, 0.30, 0.44, 0.94)
const COL_CYAN: Color = Color(0.0, 0.92, 1.0, 1.0)
const COL_CYAN_BRIGHT: Color = Color(0.92, 1.0, 1.0, 1.0)
const COL_GOLD: Color = Color(0.98, 0.80, 0.36, 0.98)
const COL_WING_BACK: Color = Color(0.18, 0.44, 0.50, 0.78)
const COL_BODY_CREAM: Color = Color(0.94, 0.93, 0.88, 1.0)
const COL_BODY_SHADE: Color = Color(0.70, 0.76, 0.76, 1.0)
const COL_HEAD_DARK: Color = Color(0.26, 0.24, 0.32, 1.0)

var wing_phase: float = 0.0
var wing_boost: float = 0.0
var vy: float = 0.0
var flow_multiplier: int = 1
var morph_ratio: float = 0.0
var _time: float = 0.0

var _fore_poly: PackedVector2Array = PackedVector2Array()
var _fore_mid: PackedVector2Array = PackedVector2Array()
var _fore_rim: PackedVector2Array = PackedVector2Array()
var _fore_costal: PackedVector2Array = PackedVector2Array()
var _hind_poly: PackedVector2Array = PackedVector2Array()
var _hind_rim: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	_build_canonical_wings()

func _quad_pts(p0: Vector2, p1: Vector2, p2: Vector2, steps: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var u: float = 1.0 - t
		out.append(u * u * p0 + 2.0 * u * t * p1 + t * t * p2)
	return out

func _build_canonical_wings() -> void:
	_fore_poly = PackedVector2Array()
	for p in _quad_pts(Vector2(2.0, 0.0), Vector2(18.0, -24.0), Vector2(8.0, -48.0), 6):
		_fore_poly.append(p)
	for p in _quad_pts(Vector2(8.0, -48.0), Vector2(-10.0, -52.0), Vector2(-24.0, -34.0), 6):
		_fore_poly.append(p)
	for p in _quad_pts(Vector2(-24.0, -34.0), Vector2(-32.0, -18.0), Vector2(-14.0, -4.0), 5):
		_fore_poly.append(p)
	_fore_poly.append(Vector2(-2.0, 2.0))

	_fore_mid = PackedVector2Array([
		Vector2(1.0, -3.0), Vector2(11.0, -22.0), Vector2(5.5, -42.0),
		Vector2(-10.0, -43.0), Vector2(-21.0, -28.0), Vector2(-22.0, -14.0), Vector2(-8.0, -4.0)
	])

	_fore_rim = PackedVector2Array([
		Vector2(9.5, -34.0), Vector2(6.5, -45.5), Vector2(-9.5, -46.5),
		Vector2(-21.5, -32.0), Vector2(-24.0, -22.0), Vector2(-14.0, -28.0), Vector2(-2.0, -36.0)
	])

	# Authentic Actias Luna dusty rose-plum leading costal band
	_fore_costal = _quad_pts(Vector2(2.0, -1.0), Vector2(16.5, -24.0), Vector2(7.6, -47.2), 6)

	_hind_poly = PackedVector2Array()
	for p in _quad_pts(Vector2(-2.0, 2.0), Vector2(-18.0, 4.0), Vector2(-34.0, 18.0), 5):
		_hind_poly.append(p)
	for p in _quad_pts(Vector2(-34.0, 18.0), Vector2(-42.0, 26.0), Vector2(-46.0, 34.0), 4):
		_hind_poly.append(p)
	for p in _quad_pts(Vector2(-46.0, 34.0), Vector2(-34.0, 30.0), Vector2(-22.0, 26.0), 4):
		_hind_poly.append(p)
	for p in _quad_pts(Vector2(-22.0, 26.0), Vector2(-10.0, 22.0), Vector2(-4.0, 10.0), 4):
		_hind_poly.append(p)

	_hind_rim = PackedVector2Array([
		Vector2(-8.0, 6.0), Vector2(-24.0, 13.0), Vector2(-36.0, 24.0),
		Vector2(-24.0, 22.0), Vector2(-12.0, 17.0)
	])

func sync_state(p_wing_phase: float, p_wing_boost: float, p_vy: float, p_flow: int, p_morph: float, dt: float) -> void:
	if _fore_poly.is_empty():
		_build_canonical_wings()
	_time += dt
	wing_phase = p_wing_phase
	wing_boost = p_wing_boost
	vy = p_vy
	flow_multiplier = p_flow
	morph_ratio = p_morph
	queue_redraw()

func _draw() -> void:
	if _fore_poly.is_empty():
		_build_canonical_wings()
	var flow_boost: float = clampf(0.88 + float(flow_multiplier - 1) * 0.08 + wing_boost * 0.35, 0.88, 1.55)
	var pitch: float = clampf(vy * 0.0011, -0.38, 0.42)

	var raw: float = sin(wing_phase)
	var flap: float = pow(raw, 0.75) if raw >= 0.0 else -pow(-raw, 1.32)
	var hover_bob: float = -flap * 3.0
	var root_pos: Vector2 = Vector2(0.0, -21.0 + hover_bob)

	# Far wing pair (shaded celadon-teal depth separation)
	var back_sy: float = 0.22 + (flap * 0.5 + 0.5) * 0.68
	var back_rot: float = pitch - 0.12 + cos(wing_phase) * 0.14
	_draw_wing_transformed(root_pos + Vector2(-2.0, -2.0), back_rot, Vector2(0.92, -back_sy), true, flow_boost)

	draw_set_transform(root_pos, pitch, Vector2.ONE)

	# Delicate tucked moth legs
	for l in range(3):
		var lx: float = 5.5 - float(l) * 3.6
		draw_polyline(PackedVector2Array([Vector2(lx, 4.0), Vector2(lx - 2.0, 7.6), Vector2(lx - 4.8, 8.2)]), Color(0.56, 0.36, 0.44, 0.85), 1.2, true)

	# Plush snowy-cream segmented abdomen
	var abd: PackedVector2Array = PackedVector2Array([
		Vector2(-18.5, 2.0), Vector2(-12.5, -2.0), Vector2(-3.5, -3.5),
		Vector2(2.8, 0.0), Vector2(-3.5, 5.2), Vector2(-12.5, 5.0)
	])
	draw_colored_polygon(abd, COL_BODY_CREAM)
	for s in range(4):
		var sx: float = -2.5 - float(s) * 3.4
		draw_line(Vector2(sx, -2.2), Vector2(sx - 1.0, 4.0), COL_BODY_SHADE, 1.2, true)

	# Fuzzy velvety thorax with rose-plum collar & luminous cyan heart glow
	draw_circle(Vector2(4.4, -0.2), 6.5, COL_BODY_CREAM)
	draw_circle(Vector2(4.2, -0.4), 3.4, Color(0.20, 0.92, 1.0, 0.35))
	draw_arc(Vector2(8.2, -0.6), 5.0, -1.4, 1.4, 12, COL_COSTAL_PLUM, 2.2, true)
	draw_circle(Vector2(11.6, -0.8), 4.2, COL_HEAD_DARK)

	# Crystalline compound eye
	draw_circle(Vector2(13.2, -1.3), 2.4, COL_CYAN)
	draw_circle(Vector2(13.8, -1.8), 1.0, COL_CYAN_BRIGHT)

	# Warm honey-gold feathered bipectinate antennae swaying with wind
	var ant_wave: float = sin(_time * 8.0 + wing_phase * 0.4) * 2.4 - vy * 0.006
	for a in range(2):
		var sy: float = -3.4 if a == 0 else -1.6
		var st: Vector2 = Vector2(13.6, sy)
		var md: Vector2 = Vector2(18.6 - float(a) * 1.4, -10.2 + float(a) * 2.2 + ant_wave * 0.55)
		var tp: Vector2 = Vector2(22.5 - float(a) * 2.2, -15.2 + float(a) * 3.4 + ant_wave)
		draw_polyline(PackedVector2Array([st, md, tp]), COL_GOLD, 1.45, true)
		for b in range(1, 7):
			var t: float = float(b) / 7.0
			var bp: Vector2 = st.lerp(md, t * 2.0) if t < 0.5 else md.lerp(tp, (t - 0.5) * 2.0)
			var bl: float = 3.6 * sin(t * PI) + 0.9
			draw_line(bp, bp + Vector2(-bl, -bl * 0.6), Color(1.0, 0.88, 0.56, 0.82), 0.95, true)

	if morph_ratio > 0.02:
		draw_arc(Vector2.ZERO, 26.0 + (1.0 - morph_ratio) * 12.0, 0.0, TAU, 32, Color(0.0, 0.92, 1.0, morph_ratio * 0.85), 2.2, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Near articulated wing sweeping smoothly between +1.02 and -0.92 (clamped away from 0)
	var front_sy: float = flap * 1.02
	if absf(front_sy) < 0.18:
		front_sy = 0.18 if front_sy >= 0.0 else -0.18
	var front_rot: float = pitch + cos(wing_phase) * 0.16
	_draw_wing_transformed(root_pos + Vector2(2.0, -1.0), front_rot, Vector2(1.0, front_sy), false, flow_boost)

func _draw_wing_transformed(origin: Vector2, rot: float, scl: Vector2, is_back: bool, flow_boost: float) -> void:
	draw_set_transform(origin, rot, scl)
	var base_c: Color = COL_WING_BACK if is_back else COL_CELADON
	var mid_c: Color = COL_WING_BACK if is_back else COL_AQUA_MID
	var edge_c: Color = Color(0.28, 0.94, 1.0, 0.40 if is_back else clampf(0.88 * flow_boost, 0.76, 1.0))

	draw_colored_polygon(_hind_poly, base_c)
	if not is_back:
		draw_colored_polygon(_hind_rim, mid_c)
		draw_polyline(_hind_poly, edge_c * Color(1, 1, 1, 0.80), 1.4, true)
		draw_circle(Vector2(-45.5, 33.5), 2.4, COL_CYAN_BRIGHT)
		var oc_h: Vector2 = Vector2(-21.0, 17.5)
		draw_circle(oc_h, 4.8, Color(0.22, 0.14, 0.28, 0.94))
		draw_arc(oc_h, 4.2, 0.0, TAU, 18, COL_GOLD, 1.5, true)
		draw_circle(oc_h, 2.0, COL_CYAN_BRIGHT)

	draw_colored_polygon(_fore_poly, base_c)
	if not is_back:
		draw_colored_polygon(_fore_mid, mid_c)
		draw_colored_polygon(_fore_rim, COL_SEAFOAM_RIM)
		draw_polyline(_fore_poly, edge_c, 1.6, true)
		draw_polyline(_fore_costal, COL_COSTAL_PLUM, 3.0, true)
		var vein_c: Color = Color(0.86, 1.0, 0.98, 0.72)
		draw_line(Vector2(1.0, -2.0), Vector2(6.5, -45.0), vein_c, 1.25, true)
		draw_line(Vector2(0.0, -3.0), Vector2(-7.0, -24.0), vein_c, 1.15, true)
		draw_line(Vector2(-7.0, -24.0), Vector2(-9.0, -45.0), vein_c, 1.0, true)
		draw_line(Vector2(-7.0, -24.0), Vector2(-22.0, -31.0), vein_c, 1.0, true)
		draw_line(Vector2(-7.0, -24.0), Vector2(-24.0, -17.0), vein_c, 0.95, true)
		# Realistic Actias Luna multi-ringed ocellus eye-spot
		var oc_f: Vector2 = Vector2(-5.5, -31.0)
		draw_circle(oc_f, 5.4, Color(0.22, 0.14, 0.28, 0.96))
		draw_arc(oc_f, 4.7, 0.0, TAU, 18, COL_GOLD, 1.6, true)
		draw_circle(oc_f, 2.4, COL_CYAN)
		draw_circle(oc_f + Vector2(0.8, -0.6), 1.05, COL_CYAN_BRIGHT)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
