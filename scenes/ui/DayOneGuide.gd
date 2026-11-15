extends CanvasLayer
## First-run INTI walkthrough: resource bars, then movement and mission controls.
## Each line waits for the action. Skip, or Options → Replay tutorial, starts it again.
## These lines do not spend INTI's two automatic warnings per day.

const BARS_OXYGEN := 0
const BARS_ENERGY := 1
const BARS_SHIELDING := 2
const MOVE := 3
const MARK := 4
const ACT := 5
const LOOK := 6
const LAMP := 7

const BOX_TIME := 4.2
const REMIND := 8.0
const FONT: Font = preload("res://assets/fonts/m5x7.ttf")

var _step := BARS_OXYGEN
var _armed := false
var _listen := false
var _done := false
var _waited := 0.0
var _box_time := 0.0
var _hidden_for := 0.0
var _device := "key"
var _replaying := false
var _resource_only := false
var _skip: Button
var _hint_snooze := 0.0
var _callout_layer: Control
var _callout_panel: PanelContainer
var _callout_label: Label
var _callout_target := Rect2()
var _callout_visible := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 37
	if get_tree().current_scene != get_parent():
		queue_free()
		return
	add_to_group(&"day_one_guide")
	_skip = Button.new()
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.theme = preload("res://ui/theme/condor_theme.tres")
	_skip.custom_minimum_size = Vector2(84, 28)
	_skip.pressed.connect(_on_skip)
	_skip.hide()
	add_child(_skip)
	_build_callout()
	Settings.language_changed.connect(_on_language)
	Settings.tutorial_replay.connect(_on_replay)
	_on_language(Settings.lang)
	if Settings.tutorial_done:
		if Settings.resource_intro_done:
			_done = true
		else:
			_resource_only = true


func _exit_tree() -> void:
	if Settings.language_changed.is_connected(_on_language):
		Settings.language_changed.disconnect(_on_language)
	if Settings.tutorial_replay.is_connected(_on_replay):
		Settings.tutorial_replay.disconnect(_on_replay)


func _process(delta: float) -> void:
	_place_skip()
	if _done or GameState.run_over:
		if _skip != null:
			_skip.hide()
		_hide_callout()
		return
	_waited += delta
	_hint_snooze = maxf(_hint_snooze - delta, 0.0)
	if _skip != null:
		var ready := DayNightSystem.has_started() and not BasePlacer.active and not Cutscenes.is_playing()
		_skip.visible = ready and _replaying
	var panel := _panel()
	if panel == null:
		_hide_callout()
		return
	if _listen:
		if _acted():
			_advance()
			return
		if _show_local_callout():
			_hidden_for = 0.0
			var device := TouchControls.prompt_device()
			if device != _device:
				_device = device
				_box_time = 0.0
				_refresh_prompt()
			else:
				_box_time += delta
				_refresh_callout()
				if _box_time >= BOX_TIME:
					if _step <= BARS_SHIELDING:
						_advance()
						return
					_hide_callout()
		elif panel.is_hold():
			_hidden_for = 0.0
			var device_hold := TouchControls.prompt_device()
			if device_hold != _device:
				_device = device_hold
				panel.show_hold(_line())
				_box_time = 0.0
			else:
				_box_time += delta
				if _box_time >= BOX_TIME:
					if _step <= BARS_SHIELDING:
						_advance()
						return
					panel.dismiss_hold()
			_hide_callout()
		else:
			_hidden_for += delta
			if _hidden_for >= REMIND and _nudge():
				_device = TouchControls.prompt_device()
				_box_time = 0.0
				_hidden_for = 0.0
				_refresh_prompt()
			else:
				_hide_callout()
		return
	_hide_callout()
	if _can_show():
		_show()


func _input(event: InputEvent) -> void:
	if _done or not _armed or (_step != LOOK and _step > BARS_SHIELDING):
		return
	var point := Vector2(INF, INF)
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed:
		point = touch.position
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		point = mouse.position
	if not point.is_finite():
		return
	var ring := get_tree().root.find_child("ResourceRing", true, false)
	if ring != null and ring.has_method(&"covers_resource") and ring.call(&"covers_resource", point):
		_advance()


func _can_show() -> bool:
	if TouchControls.is_coaching() or _hint_snooze > 0.0 or get_tree().paused or BasePlacer.active or Cutscenes.is_playing():
		return false
	if not DayNightSystem.has_started():
		return false
	if not _replaying and _step == LAMP and DayNightSystem.night_amount() <= 0.35:
		return false
	if not GameState.has_flag(&"inti_arrived") and _waited < 8.0:
		return false
	return _idle()


