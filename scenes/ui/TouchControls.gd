extends CanvasLayer
## On-screen controls. They only feed the actions the rest of the game already reads.
## Auto shows them on a touch screen, hides them when a key or a pad is used, and
## brings them back on the next touch. Yes forces them. No hides them.
##
## Landscape play shows a joystick on the left and a short cluster on the right:
## sprint, jump, flashlight, interact, a small pause, and + for the rest.
## INTI, the map and mission selection stay behind +.
## Position and size live in an edit mode opened from Options, not on the play screen.

signal arrange_finished

const PRIMARY: Array[String] = ["sprint", "jump", "flashlight", "interact", "pause"]
const SECONDARY: Array[String] = ["inti", "minimap", "cycle_mission"]
const HOLD := {
	&"interact": true,
	&"sprint": true,
}
const STATE_TAP := {
	&"jump": true,
	&"flashlight": true,
}
const EVENT_TAP := {
	&"pause": true,
	&"minimap": true,
	&"inti": true,
	&"cycle_mission": true,
}
const FONT: Font = preload("res://assets/fonts/m5x7.ttf")
## Shrink the touch-only control surfaces by 15%; user scale settings still apply.
const TOUCH_SIZE_MULTIPLIER := 0.85

var _saw_touch := false
var _physical := false
var _last_kind := "key"
var _pads_visible := false
var _stick_finger := -1
var _fingers: Dictionary = {}
var _virtual: Dictionary = {}
var _release_state: Dictionary = {}
var _release_event: Array[StringName] = []

var _root: Control
var _stick: Stick
var _more: Pad
var _pads: Dictionary = {}
var _rotate: CanvasLayer
var _rotate_label: Label
var _hint: Label
var _edit: TextPad
var _reset: TextPad
var _smaller: TextPad
var _larger: TextPad
var _scale_display: Label
var _selected_edit := "stick"
var _secondary_open := false
var _laying := false

## Five taps: move, interact, sprint, pause, and how to open the rest.
const TOUR_ITEMS: Array[String] = ["stick", "interact", "sprint", "pause", "more"]
var _tour_index := 0
var _tour_active := false
var _coach_panel: PanelContainer
var _coach_label: Label
var _coach_close: Button

var _editing := false
var _was_paused := false
var _drag_finger := -1
var _drag_id := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 18
	_build()
	_build_rotate()
	if not Settings.touch_changed.is_connected(_refresh):
		Settings.touch_changed.connect(_refresh)
	if not Settings.language_changed.is_connected(_on_language):
		Settings.language_changed.connect(_on_language)
	if not Settings.touch_layout_changed.is_connected(_on_layout_changed):
		Settings.touch_layout_changed.connect(_on_layout_changed)
	if not Settings.tutorial_replay.is_connected(_on_tutorial_replay):
		Settings.tutorial_replay.connect(_on_tutorial_replay)
	_on_language(Settings.lang)
	_refresh()


func is_coaching() -> bool:
	return _tour_active and _pads_visible and not _editing


func prompt_device() -> String:
	if _pads_visible:
		return "touch"
	if _last_kind == "pad":
		return "pad"
	return "key"


## Pause → Options asks for this. The tree stays paused until SAVE.
func begin_arrange() -> void:
	_physical = false
	_start_editing()
	_refresh()


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_saw_touch = true
		_physical = false
		_last_kind = "touch"
		# The first touch must enable the pads immediately, not a frame later.
		_refresh()
		if touch.pressed:
			if _press_at(touch.index, touch.position):
				get_viewport().set_input_as_handled()
		elif _release_finger(touch.index):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _move_finger(drag.index, drag.position):
			get_viewport().set_input_as_handled()
		return
	# Mouse may emulate a finger on desktop when controls are explicitly enabled.
	# Do NOT exit the entire handler after a first touchscreen event: a subsequent
	# keyboard press must still switch Auto mode back to keyboard.
	if (not _saw_touch or Settings.touch_mode == "yes") and event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			if _press_at(-2, mouse.position):
				get_viewport().set_input_as_handled()
		elif _release_finger(-2):
			get_viewport().set_input_as_handled()
		return
	if (not _saw_touch or Settings.touch_mode == "yes") and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if _move_finger(-2, (event as InputEventMouseMotion).position):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		_last_kind = "key"
		if Settings.touch_mode != "yes" and not _editing:
			_physical = true
			_release_all()
		return
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		_note_pad()
		return
	if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.55:
		_note_pad()


func _process(_delta: float) -> void:
	for action in _release_event:
		var up := InputEventAction.new()
		up.action = action
		up.pressed = false
		Input.parse_input_event(up)
	_release_event.clear()
	_refresh()


func _physics_process(_delta: float) -> void:
	# A very short tap between physics ticks must still be seen by Player.gd.
	for action in _release_state.keys():
		_release_state[action] = int(_release_state[action]) - 1
		if int(_release_state[action]) <= 0:
			_drop(StringName(action))
			_release_state.erase(action)


func _note_pad() -> void:
	_last_kind = "pad"
	if Settings.touch_mode != "yes" and not _editing:
		_physical = true
		_release_all()


