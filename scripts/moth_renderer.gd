extends Node2D
class_name MothRenderer

## Painterly Iridescent Twilight Luna Moth Renderer
## - Smooth Bezier-curved falcate forewings & flowing swallowtail hindwings
## - Rich multi-tone palette: velvety royal indigo-plum -> iridescent cerulean -> aqua-cyan -> warm gold eye-spots
## - Strictly non-self-intersecting canonical wing geometry driven by affine root transforms (ZERO triangulation errors!)
## - Asymmetric organic figure-8 wingbeat with body hover-bob & swaying feathered bipectinate antennae

const COL_INDIGO: Color = Color(0.14, 0.16, 0.38, 0.94)
const COL_CERULEAN: Color = Color(0.16, 0.42, 0.68, 0.92)
const COL_AQUA: Color = Color(0.18, 0.86, 0.96, 0.62)
const COL_CYAN: Color = Color(0.0, 0.92, 1.0, 1.0)
const COL_CYAN_BRIGHT: Color = Color(0.88, 0.99, 1.0, 1.0)
const COL_GOLD: Color = Color(1.0, 0.82, 0.38, 0.95)
const COL_WING_BACK: Color = Color(0.10, 0.16, 0.36, 0.72)
const COL_BODY_DARK: Color = Color(0.10, 0.14, 0.28, 1.0)
const COL_BODY_LIGHT: Color = Color(0.24, 0.36, 0.56, 1.0)
const COL_FUR_COLLAR: Color = Color(0.74, 0.92, 0.96, 0.92)

var wing_phase: float = 0.0
var wing_boost: float = 0.0
var vy: float = 0.0
var flow_multiplier: int = 1
var morph_ratio: float = 0.0
var _time: float = 0.0

