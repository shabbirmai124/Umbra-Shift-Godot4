extends Node2D

## UMBRA SHIFT — Main Orchestrator (Godot 4 GDScript)
## Manages Game State Machine (TITLE / PLAYING / PAUSED / GAME_OVER), 50ms hitstop,
## 6-layer EnvironmentBackdrop + sky_clouds.gdshader + ink_tide.gdshader + speed_lines.gdshader,
## dynamic camera (look-ahead, Moth high-flight zoom-out, Ink Tide zoom-in, trauma shake),
## Flow Multiplier (x1..x10), continuous form VFX, choreographed live Title showcase, and procedural audio.

enum GameState { TITLE, PLAYING, PAUSED, GAME_OVER }

const PIXELS_PER_METER: float = 28.0

@onready var sky_rect: ColorRect = $BackgroundLayer/SkyRect
@onready var bg_forest: EnvironmentBackdrop = $BackgroundLayer/BackForest
@onready var fg_weather: EnvironmentBackdrop = $ForegroundLayer/FrontWeather
@onready var level_gen: LevelGenerator = $LevelGenerator
@onready var player: PlayerController = $Player
@onready var cam: Camera2D = $Camera2D
@onready var vfx: VfxManager = $VfxManager
@onready var ink_tide: InkTideController = $OverlayLayer/InkTide
@onready var speed_rect: ColorRect = $OverlayLayer/SpeedLinesRect
@onready var hud: GameHUD = $HUD
@onready var audio: ProceduralAudio = $ProceduralAudio

var state: int = GameState.TITLE
var distance_m: float = 0.0
var score: float = 0.0
var smashed_count: int = 0
var flow_multiplier: int = 1
var flow_charge: float = 0.0
var max_flow: int = 1
var flow_decay_timer: float = 0.0

var hitstop_timer: float = 0.0
var death_slowmo_timer: float = 0.0
var death_cause: String = ""
var _time: float = 0.0
var _lightning_timer: float = 6.0
var _lightning_flash: float = 0.0
var _title_cam_x: float = 0.0
var _title_form_timer: float = 0.0
var _title_jump_triggered: bool = false
var _title_dash_triggered: bool = false
var _title_land_triggered: bool = false
var _title_fx_accum: float = 0.0
var _afterimage_accum: float = 0.0
var _ambient_fx_accum: float = 0.0

func _ready() -> void:
	level_gen.reset_world(20261124)
	player.reset_player()
	ink_tide.reset_tide()

	player.form_shifted.connect(_on_form_shifted)
	player.jumped.connect(_on_player_jumped)
	player.dashed.connect(_on_player_dashed)
	player.fluttered.connect(_on_player_fluttered)
	player.landed.connect(_on_player_landed)
	player.paw_stepped.connect(_on_paw_stepped)

	hud.play_pressed.connect(start_run)
	hud.resume_pressed.connect(toggle_pause)
	hud.restart_pressed.connect(start_run)
	hud.title_pressed.connect(return_to_title)
	hud.form_clicked.connect(player.request_form)

	_title_cam_x = 0.0
	player.position = Vector2(260.0, 0.0)
	cam.position = Vector2(115.0, -115.0)
	_sync_backdrops(0.0, 0.0, 260.0)
	_update_post_fx()

func start_run() -> void:
	get_tree().paused = false
	state = GameState.PLAYING
	distance_m = 0.0
	score = 0.0
	smashed_count = 0
	flow_multiplier = 1
	flow_charge = 0.0
	max_flow = 1
	flow_decay_timer = 0.0
	hitstop_timer = 0.0
	death_slowmo_timer = 0.0
	death_cause = ""

	level_gen.reset_world(int(Time.get_ticks_msec()))
	player.reset_player()
	vfx.reset_vfx()
	ink_tide.reset_tide()
	hud.set_phase("playing")
	hud.update_hud(0, 0, flow_multiplier, flow_charge, player.current_form, ink_tide.proximity)
	audio.play_morph(PlayerController.Form.FOX)

func toggle_pause() -> void:
	if state == GameState.PLAYING:
		state = GameState.PAUSED
		hud.set_phase("paused")
	elif state == GameState.PAUSED:
		state = GameState.PLAYING
		hud.set_phase("playing")