func _touch_context() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if _editing:
		return true
	if Settings.touch_mode == "no":
		return false
	if Settings.touch_mode == "yes":
		return true
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or _saw_touch


func _portrait() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var size := DisplayServer.window_get_size()
	if size.x < 8 or size.y < 8:
		return false
	return size.y > size.x + 4


func _in_play() -> bool:
	if _editing:
		return true
	var scene := get_tree().current_scene
	if scene == null or (scene.scene_file_path != "res://scenes/Main.tscn" and scene.name != "Main"):
		return false
	if get_tree().paused or GameState.run_over or Cutscenes.is_playing():
		return false
	if DayNightSystem.is_journal_open() or DayNightSystem.is_sleep_confirmation_open():
		return false
	return true


func _refresh() -> void:
	if Settings.touch_mode == "yes":
		_physical = false
	var context := _touch_context()
	var turned := context and _portrait()
	if _rotate != null:
		_rotate.visible = turned
	var show := context and not turned and (not _physical or _editing) and _in_play()
	if _root != null:
		_root.visible = show
	if _pads_visible and not show:
		_release_all()
	_pads_visible = show
	if show:
		if not Settings.touch_tutorial_done and not _tour_active and not _editing:
			_tour_active = true
			_tour_index = 0
		_layout()
	elif _coach_panel != null:
		_coach_panel.hide()


func _on_language(_lang: String) -> void:
	if _rotate_label != null:
		_rotate_label.text = Settings.text("touch.rotate")
	if _coach_close != null:
		_coach_close.tooltip_text = Settings.text("touch.tour_close")
	_refresh_edit_labels()
	_refresh_tour()


func _on_layout_changed() -> void:
	if _pads_visible or _editing:
		_layout()


func _refresh_edit_labels() -> void:
	var on := _editing
	if _edit != null:
		_edit.caption = Settings.text("touch.save")
		_edit.visible = on
		_edit.queue_redraw()
	if _reset != null:
		_reset.caption = Settings.text("touch.reset")
		_reset.visible = on
		_reset.queue_redraw()
	if _hint != null:
		_hint.text = Settings.text("touch.edit_hint") if on else ""
		_hint.visible = on
	if _smaller != null:
		_smaller.caption = "-"
		_smaller.visible = on
		_smaller.queue_redraw()
	if _larger != null:
		_larger.caption = "+"
		_larger.visible = on
		_larger.queue_redraw()
	if _scale_display != null:
		_scale_display.text = "%s  %d%%" % [_selected_edit, roundi(Settings.touch_scale(_selected_edit) * 100.0)]
		_scale_display.visible = on


func _press_at(index: int, at: Vector2) -> bool:
	if not _pads_visible:
		return false
	# Clock, dose, minimap and the INTI box keep their own taps.
	if not _editing and _over_hud(at):
		_close_tray()
		return false
	if _is_hit_pad(_edit, at):
		if _editing:
			_stop_editing()
		return true
	if _editing:
		if _is_hit_pad(_reset, at):
			Settings.reset_touch_layout()
			_layout()
			return true
		if _is_hit_pad(_smaller, at):
			_change_scale(-0.1)
			return true
		if _is_hit_pad(_larger, at):
			_change_scale(0.1)
			return true
		_drag_id = _hit_draggable(at)
		if not _drag_id.is_empty():
			_selected_edit = _drag_id
			_refresh_edit_labels()
		_drag_finger = index if not _drag_id.is_empty() else -1
		return not _drag_id.is_empty()
	# During touch onboarding, touching the highlighted pad checks it without
	# accidentally pausing or opening a journal. Other controls remain functional.
	if _tour_active and _tour_index < TOUR_ITEMS.size():
		var target := TOUR_ITEMS[_tour_index]
		var view := _control_rect(target)
		if view.has_point(at):
			_advance_tour()
			return true
		if _coach_close != null and _coach_close.get_global_rect().has_point(at):
			_finish_tour()
			return true
	if _is_hit_pad(_more, at):
		_secondary_open = not _secondary_open
		_layout()
		return true
	if _stick_rect().has_point(at) and _stick_finger == -1:
		_stick_finger = index
		_move_stick(at)
		return true
	var action := _pad_at(at)
	if action == &"":
		_close_tray()
		return false
	if _fingers.values().has(action):
		return true
	_fingers[index] = action
	var pad := _pads.get(action) as Pad
	if pad != null:
		pad.down = true
		pad.queue_redraw()
	if HOLD.has(action):
		_hold(action, true)
	elif STATE_TAP.has(action):
		Input.action_press(action)
		_virtual[action] = true
		_release_state[action] = 3
	elif EVENT_TAP.has(action):
		var down := InputEventAction.new()
		down.action = action
		down.pressed = true
		down.strength = 1.0
		Input.parse_input_event(down)
		_release_event.append(action)
	if not _editing and SECONDARY.has(String(action)):
		_secondary_open = false
		_layout()
	return true


func _close_tray() -> void:
	if not _secondary_open or _editing or _tour_active:
		return
	_secondary_open = false
	_layout()


