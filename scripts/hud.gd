extends CanvasLayer
class_name GameHUD

## Minimalist Translucent In-Game HUD, Custom Vector 3-Form Totem Widget,
## Unified Settings & Pause Modal (Easy / Normal / Hard + Run Speed Slider + Natural Audio Mixer),
## and Cinematic Game Over Card.

signal resume_pressed
signal restart_pressed
signal title_pressed
signal form_clicked(form_id: int)
signal volumes_changed(master_v: float, amb_v: float, sfx_v: float)
signal gameplay_settings_changed(difficulty_mode: int, run_speed_scale: float)

const COL_FOX: Color = Color(0.36, 1.0, 0.74, 1.0)
const COL_MOTH: Color = Color(0.14, 0.92, 1.0, 1.0)
const COL_PANGOLIN: Color = Color(1.0, 0.66, 0.14, 1.0)

var _hud_root: Control
var _pause_panel: Control
var _gameover_panel: Control
var _totem_canvas: Control

var _lbl_best: Label
var _lbl_mode_badge: Label
var _lbl_tide_warn: Label
var _lbl_dist: Label
var _lbl_score: Label
var _lbl_flow: Label
var _flow_bar: ProgressBar
var _lbl_ability: Label
var _lbl_go_stats: Label
var _flow_fill_sb: StyleBoxFlat

var _lbl_modal_title: Label
var _btn_resume: Button
var _btn_restart: Button
var _btn_title: Button

var _diff_buttons: Array[Button] = []
var _diff_active_sbs: Array[StyleBoxFlat] = []
var _diff_inactive_sb: StyleBoxFlat
var _lbl_speed_val: Label
var _sl_speed: HSlider

var _sl_master: HSlider
var _sl_amb: HSlider
var _sl_sfx: HSlider

var _selected_diff: int = 1
var _selected_speed: float = 1.0
var _active_form: int = 0
var _ability_ratio: float = 1.0
var _form_buttons: Array[Button] = []
var _form_active_sbs: Array[StyleBoxFlat] = []
var _form_inactive_sb: StyleBoxFlat
var _last_hud_form: int = -1

func _ready() -> void:
	_build_ui()
	set_phase("title")

func sync_gameplay_settings(difficulty_mode: int, run_speed_scale: float) -> void:
	_selected_diff = clampi(difficulty_mode, 0, 2)
	_selected_speed = clampf(run_speed_scale, 0.60, 1.60)
	if _sl_speed != null:
		_sl_speed.set_value_no_signal(_selected_speed)
	_refresh_settings_ui()

func set_phase(phase: String) -> void:
	var is_title_settings: bool = phase == "settings"
	_hud_root.visible = phase == "playing" or phase == "paused"
	_pause_panel.visible = phase == "paused" or is_title_settings
	_gameover_panel.visible = phase == "gameover"
	if _lbl_modal_title != null:
		_lbl_modal_title.text = "GAME SETTINGS" if is_title_settings else "PAUSED & SETTINGS"
	if _btn_resume != null:
		_btn_resume.text = "DONE" if is_title_settings else "RESUME  [P]"
	if _btn_restart != null:
		_btn_restart.visible = not is_title_settings
	if _btn_title != null:
		_btn_title.visible = not is_title_settings

func update_hud(dist: int, best_dist: int, score: int, flow: int, flow_charge: float, active_form: int, tide_danger: float, ability_ratio: float = 1.0, ability_text: String = "PHANTOM DASH READY", mode_badge: String = "") -> void:
	_active_form = clampi(active_form, 0, 2)
	_ability_ratio = clampf(ability_ratio, 0.0, 1.0)

	_lbl_best.text = "BEST  %04d m" % maxi(best_dist, dist)
	if mode_badge != "" and _lbl_mode_badge != null:
		_lbl_mode_badge.text = mode_badge
	_lbl_tide_warn.visible = tide_danger > 0.50
	_lbl_dist.text = "%04d m" % dist
	_lbl_score.text = "SCORE  %d" % score
	_lbl_flow.text = "x%d FLOW" % flow
	_flow_bar.value = clampf(flow_charge, 0.04, 1.0) * 100.0

	var cols: Array[Color] = [COL_FOX, COL_MOTH, COL_PANGOLIN]
	var active_col: Color = cols[_active_form]
	_lbl_flow.modulate = active_col
	_flow_fill_sb.bg_color = active_col
	_lbl_ability.text = ability_text
	_lbl_ability.modulate = active_col

	if _last_hud_form != _active_form:
		_last_hud_form = _active_form
		for i in range(_form_buttons.size()):
			var b: Button = _form_buttons[i]
			var is_active: bool = i == _active_form
			var sb: StyleBoxFlat = _form_active_sbs[i] if is_active else _form_inactive_sb
			b.add_theme_stylebox_override("normal", sb)
			b.add_theme_stylebox_override("hover", sb)
			b.add_theme_color_override("font_color", cols[i] if is_active else Color(0.76, 0.84, 0.92, 0.88))

	if _totem_canvas != null:
		_totem_canvas.queue_redraw()

