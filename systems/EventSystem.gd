class_name EventSystem
extends RefCounted
## One night event from data/events/events.json, plus at most one short daytime notice.
## Resource costs go back to the journal. Flags, damage and the Earth-delay queue land here.
## Nothing in here chooses an option for the player.
##
## Schema (one object in "events"):
##   id, title, text
##   sol_minimo          earliest sol (min_sol is accepted too)
##   weight              0 hides it
##   when                "journal" (default) opens on the night page.
##                       "day" is a notice only. It does not open a second journal.
##   requires_module     placed and not damaged
##   requires_placed_module
##   if                  daytime conditions, any of: dust_sols_left, panel_weak_sols_left,
##                       flag, damaged_module ("any" or a module id)
##   once                "per_sol" (default) or "per_run"
##   options[]           id, label, detail, requires_module, requires_missing_module
##     effects           oxygen, energy, food, and flags:
##                       damage_module, message_delay_seconds, message_text, bonus_food,
##                       panel_weak_sols, dust_sols, or any other flag name
## A new event is another object in the list. A daytime one needs "when": "day"
## and, if it should not be a choice, "options": [].

const PATH := "res://data/events/events.json"

static var _events: Array = []
static var _rng := RandomNumberGenerator.new()
static var _seeded := false
## Sol that already showed its one daytime notice. -1 means none yet this process.
static var _day_sol := -1


static func reset_run() -> void:
	_day_sol = -1


static func roll(sol: int) -> Dictionary:
	var warning := NasaData.warning_event(sol)
	if not warning.is_empty():
		return _prepare(warning)
	if sol == 1:
		var opening := _by_id(&"dust_storm")
		if not opening.is_empty() and _listed(opening, sol, ""):
			var first := _prepare(opening)
			if not first.is_empty():
				return first
	var last := String(GameState.last_event_id)
	var pool := _pool(sol, last)
	if pool.is_empty():
		pool = _pool(sol, "")
	var guard := pool.size()
	while guard > 0:
		guard -= 1
		var picked := _weighted(pool)
		var prepared := _prepare(picked)
		if not prepared.is_empty():
			return prepared
		pool.erase(picked)
	return {}


## Safe to call often. Returns one line the first time this sol, then "".
## DayNightSystem shows it. It does not spend an INTI line and does not open the journal.
static func check_day(sol: int) -> String:
	if _day_sol == sol:
		return ""
	var line := ""
	if GameState.dust_sols_left > 0:
		line = _day_line(sol)
		if line.is_empty():
			line = Settings.format_both("day.dust")
	elif GameState.panel_weak_sols_left > 0:
		line = _day_line(sol)
		if line.is_empty():
			line = Settings.format_both("day.weak")
	elif int(GameState.get_flag(&"repaired_panel_sol", -99)) == sol - 1:
		line = Settings.format_both("day.fixed")
	if line.is_empty():
		return ""
	_day_sol = sol
	_mark_day_seen(sol)
	return line


## Sets flags and special effects. Resource numbers are applied by ResourceSystem.apply_night.
static func apply_flags(event: Dictionary, option: Dictionary) -> void:
	var event_id := String(event.get("id", ""))
	if not event_id.is_empty():
		GameState.set_flag(StringName("saw_" + event_id), true)
	var flags: Dictionary = option.get("effects", {}).get("flags", {})
	var queued_delay := -1.0
	var queued_text := ""
	var queued_en := ""
	var saw_text := false
	for key in flags:
		var value: Variant = flags[key]
		match String(key):
			"damage_module":
				_damage(StringName(String(event.get("target_module_id", ""))))
			"message_delay_seconds":
				queued_delay = maxf(float(value), 0.0)
			"message_text":
				queued_text = String(value)
				saw_text = true
			"message_text_en":
				queued_en = String(value)
			"bonus_food":
				GameState.bonus_food += float(value)
			"panel_weak_sols":
				GameState.panel_weak_sols_left = int(value)
			"dust_sols":
				GameState.dust_sols_left = maxi(GameState.dust_sols_left, int(value))
			_:
				GameState.set_flag(StringName(String(key)), value)
				if String(key) == "repaired_panel" and bool(value):
					GameState.set_flag(&"repaired_panel_sol", GameState.current_sol)
	if saw_text:
		var delay := queued_delay if queued_delay >= 0.0 else 0.0
		if queued_en.is_empty():
			queued_en = queued_text
		GameState.enqueue_message(delay, Settings.pack(queued_text, queued_en))


static func _by_id(id: StringName) -> Dictionary:
	for event in _all():
		if StringName(String(event.get("id", ""))) == id:
			return event
	return {}


