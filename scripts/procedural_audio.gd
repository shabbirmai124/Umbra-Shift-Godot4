extends Node
class_name ProceduralAudio

## High-Performance 100% Natural Organic Woodland Soundscape & Melodic Synthesizer
## Optimized for Godot 4 GDScript:
## - Uses bulk push_buffer(PackedVector2Array) instead of per-sample push_frame()
## - Zero per-frame Dictionary lookups using Structure-of-Arrays (SoA) voice storage
## - O(1) silent fast-path when no SFX voices are active
## - Pure harmonic woodland pad, dew droplets, distant owl-flute calls, soft summer crickets, & tactile SFX

const SAMPLE_RATE: float = 16000.0
const INV_SR: float = 1.0 / SAMPLE_RATE
const MAX_VOICES: int = 24

const KIND_SINE: int = 0
const KIND_HARP: int = 1
const KIND_WOOD: int = 2

var ARP_SCALE: PackedFloat32Array = PackedFloat32Array([293.66, 349.23, 440.0, 523.25, 587.33, 659.25, 880.0])
var CHIME_NOTES: PackedFloat32Array = PackedFloat32Array([587.33, 659.25, 783.99, 880.0, 1046.5])

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

# Zero-GC SoA active SFX voice pool (dense [0 .. _v_count - 1])
var _v_count: int = 0
var _v_f0: PackedFloat32Array = PackedFloat32Array()
var _v_f1: PackedFloat32Array = PackedFloat32Array()
var _v_dur: PackedFloat32Array = PackedFloat32Array()
var _v_t: PackedFloat32Array = PackedFloat32Array()
var _v_phase: PackedFloat32Array = PackedFloat32Array()
var _v_amp: PackedFloat32Array = PackedFloat32Array()
var _v_kind: PackedInt32Array = PackedInt32Array()

# Reusable audio frame buffers for bulk push_buffer()
var _amb_buf: PackedVector2Array = PackedVector2Array()
var _sfx_buf: PackedVector2Array = PackedVector2Array()
var _zero_buf: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	_v_f0.resize(MAX_VOICES)
	_v_f1.resize(MAX_VOICES)
	_v_dur.resize(MAX_VOICES)
	_v_t.resize(MAX_VOICES)
	_v_phase.resize(MAX_VOICES)
	_v_amp.resize(MAX_VOICES)
	_v_kind.resize(MAX_VOICES)

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
	if form_id == 1:
		_spawn_voice(384.16, 395.92, 0.34, 0.075, KIND_HARP)
		_spawn_voice(512.78, 528.48, 0.39, 0.075, KIND_HARP)
		_spawn_voice(646.06, 665.84, 0.44, 0.075, KIND_HARP)
		_spawn_voice(862.40, 888.80, 0.49, 0.075, KIND_HARP)
	elif form_id == 2:
		_spawn_voice(143.89, 148.30, 0.34, 0.075, KIND_HARP)
		_spawn_voice(215.60, 222.20, 0.39, 0.075, KIND_HARP)
		_spawn_voice(287.79, 296.60, 0.44, 0.075, KIND_HARP)
	else:
		_spawn_voice(287.79, 296.60, 0.34, 0.075, KIND_HARP)
		_spawn_voice(431.20, 444.40, 0.39, 0.075, KIND_HARP)
		_spawn_voice(575.58, 593.20, 0.44, 0.075, KIND_HARP)

func play_paw_step() -> void:
	var p: float = randf_range(0.92, 1.08)
	_spawn_voice(175.0 * p, 92.0 * p, 0.055, 0.065, KIND_SINE)

func play_jump(form_id: int, is_double: bool) -> void:
	var mult: float = 1.25 if is_double else 1.0
	var base0: float = 135.0 if form_id == 2 else 260.0
	var base1: float = 220.0 if form_id == 2 else 520.0
	_spawn_voice(base0 * mult, base1 * mult, 0.16, 0.11, KIND_SINE)
	if is_double:
		_spawn_voice(587.33, 880.0, 0.24, 0.075, KIND_HARP)

func play_dash() -> void:
	_spawn_voice(340.0, 740.0, 0.20, 0.10, KIND_SINE)
	_spawn_voice(520.0, 1040.0, 0.18, 0.065, KIND_HARP)

