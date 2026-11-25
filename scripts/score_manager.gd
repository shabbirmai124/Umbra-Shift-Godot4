extends Node
class_name ScoreManager

## Manages distance, score, Flow Multiplier (x1..x10), Difficulty Modes (Easy/Normal/Hard),
## custom Run Speed multiplier, and local ConfigFile persistence (user://highscore.cfg).

enum DifficultyMode { EASY, NORMAL, HARD }

const SAVE_PATH: String = "user://highscore.cfg"
const PIXELS_PER_METER: float = 28.0

var distance_m: float = 0.0
var score: float = 0.0
var smashed_count: int = 0
var flow_multiplier: int = 1
var flow_charge: float = 0.0
var max_flow: int = 1
var flow_decay_timer: float = 0.0

var best_distance: int = 0
var best_score: int = 0

var difficulty_mode: int = DifficultyMode.NORMAL
var run_speed_scale: float = 1.0

func _ready() -> void:
	load_records()

func reset_run() -> void:
	distance_m = 0.0
	score = 0.0
	smashed_count = 0
	flow_multiplier = 1
	flow_charge = 0.0
	max_flow = 1
	flow_decay_timer = 0.0

func set_gameplay_settings(mode: int, speed_scale: float) -> void:
	difficulty_mode = clampi(mode, DifficultyMode.EASY, DifficultyMode.HARD)
	run_speed_scale = clampf(speed_scale, 0.60, 1.60)
	_save_config()

func get_mode_name() -> String:
	match difficulty_mode:
		DifficultyMode.EASY:
			return "EASY"
		DifficultyMode.HARD:
			return "HARD"
		_:
			return "NORMAL"

func get_mode_speed_mult() -> float:
	match difficulty_mode:
		DifficultyMode.EASY:
			return 0.84
		DifficultyMode.HARD:
			return 1.18
		_:
			return 1.0

func get_effective_speed_mult() -> float:
	return clampf(get_mode_speed_mult() * run_speed_scale, 0.55, 1.85)

func get_tide_aggression() -> float:
	match difficulty_mode:
		DifficultyMode.EASY:
			return 0.65
		DifficultyMode.HARD:
			return 1.38
		_:
			return 1.0

func get_score_mult() -> float:
	match difficulty_mode:
		DifficultyMode.EASY:
			return 0.85
		DifficultyMode.HARD:
			return 1.35
		_:
			return 1.0

func get_stumble_invuln() -> float:
	match difficulty_mode:
		DifficultyMode.EASY:
			return 1.25
		DifficultyMode.HARD:
			return 0.55
		_:
			return 0.78

func add_distance_px(dx: float) -> void:
	var meters: float = maxf(0.0, dx) / PIXELS_PER_METER
	distance_m += meters
	score += meters * 10.0 * float(flow_multiplier) * get_score_mult()

func add_flow(amount: float) -> void:
	flow_decay_timer = 5.4 if difficulty_mode == DifficultyMode.EASY else (3.8 if difficulty_mode == DifficultyMode.HARD else 4.6)
	if flow_multiplier >= 10:
		flow_charge = 1.0
		return
	flow_charge += amount
	while flow_charge >= 1.0 and flow_multiplier < 10:
		flow_charge -= 1.0
		flow_multiplier += 1
		max_flow = maxi(max_flow, flow_multiplier)

func register_smash(bonus_points: float = 150.0, flow_gain: float = 0.55) -> void:
	smashed_count += 1
	score += bonus_points * float(flow_multiplier) * get_score_mult()
	add_flow(flow_gain)

func apply_stumble_penalty() -> void:
	if difficulty_mode == DifficultyMode.EASY:
		flow_multiplier = maxi(1, flow_multiplier - 1)
	else:
		flow_multiplier = maxi(1, int(flow_multiplier * 0.5))
	flow_charge = 0.0

func step_decay(dt: float) -> void:
	if flow_multiplier > 1 or flow_charge > 0.0:
		flow_decay_timer -= dt
		if flow_decay_timer <= 0.0:
			var decay_rate: float = 0.10 if difficulty_mode == DifficultyMode.EASY else (0.24 if difficulty_mode == DifficultyMode.HARD else 0.16)
			flow_charge -= decay_rate * dt
			if flow_charge < 0.0:
				if flow_multiplier > 1:
					flow_multiplier -= 1
					flow_charge = 0.72
				else:
					flow_charge = 0.0

func get_difficulty() -> float:
	var ramp_span: float = 1750.0 if difficulty_mode == DifficultyMode.EASY else (1050.0 if difficulty_mode == DifficultyMode.HARD else 1400.0)
	var base_bias: float = 0.0 if difficulty_mode == DifficultyMode.EASY else (0.14 if difficulty_mode == DifficultyMode.HARD else 0.0)
	return clampf(base_bias + (distance_m - 60.0) / ramp_span, 0.0, 1.0)

func load_records() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_distance = int(cfg.get_value("records", "best_distance", 0))
		best_score = int(cfg.get_value("records", "best_score", 0))
		difficulty_mode = clampi(int(cfg.get_value("settings", "difficulty_mode", DifficultyMode.NORMAL)), DifficultyMode.EASY, DifficultyMode.HARD)
		run_speed_scale = clampf(float(cfg.get_value("settings", "run_speed_scale", 1.0)), 0.60, 1.60)

func _save_config() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("records", "best_distance", best_distance)
	cfg.set_value("records", "best_score", best_score)
	cfg.set_value("settings", "difficulty_mode", difficulty_mode)
	cfg.set_value("settings", "run_speed_scale", run_speed_scale)
	cfg.save(SAVE_PATH)

func save_records() -> bool:
	var dist_i: int = int(distance_m)
	var score_i: int = int(score)
	var is_new: bool = false
	if dist_i > best_distance:
		best_distance = dist_i
		is_new = true
	if score_i > best_score:
		best_score = score_i
	_save_config()
	return is_new
