class_name Debrief
extends Control
## End of the run. Ending, missions, what was learned, and the decision log.
## Copy comes from data/dialogue/debrief.json. "Jugar otra vez" clears the autoloads.

const DATA_PATH := "res://data/dialogue/debrief.json"
const NEXT_SCENE := "res://scenes/intro/Intro.tscn"
const MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const INK := Palette.CREMA
const PENDING := Palette.METAL

@onready var title_label: PixelTitle = %Title
@onready var hint_label: Label = %Hint
@onready var body_label: Label = %Body
@onready var inti_box: IntiBox = %Inti
@onready var recap_label: Label = %Recap
@onready var mains_title: Label = %MainsTitle
@onready var mains: VBoxContainer = %Mains
@onready var sides_title: Label = %SidesTitle
@onready var sides: VBoxContainer = %Sides
@onready var learned_title: Label = %LearnedTitle
@onready var learned_label: Label = %Learned
@onready var lessons: VBoxContainer = %Lessons
@onready var decisions_title: Label = %DecisionsTitle
@onready var decisions: VBoxContainer = %Decisions
@onready var menu_button: Button = %Menu
@onready var again_button: Button = %Again

var _real_title: Label
var _real: VBoxContainer
var _nasa_button: Button
var _nasa_panel: NasaDataPanel

var _data: Dictionary = {}
var _tap_frame := -1


func _ready() -> void:
	var vista := MarsVista.new()
	vista.name = "Vista"
	vista.night = true
	vista.show_camp = false
	vista.veil = false
	vista.debrief_sky = true
	vista.set_anchors_preset(Control.PRESET_FULL_RECT)
	vista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vista)
	move_child(vista, 0)
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.color = Color(Palette.ESPACIO, 0.28)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	move_child(scrim, 1)
	if has_node("Background"):
		$Background.hide()
	_real_title = Label.new()
	_real_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_real_title.add_theme_color_override("font_color", INK)
	_real = VBoxContainer.new()
	var content := $Margin/Card/Layout/Scroll/Content
	content.add_child(_real_title)
	content.add_child(_real)
	content.move_child(_real_title, recap_label.get_index() + 1)
	content.move_child(_real, _real_title.get_index() + 1)
	_nasa_button = Button.new()
	_nasa_button.pressed.connect(_open_nasa)
	$Margin/Card/Layout/Buttons.add_child(_nasa_button)
	$Margin/Card/Layout/Buttons.move_child(_nasa_button, 0)
	_nasa_panel = (load("res://scenes/ui/NasaDataPanel.tscn") as PackedScene).instantiate() as NasaDataPanel
	_nasa_panel.closed.connect(func() -> void: again_button.grab_focus())
	add_child(_nasa_panel)
	menu_button.pressed.connect(_on_menu)
	again_button.pressed.connect(_on_again)
	inti_box.panel_pressed.connect(_on_box)
	_data = _load()
	Settings.language_changed.connect(_apply_language)
	_apply_language(Settings.lang)
	_wire_focus()
	again_button.grab_focus()


func _wire_focus() -> void:
	var scroll := $Margin/Card/Layout/Scroll as Control
	scroll.focus_mode = Control.FOCUS_ALL
	menu_button.focus_neighbor_left = menu_button.get_path_to(menu_button)
	menu_button.focus_neighbor_right = menu_button.get_path_to(again_button)
	menu_button.focus_neighbor_top = menu_button.get_path_to(scroll)
	menu_button.focus_neighbor_bottom = menu_button.get_path_to(menu_button)
	again_button.focus_neighbor_left = again_button.get_path_to(menu_button)
	again_button.focus_neighbor_right = again_button.get_path_to(again_button)
	again_button.focus_neighbor_top = again_button.get_path_to(scroll)
	again_button.focus_neighbor_bottom = again_button.get_path_to(again_button)
	scroll.focus_neighbor_top = scroll.get_path_to(scroll)
	scroll.focus_neighbor_bottom = scroll.get_path_to(again_button)


func _apply_language(_lang: String) -> void:
	menu_button.text = Settings.text("debrief.menu")
	again_button.text = Settings.text("debrief.again")
	if _nasa_button != null:
		_nasa_button.text = Settings.text("debrief.nasa")
	if hint_label != null:
		hint_label.text = Settings.text("debrief.hint")
	learned_title.text = Settings.text("debrief.learned")
	decisions_title.text = Settings.text("debrief.decisions")
	mains_title.text = Settings.text("debrief.mains")
	sides_title.text = Settings.text("debrief.sides")
	for label in [learned_title, decisions_title, mains_title, sides_title]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fill()


