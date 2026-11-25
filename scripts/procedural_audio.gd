extends Node
class_name ProceduralAudio

## 100% Natural Organic Woodland Soundscape & Melodic Synthesizer (Zero Harsh Static Noise!)
## Synthesizes:
## - Warm breathing pentatonic moonlit forest pad (pure harmonic sine/triangle voices with slow organic breeze swells)
## - Authentic night-forest nature cues: gentle dew water droplets, distant melodic owl-flute calls, soft summer crickets
## - Soft organic wildlife SFX: cushioned mossy paw-steps, breezy silk Moth flutters, melodic harp shapeshift chords,
##   warm resonant woody/stone Pangolin impacts, and subtle low heartbeat pulse when Ink Tide closes in
## - Live Master / Ambience / SFX volume mixer controls & gentle tunnel acoustic warmth

const SAMPLE_RATE: float = 22050.0

var master_volume: float = 0.85
var ambience_volume: float = 0.78
var sfx_volume: float = 0.88

var _ambience_player: AudioStreamPlayer
var _ambience_pb: AudioStreamGeneratorPlayback
var _sfx_player: AudioStreamPlayer
var _sfx_pb: AudioStreamGeneratorPlayback

var _pad_p0: float = 0.0
var _pad_p1: float = 0.0
var _pad_p2: float = 0.0
var _pad_p3: float = 0.0
var _swell_phase: float = 0.0
var _breeze_phase: float = 0.0
var _cricket_phase: float = 0.0
var _cricket_mod: float = 0.0
var _rumble_phase: float = 0.0
var _heartbeat_phase: float = 0.0
var _flow_arp_phase: float = 0.0
var _nature_event_timer: float = 1.8
var _arp_step: int = 0
var _muted: bool = false
var _is_rolling: bool = false
var _tunnel_muffle: float = 0.0

var _voices: Array[Dictionary] = []

func _ready() -> void:
	_ambience_player = AudioStreamPlayer.new()
	var amb_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	amb_stream.mix_rate = SAMPLE_RATE
	amb_stream.buffer_length = 0.14
	_ambience_player.stream = amb_stream
	_ambience_player.set("playback_type", 1)
	add_child(_ambience_player)

	_sfx_player = AudioStreamPlayer.new()
	var sfx_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	sfx_stream.mix_rate = SAMPLE_RATE
	sfx_stream.buffer_length = 0.09
	_sfx_player.stream = sfx_stream
	_sfx_player.set("playback_type", 1)
	add_child(_sfx_player)

	_apply_volume_db()
	_ambience_player.play()
	_ambience_pb = _ambience_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_sfx_player.play()
	_sfx_pb = _sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback

func set_volumes(master_v: float, amb_v: float, sfx_v: float) -> void:
	master_volume = clampf(master_v, 0.0, 1.0)
	ambience_volume = clampf(amb_v, 0.0, 1.0)
	sfx_volume = clampf(sfx_v, 0.0, 1.0)
	_apply_volume_db()

func _apply_volume_db() -> void:
	if _ambience_player != null:
		var amb_lin: float = master_volume * ambience_volume * 0.48
		_ambience_player.volume_db = -80.0 if amb_lin <= 0.001 else linear_to_db(amb_lin)
	if _sfx_player != null:
		var sfx_lin: float = master_volume * sfx_volume * 0.62
		_sfx_player.volume_db = -80.0 if sfx_lin <= 0.001 else linear_to_db(sfx_lin)

func set_muted(m: bool) -> void:
	_muted = m
	_ambience_player.stream_paused = m
	_sfx_player.stream_paused = m

func toggle_mute() -> bool:
	set_muted(not _muted)
	return _muted

func play_morph(form_id: int) -> void:
	# Pure melodic harp-like harmonic chords (zero static noise!)
	var freqs: Array[float] = [293.66, 440.0, 587.33]
	if form_id == 1:
		freqs = [392.0, 523.25, 659.25, 880.0]
	elif form_id == 2:
		freqs = [146.83, 220.0, 293.66]
	for i in range(freqs.size()):
		var f: float = freqs[i]
		_spawn_voice(f * 0.98, f * 1.01, 0.34 + float(i) * 0.05, 0.075, "harp")

func play_paw_step() -> void:
	# Soft organic mossy ground tap
	var p: float = randf_range(0.92, 1.08)
	_spawn_voice(175.0 * p, 92.0 * p, 0.055, 0.065, "sine")

