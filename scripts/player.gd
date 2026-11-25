extends CharacterBody2D
class_name PlayerController

## UMBRA SHIFT — Core 3-Form Shapeshifting Player Controller (Godot 4 GDScript)
## Supports direct form selection (1/J, 2/K, 3/L), Q/E & Left/Right cycling,
## 0.12s coyote time, 0.12s jump & morph buffering, momentum conservation,
## and real Godot AnimationPlayer squash-and-stretch / morph / dash / stumble clips.

enum Form { FOX, MOTH, PANGOLIN }

signal form_shifted(prev_form: int, new_form: int, world_pos: Vector2)
signal jumped(form: int, is_double: bool, world_pos: Vector2)
signal dashed(world_pos: Vector2)
signal fluttered(world_pos: Vector2)
signal landed(form: int, is_slam: bool, world_pos: Vector2)
signal paw_stepped(world_pos: Vector2)

const BASE_VISUAL_SCALE: Vector2 = Vector2(1.28, 1.28)

const FOX_BASE_SPEED: float = 515.0
const MOTH_BASE_SPEED: float = 435.0
const PANGOLIN_BASE_SPEED: float = 470.0
const MAX_BONUS_SPEED: float = 280.0

const FOX_GRAVITY: float = 2150.0
const MOTH_GRAVITY: float = 520.0
const MOTH_MAX_FALL: float = 155.0
const PANGOLIN_GRAVITY: float = 2850.0
const PANGOLIN_SLAM_SPEED: float = 1180.0

const FOX_JUMP_VEL: float = -760.0
const FOX_DOUBLE_JUMP_VEL: float = -670.0
const FOX_DASH_SPEED: float = 340.0
const FOX_DASH_DURATION: float = 0.34
const FOX_DASH_COOLDOWN: float = 0.72
const MOTH_FLUTTER_VEL: float = -380.0
const MOTH_FLUTTER_COOLDOWN: float = 0.22

const COYOTE_DURATION: float = 0.13
const JUMP_BUFFER_DURATION: float = 0.13
const MORPH_BUFFER_DURATION: float = 0.10
const MORPH_EFFECT_DURATION: float = 0.14

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual_root: Node2D = $VisualRoot
@onready var fox_renderer: FoxRenderer = $VisualRoot/FoxRenderer
@onready var moth_renderer: MothRenderer = $VisualRoot/MothRenderer
@onready var pangolin_renderer: PangolinRenderer = $VisualRoot/PangolinRenderer
@onready var moth_ribbon: Line2D = $MothRibbon
@onready var trail_particles: CPUParticles2D = $TrailParticles
@onready var burst_particles: CPUParticles2D = $BurstParticles
@onready var aura_light: PointLight2D = $AuraLight
@onready var anim_player: AnimationPlayer = $AnimPlayer

var current_form: int = Form.FOX
var grounded: bool = true
var jumps_remaining: int = 2
var coyote_timer: float = COYOTE_DURATION
var jump_buffer_timer: float = 0.0
var morph_buffer_form: int = -1
var morph_buffer_timer: float = 0.0
var morph_anim_timer: float = 0.0

var dash_timer: float = 0.0
var dash_cooldown: float = 0.0
var flutter_cooldown: float = 0.0
var wing_phase: float = 0.0
var wing_boost: float = 0.0
var is_slamming: bool = false
var is_curled: bool = false
var is_under_tunnel: bool = false
var roll_angle: float = 0.0
var gait_phase: float = 0.0
var stumble_timer: float = 0.0
var invuln_timer: float = 0.0
var momentum_bonus: float = 0.0
var alive: bool = true

var _trail_points: Array[Vector2] = []

func _ready() -> void:
	_ensure_animations()

