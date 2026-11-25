extends Node2D
class_name VfxManager

## Zero-GC pooled procedural VFX renderer:
## - 0.12s bioluminescent morph particle-dissolve + dual energy rings + PointLight2D flashes
## - Fox mint-green paw sparks, wet water/mud splashes, glowing pawprints & Phantom Dash afterimages
## - Moth cyan wing-scale motes & wingbeat air-rings
## - Pangolin rolling magma sparks, rotating stone debris chunks & glowing ground fracture decals
## - Raindrop ground splash ripples

var particles: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var decals: Array[Dictionary] = []
var afterimages: Array[Dictionary] = []
var ripples: Array[Dictionary] = []
var flash_lights: Array[Dictionary] = []

var trauma: float = 0.0
var chromatic_pulse: float = 0.0
var _p_cursor: int = 0
var _r_cursor: int = 0
var _d_cursor: int = 0
var _a_cursor: int = 0
var _rip_cursor: int = 0
var _l_cursor: int = 0

func _ready() -> void:
	for _i in range(320):
		particles.append({"active": false, "pos": Vector2.ZERO, "vel": Vector2.ZERO, "life": 0.0, "max_life": 1.0, "size": 2.0, "color": Color.WHITE, "grav": 0.0, "is_debris": false, "rot": 0.0, "vrot": 0.0})
	for _i in range(24):
		rings.append({"active": false, "pos": Vector2.ZERO, "r": 6.0, "max_r": 60.0, "life": 0.0, "max_life": 0.25, "color": Color.WHITE})
	for _i in range(32):
		decals.append({"active": false, "pos": Vector2.ZERO, "life": 0.0, "max_life": 5.0, "color": Color(1.0, 0.62, 0.0), "kind": "fracture"})
	for _i in range(16):
		afterimages.append({"active": false, "pos": Vector2.ZERO, "life": 0.0, "max_life": 0.22, "dash": true})
	for _i in range(24):
		ripples.append({"active": false, "pos": Vector2.ZERO, "life": 0.0, "max_life": 0.34, "max_r": 10.0})

	var flash_tex: GradientTexture2D = _build_radial_light_texture()
	for _i in range(4):
		var lt: PointLight2D = PointLight2D.new()
		lt.texture = flash_tex
		lt.energy = 0.0
		lt.enabled = false
		add_child(lt)
		flash_lights.append({"node": lt, "life": 0.0, "max_life": 0.25, "peak": 1.5})

func _build_radial_light_texture() -> GradientTexture2D:
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0.92), Color(1, 1, 1, 0.28), Color(1, 1, 1, 0.0)])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 192
	tex.height = 192
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex

func reset_vfx() -> void:
	for p in particles:
		p["active"] = false
	for r in rings:
		r["active"] = false
	for d in decals:
		d["active"] = false
	for a in afterimages:
		a["active"] = false
	for rip in ripples:
		rip["active"] = false
	for fl in flash_lights:
		fl["life"] = 0.0
		var lt: PointLight2D = fl["node"]
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
	for i in range(22):
		var ang: float = (float(i) / 22.0) * TAU + randf_range(-0.3, 0.3)
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
	_spawn_decal(pos, Color(0.31, 1.0, 0.69), "pawprint", 1.5)

func emit_fox_afterimage(pos: Vector2, is_dash: bool = true) -> void:
	var a: Dictionary = afterimages[_a_cursor]
	_a_cursor = (_a_cursor + 1) % afterimages.size()
	a["active"] = true
	a["pos"] = pos
	a["life"] = 0.22
	a["max_life"] = 0.22
	a["dash"] = is_dash

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
	_spawn_decal(Vector2(pos.x, ground_y), Color(1.0, 0.62, 0.0), "fracture", 6.5)
	for i in range(26):
		var ang: float = randf_range(-2.1, 0.5)
		var spd: float = randf_range(180.0, 560.0)
		var is_stone: bool = i % 3 == 0
		var col: Color = Color(0.18, 0.21, 0.28) if is_stone else (Color(1.0, 0.62, 0.0) if i % 2 == 0 else Color(1.0, 0.84, 0.45))
		_spawn_particle(pos, Vector2(cos(ang), sin(ang)) * spd + Vector2(120.0, -80.0), randf_range(4.5, 8.0) if is_stone else randf_range(2.6, 5.0), randf_range(0.42, 0.88), col, 960.0, is_stone)

