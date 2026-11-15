extends Control
## Front door. Nueva partida plays the intro, which continues straight into the mission.
## Continue reopens a paused in-memory game from this running app session.

const INTRO_SCENE := "res://scenes/intro/Intro.tscn"

@onready var _play: Button = %Play
@onready var _continue: Button = %Continue
@onready var _quit: Button = %Quit
@onready var _how_panel: Control = %HowPanel
@onready var _credits_panel: Control = %CreditsPanel
@onready var _options: OptionsPanel = %Options

var _cursor: Control
var _nasa: NasaDataPanel
var _control_choice: Control
var _choice_keyboard: Button
var _choice_touch: Button
var _choice_back: Button
var _choice_title: Label
var _choice_help: Label


func _ready() -> void:
	_continue.disabled = not RunSession.has_game()
	_continue.focus_mode = Control.FOCUS_NONE if _continue.disabled else Control.FOCUS_ALL
	_quit.visible = not OS.has_feature("web")
	_play.pressed.connect(_on_play)
	_continue.pressed.connect(_on_continue)
	%How.pressed.connect(func() -> void: _open(_how_panel, %HowBack))
	_nasa = (load("res://scenes/ui/NasaDataPanel.tscn") as PackedScene).instantiate() as NasaDataPanel
	add_child(_nasa)
	_nasa.closed.connect(func() -> void:
		_set_menu_focus(true)
		_play.grab_focus()
	)
	%Nasa.pressed.connect(func() -> void: _open_nasa())
	%OptionsButton.pressed.connect(_on_options)
	%Credits.pressed.connect(func() -> void: _open(_credits_panel, %CreditsBack))
	_quit.pressed.connect(func() -> void: get_tree().quit())
	%HowBack.pressed.connect(func() -> void: _close(_how_panel))
	%CreditsBack.pressed.connect(func() -> void: _close(_credits_panel))
	_options.closed.connect(_on_options_closed)
	Settings.language_changed.connect(_apply_language)
	_apply_language(Settings.lang)
	_style_links()
	var empty := StyleBoxEmpty.new()
	$MenuPanel.add_theme_stylebox_override("panel", empty)
	_wire_menu_focus()
	_wire_overlay_focus()
	_build_cursor()
	_build_control_choice()
	# Version is not shown on the menu. Credits list the team instead.
	AudioManager.play_context("menu")
	_play.grab_focus()


func _process(_delta: float) -> void:
	_place_cursor()


func _apply_language(_lang: String) -> void:
	%Subtitle.text = Settings.text("menu.subtitle")
	_play.text = Settings.text("menu.play")
	_continue.text = Settings.text("menu.continue")
	_continue.tooltip_text = Settings.text("menu.continue_hint")
	%How.text = Settings.text("menu.how")
	%Nasa.text = Settings.text("menu.nasa")
	%OptionsButton.text = Settings.text("menu.options")
	%Credits.text = Settings.text("menu.credits")
	_quit.text = Settings.text("menu.quit")
	%HowTitle.text = Settings.text("how.title")
	%HowBody.text = Settings.text("how.body")
	%HowBack.text = Settings.text("common.back")
	%CreditsTitle.text = Settings.text("credits.title")
	%CreditsBody.text = Settings.text("credits.body")
	%CreditsBack.text = Settings.text("common.back")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if _control_choice != null and _control_choice.visible:
		_control_choice.hide()
		_play.grab_focus()
	elif _options.visible:
		_options.close()
	elif _how_panel.visible:
		_close(_how_panel)
	elif _credits_panel.visible:
		_close(_credits_panel)
	elif _nasa != null and _nasa.visible:
		_close(_nasa)
	else:
		return
	get_viewport().set_input_as_handled()


func _on_continue() -> void:
	if not RunSession.has_game():
		_continue.disabled = true
		_continue.focus_mode = Control.FOCUS_NONE
		return
	SceneFade.resume_session()