func return_to_title() -> void:
	state = GameState.TITLE
	_title_cam_x = 0.0
	_title_form_timer = 0.0
	_title_jump_triggered = false
	_title_dash_triggered = false
	_title_land_triggered = false
	level_gen.reset_world(20261124)
	player.reset_player()
	vfx.reset_vfx()
	ink_tide.reset_tide()
	hud.set_phase("title")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mute"):
		audio.toggle_mute()
	elif event.is_action_pressed("game_pause"):
		if state == GameState.PLAYING or state == GameState.PAUSED:
			toggle_pause()
	elif state == GameState.TITLE and (event.is_action_pressed("action_jump") or event.is_action_pressed("ui_accept")):
		start_run()
	elif state == GameState.GAME_OVER and (event.is_action_pressed("game_restart") or event.is_action_pressed("action_jump")):
		start_run()
	elif state == GameState.PLAYING and event.is_action_pressed("game_restart"):
		start_run()

func _process(raw_dt: float) -> void:
	var dt: float = minf(raw_dt, 0.05)
	if state == GameState.PAUSED:
		return

	_time += dt
	_lightning_timer -= dt
	if _lightning_timer <= 0.0:
		_lightning_flash = randf_range(0.72, 1.0)
		_lightning_timer = randf_range(7.0, 15.5)
	_lightning_flash = maxf(0.0, _lightning_flash - dt * 2.8)

	vfx.update_vfx(dt)

	if state == GameState.TITLE:
		_step_title_showcase(dt)
		return

	if state == GameState.GAME_OVER:
		_sync_backdrops(dt, cam.position.x, 90.0)
		audio.pump_audio(dt, 0.1, 0.3, 1, false, false)
		return

	# Dramatic slow-motion beat on defeat before revealing Game Over card
	if not player.alive:
		death_slowmo_timer -= dt
		ink_tide.update_tide(dt * 0.25, 0.0, 520.0, 1, true)
		_sync_backdrops(dt * 0.25, cam.position.x, 120.0)
		if death_slowmo_timer <= 0.0:
			state = GameState.GAME_OVER
			hud.show_game_over(int(distance_m), int(score), smashed_count, max_flow, death_cause)
		return

	# Sim-level 50ms hitstop freeze frame on heavy Pangolin smash / Meteor Slam
	if hitstop_timer > 0.0:
		hitstop_timer = maxf(0.0, hitstop_timer - dt)
		_update_camera(dt)
		return

	var difficulty: float = clampf((distance_m - 60.0) / 1450.0, 0.0, 1.0)
	var dx: float = player.step_physics(dt, difficulty, flow_multiplier, level_gen)
	distance_m += dx / PIXELS_PER_METER
	score += (dx / PIXELS_PER_METER) * 10.0 * float(flow_multiplier)

	_resolve_obstacles(dt)
	_update_flow_decay(dt)
	_emit_continuous_fx(dt)

	var ref_pace: float = PlayerController.FOX_BASE_SPEED + difficulty * 165.0
	ink_tide.update_tide(dt, player.velocity.x, ref_pace, flow_multiplier, true)

	if player.position.y > 260.0:
		_trigger_death("Swallowed by the misty ravine")
	elif ink_tide.proximity >= 0.98:
		_trigger_death("Consumed by the Shadow Ink Tide")

	level_gen.update_world(dt, player.position.x + 1950.0, cam.position.x - 950.0, difficulty, player.position, player.get_form_color(), flow_multiplier)
	_update_camera(dt)
	_sync_backdrops(dt, cam.position.x, player.velocity.x)
	_update_post_fx()

	var ability_ratio: float = 1.0
	var ability_label: String = "PHANTOM DASH READY"
	if player.current_form == PlayerController.Form.FOX:
		ability_ratio = 1.0 - clampf(player.dash_cooldown / PlayerController.FOX_DASH_COOLDOWN, 0.0, 1.0)
		ability_label = "PHANTOM DASH ACTIVE" if player.dash_timer > 0.0 else ("PHANTOM DASH READY" if ability_ratio >= 0.99 else "DASH RECHARGING")
	elif player.current_form == PlayerController.Form.MOTH:
		ability_ratio = 1.0 - clampf(player.flutter_cooldown / PlayerController.MOTH_FLUTTER_COOLDOWN, 0.0, 1.0)
		ability_label = "SPORE GLIDE · FLUTTER READY" if ability_ratio >= 0.95 else "WINGBEAT LIFT"
	else:
		ability_ratio = clampf(0.25 + player.momentum_bonus / 220.0, 0.25, 1.0)
		ability_label = "METEOR SLAM!" if player.is_slamming else ("ARMORED ROLL · SMASH READY" if player.is_curled else "MAGMA CHARGE")
	hud.update_hud(int(distance_m), int(score), flow_multiplier, flow_charge, player.current_form, ink_tide.proximity, ability_ratio, ability_label)

	var is_rolling: bool = player.current_form == PlayerController.Form.PANGOLIN and player.grounded and player.is_curled
	audio.pump_audio(dt, clampf((player.velocity.x - 420.0) / 480.0, 0.0, 1.0), ink_tide.proximity, flow_multiplier, is_rolling, true)

