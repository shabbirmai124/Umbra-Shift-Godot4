extends Node2D
class_name MothRenderer

## High-Detail Procedural Luminous Moth Renderer (#00E5FF Electric Cyan)
## 100% pure Godot 4 _draw() anatomy:
## - 4-segment velvety thorax/abdomen with furry pronotum collar, cyan pleural bands & tucked legs
## - Twin plumed bipectinate (feathery) antennae flexing dynamically with airflow
## - Asymmetric flapping falcate forewings & trailing swallowtail hindwings with secondary phase lag
## - Multi-layered translucent violet-slate membranes, intricate branching cyan venation,
##   glowing wing-margin scale dots, and detailed multi-ring ocelli eye-spots

const COLOR_CYAN := Color(0.0, 0.9, 1.0, 1.0)
const COLOR_CYAN_BRIGHT := Color(0.84, 0.99, 1.0, 1.0)
const COLOR_WING_DARK := Color(0.055, 0.088, 0.20, 0.86)
const COLOR_WING_BASE := Color(0.10, 0.16, 0.34, 0.78)
const COLOR_WING_RIM_BAND := Color(0.14, 0.42, 0.62, 0.36)
const COLOR_WING_BACK := Color(0.055, 0.095, 0.21, 0.54)
const COLOR_BODY_DARK := Color(0.045, 0.072, 0.155, 1.0)
const COLOR_BODY_MID := Color(0.078, 0.125, 0.245, 1.0)

var wing_phase: float = 0.0
var wing_boost: float = 0.0
var vy: float = 0.0
var flow_multiplier: int = 1
var morph_ratio: float = 0.0
var _time: float = 0.0

func sync_state(p_wing_phase: float, p_wing_boost: float, p_vy: float, p_flow: int, p_morph: float, dt: float) -> void:
	_time += dt
	wing_phase = p_wing_phase
	wing_boost = p_wing_boost
	vy = p_vy
	flow_multiplier = p_flow
	morph_ratio = p_morph
	queue_redraw()

