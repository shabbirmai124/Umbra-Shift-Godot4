extends Node2D

## UMBRA SHIFT — Main Game Orchestrator (Godot 4 GDScript)
## Created by Md Shabbir Mia
## Integrates all modular subsystems:
## - EnvironmentManager + sky_storm.gdshader + WeatherSystem (7-layer moonlit forest & aurora storm)
## - LevelGenerator + ObstacleRenderer + ReactiveFlora + puddle_reflect.gdshader + LightOccluder2D
## - PlayerController (Fox / Moth / Pangolin) + VfxManager + FractureSystem (Voronoi shards)
## - CameraRig + InkTideController + post_atmosphere.gdshader (shockwave, chromatic pulse, vignette, speed lines)
## - ScoreManager + GameHUD + TitleOverlay + ProceduralAudio (live DSP mixer & tunnel muffling)

enum GameState { TITLE, PLAYING, PAUSED, GAME_OVER }

@onready var sky_rect: ColorRect = $BackgroundLayer/SkyRect
@onready var env_mgr: EnvironmentManager = $BackgroundLayer/EnvironmentManager
@onready var level_gen: LevelGenerator = $LevelGenerator
@onready var reactive_flora: ReactiveFlora = $ReactiveFlora
@onready var player: PlayerController = $Player
@onready var camera_rig: CameraRig = $CameraRig
@onready var vfx: VfxManager = $VfxManager
@onready var fracture_sys: FractureSystem = $FractureSystem
@onready var weather_sys: WeatherSystem = $ForegroundLayer/WeatherSystem
@onready var ink_tide: InkTideController = $OverlayLayer/InkTide
@onready var post_rect: ColorRect = $OverlayLayer/PostAtmosphereRect
@onready var hud: GameHUD = $HUD
@onready var title_overlay: CanvasLayer = $TitleOverlay
@onready var score_mgr: ScoreManager = $ScoreManager
@onready var audio: ProceduralAudio = $ProceduralAudio

var state: int = GameState.TITLE
var hitstop_timer: float = 0.0
var death_slowmo_timer: float = 0.0
var death_cause: String = ""

var _time: float = 0.0
var _lightning_timer: float = 6.5
var _lightning_flash: float = 0.0
var _shockwave_radius: float = 0.0
var _shockwave_strength: float = 0.0
var _shockwave_center: Vector2 = Vector2(0.36, 0.62)

var _title_cam_x: float = 0.0
var _title_form_timer: float = 0.0
var _title_jump_triggered: bool = false
var _title_dash_triggered: bool = false
var _title_land_triggered: bool = false
var _title_fx_accum: float = 0.0
var _afterimage_accum: float = 0.0
var _ambient_fx_accum: float = 0.0

var _lbl_title_best: Label = null

func _ready() -> void:
	level_gen.reactive_flora = reactive_flora
	level_gen.reset_world(20261124)
	player.reset_player()
	ink_tide.reset_tide()
	fracture_sys.reset_fractures()

	player.form_shifted.connect(_on_form_shifted)
	player.jumped.connect(_on_player_jumped)
	player.dashed.connect(_on_player_dashed)
	player.fluttered.connect(_on_player_fluttered)
	player.landed.connect(_on_player_landed)
	player.paw_stepped.connect(_on_paw_stepped)

	hud.resume_pressed.connect(toggle_pause)
	hud.restart_pressed.connect(start_run)
	hud.title_pressed.connect(return_to_title)
	hud.form_clicked.connect(player.request_form)
	hud.volumes_changed.connect(audio.set_volumes)

	if title_overlay != null:
		var play_btn: Button = title_overlay.get_node_or_null("Root/TitleBox/PlayButton") as Button
		if play_btn != null:
			play_btn.pressed.connect(start_run)
		_lbl_title_best = title_overlay.get_node_or_null("Root/TitleBox/BestRecordLabel") as Label

	_sync_title_overlay_visibility(true)
	_title_cam_x = 0.0
	player.position = Vector2(280.0, 0.0)
	camera_rig.reset_rig(Vector2(125.0, -108.0))
	_sync_world_visuals(0.0, 0.0, 260.0)
	_update_post_fx(0.0)

func _sync_title_overlay_visibility(show_title: bool) -> void:
	if title_overlay != null:
		title_overlay.visible = show_title
	if show_title and _lbl_title_best != null:
		_lbl_title_best.visible = score_mgr.best_distance > 0
		_lbl_title_best.text = "PERSONAL BEST  %04d m   ·   %d pts" % [score_mgr.best_distance, score_mgr.best_score]