func _step_title_showcase(dt: float) -> void:
	# Choreographed live Title Screen showcase: hero runs along actual mossy terrain
	# in the open right-center clearing, demonstrating Fox leap/dash, Moth glide, and Pangolin roll.
	var form_duration: float = 3.4 if player.current_form == PlayerController.Form.FOX else 3.0
	_title_cam_x += 235.0 * dt
	_title_form_timer += dt

	if _title_form_timer >= form_duration:
		_title_form_timer = 0.0
		_title_jump_triggered = false
		_title_dash_triggered = false
		_title_land_triggered = false
		var prev_f: int = player.current_form
		var next_f: int = (prev_f + 1) % 3
		player.set_showcase_form(next_f)
		vfx.emit_morph_burst(player.position + Vector2(0.0, -22.0), player.get_form_color(prev_f), player.get_form_color(next_f))

	var px: float = _title_cam_x + 300.0
	var surf: Dictionary = level_gen.sample_ground(px)
	var ground_y: float = float(surf.get("y", 0.0)) if not surf.is_empty() else 0.0
	var py: float = ground_y
	var demo_dash: bool = false
	var demo_air: bool = false
	var demo_vy: float = 0.0

	if player.current_form == PlayerController.Form.FOX:
		# Graceful leap arc between 0.9s and 1.75s, followed by a glowing Phantom Dash at 2.1s..2.65s
		if _title_form_timer >= 0.9 and _title_form_timer < 1.75:
			var jt: float = (_title_form_timer - 0.9) / 0.85
			py = ground_y - sin(jt * PI) * 86.0
			demo_air = true
			demo_vy = -cos(jt * PI) * 420.0
			if not _title_jump_triggered:
				_title_jump_triggered = true
				player.play_clip("jump_stretch")
				vfx.emit_fox_sparks(Vector2(px, ground_y), 8)
		elif _title_form_timer >= 1.75 and not _title_land_triggered:
			_title_land_triggered = true
			player.play_clip("land_squash")
			vfx.emit_landing_splash(Vector2(px, ground_y), player.get_form_color(PlayerController.Form.FOX), false)
		elif _title_form_timer >= 2.15 and _title_form_timer < 2.75:
			demo_dash = true
			if not _title_dash_triggered:
				_title_dash_triggered = true
				player.play_clip("dash_surge")
				vfx.emit_fox_sparks(Vector2(px, ground_y - 14.0), 10)
	elif player.current_form == PlayerController.Form.MOTH:
		var climb: float = sin(clampf(_title_form_timer / 0.45, 0.0, 1.0) * PI * 0.5)
		py = ground_y - 72.0 * climb + sin(_time * 3.1) * 14.0
		demo_air = true
		demo_vy = cos(_time * 3.1) * 42.0
	else:
		# Pangolin drops cleanly onto the mossy slope and rolls spitting amber sparks
		if _title_form_timer < 0.24:
			var drop_t: float = _title_form_timer / 0.24
			py = ground_y - (1.0 - drop_t * drop_t) * 62.0
			demo_air = true
			demo_vy = 320.0
		elif not _title_land_triggered:
			_title_land_triggered = true
			player.play_clip("land_squash")
			vfx.emit_landing_splash(Vector2(px, ground_y), player.get_form_color(PlayerController.Form.PANGOLIN), true)

	player.position = Vector2(px, py)
	player.update_showcase(dt, 4, demo_dash, demo_air, demo_vy)

	_title_fx_accum += dt
	if _title_fx_accum >= 0.06:
		_title_fx_accum = 0.0
		if player.current_form == PlayerController.Form.FOX and demo_dash:
			vfx.emit_fox_afterimage(player.position, true)
		elif player.current_form == PlayerController.Form.FOX and not demo_air and randf() < 0.45:
			vfx.emit_fox_sparks(player.position, 2)
		elif player.current_form == PlayerController.Form.MOTH:
			vfx.emit_moth_scale_mote(player.position + Vector2(-10.0, -24.0))
		elif player.current_form == PlayerController.Form.PANGOLIN and not demo_air:
			vfx.emit_pangolin_roll_spark(player.position)

	cam.position = Vector2(_title_cam_x + 115.0, -115.0)
	cam.zoom = Vector2.ONE
	level_gen.update_world(dt, _title_cam_x + 1950.0, _title_cam_x - 850.0, 0.0, player.position, player.get_form_color(), 3)
	ink_tide.update_tide(dt, 450.0, 500.0, 1, false)
	_sync_backdrops(dt, _title_cam_x, 260.0)
	_update_post_fx()
	audio.pump_audio(dt, 0.2, 0.1, 1, false, false)

