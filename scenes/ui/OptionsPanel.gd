class_name OptionsPanel
extends Control
## Volume, language, and the window. Opened from the main menu and from pause.

signal closed
signal tutorial_restart_requested
signal touch_arrange_requested

const GRABBER_SIZE := Vector2i(12, 16)
const TRACK_COLOR := Palette.NAVY
const FILL_COLOR := Palette.ORO
const GRAB_COLOR := Palette.CREMA
const FOCUS_COLOR := Palette.ORO

@onready var _master: HSlider = %Master
@onready var _music: HSlider = %Music
@onready var _sfx: HSlider = %Sfx
@onready var _es: Button = %Es
@onready var _en: Button = %En
@onready var _window: Button = %ModeWindow
@onready var _full: Button = %ModeFull
@onready var _scale2: Button = %Scale2
@onready var _scale3: Button = %Scale3
@onready var _scale4: Button = %Scale4
@onready var _fit: Button = %ScaleFit
@onready var _vsync_on: Button = %VsyncOn
@onready var _vsync_off: Button = %VsyncOff
@onready var _touch_auto: Button = %TouchAuto
@onready var _touch_yes: Button = %TouchYes
@onready var _touch_no: Button = %TouchNo

var _vsync_status: Label
var _reduce: CheckButton
var _keys_jump: Button
var _bind_title: Label
var _bind_status: Label
var _bind_buttons: Dictionary = {}
var _bind_names: Dictionary = {}
var _bind_reset: Button
var _arrange: Button
var _await_key := ""
var _access_label: Label
var _access_picker: OptionButton

var _syncing := false
var _closing := false


func _ready() -> void:
	hide()
	var languages := ButtonGroup.new()
	languages.allow_unpress = false
	_es.button_group = languages
	_en.button_group = languages
	var modes := ButtonGroup.new()
	modes.allow_unpress = false
	_window.button_group = modes
	_full.button_group = modes
	var scales := ButtonGroup.new()
	scales.allow_unpress = true
	_scale2.button_group = scales
	_scale3.button_group = scales
	_scale4.button_group = scales
	_fit.button_group = scales
	var vsync := ButtonGroup.new()
	vsync.allow_unpress = false
	_vsync_on.button_group = vsync
	_vsync_off.button_group = vsync
	_style_slider(_master)
	_style_slider(_music)
	_style_slider(_sfx)
	_master.value_changed.connect(func(v: float) -> void:
		Settings.set_master(v)
		%MasterValue.text = _percent(v)
	)
	_music.value_changed.connect(func(v: float) -> void:
		Settings.set_music(v)
		%MusicValue.text = _percent(v)
	)
	_sfx.value_changed.connect(func(v: float) -> void:
		Settings.set_sfx(v)
		%SfxValue.text = _percent(v)
	)
	_es.toggled.connect(func(on: bool) -> void:
		if on and not _syncing:
			Settings.set_lang("es")
	)
	_en.toggled.connect(func(on: bool) -> void:
		if on and not _syncing:
			Settings.set_lang("en")
	)
	_window.toggled.connect(func(on: bool) -> void:
		if on and not _syncing:
			Settings.set_fullscreen(false)
	)
	_full.toggled.connect(func(on: bool) -> void:
		if on and not _syncing:
			Settings.set_fullscreen(true)
	)
	_scale2.toggled.connect(func(on: bool) -> void:
		if on and not _syncing:
			Settings.set_window_scale(2)
	)
	_scale3.toggled.connect(func(on: bool) -> void:
		if on and not _syncing:
			Settings.set_window_scale(3)
	)
	_scale4.toggled.connect(func(on: bool) -> void:
		if on and not _syncing:
			Settings.set_window_scale(4)
	)
	_fit.toggled.connect(func(on: bool) -> void:
		if on and not _syncing:
			Settings.set_window_scale(0)
	)
	_vsync_on.toggled.connect(func(on: bool) -> void:
		if on and not _syncing:
			Settings.set_vsync_on(true)
			_refresh_vsync_status.call_deferred()
	)
	_vsync_off.toggled.connect(func(on: bool) -> void:
		if on and not _syncing:
			Settings.set_vsync_on(false)
			_refresh_vsync_status.call_deferred()
	)
	var touches := ButtonGroup.new()
	touches.allow_unpress = false
	_touch_auto.button_group = touches
	_touch_yes.button_group = touches
	_touch_no.button_group = touches
	_touch_auto.toggled.connect(func(on: bool) -> void:
		if on and not _syncing:
			Settings.set_touch_mode("auto")
	)
	_touch_yes.toggled.connect(func(on: bool) -> void:
		if on and not _syncing:
			Settings.set_touch_mode("yes")
	)
	_touch_no.toggled.connect(func(on: bool) -> void:
		if on and not _syncing:
			Settings.set_touch_mode("no")
	)
	_arrange = Button.new()
	_arrange.name = "ArrangeTouch"
	_arrange.custom_minimum_size = Vector2(0, 40)
	_arrange.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arrange.pressed.connect(func() -> void: touch_arrange_requested.emit())
	var touch_column := %TouchName.get_parent().get_parent() as VBoxContainer
	touch_column.add_child(_arrange)
	touch_column.move_child(_arrange, %TouchName.get_parent().get_index() + 1)
	_reduce = CheckButton.new()
	_reduce.name = "ReduceEffects"
	_reduce.button_pressed = Settings.reduce_effects
	_reduce.toggled.connect(func(on: bool) -> void:
		if not _syncing:
			Settings.set_reduce_effects(on)
	)
	%Back.get_parent().add_child(_reduce)
	%Back.get_parent().move_child(_reduce, %Back.get_index())
	_build_accessibility()
	_vsync_status = Label.new()
	_vsync_status.name = "VsyncStatus"
	_vsync_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vsync_status.add_theme_font_size_override("font_size", 11)
	var vsync_column := %VsyncRow.get_parent()
	vsync_column.add_child(_vsync_status)
	vsync_column.move_child(_vsync_status, %VsyncRow.get_index() + 1)
	_build_keybind_editor()
	%TutorialAgain.pressed.connect(_restart_tutorial)
	%Back.pressed.connect(close)
	Settings.language_changed.connect(_apply_language)
	_apply_language(Settings.lang)