func start_run() -> void:
	get_tree().paused = false
	state = GameState.PLAYING
	score_mgr.reset_run()
	hitstop_timer = 0.0
	death_slowmo_timer = 0.0
	death_cause = ""
	_shockwave_strength = 0.0

	level_gen.reset_world(int(Time.get_ticks_msec()))
	player.reset_player()
	vfx.reset_vfx()
	fracture_sys.reset_fractures()
	ink_tide.reset_tide()
	camera_rig.reset_rig(Vector2(180.0, -102.0))

	_sync_title_overlay_visibility(false)
	hud.set_phase("playing")
	hud.update_hud(0, score_mgr.best_distance, 0, score_mgr.flow_multiplier, score_mgr.flow_charge, player.current_form, ink_tide.proximity)
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
	fracture_sys.reset_fractures()
	ink_tide.reset_tide()
	hud.set_phase("title")
	_sync_title_overlay_visibility(true)

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

func _trigger_shockwave(world_pos: Vector2, strength: float = 0.85) -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x > 1.0 and vp.y > 1.0:
		var screen_p: Vector2 = get_viewport().get_canvas_transform() * world_pos
		_shockwave_center = Vector2(clampf(screen_p.x / vp.x, 0.12, 0.88), clampf(screen_p.y / vp.y, 0.14, 0.88))
	_shockwave_radius = 0.02
	_shockwave_strength = clampf(strength, 0.2, 1.0)
	reactive_flora.trigger_shockwave(world_pos.x, strength * 1.25)

func _process(raw_dt: float) -> void:
	var dt: float = minf(raw_dt, 0.05)
	if state == GameState.PAUSED:
		return

	_time += dt
	_lightning_timer -= dt
	if _lightning_timer <= 0.0:
		_lightning_flash = randf_range(0.68, 0.96)
		_lightning_timer = randf_range(7.5, 16.0)
	_lightning_flash = maxf(0.0, _lightning_flash - dt * 2.8)

	vfx.update_vfx(dt)
	fracture_sys.step_fractures(dt)

	if state == GameState.TITLE:
		_step_title_showcase(dt)
		return

	if state == GameState.GAME_OVER:
		_sync_world_visuals(dt, camera_rig.position.x, 90.0)
		_update_post_fx(dt)
		audio.pump_audio(dt, 0.1, 0.3, 1, false, false, false)
		return

	# Dramatic 0.45s slow-motion beat on defeat before revealing Game Over card
	if not player.alive:
		death_slowmo_timer -= dt
		ink_tide.update_tide(dt * 0.25, 0.0, 520.0, 1, true)
		_sync_world_visuals(dt * 0.25, camera_rig.position.x, 120.0)
		_update_post_fx(dt * 0.25)
		if death_slowmo_timer <= 0.0:
			state = GameState.GAME_OVER
			var is_new: bool = score_mgr.save_records()
			hud.show_game_over(int(score_mgr.distance_m), score_mgr.best_distance, int(score_mgr.score), score_mgr.smashed_count, score_mgr.max_flow, is_new, death_cause)
		return

	# Crisp hitstop freeze frame (15ms on morph, 45ms on Pangolin smash/slam)
	if hitstop_timer > 0.0:
		hitstop_timer = maxf(0.0, hitstop_timer - dt)
		camera_rig.update_gameplay_camera(dt, player.position, player.velocity.x, player.current_form == PlayerController.Form.MOTH, ink_tide.proximity)
		_update_post_fx(dt)
		return

	var difficulty: float = score_mgr.get_difficulty()
	var dx: float = player.step_physics(dt, difficulty, score_mgr.flow_multiplier, level_gen)
	score_mgr.add_distance_px(dx)

	_resolve_obstacles(dt)
	score_mgr.step_decay(dt)
	_emit_continuous_fx(dt)
	reactive_flora.step_flora(dt, level_gen.chunks, player.position, player.velocity.x)

	var ref_pace: float = PlayerController.FOX_BASE_SPEED + difficulty * 165.0
	ink_tide.update_tide(dt, player.velocity.x, ref_pace, score_mgr.flow_multiplier, true)

	if player.position.y > 260.0:
		_trigger_death("Swallowed by the misty ravine")
	elif ink_tide.proximity >= 0.98:
		_trigger_death("Consumed by the Shadow Ink Tide")

	level_gen.update_world(dt, player.position.x + 1950.0, camera_rig.position.x - 950.0, difficulty, player.position, player.get_form_color(), score_mgr.flow_multiplier)
	camera_rig.update_gameplay_camera(dt, player.position, player.velocity.x, player.current_form == PlayerController.Form.MOTH, ink_tide.proximity)
	_sync_world_visuals(dt, camera_rig.position.x, player.velocity.x)
	_update_post_fx(dt)

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
	hud.update_hud(int(score_mgr.distance_m), score_mgr.best_distance, int(score_mgr.score), score_mgr.flow_multiplier, score_mgr.flow_charge, player.current_form, ink_tide.proximity, ability_ratio, ability_label)

	var is_rolling: bool = player.current_form == PlayerController.Form.PANGOLIN and player.grounded and player.is_curled
	audio.pump_audio(dt, clampf((player.velocity.x - 420.0) / 480.0, 0.0, 1.0), ink_tide.proximity, score_mgr.flow_multiplier, is_rolling, true, player.is_under_tunnel)