func _ensure_animations() -> void:
	if anim_player == null:
		return
	if anim_player.has_animation("morph_pop"):
		return
	var lib: AnimationLibrary = AnimationLibrary.new()
	lib.add_animation("RESET", _make_clip(0.01, [0.0], [BASE_VISUAL_SCALE], [0.0], [0.0], [0.0], [1.35]))
	lib.add_animation("morph_pop", _make_clip(0.24, [0.0, 0.06, 0.14, 0.24], [Vector2(1.56, 0.96), Vector2(1.08, 1.48), Vector2(1.34, 1.21), BASE_VISUAL_SCALE], [0.0, 0.08, 0.24], [-0.14, 0.07, 0.0], [0.0, 0.06, 0.24], [2.75, 2.05, 1.35]))
	lib.add_animation("jump_stretch", _make_clip(0.22, [0.0, 0.06, 0.22], [Vector2(1.04, 1.56), Vector2(1.14, 1.41), BASE_VISUAL_SCALE], [0.0, 0.1, 0.22], [-0.12, -0.05, 0.0], [], []))
	lib.add_animation("land_squash", _make_clip(0.2, [0.0, 0.06, 0.14, 0.2], [Vector2(1.60, 0.94), Vector2(1.39, 1.14), Vector2(1.24, 1.32), BASE_VISUAL_SCALE], [0.0, 0.08, 0.2], [0.06, -0.02, 0.0], [], []))
	lib.add_animation("dash_surge", _make_clip(0.28, [0.0, 0.08, 0.2, 0.28], [Vector2(1.70, 0.92), Vector2(1.56, 1.00), Vector2(1.35, 1.21), BASE_VISUAL_SCALE], [0.0, 0.1, 0.28], [0.09, 0.05, 0.0], [0.0, 0.1, 0.28], [2.4, 1.9, 1.35]))
	lib.add_animation("stumble_shake", _make_clip(0.32, [0.0, 0.08, 0.2, 0.32], [Vector2(1.45, 1.04), Vector2(1.12, 1.41), Vector2(1.33, 1.21), BASE_VISUAL_SCALE], [0.0, 0.06, 0.12, 0.18, 0.26, 0.32], [-0.24, 0.2, -0.15, 0.11, -0.05, 0.0], [], []))
	if anim_player.has_animation_library(""):
		anim_player.remove_animation_library("")
	anim_player.add_animation_library("", lib)

func _make_clip(dur: float, s_times: Array, s_vals: Array, r_times: Array, r_vals: Array, e_times: Array, e_vals: Array) -> Animation:
	var a: Animation = Animation.new()
	a.length = dur
	var t0: int = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t0, NodePath("VisualRoot:scale"))
	a.track_set_interpolation_type(t0, Animation.INTERPOLATION_CUBIC)
	for i in range(s_times.size()):
		a.track_insert_key(t0, float(s_times[i]), s_vals[i])
	var t1: int = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t1, NodePath("VisualRoot:rotation"))
	a.track_set_interpolation_type(t1, Animation.INTERPOLATION_CUBIC)
	for i in range(r_times.size()):
		a.track_insert_key(t1, float(r_times[i]), float(r_vals[i]))
	if e_times.size() > 0:
		var t2: int = a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(t2, NodePath("AuraLight:energy"))
		a.track_set_interpolation_type(t2, Animation.INTERPOLATION_LINEAR)
		for i in range(e_times.size()):
			a.track_insert_key(t2, float(e_times[i]), float(e_vals[i]))
	return a

func play_clip(clip_name: String) -> void:
	if anim_player != null and anim_player.has_animation(clip_name):
		anim_player.stop()
		anim_player.play(clip_name)

func _fire_burst(col: Color, vel_max: float = 240.0, offset_y: float = -20.0) -> void:
	if burst_particles == null:
		return
	burst_particles.position = Vector2(0.0, offset_y)
	burst_particles.color = col
	burst_particles.initial_velocity_max = vel_max
	burst_particles.restart()
	burst_particles.emitting = true

func reset_player() -> void:
	position = Vector2.ZERO
	velocity = Vector2(FOX_BASE_SPEED, 0.0)
	current_form = Form.FOX
	grounded = true
	jumps_remaining = 2
	coyote_timer = COYOTE_DURATION
	jump_buffer_timer = 0.0
	morph_buffer_form = -1
	morph_buffer_timer = 0.0
	morph_anim_timer = 0.0
	dash_timer = 0.0
	dash_cooldown = 0.0
	flutter_cooldown = 0.0
	wing_phase = 0.0
	wing_boost = 0.0
	is_slamming = false
	is_curled = false
	roll_angle = 0.0
	gait_phase = 0.0
	stumble_timer = 0.0
	invuln_timer = 0.0
	momentum_bonus = 0.0
	alive = true
	_trail_points.clear()
	moth_ribbon.clear_points()
	if anim_player != null:
		anim_player.stop()
	if visual_root != null:
		visual_root.scale = BASE_VISUAL_SCALE
		visual_root.rotation = 0.0
	if trail_particles != null:
		trail_particles.restart()
		trail_particles.emitting = true
	_sync_form_visibility()