var _fore_poly: PackedVector2Array = PackedVector2Array()
var _fore_mid: PackedVector2Array = PackedVector2Array()
var _fore_rim: PackedVector2Array = PackedVector2Array()
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
	# Strictly simple, non-self-intersecting clockwise Bezier forewing (root at (0,0), extends up-left)
	_fore_poly = PackedVector2Array()
	for p in _quad_pts(Vector2(2.0, 0.0), Vector2(18.0, -24.0), Vector2(8.0, -48.0), 6):
		_fore_poly.append(p)
	for p in _quad_pts(Vector2(8.0, -48.0), Vector2(-10.0, -52.0), Vector2(-24.0, -34.0), 6):
		_fore_poly.append(p)
	for p in _quad_pts(Vector2(-24.0, -34.0), Vector2(-32.0, -18.0), Vector2(-14.0, -4.0), 5):
		_fore_poly.append(p)
	_fore_poly.append(Vector2(-2.0, 2.0))

	# Mid iridescent cerulean membrane
	_fore_mid = PackedVector2Array([
		Vector2(1.0, -3.0), Vector2(11.0, -22.0), Vector2(5.5, -42.0),
		Vector2(-10.0, -43.0), Vector2(-21.0, -28.0), Vector2(-22.0, -14.0), Vector2(-8.0, -4.0)
	])

	# Soft aqua sub-marginal shimmer band
	_fore_rim = PackedVector2Array([
		Vector2(9.5, -34.0), Vector2(6.5, -45.5), Vector2(-9.5, -46.5),
		Vector2(-21.5, -32.0), Vector2(-24.0, -22.0), Vector2(-14.0, -28.0), Vector2(-2.0, -36.0)
	])

	# Smooth curved swallowtail hindwing (strictly non-self-intersecting!)
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

	# Asymmetric graceful wingbeat + counter-hover body bob
	var raw: float = sin(wing_phase)
	var flap: float = pow(raw, 0.75) if raw >= 0.0 else -pow(-raw, 1.32)
	var hover_bob: float = -flap * 3.0
	var root_pos: Vector2 = Vector2(0.0, -21.0 + hover_bob)

	# Far wing (offset slightly back & phase-lagged)
	var back_sy: float = 0.22 + (flap * 0.5 + 0.5) * 0.68
	var back_rot: float = pitch - 0.12 + cos(wing_phase) * 0.14
	_draw_wing_transformed(root_pos + Vector2(-2.0, -2.0), back_rot, Vector2(0.92, -back_sy), true, flow_boost)

	# Main body transform
	draw_set_transform(root_pos, pitch, Vector2.ONE)

	# Delicate tucked moth legs
	for l in range(3):
		var lx: float = 5.5 - float(l) * 3.6
		draw_polyline(PackedVector2Array([Vector2(lx, 4.0), Vector2(lx - 2.0, 7.6), Vector2(lx - 4.8, 8.2)]), Color(0.32, 0.62, 0.78, 0.72), 1.1, true)

	# Smooth velvety segmented abdomen
	var abd: PackedVector2Array = PackedVector2Array([
		Vector2(-18.5, 2.0), Vector2(-12.5, -2.0), Vector2(-3.5, -3.4),
		Vector2(2.5, 0.0), Vector2(-3.5, 5.2), Vector2(-12.5, 5.0)
	])
	draw_colored_polygon(abd, COL_BODY_DARK)
	for s in range(4):
		var sx: float = -2.5 - float(s) * 3.4
		draw_line(Vector2(sx, -2.2), Vector2(sx - 1.0, 3.8), Color(0.28, 0.88, 1.0, 0.62), 1.2, true)

	# Plush furry thorax & luminous pale-silver collar
	draw_circle(Vector2(4.2, -0.2), 6.2, COL_BODY_LIGHT)
	draw_circle(Vector2(8.8, -0.8), 4.8, COL_FUR_COLLAR)
	draw_circle(Vector2(11.8, -0.8), 4.0, COL_BODY_DARK)

	# Glowing crystalline compound eye
	draw_circle(Vector2(13.2, -1.3), 2.3, COL_CYAN)
	draw_circle(Vector2(13.8, -1.8), 1.0, COL_CYAN_BRIGHT)

	# Feathered bipectinate antennae swaying in wind
	var ant_wave: float = sin(_time * 8.0 + wing_phase * 0.4) * 2.4 - vy * 0.006
	for a in range(2):
		var sy: float = -3.4 if a == 0 else -1.6
		var st: Vector2 = Vector2(13.6, sy)
		var md: Vector2 = Vector2(18.6 - float(a) * 1.4, -10.2 + float(a) * 2.2 + ant_wave * 0.55)
		var tp: Vector2 = Vector2(22.5 - float(a) * 2.2, -15.2 + float(a) * 3.4 + ant_wave)
		draw_polyline(PackedVector2Array([st, md, tp]), COL_GOLD, 1.35, true)
		for b in range(1, 6):
			var t: float = float(b) / 6.0
			var bp: Vector2 = st.lerp(md, t * 2.0) if t < 0.5 else md.lerp(tp, (t - 0.5) * 2.0)
			var bl: float = 3.4 * sin(t * PI) + 0.9
			draw_line(bp, bp + Vector2(-bl, -bl * 0.6), Color(0.95, 0.88, 0.62, 0.72), 0.9, true)

	if morph_ratio > 0.02:
		draw_arc(Vector2.ZERO, 26.0 + (1.0 - morph_ratio) * 12.0, 0.0, TAU, 32, Color(0.0, 0.92, 1.0, morph_ratio * 0.85), 2.2, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Near articulated wing sweeping smoothly between +1.05 (upstroke) and -0.92 (downstroke),
	# clamping away from zero so polygon never collapses or fails triangulation!
	var front_sy: float = flap * 1.02
	if absf(front_sy) < 0.18:
		front_sy = 0.18 if front_sy >= 0.0 else -0.18
	var front_rot: float = pitch + cos(wing_phase) * 0.16
	_draw_wing_transformed(root_pos + Vector2(2.0, -1.0), front_rot, Vector2(1.0, front_sy), false, flow_boost)

func _draw_wing_transformed(origin: Vector2, rot: float, scl: Vector2, is_back: bool, flow_boost: float) -> void:
	draw_set_transform(origin, rot, scl)
	var base_c: Color = COL_WING_BACK if is_back else COL_INDIGO
	var mid_c: Color = COL_WING_BACK if is_back else COL_CERULEAN
	var edge_c: Color = Color(0.18, 0.86, 1.0, 0.36 if is_back else clampf(0.82 * flow_boost, 0.72, 0.98))

	# Hindwing first (tucked behind forewing)
	draw_colored_polygon(_hind_poly, base_c)
	if not is_back:
		draw_colored_polygon(_hind_rim, mid_c)
		draw_polyline(_hind_poly, edge_c * Color(1, 1, 1, 0.75), 1.3, true)
		draw_circle(Vector2(-45.5, 33.5), 2.2, COL_CYAN_BRIGHT)
		# Warm golden luna eye-spot on hindwing
		var oc_h: Vector2 = Vector2(-21.0, 17.5)
		draw_circle(oc_h, 4.6, Color(0.06, 0.08, 0.20, 0.92))
		draw_arc(oc_h, 4.0, 0.0, TAU, 18, COL_GOLD, 1.4, true)
		draw_circle(oc_h, 1.8, COL_CYAN_BRIGHT)

	# Sculpted falcate forewing
	draw_colored_polygon(_fore_poly, base_c)
	if not is_back:
		draw_colored_polygon(_fore_mid, mid_c)
		draw_colored_polygon(_fore_rim, COL_AQUA)
		draw_polyline(_fore_poly, edge_c, 1.5, true)
		# Delicate natural veins
		var vein_c: Color = Color(0.76, 0.98, 1.0, 0.62)
		draw_line(Vector2(1.0, -2.0), Vector2(6.5, -45.0), vein_c, 1.2, true)
		draw_line(Vector2(0.0, -3.0), Vector2(-7.0, -24.0), vein_c, 1.1, true)
		draw_line(Vector2(-7.0, -24.0), Vector2(-9.0, -45.0), vein_c, 0.95, true)
		draw_line(Vector2(-7.0, -24.0), Vector2(-22.0, -31.0), vein_c, 0.95, true)
		draw_line(Vector2(-7.0, -24.0), Vector2(-24.0, -17.0), vein_c, 0.9, true)
		# Golden-ringed cyan ocellus eye-spot on forewing
		var oc_f: Vector2 = Vector2(-5.5, -31.0)
		draw_circle(oc_f, 5.2, Color(0.06, 0.08, 0.20, 0.94))
		draw_arc(oc_f, 4.5, 0.0, TAU, 18, COL_GOLD, 1.5, true)
		draw_circle(oc_f, 2.2, COL_CYAN)
		draw_circle(oc_f + Vector2(0.7, -0.6), 1.0, COL_CYAN_BRIGHT)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
