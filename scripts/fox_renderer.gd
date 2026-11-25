extends Node2D
class_name FoxRenderer

## Painterly Organic Bioluminescent Spirit Fox Renderer
## Smooth Bezier-curved vulpine anatomy with rich natural-fantasy coloration:
## - Warm twilight-indigo & deep teal dorsal coat transitioning into luminous silver-ivory ruff & belly
## - Smooth tapered organic limbs in true 4-beat rotary gallop (zero robotic facets or hard aura discs)
## - Fluid 11-node Verlet feathered brush tail with layered indigo, ivory, and emerald-mint plume
## - Expressive head with curved ears, soft fur cheek tufts, glowing emerald-mint iris & spirit runes

const COL_MINT: Color = Color(0.31, 1.0, 0.69, 1.0)
const COL_MINT_SOFT: Color = Color(0.62, 1.0, 0.84, 0.85)
const COL_MINT_CORE: Color = Color(0.92, 1.0, 0.97, 1.0)
const COL_FUR_DEEP: Color = Color(0.11, 0.17, 0.29, 1.0)
const COL_FUR_MID: Color = Color(0.19, 0.30, 0.45, 1.0)
const COL_FUR_WARM: Color = Color(0.28, 0.44, 0.58, 1.0)
const COL_FUR_FAR: Color = Color(0.08, 0.13, 0.22, 1.0)
const COL_CREAM: Color = Color(0.76, 0.92, 0.90, 1.0)
const COL_CREAM_SHADE: Color = Color(0.46, 0.66, 0.72, 1.0)
const COL_RIM: Color = Color(0.84, 0.97, 1.0, 0.72)

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
	_init_tail()

func _init_tail() -> void:
	tail_nodes.resize(11)
	for i in range(11):
		var frac: float = float(i) / 10.0
		tail_nodes[i] = Vector2(-17.0 - float(i) * 6.5, -18.5 + sin(frac * PI) * -5.5)

func sync_state(p_gait: float, p_dash: bool, p_air: bool, p_vy: float, p_speed_ratio: float, p_flow: int, p_morph: float, dt: float) -> void:
	if tail_nodes.size() < 11:
		_init_tail()
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
	var anchor_y: float = -12.0 if is_dashing else -19.0 + sin(gait_phase * 2.0) * 1.4
	tail_nodes[0] = Vector2(-18.0, anchor_y)
	var seg_len: float = 6.6
	var follow: float = 1.0 - exp(-20.0 * maxf(dt, 0.001))
	for i in range(1, tail_nodes.size()):
		var prev: Vector2 = tail_nodes[i - 1]
		var wave: float = sin(gait_phase * 0.9 - float(i) * 0.48 + _time * 2.6) * (2.4 + float(i) * 0.65)
		var lift: float = -1.1 if not is_dashing else 0.1
		var target: Vector2 = Vector2(prev.x - seg_len, prev.y + lift + wave * 0.34 - vy * 0.0065)
		var curr: Vector2 = tail_nodes[i].lerp(target, follow)
		var delta: Vector2 = curr - prev
		if delta.length() > seg_len:
			curr = prev + delta.normalized() * seg_len
		tail_nodes[i] = curr

