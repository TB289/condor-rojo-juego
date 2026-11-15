class_name HUD
extends CanvasLayer
## Clock (top-left), a thin mission reminder (top-right), and oxygen, energy and radiation shielding around the minimap.
## The tracker shows the earliest active main, or the earliest secondary when no main is active.
## A short notice sits under the clock and does not use INTI. The interact line is a world sign, not a HUD label.

const BOX_COLOR := Palette.CREMA
const CHECK_COLOR := Palette.OK
const DONE_TINT := Palette.METAL
const TITLE_SIDE := Palette.INTI
const TITLE_MAIN := Palette.ORO
const FONT := preload("res://assets/fonts/m5x7.ttf")

const MISSION_WIDTH := 148.0

@onready var resources_panel: PanelContainer = $Root/ResourcesPanel
@onready var sol_panel: PanelContainer = $Root/SolPanel
@onready var sol_label: Label = $Root/SolPanel/Sol

var _dose_button: Button
@onready var mission_panel: PanelContainer = $Root/MissionPanel
@onready var mission_title: Label = $Root/MissionPanel/Content/Title
@onready var objective_list: VBoxContainer = $Root/MissionPanel/Content/Objectives
@onready var other_label: Label = $Root/MissionPanel/Content/Other
@onready var work_bar: ProgressBar = $Root/MissionPanel/Content/Work

var _notice: PanelContainer
var _notice_label: Label
var _notice_raw := ""
var _notice_left := 0.0
var _lamp_icon: Control
var _time_label: Label
var _speed_label: Label
var _cinematic_resources: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"hud")
	_build_notice()
	_build_cinematic_resources()
	EventBus.sol_started.connect(_on_sol_started)
	EventBus.mission_started.connect(_on_mission_changed.unbind(1))
	EventBus.mission_objective_done.connect(_on_mission_changed.unbind(2))
	EventBus.mission_completed.connect(_on_mission_changed.unbind(1))
	MissionSystem.work_progress.connect(_on_work_progress)
	Cutscenes.cutscene_started.connect(_on_cutscene_started)
	Cutscenes.cutscene_finished.connect(_on_cutscene_finished)
	Settings.language_changed.connect(_on_language)
	visible = true
	mission_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	mission_panel.gui_input.connect(_on_mission_gui)
	MissionSystem.focus_changed.connect(_on_mission_changed)
	_lamp_icon = Control.new()
	_lamp_icon.name = "LampIcon"
	_lamp_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lamp_icon.custom_minimum_size = Vector2(16, 16)
	_lamp_icon.size = Vector2(16, 16)
	_lamp_icon.visible = false
	_lamp_icon.draw.connect(_draw_lamp)
	$Root.add_child(_lamp_icon)
	var arrow := MissionArrow.new()
	arrow.name = "MissionArrow"
	$Root.add_child(arrow)
	_build_clock()
	_style_mission()
	_on_sol_started(GameState.current_sol)
	work_bar.hide()
	_on_mission_changed()
	_fit_resources.call_deferred()
	if Cutscenes.is_playing():
		_on_cutscene_started(&"")


func _build_cinematic_resources() -> void:
	# CutscenePlayer occupies canvas layer 50; keep just the three survival bars
	# above it, not the mission/clock HUD that is deliberately hidden.
	_cinematic_resources = CanvasLayer.new()
	_cinematic_resources.name = "CinematicResources"
	_cinematic_resources.layer = 55
	_cinematic_resources.visible = false
	add_child(_cinematic_resources)


func _on_cutscene_started(_id: StringName) -> void:
	# Cinematics should not leave the survival bars floating over the picture.
	# Keep the ring on the HUD tree, but hide it together with the other HUD pieces.
	var ring: Control = $Root.get_node_or_null("ResourceRing") as Control
	if ring != null:
		if ring.get_parent() != $Root:
			ring.reparent($Root)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.hide()
	if _cinematic_resources != null:
		_cinematic_resources.visible = false
	sol_panel.hide()
	mission_panel.hide()
	if _notice != null:
		_notice.hide()
	if _lamp_icon != null:
		_lamp_icon.hide()
	var hotbar := $Root.get_node_or_null("Hotbar") as Control
	if hotbar != null:
		hotbar.hide()


