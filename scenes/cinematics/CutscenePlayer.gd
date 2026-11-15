class_name CutscenePlayer
extends CanvasLayer
## Reusable cutscene runner, loaded as the "Cutscenes" autoload. Data: res://data/cinematics/cinematics.json.
## Beats: line {speaker, text}, anim {name}, wait {seconds}, focus {target, seconds}.
## While one plays the tree is paused, the HUD and the INTI panel step aside, and the camera may
## look at a mission target. Esc / Start (or a click on "Saltar") skips; E, A or a click advances a line.
## Mission cutscenes start on their own ("trigger": "mission:<id>"). Endings are played by EndingSystem.

signal cutscene_started(id: StringName)
signal cutscene_finished(id: StringName)
signal _beat_done

const DATA_PATH := "res://data/cinematics/cinematics.json"
const BAR_HEIGHT := 28.0
const VIEW_SIZE := Vector2(640, 360)

@export var seconds_per_character: float = 0.03

var _defs: Dictionary = {}
var _triggers: Dictionary = {}
var _playing := false
var _closing := false
var _skipped := false
var _current: StringName = &""
var _was_paused := false
var _token := 0
var _waiting_anim: StringName = &""
var _line_done := true
var _line_beat: Dictionary = {}
var _camera: Camera2D

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _backdrop: ColorRect = $Backdrop
@onready var _signal_trip: Node2D = $Stage/SignalTrip
@onready var _pulse: Node2D = $Stage/SignalTrip/Pulse
@onready var _bar_top: ColorRect = $BarTop
@onready var _bar_bottom: ColorRect = $BarBottom
@onready var _root: Control = $Root
@onready var _box: IntiBox = %Dialog
@onready var _skip_hint: Label = %SkipHint


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_language("")
	Settings.language_changed.connect(_apply_language)
	_anim.animation_finished.connect(_on_animation_finished)
	EventBus.mission_completed.connect(_on_mission_completed)
	_load()
	_sync_cover()
	_reset_visuals(false)


func _apply_language(_lang: String) -> void:
	_skip_hint.text = Settings.text("cut.skip")
	if _line_beat.is_empty() or not _box.is_open():
		return
	_box.retarget(Settings.pick(_line_beat, "text"))


func _process(_delta: float) -> void:
	_sync_cover()
	if not _playing:
		return
	# Something else (an ending halting the day) may unpause mid-cutscene. The player stays still.
	if not get_tree().paused:
		get_tree().paused = true
	if _line_done or not _box.is_open():
		return
	if _box.is_done():
		_finish_line()


func _input(event: InputEvent) -> void:
	if not _playing or _closing:
		return
	if event.is_action_pressed(&"pause") or _is_skip_click(event):
		get_viewport().set_input_as_handled()
		skip()
		return
	var click := _is_click(event)
	if click or event.is_action_pressed(&"interact") or event.is_action_pressed(&"inti"):
		get_viewport().set_input_as_handled()
		_advance_line()
		return
	# Keys and buttons stay with the cutscene. Movement is already frozen by the pause.
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


## Plays a cutscene and returns when it ends (or is skipped). Waits for one already playing
## and for the night journal to close. hold_cover leaves the screen dark for a scene change;
## call release_cover() afterwards. Returns false if the id is unknown.
func play(id: StringName, hold_cover: bool = false) -> bool:
	var data: Dictionary = _defs.get(id, {})
	if data.is_empty():
		push_warning("Cutscenes: unknown cutscene '%s'" % id)
		return false
	while _playing or DayNightSystem.is_journal_open():
		await get_tree().process_frame
	_begin(id)
	await _bars(true)
	for beat in data.get("beats", []):
		if _skipped:
			break
		if beat is Dictionary:
			await _run_beat(beat)
	await _end(hold_cover)
	return true


func skip() -> void:
	if not _playing or _closing or _skipped:
		return
	if not bool(_defs.get(_current, {}).get("skippable", true)):
		return
	_skipped = true
	_anim.stop()
	_release()


func is_playing() -> bool:
	return _playing


func has_cutscene(id: StringName) -> bool:
	return _defs.has(id)


## Cutscene id for a trigger like "mission:grow_potato" or "ending:rescate"; empty if none.
func for_trigger(trigger: String) -> StringName:
	return _triggers.get(trigger, &"")


## Fades out the dark cover left by play(id, true), once the next scene is in.
func release_cover() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _playing:
		return
	var tween := create_tween()
	tween.tween_property(_backdrop, "modulate:a", 0.0, 0.4)
	await tween.finished
	if not _playing:
		_reset_visuals(false)


func _begin(id: StringName) -> void:
	_playing = true
	_closing = false
	_skipped = false
	_current = id
	_was_paused = get_tree().paused
	get_tree().paused = true
	_reset_visuals(false)
	_root.show()
	_skip_hint.visible = bool(_defs.get(id, {}).get("skippable", true))
	cutscene_started.emit(id)