func play_jump(form_id: int, is_double: bool) -> void:
	var mult: float = 1.25 if is_double else 1.0
	var base0: float = 135.0 if form_id == 2 else 260.0
	var base1: float = 220.0 if form_id == 2 else 520.0
	_spawn_voice(base0 * mult, base1 * mult, 0.16, 0.11, "sine")
	if is_double:
		_spawn_voice(587.33, 880.0, 0.24, 0.075, "harp")

func play_dash() -> void:
	# Airy resonant flute-breeze glide (no harsh static)
	_spawn_voice(340.0, 740.0, 0.20, 0.10, "sine")
	_spawn_voice(520.0, 1040.0, 0.18, 0.065, "harp")

func play_flutter() -> void:
	# Velvety soft Moth wingbeat harmonic chime
	var p: float = randf_range(0.94, 1.08)
	_spawn_voice(440.0 * p, 660.0 * p, 0.16, 0.08, "sine")
	_spawn_voice(880.0 * p, 987.77 * p, 0.14, 0.04, "harp")

func play_draft_shimmer() -> void:
	_spawn_voice(587.33, 587.33, 0.36, 0.06, "harp")
	_spawn_voice(783.99, 783.99, 0.40, 0.055, "harp")
	_spawn_voice(1174.66, 1174.66, 0.44, 0.045, "harp")

func play_slam_impact() -> void:
	# Deep natural taiko-earth thud + warm wooden resonance
	_spawn_voice(118.0, 38.0, 0.30, 0.26, "sine")
	_spawn_voice(210.0, 95.0, 0.18, 0.12, "wood")

func play_smash() -> void:
	# Warm resonant earth/stone shatter chord without static hiss
	_spawn_voice(145.0, 42.0, 0.28, 0.24, "sine")
	_spawn_voice(310.0, 140.0, 0.20, 0.14, "wood")
	_spawn_voice(880.0, 784.0, 0.24, 0.065, "harp")

func play_stumble() -> void:
	_spawn_voice(160.0, 72.0, 0.24, 0.18, "wood")

func play_heartbeat(intensity: float) -> void:
	_spawn_voice(74.0, 42.0, 0.20, clampf(0.06 + intensity * 0.16, 0.04, 0.22), "sine")

func _play_natural_forest_cue() -> void:
	# Alternating organic night-forest details: dew water droplet, distant flute/owl call, or soft wind chime
	var pick: int = randi() % 3
	if pick == 0:
		# Soft water droplet falling onto a mossy puddle
		var f: float = randf_range(580.0, 860.0)
		_spawn_voice(f, f * 1.48, 0.11, 0.042, "sine")
	elif pick == 1:
		# Gentle distant woodland bird / owl 2-note breathy call
		var f: float = randf_range(440.0, 520.0)
		_spawn_voice(f, f * 0.89, 0.42, 0.036, "sine")
	else:
		# Delicate pentatonic forest wind-chime note
		var notes: Array[float] = [587.33, 659.25, 783.99, 880.0, 1046.5]
		var n: float = notes[randi() % notes.size()]
		_spawn_voice(n, n, 0.55, 0.032, "harp")

func _spawn_voice(f0: float, f1: float, dur: float, amp: float, kind: String) -> void:
	if _muted or _voices.size() > 28:
		return
	_voices.append({"f0": f0, "f1": f1, "dur": dur, "t": 0.0, "phase": 0.0, "amp": amp, "kind": kind})

func pump_audio(dt: float, speed_ratio: float, tide_proximity: float, flow_mult: int, is_rolling: bool, is_playing: bool, in_tunnel: bool = false) -> void:
	if _muted:
		return
	_is_rolling = is_rolling and is_playing
	_tunnel_muffle = lerpf(_tunnel_muffle, 1.0 if in_tunnel else 0.0, minf(1.0, dt * 6.0))

	_nature_event_timer -= dt
	if _nature_event_timer <= 0.0:
		_play_natural_forest_cue()
		_nature_event_timer = randf_range(1.9, 3.8)

	if is_playing:
		var pulse_rate: float = 0.82 + tide_proximity * 1.9 + float(flow_mult - 1) * 0.06
		_heartbeat_phase += dt * pulse_rate
		if _heartbeat_phase >= 1.0:
			_heartbeat_phase -= 1.0
			if tide_proximity > 0.30:
				play_heartbeat(tide_proximity - 0.30)

		if flow_mult >= 3:
			var arp_rate: float = 2.6 + float(flow_mult - 3) * 0.35
			_flow_arp_phase += dt * arp_rate
			if _flow_arp_phase >= 1.0:
				_flow_arp_phase -= 1.0
				var arp_scale: Array[float] = [293.66, 349.23, 440.0, 523.25, 587.33, 659.25, 880.0]
				var freq: float = arp_scale[_arp_step % arp_scale.size()]
				_arp_step += 1
				_spawn_voice(freq, freq, 0.28, 0.028 + minf(0.032, float(flow_mult - 2) * 0.004), "harp")

	_fill_ambience(speed_ratio)
	_fill_sfx()

