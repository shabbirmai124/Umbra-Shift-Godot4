extends Node2D
class_name VfxManager

## High-Performance Zero-GC Pooled Procedural VFX Renderer (SoA Dense Pools)
## - Dense swap-remove active pools: only iterates actually-active particles/rings/decals
## - Zero per-frame Dictionary lookups or PackedVector2Array heap allocations

const MAX_PARTICLES: int = 280
const MAX_RINGS: int = 24
const MAX_DECALS: int = 32
const MAX_AFTERIMAGES: int = 16
const MAX_RIPPLES: int = 24

var trauma: float = 0.0
var chromatic_pulse: float = 0.0

# Dense active particle SoA pool [0 .. _p_count - 1]
var _p_count: int = 0
var _p_pos: PackedVector2Array = PackedVector2Array()
var _p_vel: PackedVector2Array = PackedVector2Array()
var _p_life: PackedFloat32Array = PackedFloat32Array()
var _p_max_life: PackedFloat32Array = PackedFloat32Array()
var _p_size: PackedFloat32Array = PackedFloat32Array()
var _p_grav: PackedFloat32Array = PackedFloat32Array()
var _p_rot: PackedFloat32Array = PackedFloat32Array()
var _p_vrot: PackedFloat32Array = PackedFloat32Array()
var _p_col: PackedColorArray = PackedColorArray()
var _p_debris: PackedByteArray = PackedByteArray()

# Dense active rings SoA pool
var _r_count: int = 0
var _r_pos: PackedVector2Array = PackedVector2Array()
var _r_cur: PackedFloat32Array = PackedFloat32Array()
var _r_max: PackedFloat32Array = PackedFloat32Array()
var _r_life: PackedFloat32Array = PackedFloat32Array()
var _r_max_life: PackedFloat32Array = PackedFloat32Array()
var _r_col: PackedColorArray = PackedColorArray()

# Dense active decals SoA pool (kind: 0=pawprint, 1=fracture)
var _d_count: int = 0
var _d_pos: PackedVector2Array = PackedVector2Array()
var _d_life: PackedFloat32Array = PackedFloat32Array()
var _d_col: PackedColorArray = PackedColorArray()
var _d_kind: PackedByteArray = PackedByteArray()

# Dense active Fox afterimages SoA pool
var _a_count: int = 0
var _a_pos: PackedVector2Array = PackedVector2Array()
var _a_life: PackedFloat32Array = PackedFloat32Array()
var _a_max_life: PackedFloat32Array = PackedFloat32Array()
var _a_dash: PackedByteArray = PackedByteArray()

# Dense active rain ripples SoA pool
var _rip_count: int = 0
var _rip_pos: PackedVector2Array = PackedVector2Array()
var _rip_life: PackedFloat32Array = PackedFloat32Array()
var _rip_max_life: PackedFloat32Array = PackedFloat32Array()
var _rip_max_r: PackedFloat32Array = PackedFloat32Array()

# Pooled PointLight2D flashes
var _flash_nodes: Array[PointLight2D] = []
var _flash_life: PackedFloat32Array = PackedFloat32Array()
var _flash_max_life: PackedFloat32Array = PackedFloat32Array()
var _flash_peak: PackedFloat32Array = PackedFloat32Array()
var _l_cursor: int = 0