func _draw() -> void:
	var flow_boost := clampf(0.8 + float(flow_multiplier - 1) * 0.08 + wing_boost * 0.35, 0.8, 1.6)
	var pitch := clampf(vy * 0.0012, -0.42, 0.45)
	draw_set_transform(Vector2(0.0, -19.0), pitch, Vector2.ONE)

	# Soft bioluminescent cyan aura around body
	draw_circle(Vector2(-2.0, 0.0), 28.0, Color(0.0, 0.9, 1.0, 0.08 * flow_boost))

	# Asymmetric natural wingbeat (snappy downstroke, graceful floating recovery)
	var raw := sin(wing_phase)
	var flap := pow(raw, 0.74) if raw >= 0.0 else -pow(-raw, 1.36)
	var sweep_y := flap * 27.0
	var tip_bend := cos(wing_phase) * 6.5
	var tail_lag := sin(wing_phase - 0.85) * 7.5

	# Far wings (perspective depth offset behind thorax)
	_draw_wing_pair(-0.78, sweep_y * 0.76, tip_bend * 0.8, tail_lag * 0.75, true, flow_boost)

	# Delicate tucked insect tarsal legs beneath thorax
	for l in range(3):
		var lx := 6.0 - float(l) * 3.8
		draw_polyline(PackedVector2Array([
			Vector2(lx, 4.5), Vector2(lx - 2.2, 8.2), Vector2(lx - 5.4, 9.0)
		]), Color(0.18, 0.48, 0.62, 0.72), 1.1, true)

	# Tapered 5-segment velvety abdomen with luminous cyan pleural bands
	var abd_pts := PackedVector2Array([
		Vector2(-18.5, 2.2), Vector2(-13.0, -1.6), Vector2(-4.0, -3.2),
		Vector2(2.0, 0.0), Vector2(-3.5, 5.2), Vector2(-12.5, 5.0)
	])
	draw_colored_polygon(abd_pts, COLOR_BODY_DARK)
	for s in range(4):
		var sx := -2.5 - float(s) * 3.6
		var r_seg := 4.4 - float(s) * 0.65
		draw_line(Vector2(sx, -r_seg * 0.55), Vector2(sx - 1.2, r_seg * 0.95), Color(0.0, 0.9, 1.0, 0.58 * clampf(flow_boost, 0.8, 1.25)), 1.3, true)
	draw_circle(Vector2(-17.8, 2.2), 1.8, Color(0.0, 0.9, 1.0, 0.65))

	# Fuzzy muscular thorax & pronotum collar with fine procedural hair strokes
	draw_circle(Vector2(4.2, 0.0), 6.4, COLOR_BODY_MID)
	draw_circle(Vector2(9.2, -0.8), 4.8, COLOR_BODY_DARK)
	draw_polyline(PackedVector2Array([Vector2(0.5, -5.2), Vector2(4.5, -6.2), Vector2(8.8, -5.0)]), Color(0.68, 0.92, 1.0, 0.42), 1.3, true)
	# Glowing dorsal thorax rune
	draw_polyline(PackedVector2Array([Vector2(1.0, -1.8), Vector2(4.5, -3.5), Vector2(7.2, -1.2)]), Color(0.0, 0.9, 1.0, 0.85), 1.2, true)
	for h in range(4):
		var hx := 0.5 + float(h) * 2.2
		draw_line(Vector2(hx, -4.5), Vector2(hx - 1.5, -7.2), Color(0.32, 0.64, 0.82, 0.45), 0.9, true)

	# Head & large crystalline compound cyan eye
	draw_circle(Vector2(12.2, -0.8), 4.0, COLOR_BODY_MID)
	var eye := Vector2(13.6, -1.4)
	draw_circle(eye, 5.4, Color(0.0, 0.9, 1.0, 0.28 * flow_boost))
	draw_circle(eye, 2.3, COLOR_CYAN)
	draw_circle(eye + Vector2(0.5, -0.5), 1.0, COLOR_CYAN_BRIGHT)

	# Twin plumed bipectinate (feathery) antennae bending gracefully in airflow
	var ant_wave := sin(_time * 8.5 + wing_phase * 0.4) * 2.4 - vy * 0.006
	for a in range(2):
		var start := Vector2(13.8, -3.6 if a == 0 else -1.6)
		var mid := Vector2(18.5 - float(a) * 1.4, -9.8 + float(a) * 2.4 + ant_wave * 0.55)
		var tip := Vector2(22.2 - float(a) * 2.2, -14.8 + float(a) * 3.8 + ant_wave)
		draw_polyline(PackedVector2Array([start, mid, tip]), Color(0.52, 0.96, 1.0, 0.92), 1.3, true)
		for b in range(1, 6):
			var t := float(b) / 6.0
			var bp := start.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(tip, (t - 0.5) * 2.0)
			var barb_len := 3.6 * sin(t * PI) + 1.0
			draw_line(bp, bp + Vector2(-barb_len, -barb_len * 0.65), Color(0.45, 0.95, 1.0, 0.7), 0.9, true)
			draw_line(bp, bp + Vector2(barb_len * 0.55, -barb_len * 0.9), Color(0.45, 0.95, 1.0, 0.55), 0.8, true)

	# Near articulated forewing & ornate swallowtail hindwing
	_draw_wing_pair(1.0, sweep_y, tip_bend, tail_lag, false, flow_boost)

	if morph_ratio > 0.01:
		draw_arc(Vector2.ZERO, 26.0 + (1.0 - morph_ratio) * 9.0, 0.0, TAU, 32, Color(0.0, 0.9, 1.0, morph_ratio * 0.9), 2.6, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_wing_pair(side_y: float, sweep_y: float, tip_bend: float, tail_lag: float, is_back: bool, flow_boost: float) -> void:
	var fill_col := COLOR_WING_BACK if is_back else COLOR_WING_BASE
	var inner_col := COLOR_WING_BACK if is_back else COLOR_WING_DARK
	var edge_col := Color(0.0, 0.9, 1.0, 0.42 if is_back else clampf(0.88 * flow_boost, 0.78, 1.0))
	var vein_col := Color(0.58, 0.97, 1.0, 0.32 if is_back else 0.84)

	# Ornate elongated swallowtail hindwing with flexing trailing ribbon
	var hy := (11.5 + sweep_y * 0.66) * side_y
	var tail_tip := Vector2(-46.0, hy + (9.0 + tail_lag) * side_y)
	var hind := PackedVector2Array([
		Vector2(-1.0, 1.0),
		Vector2(-14.0, hy * 0.32),
		Vector2(-28.0, hy * 0.62),
		Vector2(-35.0, hy * 0.82),
		tail_tip,
		Vector2(-32.0, hy * 0.96 + tail_lag * 0.35 * side_y),
		Vector2(-23.0, hy * 0.84),
		Vector2(-17.0, hy * 0.74),
		Vector2(-9.5, hy * 0.58)
	])
	draw_colored_polygon(hind, fill_col)
	draw_polyline(hind, edge_col, 1.4, true)

	# Glowing swallowtail ribbon tip
	if not is_back:
		draw_circle(tail_tip, 2.8, Color(0.0, 0.9, 1.0, 0.42))
		draw_circle(tail_tip, 1.3, COLOR_CYAN_BRIGHT)

		# Detailed multi-ring ocellus eye-spot on hindwing
		var oc_h := Vector2(-19.5, hy * 0.54)
		draw_circle(oc_h, 5.4, Color(0.03, 0.05, 0.12, 0.92))
		draw_arc(oc_h, 4.6, 0.0, TAU, 20, COLOR_CYAN, 1.3, true)
		draw_circle(oc_h, 2.3, Color(0.0, 0.9, 1.0, 0.45))
		draw_circle(oc_h + Vector2(0.6, -0.5 * side_y), 1.2, COLOR_CYAN_BRIGHT)

	# Sculpted falcate (hooked-tip) scalloped upper forewing
	var fy := (-27.0 - sweep_y) * side_y
	var apex := Vector2(6.5, fy + (-4.5 + tip_bend) * side_y)
	var fore := PackedVector2Array([
		Vector2(4.5, -1.2),
		Vector2(14.5, fy * 0.44),
		Vector2(14.0, fy * 0.82 + tip_bend * 0.45 * side_y),
		apex,
		Vector2(-6.0, fy + (0.8 + tip_bend * 0.75) * side_y),
		Vector2(-15.5, fy + (4.2 + tip_bend * 0.5) * side_y),
		Vector2(-21.0, fy * 0.74),
		Vector2(-27.0, fy * 0.46),
		Vector2(-14.0, fy * 0.24),
		Vector2(-4.5, 2.2)
	])
	draw_colored_polygon(fore, fill_col)

	# Darker indigo basal membrane & translucent cyan sub-marginal band for layered depth
	if not is_back:
		var basal := PackedVector2Array([
			Vector2(4.0, -1.0), Vector2(10.5, fy * 0.42), Vector2(-6.0, fy * 0.48),
			Vector2(-16.0, fy * 0.30), Vector2(-4.5, 1.8)
		])
		draw_colored_polygon(basal, inner_col)
		var sub_band := PackedVector2Array([
			Vector2(11.5, fy * 0.72), apex.lerp(Vector2(0.0, 0.0), 0.08),
			Vector2(-14.0, fy * 0.86 + tip_bend * 0.35 * side_y),
			Vector2(-22.5, fy * 0.50), Vector2(-13.5, fy * 0.46), Vector2(3.5, fy * 0.62)
		])
		draw_colored_polygon(sub_band, COLOR_WING_RIM_BAND)

	draw_polyline(fore, edge_col, 1.7, true)

	# Intricate anatomical branching cyan venation & discal cell loop
	var cell_end := Vector2(-4.5, fy * 0.54)
	draw_line(Vector2(4.0, -1.0), apex.lerp(Vector2(4.0, -1.0), 0.08), vein_col, 1.3, true)
	draw_line(Vector2(3.0, -0.5), cell_end, vein_col, 1.15, true)
	draw_line(cell_end, Vector2(-5.5, fy + tip_bend * 0.55 * side_y), vein_col, 1.0, true)
	draw_line(cell_end, Vector2(-15.0, fy + (3.6 + tip_bend * 0.45) * side_y), vein_col, 0.95, true)
	draw_line(cell_end, Vector2(-24.5, fy * 0.48), vein_col, 0.95, true)
	draw_line(Vector2(-2.0, 1.0), Vector2(-34.0, hy * 0.82), vein_col, 1.0, true)
	draw_line(Vector2(-10.0, hy * 0.35), Vector2(-24.0, hy * 0.82), vein_col * Color(1, 1, 1, 0.75), 0.85, true)

	# Forewing ocellus eye-spot + luminescent margin scale dots on near wing
	if not is_back:
		var oc_f := Vector2(-3.0, fy * 0.62 + tip_bend * 0.25 * side_y)
		draw_circle(oc_f, 4.4, Color(0.03, 0.05, 0.12, 0.9))
		draw_arc(oc_f, 3.6, 0.0, TAU, 18, COLOR_CYAN, 1.2, true)
		draw_circle(oc_f, 1.5, COLOR_CYAN_BRIGHT)

		var dots := [
			Vector2(10.0, fy * 0.82),
			Vector2(1.5, fy * 0.94),
			Vector2(-9.5, fy * 0.92),
			Vector2(-19.0, fy * 0.72)
		]
		for dp in dots:
			draw_circle(dp, 1.6, Color(0.75, 0.98, 1.0, 0.78))