func _on_cutscene_finished(_id: StringName) -> void:
	var ring: Control = $Root.get_node_or_null("ResourceRing") as Control
	if ring == null and _cinematic_resources != null:
		ring = _cinematic_resources.get_node_or_null("ResourceRing") as Control
		if ring != null:
			ring.reparent($Root)
	if ring != null:
		ring.mouse_filter = Control.MOUSE_FILTER_STOP
		ring.show()
	if _cinematic_resources != null:
		_cinematic_resources.visible = false
	sol_panel.show()
	_on_sol_started(GameState.current_sol)
	_on_mission_changed()
	var hotbar := $Root.get_node_or_null("Hotbar") as Control
	if hotbar != null:
		hotbar.show()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if not event.is_action_pressed(&"cycle_mission"):
		return
	if get_tree().paused or Cutscenes.is_playing() or GameState.run_over:
		return
	MissionSystem.cycle_focus()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_update_speed_button()
	_paint_dose()
	_place_lamp()
	_place_notice()
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice != null:
			var alpha := 1.0
			if _notice_left > 2.6:
				alpha = (2.8 - _notice_left) / 0.2
			elif _notice_left < 0.45:
				alpha = _notice_left / 0.45
			_notice.modulate.a = clampf(alpha, 0.0, 1.0)
		if _notice_left <= 0.0 and _notice != null:
			_notice.visible = false


func _on_language(_lang: String) -> void:
	_update_speed_button()
	_on_sol_started(GameState.current_sol)
	_on_mission_changed()
	if _notice_label != null and _notice != null and _notice.visible:
		_notice_label.text = Settings.visible_text(_notice_raw)
	_fit_resources.call_deferred()


func _build_clock() -> void:
	var empty := StyleBoxEmpty.new()
	sol_panel.add_theme_stylebox_override("panel", empty)
	sol_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sol_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	sol_panel.grow_horizontal = Control.GROW_DIRECTION_END
	sol_panel.grow_vertical = Control.GROW_DIRECTION_END
	var parent := sol_label.get_parent()
	parent.remove_child(sol_label)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	parent.add_child(box)
	var time_row := HBoxContainer.new()
	time_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_row.add_theme_constant_override("separation", 4)
	box.add_child(time_row)
	_time_label = Label.new()
	_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_label.label_settings = _ink(16, Palette.CREMA)
	time_row.add_child(_time_label)
	_speed_label = Label.new()
	_speed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_label.label_settings = _ink(16, Palette.METAL)
	time_row.add_child(_speed_label)
	sol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(sol_label)
	var dose_row := HBoxContainer.new()
	dose_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dose_row.add_theme_constant_override("separation", 2)
	box.add_child(dose_row)
	var icon := TextureRect.new()
	icon.texture = NasaData.hazard_texture("dose")
	icon.custom_minimum_size = Vector2(12, 12)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dose_row.add_child(icon)
	_dose_button = Button.new()
	_dose_button.focus_mode = Control.FOCUS_ALL
	_dose_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_dose_button.flat = true
	_dose_button.add_theme_font_size_override("font_size", 16)
	_dose_button.add_theme_color_override("font_color", Palette.CREMA)
	_dose_button.add_theme_color_override("font_hover_color", Palette.CREMA)
	_dose_button.add_theme_color_override("font_focus_color", Palette.ORO)
	_dose_button.add_theme_color_override("font_outline_color", Palette.CONTORNO)
	_dose_button.add_theme_constant_override("outline_size", 3)
	_dose_button.pressed.connect(func() -> void:
		NasaData.show_manual("radiation")
		NasaData.show_manual("rad_mars")
	)
	dose_row.add_child(_dose_button)
	_update_speed_button()


