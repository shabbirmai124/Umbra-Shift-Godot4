extends Node2D
class_name FoxRenderer

## High-Detail Procedural Bioluminescent Fox Renderer (#4FFFB0 Mint Green)
## 100% pure Godot 4 _draw() anatomy:
## - Layered midnight-indigo pelage with slate-teal dorsal saddle & fur tufts
## - 3-segment digitigrade legs (hip -> knee -> hock -> glowing mint paw) in 4-beat gallop
## - 10-node Verlet/spring lush brush tail with glowing mint wisps & radiant tip
## - Expressive head with sculpted muzzle, whiskers, dynamic velocity-pinned ears & glowing iris
## - Bioluminescent shoulder/rib veins & moonlight rim highlights scaling with Flow

const COLOR_MINT := Color(0.31, 1.0, 0.69, 1.0)
const COLOR_MINT_BRIGHT := Color(0.84, 1.0, 0.94, 1.0)
const COLOR_FUR_DARK := Color(0.039, 0.072, 0.136, 1.0)
const COLOR_FUR_MID := Color(0.062, 0.118, 0.205, 1.0)
const COLOR_FUR_FAR := Color(0.022, 0.043, 0.082, 1.0)
const COLOR_FUR_BELLY := Color(0.028, 0.056, 0.104, 1.0)
const COLOR_RIM := Color(0.72, 0.91, 0.98, 0.56)

var gait_phase: float = 0.0
var is_dashing: bool = false
var is_airborne: bool = false
var vy: float = 0.0
var speed_ratio: float = 0.0
var flow_multiplier: int = 1
var morph_ratio: float = 0.0
var tail_nodes: PackedVector2Array = PackedVector2Array()
var _time: float = 0.0

func _ready() -> void:
	tail_nodes.resize(10)
	for i in range(10):
		tail_nodes[i] = Vector2(-18.0 - float(i) * 7.6, -18.0)

func sync_state(p_gait: float, p_dash: bool, p_air: bool, p_vy: float, p_speed_ratio: float, p_flow: int, p_morph: float, dt: float) -> void:
	_time += dt
	gait_phase = p_gait
	is_dashing = p_dash
	is_airborne = p_air
	vy = p_vy
	speed_ratio = p_speed_ratio
	flow_multiplier = p_flow
	morph_ratio = p_morph
	_update_tail_verlet(dt)
	queue_redraw()

func _update_tail_verlet(dt: float) -> void:
	var anchor := Vector2(-18.0, -11.5 if is_dashing else -18.5)
	tail_nodes[0] = anchor
	var seg_len := 7.8
	var follow := 1.0 - exp(-23.0 * maxf(dt, 0.001))
	for i in range(1, tail_nodes.size()):
		var prev := tail_nodes[i - 1]
		var wave := sin(gait_phase * 0.92 - float(i) * 0.54 + _time * 1.2) * (2.2 + float(i) * 0.58)
		var lift := -1.3 if not is_dashing else 0.15
		var target := Vector2(prev.x - seg_len, prev.y + lift + wave * 0.34 - vy * 0.0065)
		var curr := tail_nodes[i].lerp(target, follow)
		var delta := curr - prev
		if delta.length() > seg_len:
			curr = prev + delta.normalized() * seg_len
		tail_nodes[i] = curr