func _move_finger(index: int, at: Vector2) -> bool:
	if _editing and _drag_finger == index and not _drag_id.is_empty():
		var view := _view_size()
		Settings.set_touch_position(_drag_id, Vector2(at.x / maxf(view.x, 1.0), at.y / maxf(view.y, 1.0)))
		_layout()
		return true
	if index == _stick_finger:
		_move_stick(at)
		return true
	return false


func _release_finger(index: int) -> bool:
	var used := false
	if _drag_finger == index:
		_drag_finger = -1
		_drag_id = ""
		used = true
	if index == _stick_finger:
		_stick_finger = -1
		_apply_move(Vector2.ZERO)
		used = true
	if not _fingers.has(index):
		return used
	var action: StringName = _fingers[index]
	_fingers.erase(index)
	var pad := _pads.get(action) as Pad
	if pad != null:
		pad.down = false
		pad.queue_redraw()
	if HOLD.has(action):
		_hold(action, false)
	return true


func _move_stick(at: Vector2) -> void:
	var center := _stick.get_global_rect().get_center()
	var delta := at - center
	var radius := _stick.size.x * 0.42
	var dir := Vector2.ZERO
	if delta.length() >= radius * 0.22 and radius > 1.0:
		dir = delta.limit_length(radius) / radius
	_apply_move(dir)


func _apply_move(dir: Vector2) -> void:
	_axis(&"move_left", maxf(-dir.x, 0.0))
	_axis(&"move_right", maxf(dir.x, 0.0))
	_axis(&"move_up", maxf(-dir.y, 0.0))
	_axis(&"move_down", maxf(dir.y, 0.0))
	if _stick != null:
		_stick.knob = dir * (_stick.size.x * 0.28)
		_stick.queue_redraw()


func _axis(action: StringName, amount: float) -> void:
	if amount <= 0.02:
		_drop(action)
		return
	Input.action_press(action, amount)
	_virtual[action] = true


func _hold(action: StringName, down: bool) -> void:
	if down:
		Input.action_press(action)
		_virtual[action] = true
	else:
		_drop(action)


func _drop(action: StringName) -> void:
	if not _virtual.has(action):
		return
	Input.action_release(action)
	_virtual.erase(action)


func _release_all() -> void:
	_stick_finger = -1
	_drag_finger = -1
	_drag_id = ""
	_fingers.clear()
	_release_state.clear()
	var actions: Array = _virtual.keys()
	for action in actions:
		_drop(action)
	_apply_move(Vector2.ZERO)
	for pad in _pads.values():
		(pad as Pad).down = false
		(pad as Pad).queue_redraw()


func _stick_rect() -> Rect2:
	return _stick.get_global_rect().grow(8.0)


func _pad_at(at: Vector2) -> StringName:
	for action in _pads.keys():
		var pad := _pads[action] as Pad
		if pad.visible and pad.get_global_rect().grow(4.0).has_point(at):
			return action
	return &""


func _is_hit_pad(pad: Control, at: Vector2) -> bool:
	return pad != null and pad.visible and pad.get_global_rect().grow(4.0).has_point(at)


func _hit_draggable(at: Vector2) -> String:
	if _stick.get_global_rect().grow(8.0).has_point(at):
		return "stick"
	if _is_hit_pad(_more, at):
		return "more"
	for action in _pads.keys():
		var pad := _pads[action] as Pad
		if pad.visible and pad.get_global_rect().grow(4.0).has_point(at):
			return String(action)
	return ""


func _start_editing() -> void:
	_release_all()
	_selected_edit = "stick"
	_was_paused = get_tree().paused
	get_tree().paused = true
	_editing = true
	_secondary_open = true
	_physical = false
	if _coach_panel != null:
		_coach_panel.hide()
	_layout()
	_snapshot_layout()
	_refresh_edit_labels()


func _stop_editing() -> void:
	_snapshot_layout()
	Settings.save_touch_layout()
	_editing = false
	_secondary_open = false
	_drag_finger = -1
	_drag_id = ""
	if not _was_paused:
		get_tree().paused = false
	_refresh_edit_labels()
	arrange_finished.emit()


func _change_scale(step: float) -> void:
	Settings.set_touch_scale(_selected_edit, Settings.touch_scale(_selected_edit) + step)
	_layout()
	_refresh_edit_labels()


func _snapshot_layout() -> void:
	var view := _view_size()
	if view.x < 2.0 or view.y < 2.0:
		return
	# Ignore the layout signal until every control, including +, is stored.
	_laying = true
	_store_center("stick", _stick.get_global_rect().get_center(), view)
	for action in _pads.keys():
		var pad := _pads[action] as Pad
		_store_center(String(action), pad.get_global_rect().get_center(), view)
	_store_center("edit", _edit.get_global_rect().get_center(), view)
	if _reset.visible:
		_store_center("reset", _reset.get_global_rect().get_center(), view)
	_store_center("more", _more.get_global_rect().get_center(), view)
	_laying = false


func _store_center(id: String, center: Vector2, view: Vector2) -> void:
	Settings.set_touch_position(id, Vector2(center.x / view.x, center.y / view.y))