func _quad_pts(p0: Vector2, p1: Vector2, p2: Vector2, steps: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var u: float = 1.0 - t
		out.append(u * u * p0 + 2.0 * u * t * p1 + t * t * p2)
	return out

func _draw() -> void:
	if tail_nodes.size() < 11:
		_init_tail()
	var dash_boost: float = 0.35 if is_dashing else 0.0
	var flow_boost: float = clampf(0.85 + float(flow_multiplier - 1) * 0.08 + dash_boost, 0.85, 1.55)

	# Soft elliptical ground contact shadow when grounded
	if not is_airborne:
		_draw_soft_ellipse(Vector2(0.0, 1.5), 26.0 if is_dashing else 22.0, 3.6, Color(0.01, 0.02, 0.04, 0.46))

	# Lush organic curved Verlet brush tail behind body
	_draw_brush_tail(flow_boost)

	# Fluid 4-beat gallop kinematics: arched spine extension/gather + chest bob
	var body_drop: float = 6.2 if is_dashing else 0.0
	var gallop_wave: float = sin(gait_phase)
	var bob: float = 0.0 if is_airborne else (absf(sin(gait_phase)) * -3.8)
	var stretch_x: float = 1.13 if is_dashing else (1.0 + gallop_wave * 0.07)
	var stretch_y: float = 0.87 if is_dashing else (1.0 - gallop_wave * 0.05)
	var pitch: float = cos(gait_phase) * 0.08
	if is_dashing:
		pitch = 0.05
	elif is_airborne:
		pitch = clampf(vy * 0.00052, -0.34, 0.32)

	draw_set_transform(Vector2(0.0, body_drop + bob), pitch, Vector2(stretch_x, stretch_y))

	# Far organic digitigrade legs
	_draw_organic_leg(Vector2(-14.5, -16.2), gait_phase + PI * 0.36, false, true, flow_boost)
	_draw_organic_leg(Vector2(11.5, -16.8), gait_phase + PI * 1.28, true, true, flow_boost)

	# Smooth Bezier-contoured vulpine torso (upper back + rounded haunch + lithe waist + deep chest)
	var spine_flex: float = -3.4 if is_airborne else sin(gait_phase) * 3.0
	var torso: PackedVector2Array = PackedVector2Array()
	for p in _quad_pts(Vector2(-22.5, -15.5), Vector2(-10.0, -28.0 + spine_flex * 1.1), Vector2(5.0, -26.5 + spine_flex * 0.4), 6):
		torso.append(p)
	for p in _quad_pts(Vector2(5.0, -26.5 + spine_flex * 0.4), Vector2(18.5, -24.5), Vector2(22.5, -16.5), 5):
		torso.append(p)
	for p in _quad_pts(Vector2(22.5, -16.5), Vector2(19.0, -9.2), Vector2(7.0, -10.5), 5):
		torso.append(p)
	for p in _quad_pts(Vector2(7.0, -10.5), Vector2(-5.5, -13.5 + spine_flex * 0.35), Vector2(-16.5, -10.5), 5):
		torso.append(p)
	torso.append(Vector2(-22.0, -12.5))
	draw_colored_polygon(torso, COL_FUR_DEEP)

	# Upper moonlit mid-tone coat smoothly layered over back & shoulder
	var coat: PackedVector2Array = PackedVector2Array()
	for p in _quad_pts(Vector2(-20.0, -17.5), Vector2(-9.5, -27.2 + spine_flex), Vector2(5.0, -26.0 + spine_flex * 0.4), 6):
		coat.append(p)
	for p in _quad_pts(Vector2(5.0, -26.0 + spine_flex * 0.4), Vector2(16.0, -23.5), Vector2(19.0, -17.0), 4):
		coat.append(p)
	for p in _quad_pts(Vector2(19.0, -17.0), Vector2(4.0, -18.5), Vector2(-16.0, -16.5), 5):
		coat.append(p)
	draw_colored_polygon(coat, COL_FUR_MID)

	# Warm moonlit shoulder-crest sheen
	var sheen: PackedVector2Array = PackedVector2Array()
	for p in _quad_pts(Vector2(-12.0, -23.5 + spine_flex * 0.8), Vector2(0.0, -26.8 + spine_flex * 0.6), Vector2(13.5, -23.2), 5):
		sheen.append(p)
	sheen.append(Vector2(11.0, -20.8))
	sheen.append(Vector2(-9.5, -20.5))
	draw_colored_polygon(sheen, COL_FUR_WARM)

	# Soft silver-ivory chest ruff & belly fur (classic natural fox coloration!)
	var chest_fur: PackedVector2Array = PackedVector2Array()
	for p in _quad_pts(Vector2(10.0, -21.0), Vector2(23.0, -18.0), Vector2(25.2, -13.5), 4):
		chest_fur.append(p)
	chest_fur.append(Vector2(21.0, -11.5))
	chest_fur.append(Vector2(22.4, -9.2))
	chest_fur.append(Vector2(15.5, -9.0))
	chest_fur.append(Vector2(16.2, -7.4))
	for p in _quad_pts(Vector2(11.5, -9.5), Vector2(3.5, -10.8), Vector2(-6.5, -12.2), 4):
		chest_fur.append(p)
	chest_fur.append(Vector2(4.0, -15.5))
	draw_colored_polygon(chest_fur, COL_CREAM)

	# Soft shading fold inside chest ruff
	draw_polyline(PackedVector2Array([
		Vector2(13.0, -16.0), Vector2(18.5, -13.8), Vector2(22.5, -13.2)
	]), COL_CREAM_SHADE * Color(1, 1, 1, 0.7), 1.4, true)

	# Crisp natural moonlight rim tracing the spine curve
	var rim_curve: PackedVector2Array = _quad_pts(Vector2(-20.5, -17.8), Vector2(-8.5, -27.5 + spine_flex), Vector2(16.0, -23.8), 8)
	draw_polyline(rim_curve, COL_RIM, 1.5, true)

	# Delicate organic spirit-mint markings flowing along shoulder & flank
	var rune_col: Color = Color(COL_MINT.r, COL_MINT.g, COL_MINT.b, clampf(0.84 * flow_boost, 0.65, 1.0))
	draw_polyline(_quad_pts(Vector2(1.5, -21.8), Vector2(9.5, -21.5), Vector2(15.5, -17.2), 5), rune_col, 1.8, true)
	draw_polyline(_quad_pts(Vector2(-15.5, -19.8), Vector2(-10.0, -19.2), Vector2(-6.8, -15.2), 4), rune_col * Color(1, 1, 1, 0.75), 1.3, true)
	draw_circle(Vector2(10.0, -20.8), 1.6, COL_MINT_CORE)

	# Expressive painterly vulpine head
	_draw_head(flow_boost, -pitch * 0.42)

	# Near organic digitigrade legs
	_draw_organic_leg(Vector2(-15.2, -15.0), gait_phase, false, false, flow_boost)
	_draw_organic_leg(Vector2(12.2, -16.0), gait_phase + PI * 0.94, true, false, flow_boost)

	# Subtle radial morph ring only during the 0.14s shift burst
	if morph_ratio > 0.02:
		draw_arc(Vector2(2.0, -18.0), 26.0 + (1.0 - morph_ratio) * 14.0, 0.0, TAU, 32, Color(0.31, 1.0, 0.69, morph_ratio * 0.85), 2.2, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_head(flow_boost: float, counter_pitch: float) -> void:
	var air_pin: float = 0.15 if is_airborne else 0.0
	var ear_bounce: float = sin(gait_phase * 2.0 - 0.5) * 0.08 if not is_airborne else 0.0
	var ear_pin: float = 0.58 if is_dashing else clampf(speed_ratio * 0.34 + air_pin + ear_bounce, 0.0, 0.54)
	var hp: Vector2 = Vector2(17.5, -23.5 + sin(gait_phase + 0.4) * 1.1)
	var md: float = counter_pitch * 3.6

	# Back ear (softly curved organic ear silhouette)
	var b_tip: Vector2 = hp + Vector2(-1.5 - ear_pin * 10.5, -17.5 + ear_pin * 6.0)
	var b_ear: PackedVector2Array = PackedVector2Array()
	for p in _quad_pts(hp + Vector2(-4.8, -3.5), hp + Vector2(-5.2 - ear_pin * 4.0, -11.5), b_tip, 4):
		b_ear.append(p)
	for p in _quad_pts(b_tip, hp + Vector2(2.0 - ear_pin * 3.0, -10.5), hp + Vector2(3.2, -4.5), 4):
		b_ear.append(p)
	draw_colored_polygon(b_ear, COL_FUR_FAR)

	# Smooth Bezier-sculpted vulpine head & slender pointed snout
	var head_poly: PackedVector2Array = PackedVector2Array()
	for p in _quad_pts(hp + Vector2(-7.0, -2.5), hp + Vector2(-1.5, -9.2), hp + Vector2(6.5, -6.8), 5):
		head_poly.append(p)
	for p in _quad_pts(hp + Vector2(6.5, -6.8), hp + Vector2(13.5, -3.4 + md * 0.5), hp + Vector2(22.2, 0.2 + md), 4):
		head_poly.append(p)
	for p in _quad_pts(hp + Vector2(22.2, 0.2 + md), hp + Vector2(19.0, 4.2 + md * 0.7), hp + Vector2(11.0, 4.6), 4):
		head_poly.append(p)
	head_poly.append(hp + Vector2(5.5, 5.2))
	head_poly.append(hp + Vector2(1.2, 7.6))
	head_poly.append(hp + Vector2(-2.6, 5.8))
	head_poly.append(hp + Vector2(-6.5, 6.2))
	draw_colored_polygon(head_poly, COL_FUR_MID)

	# Soft luminous silver-ivory lower jaw & fluffy cheek ruff
	var cheek: PackedVector2Array = PackedVector2Array([
		hp + Vector2(-5.5, 1.8),
		hp + Vector2(3.5, 0.4),
		hp + Vector2(13.5, 2.2 + md * 0.4),
		hp + Vector2(19.0, 2.6 + md * 0.8),
		hp + Vector2(11.5, 4.8),
		hp + Vector2(5.5, 5.4),
		hp + Vector2(1.2, 7.6),
		hp + Vector2(-2.8, 5.8),
		hp + Vector2(-6.2, 5.8)
	])
	draw_colored_polygon(cheek, COL_CREAM)

	# Moonlight rim along forehead & bridge of muzzle
	draw_polyline(_quad_pts(hp + Vector2(-1.2, -8.6), hp + Vector2(9.0, -5.8), hp + Vector2(21.4, 0.1 + md), 6), COL_RIM, 1.4, true)

	# Dark nose tip & delicate soft whiskers
	draw_circle(hp + Vector2(21.6, 0.7 + md), 1.5, Color(0.03, 0.05, 0.1, 1.0))
	draw_line(hp + Vector2(14.0, 2.5), hp + Vector2(19.5, 5.2), Color(0.84, 0.98, 0.96, 0.45), 0.85, true)
	draw_line(hp + Vector2(12.8, 3.6), hp + Vector2(17.8, 6.8), Color(0.84, 0.98, 0.96, 0.35), 0.85, true)

	# Front ear with curved fur edge, dark tip, and glowing mint inner fluff
	var f_tip: Vector2 = hp + Vector2(2.2 - ear_pin * 10.8, -19.8 + ear_pin * 6.4)
	var f_ear: PackedVector2Array = PackedVector2Array()
	for p in _quad_pts(hp + Vector2(-3.2, -2.5), hp + Vector2(-2.6 - ear_pin * 4.5, -11.5), f_tip, 4):
		f_ear.append(p)
	for p in _quad_pts(f_tip, hp + Vector2(5.8 - ear_pin * 3.0, -11.2), hp + Vector2(6.0, -3.2), 4):
		f_ear.append(p)
	draw_colored_polygon(f_ear, COL_FUR_WARM)
	var inner_ear: PackedVector2Array = PackedVector2Array([
		hp + Vector2(-0.8, -4.2), f_tip.lerp(hp + Vector2(1.4, -4.0), 0.28), hp + Vector2(3.8, -4.4)
	])
	draw_colored_polygon(inner_ear, COL_CREAM_SHADE)
	draw_line(hp + Vector2(1.4, -4.8), f_tip.lerp(hp + Vector2(1.4, -4.8), 0.24), COL_MINT, 1.5, true)
	draw_polyline(_quad_pts(hp + Vector2(-2.8, -3.2), hp + Vector2(-2.2 - ear_pin * 4.2, -11.5), f_tip, 4), COL_RIM, 1.25, true)

	# Expressive almond-shaped glowing emerald-mint eye
	var eye_p: Vector2 = hp + Vector2(9.2, -1.6)
	var eye_slit: PackedVector2Array = PackedVector2Array([
		eye_p + Vector2(-3.1, -0.4),
		eye_p + Vector2(0.4, -2.3),
		eye_p + Vector2(3.3, 0.2),
		eye_p + Vector2(0.2, 1.9)
	])
	draw_colored_polygon(eye_slit, COL_MINT)
	draw_circle(eye_p + Vector2(0.6, -0.35), 1.2, COL_MINT_CORE)

func _draw_organic_leg(hip: Vector2, phase: float, is_front: bool, is_far: bool, flow_boost: float) -> void:
	var s: float = sin(phase)
	var c: float = cos(phase)
	var thigh_a: float
	var knee_a: float
	var hock_a: float
	if is_dashing:
		thigh_a = -1.22 if is_front else 1.24
		knee_a = 0.45 if is_front else -0.36
		hock_a = -0.20 if is_front else 0.24
	elif is_airborne:
		var leap_t: float = clampf(vy / 650.0, -1.0, 1.0)
		thigh_a = (-1.0 + leap_t * 0.42) if is_front else (1.0 - leap_t * 0.34)
		knee_a = 0.70 if is_front else -0.60
		hock_a = -0.24 if is_front else 0.34
	else:
		thigh_a = s * (0.80 if is_front else 0.86) + (-0.15 if is_front else 0.20)
		knee_a = (0.48 if is_front else -0.64) + maxf(0.0, c) * (0.46 if is_front else -0.50)
		hock_a = (-0.24 if is_front else 0.44) + sin(phase + 0.6) * 0.20

	var l1: float = 9.0 if is_front else 10.2
	var l2: float = 7.8 if is_front else 8.6
	var l3: float = 5.4 if is_front else 5.8
	var knee: Vector2 = hip + Vector2(sin(thigh_a), cos(thigh_a)) * l1
	var hock: Vector2 = knee + Vector2(sin(thigh_a + knee_a), cos(thigh_a + knee_a)) * l2
	var paw: Vector2 = hock + Vector2(sin(thigh_a + knee_a + hock_a), cos(thigh_a + knee_a + hock_a)) * l3

	var upper_col: Color = COL_FUR_FAR if is_far else COL_FUR_MID
	var lower_col: Color = COL_FUR_FAR if is_far else COL_FUR_DEEP
	_draw_capsule_seg(hip, knee, 4.4 if is_front else 5.4, 2.7 if is_front else 3.2, upper_col)
	_draw_capsule_seg(knee, hock, 2.5 if is_front else 2.9, 1.7, lower_col)
	_draw_capsule_seg(hock, paw, 1.7, 1.3, lower_col)

	# Glowing spirit-mint paw socks
	var paw_a: float = 0.56 if is_far else clampf(0.95 * flow_boost, 0.8, 1.0)
	_draw_capsule_seg(hock.lerp(paw, 0.42), paw, 1.8, 1.5, Color(0.31, 1.0, 0.69, paw_a * 0.85))
	var paw_poly: PackedVector2Array = PackedVector2Array([
		paw + Vector2(-2.2, 0.5), paw + Vector2(0.8, -1.6), paw + Vector2(4.5, 0.4), paw + Vector2(1.2, 1.8)
	])
	draw_colored_polygon(paw_poly, Color(0.31, 1.0, 0.69, paw_a))
	if not is_far:
		draw_circle(paw + Vector2(1.5, 0.0), 1.2, COL_MINT_CORE)

func _draw_capsule_seg(a: Vector2, b: Vector2, r0: float, r1: float, col: Color) -> void:
	var diff: Vector2 = b - a
	if diff.length_squared() < 0.001:
		return
	var dir: Vector2 = diff.normalized()
	var nrm: Vector2 = Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([a + nrm * r0, b + nrm * r1, b - nrm * r1, a - nrm * r0]), col)
	draw_circle(a, r0 * 0.94, col)
	draw_circle(b, r1 * 0.94, col)

func _draw_soft_ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(16):
		var ang: float = (float(i) / 16.0) * TAU
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_colored_polygon(pts, col)

func _draw_brush_tail(flow_boost: float) -> void:
	var count: int = tail_nodes.size()
	var widths: PackedFloat32Array = PackedFloat32Array([3.8, 6.6, 9.4, 11.4, 11.8, 11.0, 9.2, 6.8, 4.4, 2.2, 0.6])
	var upper: Array[Vector2] = []
	var lower: Array[Vector2] = []
	for i in range(count):
		var curr: Vector2 = tail_nodes[i]
		var prev: Vector2 = tail_nodes[maxi(0, i - 1)]
		var nxt: Vector2 = tail_nodes[mini(count - 1, i + 1)]
		var diff: Vector2 = nxt - prev
		var dir: Vector2 = diff.normalized() if diff.length_squared() > 0.001 else Vector2(-1.0, 0.0)
		var nrm: Vector2 = Vector2(-dir.y, dir.x)
		var w: float = widths[i]
		upper.append(curr + nrm * w)
		lower.append(curr - nrm * w)

	var poly: PackedVector2Array = PackedVector2Array()
	for p in upper:
		poly.append(p)
	for i in range(count - 1, -1, -1):
		poly.append(lower[i])
	draw_colored_polygon(poly, COL_FUR_MID)

	# Shaded underside volume
	var under: PackedVector2Array = PackedVector2Array()
	for i in range(count):
		under.append(tail_nodes[i])
	for i in range(count - 1, -1, -1):
		under.append(lower[i])
	draw_colored_polygon(under, COL_FUR_DEEP)

	# Soft silver-ivory outer plume (classic fox brush tip!)
	var tip_dir: Vector2 = (tail_nodes[count - 1] - tail_nodes[count - 2]).normalized()
	var ivory_plume: PackedVector2Array = PackedVector2Array()
	for i in range(count - 5, count):
		ivory_plume.append(upper[i])
	ivory_plume.append(tail_nodes[count - 1] + tip_dir * 6.5)
	for i in range(count - 1, count - 6, -1):
		ivory_plume.append(lower[i])
	draw_colored_polygon(ivory_plume, COL_CREAM)

	# Flowing emerald-mint spirit energy ribbons woven into tail tip
	var mint_plume: PackedVector2Array = PackedVector2Array()
	for i in range(count - 4, count):
		mint_plume.append(upper[i].lerp(tail_nodes[i], 0.35))
	mint_plume.append(tail_nodes[count - 1] + tip_dir * 7.5)
	for i in range(count - 1, count - 5, -1):
		mint_plume.append(lower[i].lerp(tail_nodes[i], 0.35))
	draw_colored_polygon(mint_plume, Color(0.31, 1.0, 0.69, 0.72 * clampf(flow_boost, 0.85, 1.2)))

	var upper_edge: PackedVector2Array = PackedVector2Array()
	for i in range(count - 1):
		upper_edge.append(upper[i])
	draw_polyline(upper_edge, COL_RIM * Color(1, 1, 1, 0.68), 1.4, true)
	draw_polyline(PackedVector2Array([tail_nodes[count - 5], tail_nodes[count - 3], tail_nodes[count - 1] + tip_dir * 5.0]), COL_MINT_CORE * Color(1, 1, 1, 0.85), 1.8, true)