func _update_speed_button() -> void:
	# Display-only x1/x4 indicator; T is the keyboard toggle (not a mouse button).
	if _time_label == null or _speed_label == null:
		return
	var clock := DayNightSystem.clock_text()
	var rate := "x4" if DayNightSystem.time_speed == DayNightSystem.TIME_BOOST_MULTIPLIER else "x1"
	if _time_label.text != clock or _speed_label.text != rate:
		_time_label.text = clock
		_speed_label.text = rate
		_speed_label.label_settings.font_color = Palette.ORO if DayNightSystem.time_speed == DayNightSystem.TIME_BOOST_MULTIPLIER else Palette.METAL
		_fit_sol.call_deferred()


func _on_sol_started(n: int) -> void:
	sol_label.text = Settings.text("hud.day") % maxi(n, 1)
	_paint_dose()
	_fit_sol.call_deferred()


func _paint_dose() -> void:
	if _dose_button == null:
		return
	var text := Settings.text("hud.dose") % NasaData.num(GameState.daily_dose_msv, 1)
	var countdown := NasaData.visible_storm_countdown()
	if countdown > 0:
		text += "  %s" % (Settings.text("nasa.countdown") % countdown)
	if _dose_button.text != text:
		_dose_button.text = text
		_fit_sol.call_deferred()
	var danger := NasaData.dose_danger()
	_dose_button.add_theme_color_override("font_color", Palette.PELIGRO if danger else Palette.CREMA)
	_dose_button.add_theme_color_override("font_hover_color", Palette.PELIGRO if danger else Palette.CREMA)


func _on_mission_changed() -> void:
	var id := MissionSystem.get_shown()
	for child in objective_list.get_children():
		objective_list.remove_child(child)
		child.queue_free()
	work_bar.hide()
	if MissionSystem.all_mains_done() and DayNightSystem.has_started() and not GameState.run_over:
		_show_survive(id)
		return
	if id == &"":
		var show := DayNightSystem.has_started() and not GameState.run_over
		mission_panel.visible = show
		if not show:
			return
		mission_title.text = Settings.text("hud.to_bed")
		_paint_title(false)
		other_label.visible = false
		_fit_mission.call_deferred()
		return
	mission_panel.visible = true
	var mission := MissionSystem.get_mission(id)
	var main := MissionSystem.get_category(id) == "main"
	mission_title.text = ("* " if main else "") + Settings.pick(mission, "title")
	_paint_title(main)
	var lead := _lead_line(mission, id)
	if not lead.is_empty():
		var done := _lead_done(mission, id)
		_add_objective(lead, done)
	other_label.visible = false
	work_bar.hide()
	_fit_mission.call_deferred()


func _paint_title(main: bool) -> void:
	var look := mission_title.label_settings.duplicate()
	look.font_color = TITLE_MAIN if main else TITLE_SIDE
	mission_title.label_settings = look


## Featured tracker once the five mains are done. One line: the side task, or the days left.
func _show_survive(followed: StringName) -> void:
	mission_panel.visible = true
	mission_title.text = Settings.text("hud.survive")
	_paint_title(true)
	var left := DayNightSystem.sols_left()
	var days := Settings.text("hud.last_night")
	if left == 1:
		days = Settings.text("hud.day_left")
	elif left > 1:
		days = Settings.text("hud.days_left") % left
	if followed != &"" and MissionSystem.get_category(followed) != "main":
		var side := _lead_line(MissionSystem.get_mission(followed), followed)
		_add_objective(side if not side.is_empty() else days, false)
	else:
		_add_objective(days, false)
	other_label.visible = false
	work_bar.hide()
	_fit_mission.call_deferred()