func _view_size() -> Vector2:
	var view := get_viewport().get_visible_rect().size
	if view.x < 2.0:
		return Vector2(640, 360)
	return view


func _layout() -> void:
	if _laying:
		return
	_laying = true
	var view := _view_size()
	var blocks := _blockers()
	_place_stick(view, blocks)
	_place_cluster(view, blocks)
	_keep_pads_clear_of_map(view, blocks)
	_place_edit_strip(view)
	_refresh_edit_labels()
	_refresh_tour()
	_laying = false


func _place_stick(view: Vector2, blocks: Array[Rect2]) -> void:
	var side := 100.0 * TOUCH_SIZE_MULTIPLIER * Settings.touch_scale("stick")
	var band := _band(blocks, view, true)
	band.y = minf(band.y, view.y - 28.0)
	var y := clampf(band.y - side, band.x, maxf(band.x, band.y - side))
	_place_named("stick", _stick, Vector2(10.0, y), Vector2(side, side), view)


## This region is always reserved for the minimap and its oxygen/energy/shielding arcs.
## The minimap can become 160 px wide; do not depend on the node's first-frame size.
func _map_safe_rect(view: Vector2) -> Rect2:
	var side := 80.0
	var minimap := get_tree().root.find_child("Minimap", true, false) as Control
	if minimap != null and minimap.visible:
		side = maxf(side, minimap.size.x)
	var margin := 20.0 + 18.0 # map margin plus resource-ring icons
	var top_left := Vector2(view.x - side - margin, view.y - side - margin)
	return Rect2(top_left, view - top_left)


## Keep *every* active right-side pad, including the expanded + tray, away from
## the minimap. Saved user positions are checked as well as automatic positions.
func _keep_pads_clear_of_map(view: Vector2, blocks: Array[Rect2]) -> void:
	if _editing:
		return
	var pads: Array[Control] = []
	for action in PRIMARY:
		var pad := _pads.get(StringName(action)) as Control
		if pad != null and pad.visible:
			pads.append(pad)
	pads.append(_more)
	for action in SECONDARY:
		var pad := _pads.get(StringName(action)) as Control
		if pad != null and pad.visible:
			pads.append(pad)
	if pads.is_empty():
		return
	var bounds := pads[0].get_global_rect()
	for i in range(1, pads.size()):
		bounds = bounds.merge(pads[i].get_global_rect())
	var reserved := _map_safe_rect(view).grow(6.0)
	if not bounds.intersects(reserved):
		return
	# Move the group as one block, preserving relative button placement. If the
	# map is expanded and there is no room above it, move left instead.
	var shifts: Array[Vector2] = [
		Vector2(0.0, reserved.position.y - bounds.end.y - 3.0),
		Vector2(reserved.position.x - bounds.end.x - 3.0, 0.0),
		Vector2(reserved.position.x - bounds.end.x - 3.0, reserved.position.y - bounds.end.y - 3.0),
	]
	var best := Vector2.ZERO
	var score := INF
	for shift in shifts:
		var moved := Rect2(bounds.position + shift, bounds.size)
		if moved.position.x < 2.0 or moved.position.y < 2.0 or moved.end.x > view.x - 2.0 or moved.end.y > view.y - 2.0:
			continue
		if moved.intersects(reserved):
			continue
		var clashes := false
		for block in blocks:
			# Ignore ResourceRing and Minimap here: the reserved area contains both.
			if block.intersects(reserved):
				continue
			if moved.intersects(block.grow(4.0)):
				clashes = true
				break
		if clashes:
			continue
		var distance := absf(shift.x) + absf(shift.y)
		if distance < score:
			score = distance
			best = shift
	if score == INF:
		# Worst case on narrow screens: favor leaving the map unobstructed.
		best = shifts[0] if bounds.position.y + shifts[0].y >= 2.0 else shifts[1]
	for pad in pads:
		pad.position += best


func _place_cluster(view: Vector2, blocks: Array[Rect2]) -> void:
	# Pause and + sit in a narrow column. The four walking actions stay a 2×2 beside them,
	# so a tall mission tracker does not push the cluster down over the playfield.
	var bw := 50.0 * TOUCH_SIZE_MULTIPLIER
	var gap := 6.0 * TOUCH_SIZE_MULTIPLIER
	var small := 40.0 * TOUCH_SIZE_MULTIPLIER
	var grid := Vector2(bw * 2.0 + gap, bw * 2.0 + gap)
	var block := Vector2(small + gap + grid.x, grid.y)
	var band := _band(blocks, view, false)
	var safe_map := _map_safe_rect(view)
	var safe_bottom := minf(band.y, safe_map.position.y - 6.0)
	var origin := Vector2(view.x - 8.0 - block.x, safe_bottom - block.y)
	if origin.y < band.x:
		origin.x = minf(origin.x, _lower_edge(blocks, view) - 8.0 - block.x)
		origin.y = band.x
	origin.x = clampf(origin.x, 96.0, maxf(96.0, view.x - block.x - 4.0))
	origin.y = clampf(origin.y, 4.0, maxf(4.0, view.y - block.y - 4.0))
	var grid_at := origin + Vector2(small + gap, 0.0)
	_place("sprint", grid_at, bw, view)
	_place("jump", grid_at + Vector2(bw + gap, 0.0), bw, view)
	_place("flashlight", grid_at + Vector2(0.0, bw + gap), bw, view)
	_place("interact", grid_at + Vector2(bw + gap, bw + gap), bw, view)
	var nudge := (bw - small) * 0.5
	_place("pause", origin + Vector2(0.0, nudge), small, view)
	for name in PRIMARY:
		(_pads[StringName(name)] as Pad).visible = true
	var more_pos := origin + Vector2(0.0, bw + gap + nudge)
	_place_named("more", _more, more_pos, Vector2.ONE * small * Settings.touch_scale("more"), view)
	_more.marked = _secondary_open
	_more.visible = true
	_more.queue_redraw()
	_place_secondary(view, blocks, origin, block)


