extends Node
## Facade for INTI. The rest of the game calls ask_hint(). INTI speaks on its own only
## on arrival (once per run) and for a real danger: a bar crossing critical, or a storm.
## At most max_auto_per_day danger lines, with auto_gap_seconds of play between them.

signal line_ready(text: String, tip: String)
signal auto_line(text: String)
## Emitted when the hint panel closes and nothing else is waiting.
signal became_idle

const LOW := 25.0
const DANGER_EVENTS: Array[String] = ["dust_storm", "solar_storm", "meteor", "radiation_alert"]

## Short lines. One or two sentences. Spanish and English say the same thing.
const AUTO_LINES := {
	"arrival": {
		"es": "Hola. Soy INTI. Si quieres una pista, aprieta Tab.",
		"en": "Hi. I'm INTI. If you want a hint, press Tab.",
	},
	"oxygen": {
		"es": "El oxígeno está muy bajo.",
		"en": "Oxygen is very low.",
	},
	"energy": {
		"es": "Queda poca energía.",
		"en": "Energy is running low.",
	},
	"food": {
		"es": "Queda poca comida.",
		"en": "Food is running low.",
	},
	"dust_storm": {
		"es": "Hay una tormenta de polvo. Los paneles darán menos.",
		"en": "There is a dust storm. The panels will make less power.",
	},
	"solar_storm": {
		"es": "Hay una tormenta solar. El hábitat protege mejor.",
		"en": "There is a solar storm. The habitat protects you better.",
	},
	"meteor": {
		"es": "Una piedra del cielo golpeó la base.",
		"en": "A rock from the sky hit the base.",
	},
	"radiation_alert": {
		"es": "Mañana pueden llegar partículas del Sol. El diario tiene el aviso.",
		"en": "Particles from the Sun may arrive tomorrow. The journal has the warning.",
	},
}

var _extra_lines: Dictionary = {}

const MAINS_CLEAR := {
	"es": "Todas las misiones principales están hechas. Ahora mantén la base viva hasta el Día 10.",
	"en": "All the main missions are done. Now keep the base alive until Day 10.",
}

@export var auto_gap_seconds: float = 60.0
@export var max_auto_per_day: int = 2
@export var toast_seconds: float = 4.5

var provider: INTIProvider = ScriptedProvider.new()

var _queue: Array[Dictionary] = []
var _showing := false
var _bound := false
## True while the hint typewriter is still running, so E finishes the line instead of using a module.
var typing := false
## True while a hint or a toast is on screen, so another auto line waits.
var ui_busy := false

var _previous: Dictionary = {}
var _shown: Dictionary = {}
var _pending: Dictionary = {}
var _auto_used := 0
var _since_auto := 0.0
var _auto_spoken := false


func _ready() -> void:
	for key in ["oxygen", "energy", "food"]:
		_previous[key] = ResourceSystem.get_value(StringName(key))
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.sol_started.connect(_on_sol_started)
	EventBus.event_triggered.connect(_on_event_triggered)


func _process(delta: float) -> void:
	if RunSession.is_suspended():
		return
	if not _in_play():
		return
	_since_auto += delta
	_try_arrival()
	_flush_auto()


func say(trigger_id: String) -> void:
	var state := current_state()
	_enqueue(provider.get_line(trigger_id, state), provider.get_last_tip())


## A line the player did not ask for. Kept for callers that still pass a sentence.
## Automatic play uses _request_auto so the daily cap applies.
func tell(text: String, tip: String = "") -> void:
	_enqueue(text, tip)


## Once, when the five main missions are done. Not a danger line, so it does not use the daily cap.
## One danger line that still respects the two-a-Day cap. True when it actually spoke.
func warn_line(id: String, spanish: String, english: String) -> bool:
	_extra_lines[id] = {"es": spanish, "en": english}
	var before := _auto_used
	_on_event_triggered(StringName(id))
	return _auto_used > before


func announce_mains_clear() -> void:
	tell(Settings.pack(String(MAINS_CLEAR.es), String(MAINS_CLEAR.en)))


func ask_hint() -> void:
	var state := current_state()
	_enqueue(provider.get_hint(state), provider.get_last_tip())