func _idle() -> bool:
	var panel := _panel()
	if panel == null or panel.is_hold():
		return false
	if IntiBrain.ui_busy or IntiBrain.is_busy():
		return false
	return not panel.box.is_open()


func _nudge() -> bool:
	if get_tree().paused or BasePlacer.active or Cutscenes.is_playing() or TouchControls.is_coaching():
		return false
	var panel := _panel()
	if panel == null or panel.box.is_open() or IntiBrain.ui_busy or IntiBrain.is_busy():
		return false
	return true


func _show() -> void:
	var panel := _panel()
	if panel == null:
		return
	_device = TouchControls.prompt_device()
	_listen = true
	_armed = true
	_box_time = 0.0
	_hidden_for = 0.0
	_refresh_prompt()
	_skip.text = Settings.text("tutorial.next") if _replaying else Settings.text("tutorial.skip")
	_skip.visible = _replaying


func _acted() -> bool:
	if _replaying:
		return Input.is_action_just_pressed(&"interact") or Input.is_action_just_pressed(&"inti")
	match _step:
		BARS_OXYGEN, BARS_ENERGY, BARS_SHIELDING:
			return Input.is_action_just_pressed(&"interact")
		MOVE:
			return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down").length() > 0.25
		MARK:
			var goal := MissionSystem.goal_world()
			var player := get_tree().get_first_node_in_group(&"player") as Node2D
			return goal.is_finite() and player != null and player.global_position.distance_to(goal) < 72.0
		ACT, LOOK:
			return Input.is_action_just_pressed(&"interact")
		LAMP:
			return DayNightSystem.night_amount() > 0.35 and Input.is_action_just_pressed(&"flashlight")
	return false


func _advance() -> void:
	if not _listen and not _armed:
		return
	_armed = false
	_listen = false
	_box_time = 0.0
	_hide_callout()
	var panel := _panel()
	if panel != null:
		panel.dismiss_hold()
	_step += 1
	if _step > LAMP or (_resource_only and _step > BARS_SHIELDING):
		_finish()


func _finish() -> void:
	_done = true
	_replaying = false
	_armed = false
	_listen = false
	_hide_callout()
	_skip.hide()
	var panel := _panel()
	if panel != null and panel.is_hold():
		panel.dismiss_hold()
	Settings.complete_resource_intro()
	Settings.complete_tutorial()


func _on_skip() -> void:
	if _replaying:
		_advance() # Next: skip requirements like finding a long-finished objective.
	else:
		_finish()


func snooze_for_inti() -> void:
	# TAB opens INTI without the tutorial immediately reclaiming the same dialog.
	_hint_snooze = 12.0
	_armed = false
	_listen = false
	_box_time = 0.0
	_hide_callout()


func _on_replay() -> void:
	_replaying = true
	_resource_only = false
	_done = false
	_step = BARS_OXYGEN
	_armed = false
	_listen = false
	_box_time = 0.0
	_hidden_for = 0.0
	_waited = 8.0
	_hint_snooze = 0.0
	_hide_callout()
	var panel := _panel()
	if panel != null and panel.is_hold():
		panel.dismiss_hold()


func _on_language(_lang: String) -> void:
	_skip.text = Settings.text("tutorial.next") if _replaying else Settings.text("tutorial.skip")
	if _armed:
		_refresh_prompt()


func _line() -> String:
	if _step <= BARS_SHIELDING:
		return Settings.text("tutorial.bars.%s" % _kind())
	var kind := "mark_main" if _step == MARK and _shown_is_main() else _kind()
	return Settings.text("tutorial.%s.%s" % [kind, _device])


func _kind() -> String:
	match _step:
		BARS_OXYGEN:
			return "oxygen"
		BARS_ENERGY:
			return "energy"
		BARS_SHIELDING:
			return "shielding"
		MOVE:
			return "move"
		MARK:
			return "mark"
		ACT:
			return "act"
		LOOK:
			return "look"
		_:
			return "lamp"


func _shown_is_main() -> bool:
	var id := MissionSystem.get_shown()
	return id != &"" and MissionSystem.get_category(id) == "main"


func _panel() -> IntiPanel:
	return get_tree().get_first_node_in_group(&"inti_panel") as IntiPanel


func _place_skip() -> void:
	if _skip == null:
		return
	# Replay-only control; regular gameplay never displays the big 'Saltar' button.
	var view := get_viewport().get_visible_rect().size
	_skip.position = Vector2(maxf(8.0, view.x - 100.0), maxf(8.0, view.y - 120.0))
	_skip.size = Vector2(90, 28)