func show_game_over(dist: int, best_dist: int, score: int, smashed: int, max_flow: int, is_new: bool, cause: String, mode_label: String = "NORMAL") -> void:
	var rec_tag: String = "   ★ NEW RECORD" if is_new else ""
	_lbl_go_stats.text = "%s\n\nMode: %s  (%.2fx Speed)\nDistance: %d m%s   ·   Best: %d m\nScore: %d   ·   Shattered: %d   ·   Peak Flow: x%d\n\nPress SPACE or R for instant restart" % [cause, mode_label, _selected_speed, dist, rec_tag, best_dist, score, smashed, max_flow]
	set_phase("gameover")

func _on_form_button_pressed(idx: int) -> void:
	form_clicked.emit(idx)

func _on_diff_button_pressed(idx: int) -> void:
	_selected_diff = clampi(idx, 0, 2)
	_refresh_settings_ui()
	gameplay_settings_changed.emit(_selected_diff, _selected_speed)

func _on_speed_slider_changed(val: float) -> void:
	_selected_speed = clampf(val, 0.60, 1.60)
	_refresh_settings_ui()
	gameplay_settings_changed.emit(_selected_diff, _selected_speed)

func _speed_feel_tag(spd: float) -> String:
	if spd <= 0.72:
		return "Calm"
	elif spd <= 0.92:
		return "Relaxed"
	elif spd <= 1.08:
		return "Standard"
	elif spd <= 1.32:
		return "Fast"
	return "Turbo"

func _refresh_settings_ui() -> void:
	var diff_cols: Array[Color] = [COL_FOX, COL_MOTH, COL_PANGOLIN]
	for i in range(_diff_buttons.size()):
		var b: Button = _diff_buttons[i]
		var is_act: bool = i == _selected_diff
		var sb: StyleBoxFlat = _diff_active_sbs[i] if is_act else _diff_inactive_sb
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_color_override("font_color", Color(0.02, 0.08, 0.10) if is_act else Color(0.80, 0.88, 0.95))
	if _lbl_speed_val != null:
		_lbl_speed_val.text = "Run Speed:  %.2fx  (%s)" % [_selected_speed, _speed_feel_tag(_selected_speed)]
		_lbl_speed_val.add_theme_color_override("font_color", diff_cols[_selected_diff])

func _on_resume_pressed() -> void:
	resume_pressed.emit()

func _on_restart_pressed() -> void:
	restart_pressed.emit()

func _on_title_pressed() -> void:
	title_pressed.emit()

func _on_volume_slider_changed(_val: float) -> void:
	if _sl_master != null and _sl_amb != null and _sl_sfx != null:
		volumes_changed.emit(_sl_master.value, _sl_amb.value, _sl_sfx.value)