func _restart_tutorial() -> void:
	Settings.replay_tutorial()
	tutorial_restart_requested.emit()
	close()


func open() -> void:
	_await_key = ""
	_closing = false
	_sync()
	modulate.a = 0.0
	show()
	UiMotion.fade_in(self)
	_wire_focus()
	_master.grab_focus()


func close() -> void:
	_await_key = ""
	if not visible or _closing:
		return
	_closing = true
	UiMotion.fade_out(self, func() -> void:
		_closing = false
		hide()
		modulate.a = 1.0
		closed.emit()
	)


func _sync() -> void:
	_syncing = true
	_master.set_value_no_signal(Settings.master)
	_music.set_value_no_signal(Settings.music)
	_sfx.set_value_no_signal(Settings.sfx)
	%MasterValue.text = _percent(Settings.master)
	%MusicValue.text = _percent(Settings.music)
	%SfxValue.text = _percent(Settings.sfx)
	_es.set_pressed_no_signal(Settings.lang != "en")
	_en.set_pressed_no_signal(Settings.lang == "en")
	_window.set_pressed_no_signal(not Settings.fullscreen)
	_full.set_pressed_no_signal(Settings.fullscreen)
	_vsync_on.set_pressed_no_signal(Settings.vsync_on)
	_vsync_off.set_pressed_no_signal(not Settings.vsync_on)
	_touch_auto.set_pressed_no_signal(Settings.touch_mode == "auto")
	_touch_yes.set_pressed_no_signal(Settings.touch_mode == "yes")
	_touch_no.set_pressed_no_signal(Settings.touch_mode == "no")
	_show_arrange()
	_refresh_scales()
	_refresh_vsync_status()
	if _access_picker != null:
		_access_picker.select(Settings.accessibility_mode)
	_syncing = false


func _show_arrange() -> void:
	if _arrange == null:
		return
	var scene := get_tree().current_scene
	var path := "" if scene == null else scene.scene_file_path
	_arrange.visible = path.ends_with("Main.tscn") or (scene != null and scene.name == "Main")


func _refresh_scales() -> void:
	var web := OS.has_feature("web")
	%ScaleRow.visible = not web
	%VsyncRow.visible = not web
	if _vsync_status != null:
		_vsync_status.visible = not web
	var fit := Settings.max_fit_scale()
	_show_scale(_scale2, not web and fit >= 2)
	_show_scale(_scale3, not web and fit >= 3)
	_show_scale(_scale4, not web and fit >= 4)
	_show_scale(_fit, not web)
	_scale2.set_pressed_no_signal(Settings.window_scale == 2 and _scale2.visible)
	_scale3.set_pressed_no_signal(Settings.window_scale == 3 and _scale3.visible)
	_scale4.set_pressed_no_signal(Settings.window_scale == 4 and _scale4.visible)
	var picked := _scale2.button_pressed or _scale3.button_pressed or _scale4.button_pressed
	_fit.set_pressed_no_signal(_fit.visible and (Settings.window_scale <= 0 or not picked))
	for button in [_vsync_on, _vsync_off]:
		button.focus_mode = Control.FOCUS_NONE if web else Control.FOCUS_ALL