func _show_local_callout() -> bool:
	return _device == "key" and _step in [BARS_OXYGEN, BARS_ENERGY, BARS_SHIELDING, LOOK]


func _refresh_prompt() -> void:
	var panel := _panel()
	if panel == null:
		return
	if _show_local_callout() and _refresh_callout():
		panel.dismiss_hold()
		return
	_hide_callout()
	panel.show_hold(_line())


func _build_callout() -> void:
	_callout_layer = Control.new()
	_callout_layer.name = "KeyboardGuideCallout"
	_callout_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_callout_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_callout_layer.visible = false
	_callout_layer.draw.connect(_draw_callout)
	add_child(_callout_layer)
	_callout_panel = PanelContainer.new()
	_callout_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.051, 0.071, 0.11, 0.90)
	style.border_color = Color(Palette.INTI, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(4)
	style.anti_aliasing = false
	_callout_panel.add_theme_stylebox_override("panel", style)
	_callout_layer.add_child(_callout_panel)
	_callout_label = Label.new()
	_callout_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := LabelSettings.new()
	look.font = FONT
	look.font_size = 16
	look.font_color = Palette.CREMA
	look.outline_size = 1
	look.outline_color = Palette.ESPACIO
	_callout_label.label_settings = look
	_callout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_callout_label.custom_minimum_size = Vector2(188, 0)
	_callout_panel.add_child(_callout_label)


func _refresh_callout() -> bool:
	var ring := get_tree().root.find_child("ResourceRing", true, false)
	if ring == null or not ring.has_method(&"resource_rect"):
		_hide_callout()
		return false
	var target_id: StringName = &""
	match _step:
		BARS_OXYGEN, LOOK:
			target_id = &"oxygen"
		BARS_ENERGY:
			target_id = &"energy"
		BARS_SHIELDING:
			target_id = &"shielding"
		_:
			target_id = &""
	if target_id == &"":
		_hide_callout()
		return false
	var target: Rect2 = ring.call(&"resource_rect", target_id)
	if target.size.x <= 0.0 or target.size.y <= 0.0:
		_hide_callout()
		return false
	_callout_target = target
	_callout_label.text = _line()
	var view := get_viewport().get_visible_rect().size
	var size_hint := _callout_label.get_minimum_size() + Vector2(16.0, 10.0)
	var width := clampf(maxf(size_hint.x, 196.0), 196.0, minf(252.0, maxf(196.0, view.x - 24.0)))
	var height := maxf(size_hint.y, 44.0)
	_callout_panel.size = Vector2(width, height)
	var x := target.position.x - width - 10.0
	if x < 6.0:
		x = target.end.x + 10.0
	var y := clampf(target.get_center().y - height * 0.5, 6.0, maxf(6.0, view.y - height - 6.0))
	_callout_panel.position = Vector2(clampf(x, 6.0, maxf(6.0, view.x - width - 6.0)), y)
	_callout_visible = true
	_callout_layer.visible = true
	_callout_layer.queue_redraw()
	return true


func _hide_callout() -> void:
	_callout_visible = false
	if _callout_layer != null:
		_callout_layer.visible = false
		_callout_layer.queue_redraw()


func _draw_callout() -> void:
	if not _callout_visible:
		return
	var focus := _callout_target.grow(4.0)
	_callout_layer.draw_rect(focus, Color(1.0, 0.878, 0.0, 0.22), true)
	_callout_layer.draw_rect(focus, Color(1.0, 0.878, 0.0, 1.0), false, 2.0)
	var bubble := _callout_panel.get_global_rect()
	var from := Vector2.ZERO
	if bubble.get_center().x < focus.get_center().x:
		from = Vector2(bubble.end.x, clampf(focus.get_center().y, bubble.position.y + 6.0, bubble.end.y - 6.0))
	else:
		from = Vector2(bubble.position.x, clampf(focus.get_center().y, bubble.position.y + 6.0, bubble.end.y - 6.0))
	var to := focus.get_center()
	_callout_layer.draw_line(from, to, Color(1.0, 0.878, 0.0, 1.0), 2.0)
	var dir := (to - from).normalized()
	var tip_a := to - dir * 8.0 + Vector2(-dir.y, dir.x) * 4.0
	var tip_b := to - dir * 8.0 + Vector2(dir.y, -dir.x) * 4.0
	_callout_layer.draw_colored_polygon(PackedVector2Array([to, tip_a, tip_b]), Color(1.0, 0.878, 0.0, 1.0))
