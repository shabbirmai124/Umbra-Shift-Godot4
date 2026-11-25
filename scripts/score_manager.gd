extends Node
class_name ScoreManager

## Manages distance, score, Flow Multiplier (x1..x10), obstacles shattered,
## and local ConfigFile persistence (user://highscore.cfg).

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

func add_distance_px(dx: float) -> void:
	var meters: float = maxf(0.0, dx) / PIXELS_PER_METER
	distance_m += meters
	score += meters * 10.0 * float(flow_multiplier)

func add_flow(amount: float) -> void:
	flow_decay_timer = 4.6
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
	score += bonus_points * float(flow_multiplier)
	add_flow(flow_gain)

func apply_stumble_penalty() -> void:
	flow_multiplier = maxi(1, int(flow_multiplier * 0.5))
	flow_charge = 0.0

func step_decay(dt: float) -> void:
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

func get_difficulty() -> float:
	# 0-150m Awakening -> 150-500m Twilight Rush -> 500-1000m Tempest Flow -> 1000m+ Abyssal Speedrun
	return clampf((distance_m - 60.0) / 1400.0, 0.0, 1.0)

func load_records() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_distance = int(cfg.get_value("records", "best_distance", 0))
		best_score = int(cfg.get_value("records", "best_score", 0))

func save_records() -> bool:
	var dist_i: int = int(distance_m)
	var score_i: int = int(score)
	var is_new: bool = false
	if dist_i > best_distance:
		best_distance = dist_i
		is_new = true
	if score_i > best_score:
		best_score = score_i
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("records", "best_distance", best_distance)
	cfg.set_value("records", "best_score", best_score)
	cfg.save(SAVE_PATH)
	return is_new