func _place_secondary(view: Vector2, blocks: Array[Rect2], origin: Vector2, block: Vector2) -> void:
	var show := _secondary_open or _editing
	var bw := 36.0 * TOUCH_SIZE_MULTIPLIER
	var gap := 4.0 * TOUCH_SIZE_MULTIPLIER
	var cols := 3
	var rows := int(ceil(float(SECONDARY.size()) / float(cols)))
	var tray := Vector2(cols * bw + float(cols - 1) * gap, rows * bw + float(rows - 1) * gap)
	var at := Vector2(origin.x - 8.0 - tray.x, origin.y + (block.y - tray.y) * 0.5)
	var avoid := blocks.duplicate()
	avoid.append(_stick.get_global_rect().grow(6.0))
	avoid.append(Rect2(origin, block).grow(4.0))
	at = _shift_clear(at, tray, avoid, view)
	for i in SECONDARY.size():
		var name := SECONDARY[i]
		var cell := at + Vector2(float(i % cols) * (bw + gap), float(int(i / cols)) * (bw + gap))
		_place(name, cell, bw, view)
		(_pads[StringName(name)] as Pad).visible = show


func _place_edit_strip(view: Vector2) -> void:
	var y := 28.0
	var unit := TOUCH_SIZE_MULTIPLIER
	var edit_size := Vector2(84, 28) * unit
	_place_named("edit", _edit, Vector2(8.0, y), edit_size, view)
	_place_named("reset", _reset, Vector2(8.0 + (84.0 + 6.0) * unit, y), Vector2(104, 28) * unit, view)
	var smaller_at := Vector2(8.0 + (84.0 + 116.0) * unit, y)
	_place_named("scale_down", _smaller, smaller_at, Vector2(28, 28) * unit, view)
	_place_named("scale_up", _larger, smaller_at + Vector2(34.0 * unit, 0.0), Vector2(28, 28) * unit, view)
	if _scale_display != null:
		_scale_display.position = smaller_at + Vector2(68.0 * unit, 2.0)
		_scale_display.size = Vector2(minf(160.0, view.x - _scale_display.position.x - 4.0), 24.0)
	if _hint != null:
		_hint.position = Vector2(8, 4)
		_hint.size = Vector2(minf(view.x - 16.0, 420.0), 22.0)


func _place(action: String, at: Vector2, side: float, view: Vector2) -> void:
	var pad := _pads.get(StringName(action)) as Pad
	if pad == null:
		return
	_place_named(action, pad, at, Vector2(side, side) * Settings.touch_scale(action), view)


func _place_named(id: String, node: Control, auto_top_left: Vector2, size: Vector2, view: Vector2) -> void:
	if node == null:
		return
	node.size = size
	var fallback := auto_top_left + size * 0.5
	var center := Settings.touch_center(id, fallback, view)
	var pos := center - size * 0.5
	pos.x = clampf(pos.x, 2.0, maxf(view.x - size.x - 2.0, 2.0))
	pos.y = clampf(pos.y, 2.0, maxf(view.y - size.y - 2.0, 2.0))
	node.position = pos


## Top-left clock and mission raise the ceiling. Bottom-right map and a wide INTI box raise the floor.
func _band(blocks: Array[Rect2], view: Vector2, left: bool) -> Vector2:
	var min_y := 8.0
	var max_bottom := view.y - 8.0
	for block in blocks:
		var center := block.get_center()
		var spans := block.size.x > view.x * 0.55
		var on_side := center.x < view.x * 0.48 if left else center.x > view.x * 0.52
		if not on_side and not (spans and center.y >= view.y * 0.4):
			continue
		if center.y < view.y * 0.46:
			min_y = maxf(min_y, block.end.y + 6.0)
		else:
			max_bottom = minf(max_bottom, block.position.y - 6.0)
	return Vector2(min_y, maxf(max_bottom, min_y + 36.0))


func _lower_edge(blocks: Array[Rect2], view: Vector2) -> float:
	var edge := view.x - 8.0
	for block in blocks:
		if block.position.y > view.y * 0.45 and block.position.x > view.x * 0.35:
			edge = minf(edge, block.position.x)
	return edge


