extends CanvasLayer
class_name GameHUD

## Polished procedural UI for UMBRA SHIFT (100% code-authored StyleBoxFlat + Control nodes)
## - Live Title Screen with sleek compact PLAY CTA & visual control badges (open clearing for hero showcase)
## - Minimalist In-Game HUD: Top-Left Personal Best + Tide warning, Top-Right Distance/Score/xFLOW,
##   Bottom-Left translucent 3-Form Indicator (Mint Fox, Cyan Moth, Amber Pangolin) with active glow
## - Pause & Cinematic Game Over summary cards with ConfigFile (user://highscore.cfg) persistence

signal play_pressed
signal resume_pressed
signal restart_pressed
signal title_pressed
signal form_clicked(form_id: int)

const SAVE_PATH: String = "user://highscore.cfg"
const COL_FOX: Color = Color(0.31, 1.0, 0.69, 1.0)
const COL_MOTH: Color = Color(0.0, 0.9, 1.0, 1.0)
const COL_PANGOLIN: Color = Color(1.0, 0.62, 0.0, 1.0)

var best_distance: int = 0
var best_score: int = 0

var _title_panel: Control
var _hud_root: Control
var _pause_panel: Control
var _gameover_panel: Control

var _lbl_title_best: Label
var _lbl_best: Label
var _lbl_tide_warn: Label
var _lbl_dist: Label
var _lbl_score: Label
var _lbl_flow: Label
var _flow_bar: ProgressBar
var _lbl_ability: Label
var _ability_bar: ProgressBar
var _lbl_go_stats: Label
var _form_buttons: Array[Button] = []
var _flow_fill_sb: StyleBoxFlat
var _form_active_sbs: Array[StyleBoxFlat] = []
var _form_inactive_sb: StyleBoxFlat
var _last_hud_form: int = -1

func _ready() -> void:
	load_high_score()
	_build_ui()
	set_phase("title")

func load_high_score() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_distance = int(cfg.get_value("records", "best_distance", 0))
		best_score = int(cfg.get_value("records", "best_score", 0))

func save_high_score(dist: int, score: int) -> bool:
	var is_new: bool = false
	if dist > best_distance:
		best_distance = dist
		is_new = true
	if score > best_score:
		best_score = score
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("records", "best_distance", best_distance)
	cfg.set_value("records", "best_score", best_score)
	cfg.save(SAVE_PATH)
	return is_new

func set_phase(phase: String) -> void:
	_title_panel.visible = phase == "title"
	_hud_root.visible = phase == "playing" or phase == "paused"
	_pause_panel.visible = phase == "paused"
	_gameover_panel.visible = phase == "gameover"
	if phase == "title":
		_lbl_title_best.visible = best_distance > 0
		_lbl_title_best.text = "PERSONAL BEST  %04d m   ·   %d pts" % [best_distance, best_score]

func update_hud(dist: int, score: int, flow: int, flow_charge: float, active_form: int, tide_danger: float, ability_ratio: float = 1.0, ability_text: String = "PHANTOM DASH READY") -> void:
	_lbl_best.text = "BEST  %04d m" % maxi(best_distance, dist)
	_lbl_tide_warn.visible = tide_danger > 0.52
	_lbl_dist.text = "%04d m" % dist
	_lbl_score.text = "SCORE  %d" % score
	_lbl_flow.text = "x%d FLOW" % flow
	_flow_bar.value = clampf(flow_charge, 0.04, 1.0) * 100.0

	var cols: Array[Color] = [COL_FOX, COL_MOTH, COL_PANGOLIN]
	var form_idx: int = clampi(active_form, 0, 2)
	var active_col: Color = cols[form_idx]
	_lbl_flow.modulate = active_col
	_flow_fill_sb.bg_color = active_col

	_lbl_ability.text = ability_text
	_lbl_ability.modulate = active_col
	_ability_bar.value = clampf(ability_ratio, 0.0, 1.0) * 100.0

	if _last_hud_form != form_idx:
		_last_hud_form = form_idx
		for i in range(_form_buttons.size()):
			var b: Button = _form_buttons[i]
			var is_active: bool = i == form_idx
			var sb: StyleBoxFlat = _form_active_sbs[i] if is_active else _form_inactive_sb
			b.add_theme_stylebox_override("normal", sb)
			b.add_theme_stylebox_override("hover", sb)
			b.add_theme_color_override("font_color", cols[i] if is_active else Color(0.68, 0.76, 0.84, 0.85))

func show_game_over(dist: int, score: int, smashed: int, max_flow: int, cause: String) -> void:
	var is_new: bool = save_high_score(dist, score)
	var rec_tag: String = "  [NEW RECORD]" if is_new else ""
	_lbl_go_stats.text = "%s\n\nDistance: %d m%s   |   Best: %d m\nScore: %d   |   Obstacles Smashed: %d   |   Peak Flow: x%d\n\nPress R or Space for instant restart" % [cause, dist, rec_tag, best_distance, score, smashed, max_flow]
	set_phase("gameover")