func request_form(target: int) -> void:
	if target != current_form:
		morph_buffer_form = target
		morph_buffer_timer = MORPH_BUFFER_DURATION

func cycle_form(dir: int) -> void:
	var nxt: int = (current_form + dir + 3) % 3
	request_form(nxt)

func set_showcase_form(target: int) -> void:
	current_form = target % 3
	morph_buffer_form = -1
	morph_buffer_timer = 0.0
	morph_anim_timer = MORPH_EFFECT_DURATION
	is_curled = current_form == Form.PANGOLIN
	is_slamming = false
	dash_timer = 0.0
	wing_boost = 1.0 if current_form == Form.MOTH else 0.0
	_sync_form_visibility()
	play_clip("morph_pop")
	_fire_burst(get_form_color(), 250.0, -22.0)

func update_showcase(dt: float, flow_multiplier: int, is_dashing_demo: bool, is_air_demo: bool, vy_demo: float) -> void:
	morph_anim_timer = maxf(0.0, morph_anim_timer - dt)
	wing_boost = maxf(0.0, wing_boost - dt * 2.2)
	dash_timer = 0.2 if is_dashing_demo else 0.0
	grounded = not is_air_demo
	velocity = Vector2(560.0 if is_dashing_demo else 490.0, vy_demo)
	gait_phase += (15.5 if is_dashing_demo else 11.2) * dt
	wing_phase += (12.5 + wing_boost * 9.0) * dt
	roll_angle += 9.8 * dt
	_update_moth_ribbon()
	_update_renderers(dt, flow_multiplier)

func trigger_stumble() -> void:
	stumble_timer = 0.52
	invuln_timer = 0.72
	momentum_bonus = 0.0
	play_clip("stumble_shake")
	_fire_burst(Color(0.86, 0.52, 1.0, 0.95), 210.0, -18.0)

func grant_smash_boost(amount: float = 115.0) -> void:
	is_curled = true
	momentum_bonus = minf(220.0, momentum_bonus + amount)
	play_clip("dash_surge")
	_fire_burst(Color(1.0, 0.68, 0.14, 1.0), 320.0, -18.0)

func get_form_color(form_id: int = -1) -> Color:
	var f: int = current_form if form_id < 0 else form_id
	match f:
		Form.FOX:
			return Color(0.31, 1.0, 0.69, 1.0)
		Form.MOTH:
			return Color(0.0, 0.9, 1.0, 1.0)
		_:
			return Color(1.0, 0.62, 0.0, 1.0)