func play_flutter() -> void:
	var p: float = randf_range(0.94, 1.08)
	_spawn_voice(440.0 * p, 660.0 * p, 0.16, 0.08, KIND_SINE)
	_spawn_voice(880.0 * p, 987.77 * p, 0.14, 0.04, KIND_HARP)

func play_draft_shimmer() -> void:
	_spawn_voice(587.33, 587.33, 0.36, 0.06, KIND_HARP)
	_spawn_voice(783.99, 783.99, 0.40, 0.055, KIND_HARP)
	_spawn_voice(1174.66, 1174.66, 0.44, 0.045, KIND_HARP)

func play_slam_impact() -> void:
	_spawn_voice(118.0, 38.0, 0.30, 0.26, KIND_SINE)
	_spawn_voice(210.0, 95.0, 0.18, 0.12, KIND_WOOD)

func play_smash() -> void:
	_spawn_voice(145.0, 42.0, 0.28, 0.24, KIND_SINE)
	_spawn_voice(310.0, 140.0, 0.20, 0.14, KIND_WOOD)
	_spawn_voice(880.0, 784.0, 0.24, 0.065, KIND_HARP)

func play_stumble() -> void:
	_spawn_voice(160.0, 72.0, 0.24, 0.18, KIND_WOOD)

func play_heartbeat(intensity: float) -> void:
	_spawn_voice(74.0, 42.0, 0.20, clampf(0.06 + intensity * 0.16, 0.04, 0.22), KIND_SINE)

func _play_natural_forest_cue() -> void:
	var pick: int = randi() % 3
	if pick == 0:
		var f: float = randf_range(580.0, 860.0)
		_spawn_voice(f, f * 1.48, 0.11, 0.042, KIND_SINE)
	elif pick == 1:
		var f: float = randf_range(440.0, 520.0)
		_spawn_voice(f, f * 0.89, 0.42, 0.036, KIND_SINE)
	else:
		var n: float = CHIME_NOTES[randi() % CHIME_NOTES.size()]
		_spawn_voice(n, n, 0.55, 0.032, KIND_HARP)

func _spawn_voice(f0: float, f1: float, dur: float, amp: float, kind: int) -> void:
	if _muted or _v_count >= MAX_VOICES:
		return
	var idx: int = _v_count
	_v_count += 1
	_v_f0[idx] = f0
	_v_f1[idx] = f1
	_v_dur[idx] = maxf(0.001, dur)
	_v_t[idx] = 0.0
	_v_phase[idx] = 0.0
	_v_amp[idx] = amp
	_v_kind[idx] = kind

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
				var freq: float = ARP_SCALE[_arp_step % ARP_SCALE.size()]
				_arp_step += 1
				_spawn_voice(freq, freq, 0.28, 0.028 + minf(0.032, float(flow_mult - 2) * 0.004), KIND_HARP)

	_fill_ambience(speed_ratio)
	_fill_sfx()