func _on_play() -> void:
	_update_choice_language(Settings.lang)
	_control_choice.show()
	_choice_keyboard.grab_focus()


func _start_new_game(touch: bool) -> void:
	Settings.set_touch_mode("yes" if touch else "no")
	_control_choice.hide()
	get_tree().paused = false
	RunSession.discard() # New Game replaces any suspended session.
	GameState.reset()
	ResourceSystem.reset()
	DayNightSystem.reset_cycle()
	SceneFade.change_scene(INTRO_SCENE)


## On a new run, show the control choice from 2.5.3; the mode can still be
## switched at any moment using Options in the pause menu.
func _build_control_choice() -> void:
	_control_choice = Control.new()
	_control_choice.name = "ControlChoice"
	add_child(_control_choice)
	_control_choice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.05, 0.10, 0.87)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_control_choice.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_control_choice.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(324, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.NAVY
	style.border_color = Palette.ORO
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_choice_title = Label.new()
	_choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_choice_title.add_theme_font_size_override("font_size", 24)
	_choice_title.add_theme_color_override("font_color", Palette.ORO)
	column.add_child(_choice_title)
	_choice_help = Label.new()
	_choice_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_choice_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_choice_help)
	_choice_keyboard = Button.new()
	_choice_keyboard.custom_minimum_size.y = 46
	_choice_keyboard.pressed.connect(_start_new_game.bind(false))
	column.add_child(_choice_keyboard)
	_choice_touch = Button.new()
	_choice_touch.custom_minimum_size.y = 46
	_choice_touch.pressed.connect(_start_new_game.bind(true))
	column.add_child(_choice_touch)
	_choice_back = Button.new()
	_choice_back.custom_minimum_size.y = 30
	_choice_back.pressed.connect(func() -> void:
		_control_choice.hide()
		_play.grab_focus()
	)
	column.add_child(_choice_back)
	_control_choice.hide()
	Settings.language_changed.connect(_update_choice_language)
	_update_choice_language(Settings.lang)


func _update_choice_language(_lang: String) -> void:
	if _choice_title == null:
		return
	_choice_title.text = Settings.text("controls.choose")
	_choice_help.text = Settings.text("controls.overwrite") if RunSession.has_game() else Settings.text("controls.later")
	_choice_keyboard.text = Settings.text("controls.keyboard")
	_choice_touch.text = Settings.text("controls.touchscreen")
	_choice_back.text = Settings.text("common.back")


## Build marker makes it easy to tell an old export from this updated source.
func _build_build_stamp() -> void:
	var stamp := Label.new()
	stamp.name = "BuildStamp"
	stamp.text = ""
	stamp.add_theme_font_size_override("font_size", 11)
	stamp.add_theme_color_override("font_color", Palette.CREMA)
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	add_child(stamp)
	stamp.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	stamp.offset_left = -176.0
	stamp.offset_top = -20.0
	stamp.offset_right = -5.0
	stamp.offset_bottom = -3.0


func _open_nasa() -> void:
	_how_panel.visible = false
	_credits_panel.visible = false
	_options.close()
	_set_menu_focus(false)
	_nasa.modulate.a = 0.0
	_nasa.open()
	UiMotion.fade_in(_nasa)
	_nasa.back_button().grab_focus()


func _on_options() -> void:
	_how_panel.visible = false
	_credits_panel.visible = false
	_options.open()


func _on_options_closed() -> void:
	_play.grab_focus()


func _open(panel: Control, back: Button) -> void:
	_how_panel.visible = false
	_credits_panel.visible = false
	_options.close()
	_set_menu_focus(false)
	panel.modulate.a = 0.0
	panel.visible = true
	UiMotion.fade_in(panel)
	back.grab_focus()


func _close(panel: Control) -> void:
	if not panel.visible:
		return
	UiMotion.fade_out(panel, func() -> void:
		panel.visible = false
		panel.modulate.a = 1.0
		_set_menu_focus(true)
		_play.grab_focus()
	)