func step_physics(dt: float, difficulty: float, flow_multiplier: int, level_gen: LevelGenerator) -> float:
	if not alive:
		return 0.0

	coyote_timer = maxf(0.0, coyote_timer - dt)
	jump_buffer_timer = maxf(0.0, jump_buffer_timer - dt)
	morph_buffer_timer = maxf(0.0, morph_buffer_timer - dt)
	morph_anim_timer = maxf(0.0, morph_anim_timer - dt)
	dash_timer = maxf(0.0, dash_timer - dt)
	dash_cooldown = maxf(0.0, dash_cooldown - dt)
	flutter_cooldown = maxf(0.0, flutter_cooldown - dt)
	stumble_timer = maxf(0.0, stumble_timer - dt)
	invuln_timer = maxf(0.0, invuln_timer - dt)
	wing_boost = maxf(0.0, wing_boost - dt * 3.2)

	var decay: float = 42.0 if current_form == Form.MOTH else 68.0
	momentum_bonus = maxf(0.0, momentum_bonus - decay * dt)

	# Read dual-style inputs
	if Input.is_action_just_pressed("shift_fox"):
		request_form(Form.FOX)
	elif Input.is_action_just_pressed("shift_moth"):
		request_form(Form.MOTH)
	elif Input.is_action_just_pressed("shift_pangolin"):
		request_form(Form.PANGOLIN)
	elif Input.is_action_just_pressed("cycle_left"):
		cycle_form(-1)
	elif Input.is_action_just_pressed("cycle_right"):
		cycle_form(1)

	if Input.is_action_just_pressed("action_jump"):
		jump_buffer_timer = JUMP_BUFFER_DURATION

	# Execute buffered morph transition (delays standing up inside a tight low root tunnel!)
	if morph_buffer_form >= 0 and morph_buffer_timer > 0.0:
		var blocked_by_roof: bool = current_form == Form.FOX and dash_timer > 0.0 and morph_buffer_form == Form.MOTH and level_gen.is_under_root_tunnel(position.x)
		if not blocked_by_roof:
			_apply_morph(morph_buffer_form)
	elif morph_buffer_timer <= 0.0:
		morph_buffer_form = -1

	var jump_held: bool = Input.is_action_pressed("action_jump")
	var jump_released: bool = Input.is_action_just_released("action_jump")
	var dash_pressed: bool = Input.is_action_just_pressed("action_dash")
	var slam_pressed: bool = Input.is_action_just_pressed("action_slam")
	var slam_held: bool = Input.is_action_pressed("action_slam")

	# Form-specific jump, dash, flutter, and Meteor Slam controls
	match current_form:
		Form.FOX:
			if jump_buffer_timer > 0.0:
				if grounded or coyote_timer > 0.0:
					velocity.y = FOX_JUMP_VEL
					grounded = false
					coyote_timer = 0.0
					jump_buffer_timer = 0.0
					jumps_remaining = 1
					play_clip("jump_stretch")
					_fire_burst(get_form_color(Form.FOX), 190.0, -6.0)
					emit_signal("jumped", Form.FOX, false, global_position)
				elif jumps_remaining > 0:
					velocity.y = FOX_DOUBLE_JUMP_VEL
					jump_buffer_timer = 0.0
					jumps_remaining = 0
					play_clip("jump_stretch")
					_fire_burst(Color(0.55, 1.0, 0.85, 0.95), 250.0, -14.0)
					emit_signal("jumped", Form.FOX, true, global_position)
			if jump_released and velocity.y < -220.0:
				velocity.y *= 0.48
			if (dash_pressed or (slam_pressed and grounded)) and dash_cooldown <= 0.0:
				dash_timer = FOX_DASH_DURATION
				dash_cooldown = FOX_DASH_COOLDOWN
				if not grounded and velocity.y > 0.0:
					velocity.y = 0.0
				play_clip("dash_surge")
				_fire_burst(Color(0.45, 1.0, 0.78, 1.0), 290.0, -16.0)
				emit_signal("dashed", global_position + Vector2(0.0, -14.0))
			if slam_held and not grounded and dash_timer <= 0.0:
				velocity.y += 1250.0 * dt
		Form.MOTH:
			if jump_buffer_timer > 0.0 and flutter_cooldown <= 0.0:
				velocity.y = MOTH_FLUTTER_VEL
				grounded = false
				coyote_timer = 0.0
				jump_buffer_timer = 0.0
				flutter_cooldown = MOTH_FLUTTER_COOLDOWN
				wing_boost = 1.0
				play_clip("jump_stretch")
				_fire_burst(Color(0.28, 0.94, 1.0, 0.95), 220.0, -20.0)
				emit_signal("fluttered", global_position + Vector2(0.0, -18.0))
			if slam_held and not grounded:
				velocity.y += 980.0 * dt
		Form.PANGOLIN:
			if jump_buffer_timer > 0.0 and (grounded or coyote_timer > 0.0):
				velocity.y = -590.0
				grounded = false
				coyote_timer = 0.0
				jump_buffer_timer = 0.0
				is_curled = true
				play_clip("jump_stretch")
				_fire_burst(Color(1.0, 0.66, 0.14, 0.95), 210.0, -8.0)
				emit_signal("jumped", Form.PANGOLIN, false, global_position)
			if slam_pressed and not grounded and not is_slamming:
				is_slamming = true
				is_curled = true
				velocity.y = maxf(velocity.y, PANGOLIN_SLAM_SPEED)
				play_clip("jump_stretch")

	# Target speed & adaptive acceleration
	var base: float = FOX_BASE_SPEED
	if current_form == Form.MOTH:
		base = MOTH_BASE_SPEED
	elif current_form == Form.PANGOLIN:
		base = PANGOLIN_BASE_SPEED
	var target_vx: float = base + difficulty * 175.0 + float(flow_multiplier - 1) * 14.0 + momentum_bonus
	if current_form == Form.FOX and dash_timer > 0.0:
		target_vx += FOX_DASH_SPEED
	if stumble_timer > 0.0:
		target_vx *= 0.56
	var dash_cap_add: float = FOX_DASH_SPEED if dash_timer > 0.0 else 0.0
	velocity.x = lerpf(velocity.x, minf(base + MAX_BONUS_SPEED + dash_cap_add, target_vx), minf(1.0, 6.8 * dt))

	# Gravity
	if not grounded:
		match current_form:
			Form.FOX:
				var g: float = FOX_GRAVITY * (0.22 if dash_timer > 0.0 else 1.0)
				velocity.y += g * dt
			Form.MOTH:
				var gf: float = 0.58 if (jump_held and velocity.y > 0.0) else 1.0
				velocity.y += MOTH_GRAVITY * gf * dt
				var cap: float = MOTH_MAX_FALL
				if slam_held:
					cap = 440.0
				elif jump_held:
					cap = MOTH_MAX_FALL * 0.58
				velocity.y = minf(velocity.y, cap)
			Form.PANGOLIN:
				var slam_mult: float = 1.4 if is_slamming else 1.0
				velocity.y += PANGOLIN_GRAVITY * slam_mult * dt

	var prev_x: float = position.x
	var prev_y: float = position.y
	position += velocity * dt
	if position.y < -390.0:
		position.y = -390.0
		velocity.y = maxf(0.0, velocity.y)

	# Check elevated one-way mossy ledges & tree-branch sanctuaries first
	is_under_tunnel = level_gen.is_under_root_tunnel(position.x)
	var plat: Dictionary = level_gen.sample_elevated_platform(position.x, prev_y, position.y, velocity.y)
	var surface: Dictionary = level_gen.sample_ground(position.x)
	if current_form == Form.PANGOLIN and grounded and not surface.is_empty():
		var slope: float = float(surface.get("slope", 0.0))
		if slope > 0.05:
			momentum_bonus = minf(220.0, momentum_bonus + slope * 540.0 * dt)
			is_curled = true
		else:
			is_curled = velocity.x > PANGOLIN_BASE_SPEED + 45.0 or momentum_bonus > 35.0

	var landed_now: bool = false
	var was_slam: bool = is_slamming
	if not plat.is_empty():
		var plat_y: float = float(plat["y"])
		if not grounded and velocity.y > 90.0:
			landed_now = true
		position.y = plat_y
		velocity.y = 0.0
		grounded = true
		coyote_timer = COYOTE_DURATION
		jumps_remaining = 2
	elif not surface.is_empty():
		var ground_y: float = float(surface.get("y", 0.0))
		# Includes forgiving 8px ledge corner-correction when barely grazing a landing edge
		if position.y >= ground_y - 2.0 and (prev_y <= ground_y + 34.0 or grounded):
			if not grounded and velocity.y > 110.0:
				landed_now = true
			position.y = ground_y
			velocity.y = 0.0
			grounded = true
			coyote_timer = COYOTE_DURATION
			jumps_remaining = 2
		elif position.y < ground_y - 4.0:
			grounded = false
	else:
		grounded = false

	if landed_now:
		is_slamming = false
		if current_form == Form.PANGOLIN and was_slam:
			momentum_bonus = minf(220.0, momentum_bonus + 95.0)
		play_clip("land_squash")
		_fire_burst(get_form_color(), 280.0 if was_slam else 160.0, -4.0)
		emit_signal("landed", current_form, was_slam, global_position)

	# Sync gait, wingbeat, and roll
	var dx: float = maxf(0.0, position.x - prev_x)
	var prev_step: int = int(floor(gait_phase / PI))
	gait_phase += dx * 0.048
	var next_step: int = int(floor(gait_phase / PI))
	if grounded and current_form == Form.FOX and dash_timer <= 0.0 and next_step > prev_step:
		emit_signal("paw_stepped", global_position)

	if current_form == Form.MOTH:
		wing_phase += dt * (11.5 + wing_boost * 11.0)
	_update_moth_ribbon()

	if current_form == Form.PANGOLIN:
		roll_angle += (dx / 18.0) * (1.15 if is_curled else 0.5)

	_update_renderers(dt, flow_multiplier)
	return dx