func _refresh_vsync_status() -> void:
	if _vsync_status == null or OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	var key := "options.vsync_applied" if Settings.vsync_matches_request() else "options.vsync_fallback"
	_vsync_status.text = Settings.text(key)
	_vsync_status.add_theme_color_override("font_color", Palette.CREMA if Settings.vsync_matches_request() else Palette.ORO)


func _show_scale(button: Button, on: bool) -> void:
	button.visible = on
	button.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE


func _apply_language(_lang: String) -> void:
	%Title.text = Settings.text("options.title")
	%MasterName.text = Settings.text("options.master")
	%MusicName.text = Settings.text("options.music")
	%SfxName.text = Settings.text("options.sfx")
	%LangName.text = Settings.text("options.language")
	%ModeName.text = Settings.text("options.screen")
	_window.text = Settings.text("options.windowed")
	_full.text = Settings.text("options.fullscreen")
	%ScaleName.text = Settings.text("options.scale")
	_fit.text = Settings.text("options.fit")
	%VsyncName.text = Settings.text("options.vsync")
	_vsync_on.text = Settings.text("options.on")
	_vsync_off.text = Settings.text("options.off")
	%TouchName.text = Settings.text("options.touch")
	_touch_auto.text = Settings.text("options.touch_auto")
	_touch_yes.text = Settings.text("options.touch_yes")
	_touch_no.text = Settings.text("options.touch_no")
	if _arrange != null:
		_arrange.text = Settings.text("touch.arrange")
	%TutorialName.text = Settings.text("options.tutorial")
	%TutorialAgain.text = Settings.text("options.tutorial_again")
	_es.text = Settings.text("options.es")
	_en.text = Settings.text("options.en")
	%Back.text = Settings.text("common.back")
	if _reduce != null:
		_reduce.text = Settings.text("options.reduce")
	if _access_label != null:
		_access_label.text = Settings.text("options.accessibility")
	if _access_picker != null:
		for i in range(4):
			_access_picker.set_item_text(i, Settings.text(["options.access_off", "options.access_contrast", "options.access_blue", "options.access_gray"][i]))
	if _keys_jump != null:
		_keys_jump.text = Settings.text("options.keybind_jump")
	if _bind_title != null:
		_bind_title.text = Settings.text("options.keybinds")
	if _bind_reset != null:
		_bind_reset.text = Settings.text("options.reset_keys")
	for action in _bind_names.keys():
		var action_name := _bind_names[action] as Label
		if is_instance_valid(action_name):
			action_name.text = Settings.text("actions." + String(action))
	_refresh_bind_labels()
	if is_node_ready():
		_sync()


func _build_accessibility() -> void:
	var column := %Back.get_parent() as VBoxContainer
	var row := HBoxContainer.new()
	row.name = "AccessibilityRow"
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	column.move_child(row, %Back.get_index())
	_access_label = Label.new()
	_access_label.custom_minimum_size = Vector2(158, 0)
	_access_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_access_label)
	_access_picker = OptionButton.new()
	_access_picker.name = "AccessibilityMode"
	_access_picker.custom_minimum_size = Vector2(180, 30)
	_access_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(4):
		_access_picker.add_item("", i)
	_access_picker.item_selected.connect(func(index: int) -> void:
		if not _syncing:
			Settings.set_accessibility_mode(index)
	)
	row.add_child(_access_picker)


## Works in both the main-menu Options and the in-game pause menu.
## This editor is part of the existing options scroll area, not a new scene.
func _build_keybind_editor() -> void:
	var column := %Back.get_parent() as VBoxContainer
	_keys_jump = Button.new()
	_keys_jump.name = "ConfigureKeybinds"
	_keys_jump.custom_minimum_size.y = 32
	_keys_jump.pressed.connect(_show_keybinds)
	column.add_child(_keys_jump)
	column.move_child(_keys_jump, %Title.get_index() + 1)
	_bind_title = Label.new()
	_bind_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bind_title.add_theme_color_override("font_color", Palette.ORO)
	column.add_child(_bind_title)
	column.move_child(_bind_title, %TutorialAgain.get_parent().get_index())
	for action in Settings.EDITABLE_ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		column.add_child(row)
		column.move_child(row, %TutorialAgain.get_parent().get_index())
		var name := Label.new()
		name.text = Settings.text("actions." + action)
		name.custom_minimum_size = Vector2(178, 0)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var bind := Button.new()
		bind.custom_minimum_size = Vector2(110, 24)
		bind.pressed.connect(_begin_rebind.bind(action))
		row.add_child(bind)
		_bind_buttons[action] = bind
		_bind_names[action] = name
	_bind_status = Label.new()
	_bind_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_bind_status)
	column.move_child(_bind_status, %TutorialAgain.get_parent().get_index())
	_bind_reset = Button.new()
	_bind_reset.custom_minimum_size = Vector2(184, 28)
	_bind_reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bind_reset.pressed.connect(func() -> void:
		_await_key = ""
		Settings.reset_keybinds()
		_bind_status.text = ""
	)
	column.add_child(_bind_reset)
	column.move_child(_bind_reset, %TutorialAgain.get_parent().get_index())
	Settings.keybinds_changed.connect(_refresh_bind_labels)
	_refresh_bind_labels()


