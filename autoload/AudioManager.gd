extends Node
## Music and a few effects. Tracks live in assets/audio/ (see assets/audio/music/README.md).
## A missing file is skipped: no error, no warning, no empty stream. Drop the .ogg later; no code change.
## Looping contexts set AudioStream.loop at playback. Still enable Loop on the Godot import.

const CROSSFADE := 0.9
const NIGHT_AT := 0.45
## Linear gain for the shared looping theme, about -8 dB.
const THEME_GAIN := 0.4

const MUSIC := {
	"menu": "res://assets/audio/music/menu.ogg",
	"intro": "res://assets/audio/music/intro.ogg",
	"surface_day": "res://assets/audio/music/surface_day.ogg",
	"surface_night": "res://assets/audio/music/surface_night.ogg",
	"interior": "res://assets/audio/music/interior.ogg",
	"storm": "res://assets/audio/music/storm.ogg",
	"event_sting": "res://assets/audio/music/event_sting.ogg",
	"theme": "res://assets/audio/music/condor_theme.mp3",
}

const SFX := {
	"footstep": "res://assets/audio/sfx/footstep.ogg",
	"jump": "res://assets/audio/sfx/jump.ogg",
	"land": "res://assets/audio/sfx/land.ogg",
	"ui_click": "res://assets/audio/sfx/ui_click.ogg",
	"door": "res://assets/audio/sfx/door.ogg",
}

## fixed: a screen asked for one track. game: follow day, night, interior, storm. hold: leave it.
const MODE_FIXED := 0
const MODE_GAME := 1
const MODE_HOLD := 2

var _mode := MODE_FIXED
var _current := ""
var _active: AudioStreamPlayer
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _level_a := 0.0
var _level_b := 0.0
var _target_a := 0.0
var _target_b := 0.0
var _duck := 1.0
var _sting_used := false
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_i := 0
## path -> AudioStream, or false once we know it is missing.
var _found: Dictionary = {}
var _web_heard := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = _music_player("MusicA")
	_b = _music_player("MusicB")
	for i in 4:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % i
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		if AudioServer.get_bus_index("SFX") >= 0:
			player.bus = "SFX"
		add_child(player)
		_sfx.append(player)


func _process(delta: float) -> void:
	_duck = move_toward(_duck, _duck_goal(), delta / 0.4)
	_level_a = move_toward(_level_a, _target_a, delta / CROSSFADE)
	_level_b = move_toward(_level_b, _target_b, delta / CROSSFADE)
	_apply_level(_a, _level_a, _target_a)
	_apply_level(_b, _level_b, _target_b)
	if _mode == MODE_GAME:
		_follow_game()


func _input(event: InputEvent) -> void:
	if not _web_heard and _web_gesture(event):
		_web_heard = true
		_kick_web_audio()
	if event.is_echo():
		return
	if event.is_action_pressed(&"ui_accept"):
		var owner := get_viewport().gui_get_focus_owner()
		if owner is BaseButton and not (owner as BaseButton).disabled:
			play_sfx("ui_click")
		return
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if _under_button(get_viewport().gui_get_hovered_control()):
		play_sfx("ui_click")


func _web_gesture(event: InputEvent) -> bool:
	if not OS.has_feature("web") or event.is_echo():
		return false
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventKey:
		return (event as InputEventKey).pressed
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	return false


## The browser stays silent until the first tap. If the menu track never started, start it now.
func _kick_web_audio() -> void:
	if not OS.has_feature("web"):
		return
	if _active != null and _active.playing:
		return
	if _mode == MODE_GAME:
		_follow_game()
		return
	if _current.is_empty():
		return
	var id := _current
	_current = ""
	_start(id, 1.0, id != "intro" and id != "event_sting")


## Menu, intro, or any named context. Intro plays once. If intro is missing, menu keeps going.
func play_context(id: String) -> void:
	_mode = MODE_FIXED
	if id == "intro" and not _has("intro"):
		if _has("menu"):
			_start("menu", 1.0, true)
		elif _has("theme"):
			_start("theme", THEME_GAIN, true)
		else:
			_start("", 0.0, false)
		return
	var loop_on := id != "intro" and id != "event_sting"
	var gain := 1.0
	if id == "storm":
		gain = 0.55
	elif id == "event_sting":
		gain = 0.7
	elif id == "theme":
		gain = THEME_GAIN
	if not _has(id) and loop_on and _has("theme"):
		_start("theme", THEME_GAIN, true)
		return
	_start(id, gain, loop_on)


## Surface, interior and storm, from GameState and DayNightSystem.
func enter_gameplay() -> void:
	_mode = MODE_GAME
	_follow_game()


## Stop following. The track that is already playing stays until the next play_context.
func hold() -> void:
	_mode = MODE_HOLD