func _draw_totem_icons() -> void:
	if _totem_canvas == null:
		return
	var cols: Array[Color] = [COL_FOX, COL_MOTH, COL_PANGOLIN]
	for i in range(3):
		var cx: float = 54.0 + float(i) * 124.0
		var cy: float = 22.0
		var is_act: bool = i == _active_form
		var col: Color = cols[i] if is_act else Color(0.60, 0.70, 0.82, 0.65)

		if is_act:
			_totem_canvas.draw_circle(Vector2(cx, cy), 20.0, Color(col.r, col.g, col.b, 0.16))
			_totem_canvas.draw_arc(Vector2(cx, cy), 17.5, -PI * 0.5, -PI * 0.5 + TAU * _ability_ratio, 24, col, 2.5, true)
		else:
			_totem_canvas.draw_arc(Vector2(cx, cy), 16.0, 0.0, TAU, 20, Color(0.45, 0.56, 0.68, 0.32), 1.4, true)

		if i == 0:
			var fox_poly: PackedVector2Array = PackedVector2Array([
				Vector2(cx - 8.5, cy - 1.5),
				Vector2(cx - 7.0, cy - 10.0),
				Vector2(cx - 2.2, cy - 4.8),
				Vector2(cx + 2.2, cy - 4.8),
				Vector2(cx + 7.0, cy - 10.0),
				Vector2(cx + 8.5, cy - 1.5),
				Vector2(cx, cy + 9.5)
			])
			_totem_canvas.draw_colored_polygon(fox_poly, Color(col.r, col.g, col.b, 0.28 if is_act else 0.12))
			fox_poly.append(fox_poly[0])
			_totem_canvas.draw_polyline(fox_poly, col, 1.7, true)
		elif i == 1:
			var lw: PackedVector2Array = PackedVector2Array([
				Vector2(cx, cy - 1.5), Vector2(cx - 11.0, cy - 8.5), Vector2(cx - 10.0, cy + 1.5),
				Vector2(cx - 4.5, cy + 9.5), Vector2(cx, cy + 4.0)
			])
			var rw: PackedVector2Array = PackedVector2Array([
				Vector2(cx, cy - 1.5), Vector2(cx + 11.0, cy - 8.5), Vector2(cx + 10.0, cy + 1.5),
				Vector2(cx + 4.5, cy + 9.5), Vector2(cx, cy + 4.0)
			])
			_totem_canvas.draw_colored_polygon(lw, Color(col.r, col.g, col.b, 0.28 if is_act else 0.12))
			_totem_canvas.draw_colored_polygon(rw, Color(col.r, col.g, col.b, 0.28 if is_act else 0.12))
			lw.append(lw[0])
			rw.append(rw[0])
			_totem_canvas.draw_polyline(lw, col, 1.6, true)
			_totem_canvas.draw_polyline(rw, col, 1.6, true)
		else:
			_totem_canvas.draw_circle(Vector2(cx, cy), 8.5, Color(col.r, col.g, col.b, 0.24 if is_act else 0.10))
			_totem_canvas.draw_arc(Vector2(cx, cy), 8.5, 0.2, TAU - 0.3, 16, col, 1.9, true)
			_totem_canvas.draw_arc(Vector2(cx, cy), 4.6, 0.8, TAU - 0.6, 12, col, 1.5, true)

func _make_box(bg: Color, border: Color, radius: int = 6, border_w: int = 1) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