func _show_keybinds() -> void:
	_await_key = ""
	_refresh_bind_labels()
	# Scroll to the real editor and give keyboard focus to its first action.
	var scroll := $Center/Panel/Margin/Scroll as ScrollContainer
	scroll.ensure_control_visible(_bind_title)
	if not _bind_buttons.is_empty():
		var button := _bind_buttons[Settings.EDITABLE_ACTIONS[0]] as Button
		button.grab_focus()


func _begin_rebind(action: String) -> void:
	_await_key = action
	_bind_status.text = Settings.text("options.keybind_hint")
	_refresh_bind_labels()


func _input(event: InputEvent) -> void:
	if not visible or _await_key.is_empty() or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		get_viewport().set_input_as_handled()
		return
	var physical := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	if physical == KEY_ESCAPE:
		_await_key = ""
		_bind_status.text = ""
	elif not Settings.set_keybind(_await_key, physical):
		_bind_status.text = Settings.text("options.keybind_conflict")
	else:
		_await_key = ""
		_bind_status.text = ""
	_refresh_bind_labels()
	get_viewport().set_input_as_handled()


func _refresh_bind_labels() -> void:
	for action in _bind_buttons.keys():
		var button := _bind_buttons[action] as Button
		button.text = "..." if _await_key == action else OS.get_keycode_string(Settings.primary_key(action))


func _percent(value: float) -> String:
	return "%d" % roundi(value * 100.0)


func _wire_focus() -> void:
	var rows: Array = [
		[_keys_jump],
		[_master],
		[_music],
		[_sfx],
		[_window, _full],
		[_scale2, _scale3, _scale4, _fit],
		[_vsync_on, _vsync_off],
		[_es, _en],
		[_touch_auto, _touch_yes, _touch_no],
		[_arrange],
		[%TutorialAgain],
		[_access_picker],
		[%Back],
	]
	# The editor is inserted between touch-mode and tutorial in the scroll column.
	var tutorial_row := rows.find([%TutorialAgain])
	if tutorial_row >= 0:
		for i in range(Settings.EDITABLE_ACTIONS.size() - 1, -1, -1):
			rows.insert(tutorial_row, [_bind_buttons[Settings.EDITABLE_ACTIONS[i]]])
		rows.insert(tutorial_row + Settings.EDITABLE_ACTIONS.size(), [_bind_reset])
	var active: Array = []
	for row in rows:
		var visible_controls: Array[Control] = []
		for item in row:
			var control := item as Control
			if control.visible and control.focus_mode != Control.FOCUS_NONE:
				visible_controls.append(control)
		if visible_controls.is_empty():
			continue
		active.append(visible_controls)
	for r in active.size():
		var line: Array[Control] = active[r]
		var up: Control = active[r - 1][0] if r > 0 else line[0]
		var down: Control = active[r + 1][0] if r + 1 < active.size() else line[0]
		for i in line.size():
			var control := line[i]
			var left := line[i - 1] if i > 0 else control
			var right := line[i + 1] if i + 1 < line.size() else control
			if control is HSlider:
				control.focus_neighbor_left = NodePath()
				control.focus_neighbor_right = NodePath()
			else:
				control.focus_neighbor_left = control.get_path_to(left)
				control.focus_neighbor_right = control.get_path_to(right)
			control.focus_neighbor_top = control.get_path_to(up)
			control.focus_neighbor_bottom = control.get_path_to(down)


func _style_slider(slider: HSlider) -> void:
	slider.focus_mode = Control.FOCUS_ALL
	var track := StyleBoxFlat.new()
	track.bg_color = TRACK_COLOR
	track.anti_aliasing = false
	track.set_corner_radius_all(0)
	track.set_content_margin_all(0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = FILL_COLOR
	fill.anti_aliasing = false
	fill.set_corner_radius_all(0)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = FOCUS_COLOR
	focus.anti_aliasing = false
	focus.set_corner_radius_all(0)
	focus.set_border_width_all(2)
	slider.add_theme_stylebox_override("focus", focus)
	var grab := _pixel(GRAB_COLOR)
	slider.add_theme_icon_override("grabber", grab)
	slider.add_theme_icon_override("grabber_highlight", grab)
	slider.add_theme_icon_override("grabber_disabled", _pixel(Palette.METAL))


func _pixel(color: Color) -> ImageTexture:
	var image := Image.create(GRABBER_SIZE.x, GRABBER_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture := ImageTexture.create_from_image(image)
	return texture