func _fill_ambience(speed_ratio: float) -> void:
	if _ambience_pb == null and _ambience_player != null and _ambience_player.playing:
		_ambience_pb = _ambience_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _ambience_pb == null:
		return
	var frames: int = _ambience_pb.get_frames_available()
	if frames <= 0:
		return
	if _amb_buf.size() != frames:
		_amb_buf.resize(frames)

	var muffle_gain: float = lerpf(1.0, 0.62, _tunnel_muffle)
	var d_swell: float = TAU * 0.085 * INV_SR
	var d_breeze: float = TAU * 0.14 * INV_SR
	var d_p0: float = TAU * 146.83 * INV_SR
	var d_p1: float = TAU * 220.00 * INV_SR
	var d_p2: float = TAU * 261.63 * INV_SR
	var d_p3: float = TAU * 329.63 * INV_SR
	var d_cmod: float = TAU * 0.42 * INV_SR
	var d_cph: float = TAU * 3420.0 * INV_SR
	var d_rumble: float = TAU * (56.0 + speed_ratio * 22.0) * INV_SR
	var rolling: bool = _is_rolling

	var p0: float = _pad_p0
	var p1: float = _pad_p1
	var p2: float = _pad_p2
	var p3: float = _pad_p3
	var sw_p: float = _swell_phase
	var br_p: float = _breeze_phase
	var cm: float = _cricket_mod
	var cp: float = _cricket_phase
	var rp: float = _rumble_phase

	for i in range(frames):
		sw_p += d_swell
		br_p += d_breeze
		var swell: float = 0.68 + 0.32 * sin(sw_p)
		var breeze: float = 0.62 + 0.38 * sin(br_p)

		p0 += d_p0
		p1 += d_p1
		p2 += d_p2
		p3 += d_p3

		var s0: float = sin(p0) * 0.22
		var s1: float = sin(p1) * 0.14
		var s2: float = sin(p2) * 0.09
		var s3: float = sin(p3) * 0.06 * muffle_gain

		var pad_l: float = s0 + s1 * swell + s2 * breeze + s3 * swell
		var pad_r: float = s0 * 0.96 + s1 * breeze + s2 * swell + s3 * breeze

		cm += d_cmod
		var c_env: float = maxf(0.0, sin(cm) - 0.68) * 3.1
		var cricket: float = 0.0
		if c_env > 0.0:
			cp += d_cph
			var c_pulse: float = maxf(0.0, sin(cm * 28.0))
			cricket = sin(cp) * c_env * c_pulse * 0.014 * muffle_gain

		var rumble: float = 0.0
		if rolling:
			rp += d_rumble
			rumble = sin(rp) * 0.12

		_amb_buf[i] = Vector2(
			clampf(pad_l + cricket + rumble, -0.78, 0.78),
			clampf(pad_r + cricket * 0.8 + rumble, -0.78, 0.78)
		)

	_pad_p0 = fmod(p0, TAU)
	_pad_p1 = fmod(p1, TAU)
	_pad_p2 = fmod(p2, TAU)
	_pad_p3 = fmod(p3, TAU)
	_swell_phase = fmod(sw_p, TAU)
	_breeze_phase = fmod(br_p, TAU)
	_cricket_mod = fmod(cm, TAU)
	_cricket_phase = fmod(cp, TAU)
	_rumble_phase = fmod(rp, TAU)

	_ambience_pb.push_buffer(_amb_buf)

func _fill_sfx() -> void:
	if _sfx_pb == null and _sfx_player != null and _sfx_player.playing:
		_sfx_pb = _sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _sfx_pb == null:
		return
	var frames: int = _sfx_pb.get_frames_available()
	if frames <= 0:
		return

	# O(1) fast path when no SFX voices are playing
	if _v_count == 0:
		if _zero_buf.size() != frames:
			_zero_buf.resize(frames)
			_zero_buf.fill(Vector2.ZERO)
		_sfx_pb.push_buffer(_zero_buf)
		return

	if _sfx_buf.size() != frames:
		_sfx_buf.resize(frames)

	var tau_inv_sr: float = TAU * INV_SR
	for i in range(frames):
		var mix: float = 0.0
		var idx: int = _v_count - 1
		while idx >= 0:
			var vt: float = _v_t[idx] + INV_SR
			var vdur: float = _v_dur[idx]
			if vt >= vdur:
				# Swap-remove dead voice in O(1)
				var last: int = _v_count - 1
				if idx != last:
					_v_f0[idx] = _v_f0[last]
					_v_f1[idx] = _v_f1[last]
					_v_dur[idx] = _v_dur[last]
					_v_t[idx] = _v_t[last]
					_v_phase[idx] = _v_phase[last]
					_v_amp[idx] = _v_amp[last]
					_v_kind[idx] = _v_kind[last]
				_v_count = last
				idx -= 1
				continue
			_v_t[idx] = vt
			var prog: float = vt / vdur
			var rem: float = 1.0 - prog
			var attack: float = minf(1.0, prog * 22.0)
			var env: float = attack * rem * rem
			var freq: float = _v_f0[idx] + (_v_f1[idx] - _v_f0[idx]) * prog
			var vphase: float = _v_phase[idx] + freq * tau_inv_sr
			_v_phase[idx] = vphase
			var vkind: int = _v_kind[idx]
			var s_val: float
			if vkind == KIND_HARP:
				s_val = sin(vphase) * 0.78 + sin(vphase * 2.0) * 0.22
			elif vkind == KIND_WOOD:
				s_val = sin(vphase) * 0.65 + sin(vphase * 2.75) * 0.25 + sin(vphase * 4.1) * 0.10
			else:
				s_val = sin(vphase)
			mix += s_val * _v_amp[idx] * env
			idx -= 1
		var clamped: float = clampf(mix, -0.88, 0.88)
		_sfx_buf[i] = Vector2(clamped, clamped)

	_sfx_pb.push_buffer(_sfx_buf)