func _step_title_showcase(dt: float) -> void:
	var form_duration: float = 3.6 if player.current_form == PlayerController.Form.FOX else 3.2
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
		_trigger_shockwave(player.position + Vector2(0.0, -22.0), 0.52)

	var px: float = _title_cam_x + 305.0
	var surf: Dictionary = level_gen.sample_ground(px)
	var ground_y: float = float(surf.get("y", 0.0)) if not surf.is_empty() else 0.0
	var py: float = ground_y
	var demo_dash: bool = false
	var demo_air: bool = false
	var demo_vy: float = 0.0

	if player.current_form == PlayerController.Form.FOX:
		if _title_form_timer >= 0.95 and _title_form_timer < 1.80:
			var jt: float = (_title_form_timer - 0.95) / 0.85
			py = ground_y - sin(jt * PI) * 86.0
			demo_air = true
			demo_vy = -cos(jt * PI) * 420.0
			if not _title_jump_triggered:
				_title_jump_triggered = true
				player.play_clip("jump_stretch")
				vfx.emit_fox_sparks(Vector2(px, ground_y), 8)
		elif _title_form_timer >= 1.80 and not _title_land_triggered:
			_title_land_triggered = true
			player.play_clip("land_squash")
			vfx.emit_landing_splash(Vector2(px, ground_y), player.get_form_color(PlayerController.Form.FOX), false)
		elif _title_form_timer >= 2.25 and _title_form_timer < 2.85:
			demo_dash = true
			if not _title_dash_triggered:
				_title_dash_triggered = true
				player.play_clip("dash_surge")
				vfx.emit_fox_sparks(Vector2(px, ground_y - 14.0), 10)
	elif player.current_form == PlayerController.Form.MOTH:
		var climb: float = sin(clampf(_title_form_timer / 0.45, 0.0, 1.0) * PI * 0.5)
		py = ground_y - 74.0 * climb + sin(_time * 3.1) * 14.0
		demo_air = true
		demo_vy = cos(_time * 3.1) * 42.0
	else:
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
	reactive_flora.step_flora(dt, level_gen.chunks, player.position, 480.0)

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

	camera_rig.update_title_camera(_title_cam_x)
	level_gen.update_world(dt, _title_cam_x + 1950.0, _title_cam_x - 850.0, 0.0, player.position, player.get_form_color(), 3)
	ink_tide.update_tide(dt, 450.0, 500.0, 1, false)
	_sync_world_visuals(dt, _title_cam_x, 260.0)
	_update_post_fx(dt)
	audio.pump_audio(dt, 0.2, 0.1, 1, false, false, false)

func _emit_continuous_fx(dt: float) -> void:
	if player.current_form == PlayerController.Form.FOX and (player.dash_timer > 0.0 or score_mgr.flow_multiplier >= 5):
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
			vfx.emit_rain_ripple(Vector2(camera_rig.position.x + randf_range(-520.0, 620.0), 0.0))

