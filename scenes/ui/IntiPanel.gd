class_name IntiPanel
extends CanvasLayer
## Hosts the shared INTI box. Tab asks for a hint, finishes the typewriter, or closes the line.
## Arrival and danger use the same box. They do not take the E key from modules.

const HINT_STEP := 0.014
const AUTO_STEP := 0.015

var _toast := false
var _hold := false
var _advance_frame := -1
var _toast_left := 0.0
var _compact := false
var _map_inset := -1.0

const MAP_MARGIN := 6.0
const MAP_GAP := 8.0

@onready var box: IntiBox = $Box
@onready var call_hint: Label = $CallHint


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"inti_panel")
	box.panel_pressed.connect(_on_panel_pressed)
	box.close_pressed.connect(_on_close_pressed)
	box.typing_finished.connect(_on_typing_finished)
	_apply_language("")
	var hint_style := LabelSettings.new()
	hint_style.font = preload("res://assets/fonts/m5x7.ttf")
	hint_style.font_size = 16
	hint_style.font_color = Palette.CREMA
	hint_style.outline_size = 1
	hint_style.outline_color = Palette.ESPACIO
	call_hint.label_settings = hint_style
	call_hint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	call_hint.scale = Vector2.ONE
	var hint_back := StyleBoxFlat.new()
	hint_back.bg_color = Color(0.051, 0.071, 0.11, 0.84)
	hint_back.content_margin_left = 4
	hint_back.content_margin_right = 4
	hint_back.content_margin_top = 1
	hint_back.content_margin_bottom = 2
	hint_back.set_corner_radius_all(2)
	hint_back.anti_aliasing = false
	call_hint.add_theme_stylebox_override("normal", hint_back)
	Settings.language_changed.connect(_apply_language)
	IntiBrain.line_ready.connect(_on_line)
	IntiBrain.auto_line.connect(_on_auto)
	IntiBrain.bind_panel()


func _exit_tree() -> void:
	IntiBrain.typing = false
	IntiBrain.ui_busy = false
	if IntiBrain.line_ready.is_connected(_on_line):
		IntiBrain.line_ready.disconnect(_on_line)
	if IntiBrain.auto_line.is_connected(_on_auto):
		IntiBrain.auto_line.disconnect(_on_auto)
	IntiBrain.unbind_panel()


func _process(delta: float) -> void:
	visible = not Cutscenes.is_playing()
	if not visible:
		return
	var compact := DayNightSystem.is_journal_open()
	if compact != _compact:
		_compact = compact
		_map_inset = -1.0
		box.set_compact(compact)
	if not _compact and box.is_open():
		var inset := _panel_right_inset()
		if absf(inset - _map_inset) > 0.5:
			_map_inset = inset
			box.set_right_inset(inset)
	if not box.is_open():
		call_hint.visible = not BasePlacer.active and not compact
		if call_hint.visible:
			_apply_language("")
		return
	call_hint.hide()
	if _toast and not _hold and _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_close()


func _input(event: InputEvent) -> void:
	if Cutscenes.is_playing() or event.is_echo():
		return
	if get_tree().paused and not DayNightSystem.is_journal_open():
		return
	if event.is_action_pressed(&"inti"):
		# A tutorial hold must not permanently disable TAB/INTI.
		if _hold:
			dismiss_hold()
			var guide := get_tree().get_first_node_in_group(&"day_one_guide")
			if guide != null and guide.has_method(&"snooze_for_inti"):
				guide.call(&"snooze_for_inti")
			if not get_tree().paused:
				IntiBrain.ask_hint()
			get_viewport().set_input_as_handled()
			return
		if not box.is_open() and not get_tree().paused and not GameState.run_over:
			IntiBrain.ask_hint()
			get_viewport().set_input_as_handled()
			return
		if _toast and box.is_open():
			if box.is_done():
				_close()
			else:
				box.finish_typing()
			get_viewport().set_input_as_handled()
			return
	if _hold or not box.is_open() or _toast:
		return
	if not _is_advance(event):
		return
	# A touch may also become a mouse click. One frame, one advance.
	if _advance_frame == Engine.get_process_frames():
		get_viewport().set_input_as_handled()
		return
	_advance_frame = Engine.get_process_frames()
	if box.is_done():
		_close()
	else:
		box.finish_typing()
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# TAB is now handled in _input so a GUI does not randomly swallow it.
	pass