func _draw() -> void:
	var flow_boost := clampf(0.75 + float(flow_multiplier - 1) * 0.08 + (0.35 if is_dashing else 0.0), 0.75, 1.55)
	_draw_brush_tail(flow_boost)

	var body_drop := 7.0 if is_dashing else 0.0
	var bob := 0.0 if is_airborne else sin(gait_phase * 2.0) * 2.4
	var pitch := 0.08 if is_dashing else (clampf(vy * 0.00052, -0.38, 0.36) if is_airborne else sin(gait_phase) * 0.055)

	draw_set_transform(Vector2(0.0, body_drop + bob), pitch, Vector2.ONE)

	# Soft bioluminescent ground aura reflection under chest when dashing / high flow
	if is_dashing or flow_multiplier >= 3:
		draw_circle(Vector2(4.0, -16.0), 26.0, Color(0.31, 1.0, 0.69, 0.08 * flow_boost))

	# Far 3-segment digitigrade legs (4-beat rotary gallop offset)
	_draw_digitigrade_leg(Vector2(-15.5, -15.5), gait_phase + PI * 0.34, false, true, flow_boost)
	_draw_digitigrade_leg(Vector2(11.5, -16.5), gait_phase + PI * 1.26, true, true, flow_boost)

	# Lithe arched torso with tapered waist and muscular shoulder/haunch contours
	var spine_flex := -2.6 if is_airborne else sin(gait_phase) * 2.3
	var torso := PackedVector2Array([
		Vector2(-22.5, -15.5),
		Vector2(-18.0, -22.2 + spine_flex * 0.8),
		Vector2(-9.0, -25.2 + spine_flex),
		Vector2(2.5, -26.4 + spine_flex * 0.55),
		Vector2(13.5, -24.2),
		Vector2(21.5, -18.5),
		Vector2(22.5, -13.8),
		Vector2(14.5, -10.2),
		Vector2(5.5, -10.8),
		Vector2(-4.5, -12.6),
		Vector2(-14.5, -10.6),
		Vector2(-20.0, -11.5)
	])
	draw_colored_polygon(torso, COLOR_FUR_DARK)

	# Upper dorsal slate-teal saddle coat for volume and depth
	var saddle := PackedVector2Array([
		Vector2(-18.5, -18.5),
		Vector2(-10.0, -24.5 + spine_flex),
		Vector2(2.0, -25.8 + spine_flex * 0.55),
		Vector2(13.0, -23.6),
		Vector2(16.5, -17.8),
		Vector2(4.0, -18.2),
		Vector2(-9.5, -17.5)
	])
	draw_colored_polygon(saddle, COLOR_FUR_MID)

	# Shaded lower ribcage/belly silhouette
	var belly := PackedVector2Array([
		Vector2(-13.0, -11.5),
		Vector2(-4.0, -12.8),
		Vector2(6.0, -11.4),
		Vector2(14.0, -10.8),
		Vector2(10.0, -14.2),
		Vector2(-4.5, -15.4)
	])
	draw_colored_polygon(belly, COLOR_FUR_BELLY)

	# Layered chest/neck ruff fur tufts & rear haunch fur strokes
	var chest_ruff := PackedVector2Array([
		Vector2(12.0, -23.0), Vector2(21.5, -17.5), Vector2(24.0, -14.5),
		Vector2(18.5, -12.2), Vector2(20.5, -10.0), Vector2(14.0, -9.8),
		Vector2(15.5, -8.2), Vector2(9.0, -11.8)
	])
	draw_colored_polygon(chest_ruff, COLOR_FUR_MID)
	draw_line(Vector2(14.5, -15.0), Vector2(20.5, -12.2), COLOR_RIM * Color(1, 1, 1, 0.45), 1.0, true)
	draw_line(Vector2(-15.5, -18.0), Vector2(-21.0, -14.5), COLOR_RIM * Color(1, 1, 1, 0.35), 1.0, true)

	# Moonlit rim-light tracing arched spine & haunch
	draw_polyline(PackedVector2Array([
		Vector2(-21.0, -16.8),
		Vector2(-17.0, -22.2 + spine_flex * 0.8),
		Vector2(-9.0, -25.2 + spine_flex),
		Vector2(2.5, -26.4 + spine_flex * 0.55),
		Vector2(13.5, -24.2),
		Vector2(19.5, -20.0)
	]), COLOR_RIM, 1.7, true)

	# Bioluminescent shoulder-blade, flank & spine energy constellation veins
	var vein_col := Color(COLOR_MINT.r, COLOR_MINT.g, COLOR_MINT.b, clampf(0.75 * flow_boost, 0.55, 1.0))
	draw_polyline(PackedVector2Array([Vector2(4.0, -21.8), Vector2(10.5, -21.0), Vector2(16.2, -17.5)]), vein_col, 1.8, true)
	draw_polyline(PackedVector2Array([Vector2(1.0, -19.2), Vector2(7.5, -18.5), Vector2(12.5, -15.4)]), vein_col * Color(1, 1, 1, 0.78), 1.3, true)
	draw_polyline(PackedVector2Array([Vector2(-14.5, -20.0), Vector2(-9.5, -18.8), Vector2(-6.5, -15.5)]), vein_col * Color(1, 1, 1, 0.65), 1.2, true)
	draw_circle(Vector2(10.5, -21.0), 1.8, COLOR_MINT_BRIGHT * Color(1, 1, 1, 0.85))
	draw_circle(Vector2(-9.5, -18.8), 1.4, COLOR_MINT_BRIGHT * Color(1, 1, 1, 0.7))

	# Expressive articulated head, pointed snout, cheek tufts, whiskers & dynamic pinned ears
	_draw_head(flow_boost)

	# Near 3-segment digitigrade legs
	_draw_digitigrade_leg(Vector2(-16.0, -15.0), gait_phase, false, false, flow_boost)
	_draw_digitigrade_leg(Vector2(12.2, -16.0), gait_phase + PI * 0.94, true, false, flow_boost)

	# Morph energy halo during 0.12s transition
	if morph_ratio > 0.01:
		draw_arc(Vector2(2.0, -17.0), 26.0 + (1.0 - morph_ratio) * 8.0, 0.0, TAU, 32, Color(0.31, 1.0, 0.69, morph_ratio * 0.88), 2.6, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_head(flow_boost: float) -> void:
	var ear_pin := 0.62 if is_dashing else clampf(speed_ratio * 0.42 + (0.15 if is_airborne else 0.0), 0.0, 0.55)
	var head_pos := Vector2(17.0, -23.0)

	# Back triangular ear
	var back_tip := head_pos + Vector2(-2.0 - ear_pin * 11.5, -17.5 + ear_pin * 6.5)
	var back_ear := PackedVector2Array([
		head_pos + Vector2(-4.5, -3.0),
		back_tip,
		head_pos + Vector2(3.0, -4.5)
	])
	draw_colored_polygon(back_ear, COLOR_FUR_FAR)
	draw_line(head_pos + Vector2(-0.5, -5.0), back_tip.lerp(head_pos + Vector2(-0.5, -5.0), 0.28), Color(0.31, 1.0, 0.69, 0.42), 1.1, true)

	# Sculpted vulpine skull, brow ridge, tapered muzzle & fluffy cheek tufts
	var skull := PackedVector2Array([
		head_pos + Vector2(-6.5, -4.0),
		head_pos + Vector2(-1.5, -8.2),
		head_pos + Vector2(5.0, -7.2),
		head_pos + Vector2(10.5, -3.6),
		head_pos + Vector2(21.0, 0.2),
		head_pos + Vector2(19.5, 2.5),
		head_pos + Vector2(13.5, 4.4),
		head_pos + Vector2(6.5, 4.6),
		head_pos + Vector2(1.5, 6.8),
		head_pos + Vector2(-2.5, 5.4),
		head_pos + Vector2(-6.5, 6.0),
		head_pos + Vector2(-7.0, 1.8)
	])
	draw_colored_polygon(skull, COLOR_FUR_DARK)

	# Lighter upper brow & cheek ruff plane
	var cheek := PackedVector2Array([
		head_pos + Vector2(-4.0, 1.5),
		head_pos + Vector2(4.0, 0.5),
		head_pos + Vector2(9.5, 3.8),
		head_pos + Vector2(1.5, 6.2),
		head_pos + Vector2(-4.5, 4.8)
	])
	draw_colored_polygon(cheek, COLOR_FUR_MID)

	# Moonlight rim along brow & muzzle bridge
	draw_polyline(PackedVector2Array([
		head_pos + Vector2(-1.5, -8.2),
		head_pos + Vector2(5.0, -7.2),
		head_pos + Vector2(10.5, -3.6),
		head_pos + Vector2(20.5, 0.0)
	]), COLOR_RIM, 1.4, true)

	# Dark glossy vulpine nose tip + glowing cheek whiskers
	draw_circle(head_pos + Vector2(20.4, 0.8), 1.5, Color(0.015, 0.025, 0.05, 1.0))
	draw_line(head_pos + Vector2(13.5, 2.2), head_pos + Vector2(18.5, 5.2), Color(0.62, 0.94, 0.88, 0.35), 0.8, true)
	draw_line(head_pos + Vector2(12.2, 3.2), head_pos + Vector2(16.8, 6.6), Color(0.62, 0.94, 0.88, 0.28), 0.8, true)

	# Front triangular ear with dark base, moonlight rim, and glowing mint inner vein
	var front_tip := head_pos + Vector2(2.2 - ear_pin * 11.5, -19.5 + ear_pin * 6.8)
	var front_ear := PackedVector2Array([
		head_pos + Vector2(-3.0, -2.5),
		front_tip,
		head_pos + Vector2(5.8, -3.0)
	])
	draw_colored_polygon(front_ear, COLOR_FUR_MID)
	draw_polyline(PackedVector2Array([head_pos + Vector2(-2.6, -3.0), front_tip]), COLOR_RIM, 1.2, true)
	draw_line(head_pos + Vector2(1.4, -4.5), front_tip.lerp(head_pos + Vector2(1.4, -4.5), 0.22), COLOR_MINT, 1.6, true)

	# Piercing layered glowing mint eye (outer aura -> emerald iris -> radiant pupil -> specular glint)
	var eye_pos := head_pos + Vector2(8.8, -1.6)
	draw_circle(eye_pos, 5.6 * clampf(flow_boost, 0.85, 1.25), Color(0.31, 1.0, 0.69, 0.26))
	var eye_slit := PackedVector2Array([
		eye_pos + Vector2(-2.8, -0.4),
		eye_pos + Vector2(0.4, -2.1),
		eye_pos + Vector2(3.1, 0.2),
		eye_pos + Vector2(0.2, 1.8)
	])
	draw_colored_polygon(eye_slit, COLOR_MINT)
	draw_circle(eye_pos + Vector2(0.4, -0.3), 1.05, COLOR_MINT_BRIGHT)

func _draw_digitigrade_leg(hip: Vector2, phase: float, is_front: bool, is_far: bool, flow_boost: float) -> void:
	var s := sin(phase)
	var c := cos(phase)
	var thigh_a: float
	var knee_a: float
	var hock_a: float
	if is_dashing:
		thigh_a = -1.22 if is_front else 1.24
		knee_a = 0.48 if is_front else -0.38
		hock_a = -0.22 if is_front else 0.26
	elif is_airborne:
		var leap_t := clampf(vy / 650.0, -1.0, 1.0)
		thigh_a = (-0.98 + leap_t * 0.45) if is_front else (0.98 - leap_t * 0.35)
		knee_a = 0.68 if is_front else -0.58
		hock_a = -0.25 if is_front else 0.35
	else:
		thigh_a = s * (0.76 if is_front else 0.84) + (-0.16 if is_front else 0.18)
		knee_a = (0.48 if is_front else -0.62) + maxf(0.0, c) * (0.44 if is_front else -0.48)
		hock_a = (-0.24 if is_front else 0.42) + sin(phase + 0.6) * 0.18

	var l1 := 8.8 if is_front else 9.8
	var l2 := 7.6 if is_front else 8.4
	var l3 := 5.2 if is_front else 5.6
	var knee := hip + Vector2(sin(thigh_a), cos(thigh_a)) * l1
	var hock := knee + Vector2(sin(thigh_a + knee_a), cos(thigh_a + knee_a)) * l2
	var paw := hock + Vector2(sin(thigh_a + knee_a + hock_a), cos(thigh_a + knee_a + hock_a)) * l3

	var leg_col := COLOR_FUR_FAR if is_far else COLOR_FUR_DARK
	var hl_col := Color(COLOR_RIM.r, COLOR_RIM.g, COLOR_RIM.b, 0.18 if is_far else 0.38)
	draw_line(hip, knee, leg_col, 4.8 if is_front else 5.8, true)
	draw_line(knee, hock, leg_col, 3.4 if is_front else 3.8, true)
	draw_line(hock, paw, leg_col, 2.5, true)
	if not is_far:
		draw_line(hip + Vector2(1.0, 0.0), knee + Vector2(1.0, 0.0), hl_col, 1.1, true)

	# Glowing mint bioluminescent paw sock & pad
	var paw_alpha := 0.52 if is_far else clampf(0.92 * flow_boost, 0.75, 1.0)
	draw_line(hock.lerp(paw, 0.45), paw, Color(0.31, 1.0, 0.69, paw_alpha * 0.75), 2.4, true)
	draw_circle(paw + Vector2(1.3, 0.0), 2.6, Color(0.31, 1.0, 0.69, paw_alpha))
	if not is_far:
		draw_circle(paw + Vector2(1.5, 0.0), 1.2, COLOR_MINT_BRIGHT)

func _draw_brush_tail(flow_boost: float) -> void:
	var count := tail_nodes.size()
	if count < 4:
		return
	var widths := [4.2, 7.2, 10.4, 12.2, 12.4, 11.0, 9.0, 6.4, 3.6, 1.2]
	var upper: Array[Vector2] = []
	var lower: Array[Vector2] = []
	for i in range(count):
		var curr := tail_nodes[i]
		var prev := tail_nodes[maxi(0, i - 1)]
		var nxt := tail_nodes[mini(count - 1, i + 1)]
		var dir := (nxt - prev).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var w: float = widths[mini(widths.size() - 1, i)]
		upper.append(curr + nrm * w)
		lower.append(curr - nrm * w)

	var poly := PackedVector2Array()
	for p in upper:
		poly.append(p)
	for i in range(count - 1, -1, -1):
		poly.append(lower[i])
	draw_colored_polygon(poly, COLOR_FUR_DARK)

	# Moonlight rim along upper edge of brush tail
	var upper_edge := PackedVector2Array()
	for i in range(count - 2):
		upper_edge.append(upper[i])
	draw_polyline(upper_edge, COLOR_RIM * Color(1, 1, 1, 0.65), 1.3, true)

	# Feathery glowing mint energy plume covering the outer third of the tail
	var plume := PackedVector2Array()
	for i in range(count - 4, count):
		plume.append(upper[i])
	for i in range(count - 1, count - 5, -1):
		plume.append(lower[i])
	draw_colored_polygon(plume, Color(0.18, 0.72, 0.56, 0.45 * clampf(flow_boost, 0.8, 1.2)))

	# Radiant bioluminescent tail tip & trailing spine wisp
	var tip := tail_nodes[count - 1]
	var mid := tail_nodes[count - 4]
	draw_circle(tip, 15.0 * clampf(flow_boost, 0.85, 1.3), Color(0.31, 1.0, 0.69, 0.24))
	draw_circle(tip, 6.2, COLOR_MINT)
	draw_circle(tip, 2.8, COLOR_MINT_BRIGHT)
	draw_polyline(PackedVector2Array([mid, tail_nodes[count - 3], tail_nodes[count - 2], tip]), Color(0.55, 1.0, 0.84, 0.9), 2.8, true)