func _sync_world_visuals(dt: float, cam_x: float, speed_px: float) -> void:
	if sky_rect != null:
		var smat: ShaderMaterial = sky_rect.material as ShaderMaterial
		if smat != null:
			smat.set_shader_parameter("scroll_x", cam_x)
			smat.set_shader_parameter("lightning_flash", _lightning_flash)
	env_mgr.sync_environment(dt, cam_x, speed_px, score_mgr.flow_multiplier, _lightning_flash, player.get_form_color())
	weather_sys.sync_weather(dt, cam_x, speed_px, player.get_form_color())

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
						score_mgr.add_flow(0.45)
						ink_tide.push_back(0.04)
						audio.play_draft_shimmer()
				continue

			if not bool(obs["cleared"]) and player.position.x > obox.end.x + 12.0:
				obs["cleared"] = true
				score_mgr.add_flow(0.35)
				ink_tide.push_back(0.025)

			if not pbox.intersects(obox):
				continue

			if kind == "monolith" or kind == "crystal_wall" or kind == "fallen_log":
				if player.current_form == PlayerController.Form.PANGOLIN:
					obs["intact"] = false
					obs["cleared"] = true
					player.grant_smash_boost(115.0)
					hitstop_timer = 0.045
					ink_tide.push_back(0.075)
					score_mgr.register_smash(150.0, 0.55)
					camera_rig.add_trauma(0.55)
					vfx.emit_smash_debris(obox.get_center(), player.position.y)
					fracture_sys.shatter_obstacle(obox.get_center(), player.position.y, kind == "crystal_wall")
					_trigger_shockwave(obox.get_center(), 0.95)
					audio.play_smash()
				elif player.invuln_timer <= 0.0:
					obs["intact"] = false
					_apply_stumble(0.24)
			elif kind == "thorn_bramble":
				if player.current_form == PlayerController.Form.PANGOLIN:
					obs["intact"] = false
					obs["cleared"] = true
					player.grant_smash_boost(45.0)
					score_mgr.register_smash(80.0, 0.35)
					camera_rig.add_trauma(0.28)
					vfx.emit_smash_debris(obox.get_center(), player.position.y)
					fracture_sys.shatter_obstacle(obox.get_center(), player.position.y, false)
					audio.play_smash()
				elif player.invuln_timer <= 0.0:
					obs["cleared"] = true
					_apply_stumble(0.22)
			elif kind == "root_tunnel":
				if player.invuln_timer <= 0.0:
					obs["cleared"] = true
					_apply_stumble(0.20)

func _apply_stumble(tide_surge: float) -> void:
	player.trigger_stumble()
	score_mgr.apply_stumble_penalty()
	ink_tide.surge_forward(tide_surge)
	camera_rig.add_trauma(0.45)
	hitstop_timer = 0.036
	audio.play_stumble()

func _trigger_death(cause: String) -> void:
	player.alive = false
	death_cause = cause
	death_slowmo_timer = 0.45
	camera_rig.add_trauma(0.75)
	audio.play_stumble()

func _update_post_fx(dt: float) -> void:
	if _shockwave_strength > 0.0:
		_shockwave_radius += dt * 1.45
		_shockwave_strength = maxf(0.0, _shockwave_strength - dt * 2.8)
	if post_rect != null:
		var mat: ShaderMaterial = post_rect.material as ShaderMaterial
		if mat != null:
			var speed_i: float = clampf(float(score_mgr.flow_multiplier - 4) / 6.0, 0.0, 1.0) if state == GameState.PLAYING else 0.0
			var vig: float = 0.14 + maxf(0.0, ink_tide.proximity - 0.22) * 0.48
			mat.set_shader_parameter("speed_intensity", speed_i)
			mat.set_shader_parameter("chromatic_pulse", vfx.chromatic_pulse)
			mat.set_shader_parameter("vignette_strength", vig)
			mat.set_shader_parameter("shockwave_radius", _shockwave_radius)
			mat.set_shader_parameter("shockwave_strength", _shockwave_strength)
			mat.set_shader_parameter("shockwave_center", _shockwave_center)
			mat.set_shader_parameter("accent_color", player.get_form_color())

func _on_form_shifted(prev_form: int, new_form: int, pos: Vector2) -> void:
	hitstop_timer = maxf(hitstop_timer, 0.015)
	camera_rig.add_trauma(0.18)
	vfx.emit_morph_burst(pos, player.get_form_color(prev_form), player.get_form_color(new_form))
	_trigger_shockwave(pos, 0.58)
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
	camera_rig.add_trauma(0.16)
	audio.play_dash()

func _on_player_fluttered(pos: Vector2) -> void:
	vfx.emit_moth_flutter(pos)
	audio.play_flutter()

func _on_player_landed(form_id: int, is_slam: bool, pos: Vector2) -> void:
	if form_id == PlayerController.Form.PANGOLIN and is_slam:
		hitstop_timer = 0.045
		camera_rig.add_trauma(0.55)
		vfx.emit_smash_debris(pos, pos.y)
		fracture_sys.stamp_ground_fissure(pos, 1.35)
		_trigger_shockwave(pos, 0.90)
		audio.play_slam_impact()
	else:
		vfx.emit_landing_splash(pos, player.get_form_color(form_id), form_id == PlayerController.Form.PANGOLIN)

func _on_paw_stepped(pos: Vector2) -> void:
	vfx.emit_fox_sparks(pos, 4)
	vfx.emit_pawprint(pos)
	audio.play_paw_step()
