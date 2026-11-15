extends Node2D
## A short Mars briefing, then the arrival film (about 38 s).
## Continuar advances the briefing. Esc, Start, or a click skips it into the film.
## The same input skips the film into the main mission scene. The map flag stays
## even if the film is skipped. The base uses the predetermined default kit.

const NEXT_SCENE := "res://scenes/Main.tscn"
const THEME := preload("res://ui/theme/condor_theme.tres")
const SKIP_LOCK_MSEC := 400
const TITLE_COLOR := Color(1, 0.878431, 0, 1)
const BRIEF_PAGES: Array[String] = ["intro.brief.mars", "intro.brief.goals"]
const BRIEF_TITLES: Array[String] = ["intro.brief.mars_title", "intro.brief.goals_title"]
## The briefing is the game's own copy, not INTI.
const BRIEF_STEP := 0.022
const CONTINUE_DELAY := 1.5

var _done := false
var _briefing := true
var _page := 0
var _ready_msec := 0

var _brief_layer: CanvasLayer
var _brief_title: Label
var _brief_body: Label
var _brief_hint: Label
var _brief_next: Button
var _type_text := ""
var _typed := 0
var _type_left := 0.0
var _typing := false
var _continue_left := 0.0

@onready var _caption: Label = %Caption
@onready var _inti: IntiBox = $UI/Root/IntiBubble
@onready var _astronaut: AnimatedSprite2D = %Astronaut
@onready var _player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_ready_msec = Time.get_ticks_msec()
	if _player.is_playing():
		_player.stop()
	_spawn_stars(%StarsFar, 72, 1.0, 860.0, 2040)
	_spawn_stars(%StarsNear, 34, 2.0, 1140.0, 7)
	_player.animation_finished.connect(_on_animation_finished)
	_build_brief()
	AudioManager.play_context("intro")
	Settings.language_changed.connect(_on_language)
	_on_language(Settings.lang)
	_fit_backdrops()
	get_viewport().size_changed.connect(_fit_backdrops)


func _fit_backdrops() -> void:
	var rect := get_viewport().get_visible_rect().size
	for path in ["Letterbox", "Shots/ShotEarth/Sky", "Shots/ShotEarth/SkyHorizon", "Shots/ShotSpace/Space", "Shots/ShotMars/Sky", "Shots/ShotMars/Horizon", "Shots/ShotMars/Ground", "Shots/ShotMars/GroundEdge"]:
		var node := get_node_or_null(path) as ColorRect
		if node != null:
			node.size.x = rect.x

func _on_language(_lang: String) -> void:
	if _briefing:
		%SkipHint.text = Settings.text("intro.brief.skip")
		_show_page()
	else:
		%SkipHint.text = Settings.text("intro.skip")


func _process(delta: float) -> void:
	if _brief_body == null or not _briefing:
		return
	if _typing:
		_type_left += delta
		while _type_left >= BRIEF_STEP and _typed < _type_text.length():
			_type_left -= BRIEF_STEP
			_typed += 1
		_brief_body.visible_characters = _typed
		if _typed < _type_text.length():
			return
		_typing = false
		_continue_left = CONTINUE_DELAY
		return
	if _continue_left <= 0.0:
		return
	_continue_left = maxf(0.0, _continue_left - delta)
	if _continue_left <= 0.0 and _brief_next != null:
		_brief_next.visible = true
		_brief_next.disabled = false
		_brief_next.grab_focus()


func _input(event: InputEvent) -> void:
	if _briefing or _done or Time.get_ticks_msec() - _ready_msec < SKIP_LOCK_MSEC:
		return
	if event.is_action_pressed(&"pause") or _is_click(event):
		get_viewport().set_input_as_handled()
		finish_intro()


func _unhandled_input(event: InputEvent) -> void:
	if not _briefing or _done or Time.get_ticks_msec() - _ready_msec < SKIP_LOCK_MSEC:
		return
	if event.is_action_pressed(&"pause") or _is_click(event):
		get_viewport().set_input_as_handled()
		_start_film()


## AnimationPlayer method track. The text is a Settings key (intro.*) or a raw line.
func show_caption(text: String) -> void:
	_caption.text = _line(text)


func hide_caption() -> void:
	_caption.text = ""