func show_line(text: String, tip: String) -> void:
	_hold = false
	_toast = false
	_toast_left = 0.0
	_begin(text, tip, true, HINT_STEP)


func show_toast(text: String) -> void:
	_hold = false
	_toast = true
	_toast_left = 0.0
	_begin(text, "", false, AUTO_STEP)


## A tutorial line in this same box. It stays until dismiss_hold and does not take E or the daily cap.
func show_hold(text: String) -> void:
	_hold = true
	_toast = false
	_toast_left = 0.0
	_begin(text, "", false, AUTO_STEP)


func is_hold() -> bool:
	return _hold


func dismiss_hold() -> void:
	if not _hold:
		return
	_hold = false
	if box.is_open():
		box.dismiss()
	IntiBrain.typing = false
	IntiBrain.ui_busy = false
	call_hint.visible = not BasePlacer.active


## Pixels from the bottom of the screen that the hotbar should stay above.
func bottom_reserve() -> float:
	if box != null and box.is_open() and not box.is_compact() and box.panel != null:
		return box.bottom_margin + box.panel.size.y + 6.0
	return 28.0


func _begin(text: String, tip: String, capture: bool, step: float) -> void:
	IntiBrain.typing = capture
	IntiBrain.ui_busy = true
	if not _compact:
		box.set_right_inset(_panel_right_inset())
	box.set_compact(_compact)
	box.present(text, tip, step, capture)
	call_hint.hide()


func _close() -> void:
	if not box.is_open():
		return
	if not _toast and not box.is_done():
		return
	var was_toast := _toast
	_toast = false
	_toast_left = 0.0
	box.dismiss()
	IntiBrain.typing = false
	call_hint.show()
	if was_toast:
		IntiBrain.notify_auto_closed()
	else:
		IntiBrain.notify_closed()


func _on_auto(text: String) -> void:
	show_toast(text)


func _on_line(text: String, tip: String) -> void:
	show_line(text, tip)


func _on_close_pressed() -> void:
	_close()


func _on_panel_pressed() -> void:
	if _toast:
		return
	if box.is_done():
		_close()
	else:
		box.finish_typing()


func _on_typing_finished() -> void:
	IntiBrain.typing = false
	if _toast:
		_toast_left = IntiBrain.toast_seconds


func _is_advance(event: InputEvent) -> bool:
	if event.is_action_pressed(&"inti") or event.is_action_pressed(&"interact"):
		return true
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed and box.panel != null and box.panel.get_global_rect().has_point(touch.position):
		return true
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT


func _apply_language(_lang: String) -> void:
	var touch := TouchControls != null and TouchControls.has_method(&"prompt_device") and TouchControls.prompt_device() == "touch"
	var hint := Settings.text("inti.tab_touch") if touch else Settings.text("inti.tab")
	if call_hint.text != hint or call_hint.size.x > call_hint.get_combined_minimum_size().x + 0.5:
		call_hint.text = hint
		call_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var fit := call_hint.get_combined_minimum_size()
		call_hint.offset_left = 8.0
		call_hint.offset_right = 8.0 + fit.x
		call_hint.offset_bottom = -4.0
		call_hint.offset_top = -4.0 - fit.y


func _panel_right_inset() -> float:
	if _compact:
		return 8.0
	var map := get_tree().root.find_child("Minimap", true, false) as Control
	if map == null or not map.visible:
		return 8.0
	var side := map.size.x
	if side < 40.0:
		side = 80.0
	return MAP_MARGIN + side + MAP_GAP
