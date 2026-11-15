extends Node
## Run-wide state. Mission numbers (sol length, run length, etc.) live in res://data/, not here.

var current_sol: int = 0
var flags: Dictionary = {}
var chosen_kit: StringName = &""
## Module ids to place at the start, after the player's change to the kit.
var start_modules: Array[StringName] = []
var language: String = "en"

## One line per choice, for the debrief. {sol: int, text: String}
var decisions: Array[Dictionary] = []
## Sols of dust still ahead, not counting a storm that is only just being resolved tonight.
var dust_sols_left: int = 0
var panel_weak_sols_left: int = 0
## Permanent dust coating on the solar panel (0 clean, 100 heavily coated).
## Unlike weather flags, it stays until the player actually cleans the panel.
var solar_panel_dust: float = 0.0
var damaged_module_ids: Array[StringName] = []
var pending_notes: PackedStringArray = []
## Seconds left until Earth's reply arrives. Negative means nothing is in flight.
## message_queue holds the ones waiting behind it: {delay, text}. Nothing is overwritten.
var message_delay_left: float = -1.0
var message_text: String = ""
var message_queue: Array[Dictionary] = []
## Food granted by last night's "let it grow", applied on the next night before dinner.
var bonus_food: float = 0.0
var ending_id: StringName = &""
var rescue_resource: StringName = &""
var last_event_id: StringName = &""
## Event id while the journal is open (dust_storm, solar_storm, ...). Empty otherwise.
var active_event: String = ""
var meals_skipped: int = 0
var run_over: bool = false
## Empty on the surface. "habitat" or "greenhouse" while that interior is showing.
var interior_id: StringName = &""
## Mission progress for this run: id -> {state, done: Array, since: {objective_id: sol}}.
## Definitions live in res://data/missions/; MissionSystem owns the rules.
var missions: Dictionary = {}
## Active mission ids in the order they started (newest last).
var mission_order: Array[StringName] = []
## Greenhouse bed: 0 sprout, 1 growing, 2 ready, 3 picked. Starts growing so the row is never blank.
var bed_stage: int = 1
## Repeatable greenhouse sandbox: stocks are gameplay units, not NASA measurements.
var farm_started: bool = false
var farm_seed_stock: int = 4
var farm_water_stock: int = 4
var farm_seeded_sol: int = -1
var farm_watered: bool = false
## Cumulative dose in mSv. It never ends the run.
var dose_msv: float = 0.0
## Daily dose resets at dawn; total dose_msv remains cumulative for the debrief.
var daily_dose_msv: float = 0.0
var exercised_today: bool = false
var exercise_days: int = 0
var days_without_exercise: int = 0
var weak_muscles: bool = false
## "" , "bags", "sealed" or "open". today is the storm day; next is chosen the night before.
var shelter_today: String = ""
var shelter_next: String = ""
var message_count: int = 0
var message_wait_sum: float = 0.0
var held_messages: Array = []
var storms_faced: Array = []
var live_sandstorm_left: float = 0.0


func set_flag(flag: StringName, value: Variant = true) -> void:
	flags[flag] = value


## Applies the preset starting kit from data/base.json. Used now that the
## separate kit-pick screen is skipped in normal play.
func use_default_kit() -> void:
	var kit := BaseCatalog.get_kit(StringName(BaseCatalog.get_rule("default_kit", "")))
	if kit:
		chosen_kit = kit.id
		start_modules = kit.module_ids.duplicate()


func get_flag(flag: StringName, default: Variant = false) -> Variant:
	return flags.get(flag, default)


func has_flag(flag: StringName) -> bool:
	return flags.has(flag)


## Starts the delay if the wire is free. Otherwise the text waits, with its own delay, behind the one in flight.
func enqueue_message(delay: float, text: String, count: bool = true) -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		return
	var wait := maxf(delay, 0.0)
	if NasaData.is_blackout():
		NasaData.hold_message(wait, clean)
		return
	if count:
		NasaData.note_message(wait)
	if message_delay_left < 0.0:
		message_delay_left = wait
		message_text = clean
		return
	message_queue.append({"delay": wait, "text": clean})


## The line that just arrived. The next queued text, if any, starts its own delay.
func take_arrived_message() -> String:
	var text := message_text
	message_text = ""
	if message_queue.is_empty():
		message_delay_left = -1.0
		return text
	var next: Dictionary = message_queue.pop_front()
	message_delay_left = float(next.get("delay", 0.0))
	message_text = String(next.get("text", ""))
	return text


func add_note(key: String, es_args: Array = [], en_args: Array = []) -> void:
	pending_notes.append(Settings.format_both(key, es_args, en_args))


func add_raw(spanish: String, english: String) -> void:
	if spanish.strip_edges().is_empty() and english.strip_edges().is_empty():
		return
	var other := english if not english.strip_edges().is_empty() else spanish
	pending_notes.append(Settings.pack(spanish, other))


func log_decision(text: String) -> void:
	decisions.append({"sol": current_sol, "text": text})


func reset() -> void:
	var lang := language
	current_sol = 0
	flags.clear()
	chosen_kit = &""
	start_modules.clear()
	decisions.clear()
	dust_sols_left = 0
	panel_weak_sols_left = 0
	solar_panel_dust = 0.0
	damaged_module_ids.clear()
	pending_notes = PackedStringArray()
	message_delay_left = -1.0
	message_text = ""
	message_queue.clear()
	bonus_food = 0.0
	ending_id = &""
	rescue_resource = &""
	last_event_id = &""
	active_event = ""
	meals_skipped = 0
	run_over = false
	interior_id = &""
	missions.clear()
	mission_order.clear()
	bed_stage = 1
	farm_started = false
	farm_seed_stock = 4
	farm_water_stock = 4
	farm_seeded_sol = -1
	farm_watered = false
	dose_msv = 0.0
	daily_dose_msv = 0.0
	exercised_today = false
	exercise_days = 0
	days_without_exercise = 0
	weak_muscles = false
	shelter_today = ""
	shelter_next = ""
	message_count = 0
	message_wait_sum = 0.0
	held_messages.clear()
	storms_faced.clear()
	live_sandstorm_left = 0.0
	language = lang
	NasaData.begin_run()