func _fill() -> void:
	_clear(lessons)
	_clear(decisions)
	_clear(mains)
	_clear(sides)
	if GameState.ending_id.is_empty():
		title_label.set_text(Settings.text("debrief.preview_title"))
		body_label.text = Settings.text("debrief.preview_body")
		inti_box.dismiss()
		inti_box.hide()
		recap_label.text = ""
		learned_label.text = ""
		learned_title.hide()
		decisions_title.hide()
		mains_title.hide()
		sides_title.hide()
		if _real_title != null:
			_real_title.hide()
		return
	var endings: Dictionary = _data.get("endings", {})
	var ending: Dictionary = endings.get(String(GameState.ending_id), {})
	title_label.set_text(Settings.pick(ending, "title"))
	body_label.text = Settings.pick(ending, "text")
	var inti := _inti_line(ending)
	if inti.is_empty():
		inti_box.dismiss()
		inti_box.hide()
	else:
		inti_box.show()
		inti_box.present(inti, "", 0.02, true)
	recap_label.text = Settings.text("debrief.day") % [GameState.current_sol, DayNightSystem.mission_length()]
	_fill_real()
	_fill_missions(true)
	_fill_missions(false)
	mains_title.show()
	learned_title.hide()
	learned_label.hide()
	decisions_title.show()
	if GameState.decisions.is_empty():
		decisions.add_child(_line(Settings.text("debrief.none_yet"), INK))
	else:
		var total := GameState.decisions.size()
		var start := maxi(total - 3, 0)
		for i in range(start, total):
			var entry: Dictionary = GameState.decisions[i]
			var written := Settings.visible_text(String(entry.get("text", "")))
			decisions.add_child(_line(Settings.text("debrief.logged") % [entry.get("sol", "?"), written], INK))


func _fill_real() -> void:
	if _real == null:
		return
	for child in _real.get_children():
		_real.remove_child(child)
		child.queue_free()
	if GameState.ending_id.is_empty():
		_real_title.hide()
		return
	_real_title.show()
	_real_title.text = Settings.text("debrief.real")
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 6)
	for row in NasaData.hazard_rows():
		var icon := TextureRect.new()
		icon.texture = NasaData.hazard_texture(String(row.get("id", "")))
		icon.custom_minimum_size = Vector2(12, 12)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icons.add_child(icon)
	_real.add_child(icons)
	for line in NasaData.debrief_lines():
		_real.add_child(_line(line, INK))


func _open_nasa() -> void:
	_nasa_panel.open()


func _fill_missions(main: bool) -> void:
	var box := mains if main else sides
	var title := mains_title if main else sides_title
	var count := 0
	for id in MissionSystem.all_ids():
		var is_main := MissionSystem.get_category(id) == "main"
		if is_main != main:
			continue
		var done := MissionSystem.get_state(id) == MissionSystem.COMPLETED
		if not main and not done:
			continue
		var name := Settings.pick(MissionSystem.get_mission(id), "title")
		if name.is_empty():
			name = String(id)
		if done:
			box.add_child(_line("[x] %s" % name, INK))
		else:
			box.add_child(_line("[ ] %s  %s" % [name, Settings.text("debrief.pending")], PENDING))
		count += 1
	title.visible = count > 0
	box.visible = count > 0


func _inti_line(ending: Dictionary) -> String:
	if GameState.ending_id == &"rescate":
		var lines: Dictionary = _data.get("rescue_lines", {})
		if Settings.lang == "en" and _data.get("rescue_lines_en", {}) is Dictionary:
			var english: Dictionary = _data.get("rescue_lines_en", {})
			var specific_en := String(english.get(String(GameState.rescue_resource), ""))
			if not specific_en.is_empty():
				return specific_en
		var specific := String(lines.get(String(GameState.rescue_resource), ""))
		if not specific.is_empty():
			return specific
	return Settings.pick(ending, "inti")


func _line(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	return label


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.free()


func _load() -> Dictionary:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
	if parsed is Dictionary:
		return parsed
	push_error("Debrief: could not read %s" % DATA_PATH)
	return {}


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_accept") and not event.is_action_pressed(&"interact"):
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is BaseButton:
		return
	_continue()
	get_viewport().set_input_as_handled()


func _on_box() -> void:
	_continue()


func _continue() -> void:
	var frame := Engine.get_process_frames()
	if frame == _tap_frame:
		return
	_tap_frame = frame
	if inti_box.is_open() and not inti_box.is_done():
		inti_box.finish_typing()
		return
	var scroll := $Margin/Card/Layout/Scroll as ScrollContainer
	var bar := scroll.get_v_scroll_bar()
	if bar.max_value - bar.value > 8.0:
		bar.value = minf(bar.value + scroll.size.y * 0.8, bar.max_value)
		return
	again_button.grab_focus()


func _on_menu() -> void:
	_leave(MENU_SCENE)


func _on_again() -> void:
	_leave(NEXT_SCENE)


func _leave(scene: String) -> void:
	if scene == MENU_SCENE:
		AudioManager.play_context("menu")
	else:
		AudioManager.hold()
	get_tree().paused = false
	GameState.reset()
	ResourceSystem.reset()
	DayNightSystem.reset_cycle()
	SceneFade.change_scene(scene)