func emit_rain_ripple(pos: Vector2) -> void:
	var rip: Dictionary = ripples[_rip_cursor]
	_rip_cursor = (_rip_cursor + 1) % ripples.size()
	rip["active"] = true
	rip["pos"] = pos
	rip["life"] = 0.32
	rip["max_life"] = 0.32
	rip["max_r"] = randf_range(7.0, 12.0)

func update_vfx(dt: float) -> void:
	trauma = maxf(0.0, trauma - dt * 1.9)
	chromatic_pulse = maxf(0.0, chromatic_pulse - dt * 6.5)

	for p in particles:
		if not bool(p["active"]):
			continue
		var life: float = float(p["life"]) - dt
		p["life"] = life
		if life <= 0.0:
			p["active"] = false
			continue
		var vel: Vector2 = p["vel"]
		vel.y += float(p["grav"]) * dt
		p["vel"] = vel
		var pos: Vector2 = p["pos"]
		p["pos"] = pos + vel * dt
		p["rot"] = float(p["rot"]) + float(p["vrot"]) * dt

	for r in rings:
		if not bool(r["active"]):
			continue
		var life: float = float(r["life"]) - dt
		r["life"] = life
		if life <= 0.0:
			r["active"] = false
			continue
		var max_l: float = maxf(0.001, float(r["max_life"]))
		var prog: float = 1.0 - life / max_l
		var max_r: float = float(r["max_r"])
		r["r"] = 6.0 + (max_r - 6.0) * (1.0 - pow(1.0 - prog, 3.0))

	for d in decals:
		if not bool(d["active"]):
			continue
		var life: float = float(d["life"]) - dt
		d["life"] = life
		if life <= 0.0:
			d["active"] = false

	for a in afterimages:
		if not bool(a["active"]):
			continue
		var life: float = float(a["life"]) - dt
		a["life"] = life
		if life <= 0.0:
			a["active"] = false

	for rip in ripples:
		if not bool(rip["active"]):
			continue
		var life: float = float(rip["life"]) - dt
		rip["life"] = life
		if life <= 0.0:
			rip["active"] = false

	for fl in flash_lights:
		var life: float = float(fl["life"])
		if life <= 0.0:
			continue
		life = maxf(0.0, life - dt)
		fl["life"] = life
		var lt: PointLight2D = fl["node"]
		if life <= 0.0:
			lt.enabled = false
			lt.energy = 0.0
		else:
			var t: float = life / maxf(0.001, float(fl["max_life"]))
			lt.energy = float(fl["peak"]) * t * t

	queue_redraw()

func _spawn_flash_light(pos: Vector2, col: Color, peak_energy: float, tex_scale: float, dur: float) -> void:
	if flash_lights.is_empty():
		return
	var fl: Dictionary = flash_lights[_l_cursor]
	_l_cursor = (_l_cursor + 1) % flash_lights.size()
	var lt: PointLight2D = fl["node"]
	lt.position = pos
	lt.color = col
	lt.texture_scale = tex_scale
	lt.energy = peak_energy
	lt.enabled = true
	fl["life"] = dur
	fl["max_life"] = dur
	fl["peak"] = peak_energy

func _spawn_particle(pos: Vector2, vel: Vector2, size: float, life: float, col: Color, grav: float, is_debris: bool) -> void:
	var p: Dictionary = particles[_p_cursor]
	_p_cursor = (_p_cursor + 1) % particles.size()
	p["active"] = true
	p["pos"] = pos
	p["vel"] = vel
	p["size"] = size
	p["life"] = life
	p["max_life"] = life
	p["color"] = col
	p["grav"] = grav
	p["is_debris"] = is_debris
	p["rot"] = randf_range(0.0, TAU)
	p["vrot"] = randf_range(-12.0, 12.0)