func show_inti(text: String) -> void:
	_inti.present(text, "", 0.02, false)


func hide_inti() -> void:
	_inti.dismiss()


func play_walk() -> void:
	_astronaut.play(&"walk_right")


func plant_flag() -> void:
	_astronaut.play(&"interact_right")
	if not _astronaut.animation_finished.is_connected(_on_flag_planted):
		_astronaut.animation_finished.connect(_on_flag_planted, CONNECT_ONE_SHOT)


func finish_intro() -> void:
	if _done:
		return
	_done = true
	_briefing = false
	if _player.is_playing():
		_player.stop()
	if GameState.start_modules.is_empty():
		GameState.use_default_kit()
	SceneFade.change_scene(NEXT_SCENE)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"intro":
		finish_intro()


func _on_flag_planted() -> void:
	if _done or not is_instance_valid(_astronaut):
		return
	_astronaut.play(&"idle_right")


func _advance_brief() -> void:
	if _typing or _continue_left > 0.0 or _brief_next == null or not _brief_next.visible or _brief_next.disabled:
		return
	if Time.get_ticks_msec() - _ready_msec < SKIP_LOCK_MSEC:
		return
	_page += 1
	if _page >= BRIEF_PAGES.size():
		_start_film()
		return
	_show_page()


func _start_film() -> void:
	if _done or not _briefing or Time.get_ticks_msec() - _ready_msec < SKIP_LOCK_MSEC:
		return
	_briefing = false
	_typing = false
	_continue_left = 0.0
	%SkipHint.text = Settings.text("intro.skip")
	if _brief_layer != null:
		_brief_layer.queue_free()
		_brief_layer = null
	if not _player.is_playing():
		_player.play(&"intro")


func _show_page() -> void:
	if _brief_title == null:
		return
	var page := clampi(_page, 0, BRIEF_PAGES.size() - 1)
	_brief_title.text = Settings.text(BRIEF_TITLES[page])
	_type_text = Settings.text(BRIEF_PAGES[page])
	_typed = 0
	_type_left = 0.0
	_brief_body.text = _type_text
	_brief_body.visible_characters = 0 if not _type_text.is_empty() else -1
	_typing = not _type_text.is_empty()
	_continue_left = 0.0 if _typing else CONTINUE_DELAY
	_brief_next.visible = false
	_brief_next.disabled = true
	_brief_next.text = Settings.text("intro.brief.next")
	_brief_hint.text = Settings.text("intro.brief.skip")


func _build_brief() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Briefing"
	layer.layer = 20
	add_child(layer)
	_brief_layer = layer

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = THEME
	root.gui_input.connect(func(event: InputEvent) -> void:
		if _is_click(event):
			root.accept_event()
			_start_film()
	)
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.102, 0.047, 0.078, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	_brief_title = Label.new()
	_brief_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brief_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brief_title.add_theme_color_override("font_color", TITLE_COLOR)
	_brief_title.add_theme_font_size_override("font_size", 32)
	column.add_child(_brief_title)

	_brief_body = Label.new()
	_brief_body.custom_minimum_size = Vector2(560, 0)
	_brief_body.add_theme_font_size_override("font_size", 20)
	_brief_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_brief_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brief_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_brief_body)

	_brief_next = Button.new()
	_brief_next.custom_minimum_size = Vector2(160, 40)
	_brief_next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_brief_next.pressed.connect(_advance_brief)
	column.add_child(_brief_next)

	_brief_hint = Label.new()
	_brief_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brief_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_brief_hint)

	_show_page()
	root.modulate.a = 0.0
	UiMotion.fade_in(root)


func _line(text: String) -> String:
	if text.begins_with("intro."):
		return Settings.text(text)
	return text


func _is_click(event: InputEvent) -> bool:
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT


func _spawn_stars(layer: Node2D, count: int, size: float, span: float, seed_id: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_id
	for _i in count:
		var star := ColorRect.new()
		var px := size if rng.randf() > 0.22 else size + 1.0
		star.size = Vector2(px, px)
		star.position = Vector2(rng.randf_range(-32.0, span), rng.randf_range(4.0, 350.0))
		star.color = Color("FFFCE8") if rng.randf() > 0.16 else Color("B8F4FF")
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(star)