# Reusable polygon buffers
var _frac_line: PackedVector2Array = PackedVector2Array()
var _after_poly: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	_p_pos.resize(MAX_PARTICLES)
	_p_vel.resize(MAX_PARTICLES)
	_p_life.resize(MAX_PARTICLES)
	_p_max_life.resize(MAX_PARTICLES)
	_p_size.resize(MAX_PARTICLES)
	_p_grav.resize(MAX_PARTICLES)
	_p_rot.resize(MAX_PARTICLES)
	_p_vrot.resize(MAX_PARTICLES)
	_p_col.resize(MAX_PARTICLES)
	_p_debris.resize(MAX_PARTICLES)

	_r_pos.resize(MAX_RINGS)
	_r_cur.resize(MAX_RINGS)
	_r_max.resize(MAX_RINGS)
	_r_life.resize(MAX_RINGS)
	_r_max_life.resize(MAX_RINGS)
	_r_col.resize(MAX_RINGS)

	_d_pos.resize(MAX_DECALS)
	_d_life.resize(MAX_DECALS)
	_d_col.resize(MAX_DECALS)
	_d_kind.resize(MAX_DECALS)

	_a_pos.resize(MAX_AFTERIMAGES)
	_a_life.resize(MAX_AFTERIMAGES)
	_a_max_life.resize(MAX_AFTERIMAGES)
	_a_dash.resize(MAX_AFTERIMAGES)

	_rip_pos.resize(MAX_RIPPLES)
	_rip_life.resize(MAX_RIPPLES)
	_rip_max_life.resize(MAX_RIPPLES)
	_rip_max_r.resize(MAX_RIPPLES)

	_frac_line.resize(4)
	_after_poly.resize(7)

	var flash_tex: GradientTexture2D = _build_radial_light_texture()
	_flash_life.resize(4)
	_flash_max_life.resize(4)
	_flash_peak.resize(4)
	for i in range(4):
		var lt: PointLight2D = PointLight2D.new()
		lt.texture = flash_tex
		lt.energy = 0.0
		lt.enabled = false
		lt.range_item_cull_mask = 1
		add_child(lt)
		_flash_nodes.append(lt)
		_flash_life[i] = 0.0
		_flash_max_life[i] = 0.25
		_flash_peak[i] = 1.5

func _build_radial_light_texture() -> GradientTexture2D:
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0.92), Color(1, 1, 1, 0.28), Color(1, 1, 1, 0.0)])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex

func reset_vfx() -> void:
	_p_count = 0
	_r_count = 0
	_d_count = 0
	_a_count = 0
	_rip_count = 0
	for i in range(_flash_nodes.size()):
		_flash_life[i] = 0.0
		var lt: PointLight2D = _flash_nodes[i]
		lt.enabled = false
		lt.energy = 0.0
	trauma = 0.0
	chromatic_pulse = 0.0
	queue_redraw()

func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)

func emit_morph_burst(pos: Vector2, old_col: Color, new_col: Color) -> void:
	chromatic_pulse = 1.0
	add_trauma(0.18)
	_spawn_flash_light(pos, new_col, 1.9, 1.55, 0.22)
	_spawn_ring(pos, 74.0, 0.24, new_col)
	_spawn_ring(pos, 48.0, 0.16, old_col)
	for i in range(20):
		var ang: float = (float(i) / 20.0) * TAU + randf_range(-0.3, 0.3)
		var spd: float = randf_range(95.0, 310.0)
		_spawn_particle(pos, Vector2(cos(ang), sin(ang)) * spd, randf_range(2.2, 5.2), randf_range(0.24, 0.45), new_col if i % 2 == 0 else old_col, 90.0, false)

func emit_fox_sparks(pos: Vector2, count: int = 5) -> void:
	for i in range(count):
		var col: Color = Color(0.8, 1.0, 0.92) if i % 3 == 0 else Color(0.31, 1.0, 0.69)
		_spawn_particle(pos, Vector2(randf_range(-210.0, -75.0), randf_range(-125.0, -35.0)), randf_range(1.8, 3.6), randf_range(0.22, 0.42), col, 240.0, false)

func emit_double_jump_burst(pos: Vector2) -> void:
	_spawn_ring(pos, 42.0, 0.2, Color(0.31, 1.0, 0.69))
	_spawn_flash_light(pos, Color(0.31, 1.0, 0.69), 1.35, 1.15, 0.16)
	emit_fox_sparks(pos, 10)

func emit_pawprint(pos: Vector2) -> void:
	_spawn_decal(pos, Color(0.31, 1.0, 0.69), 0, 1.5)

func emit_fox_afterimage(pos: Vector2, is_dash: bool = true) -> void:
	var idx: int = _a_count if _a_count < MAX_AFTERIMAGES else 0
	if _a_count < MAX_AFTERIMAGES:
		_a_count += 1
	_a_pos[idx] = pos
	_a_life[idx] = 0.22
	_a_max_life[idx] = 0.22
	_a_dash[idx] = 1 if is_dash else 0

func emit_landing_splash(pos: Vector2, accent: Color, heavy: bool = false) -> void:
	var count: int = 12 if heavy else 7
	for i in range(count):
		var side: float = randf_range(-1.0, 1.0)
		var col: Color = Color(0.62, 0.84, 0.95) if i % 2 == 0 else accent
		_spawn_particle(pos + Vector2(side * 10.0, -2.0), Vector2(side * randf_range(75.0, 180.0) - 40.0, randf_range(-210.0, -75.0)), randf_range(2.0, 4.2), randf_range(0.28, 0.5), col, 580.0, false)