func _spawn_ring(pos: Vector2, max_r: float, life: float, col: Color) -> void:
	var r: Dictionary = rings[_r_cursor]
	_r_cursor = (_r_cursor + 1) % rings.size()
	r["active"] = true
	r["pos"] = pos
	r["r"] = 6.0
	r["max_r"] = max_r
	r["life"] = life
	r["max_life"] = life
	r["color"] = col

func _spawn_decal(pos: Vector2, col: Color, kind: String, life: float) -> void:
	var d: Dictionary = decals[_d_cursor]
	_d_cursor = (_d_cursor + 1) % decals.size()
	d["active"] = true
	d["pos"] = pos
	d["life"] = life
	d["max_life"] = life
	d["color"] = col
	d["kind"] = kind

func _draw() -> void:
	# Ground decals (magma fractures & glowing Fox pawprints)
	for d in decals:
		if not bool(d["active"]):
			continue
		var c: Color = d["color"]
		c.a = clampf(float(d["life"]) / 1.5, 0.0, 0.85)
		var p: Vector2 = d["pos"]
		if String(d["kind"]) == "fracture":
			draw_polyline(PackedVector2Array([p + Vector2(-28, 3), p + Vector2(-8, 9), p + Vector2(10, 2), p + Vector2(30, 7)]), c, 2.3, true)
			draw_line(p + Vector2(-8, 9), p + Vector2(-16, 18), c, 1.8, true)
			draw_line(p + Vector2(8, 3), p + Vector2(16, 16), c, 1.8, true)
		else:
			draw_line(p + Vector2(-4, 1.5), p + Vector2(4, 1.5), c, 2.2, true)

	# Raindrop splash ripples
	for rip in ripples:
		if not bool(rip["active"]):
			continue
		var t: float = 1.0 - float(rip["life"]) / maxf(0.001, float(rip["max_life"]))
		var r: float = 2.0 + float(rip["max_r"]) * t
		var c: Color = Color(0.7, 0.88, 0.98, (1.0 - t) * 0.42)
		var p: Vector2 = rip["pos"]
		draw_line(p + Vector2(-r, -1.0), p + Vector2(r, -1.0), c, 1.2, true)

	# Fox Phantom Dash translucent mint-outlined afterimages
	for a in afterimages:
		if not bool(a["active"]):
			continue
		var ratio: float = clampf(float(a["life"]) / maxf(0.001, float(a["max_life"])), 0.0, 1.0)
		var p: Vector2 = a["pos"]
		var dy: float = 6.0 if bool(a["dash"]) else 0.0
		var poly: PackedVector2Array = PackedVector2Array([
			p + Vector2(-24, -14 + dy), p + Vector2(10, -23 + dy), p + Vector2(18, -30 + dy),
			p + Vector2(22, -22 + dy), p + Vector2(30, -17 + dy), p + Vector2(18, -12 + dy), p + Vector2(-20, -10 + dy)
		])
		draw_colored_polygon(poly, Color(0.31, 1.0, 0.69, ratio * 0.14))
		draw_polyline(poly, Color(0.31, 1.0, 0.69, ratio * 0.65), 1.5, true)
		draw_line(p + Vector2(-22, -13 + dy), p + Vector2(-58, -14 + dy), Color(0.31, 1.0, 0.69, ratio * 0.55), 3.0, true)

	# Shockwave rings
	for r in rings:
		if not bool(r["active"]):
			continue
		var c: Color = r["color"]
		c.a = clampf(float(r["life"]) / maxf(0.001, float(r["max_life"])), 0.0, 0.85)
		draw_arc(r["pos"], float(r["r"]), 0.0, TAU, 32, c, 2.6 * c.a, true)

	# Pooled sparks, motes & rotating stone debris
	for p in particles:
		if not bool(p["active"]):
			continue
		var ratio: float = clampf(float(p["life"]) / maxf(0.001, float(p["max_life"])), 0.0, 1.0)
		var c: Color = p["color"]
		c.a = ratio
		var pos: Vector2 = p["pos"]
		if bool(p["is_debris"]):
			var s: float = float(p["size"]) * 0.5
			draw_set_transform(pos, float(p["rot"]), Vector2.ONE)
			draw_rect(Rect2(-s, -s * 0.8, s * 2.0, s * 1.6), c)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_circle(pos, maxf(1.0, float(p["size"]) * ratio), c)