## A short line on screen. Not an INTI line, and it does not pause the game.
func show_notice(text: String) -> void:
	if _notice == null or _notice_label == null or text.is_empty():
		return
	_notice_raw = text
	_notice_label.text = Settings.visible_text(text)
	_notice.visible = true
	_notice.modulate.a = 0.0
	_notice_left = 2.8


func _build_notice() -> void:
	_notice = PanelContainer.new()
	_notice.name = "Notice"
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.visible = false
	_notice.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.051, 0.071, 0.11, 0.92)
	back.border_color = Palette.ESPACIO
	back.set_border_width_all(1)
	back.set_content_margin_all(3)
	back.anti_aliasing = false
	_notice.add_theme_stylebox_override("panel", back)
	_notice_label = Label.new()
	_notice_label.name = "Line"
	_notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_notice_label.clip_text = true
	_notice_label.label_settings = _sign_ink(Palette.CREMA)
	_notice.add_child(_notice_label)
	$Root.add_child(_notice)


func _style_mission() -> void:
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.051, 0.071, 0.11, 0.84)
	plate.border_color = Color(Palette.INTI, 0.9)
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(3)
	plate.set_content_margin_all(5)
	plate.anti_aliasing = false
	mission_panel.add_theme_stylebox_override("panel", plate)
	var content := mission_panel.get_node("Content") as VBoxContainer
	content.add_theme_constant_override("separation", 4)
	objective_list.add_theme_constant_override("separation", 3)
	mission_title.label_settings = _sign_ink(TITLE_MAIN)
	other_label.label_settings = _sign_ink(Palette.METAL)


func _add_objective(text: String, done: bool) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	var box := Control.new()
	box.custom_minimum_size = Vector2(12, 16)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.draw.connect(_draw_box.bind(box, done))
	var label := Label.new()
	label.text = text
	label.label_settings = _sign_ink(Palette.CREMA)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if done:
		label.modulate = DONE_TINT
	row.add_child(box)
	row.add_child(label)
	objective_list.add_child(row)


## The pixel font has no check glyph, so the box and tick are drawn.
func _draw_box(box: Control, done: bool) -> void:
	var side := 10.0
	var origin := Vector2((box.size.x - side) * 0.5, (box.size.y - side) * 0.5)
	box.draw_rect(Rect2(origin, Vector2(side, side)), BOX_COLOR, false, 1.0)
	if done:
		box.draw_polyline(PackedVector2Array([
			origin + Vector2(2, 5), origin + Vector2(4, 7), origin + Vector2(8, 2),
		]), CHECK_COLOR, 1.0)


func _fit_sol() -> void:
	var width := ceili(sol_panel.get_combined_minimum_size().x)
	var height := ceili(sol_panel.get_combined_minimum_size().y)
	sol_panel.offset_left = 6.0
	sol_panel.offset_top = 4.0
	sol_panel.offset_right = 6.0 + width
	sol_panel.offset_bottom = 4.0 + height


func _fit_mission() -> void:
	mission_panel.offset_left = -6.0 - MISSION_WIDTH
	mission_panel.offset_right = -6.0
	mission_panel.offset_top = 6.0
	var style := mission_panel.get_theme_stylebox("panel")
	var inner := MISSION_WIDTH
	if style:
		inner -= style.content_margin_left + style.content_margin_right
	var content := mission_panel.get_node("Content") as VBoxContainer
	var height := _column_height(content, inner)
	if style:
		height += ceili(style.content_margin_top + style.content_margin_bottom)
	mission_panel.offset_bottom = 6.0 + height


## Wrapped lines stay inside the narrow tracker. The panel grows down, not sideways.
func _column_height(box: VBoxContainer, width: float) -> int:
	var total := 0
	var shown := 0
	for child in box.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		total += _block_height(control, width)
		shown += 1
	if shown > 1:
		total += box.get_theme_constant("separation") * (shown - 1)
	return total