func emit_moth_flutter(pos: Vector2) -> void:
	_spawn_ring(pos, 44.0, 0.26, Color(0.0, 0.9, 1.0))
	_spawn_flash_light(pos, Color(0.0, 0.9, 1.0), 1.25, 1.15, 0.18)
	for i in range(8):
		var col: Color = Color(0.0, 0.9, 1.0) if i % 2 == 0 else Color(0.7, 0.97, 1.0)
		_spawn_particle(pos, Vector2(randf_range(-130.0, -40.0), randf_range(20.0, 95.0)), randf_range(1.8, 3.8), randf_range(0.42, 0.85), col, -20.0, false)

func emit_moth_scale_mote(pos: Vector2) -> void:
	_spawn_particle(pos + Vector2(randf_range(-10.0, 6.0), randf_range(-12.0, 12.0)), Vector2(randf_range(-85.0, -35.0), randf_range(-25.0, 25.0)), randf_range(1.6, 3.2), randf_range(0.45, 0.85), Color(0.0, 0.9, 1.0), -14.0, false)

func emit_pangolin_roll_spark(pos: Vector2) -> void:
	var col: Color = Color(1.0, 0.62, 0.0) if randf() < 0.65 else Color(1.0, 0.34, 0.0)
	_spawn_particle(pos + Vector2(-8.0, -2.0), Vector2(randf_range(-240.0, -110.0), randf_range(-125.0, -40.0)), randf_range(2.0, 4.0), randf_range(0.24, 0.48), col, 490.0, false)

func emit_smash_debris(pos: Vector2, ground_y: float) -> void:
	add_trauma(0.56)
	_spawn_flash_light(pos, Color(1.0, 0.56, 0.05), 2.45, 2.2, 0.32)
	_spawn_ring(pos, 98.0, 0.28, Color(1.0, 0.62, 0.0))
	_spawn_decal(Vector2(pos.x, ground_y), Color(1.0, 0.62, 0.0), 1, 6.5)
	for i in range(24):
		var ang: float = randf_range(-2.1, 0.5)
		var spd: float = randf_range(180.0, 560.0)
		var is_stone: bool = i % 3 == 0
		var col: Color = Color(0.18, 0.21, 0.28) if is_stone else (Color(1.0, 0.62, 0.0) if i % 2 == 0 else Color(1.0, 0.84, 0.45))
		_spawn_particle(pos, Vector2(cos(ang), sin(ang)) * spd + Vector2(120.0, -80.0), randf_range(4.5, 8.0) if is_stone else randf_range(2.6, 5.0), randf_range(0.42, 0.88), col, 960.0, is_stone)

func emit_rain_ripple(pos: Vector2) -> void:
	var idx: int = _rip_count if _rip_count < MAX_RIPPLES else 0
	if _rip_count < MAX_RIPPLES:
		_rip_count += 1
	_rip_pos[idx] = pos
	_rip_life[idx] = 0.32
	_rip_max_life[idx] = 0.32
	_rip_max_r[idx] = randf_range(7.0, 12.0)