static func _all() -> Array:
	if not _events.is_empty():
		return _events
	var file := FileAccess.open(PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
	if parsed is Dictionary and parsed.get("events", []) is Array:
		_events = parsed["events"]
	else:
		push_error("EventSystem: could not read %s" % PATH)
	return _events


static func _pool(sol: int, skip_id: String) -> Array:
	var pool: Array = []
	for event in _all():
		if _listed(event, sol, skip_id):
			pool.append(event)
	return pool


static func _listed(event: Dictionary, sol: int, skip_id: String) -> bool:
	if String(event.get("when", "journal")) != "journal":
		return false
	return _available(event, sol, skip_id)


static func _available(event: Dictionary, sol: int, skip_id: String) -> bool:
	var earliest := int(event.get("sol_minimo", event.get("min_sol", 1)))
	if earliest > sol:
		return false
	if skip_id != "" and String(event.get("id", "")) == skip_id:
		return false
	# The journal's dust event is now the aftermath of the playable Sol 1 storm.
	# Don't randomly repeat a duplicate dust storm on later nights.
	if String(event.get("id", "")) == "dust_storm" and sol != 1:
		return false
	if float(event.get("weight", 1)) <= 0.0:
		return false
	if String(event.get("id", "")) == "earth_message" and NasaData.is_blackout(sol):
		return false
	if event.has("requires_module") and not _has_module(StringName(String(event["requires_module"]))):
		return false
	if bool(event.get("requires_placed_module", false)) and _placed().is_empty():
		return false
	return true


static func _day_line(sol: int) -> String:
	for event in _all():
		if String(event.get("when", "journal")) != "day":
			continue
		if not _available(event, sol, ""):
			continue
		if not _day_if(event):
			continue
		var once := String(event.get("once", "per_sol"))
		if once == "per_run" and GameState.has_flag(StringName("saw_day_" + String(event.get("id", "")))):
			continue
		var spanish := String(event.get("text", ""))
		var english := String(event.get("text_en", spanish))
		return Settings.pack(spanish, english)
	return ""


static func _day_if(event: Dictionary) -> bool:
	var need: Variant = event.get("if", {})
	if not need is Dictionary or need.is_empty():
		return true
	if int(need.get("dust_sols_left", 0)) > 0 and GameState.dust_sols_left < int(need.get("dust_sols_left", 0)):
		return false
	if int(need.get("panel_weak_sols_left", 0)) > 0 and GameState.panel_weak_sols_left < int(need.get("panel_weak_sols_left", 0)):
		return false
	var flag := String(need.get("flag", ""))
	if not flag.is_empty() and not GameState.has_flag(StringName(flag)):
		return false
	var damaged := String(need.get("damaged_module", ""))
	if damaged == "any" and GameState.damaged_module_ids.is_empty():
		return false
	if not damaged.is_empty() and damaged != "any" and StringName(damaged) not in GameState.damaged_module_ids:
		return false
	return true


static func _mark_day_seen(sol: int) -> void:
	for event in _all():
		if String(event.get("when", "")) != "day":
			continue
		if String(event.get("once", "")) != "per_run":
			continue
		if _available(event, sol, "") and _day_if(event):
			GameState.set_flag(StringName("saw_day_" + String(event.get("id", ""))), true)


static func _prepare(source: Dictionary) -> Dictionary:
	var event: Dictionary = source.duplicate(true)
	if String(event.get("id", "")) == "earth_message":
		var delay := NasaData.round_trip_seconds(GameState.current_sol)
		var seconds := int(round(delay))
		for option in event.get("options", []):
			if not option is Dictionary:
				continue
			var flags: Dictionary = option.get("effects", {}).get("flags", {})
			if flags.has("message_delay_seconds"):
				flags["message_delay_seconds"] = seconds
				option["detail"] = "Envías la respuesta. En el juego tarda %d s: es la luz, ida y vuelta." % seconds
				option["detail_en"] = "You send the reply. In the game it takes %d s: that is the light, both ways." % seconds
	if String(event.get("id", "")) == "meteor":
		var target := _pick_target()
		if target == null:
			return {}
		event["target_module_id"] = String(target.data.id)
		event["text"] = String(event.get("text", "")).replace("{module}", target.data.display_name)
		event["text_en"] = String(event.get("text_en", "")).replace("{module}", target.data.name_en())
	var visible: Array = []
	for option in event.get("options", []):
		if _option_visible(option):
			visible.append(option)
	if visible.is_empty():
		return {}
	event["options"] = visible
	return event


static func _option_visible(option: Dictionary) -> bool:
	if option.has("requires_module") and not _has_module(StringName(String(option["requires_module"]))):
		return false
	if option.has("requires_missing_module") and _has_module(StringName(String(option["requires_missing_module"]))):
		return false
	return true


static func _has_module(id: StringName) -> bool:
	for module in _placed():
		if module.data.id == id and not module.damaged:
			return true
	return false


static func _placed() -> Array[BaseModule]:
	return ResourceSystem.get_modules()


static func _pick_target() -> BaseModule:
	var others: Array[BaseModule] = []
	var any: Array[BaseModule] = []
	for module in _placed():
		if module.damaged:
			continue
		any.append(module)
		if module.data.id != &"habitat":
			others.append(module)
	var pool := others if not others.is_empty() else any
	if pool.is_empty():
		return null
	return pool[_rand().randi() % pool.size()]


static func _damage(id: StringName) -> void:
	if id.is_empty():
		return
	var shown_es := String(id)
	var shown_en := String(id)
	for module in _placed():
		if module.data.id == id:
			module.set_damaged(true)
			shown_es = module.data.display_name
			shown_en = module.data.name_en()
			break
	if id not in GameState.damaged_module_ids:
		GameState.damaged_module_ids.append(id)
	GameState.add_note("journal.damaged", [shown_es], [shown_en])


static func _weighted(pool: Array) -> Dictionary:
	var total := 0.0
	for event in pool:
		total += float(event.get("weight", 1))
	var cursor := _rand().randf() * total
	for event in pool:
		cursor -= float(event.get("weight", 1))
		if cursor <= 0.0:
			return event
	return pool.back()


static func _rand() -> RandomNumberGenerator:
	if not _seeded:
		_rng.randomize()
		_seeded = true
	return _rng