func play_sfx(id: String) -> void:
	if _sfx.is_empty():
		return
	var shared := _find(String(SFX.get(id, "")))
	if shared == null:
		return
	var stream := shared.duplicate()
	_set_loop(stream, false)
	var player := _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	player.stream = stream
	player.play()


func _follow_game() -> void:
	var id := _game_id()
	if id == "storm":
		_start(id, 0.55, true)
	elif id == "event_sting":
		_start(id, 0.7, false)
	elif id.is_empty():
		if _has("theme"):
			_start("theme", THEME_GAIN, true)
		else:
			_start("", 0.0, false)
	else:
		_start(id, THEME_GAIN if id == "theme" else 1.0, true)


func _game_id() -> String:
	if GameState.interior_id != &"" and _has("interior"):
		return "interior"
	if _storming():
		if _has("storm"):
			return "storm"
		if _has("event_sting"):
			if not _sting_used:
				_sting_used = true
				return "event_sting"
			if _current == "event_sting" and _active != null and _active.playing:
				return "event_sting"
	elif _sting_used:
		_sting_used = false
	return _surface_id()


func _surface_id() -> String:
	var night := DayNightSystem.night_amount() >= NIGHT_AT
	var day_ok := _has("surface_day")
	var night_ok := _has("surface_night")
	if night and night_ok:
		return "surface_night"
	if not night and day_ok:
		return "surface_day"
	if day_ok:
		return "surface_day"
	if night_ok:
		return "surface_night"
	if _has("theme"):
		return "theme"
	return ""


func _storming() -> bool:
	return GameState.dust_sols_left > 0 or GameState.active_event == "dust_storm"


func _duck_goal() -> float:
	if _mode != MODE_GAME:
		return 1.0
	var goal := 1.0
	if Cutscenes.is_playing():
		goal = minf(goal, 0.58)
	if DayNightSystem.is_journal_open():
		goal = minf(goal, 0.62)
	if get_tree().paused:
		goal = minf(goal, 0.55)
	return goal


func _start(id: String, gain: float, loop_on: bool) -> void:
	var path := _id_path(id)
	if not path.is_empty() and _active != null and _active.playing and _id_path(_current) == path:
		_current = id
		return
	if id == _current and _active != null and _active.playing:
		return
	if id.is_empty() or not _has(id):
		_current = ""
		_target_a = 0.0
		_target_b = 0.0
		_active = null
		return
	var stream := _find(String(MUSIC.get(id, ""))).duplicate()
	_set_loop(stream, loop_on)
	var incoming := _b if _active == _a else _a
	if incoming == _a:
		_level_a = 0.0
		_target_a = gain
		_target_b = 0.0
	else:
		_level_b = 0.0
		_target_b = gain
		_target_a = 0.0
	incoming.stream = stream
	incoming.volume_db = _db(0.0)
	incoming.play()
	_active = incoming
	_current = id


func _apply_level(player: AudioStreamPlayer, level: float, target: float) -> void:
	player.volume_db = _db(level)
	if target <= 0.0 and level <= 0.001 and player.playing:
		player.stop()


func _db(level: float) -> float:
	var linear := maxf(level, 0.0) * _duck
	if linear <= 0.001:
		return -80.0
	return linear_to_db(linear)


func _has(id: String) -> bool:
	return _find(String(MUSIC.get(id, ""))) != null


func _id_path(id: String) -> String:
	if id.is_empty():
		return ""
	var stream := _find(String(MUSIC.get(id, "")))
	if stream == null:
		return ""
	return stream.resource_path


## Shared imported stream, or null. Misses are remembered so we do not ask again.
func _find(ogg_path: String) -> AudioStream:
	if ogg_path.is_empty():
		return null
	var paths: PackedStringArray = [ogg_path]
	if ogg_path.ends_with(".ogg"):
		var stem := ogg_path.trim_suffix(".ogg")
		paths.append(stem + ".mp3")
		paths.append(stem + ".wav")
	for path in paths:
		if _found.has(path):
			var cached: Variant = _found[path]
			if cached is AudioStream:
				return cached
			continue
		if not ResourceLoader.exists(path):
			_found[path] = false
			continue
		var res: Variant = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if res is AudioStream:
			_found[path] = res
			return res
		_found[path] = false
	return null


func _set_loop(stream: AudioStream, loop_on: bool) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop_on
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop_on
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop_on else AudioStreamWAV.LOOP_DISABLED


func _music_player(node_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("Music") >= 0:
		player.bus = "Music"
	add_child(player)
	return player


func _under_button(node: Node) -> bool:
	var current := node
	while current != null:
		if current is BaseButton and not (current as BaseButton).disabled:
			return true
		current = current.get_parent()
	return false