func _fill_ambience(speed_ratio: float) -> void:
	if _ambience_pb == null and _ambience_player != null and _ambience_player.playing:
		_ambience_pb = _ambience_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _ambience_pb == null:
		return
	var frames: int = _ambience_pb.get_frames_available()
	var inv_sr: float = 1.0 / SAMPLE_RATE
	var muffle_gain: float = lerpf(1.0, 0.62, _tunnel_muffle)

	# Serene, warm D-minor / F-major pentatonic twilight forest pad + gentle distant night crickets
	# ZERO white noise / static hiss!
	for _i in range(frames):
		_swell_phase += TAU * 0.085 * inv_sr
		_breeze_phase += TAU * 0.14 * inv_sr
		var swell: float = 0.68 + 0.32 * sin(_swell_phase)
		var breeze: float = 0.62 + 0.38 * sin(_breeze_phase)

		_pad_p0 += TAU * 146.83 * inv_sr # D3 warm root
		_pad_p1 += TAU * 220.00 * inv_sr # A3 open fifth
		_pad_p2 += TAU * 261.63 * inv_sr # C4 soft seventh
		_pad_p3 += TAU * 329.63 * inv_sr # E4 luminous ninth

		var pad_l: float = (sin(_pad_p0) * 0.22 + sin(_pad_p1) * 0.14 * swell + sin(_pad_p2) * 0.09 * breeze + sin(_pad_p3) * 0.06 * swell * muffle_gain)
		var pad_r: float = (sin(_pad_p0 + 0.25) * 0.22 + sin(_pad_p1 + 0.4) * 0.14 * breeze + sin(_pad_p2 + 0.6) * 0.09 * swell + sin(_pad_p3 + 0.9) * 0.06 * breeze * muffle_gain)

		# Very soft, gentle natural night cricket pulse (quiet high harmonic shimmer, never harsh)
		_cricket_mod += TAU * 0.42 * inv_sr
		var c_env: float = maxf(0.0, sin(_cricket_mod) - 0.68) * 3.1
		var c_pulse: float = maxf(0.0, sin(_cricket_mod * 28.0))
		_cricket_phase += TAU * 3420.0 * inv_sr
		var cricket: float = sin(_cricket_phase) * c_env * c_pulse * 0.014 * muffle_gain

		var rumble: float = 0.0
		if _is_rolling:
			_rumble_phase += TAU * (56.0 + speed_ratio * 22.0) / SAMPLE_RATE
			rumble = sin(_rumble_phase) * 0.12

		var out_l: float = clampf(pad_l + cricket + rumble, -0.78, 0.78)
		var out_r: float = clampf(pad_r + cricket * 0.8 + rumble, -0.78, 0.78)
		_ambience_pb.push_frame(Vector2(out_l, out_r))

func _fill_sfx() -> void:
	if _sfx_pb == null and _sfx_player != null and _sfx_player.playing:
		_sfx_pb = _sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _sfx_pb == null:
		return
	var frames: int = _sfx_pb.get_frames_available()
	var inv_sr: float = 1.0 / SAMPLE_RATE
	for _i in range(frames):
		var mix: float = 0.0
		for idx in range(_voices.size() - 1, -1, -1):
			var v: Dictionary = _voices[idx]
			var vt: float = float(v["t"]) + inv_sr
			var vdur: float = maxf(0.001, float(v["dur"]))
			v["t"] = vt
			if vt >= vdur:
				_voices.remove_at(idx)
				continue
			var prog: float = vt / vdur
			var attack: float = minf(1.0, prog * 22.0)
			var release: float = pow(1.0 - prog, 1.55)
			var env: float = attack * release
			var vamp: float = float(v["amp"])
			var freq: float = lerpf(float(v["f0"]), float(v["f1"]), prog)
			var vphase: float = float(v["phase"]) + TAU * freq * inv_sr
			v["phase"] = vphase
			var vkind: String = String(v["kind"])
			if vkind == "harp":
				mix += (sin(vphase) * 0.78 + sin(vphase * 2.0) * 0.22) * vamp * env
			elif vkind == "wood":
				mix += (sin(vphase) * 0.65 + sin(vphase * 2.75) * 0.25 + sin(vphase * 4.1) * 0.10) * vamp * env
			else:
				mix += sin(vphase) * vamp * env
		var clamped: float = clampf(mix, -0.88, 0.88)
		_sfx_pb.push_frame(Vector2(clamped, clamped))
