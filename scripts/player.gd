extends CharacterBody2D
class_name PlayerController

## UMBRA SHIFT — Core 3-Form Shapeshifting Player Controller (Godot 4 GDScript)
## Supports direct form selection (1/J, 2/K, 3/L), Q/E & Left/Right cycling,
## 0.12s coyote time, 0.12s jump & morph buffering, and momentum conservation.

enum Form { FOX, MOTH, PANGOLIN }

signal form_shifted(prev_form: int, new_form: int, world_pos: Vector2)
signal jumped(form: int, is_double: bool, world_pos: Vector2)
signal dashed(world_pos: Vector2)
signal fluttered(world_pos: Vector2)
signal landed(form: int, is_slam: bool, world_pos: Vector2)
signal paw_stepped(world_pos: Vector2)

const FOX_BASE_SPEED := 515.0
const MOTH_BASE_SPEED := 435.0
const PANGOLIN_BASE_SPEED := 470.0
const MAX_BONUS_SPEED := 280.0

const FOX_GRAVITY := 2150.0
const MOTH_GRAVITY := 520.0
const MOTH_MAX_FALL := 155.0
const PANGOLIN_GRAVITY := 2850.0
const PANGOLIN_SLAM_SPEED := 1180.0

const FOX_JUMP_VEL := -760.0
const FOX_DOUBLE_JUMP_VEL := -670.0
const FOX_DASH_SPEED := 340.0
const FOX_DASH_DURATION := 0.34
const FOX_DASH_COOLDOWN := 0.72
const MOTH_FLUTTER_VEL := -380.0
const MOTH_FLUTTER_COOLDOWN := 0.22

const COYOTE_DURATION := 0.12
const JUMP_BUFFER_DURATION := 0.12
const MORPH_BUFFER_DURATION := 0.12
const MORPH_EFFECT_DURATION := 0.12

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var fox_renderer: FoxRenderer = $FoxRenderer
@onready var moth_renderer: MothRenderer = $MothRenderer
@onready var pangolin_renderer: PangolinRenderer = $PangolinRenderer
@onready var moth_ribbon: Line2D = $MothRibbon
@onready var aura_light: PointLight2D = $AuraLight

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
var roll_angle: float = 0.0
var gait_phase: float = 0.0
var stumble_timer: float = 0.0
var invuln_timer: float = 0.0
var momentum_bonus: float = 0.0
var alive: bool = true

var _trail_points: Array[Vector2] = []
var _visual_scale := Vector2.ONE

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
	_visual_scale = Vector2.ONE
	_trail_points.clear()
	moth_ribbon.clear_points()
	_sync_form_visibility()

func request_form(target: int) -> void:
	if target != current_form:
		morph_buffer_form = target
		morph_buffer_timer = MORPH_BUFFER_DURATION

func cycle_form(dir: int) -> void:
	var nxt := (current_form + dir + 3) % 3
	request_form(nxt)

func set_showcase_form(target: int) -> void:
	current_form = target % 3
	morph_buffer_form = -1
	morph_buffer_timer = 0.0
	morph_anim_timer = MORPH_EFFECT_DURATION
	is_curled = current_form == Form.PANGOLIN
	is_slamming = false
	dash_timer = 0.0
	_visual_scale = Vector2(1.16, 0.88)
	_sync_form_visibility()

func trigger_stumble() -> void:
	stumble_timer = 0.52
	invuln_timer = 0.72
	momentum_bonus = 0.0

func grant_smash_boost(amount: float = 115.0) -> void:
	is_curled = true
	momentum_bonus = minf(220.0, momentum_bonus + amount)
	_visual_scale = Vector2(1.26, 0.78)

func get_form_color(form_id: int = -1) -> Color:
	var f := current_form if form_id < 0 else form_id
	match f:
		Form.FOX:
			return Color(0.31, 1.0, 0.69, 1.0)
		Form.MOTH:
			return Color(0.0, 0.9, 1.0, 1.0)
		_:
			return Color(1.0, 0.62, 0.0, 1.0)

