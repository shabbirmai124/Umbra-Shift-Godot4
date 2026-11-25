extends Node
class_name ProceduralAudio

## 100% Procedural AudioStreamGenerator Sound Synthesizer for Godot 4
## Synthesizes:
## - Filtered pink-noise rain & shifting night wind ambience
## - Fox crisp paw-taps, airy Phantom Dash whoosh & melodic mint double-jump chime
## - Moth velvety wing-flutter sweeps & crystalline harmonic glide/updraft shimmers
## - Pangolin deep stone-roll rumble, heavy sub-bass Meteor Slam & layered rock-shatter crackles
## - Distinct 3-form shapeshift harmonic whooshes
## - Accelerating Shadow Ink Tide sub-bass heartbeat & Flow x3+ rhythmic arpeggio warmth

const SAMPLE_RATE := 22050.0

var _ambience_player: AudioStreamPlayer
var _ambience_pb: AudioStreamGeneratorPlayback
var _sfx_player: AudioStreamPlayer
var _sfx_pb: AudioStreamGeneratorPlayback

var _pink_b0 := 0.0
var _pink_b1 := 0.0
var _pink_b2 := 0.0
var _wind_lp := 0.0
var _wind_phase := 0.0
var _rumble_phase := 0.0
var _heartbeat_phase := 0.0
var _flow_arp_phase := 0.0
var _arp_step := 0
var _muted := false
var _is_rolling := false

var _voices: Array[Dictionary] = []

func _ready() -> void:
	_ambience_player = AudioStreamPlayer.new()
	var amb_stream := AudioStreamGenerator.new()
	amb_stream.mix_rate = SAMPLE_RATE
	amb_stream.buffer_length = 0.12
	_ambience_player.stream = amb_stream
	_ambience_player.volume_db = -10.0
	add_child(_ambience_player)
	_ambience_player.play()
	_ambience_pb = _ambience_player.get_stream_playback()

	_sfx_player = AudioStreamPlayer.new()
	var sfx_stream := AudioStreamGenerator.new()
	sfx_stream.mix_rate = SAMPLE_RATE
	sfx_stream.buffer_length = 0.08
	_sfx_player.stream = sfx_stream
	_sfx_player.volume_db = -4.0
	add_child(_sfx_player)
	_sfx_player.play()
	_sfx_pb = _sfx_player.get_stream_playback()

func set_muted(m: bool) -> void:
	_muted = m
	_ambience_player.stream_paused = m
	_sfx_player.stream_paused = m

func toggle_mute() -> bool:
	set_muted(not _muted)
	return _muted

func play_morph(form_id: int) -> void:
	# Bright mint for Fox, airy high cyan for Moth, deep resonant amber for Pangolin
	var freqs: Array = [329.63, 493.88, 659.25] if form_id == 0 else ([392.0, 587.33, 880.0, 987.77] if form_id == 1 else [146.83, 220.0, 293.66])
	for f in freqs:
		_spawn_voice(f * 0.94, f * 1.04, 0.25, 0.085, false)
	_spawn_voice(520.0 if form_id != 2 else 220.0, 1450.0 if form_id == 1 else 620.0, 0.14, 0.06, true)

func play_paw_step() -> void:
	var p := randf_range(0.92, 1.08)
	_spawn_voice(195.0 * p, 85.0 * p, 0.048, 0.07, false)

func play_jump(form_id: int, is_double: bool) -> void:
	var mult := 1.25 if is_double else 1.0
	var f0 := (120.0 if form_id == 2 else 255.0) * mult
	var f1 := (215.0 if form_id == 2 else 560.0) * mult
	_spawn_voice(f0, f1, 0.13, 0.13, false)
	if is_double:
		# Subtle melodic mint chime on Fox double-jump
		_spawn_voice(659.25, 880.0, 0.18, 0.075, false)

func play_dash() -> void:
	_spawn_voice(700.0, 2400.0, 0.19, 0.16, true)

func play_flutter() -> void:
	var p := randf_range(0.94, 1.08)
	_spawn_voice(470.0 * p, 760.0 * p, 0.12, 0.10, false)

func play_draft_shimmer() -> void:
	_spawn_voice(659.25, 659.25, 0.26, 0.065, false)
	_spawn_voice(880.0, 880.0, 0.30, 0.055, false)
	_spawn_voice(1174.66, 1174.66, 0.32, 0.045, false)

func play_slam_impact() -> void:
	_spawn_voice(110.0, 28.0, 0.26, 0.32, false)
	_spawn_voice(640.0, 180.0, 0.2, 0.22, true)