func update_vfx(dt: float) -> void:
	trauma = maxf(0.0, trauma - dt * 1.9)
	chromatic_pulse = maxf(0.0, chromatic_pulse - dt * 6.5)

	var i: int = _p_count - 1
	while i >= 0:
		var life: float = _p_life[i] - dt
		if life <= 0.0:
			var last: int = _p_count - 1
			if i != last:
				_p_pos[i] = _p_pos[last]
				_p_vel[i] = _p_vel[last]
				_p_life[i] = _p_life[last]
				_p_max_life[i] = _p_max_life[last]
				_p_size[i] = _p_size[last]
				_p_grav[i] = _p_grav[last]
				_p_rot[i] = _p_rot[last]
				_p_vrot[i] = _p_vrot[last]
				_p_col[i] = _p_col[last]
				_p_debris[i] = _p_debris[last]
			_p_count = last
		else:
			_p_life[i] = life
			var vel: Vector2 = _p_vel[i]
			vel.y += _p_grav[i] * dt
			_p_vel[i] = vel
			_p_pos[i] = _p_pos[i] + vel * dt
			_p_rot[i] = _p_rot[i] + _p_vrot[i] * dt
		i -= 1

	i = _r_count - 1
	while i >= 0:
		var life: float = _r_life[i] - dt
		if life <= 0.0:
			var last: int = _r_count - 1
			if i != last:
				_r_pos[i] = _r_pos[last]
				_r_cur[i] = _r_cur[last]
				_r_max[i] = _r_max[last]
				_r_life[i] = _r_life[last]
				_r_max_life[i] = _r_max_life[last]
				_r_col[i] = _r_col[last]
			_r_count = last
		else:
			_r_life[i] = life
			var rem: float = life / _r_max_life[i]
			_r_cur[i] = 6.0 + (_r_max[i] - 6.0) * (1.0 - rem * rem * rem)
		i -= 1

	i = _d_count - 1
	while i >= 0:
		var life: float = _d_life[i] - dt
		if life <= 0.0:
			var last: int = _d_count - 1
			if i != last:
				_d_pos[i] = _d_pos[last]
				_d_life[i] = _d_life[last]
				_d_col[i] = _d_col[last]
				_d_kind[i] = _d_kind[last]
			_d_count = last
		else:
			_d_life[i] = life
		i -= 1

	i = _a_count - 1
	while i >= 0:
		var life: float = _a_life[i] - dt
		if life <= 0.0:
			var last: int = _a_count - 1
			if i != last:
				_a_pos[i] = _a_pos[last]
				_a_life[i] = _a_life[last]
				_a_max_life[i] = _a_max_life[last]
				_a_dash[i] = _a_dash[last]
			_a_count = last
		else:
			_a_life[i] = life
		i -= 1

	i = _rip_count - 1
	while i >= 0:
		var life: float = _rip_life[i] - dt
		if life <= 0.0:
			var last: int = _rip_count - 1
			if i != last:
				_rip_pos[i] = _rip_pos[last]
				_rip_life[i] = _rip_life[last]
				_rip_max_life[i] = _rip_max_life[last]
				_rip_max_r[i] = _rip_max_r[last]
			_rip_count = last
		else:
			_rip_life[i] = life
		i -= 1

	for fi in range(_flash_nodes.size()):
		var fl: float = _flash_life[fi]
		if fl <= 0.0:
			continue
		fl = maxf(0.0, fl - dt)
		_flash_life[fi] = fl
		var lt: PointLight2D = _flash_nodes[fi]
		if fl <= 0.0:
			lt.enabled = false
			lt.energy = 0.0
		else:
			var t: float = fl / _flash_max_life[fi]
			lt.energy = _flash_peak[fi] * t * t

	if _p_count > 0 or _r_count > 0 or _d_count > 0 or _a_count > 0 or _rip_count > 0:
		queue_redraw()

func _spawn_flash_light(pos: Vector2, col: Color, peak_energy: float, tex_scale: float, dur: float) -> void:
	if _flash_nodes.is_empty():
		return
	var idx: int = _l_cursor
	_l_cursor = (_l_cursor + 1) % _flash_nodes.size()
	var lt: PointLight2D = _flash_nodes[idx]
	lt.position = pos
	lt.color = col
	lt.texture_scale = tex_scale
	lt.energy = peak_energy
	lt.enabled = true
	_flash_life[idx] = dur
	_flash_max_life[idx] = maxf(0.001, dur)
	_flash_peak[idx] = peak_energy

func _spawn_particle(pos: Vector2, vel: Vector2, size: float, life: float, col: Color, grav: float, is_debris: bool) -> void:
	var idx: int = _p_count if _p_count < MAX_PARTICLES else (randi() % MAX_PARTICLES)
	if _p_count < MAX_PARTICLES:
		_p_count += 1
	_p_pos[idx] = pos
	_p_vel[idx] = vel
	_p_size[idx] = size
	_p_life[idx] = life
	_p_max_life[idx] = maxf(0.001, life)
	_p_col[idx] = col
	_p_grav[idx] = grav
	_p_debris[idx] = 1 if is_debris else 0
	_p_rot[idx] = randf_range(0.0, TAU)
	_p_vrot[idx] = randf_range(-12.0, 12.0)