func _menu_buttons() -> Array[Button]:
	var buttons: Array[Button] = [_play, _continue, %OptionsButton, %How, %Nasa, %Credits]
	if _quit.visible:
		buttons.append(_quit)
	return buttons


func _focus_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for button in _menu_buttons():
		if button.visible and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			buttons.append(button)
	return buttons


func _set_menu_focus(enabled: bool) -> void:
	var mode := Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	for button in _menu_buttons():
		if not button.disabled:
			button.focus_mode = mode
	_continue.focus_mode = Control.FOCUS_NONE if _continue.disabled else mode


func _wire_menu_focus() -> void:
	var buttons := _focus_buttons()
	for i in buttons.size():
		var up := buttons[i - 1] if i > 0 else buttons[i]
		var down := buttons[i + 1] if i + 1 < buttons.size() else buttons[i]
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(up)
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(down)
		buttons[i].focus_neighbor_left = buttons[i].get_path_to(buttons[i])
		buttons[i].focus_neighbor_right = buttons[i].get_path_to(buttons[i])


func _wire_overlay_focus() -> void:
	%HowBack.focus_neighbor_top = %HowBack.get_path_to(%HowBack)
	%HowBack.focus_neighbor_bottom = %HowBack.get_path_to(%HowBack)
	%HowBack.focus_neighbor_left = %HowBack.get_path_to(%HowBack)
	%HowBack.focus_neighbor_right = %HowBack.get_path_to(%HowBack)
	var scroll: Control = %CreditsScroll
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.focus_neighbor_top = scroll.get_path_to(scroll)
	scroll.focus_neighbor_bottom = scroll.get_path_to(%CreditsBack)
	%CreditsBack.focus_neighbor_top = %CreditsBack.get_path_to(scroll)
	%CreditsBack.focus_neighbor_bottom = %CreditsBack.get_path_to(%CreditsBack)
	%CreditsBack.focus_neighbor_left = %CreditsBack.get_path_to(%CreditsBack)
	%CreditsBack.focus_neighbor_right = %CreditsBack.get_path_to(%CreditsBack)


func _style_links() -> void:
	var empty := StyleBoxEmpty.new()
	for button in _menu_buttons():
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, empty)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_color_override("font_color", Palette.CREMA)
		button.add_theme_color_override("font_hover_color", Palette.NARANJA)
		button.add_theme_color_override("font_pressed_color", Palette.NARANJA)
		button.add_theme_color_override("font_focus_color", Palette.ORO)
		button.add_theme_color_override("font_disabled_color", Palette.METAL)
		button.add_theme_color_override("font_outline_color", Palette.CONTORNO)
		button.add_theme_constant_override("outline_size", 1)


func _build_cursor() -> void:
	_cursor = Control.new()
	_cursor.name = "Cursor"
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.custom_minimum_size = Vector2(8, 8)
	_cursor.size = Vector2(8, 8)
	_cursor.draw.connect(func() -> void:
		_cursor.draw_colored_polygon(PackedVector2Array([
			Vector2(0, 0), Vector2(0, 8), Vector2(7, 4),
		]), Palette.SOMBRA)
		_cursor.draw_colored_polygon(PackedVector2Array([
			Vector2(1, 1), Vector2(1, 7), Vector2(6, 4),
		]), Palette.NARANJA)
	)
	add_child(_cursor)


func _place_cursor() -> void:
	if _cursor == null:
		return
	if _how_panel.visible or _credits_panel.visible or _options.visible or (_control_choice != null and _control_choice.visible) or (_nasa != null and _nasa.visible):
		_cursor.hide()
		return
	var owner := get_viewport().gui_get_focus_owner() as Button
	if owner == null or owner not in _focus_buttons():
		_cursor.hide()
		return
	var blink := int(Time.get_ticks_msec() / 380) % 2 == 0
	_cursor.visible = blink
	_cursor.global_position = owner.global_position + Vector2(-12, 6)