func _shift_clear(at: Vector2, size: Vector2, blocks: Array[Rect2], view: Vector2) -> Vector2:
	var rect := Rect2(at, size)
	var guard := 0
	while guard < 48 and not _clear(rect, blocks):
		guard += 1
		if rect.position.x > 150.0:
			rect.position.x -= 8.0
		elif rect.position.y > 72.0:
			rect.position.y -= 8.0
		else:
			break
	rect.position.x = clampf(rect.position.x, 4.0, maxf(4.0, view.x - size.x - 4.0))
	rect.position.y = clampf(rect.position.y, 4.0, maxf(4.0, view.y - size.y - 4.0))
	return rect.position


func _clear(rect: Rect2, blocks: Array[Rect2]) -> bool:
	var grown := rect.grow(4.0)
	for block in blocks:
		if grown.intersects(block):
			return false
	return true


func _blockers() -> Array[Rect2]:
	var found: Array[Rect2] = []
	for node_name in ["SolPanel", "MissionPanel", "ResourceRing", "Minimap"]:
		var node := get_tree().root.find_child(node_name, true, false) as Control
		if node != null and node.visible and node.size.x > 4.0 and node.size.y > 4.0:
			found.append(node.get_global_rect())
	var host := get_tree().get_first_node_in_group(&"inti_panel")
	if host != null:
		var box := host.get("box") as IntiBox
		if box != null and box.is_open():
			for part_name in ["Panel", "Portrait"]:
				var part := box.get_node_or_null(part_name) as Control
				if part != null and part.visible and part.size.x > 4.0:
					found.append(part.get_global_rect())
	return found


func _over_hud(at: Vector2) -> bool:
	for block in _blockers():
		if block.has_point(at):
			return true
	return false


func _build() -> void:
	_root = Control.new()
	_root.name = "Pads"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_stick = Stick.new()
	_stick.name = "Stick"
	_root.add_child(_stick)
	for action in PRIMARY + SECONDARY:
		var pad := Pad.new()
		pad.name = action
		pad.glyph = action
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(pad)
		_pads[StringName(action)] = pad
	_more = Pad.new()
	_more.name = "More"
	_more.glyph = "more"
	_more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_more)
	_edit = TextPad.new()
	_edit.name = "Edit"
	_edit.visible = false
	_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_edit)
	_reset = TextPad.new()
	_reset.name = "Reset"
	_reset.visible = false
	_reset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_reset)
	_smaller = TextPad.new()
	_smaller.name = "Smaller"
	_smaller.visible = false
	_smaller.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_smaller)
	_larger = TextPad.new()
	_larger.name = "Larger"
	_larger.visible = false
	_larger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_larger)
	_scale_display = Label.new()
	_scale_display.name = "ScaleValue"
	_scale_display.visible = false
	_scale_display.add_theme_font_override("font", FONT)
	_scale_display.add_theme_font_size_override("font_size", 12)
	_scale_display.add_theme_color_override("font_color", Palette.CREMA)
	_scale_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_scale_display)
	_build_coach()
	_hint = Label.new()
	_hint.name = "EditHint"
	_hint.visible = false
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_color_override("font_color", Palette.CREMA)
	_hint.add_theme_font_override("font", FONT)
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_hint)