## day is the sol. outside / resources come from the systems that already own them.
func current_state() -> Dictionary:
	var last_decision := ""
	if not GameState.decisions.is_empty():
		var last: Dictionary = GameState.decisions.back()
		last_decision = String(last.get("text", ""))
	return {
		"day": GameState.current_sol,
		"oxygen": ResourceSystem.get_value(&"oxygen"),
		"energy": ResourceSystem.get_value(&"energy"),
		"food": ResourceSystem.get_value(&"food"),
		"outside": ResourceSystem.is_outside(),
		"active_event": GameState.active_event,
		"last_decision": last_decision,
		"flags": GameState.flags.duplicate(),
	}


func bind_panel() -> void:
	_bound = true
	_pump()


func unbind_panel() -> void:
	_bound = false
	_showing = false
	ui_busy = false
	_queue.clear()


func is_busy() -> bool:
	return _showing or not _queue.is_empty() or ui_busy


func has_panel() -> bool:
	return _bound


func notify_closed() -> void:
	_showing = false
	ui_busy = false
	if _bound:
		_pump()
	if not is_busy():
		became_idle.emit()


## The toast closed itself. The next danger line waits a full gap after this.
func notify_auto_closed() -> void:
	ui_busy = false
	_since_auto = 0.0


func _enqueue(text: String, tip: String) -> void:
	if not NasaData.SHOW_FACT_POPUPS:
		tip = ""
	if text.is_empty() and tip.is_empty():
		return
	_queue.append({"text": text, "tip": tip})
	_pump()


func _pump() -> void:
	if _showing or not _bound or _queue.is_empty():
		return
	_showing = true
	ui_busy = true
	var item: Dictionary = _queue.pop_front()
	line_ready.emit(String(item.get("text", "")), String(item.get("tip", "")))


## New run or back to the menu. Does not touch the daily cap rules; it only clears leftovers.
func reset_run() -> void:
	_queue.clear()
	_showing = false
	ui_busy = false
	typing = false
	_pending.clear()
	_shown.clear()
	_extra_lines.clear()
	_auto_used = 0
	_since_auto = auto_gap_seconds
	_auto_spoken = false
	for key in ["oxygen", "energy", "food"]:
		_previous[key] = ResourceSystem.get_value(StringName(key))


func _on_sol_started(_n: int) -> void:
	_auto_used = 0
	_shown.clear()
	_pending.clear()
	_since_auto = auto_gap_seconds
	_auto_spoken = false


func _try_arrival() -> void:
	if GameState.current_sol != 1 or GameState.has_flag(&"inti_arrived"):
		return
	if BasePlacer.active or Cutscenes.is_playing() or not DayNightSystem.has_started():
		return
	if ui_busy:
		return
	GameState.set_flag(&"inti_arrived", true)
	_emit_auto("arrival")


func _on_resource_changed(id: StringName, value: float, _max_value: float) -> void:
	var key := String(id)
	if key not in ["oxygen", "energy", "food"]:
		return
	var previous := float(_previous.get(key, value))
	_previous[key] = value
	if not _in_play() or value >= LOW or previous < LOW:
		return
	_request_auto(key)


func _on_event_triggered(id: StringName) -> void:
	var key := String(id)
	if (key not in DANGER_EVENTS and not _extra_lines.has(key)) or _shown.has(key):
		return
	# The journal is already open and paused, so say it now or the next morning wipes it.
	if ui_busy or (_auto_spoken and _since_auto < auto_gap_seconds) or _auto_used >= max_auto_per_day:
		_shown[key] = true
		return
	_shown[key] = true
	_auto_used += 1
	_emit_auto(key)


func _request_auto(id: String) -> void:
	if _shown.has(id):
		return
	if not _pending.is_empty():
		return
	if _auto_used >= max_auto_per_day:
		_shown[id] = true
		return
	_pending = {"id": id}


func _flush_auto() -> void:
	if _pending.is_empty() or ui_busy:
		return
	if _auto_spoken and _since_auto < auto_gap_seconds:
		return
	var id := String(_pending.get("id", ""))
	_pending.clear()
	if id.is_empty() or _shown.has(id):
		return
	if _auto_used >= max_auto_per_day:
		_shown[id] = true
		return
	_shown[id] = true
	_auto_used += 1
	_emit_auto(id)


func _emit_auto(id: String) -> void:
	_auto_spoken = true
	_since_auto = 0.0
	ui_busy = true
	auto_line.emit(_auto_text(id))


func _auto_text(id: String) -> String:
	var row: Dictionary = _extra_lines.get(id, AUTO_LINES.get(id, {}))
	return Settings.pack(String(row.get("es", "")), String(row.get("en", "")))


func _in_play() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == "res://scenes/Main.tscn" and not GameState.run_over