func _update_moth_ribbon() -> void:
	if current_form == Form.MOTH:
		_trail_points.append(global_position + Vector2(-10.0, -24.0 + sin(wing_phase) * 3.5))
		if _trail_points.size() > 30:
			_trail_points.pop_front()
		moth_ribbon.clear_points()
		for p in _trail_points:
			moth_ribbon.add_point(to_local(p))
	elif _trail_points.size() > 0:
		_trail_points.pop_front()
		moth_ribbon.clear_points()
		for p in _trail_points:
			moth_ribbon.add_point(to_local(p))

func get_hitbox_rect() -> Rect2:
	var w: float = 42.0
	var h: float = 34.0
	if current_form == Form.FOX and dash_timer > 0.0:
		w = 48.0
		h = 20.0
	elif current_form == Form.MOTH:
		w = 34.0
		h = 30.0
	elif current_form == Form.PANGOLIN and (is_curled or is_slamming):
		w = 36.0
		h = 32.0
	return Rect2(position.x - w * 0.5, position.y - h, w, h)

func _apply_morph(target: int) -> void:
	var prev: int = current_form
	current_form = target
	morph_buffer_form = -1
	morph_buffer_timer = 0.0
	morph_anim_timer = MORPH_EFFECT_DURATION

	# Momentum conservation across form transitions
	if prev == Form.PANGOLIN and (is_curled or momentum_bonus > 15.0):
		momentum_bonus = minf(220.0, maxf(momentum_bonus, 95.0))
	elif prev == Form.FOX and dash_timer > 0.0:
		momentum_bonus = minf(220.0, momentum_bonus + 70.0)

	if target == Form.MOTH:
		is_slamming = false
		is_curled = false
		dash_timer = 0.0
		if velocity.y > 80.0:
			velocity.y = 60.0
		wing_boost = 1.0
	elif target == Form.FOX:
		is_slamming = false
		is_curled = false
		jumps_remaining = 2 if grounded else maxi(1, jumps_remaining)
	else:
		dash_timer = 0.0
		is_curled = velocity.x > PANGOLIN_BASE_SPEED + 35.0 or not grounded

	_sync_form_visibility()
	play_clip("morph_pop")
	_fire_burst(get_form_color(target), 260.0, -22.0)
	emit_signal("form_shifted", prev, target, global_position + Vector2(0.0, -22.0))