func _on_form_button_pressed(idx: int) -> void:
	form_clicked.emit(idx)

func _on_play_pressed() -> void:
	play_pressed.emit()

func _on_resume_pressed() -> void:
	resume_pressed.emit()

func _on_restart_pressed() -> void:
	restart_pressed.emit()

func _on_title_pressed() -> void:
	title_pressed.emit()

func _make_box(bg: Color, border: Color, radius: int = 6, border_w: int = 1) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _build_ui() -> void:
	# ---------------------------------------------------------
	# LIVE TITLE SCREEN
	# ---------------------------------------------------------
	_title_panel = Control.new()
	_title_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_title_panel)

	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.position = Vector2(88, 96)
	title_box.add_theme_constant_override("separation", 14)
	_title_panel.add_child(title_box)

	_lbl_title_best = Label.new()
	_lbl_title_best.add_theme_font_size_override("font_size", 13)
	_lbl_title_best.modulate = COL_FOX
	title_box.add_child(_lbl_title_best)

	var lbl_title: Label = Label.new()
	lbl_title.text = "UMBRA SHIFT"
	lbl_title.add_theme_font_size_override("font_size", 58)
	lbl_title.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	lbl_title.add_theme_color_override("font_outline_color", Color(0.015, 0.03, 0.08))
	lbl_title.add_theme_constant_override("outline_size", 6)
	title_box.add_child(lbl_title)

	var lbl_tag: Label = Label.new()
	lbl_tag.text = "OUTRUN THE SHADOW INK TIDE"
	lbl_tag.add_theme_font_size_override("font_size", 14)
	lbl_tag.modulate = Color(0.68, 0.82, 0.92, 0.92)
	title_box.add_child(lbl_tag)

	# Visual Form Legend Row
	var form_legend: HBoxContainer = HBoxContainer.new()
	form_legend.add_theme_constant_override("separation", 10)
	title_box.add_child(form_legend)
	var legend_texts: Array[String] = [
		"[1 / J] FOX · Speed & Dash",
		"[2 / K] MOTH · Glide & Drafts",
		"[3 / L] PANGOLIN · Smash & Slam"
	]
	var legend_cols: Array[Color] = [COL_FOX, COL_MOTH, COL_PANGOLIN]
	for i in range(legend_texts.size()):
		var badge: PanelContainer = PanelContainer.new()
		badge.add_theme_stylebox_override("panel", _make_box(Color(0.028, 0.058, 0.115, 0.84), legend_cols[i], 5, 1))
		var blbl: Label = Label.new()
		blbl.text = legend_texts[i]
		blbl.add_theme_font_size_override("font_size", 12)
		blbl.add_theme_color_override("font_color", legend_cols[i])
		badge.add_child(blbl)
		form_legend.add_child(badge)

	# Compact Sleek PLAY CTA (never stretches full container width)
	var btn_play: Button = Button.new()
	btn_play.text = "PLAY"
	btn_play.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn_play.custom_minimum_size = Vector2(210, 52)
	btn_play.add_theme_font_size_override("font_size", 19)
	var play_sb: StyleBoxFlat = _make_box(COL_FOX, Color(0.78, 1.0, 0.9), 7, 1)
	btn_play.add_theme_stylebox_override("normal", play_sb)
	btn_play.add_theme_stylebox_override("hover", _make_box(Color(0.52, 1.0, 0.8), Color.WHITE, 7, 1))
	btn_play.add_theme_stylebox_override("pressed", _make_box(Color(0.24, 0.86, 0.6), Color(0.8, 1.0, 0.9), 7, 1))
	btn_play.add_theme_color_override("font_color", Color(0.02, 0.08, 0.1))
	btn_play.add_theme_color_override("font_hover_color", Color(0.02, 0.08, 0.1))
	btn_play.focus_mode = Control.FOCUS_NONE
	btn_play.pressed.connect(_on_play_pressed)
	title_box.add_child(btn_play)

	var controls_hint: Label = Label.new()
	controls_hint.text = "Q / E or Left / Right: Cycle Form   ·   Space / W / Up: Jump or Glide   ·   Shift / Right-Click: Fox Dash   ·   S / Down: Slam or Fast-Fall   ·   P: Pause"
	controls_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	controls_hint.offset_left = 88.0
	controls_hint.offset_top = -56.0
	controls_hint.offset_right = 1220.0
	controls_hint.offset_bottom = -30.0
	controls_hint.add_theme_font_size_override("font_size", 12)
	controls_hint.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.05, 0.9))
	controls_hint.add_theme_constant_override("outline_size", 3)
	controls_hint.modulate = Color(0.78, 0.86, 0.94, 0.86)
	_title_panel.add_child(controls_hint)

	# ---------------------------------------------------------
	# IN-GAME MINIMALIST HUD
	# ---------------------------------------------------------
	_hud_root = Control.new()
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_root)

	var top_left: VBoxContainer = VBoxContainer.new()
	top_left.position = Vector2(28, 22)
	top_left.add_theme_constant_override("separation", 6)
	_hud_root.add_child(top_left)

	_lbl_best = Label.new()
	_lbl_best.add_theme_font_size_override("font_size", 16)
	_lbl_best.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.05))
	_lbl_best.add_theme_constant_override("outline_size", 3)
	top_left.add_child(_lbl_best)

	_lbl_tide_warn = Label.new()
	_lbl_tide_warn.text = "SHADOW INK TIDE CLOSING IN"
	_lbl_tide_warn.add_theme_font_size_override("font_size", 12)
	_lbl_tide_warn.modulate = Color(0.78, 0.52, 1.0, 0.95)
	_lbl_tide_warn.visible = false
	top_left.add_child(_lbl_tide_warn)

	var top_right: VBoxContainer = VBoxContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.offset_left = -248.0
	top_right.offset_top = 20.0
	top_right.offset_right = -28.0
	top_right.offset_bottom = 136.0
	top_right.add_theme_constant_override("separation", 2)
	_hud_root.add_child(top_right)

	_lbl_dist = Label.new()
	_lbl_dist.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_dist.add_theme_font_size_override("font_size", 32)
	_lbl_dist.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.05))
	_lbl_dist.add_theme_constant_override("outline_size", 4)
	top_right.add_child(_lbl_dist)

	_lbl_score = Label.new()
	_lbl_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_score.add_theme_font_size_override("font_size", 14)
	_lbl_score.modulate = Color(0.84, 0.9, 0.96, 0.9)
	top_right.add_child(_lbl_score)

	_lbl_flow = Label.new()
	_lbl_flow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_flow.add_theme_font_size_override("font_size", 21)
	top_right.add_child(_lbl_flow)

	_flow_bar = ProgressBar.new()
	_flow_bar.custom_minimum_size = Vector2(140, 7)
	_flow_bar.show_percentage = false
	var flow_bg: StyleBoxFlat = StyleBoxFlat.new()
	flow_bg.bg_color = Color(0.06, 0.11, 0.19, 0.82)
	flow_bg.set_corner_radius_all(3)
	_flow_fill_sb = StyleBoxFlat.new()
	_flow_fill_sb.bg_color = COL_FOX
	_flow_fill_sb.set_corner_radius_all(3)
	_flow_bar.add_theme_stylebox_override("background", flow_bg)
	_flow_bar.add_theme_stylebox_override("fill", _flow_fill_sb)
	top_right.add_child(_flow_bar)

	# Bottom-Left Translucent 3-Form Indicator + Live Ability / Cooldown Meter
	var form_stack: VBoxContainer = VBoxContainer.new()
	form_stack.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	form_stack.offset_left = 28.0
	form_stack.offset_top = -108.0
	form_stack.offset_right = 468.0
	form_stack.offset_bottom = -34.0
	form_stack.add_theme_constant_override("separation", 6)
	_hud_root.add_child(form_stack)

	var form_row: HBoxContainer = HBoxContainer.new()
	form_row.add_theme_constant_override("separation", 10)
	form_stack.add_child(form_row)

	_form_inactive_sb = _make_box(Color(0.035, 0.078, 0.133, 0.68), Color(0.38, 0.48, 0.58, 0.35), 6, 1)
	_form_active_sbs = [
		_make_box(Color(0.035, 0.078, 0.133, 0.92), COL_FOX, 6, 2),
		_make_box(Color(0.035, 0.078, 0.133, 0.92), COL_MOTH, 6, 2),
		_make_box(Color(0.035, 0.078, 0.133, 0.92), COL_PANGOLIN, 6, 2)
	]
	var names: Array[String] = ["[1/J] Fox", "[2/K] Moth", "[3/L] Pangolin"]
	for i in range(3):
		var b: Button = Button.new()
		b.text = names[i]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_form_button_pressed.bind(i))
		form_row.add_child(b)
		_form_buttons.append(b)

	var ability_row: HBoxContainer = HBoxContainer.new()
	ability_row.add_theme_constant_override("separation", 10)
	form_stack.add_child(ability_row)

	_ability_bar = ProgressBar.new()
	_ability_bar.custom_minimum_size = Vector2(146, 6)
	_ability_bar.show_percentage = false
	_ability_bar.add_theme_stylebox_override("background", flow_bg)
	_ability_bar.add_theme_stylebox_override("fill", _flow_fill_sb)
	ability_row.add_child(_ability_bar)

	_lbl_ability = Label.new()
	_lbl_ability.text = "PHANTOM DASH READY"
	_lbl_ability.add_theme_font_size_override("font_size", 11)
	ability_row.add_child(_lbl_ability)

	var quick_hint: Label = Label.new()
	quick_hint.text = "[M] Mute   ·   [P] Pause   ·   [R] Restart"
	quick_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quick_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	quick_hint.offset_left = -310.0
	quick_hint.offset_top = -56.0
	quick_hint.offset_right = -28.0
	quick_hint.offset_bottom = -32.0
	quick_hint.add_theme_font_size_override("font_size", 11)
	quick_hint.modulate = Color(0.68, 0.78, 0.88, 0.65)
	_hud_root.add_child(quick_hint)

	# ---------------------------------------------------------
	# PAUSE MODAL
	# ---------------------------------------------------------
	_pause_panel = ColorRect.new()
	_pause_panel.color = Color(0.015, 0.025, 0.06, 0.76)
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_pause_panel)
	var pcard: PanelContainer = PanelContainer.new()
	pcard.set_anchors_preset(Control.PRESET_CENTER)
	pcard.offset_left = -155.0
	pcard.offset_top = -105.0
	pcard.offset_right = 155.0
	pcard.offset_bottom = 105.0
	pcard.add_theme_stylebox_override("panel", _make_box(Color(0.035, 0.06, 0.11, 0.96), Color(0.35, 0.48, 0.62, 0.6), 8, 1))
	_pause_panel.add_child(pcard)
	var pbox: VBoxContainer = VBoxContainer.new()
	pbox.add_theme_constant_override("separation", 12)
	pcard.add_child(pbox)
	var plbl: Label = Label.new()
	plbl.text = "PAUSED"
	plbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plbl.add_theme_font_size_override("font_size", 26)
	pbox.add_child(plbl)
	var b_res: Button = Button.new()
	b_res.text = "Resume"
	b_res.focus_mode = Control.FOCUS_NONE
	b_res.add_theme_stylebox_override("normal", _make_box(Color(0.07, 0.14, 0.22, 0.95), COL_FOX, 5, 1))
	b_res.pressed.connect(_on_resume_pressed)
	pbox.add_child(b_res)
	var b_rst: Button = Button.new()
	b_rst.text = "Restart"
	b_rst.focus_mode = Control.FOCUS_NONE
	b_rst.add_theme_stylebox_override("normal", _make_box(Color(0.06, 0.11, 0.19, 0.92), Color(0.35, 0.48, 0.62, 0.55), 5, 1))
	b_rst.pressed.connect(_on_restart_pressed)
	pbox.add_child(b_rst)
	var b_tit: Button = Button.new()
	b_tit.text = "Title"
	b_tit.focus_mode = Control.FOCUS_NONE
	b_tit.add_theme_stylebox_override("normal", _make_box(Color(0.06, 0.11, 0.19, 0.92), Color(0.35, 0.48, 0.62, 0.55), 5, 1))
	b_tit.pressed.connect(_on_title_pressed)
	pbox.add_child(b_tit)

	# ---------------------------------------------------------
	# GAME OVER SUMMARY MODAL
	# ---------------------------------------------------------
	_gameover_panel = ColorRect.new()
	_gameover_panel.color = Color(0.015, 0.02, 0.055, 0.82)
	_gameover_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_gameover_panel)
	var gcard: PanelContainer = PanelContainer.new()
	gcard.set_anchors_preset(Control.PRESET_CENTER)
	gcard.offset_left = -240.0
	gcard.offset_top = -140.0
	gcard.offset_right = 240.0
	gcard.offset_bottom = 140.0
	gcard.add_theme_stylebox_override("panel", _make_box(Color(0.032, 0.055, 0.105, 0.97), Color(0.31, 1.0, 0.69, 0.45), 8, 1))
	_gameover_panel.add_child(gcard)
	var gbox: VBoxContainer = VBoxContainer.new()
	gbox.add_theme_constant_override("separation", 14)
	gcard.add_child(gbox)
	var glbl: Label = Label.new()
	glbl.text = "RUN ENDED"
	glbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glbl.add_theme_font_size_override("font_size", 30)
	gbox.add_child(glbl)
	_lbl_go_stats = Label.new()
	_lbl_go_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gbox.add_child(_lbl_go_stats)
	var b_again: Button = Button.new()
	b_again.text = "PLAY AGAIN"
	b_again.focus_mode = Control.FOCUS_NONE
	b_again.custom_minimum_size = Vector2(0, 42)
	b_again.add_theme_stylebox_override("normal", play_sb)
	b_again.add_theme_color_override("font_color", Color(0.02, 0.08, 0.1))
	b_again.pressed.connect(_on_restart_pressed)
	gbox.add_child(b_again)