func step_physics(dt: float, difficulty: float, flow_multiplier: int, level_gen: Node2D) -> float:
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

	var decay := 42.0 if current_form == Form.MOTH else 68.0
	momentum_bonus = maxf(0.0, momentum_bonus - decay * dt)
	_visual_scale = _visual_scale.lerp(Vector2.ONE, 1.0 - exp(-15.0 * dt))

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

	var jump_held := Input.is_action_pressed("action_jump")
	var jump_released := Input.is_action_just_released("action_jump")
	var dash_pressed := Input.is_action_just_pressed("action_dash")
	var slam_pressed := Input.is_action_just_pressed("action_slam")
	var slam_held := Input.is_action_pressed("action_slam")

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
					_visual_scale = Vector2(0.84, 1.2)
					emit_signal("jumped", Form.FOX, false, global_position)
				elif jumps_remaining > 0:
					velocity.y = FOX_DOUBLE_JUMP_VEL
					jump_buffer_timer = 0.0
					jumps_remaining = 0
					_visual_scale = Vector2(0.86, 1.18)
					emit_signal("jumped", Form.FOX, true, global_position)
			if jump_released and velocity.y < -220.0:
				velocity.y *= 0.48
			if (dash_pressed or (slam_pressed and grounded)) and dash_cooldown <= 0.0:
				dash_timer = FOX_DASH_DURATION
				dash_cooldown = FOX_DASH_COOLDOWN
				if not grounded and velocity.y > 0.0:
					velocity.y = 0.0
				_visual_scale = Vector2(1.32, 0.72)
				emit_signal("dashed", global_position + Vector2(0.0, -12.0))
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
				_visual_scale = Vector2(0.9, 1.12)
				emit_signal("fluttered", global_position + Vector2(0.0, -16.0))
			if slam_held and not grounded:
				velocity.y += 980.0 * dt
		Form.PANGOLIN:
			if jump_buffer_timer > 0.0 and (grounded or coyote_timer > 0.0):
				velocity.y = -590.0
				grounded = false
				coyote_timer = 0.0
				jump_buffer_timer = 0.0
				is_curled = true
				_visual_scale = Vector2(0.88, 1.14)
				emit_signal("jumped", Form.PANGOLIN, false, global_position)
			if slam_pressed and not grounded and not is_slamming:
				is_slamming = true
				is_curled = true
				velocity.y = maxf(velocity.y, PANGOLIN_SLAM_SPEED)
				_visual_scale = Vector2(0.82, 1.24)

	# Target speed & adaptive acceleration
	var base := FOX_BASE_SPEED if current_form == Form.FOX else (MOTH_BASE_SPEED if current_form == Form.MOTH else PANGOLIN_BASE_SPEED)
	var target_vx := base + difficulty * 175.0 + float(flow_multiplier - 1) * 14.0 + momentum_bonus
	if current_form == Form.FOX and dash_timer > 0.0:
		target_vx += FOX_DASH_SPEED
	if stumble_timer > 0.0:
		target_vx *= 0.56
	velocity.x = lerpf(velocity.x, minf(base + MAX_BONUS_SPEED + (FOX_DASH_SPEED if dash_timer > 0.0 else 0.0), target_vx), minf(1.0, 6.8 * dt))

	# Gravity
	if not grounded:
		match current_form:
			Form.FOX:
				var g := FOX_GRAVITY * (0.22 if dash_timer > 0.0 else 1.0)
				velocity.y += g * dt
			Form.MOTH:
				var gf := 0.58 if (jump_held and velocity.y > 0.0) else 1.0
				velocity.y += MOTH_GRAVITY * gf * dt
				var cap := 440.0 if slam_held else (MOTH_MAX_FALL * 0.58 if jump_held else MOTH_MAX_FALL)
				velocity.y = minf(velocity.y, cap)
			Form.PANGOLIN:
				velocity.y += PANGOLIN_GRAVITY * (1.4 if is_slamming else 1.0) * dt

	var prev_x := position.x
	var prev_y := position.y
	position += velocity * dt
	if position.y < -390.0:
		position.y = -390.0
		velocity.y = maxf(0.0, velocity.y)

	# Check elevated one-way mossy ledges & tree-branch sanctuaries first
	var plat: Dictionary = level_gen.sample_elevated_platform(position.x, prev_y, position.y, velocity.y)
	var surface: Dictionary = level_gen.sample_ground(position.x)
	if current_form == Form.PANGOLIN and grounded and not surface.is_empty():
		var slope: float = surface.get("slope", 0.0)
		if slope > 0.05:
			momentum_bonus = minf(220.0, momentum_bonus + slope * 540.0 * dt)
			is_curled = true
		else:
			is_curled = velocity.x > PANGOLIN_BASE_SPEED + 45.0 or momentum_bonus > 35.0

	var landed_now := false
	var was_slam := is_slamming
	if not plat.is_empty():
		var plat_y: float = plat["y"]
		if not grounded and velocity.y > 90.0:
			landed_now = true
		position.y = plat_y
		velocity.y = 0.0
		grounded = true
		coyote_timer = COYOTE_DURATION
		jumps_remaining = 2
	elif not surface.is_empty():
		var ground_y: float = surface.get("y", 0.0)
		if position.y >= ground_y and (prev_y <= ground_y + 26.0 or grounded):
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
			_visual_scale = Vector2(1.32, 0.68)
		else:
			_visual_scale = Vector2(1.18, 0.82)
		emit_signal("landed", current_form, was_slam, global_position)

	# Sync gait, wingbeat, and roll
	var dx := maxf(0.0, position.x - prev_x)
	var prev_step := int(floor(gait_phase / PI))
	gait_phase += dx * 0.048
	var next_step := int(floor(gait_phase / PI))
	if grounded and current_form == Form.FOX and dash_timer <= 0.0 and next_step > prev_step:
		emit_signal("paw_stepped", global_position)

	if current_form == Form.MOTH:
		wing_phase += dt * (11.5 + wing_boost * 11.0)
		_trail_points.append(global_position + Vector2(-8.0, -16.0 + sin(wing_phase) * 3.0))
		if _trail_points.size() > 28:
			_trail_points.pop_front()
		moth_ribbon.clear_points()
		for p in _trail_points:
			moth_ribbon.add_point(to_local(p))
	else:
		if _trail_points.size() > 0:
			_trail_points.pop_front()
			moth_ribbon.clear_points()
			for p in _trail_points:
				moth_ribbon.add_point(to_local(p))

	if current_form == Form.PANGOLIN:
		roll_angle += (dx / 18.0) * (1.15 if is_curled else 0.5)

	_update_renderers(dt, flow_multiplier)
	return dx