func _build_ui() -> void:
	# ---------------------------------------------------------
	# IN-GAME MINIMALIST TRANSLUCENT HUD (1280x720)
	# ---------------------------------------------------------
	_hud_root = Control.new()
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_root)

	var top_left: VBoxContainer = VBoxContainer.new()
	top_left.position = Vector2(28, 20)
	top_left.add_theme_constant_override("separation", 3)
	_hud_root.add_child(top_left)

	_lbl_best = Label.new()
	_lbl_best.add_theme_font_size_override("font_size", 17)
	_lbl_best.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	_lbl_best.add_theme_color_override("font_outline_color", Color(0.015, 0.03, 0.07, 0.92))
	_lbl_best.add_theme_constant_override("outline_size", 4)
	top_left.add_child(_lbl_best)

	_lbl_mode_badge = Label.new()
	_lbl_mode_badge.text = "NORMAL  ·  1.00x"
	_lbl_mode_badge.add_theme_font_size_override("font_size", 12)
	_lbl_mode_badge.add_theme_color_override("font_color", Color(0.74, 0.88, 0.98, 0.92))
	_lbl_mode_badge.add_theme_color_override("font_outline_color", Color(0.015, 0.03, 0.07, 0.90))
	_lbl_mode_badge.add_theme_constant_override("outline_size", 3)
	top_left.add_child(_lbl_mode_badge)

	_lbl_tide_warn = Label.new()
	_lbl_tide_warn.text = "SHADOW INK TIDE CLOSING IN"
	_lbl_tide_warn.add_theme_font_size_override("font_size", 13)
	_lbl_tide_warn.modulate = Color(0.84, 0.56, 1.0, 0.96)
	_lbl_tide_warn.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.06, 0.95))
	_lbl_tide_warn.add_theme_constant_override("outline_size", 3)
	_lbl_tide_warn.visible = false
	top_left.add_child(_lbl_tide_warn)

	var top_right: VBoxContainer = VBoxContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.offset_left = -260.0
	top_right.offset_top = 18.0
	top_right.offset_right = -28.0
	top_right.offset_bottom = 148.0
	top_right.add_theme_constant_override("separation", 2)
	_hud_root.add_child(top_right)

	_lbl_dist = Label.new()
	_lbl_dist.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_dist.add_theme_font_size_override("font_size", 34)
	_lbl_dist.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0))
	_lbl_dist.add_theme_color_override("font_outline_color", Color(0.015, 0.03, 0.07, 0.92))
	_lbl_dist.add_theme_constant_override("outline_size", 5)
	top_right.add_child(_lbl_dist)

	_lbl_score = Label.new()
	_lbl_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_score.add_theme_font_size_override("font_size", 14)
	_lbl_score.modulate = Color(0.88, 0.93, 0.98, 0.94)
	_lbl_score.add_theme_color_override("font_outline_color", Color(0.015, 0.03, 0.07, 0.85))
	_lbl_score.add_theme_constant_override("outline_size", 3)
	top_right.add_child(_lbl_score)

	_lbl_flow = Label.new()
	_lbl_flow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_flow.add_theme_font_size_override("font_size", 22)
	_lbl_flow.add_theme_color_override("font_outline_color", Color(0.015, 0.03, 0.07, 0.92))
	_lbl_flow.add_theme_constant_override("outline_size", 4)
	top_right.add_child(_lbl_flow)

	_flow_bar = ProgressBar.new()
	_flow_bar.custom_minimum_size = Vector2(160, 7)
	_flow_bar.show_percentage = false
	var flow_bg: StyleBoxFlat = StyleBoxFlat.new()
	flow_bg.bg_color = Color(0.06, 0.12, 0.20, 0.82)
	flow_bg.set_corner_radius_all(3)
	_flow_fill_sb = StyleBoxFlat.new()
	_flow_fill_sb.bg_color = COL_FOX
	_flow_fill_sb.set_corner_radius_all(3)
	_flow_bar.add_theme_stylebox_override("background", flow_bg)
	_flow_bar.add_theme_stylebox_override("fill", _flow_fill_sb)
	top_right.add_child(_flow_bar)

	var form_stack: VBoxContainer = VBoxContainer.new()
	form_stack.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	form_stack.offset_left = 28.0
	form_stack.offset_top = -126.0
	form_stack.offset_right = 440.0
	form_stack.offset_bottom = -22.0
	form_stack.add_theme_constant_override("separation", 5)
	_hud_root.add_child(form_stack)

	_totem_canvas = Control.new()
	_totem_canvas.custom_minimum_size = Vector2(380, 44)
	_totem_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_totem_canvas.draw.connect(_draw_totem_icons)
	form_stack.add_child(_totem_canvas)

	var form_row: HBoxContainer = HBoxContainer.new()
	form_row.add_theme_constant_override("separation", 10)
	form_stack.add_child(form_row)

	_form_inactive_sb = _make_box(Color(0.04, 0.08, 0.14, 0.72), Color(0.42, 0.54, 0.66, 0.42), 6, 1)
	_form_active_sbs = [
		_make_box(Color(0.04, 0.10, 0.16, 0.92), COL_FOX, 6, 2),
		_make_box(Color(0.04, 0.10, 0.16, 0.92), COL_MOTH, 6, 2),
		_make_box(Color(0.04, 0.10, 0.16, 0.92), COL_PANGOLIN, 6, 2)
	]
	var names: Array[String] = ["[1/J] Fox", "[2/K] Moth", "[3/L] Pangolin"]
	for i in range(3):
		var b: Button = Button.new()
		b.text = names[i]
		b.custom_minimum_size = Vector2(114, 32)
		b.add_theme_font_size_override("font_size", 13)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_form_button_pressed.bind(i))
		form_row.add_child(b)
		_form_buttons.append(b)

	_lbl_ability = Label.new()
	_lbl_ability.text = "PHANTOM DASH READY"
	_lbl_ability.add_theme_font_size_override("font_size", 12)
	_lbl_ability.add_theme_color_override("font_outline_color", Color(0.015, 0.03, 0.07, 0.90))
	_lbl_ability.add_theme_constant_override("outline_size", 3)
	form_stack.add_child(_lbl_ability)

	var quick_hint: Label = Label.new()
	quick_hint.text = "[M] Mute   ·   [P] Settings & Pause   ·   [R] Restart"
	quick_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quick_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	quick_hint.offset_left = -380.0
	quick_hint.offset_top = -46.0
	quick_hint.offset_right = -28.0
	quick_hint.offset_bottom = -22.0
	quick_hint.add_theme_font_size_override("font_size", 12)
	quick_hint.add_theme_color_override("font_outline_color", Color(0.015, 0.03, 0.07, 0.85))
	quick_hint.add_theme_constant_override("outline_size", 3)
	quick_hint.modulate = Color(0.78, 0.88, 0.95, 0.82)
	_hud_root.add_child(quick_hint)

	# ---------------------------------------------------------
	# UNIFIED TRANSLUCENT PAUSE & SETTINGS MODAL
	# (Difficulty Easy/Normal/Hard + Run Speed Slider + Audio Mixer)
	# ---------------------------------------------------------
	_pause_panel = ColorRect.new()
	_pause_panel.color = Color(0.015, 0.028, 0.065, 0.72)
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_pause_panel)

	var pcard: PanelContainer = PanelContainer.new()
	pcard.set_anchors_preset(Control.PRESET_CENTER)
	pcard.offset_left = -225.0
	pcard.offset_top = -255.0
	pcard.offset_right = 225.0
	pcard.offset_bottom = 255.0
	pcard.add_theme_stylebox_override("panel", _make_box(Color(0.04, 0.075, 0.135, 0.96), Color(0.36, 0.96, 0.74, 0.62), 10, 2))
	_pause_panel.add_child(pcard)

	var pbox: VBoxContainer = VBoxContainer.new()
	pbox.add_theme_constant_override("separation", 9)
	pcard.add_child(pbox)

	_lbl_modal_title = Label.new()
	_lbl_modal_title.text = "PAUSED & SETTINGS"
	_lbl_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_modal_title.add_theme_font_size_override("font_size", 24)
	_lbl_modal_title.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	pbox.add_child(_lbl_modal_title)

	# Difficulty Mode Selector (EASY / NORMAL / HARD)
	var diff_hdr: Label = Label.new()
	diff_hdr.text = "Difficulty Mode"
	diff_hdr.add_theme_font_size_override("font_size", 13)
	diff_hdr.add_theme_color_override("font_color", Color(0.84, 0.92, 0.98))
	pbox.add_child(diff_hdr)

	var diff_row: HBoxContainer = HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 8)
	pbox.add_child(diff_row)

	_diff_inactive_sb = _make_box(Color(0.07, 0.12, 0.20, 0.90), Color(0.42, 0.56, 0.70, 0.50), 6, 1)
	_diff_active_sbs = [
		_make_box(COL_FOX, Color(0.84, 1.0, 0.94), 6, 2),
		_make_box(COL_MOTH, Color(0.82, 0.98, 1.0), 6, 2),
		_make_box(COL_PANGOLIN, Color(1.0, 0.92, 0.72), 6, 2)
	]
	var diff_names: Array[String] = ["EASY", "NORMAL", "HARD"]
	for i in range(3):
		var db: Button = Button.new()
		db.text = diff_names[i]
		db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		db.custom_minimum_size = Vector2(0, 32)
		db.add_theme_font_size_override("font_size", 13)
		db.focus_mode = Control.FOCUS_NONE
		db.pressed.connect(_on_diff_button_pressed.bind(i))
		diff_row.add_child(db)
		_diff_buttons.append(db)

	# Run Speed Control Slider (0.60x .. 1.60x)
	var spd_box: VBoxContainer = VBoxContainer.new()
	spd_box.add_theme_constant_override("separation", 2)
	pbox.add_child(spd_box)

	_lbl_speed_val = Label.new()
	_lbl_speed_val.text = "Run Speed:  1.00x  (Standard)"
	_lbl_speed_val.add_theme_font_size_override("font_size", 13)
	spd_box.add_child(_lbl_speed_val)

	_sl_speed = HSlider.new()
	_sl_speed.min_value = 0.60
	_sl_speed.max_value = 1.60
	_sl_speed.step = 0.05
	_sl_speed.value = 1.00
	_sl_speed.focus_mode = Control.FOCUS_NONE
	_sl_speed.value_changed.connect(_on_speed_slider_changed)
	spd_box.add_child(_sl_speed)

	# Audio Mixer Sliders
	_sl_master = _add_slider_row(pbox, "Master Volume", 0.85)
	_sl_amb = _add_slider_row(pbox, "Natural Forest Ambience", 0.78)
	_sl_sfx = _add_slider_row(pbox, "Shapeshift & Wildlife SFX", 0.88)

	_btn_resume = Button.new()
	_btn_resume.text = "RESUME  [P]"
	_btn_resume.custom_minimum_size = Vector2(0, 36)
	_btn_resume.add_theme_font_size_override("font_size", 15)
	_btn_resume.focus_mode = Control.FOCUS_NONE
	_btn_resume.add_theme_stylebox_override("normal", _make_box(COL_FOX, Color(0.84, 1.0, 0.94), 6, 1))
	_btn_resume.add_theme_color_override("font_color", Color(0.02, 0.08, 0.10))
	_btn_resume.pressed.connect(_on_resume_pressed)
	pbox.add_child(_btn_resume)

	_btn_restart = Button.new()
	_btn_restart.text = "RESTART RUN  [R]"
	_btn_restart.custom_minimum_size = Vector2(0, 32)
	_btn_restart.add_theme_font_size_override("font_size", 13)
	_btn_restart.focus_mode = Control.FOCUS_NONE
	_btn_restart.add_theme_stylebox_override("normal", _make_box(Color(0.08, 0.14, 0.24, 0.94), Color(0.42, 0.56, 0.70, 0.65), 6, 1))
	_btn_restart.pressed.connect(_on_restart_pressed)
	pbox.add_child(_btn_restart)

	_btn_title = Button.new()
	_btn_title.text = "RETURN TO TITLE"
	_btn_title.custom_minimum_size = Vector2(0, 32)
	_btn_title.add_theme_font_size_override("font_size", 13)
	_btn_title.focus_mode = Control.FOCUS_NONE
	_btn_title.add_theme_stylebox_override("normal", _make_box(Color(0.08, 0.14, 0.24, 0.94), Color(0.42, 0.56, 0.70, 0.65), 6, 1))
	_btn_title.pressed.connect(_on_title_pressed)
	pbox.add_child(_btn_title)

	_refresh_settings_ui()

	# ---------------------------------------------------------
	# CINEMATIC GAME OVER SUMMARY MODAL
	# ---------------------------------------------------------
	_gameover_panel = ColorRect.new()
	_gameover_panel.color = Color(0.015, 0.025, 0.06, 0.76)
	_gameover_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_gameover_panel)

	var gcard: PanelContainer = PanelContainer.new()
	gcard.set_anchors_preset(Control.PRESET_CENTER)
	gcard.offset_left = -255.0
	gcard.offset_top = -152.0
	gcard.offset_right = 255.0
	gcard.offset_bottom = 152.0
	gcard.add_theme_stylebox_override("panel", _make_box(Color(0.038, 0.068, 0.125, 0.96), Color(0.36, 1.0, 0.74, 0.60), 10, 2))
	_gameover_panel.add_child(gcard)

	var gbox: VBoxContainer = VBoxContainer.new()
	gbox.add_theme_constant_override("separation", 14)
	gcard.add_child(gbox)

	var glbl: Label = Label.new()
	glbl.text = "RUN ENDED"
	glbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glbl.add_theme_font_size_override("font_size", 30)
	glbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	gbox.add_child(glbl)

	_lbl_go_stats = Label.new()
	_lbl_go_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_go_stats.add_theme_font_size_override("font_size", 15)
	_lbl_go_stats.add_theme_color_override("font_color", Color(0.86, 0.92, 0.98))
	gbox.add_child(_lbl_go_stats)

	var b_again: Button = Button.new()
	b_again.text = "PLAY AGAIN  [SPACE / R]"
	b_again.focus_mode = Control.FOCUS_NONE
	b_again.custom_minimum_size = Vector2(0, 42)
	b_again.add_theme_font_size_override("font_size", 17)
	b_again.add_theme_stylebox_override("normal", _make_box(COL_FOX, Color(0.84, 1.0, 0.94), 6, 1))
	b_again.add_theme_color_override("font_color", Color(0.02, 0.08, 0.10))
	b_again.pressed.connect(_on_restart_pressed)
	gbox.add_child(b_again)

func _add_slider_row(parent: VBoxContainer, title: String, init_val: float) -> HSlider:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	parent.add_child(row)
	var lbl: Label = Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.80, 0.88, 0.95))
	row.add_child(lbl)
	var sl: HSlider = HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.02
	sl.value = init_val
	sl.focus_mode = Control.FOCUS_NONE
	sl.value_changed.connect(_on_volume_slider_changed)
	row.add_child(sl)
	return sl