func _end(hold_cover: bool) -> void:
	_closing = true
	_anim.stop()
	_box.dismiss()
	_release_camera()
	if not _skipped:
		await _bars(false)
	_reset_visuals(hold_cover)
	# The key that closed the last line must not reach the player as a fresh "interact".
	await get_tree().physics_frame
	var id := _current
	_playing = false
	_closing = false
	_current = &""
	get_tree().paused = _was_paused
	cutscene_finished.emit(id)


func _run_beat(beat: Dictionary) -> void:
	_token += 1
	match String(beat.get("type", "")):
		"line":
			var text := Settings.pick(beat, "text")
			if text.is_empty():
				return
			_line_beat = beat
			_show_line(String(beat.get("speaker", "INTI")), text)
			await _beat_done
			_box.dismiss()
		"anim":
			var anim_name := StringName(String(beat.get("name", "")))
			if not _anim.has_animation(anim_name):
				push_warning("Cutscenes: no animation '%s' in '%s'" % [anim_name, _current])
				return
			_waiting_anim = anim_name
			_anim.play(anim_name)
			await _beat_done
			_waiting_anim = &""
		"wait":
			_wait(float(beat.get("seconds", 0.5)))
			await _beat_done
		"focus":
			if _focus(StringName(String(beat.get("target", "")))):
				_wait(float(beat.get("seconds", 1.0)))
				await _beat_done
		var other:
			push_warning("Cutscenes: unknown beat type '%s' in '%s'" % [other, _current])


func _bars(opening: bool) -> void:
	_token += 1
	_waiting_anim = &"bars_in" if opening else &"bars_out"
	_anim.play(_waiting_anim)
	await _beat_done
	_waiting_anim = &""


func _wait(seconds: float) -> void:
	get_tree().create_timer(maxf(seconds, 0.0), true).timeout.connect(_release.bind(_token))


func _release(token: int = -1) -> void:
	if token == -1 or token == _token:
		_beat_done.emit()


func _show_line(_speaker: String, text: String) -> void:
	_line_done = false
	_box.present(text, "", seconds_per_character, false)


func _finish_line() -> void:
	_line_done = true


func _advance_line() -> void:
	if not _box.is_open():
		return
	if not _box.is_done():
		_box.finish_typing()
		_line_done = true
		return
	_release()


func _game_camera() -> Camera2D:
	var frame := get_tree().get_first_node_in_group(&"world_frame")
	if frame != null and frame.has_method(&"current_camera"):
		var camera := frame.call(&"current_camera") as Camera2D
		if camera != null:
			return camera
	return get_viewport().get_camera_2d()


func _focus(target_id: StringName) -> bool:
	var camera := _game_camera()
	if camera == null or not camera.has_method("focus_on"):
		push_warning("Cutscenes: no camera to focus in '%s'" % _current)
		return false
	for node in get_tree().get_nodes_in_group(MissionSystem.TARGET_GROUP):
		if node.get_target_id() == target_id and node is Node2D:
			camera.focus_on((node as Node2D).global_position)
			_camera = camera
			return true
	push_warning("Cutscenes: no target '%s' on the map for '%s'" % [target_id, _current])
	return false


func _release_camera() -> void:
	if is_instance_valid(_camera):
		_camera.release_focus()
	_camera = null


func _sync_cover() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.x < 2.0 or view.y < 2.0:
		view = VIEW_SIZE
	_backdrop.position = Vector2.ZERO
	_backdrop.size = view
	_bar_top.position.x = 0.0
	_bar_top.size = Vector2(view.x, BAR_HEIGHT)
	_bar_bottom.position.x = 0.0
	_bar_bottom.size = Vector2(view.x, BAR_HEIGHT)
	if is_instance_valid(_root):
		_root.position = Vector2.ZERO
		_root.size = view


## Rest state: nothing half-faded. hold_cover keeps the dark backdrop fully on.
func _reset_visuals(hold_cover: bool) -> void:
	_sync_cover()
	var view := get_viewport().get_visible_rect().size
	if view.x < 2.0 or view.y < 2.0:
		view = VIEW_SIZE
	_backdrop.modulate.a = 1.0 if hold_cover else 0.0
	_signal_trip.modulate.a = 0.0
	_pulse.position = Vector2(150, 150)
	_bar_top.position = Vector2(0, -BAR_HEIGHT)
	_bar_bottom.position = Vector2(0, view.y)
	if is_instance_valid(_box):
		_box.dismiss()
	_root.hide()
	_line_done = true


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == _waiting_anim:
		_release()


func _on_mission_completed(id: StringName) -> void:
	var cutscene := for_trigger("mission:%s" % id)
	if cutscene != &"":
		play(cutscene)


func _is_click(event: InputEvent) -> bool:
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT


func _is_skip_click(event: InputEvent) -> bool:
	return _is_click(event) and _skip_hint.visible \
			and _skip_hint.get_global_rect().has_point((event as InputEventMouseButton).position)


func _load() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
	if not parsed is Dictionary:
		push_error("Cutscenes: could not read %s" % DATA_PATH)
		return
	for entry in parsed.get("cinematics", []):
		var id := StringName(String(entry.get("id", "")))
		if id == &"":
			continue
		_defs[id] = entry
		var trigger := String(entry.get("trigger", ""))
		if not trigger.is_empty():
			_triggers[trigger] = id