func _emit_continuous_fx(dt: float) -> void:
	# Fox Phantom Dash & High-Flow translucent afterimages
	if player.current_form == PlayerController.Form.FOX and (player.dash_timer > 0.0 or flow_multiplier >= 5):
		_afterimage_accum += dt
		var step: float = 0.042 if player.dash_timer > 0.0 else 0.085
		if _afterimage_accum >= step:
			_afterimage_accum = 0.0
			vfx.emit_fox_afterimage(player.position, player.dash_timer > 0.0)

	_ambient_fx_accum += dt
	if _ambient_fx_accum >= 0.048:
		_ambient_fx_accum = 0.0
		if player.current_form == PlayerController.Form.MOTH:
			vfx.emit_moth_scale_mote(player.position + Vector2(-10.0, -22.0))
		elif player.current_form == PlayerController.Form.PANGOLIN and player.grounded and player.is_curled:
			vfx.emit_pangolin_roll_spark(player.position)
		if randf() < 0.4:
			vfx.emit_rain_ripple(Vector2(cam.position.x + randf_range(-520.0, 620.0), 0.0))

func _sync_backdrops(dt: float, cam_x: float, speed_px: float) -> void:
	if sky_rect != null:
		var smat: ShaderMaterial = sky_rect.material as ShaderMaterial
		if smat != null:
			smat.set_shader_parameter("scroll_x", cam_x)
			smat.set_shader_parameter("lightning_flash", _lightning_flash)
	bg_forest.sync_backdrop(dt, cam_x, speed_px, flow_multiplier, _lightning_flash, player.get_form_color())
	fg_weather.sync_backdrop(dt, cam_x, speed_px, flow_multiplier, _lightning_flash, player.get_form_color())

func _resolve_obstacles(dt: float) -> void:
	var pbox: Rect2 = player.get_hitbox_rect()
	for chunk in level_gen.chunks:
		if player.position.x + 120.0 < float(chunk["x_start"]) or player.position.x - 120.0 > float(chunk["x_end"]):
			continue
		var obs_list: Array = chunk["obstacles"]
		for obs_item in obs_list:
			var obs: Dictionary = obs_item
			if not bool(obs["intact"]):
				continue
			var obox: Rect2 = obs["rect"]
			var kind: String = String(obs["kind"])
			if kind == "high_platform" or kind == "mossy_ledge":
				continue
			if kind == "spore_draft":
				if pbox.intersects(obox) and player.current_form == PlayerController.Form.MOTH:
					player.velocity.y = maxf(-420.0, player.velocity.y - 1240.0 * dt)
					player.grounded = false
					if not bool(obs["cleared"]):
						obs["cleared"] = true
						_add_flow(0.45)
						ink_tide.push_back(0.04)
						audio.play_draft_shimmer()
				continue

			if not bool(obs["cleared"]) and player.position.x > obox.end.x + 12.0:
				obs["cleared"] = true
				_add_flow(0.35)
				ink_tide.push_back(0.025)

			if not pbox.intersects(obox):
				continue

			if kind == "monolith" or kind == "crystal_wall" or kind == "fallen_log":
				if player.current_form == PlayerController.Form.PANGOLIN:
					obs["intact"] = false
					obs["cleared"] = true
					smashed_count += 1
					player.grant_smash_boost(115.0)
					hitstop_timer = 0.05
					ink_tide.push_back(0.075)
					_add_flow(0.55)
					score += 150.0 * float(flow_multiplier)
					vfx.emit_smash_debris(obox.get_center(), player.position.y)
					audio.play_smash()
				elif player.invuln_timer <= 0.0:
					obs["intact"] = false
					_apply_stumble(0.26)
			elif kind == "thorn_bramble":
				if player.current_form == PlayerController.Form.PANGOLIN:
					obs["intact"] = false
					obs["cleared"] = true
					smashed_count += 1
					player.grant_smash_boost(45.0)
					_add_flow(0.35)
					vfx.emit_smash_debris(obox.get_center(), player.position.y)
					audio.play_smash()
				elif player.invuln_timer <= 0.0:
					obs["cleared"] = true
					_apply_stumble(0.24)
			elif kind == "root_tunnel":
				if player.invuln_timer <= 0.0:
					obs["cleared"] = true
					_apply_stumble(0.22)