func _block_height(control: Control, width: float) -> int:
	if control is Label:
		return _label_height(control as Label, width)
	if control is HBoxContainer:
		var row := control as HBoxContainer
		var row_h := 0
		var used := 0.0
		var labels: Array[Label] = []
		for child in row.get_children():
			var item := child as Control
			if item == null or not item.visible:
				continue
			if item is Label:
				labels.append(item)
			else:
				used += item.get_combined_minimum_size().x + row.get_theme_constant("separation")
				row_h = maxi(row_h, ceili(item.get_combined_minimum_size().y))
		var remain := maxf(width - used, 32.0)
		for label in labels:
			row_h = maxi(row_h, _label_height(label, remain))
		return row_h
	if control is VBoxContainer:
		return _column_height(control as VBoxContainer, width)
	return ceili(control.get_combined_minimum_size().y)


func _label_height(label: Label, width: float) -> int:
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	if label.label_settings:
		if label.label_settings.font:
			font = label.label_settings.font
		if label.label_settings.font_size > 0:
			size = label.label_settings.font_size
	if font == null or label.text.is_empty():
		return size
	var bounds := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, width, size)
	return maxi(ceili(bounds.y), size)


func _fit_resources() -> void:
	resources_panel.visible = false
	resources_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resources_panel.process_mode = Node.PROCESS_MODE_DISABLED


func _on_mission_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		MissionSystem.cycle_focus()
		get_viewport().set_input_as_handled()


func _place_lamp() -> void:
	if _lamp_icon == null:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	var on := player != null and player.is_flashlight_on() and not Cutscenes.is_playing()
	_lamp_icon.visible = on
	if not on:
		return
	var rect := sol_panel.get_rect()
	_lamp_icon.position = Vector2(rect.end.x + 4.0, rect.position.y)
	_lamp_icon.queue_redraw()


func _draw_lamp() -> void:
	_lamp_icon.draw_rect(Rect2(2, 6, 8, 5), Palette.ORO)
	_lamp_icon.draw_rect(Rect2(3, 7, 6, 2), Palette.SOL)
	_lamp_icon.draw_rect(Rect2(10, 7, 4, 1), Palette.ORO)
	_lamp_icon.draw_rect(Rect2(10, 5, 3, 1), Palette.SOL)
	_lamp_icon.draw_rect(Rect2(10, 9, 3, 1), Palette.SOL)


func _on_work_progress(ratio: float) -> void:
	work_bar.visible = ratio >= 0.0 and ratio <= 1.0 and mission_panel.visible
	work_bar.value = clampf(ratio, 0.0, 1.0)


func _ink(size: int, color: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = FONT
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = 3
	settings.outline_color = Palette.CONTORNO
	return settings


## Same small face as the world sign: one-pixel dark outline, no heavy shadow.
func _sign_ink(color: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = FONT
	settings.font_size = 16
	settings.font_color = color
	settings.outline_size = 1
	settings.outline_color = Palette.ESPACIO
	return settings


func _lead_line(mission: Dictionary, id: StringName) -> String:
	var first := ""
	for objective in mission.get("objectives", []):
		var label := Settings.pick(objective, "label")
		if first.is_empty():
			first = label
		if not MissionSystem.is_objective_done(id, String(objective.get("id", ""))):
			return label
	return first


func _lead_done(mission: Dictionary, id: StringName) -> bool:
	var any := false
	for objective in mission.get("objectives", []):
		any = true
		if not MissionSystem.is_objective_done(id, String(objective.get("id", ""))):
			return false
	return any


func _place_notice() -> void:
	if _notice == null or _notice_label == null:
		return
	var clock := sol_panel.get_global_rect()
	var text := _notice_label.text
	var text_w := 24.0
	if not text.is_empty():
		text_w = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16).x
	var width := clampf(text_w + 8.0, 24.0, 220.0)
	var height := 22.0
	_notice.position = Vector2(clock.position.x, clock.end.y + 3.0)
	_notice.size = Vector2(width, height)
	_notice_label.custom_minimum_size = Vector2(width - 8.0, 16.0)
