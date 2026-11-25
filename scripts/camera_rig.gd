extends Camera2D
class_name CameraRig

## Cinematic Dynamic Camera Rig (1280x720 canvas_items vector viewport)
## - Frames the mossy forest floor cleanly in the lower 24% of the screen
## - Velocity-proportional horizontal look-ahead (+160px to +280px)
## - Dynamic altitude zoom-out when Moth ascends high (1.0 -> 0.86)
## - Tension zoom-in as the Shadow Ink Tide closes in
## - Organic multi-frequency trauma screen shake with exponential decay

const BASE_ZOOM: float = 1.0

var trauma: float = 0.0
var _shake_time: float = 0.0

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func reset_rig(start_pos: Vector2) -> void:
	trauma = 0.0
	offset = Vector2.ZERO
	position = start_pos
	zoom = Vector2(BASE_ZOOM, BASE_ZOOM)

func update_title_camera(title_cam_x: float) -> void:
	position = Vector2(title_cam_x + 130.0, -142.0)
	zoom = Vector2(BASE_ZOOM, BASE_ZOOM)
	offset = Vector2.ZERO

func update_gameplay_camera(dt: float, player_pos: Vector2, player_vx: float, is_moth: bool, tide_proximity: float) -> void:
	_shake_time += dt
	trauma = maxf(0.0, trauma - dt * 1.65)

	var look_ahead: float = clampf(165.0 + maxf(0.0, (player_vx - 460.0) * 0.36), 165.0, 290.0)
	var target_y: float = clampf(player_pos.y * 0.54 - 138.0, -310.0, -112.0)
	var target_pos: Vector2 = Vector2(player_pos.x + look_ahead, target_y)
	position = position.lerp(target_pos, minf(1.0, 8.8 * dt))

	var mag: float = trauma * trauma * 18.0
	var sx: float = (sin(_shake_time * 47.0) * 0.65 + cos(_shake_time * 83.0) * 0.35) * mag
	var sy: float = (cos(_shake_time * 59.0) * 0.65 + sin(_shake_time * 97.0) * 0.35) * mag * 0.85
	offset = Vector2(sx, sy)

	var alt_zoom_out: float = 0.0
	if is_moth and player_pos.y < -105.0:
		alt_zoom_out = clampf((-player_pos.y - 105.0) * 0.00052, 0.0, 0.14)
	var tide_zoom_in: float = maxf(0.0, (tide_proximity - 0.46) * 0.11)
	var rel_z: float = clampf(1.0 - alt_zoom_out + tide_zoom_in, 0.86, 1.11)
	var z: float = BASE_ZOOM * rel_z
	zoom = zoom.lerp(Vector2(z, z), minf(1.0, 4.4 * dt))