func _apply_stumble(tide_surge: float) -> void:
	player.trigger_stumble()
	flow_multiplier = maxi(1, int(flow_multiplier * 0.5))
	flow_charge = 0.0
	ink_tide.surge_forward(tide_surge)
	vfx.add_trauma(0.45)
	hitstop_timer = 0.038
	audio.play_stumble()

func _add_flow(amount: float) -> void:
	flow_decay_timer = 4.6
	if flow_multiplier >= 10:
		flow_charge = 1.0
		return
	flow_charge += amount
	while flow_charge >= 1.0 and flow_multiplier < 10:
		flow_charge -= 1.0
		flow_multiplier += 1
		max_flow = maxi(max_flow, flow_multiplier)

func _update_flow_decay(dt: float) -> void:
	if flow_multiplier > 1 or flow_charge > 0.0:
		flow_decay_timer -= dt
		if flow_decay_timer <= 0.0:
			flow_charge -= 0.16 * dt
			if flow_charge < 0.0:
				if flow_multiplier > 1:
					flow_multiplier -= 1
					flow_charge = 0.72
				else:
					flow_charge = 0.0

func _trigger_death(cause: String) -> void:
	player.alive = false
	death_cause = cause
	death_slowmo_timer = 0.48
	vfx.add_trauma(0.72)
	audio.play_stumble()

func _update_camera(dt: float) -> void:
	var look_ahead: float = 155.0 + maxf(0.0, (player.velocity.x - 460.0) * 0.42)
	var target_pos: Vector2 = Vector2(player.position.x + look_ahead, clampf(player.position.y * 0.55 - 105.0, -290.0, -80.0))
	cam.position = cam.position.lerp(target_pos, minf(1.0, 9.0 * dt))

	var shake_mag: float = vfx.trauma * vfx.trauma * 18.0
	cam.offset = Vector2(sin(_time * 46.0) * shake_mag, cos(_time * 58.0) * shake_mag * 0.85)

	var alt_zoom_out: float = 0.0
	if player.current_form == PlayerController.Form.MOTH and player.position.y < -110.0:
		alt_zoom_out = clampf((-player.position.y - 110.0) * 0.00045, 0.0, 0.11)
	var tide_zoom_in: float = maxf(0.0, (ink_tide.proximity - 0.45) * 0.13)
	var z: float = 1.0 - alt_zoom_out + tide_zoom_in
	cam.zoom = cam.zoom.lerp(Vector2(z, z), minf(1.0, 4.5 * dt))

func _update_post_fx() -> void:
	if speed_rect != null:
		var mat: ShaderMaterial = speed_rect.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("speed_intensity", clampf(float(flow_multiplier - 3) / 7.0, 0.0, 1.0))
			mat.set_shader_parameter("chromatic_pulse", vfx.chromatic_pulse)
			mat.set_shader_parameter("accent_color", player.get_form_color())

func _on_form_shifted(prev_form: int, new_form: int, pos: Vector2) -> void:
	vfx.emit_morph_burst(pos, player.get_form_color(prev_form), player.get_form_color(new_form))
	audio.play_morph(new_form)

func _on_player_jumped(form_id: int, is_double: bool, pos: Vector2) -> void:
	if is_double:
		vfx.emit_double_jump_burst(pos)
	else:
		vfx.emit_fox_sparks(pos, 8)
	audio.play_jump(form_id, is_double)

func _on_player_dashed(pos: Vector2) -> void:
	vfx.emit_fox_sparks(pos, 12)
	vfx.emit_fox_afterimage(player.position, true)
	vfx.add_trauma(0.16)
	audio.play_dash()

func _on_player_fluttered(pos: Vector2) -> void:
	vfx.emit_moth_flutter(pos)
	audio.play_flutter()

func _on_player_landed(form_id: int, is_slam: bool, pos: Vector2) -> void:
	if form_id == PlayerController.Form.PANGOLIN and is_slam:
		hitstop_timer = 0.045
		vfx.emit_smash_debris(pos, pos.y)
		audio.play_slam_impact()
	else:
		vfx.emit_landing_splash(pos, player.get_form_color(form_id), form_id == PlayerController.Form.PANGOLIN)

func _on_paw_stepped(pos: Vector2) -> void:
	vfx.emit_fox_sparks(pos, 4)
	vfx.emit_pawprint(pos)
	audio.play_paw_step()