func _build_coach() -> void:
	_coach_panel = PanelContainer.new()
	_coach_panel.name = "TouchCoach"
	_coach_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coach_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.051, 0.071, 0.11, 0.86)
	style.border_color = Color(Palette.INTI, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(4)
	style.anti_aliasing = false
	_coach_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_coach_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coach_panel.add_child(column)
	_coach_label = Label.new()
	_coach_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := LabelSettings.new()
	look.font = FONT
	look.font_size = 16
	look.font_color = Palette.CREMA
	look.outline_size = 1
	look.outline_color = Palette.ESPACIO
	_coach_label.label_settings = look
	_coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach_label.custom_minimum_size = Vector2(156, 0)
	column.add_child(_coach_label)
	_coach_close = Button.new()
	_coach_close.text = "×"
	_coach_close.tooltip_text = Settings.text("touch.tour_close")
	_coach_close.focus_mode = Control.FOCUS_NONE
	_coach_close.flat = true
	_coach_close.custom_minimum_size = Vector2(14, 14)
	_coach_close.pressed.connect(_finish_tour)
	column.add_child(_coach_close)


func _on_tutorial_replay() -> void:
	_tour_index = 0
	_tour_active = true
	_secondary_open = false
	_refresh()


func _advance_tour() -> void:
	var id := TOUR_ITEMS[_tour_index] if _tour_index < TOUR_ITEMS.size() else ""
	_tour_index += 1
	if id == "more":
		_secondary_open = true
	if _tour_index >= TOUR_ITEMS.size():
		_finish_tour()
	_layout()


func _finish_tour() -> void:
	_tour_active = false
	Settings.complete_touch_tutorial()
	if _coach_panel != null:
		_coach_panel.hide()
	for action in _pads.keys():
		(_pads[action] as Pad).highlight = false
	if _stick != null:
		_stick.highlight = false
	if _more != null:
		_more.highlight = false


func _refresh_tour() -> void:
	if _coach_panel == null or _stick == null:
		return
	var active := _pads_visible and _tour_active and not _editing and _tour_index < TOUR_ITEMS.size()
	_coach_panel.visible = active
	var focused := TOUR_ITEMS[_tour_index] if active else ""
	_stick.highlight = focused == "stick"
	_stick.queue_redraw()
	if _more != null:
		_more.highlight = focused == "more"
		_more.queue_redraw()
	for action in _pads.keys():
		var pad := _pads[action] as Pad
		pad.highlight = focused == String(action)
		pad.queue_redraw()
	if not active:
		return
	var id := TOUR_ITEMS[_tour_index]
	_coach_label.text = "%d/%d · %s\n%s" % [
		_tour_index + 1,
		TOUR_ITEMS.size(),
		Settings.text("touch.tour_tap"),
		Settings.text("touch.tour_%s" % id),
	]
	var rect := _control_rect(id)
	var view := _view_size()
	var width := 168.0
	var height := 52.0
	_coach_panel.size = Vector2(width, height)
	var x := rect.end.x + 6.0 if rect.get_center().x < view.x * 0.5 else rect.position.x - width - 6.0
	var y := rect.get_center().y - height * 0.5
	_coach_panel.position = Vector2(
		clampf(x, 4.0, maxf(4.0, view.x - width - 4.0)),
		clampf(y, 4.0, maxf(4.0, view.y - height - 4.0))
	)


func _control_rect(id: String) -> Rect2:
	if id == "stick":
		return _stick.get_global_rect().grow(10.0)
	if id == "more":
		return _more.get_global_rect().grow(4.0)
	var pad := _pads.get(StringName(id)) as Pad
	if pad == null:
		return Rect2()
	return pad.get_global_rect().grow(4.0)


func _build_rotate() -> void:
	_rotate = CanvasLayer.new()
	_rotate.name = "Rotate"
	_rotate.layer = 80
	_rotate.process_mode = Node.PROCESS_MODE_ALWAYS
	_rotate.visible = false
	add_child(_rotate)
	var cover := Control.new()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_rotate.add_child(cover)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Palette.ESPACIO
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(dim)
	var sun := TextureRect.new()
	sun.texture = load("res://assets/art/ui/inti_avatar.png")
	sun.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sun.custom_minimum_size = Vector2(64, 64)
	sun.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sun.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sun.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sun.set_anchors_preset(Control.PRESET_CENTER)
	sun.offset_left = -32
	sun.offset_top = -70
	sun.offset_right = 32
	sun.offset_bottom = -6
	cover.add_child(sun)
	_rotate_label = Label.new()
	_rotate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotate_label.add_theme_color_override("font_color", Palette.CREMA)
	_rotate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotate_label.set_anchors_preset(Control.PRESET_CENTER)
	_rotate_label.offset_left = -160
	_rotate_label.offset_top = 8
	_rotate_label.offset_right = 160
	_rotate_label.offset_bottom = 36
	cover.add_child(_rotate_label)


class Stick extends Control:
	var knob := Vector2.ZERO
	var highlight := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(center, radius, Color("30425a", 0.22))
		draw_circle(center, radius - 4.0, Color("c9d6ea", 0.26))
		draw_arc(center, radius - 1.0, 0.0, TAU, 28, Color("ffe000") if highlight else Color("10213b"), 2.0 if highlight else 1.0, true)
		draw_circle(center + knob, radius * 0.34, Color("f7f2de", 0.92))
		draw_arc(center + knob, radius * 0.34, 0.0, TAU, 20, Color("10213b"), 1.0, true)


class Pad extends Control:
	const TOUCH_ICON_JUMP: Texture2D = preload("res://assets/art/ui/touch/icon_jump.png")
	const TOUCH_ICON_INTERACT: Texture2D = preload("res://assets/art/ui/touch/icon_interact.png")
	const TOUCH_ICON_SPRINT: Texture2D = preload("res://assets/art/ui/touch/icon_sprint.png")
	const TOUCH_ICON_FLASHLIGHT: Texture2D = preload("res://assets/art/ui/touch/icon_flashlight.png")
	const TOUCH_ICON_PAUSE: Texture2D = preload("res://assets/art/ui/touch/icon_pause.png")
	const TOUCH_ICON_MORE: Texture2D = preload("res://assets/art/ui/touch/icon_more.png")
	const TOUCH_ICON_INTI: Texture2D = preload("res://assets/art/ui/touch/icon_inti.png")
	const TOUCH_ICON_MINIMAP: Texture2D = preload("res://assets/art/ui/touch/icon_minimap.png")
	const TOUCH_ICON_CYCLE: Texture2D = preload("res://assets/art/ui/touch/icon_cycle_mission.png")
	var glyph := ""
	var down := false
	var highlight := false
	var marked := false

	func _draw() -> void:
		var inset := 5.0
		var inner := Rect2(Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0))
		if inner.size.x < 10.0:
			inner = Rect2(Vector2.ZERO, size)
		var top_fill := Color("d6deee", 0.94 if down else 0.76)
		var low_fill := Color("96a7c8", 0.94 if down else 0.76)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.68)), top_fill)
		draw_rect(Rect2(inner.position + Vector2(0.0, inner.size.y * 0.68), Vector2(inner.size.x, inner.size.y * 0.32)), low_fill)
		var edge := Color("ffe000") if down or highlight else Color("10213b")
		draw_rect(inner, edge, false, 2.0)
		var gloss := Rect2(inner.position + Vector2(4.0, 4.0), Vector2(inner.size.x * 0.26, inner.size.y * 0.18))
		draw_rect(gloss, Color.WHITE if down else Color(1.0, 1.0, 1.0, 0.55))
		var tex := _icon_texture(glyph)
		if tex != null and not (glyph == "more" and marked):
			var pad := inner.size.x * (0.10 if _is_framed_icon(glyph) else 0.16)
			var icon_rect := inner.grow(-pad)
			draw_texture_rect(tex, icon_rect, false)
			return
		var factor := inner.size.x / 48.0
		draw_set_transform(inner.position, 0.0, Vector2(factor, factor))
		_icon(glyph, Vector2(48, 48), Color(Palette.CREMA, 0.92))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _icon_texture(kind: String) -> Texture2D:
		match kind:
			"jump":
				return TOUCH_ICON_JUMP
			"sprint":
				return TOUCH_ICON_SPRINT
			"flashlight":
				return TOUCH_ICON_FLASHLIGHT
			"interact":
				return TOUCH_ICON_INTERACT
			"pause":
				return TOUCH_ICON_PAUSE
			"more":
				return TOUCH_ICON_MORE
			"inti":
				return TOUCH_ICON_INTI
			"minimap":
				return TOUCH_ICON_MINIMAP
			"cycle_mission":
				return TOUCH_ICON_CYCLE
			_:
				return null

	func _is_framed_icon(kind: String) -> bool:
		return kind == "inti" or kind == "minimap" or kind == "cycle_mission"

	func _icon(kind: String, box: Vector2, color: Color) -> void:
		var c := box * 0.5
		match kind:
			"jump":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(-8, 6), c + Vector2(8, 6)]), color)
			"sprint":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -7), c + Vector2(0, -7), c + Vector2(-4, 1)]), color)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-2, -1), c + Vector2(8, -1), c + Vector2(2, 7)]), color)
			"flashlight":
				draw_circle(c + Vector2(0, 2), 5.0, color)
				draw_line(c + Vector2(0, -8), c + Vector2(0, -4), color, 2.0)
				draw_line(c + Vector2(-7, -4), c + Vector2(-4, -1), color, 2.0)
				draw_line(c + Vector2(7, -4), c + Vector2(4, -1), color, 2.0)
			"inti":
				draw_circle(c, 5.0, color)
				draw_arc(c, 9.0, 0.0, TAU, 16, color, 1.5, true)
			"minimap":
				draw_arc(c, 8.0, 0.0, TAU, 16, color, 2.0, true)
				draw_circle(c + Vector2(2, -2), 2.0, color)
			"cycle_mission":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -2), c + Vector2(-2, -2), c + Vector2(-5, -7)]), color)
				draw_colored_polygon(PackedVector2Array([c + Vector2(8, 2), c + Vector2(2, 2), c + Vector2(5, 7)]), color)
			"pause":
				draw_rect(Rect2(c + Vector2(-6, -7), Vector2(4, 14)), color)
				draw_rect(Rect2(c + Vector2(2, -7), Vector2(4, 14)), color)
			"more":
				var arm := 8.0
				if marked:
					draw_line(c + Vector2(-arm, -arm), c + Vector2(arm, arm), color, 3.0)
					draw_line(c + Vector2(arm, -arm), c + Vector2(-arm, arm), color, 3.0)
				else:
					draw_line(c + Vector2(-arm, 0), c + Vector2(arm, 0), color, 3.0)
					draw_line(c + Vector2(0, -arm), c + Vector2(0, arm), color, 3.0)
			_:
				draw_rect(Rect2(c + Vector2(-6, -5), Vector2(12, 10)), color)
				draw_rect(Rect2(c + Vector2(-2, -8), Vector2(4, 4)), color)


class TextPad extends Control:
	const FONT: Font = preload("res://assets/fonts/m5x7.ttf")
	var caption := ""
	var down := false

	func _draw() -> void:
		var fill := Color("c9d6ea", 0.95 if down else 0.84)
		var shadow := Color("96a7c8", 0.95 if down else 0.84)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.68)), fill)
		draw_rect(Rect2(Vector2(0.0, size.y * 0.68), Vector2(size.x, size.y * 0.32)), shadow)
		var edge := Color("ffe000") if down else Color("10213b")
		draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), edge, false, 2.0)
		if caption.is_empty():
			return
		var fontsize := 10 if caption.length() >= 8 else 12
		var width := FONT.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fontsize).x
		draw_string(FONT, Vector2((size.x - width) * 0.5, size.y * 0.5 + 4.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fontsize, Color("10213b"))