func play_smash() -> void:
	_spawn_voice(145.0, 32.0, 0.24, 0.30, false)
	_spawn_voice(1350.0, 300.0, 0.25, 0.26, true)
	_spawn_voice(1046.5, 980.0, 0.14, 0.08, false)

func play_stumble() -> void:
	_spawn_voice(165.0, 58.0, 0.22, 0.22, false)

func play_heartbeat(intensity: float) -> void:
	_spawn_voice(68.0, 34.0, 0.18, clampf(0.08 + intensity * 0.22, 0.05, 0.3), false)

func _spawn_voice(f0: float, f1: float, dur: float, amp: float, noise: bool) -> void:
	if _muted or _voices.size() > 28:
		return
	_voices.append({"f0": f0, "f1": f1, "dur": dur, "t": 0.0, "phase": 0.0, "amp": amp, "noise": noise})

func pump_audio(dt: float, speed_ratio: float, tide_proximity: float, flow_mult: int, is_rolling: bool, is_playing: bool) -> void:
	if _muted:
		return
	_is_rolling = is_rolling and is_playing

	if is_playing:
		# Accelerating Shadow Ink Tide danger heartbeat
		var pulse_rate := 0.85 + tide_proximity * 2.1 + float(flow_mult - 1) * 0.08
		_heartbeat_phase += dt * pulse_rate
		if _heartbeat_phase >= 1.0:
			_heartbeat_phase -= 1.0
			if tide_proximity > 0.25:
				play_heartbeat(tide_proximity - 0.25)

		# Subtle rhythmic harmonic arpeggio unlocked at Flow x3+
		if flow_mult >= 3:
			var arp_rate := 3.2 + float(flow_mult - 3) * 0.45
			_flow_arp_phase += dt * arp_rate
			if _flow_arp_phase >= 1.0:
				_flow_arp_phase -= 1.0
				var scale := [293.66, 329.63, 440.0, 493.88, 587.33, 659.25, 880.0]
				var freq: float = scale[_arp_step % scale.size()]
				_arp_step += 1
				_spawn_voice(freq, freq, 0.16, 0.03 + minf(0.04, float(flow_mult - 2) * 0.005), false)

	_fill_ambience(speed_ratio)
	_fill_sfx()

func _fill_ambience(speed_ratio: float) -> void:
	if _ambience_pb == null:
		return
	var frames := _ambience_pb.get_frames_available()
	var cutoff := clampf(0.04 + speed_ratio * 0.08, 0.04, 0.18)
	for _i in range(frames):
		var white := randf_range(-1.0, 1.0)
		_pink_b0 = 0.99765 * _pink_b0 + white * 0.099046
		_pink_b1 = 0.96300 * _pink_b1 + white * 0.296516
		_pink_b2 = 0.57000 * _pink_b2 + white * 1.052691
		var pink := (_pink_b0 + _pink_b1 + _pink_b2 + white * 0.1848) * 0.055
		_wind_lp += (pink - _wind_lp) * cutoff
		_wind_phase += 0.00018
		var wind_mod := 0.65 + 0.35 * sin(_wind_phase)
		var rumble := 0.0
		if _is_rolling:
			_rumble_phase += TAU * (52.0 + speed_ratio * 24.0) / SAMPLE_RATE
			rumble = sin(_rumble_phase) * 0.14
		var sample := clampf(pink * 0.35 + _wind_lp * 1.15 * wind_mod + rumble, -0.82, 0.82)
		_ambience_pb.push_frame(Vector2(sample, sample))

func _fill_sfx() -> void:
	if _sfx_pb == null:
		return
	var frames := _sfx_pb.get_frames_available()
	var inv_sr := 1.0 / SAMPLE_RATE
	for _i in range(frames):
		var mix := 0.0
		for idx in range(_voices.size() - 1, -1, -1):
			var v: Dictionary = _voices[idx]
			v["t"] += inv_sr
			if v["t"] >= v["dur"]:
				_voices.remove_at(idx)
				continue
			var prog: float = v["t"] / v["dur"]
			var env := (1.0 - prog) * minf(1.0, prog * 18.0)
			if v["noise"]:
				mix += randf_range(-1.0, 1.0) * v["amp"] * env
			else:
				var freq := lerpf(v["f0"], v["f1"], prog)
				v["phase"] += TAU * freq * inv_sr
				mix += sin(v["phase"]) * v["amp"] * env
		var clamped := clampf(mix, -0.92, 0.92)
		_sfx_pb.push_frame(Vector2(clamped, clamped))