func get_hitbox_rect() -> Rect2:
	var w := 42.0
	var h := 34.0
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
	var prev := current_form
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
	emit_signal("form_shifted", prev, target, global_position + Vector2(0.0, -18.0))

func _sync_form_visibility() -> void:
	fox_renderer.visible = current_form == Form.FOX
	moth_renderer.visible = current_form == Form.MOTH
	pangolin_renderer.visible = current_form == Form.PANGOLIN
	aura_light.color = get_form_color()

func _update_renderers(dt: float, flow_multiplier: int) -> void:
	var morph_r := morph_anim_timer / MORPH_EFFECT_DURATION if morph_anim_timer > 0.0 else 0.0
	var speed_r := clampf((velocity.x - 480.0) / 360.0, 0.0, 1.0)
	fox_renderer.scale = _visual_scale
	moth_renderer.scale = _visual_scale
	pangolin_renderer.scale = _visual_scale
	aura_light.energy = 1.15 + float(flow_multiplier - 1) * 0.08 + wing_boost * 0.3

	if current_form == Form.FOX:
		fox_renderer.sync_state(gait_phase, dash_timer > 0.0, not grounded, velocity.y, speed_r, flow_multiplier, morph_r, dt)
	elif current_form == Form.MOTH:
		moth_renderer.sync_state(wing_phase, wing_boost, velocity.y, flow_multiplier, morph_r, dt)
	else:
		var heat := clampf(0.38 + momentum_bonus / 200.0 + (0.65 if is_slamming else 0.0), 0.3, 1.0)
		pangolin_renderer.sync_state(gait_phase, is_curled, is_slamming, roll_angle, heat, morph_r, dt)