func _spawn_ring(pos: Vector2, max_r: float, life: float, col: Color) -> void:
	var idx: int = _r_count if _r_count < MAX_RINGS else 0
	if _r_count < MAX_RINGS:
		_r_count += 1
	_r_pos[idx] = pos
	_r_cur[idx] = 6.0
	_r_max[idx] = max_r
	_r_life[idx] = life
	_r_max_life[idx] = maxf(0.001, life)
	_r_col[idx] = col

func _spawn_decal(pos: Vector2, col: Color, kind: int, life: float) -> void:
	var idx: int = _d_count if _d_count < MAX_DECALS else 0
	if _d_count < MAX_DECALS:
		_d_count += 1
	_d_pos[idx] = pos
	_d_life[idx] = life
	_d_col[idx] = col
	_d_kind[idx] = kind

func _draw() -> void:
	for i in range(_d_count):
		var c: Color = _d_col[i]
		c.a = clampf(_d_life[i] / 1.5, 0.0, 0.85)
		var p: Vector2 = _d_pos[i]
		if _d_kind[i] == 1:
			_frac_line[0] = p + Vector2(-28.0, 3.0)
			_frac_line[1] = p + Vector2(-8.0, 9.0)
			_frac_line[2] = p + Vector2(10.0, 2.0)
			_frac_line[3] = p + Vector2(30.0, 7.0)
			draw_polyline(_frac_line, c, 2.3, true)
			draw_line(p + Vector2(-8.0, 9.0), p + Vector2(-16.0, 18.0), c, 1.8, true)
			draw_line(p + Vector2(8.0, 3.0), p + Vector2(16.0, 16.0), c, 1.8, true)
		else:
			draw_line(p + Vector2(-4.0, 1.5), p + Vector2(4.0, 1.5), c, 2.2, true)

	for i in range(_rip_count):
		var t: float = 1.0 - _rip_life[i] / _rip_max_life[i]
		var r: float = 2.0 + _rip_max_r[i] * t
		var p: Vector2 = _rip_pos[i]
		draw_line(p + Vector2(-r, -1.0), p + Vector2(r, -1.0), Color(0.7, 0.88, 0.98, (1.0 - t) * 0.42), 1.2, true)

	for i in range(_a_count):
		var ratio: float = clampf(_a_life[i] / _a_max_life[i], 0.0, 1.0)
		var p: Vector2 = _a_pos[i]
		var dy: float = 6.0 if _a_dash[i] == 1 else 0.0
		_after_poly[0] = p + Vector2(-24.0, -14.0 + dy)
		_after_poly[1] = p + Vector2(10.0, -23.0 + dy)
		_after_poly[2] = p + Vector2(18.0, -30.0 + dy)
		_after_poly[3] = p + Vector2(22.0, -22.0 + dy)
		_after_poly[4] = p + Vector2(30.0, -17.0 + dy)
		_after_poly[5] = p + Vector2(18.0, -12.0 + dy)
		_after_poly[6] = p + Vector2(-20.0, -10.0 + dy)
		draw_colored_polygon(_after_poly, Color(0.31, 1.0, 0.69, ratio * 0.14))
		draw_polyline(_after_poly, Color(0.31, 1.0, 0.69, ratio * 0.65), 1.5, true)
		draw_line(p + Vector2(-22.0, -13.0 + dy), p + Vector2(-58.0, -14.0 + dy), Color(0.31, 1.0, 0.69, ratio * 0.55), 3.0, true)

	for i in range(_r_count):
		var c: Color = _r_col[i]
		c.a = clampf(_r_life[i] / _r_max_life[i], 0.0, 0.85)
		draw_arc(_r_pos[i], _r_cur[i], 0.0, TAU, 24, c, 2.6 * c.a, true)

	for i in range(_p_count):
		var ratio: float = clampf(_p_life[i] / _p_max_life[i], 0.0, 1.0)
		var c: Color = _p_col[i]
		c.a = ratio
		var pos: Vector2 = _p_pos[i]
		if _p_debris[i] == 1:
			var s: float = _p_size[i] * 0.5
			draw_set_transform(pos, _p_rot[i], Vector2.ONE)
			draw_rect(Rect2(-s, -s * 0.8, s * 2.0, s * 1.6), c)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_circle(pos, maxf(1.0, _p_size[i] * ratio), c)