func _sync_form_visibility() -> void:
	fox_renderer.visible = current_form == Form.FOX
	moth_renderer.visible = current_form == Form.MOTH
	pangolin_renderer.visible = current_form == Form.PANGOLIN
	var col: Color = get_form_color()
	aura_light.color = col
	if trail_particles != null:
		trail_particles.color = Color(col.r, col.g, col.b, 0.85)
		if current_form == Form.FOX:
			trail_particles.position = Vector2(-14.0, -16.0)
			trail_particles.gravity = Vector2(0.0, -24.0)
			trail_particles.direction = Vector2(-1.0, -0.22)
		elif current_form == Form.MOTH:
			trail_particles.position = Vector2(-10.0, -24.0)
			trail_particles.gravity = Vector2(0.0, 12.0)
			trail_particles.direction = Vector2(-1.0, 0.12)
		else:
			trail_particles.position = Vector2(-8.0, -10.0)
			trail_particles.gravity = Vector2(0.0, 95.0)
			trail_particles.direction = Vector2(-1.0, -0.55)
	if burst_particles != null:
		burst_particles.color = Color(col.r, col.g, col.b, 0.95)

func _update_renderers(dt: float, flow_multiplier: int) -> void:
	var morph_r: float = morph_anim_timer / MORPH_EFFECT_DURATION if morph_anim_timer > 0.0 else 0.0
	var speed_r: float = clampf((velocity.x - 480.0) / 360.0, 0.0, 1.0)
	if anim_player == null or not anim_player.is_playing():
		aura_light.energy = 0.92 + float(flow_multiplier - 1) * 0.06 + wing_boost * 0.24

	if current_form == Form.FOX:
		fox_renderer.sync_state(gait_phase, dash_timer > 0.0, not grounded, velocity.y, speed_r, flow_multiplier, morph_r, dt)
	elif current_form == Form.MOTH:
		moth_renderer.sync_state(wing_phase, wing_boost, velocity.y, flow_multiplier, morph_r, dt)
	else:
		var slam_heat: float = 0.65 if is_slamming else 0.0
		var heat: float = clampf(0.42 + momentum_bonus / 200.0 + slam_heat, 0.35, 1.0)
		pangolin_renderer.sync_state(gait_phase, is_curled, is_slamming, roll_angle, heat, morph_r, dt)
