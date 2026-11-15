extends Node
## Saved NASA facts. The game never calls the network.
## Every other script asks here. Nothing else opens res://data/nasa/.

## Place discoveries and NASA fact cards. Off until they come back in another form.
const SHOW_FACT_POPUPS := false
const DIR := "res://data/nasa/"
const LOOP_PATH := "res://data/loop.json"
const EXAMPLE_ID := "oct2024"
const AUTO_CAP := 4
const SCRIPTED_SOLAR_STORM_SOL := 3
const HAZARD_TEX := {
	"radiation": "res://assets/art/ui/hazards/hazard_radiation.png",
	"isolation": "res://assets/art/ui/hazards/hazard_isolation.png",
	"distance": "res://assets/art/ui/hazards/hazard_distance.png",
	"gravity": "res://assets/art/ui/hazards/hazard_gravity.png",
	"environment": "res://assets/art/ui/hazards/hazard_environment.png",
	"dose": "res://assets/art/ui/hazards/icon_dose.png",
}
const MONTHS_ES: PackedStringArray = [
	"enero", "febrero", "marzo", "abril", "mayo", "junio",
	"julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
]
const MONTHS_EN: PackedStringArray = [
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December",
]
const MONTHS_SHORT_ES: PackedStringArray = [
	"ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic",
]
const MONTHS_SHORT_EN: PackedStringArray = [
	"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
]

var _sources: Dictionary = {}
var _accessed := "2026-11-13"
var _capsules: Dictionary = {}
var _scenarios: Array = []
var _places: Dictionary = {}
var _studies: Dictionary = {}
var _images: Array = []
var _scenario: Dictionary = {}
var _rules: Dictionary = {}
var _ready_data := false
var _rng := RandomNumberGenerator.new()
var _card: DataCapsule
var _snow: ParticleSnow
var _queue: Array[Dictionary] = []
var _auto_today := 0
var _glossary_i := 0
var _phase := ""
var _storm_at := 1.0
var _countdown := 0.0
var _window := 0.0
var _storm_level := 0
## Gameplay-only acute storm danger. This is NOT a NASA dose threshold.
## The measured mSv dose continues to be recorded separately.
const DANGER_THRESHOLD := 100.0
var _storm_danger := 0.0
var _warned_danger := false
var _zones := {"out": 0.0, "base": 0.0, "refuge": 0.0, "cave": 0.0}
var _energy_flip := false


func _ready() -> void:
	_rng.randomize()
	_ensure()
	_card = (load("res://scenes/ui/DataCapsule.tscn") as PackedScene).instantiate() as DataCapsule
	_card.dismissed.connect(_on_card_dismissed)
	add_child(_card)
	_snow = (load("res://scenes/ui/ParticleSnow.tscn") as PackedScene).instantiate() as ParticleSnow
	add_child(_snow)


func capsule(id: String) -> String:
	_ensure()
	var row: Dictionary = _capsules.get(id, {})
	var key := "en" if Settings.lang == "en" else "es"
	return String(row.get(key, row.get("es", "")))


func source(id: String) -> Dictionary:
	_ensure()
	var row: Dictionary = _sources.get(id.strip_edges(), {})
	return {"name": String(row.get("name", id)), "url": String(row.get("url", ""))}


func scenario() -> Dictionary:
	_ensure()
	return _scenario


func today() -> Dictionary:
	return day_row(maxi(GameState.current_sol, 1))


func day_row(sol: int) -> Dictionary:
	_ensure()
	for day in _scenario.get("days", []):
		if day is Dictionary and int(day.get("dia", 0)) == sol:
			var row := (day as Dictionary).duplicate(true)
			# Keep the space-weather scenario data, but force the gameplay solar storm
			# to happen only on Sol 3 so the run pacing is predictable.
			if sol == SCRIPTED_SOLAR_STORM_SOL:
				row["storm"] = true
				# The game's mandatory storm also takes priority over a scenario blackout,
				# ensuring the Sol 2 journal can announce it to the player.
				row["blackout"] = false
				row["level"] = maxi(int(row.get("level", 0)), 3)
				if String(row.get("flare", "")).is_empty():
					row["flare"] = "X-class"
				if int(row.get("sep", 0)) <= 0:
					row["sep"] = 1
			else:
				row["storm"] = false
			return row
	return {
		"dia": sol,
		"light_min": 12.0,
		"level": 3 if sol == SCRIPTED_SOLAR_STORM_SOL else 0,
		"storm": sol == SCRIPTED_SOLAR_STORM_SOL,
		"flare": "X-class" if sol == SCRIPTED_SOLAR_STORM_SOL else "",
		"sep": 1 if sol == SCRIPTED_SOLAR_STORM_SOL else 0,
	}


func place(id: String) -> Dictionary:
	_ensure()
	return _places.get(id, {})


func study(id: String) -> Dictionary:
	_ensure()
	return _studies.get(id, {})


func images() -> Array:
	_ensure()
	return _images


func begin_run() -> void:
	_ensure()
	var ids := _scenario_ids()
	if ids.is_empty():
		return
	var pool := ids.duplicate()
	var last := Settings.last_scenario
	if pool.size() > 1 and last in pool:
		pool.erase(last)
	var pick: String = pool[_rng.randi() % pool.size()]
	force_scenario(pick)
	Settings.set_last_scenario(pick)
	_queue.clear()
	_auto_today = 0
	_glossary_i = 0
	if _card != null and _card.has_method(&"hide_card"):
		_card.hide_card()


func force_scenario(id: String) -> bool:
	_ensure()
	for row in _scenarios:
		if row is Dictionary and String(row.get("id", "")) == id:
			_scenario = row
			_reset_clock()
			return true
	return false


func cycle_scenario() -> String:
	var ids := _scenario_ids()
	if ids.is_empty():
		return ""
	var current := String(_scenario.get("id", ""))
	var index := ids.find(current)
	var next: String = ids[(index + 1) % ids.size()]
	force_scenario(next)
	return next


func is_blackout(sol: int = -1) -> bool:
	var day := day_row(GameState.current_sol if sol < 0 else sol)
	return bool(day.get("blackout", false))


func round_trip_seconds(sol: int = -1) -> float:
	var day := day_row(GameState.current_sol if sol < 0 else sol)
	var light := float(day.get("light_min", 12.0))
	return light * 2.0 * _rule("light_seconds_per_minute", 2.0)


func light_minutes(sol: int = -1) -> float:
	return float(day_row(GameState.current_sol if sol < 0 else sol).get("light_min", 0.0))


func antenna_line() -> String:
	if _scenario.is_empty():
		return ""
	if is_blackout():
		if Settings.lang == "en":
			return "No contact until Day 5: the Sun is between Earth and Mars."
		return "Sin contacto hasta el Día 5: el Sol está entre la Tierra y Marte."
	var day := today()
	var light := float(day.get("light_min", 0.0))
	var seconds := roundi(light * 2.0 * _rule("light_seconds_per_minute", 2.0))
	if Settings.lang == "en":
		return "Today light takes %s min and a reply takes %d s." % [num(light, 1), seconds]
	return "Hoy la luz tarda %s min y la respuesta %d s." % [num(light, 1), seconds]


func scenario_line() -> String:
	return Settings.visible_text(scenario_notice())


func scenario_notice() -> String:
	if _scenario.is_empty():
		return ""
	var start := String(_scenario.get("start", ""))
	var end := String(_scenario.get("end", ""))
	return Settings.pack(
		"Tu misión usa el clima espacial real del %s (DONKI, NASA)." % _span(start, end, false),
		"Your mission uses the real space weather from %s (DONKI, NASA)." % _span(start, end, true)
	)


func warning_event(sol: int) -> Dictionary:
	var tomorrow := day_row(sol + 1)
	if tomorrow.is_empty() or not bool(tomorrow.get("storm", false)):
		return {}
	if bool(tomorrow.get("blackout", false)):
		return {}
	var flare := String(tomorrow.get("flare", ""))
	var spanish := ""
	var english := ""
	if not flare.is_empty():
		spanish = "Mañana pueden llegar partículas (llamarada %s)." % flare
		english = "Particles may arrive tomorrow (%s flare)." % flare
	elif int(tomorrow.get("sep", 0)) > 0:
		spanish = "Mañana pueden llegar partículas solares a la base."
		english = "Solar particles may reach the base tomorrow."
	else:
		spanish = "Mañana pueden llegar partículas del Sol."
		english = "Particles from the Sun may arrive tomorrow."
	var food := -int(_rule("shelter_food", 6.0))
	var bags_energy := -int(_rule("shelter_energy", 4.0))
	var seal := -int(_rule("seal_energy", 2.0))
	var found := int(_rule("plan_food", 6.0))
	var event := {
		"id": "radiation_alert",
		"title": "Aviso del Sol",
		"title_en": "Word from the Sun",
		"text": spanish,
		"text_en": english,
		"hazard": "radiation",
		"weight": 1,
		"options": [
			{
				"id": "bags",
				"label": "Refugio con bolsas",
				"label_en": "Shelter with bags",
				"detail": "Gastas comida y energía; adentro la dosis baja a un cuarto.",
				"detail_en": "It costs food and energy; inside the dose drops to a quarter.",
				"hazard": "radiation",
				"effects": {"food": food, "energy": bags_energy, "flags": {"storm_plan": "bags", "built_shelter": true}},
			},
			{
				"id": "seal",
				"label": "Solo cerrar el hábitat",
				"label_en": "Just close the habitat",
				"detail": "Gastas un poco de energía y adentro la dosis baja a la mitad.",
				"detail_en": "It costs a little energy, and inside the dose drops by half.",
				"hazard": "radiation",
				"effects": {"energy": seal, "flags": {"storm_plan": "sealed"}},
			},
			{
				"id": "plan",
				"label": "Seguir con el plan",
				"label_en": "Stick to the plan",
				"detail": "Hoy no gastas, pero afuera la dosis es completa.",
				"detail_en": "No cost today, but outside you take the full dose.",
				"hazard": "radiation",
				"effects": {"flags": {"bonus_food": found, "storm_plan": "open"}},
			},
		],
	}
	if not GameState.has_flag(&"saw_storm_photo"):
		GameState.set_flag(&"saw_storm_photo", true)
		show_capsule("curiosity_snow", true)
	return event


func journal_lines(sol: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var day := day_row(sol)
	if day.is_empty():
		return lines
	if int(day.get("level", 0)) == 1 and not bool(day.get("storm", false)):
		lines.append(_level_one_line(day))
	if day.has("kp"):
		lines.append(_kp_line(day))
		show_capsule("magnet", true)
		show_capsule("iss_storm", true)
	return lines


func on_sol_started(n: int) -> void:
	_ensure()
	_auto_today = 0
	_reset_clock()
	advance_exercise(n)
	GameState.shelter_today = GameState.shelter_next
	GameState.shelter_next = ""
	# The daily display resets to background at each dawn. Keep the mission's
	# cumulative exposure separately for mission evaluation and the debrief.
	GameState.daily_dose_msv = _rule("daily_msv", 0.67)
	GameState.dose_msv += GameState.daily_dose_msv
	if is_blackout(n):
		_hold_live_messages()
		GameState.set_flag(&"saw_blackout", true)
		if not GameState.has_flag(&"blackout_capsule"):
			GameState.set_flag(&"blackout_capsule", true)
			show_capsule("blackout", true)
	else:
		_release_held()
	var day := day_row(n)
	if bool(day.get("storm", false)):
		_arm_storm(day)
	if n == 1 and not GameState.has_flag(&"scenario_said"):
		GameState.set_flag(&"scenario_said", true)
		if SHOW_FACT_POPUPS:
			_notice_packed(scenario_notice())
		var general: Array[String] = ["sol", "gravity", "hazards"]
		show_capsule(general[_rng.randi() % general.size()], true)
	if not GameState.has_flag(&"gcr_said"):
		if IntiBrain.warn_line("shield_gcr", "Cada Día suma un poco de radiación. El escudo casi no la baja.", "Each Day adds a little radiation. Shielding barely lowers it."):
			GameState.set_flag(&"gcr_said", true)
			show_capsule("shield_gcr", true)


func tick(delta: float, progress: float) -> void:
	if GameState.run_over:
		return
	# Acute hazard slowly fades once the storm is over, then resets at next dawn.
	# This models temporary danger, not biological removal of absorbed radiation.
	if _phase == "done":
		_storm_danger = maxf(0.0, _storm_danger - delta * 2.0)
	if _phase == "wait" and progress >= _storm_at:
		_phase = "countdown"
		_countdown = _rule("warning_seconds", 15.0)
		var seconds := int(round(_countdown))
		IntiBrain.warn_line(
			"particle_alert",
			"¡ALERTA SOLAR! Regresa al hábitat; las partículas llegan en %d s." % seconds,
			"SOLAR WARNING! Return to the habitat. Particles in %d s." % seconds
		)
		_solar_notice("¡Tormenta solar! Vuelve al hábitat en %d s." % seconds,
			"Solar storm! Return to the habitat within %d s." % seconds)
		EventBus.event_triggered.emit(&"solar_storm")
	elif _phase == "countdown":
		_countdown = maxf(_countdown - delta, 0.0)
		if _countdown <= 0.0:
			_phase = "window"
			_window = _rule("window_seconds", 60.0)
			_solar_notice("¡Partículas solares! REFUGIO INMEDIATO.",
				"Solar radiation! SHELTER IMMEDIATELY.")
	elif _phase == "window":
		var mult := protection_multiplier()
		var full := storm_full_dose(_storm_level)
		var span := maxf(_rule("window_seconds", 60.0), 1.0)
		var storm_dose_delta := full * (delta / span) * mult
		GameState.dose_msv += storm_dose_delta
		GameState.daily_dose_msv += storm_dose_delta
		_note_zone(mult, delta)
		# Outside is lethal after prolonged exposure during an intense event.
		# Shelter halts this game meter; the cave protects less than a habitat.
		if GameState.interior_id == &"":
			_storm_danger += delta * (3.6 if _storm_level >= 3 else 2.8)
		elif GameState.interior_id == &"cave":
			_storm_danger += delta * 0.45
		else:
			_storm_danger = maxf(_storm_danger - delta * 4.5, 0.0)
		if _storm_danger >= 60.0 and not _warned_danger:
			_warned_danger = true
			_solar_notice("¡Exposición crítica! Entra al hábitat ahora.",
				"Critical exposure! Enter the habitat now.")
		if _storm_danger >= DANGER_THRESHOLD:
			GameState.set_flag(&"lethal_solar_exposure", true)
			GameState.add_raw("Exposición solar fatal fuera del refugio.",
				"Fatal solar storm exposure outside shelter.")
			EndingSystem.try_end(&"radiation")
			return
		if mult >= 0.99:
			GameState.set_flag(&"storm_outside", true)
		_window -= delta
		if _window <= 0.0:
			_finish_storm()
	if _snow != null:
		_snow.active = _phase == "window" and GameState.interior_id == &""


func show_capsule(id: String, automatic: bool = true) -> void:
	if not SHOW_FACT_POPUPS:
		return
	if id.is_empty() or capsule(id).is_empty():
		return
	_queue.append({"kind": "text", "id": id, "auto": automatic})
	_pump()


func show_manual(id: String) -> void:
	show_capsule(id, false)


func energy_capsule() -> String:
	_energy_flip = not _energy_flip
	return "spirit_dust" if _energy_flip else "dust"


func show_photos(ids: PackedStringArray, then_capsules: PackedStringArray = PackedStringArray()) -> void:
	if not SHOW_FACT_POPUPS:
		return
	_queue.append({"kind": "photos", "ids": ids, "then": then_capsules, "auto": false})
	_pump()


func visible_storm_countdown() -> int:
	# Give a 15-second early warning, but only show the final five numbers.
	if _phase != "countdown":
		return 0
	if _countdown > 5.0:
		return 0
	return clampi(ceili(_countdown), 1, 5)


func radiation_shielding() -> float:
	# Gameplay-only percent of effective suit protection remaining during an
	# acute particle event. Recover in shelter or as the storm settles.
	return clampf(100.0 - _storm_danger, 0.0, 100.0)


func countdown_left() -> float:
	if _phase == "countdown":
		return _countdown
	return 0.0


func solar_storm_countdown_active() -> bool:
	return _phase == "countdown"


func solar_storm_active() -> bool:
	return _phase == "window"


func solar_storm_danger() -> float:
	return clampf(_storm_danger / DANGER_THRESHOLD, 0.0, 1.0)


## Debug-only preview of the warning, flare visuals, shelter safety and ending.
func debug_trigger_solar_storm() -> void:
	if not OS.is_debug_build() or not DayNightSystem.has_started() or GameState.run_over:
		return
	_storm_level = 3
	_storm_danger = 0.0
	_warned_danger = false
	_phase = "countdown"
	_countdown = 15.0
	_window = 0.0
	_solar_notice("Prueba: tormenta solar en 15 s. ¡Refugio!",
		"TEST: solar storm in 15 s. Seek shelter!")
	EventBus.event_triggered.emit(&"solar_storm")


func _solar_notice(es: String, en: String) -> void:
	GameState.add_raw(es, en)
	var hud := get_tree().get_first_node_in_group(&"hud")
	if hud != null and hud.has_method(&"show_notice"):
		hud.call(&"show_notice", Settings.pack(es, en))


func dose_danger() -> bool:
	return _phase == "countdown" or _phase == "window"


func blocks_capsules() -> bool:
	return _phase == "countdown"


func protection_multiplier() -> float:
	var refuge := _rule("mult_refuge", 0.25)
	var interior := _rule("mult_interior", 0.5)
	var outside := _rule("mult_outside", 1.0)
	if GameState.interior_id == &"cave":
		return refuge
	if GameState.interior_id == &"habitat" and GameState.shelter_today == "bags":
		return refuge
	if GameState.interior_id != &"":
		return interior
	return outside


func storm_dose(level: int, seconds: float, mult: float) -> float:
	var span := maxf(_rule("window_seconds", 60.0), 1.0)
	return storm_full_dose(level) * (seconds / span) * mult


func storm_full_dose(level: int) -> float:
	if level >= 3:
		return _rule("storm_level3_msv", 5.0)
	if level >= 2:
		return _rule("storm_level2_msv", 2.0)
	return 0.0


func adopt_plan(option_id: String) -> void:
	match option_id:
		"bags":
			GameState.shelter_next = "bags"
			GameState.set_flag(&"built_shelter", true)
		"seal":
			GameState.shelter_next = "sealed"
		"plan":
			GameState.shelter_next = "open"


func advance_exercise(_sol: int) -> void:
	# No habitat bike remains, so skipped-day penalties are not applied.
	GameState.exercised_today = false
	GameState.weak_muscles = false


func finish_exercise() -> void:
	if GameState.exercised_today or GameState.run_over:
		return
	ResourceSystem.add(&"energy", _rule("exercise_energy", -2.0))
	ResourceSystem.add(&"food", _rule("exercise_food", -2.0))
	GameState.exercised_today = true
	GameState.exercise_days += 1
	GameState.days_without_exercise = 0
	GameState.weak_muscles = false
	GameState.set_flag(&"weak_told", false)
	GameState.set_flag(&"exercised_any", true)
	if not GameState.has_flag(&"exercise_study"):
		GameState.set_flag(&"exercise_study", true)
		show_capsule("bedrest" if _rng.randf() < 0.5 else "mice", true)


func exercise_seconds() -> float:
	return _rule("exercise_seconds", 3.0)


func weak_run_scale() -> float:
	return _rule("weak_run_scale", 0.85)


func weak_jump_scale() -> float:
	return _rule("weak_jump_scale", 0.85)


func on_message_arrived() -> void:
	if GameState.has_flag(&"isolation_said"):
		return
	GameState.set_flag(&"isolation_said", true)
	show_capsule("isolation", true)


func on_main_started(id: StringName) -> void:
	if SHOW_FACT_POPUPS:
		for spot in _places_for(String(id)):
			var text_id := "place:" + String(spot.get("id", ""))
			_queue.append({"kind": "place", "place": spot, "auto": true, "id": text_id})
		_pump()
	if id == &"grow_potato":
		show_capsule("regolith", true)


func on_harvest() -> void:
	var plants: Array[String] = ["lettuce", "peppers", "tomato_light"]
	show_capsule(plants[_rng.randi() % plants.size()], true)


func on_rovers_done() -> void:
	show_photos(PackedStringArray(["PIA22930", "PIA17760"]), PackedStringArray(["opportunity", "spirit"]))


func note_message(delay: float) -> void:
	GameState.message_count += 1
	GameState.message_wait_sum += maxf(delay, 0.0)


func hold_message(delay: float, text: String, already_counted: bool = false) -> void:
	GameState.held_messages.append({"delay": delay, "text": text, "counted": already_counted})


func debrief_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var span := format_span(String(_scenario.get("start", "")), String(_scenario.get("end", "")))
	if Settings.lang == "en":
		lines.append("Real space weather from %s." % span)
	else:
		lines.append("Clima espacial real del %s." % span)
	lines.append(_storm_recap())
	lines.append(_dose_recap())
	lines.append(_message_recap())
	return lines


func hazard_rows() -> Array:
	return [
		{
			"id": "radiation",
			"es": "Radiación",
			"en": "Radiation",
			"game_es": "Contador de dosis y tormentas solares reales. El refugio se paga con comida y energía.",
			"game_en": "A dose counter and real solar storms. The shelter is paid for with food and energy.",
			"fact_es": "0,67 mSv al día en la superficie (Curiosity RAD). El blindaje baja las partículas de una tormenta a la mitad.",
			"fact_en": "0.67 mSv a day on the surface (Curiosity RAD). Shielding cuts solar-storm particles by half.",
			"src": "rad_surface",
		},
		{
			"id": "isolation",
			"es": "Aislamiento",
			"en": "Isolation",
			"game_es": "Mensajes de Quito que llegan tarde, o no llegan en la conjunción. INTI acompaña.",
			"game_en": "Messages from Quito that arrive late, or not at all in conjunction. INTI stays with you.",
			"fact_es": "Vivir lejos y en un lugar pequeño cansa la mente. Por eso importan los mensajes de casa.",
			"fact_en": "Living far away in a small place tires the mind. That is why messages from home matter.",
			"src": "hrp_hazards",
		},
		{
			"id": "distance",
			"es": "Distancia de la Tierra",
			"en": "Distance from Earth",
			"game_es": "La respuesta tarda lo que tarda la luz ese Día. En la conjunción no hay contacto.",
			"game_en": "A reply takes as long as the light does that Day. In conjunction there is no contact.",
			"fact_es": "Un mensaje tarda entre 3 y 22 minutos. En este juego, 1 minuto de luz son 2 segundos.",
			"fact_en": "A message takes 3 to 22 minutes. In this game, 1 minute of light is 2 seconds.",
			"src": "relay",
		},
		{
			"id": "gravity",
			"es": "Gravedad",
			"en": "Gravity",
			"game_es": "En Marte la gravedad es el 38 % de la de la Tierra.",
			"game_en": "On Mars, gravity is 38% of Earth's.",
			"fact_es": "En la Estación, unos 2 horas de ejercicio al día. OSD-342, OSD-937, OSD-946, OSD-396 y OSD-984.",
			"fact_en": "On the Station, about 2 hours of exercise a day. OSD-342, OSD-937, OSD-946, OSD-396 and OSD-984.",
			"src": "bone_muscle",
		},
		{
			"id": "environment",
			"es": "Ambiente cerrado u hostil",
			"en": "Closed or hostile environment",
			"game_es": "Oxígeno, energía y comida. El invernadero da comida y un poco de aire.",
			"game_en": "Oxygen, energy and food. The greenhouse gives food and a little air.",
			"fact_es": "El aire de Marte es 95 % CO2. MOXIE sacó 122 g de oxígeno. Las plantas reciclan el CO2.",
			"fact_en": "Mars air is 95% CO2. MOXIE made 122 g of oxygen. Plants recycle CO2.",
			"src": "nssdc_mars",
		},
	]


func glossary() -> Array:
	return [
		{"es": "sol", "en": "sol", "capsule": "sol"},
		{"es": "radiación", "en": "radiation", "capsule": "radiation"},
		{"es": "dosis", "en": "dose", "capsule": "rad_mars"},
		{"es": "mSv", "en": "mSv", "capsule": "rad_earth"},
		{"es": "microgravedad", "en": "microgravity", "capsule": "microgravity"},
		{"es": "regolito", "en": "regolith", "capsule": "regolith"},
		{"es": "retraso de la luz", "en": "light delay", "capsule": "delay"},
		{"es": "llamarada", "en": "flare", "capsule": "flare"},
		{"es": "partículas solares", "en": "solar particles", "capsule": "particles"},
		{"es": "conjunción", "en": "conjunction", "capsule": "blackout"},
	]


func glossary_line() -> String:
	var rows := glossary()
	if rows.is_empty():
		return ""
	var row: Dictionary = rows[_glossary_i % rows.size()]
	_glossary_i += 1
	var term := String(row.get("en" if Settings.lang == "en" else "es", ""))
	return "%s: %s" % [term, capsule(String(row.get("capsule", "")))]


func banner() -> String:
	if Settings.lang == "en":
		return "Real data from NASA and the Canadian Space Agency, saved in the game on November 13, 2026. This is not live data."
	return "Datos reales de la NASA y de la Agencia Espacial Canadiense, guardados en el juego el 13 de noviembre de 2026. No son datos en vivo."


func honesty() -> String:
	if Settings.lang == "en":
		return "We use real storms NASA saw on those dates, as if they reached your base. Not all of them were aimed at Mars."
	return "Usamos tormentas reales que vio la NASA en esas fechas, como si llegaran a tu base. No todas apuntaban a Marte."


func places_note() -> String:
	if Settings.lang == "en":
		return "In the game these places are close together so you can visit them. On Mars they are thousands of kilometers apart."
	return "En el juego estos lugares están cerca para que puedas visitarlos. En Marte están a miles de kilómetros entre sí."


func accessed_line() -> String:
	if Settings.lang == "en":
		return "accessed on November 13, 2026"
	return "consultado el 13 de noviembre de 2026"


func has_played() -> bool:
	return not Settings.last_scenario.is_empty()


func display_scenario() -> Dictionary:
	if not _scenario.is_empty() and has_played():
		return _scenario
	if has_played():
		for row in _scenarios:
			if row is Dictionary and String(row.get("id", "")) == Settings.last_scenario:
				return row
	for row in _scenarios:
		if row is Dictionary and String(row.get("id", "")) == EXAMPLE_ID:
			return row
	return {}


func scenario_is_example() -> bool:
	return not has_played()


func hazard_texture(id: String) -> Texture2D:
	var path := String(HAZARD_TEX.get(id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)


func hazard_for(capsule_id: String) -> String:
	match capsule_id:
		"radiation", "rad_mars", "rad_cruise", "rad_earth", "rad_ct", "rad_storm2024", "rad_limit", "rad_mission", "shield", "shield_gcr", "orion", "caves", "flare", "particles", "magnet", "iss_storm", "curiosity_snow":
			return "radiation"
		"isolation", "blackout":
			return "isolation"
		"delay", "relay", "no_sight", "distance", "resupply":
			return "distance"
		"gravity", "microgravity", "bone", "exercise", "mice", "bedrest":
			return "gravity"
		_:
			return "environment"


func short_source(id: String) -> String:
	var clean := id.strip_edges()
	var known := {
		"hrp_hazards": {"es": "NASA, 5 peligros", "en": "NASA, 5 hazards"},
		"donki": {"es": "NASA DONKI", "en": "NASA DONKI"},
		"horizons": {"es": "NASA JPL Horizons", "en": "NASA JPL Horizons"},
		"radlab": {"es": "NASA RadLab", "en": "NASA RadLab"},
		"rad_surface": {"es": "NASA, Curiosity RAD", "en": "NASA, Curiosity RAD"},
		"srag_faq": {"es": "NASA, SRAG", "en": "NASA, SRAG"},
		"ochmo_radiation": {"es": "NASA OCHMO", "en": "NASA OCHMO"},
		"orion_shelter": {"es": "NASA, Orion", "en": "NASA, Orion"},
		"mars_storm_2024": {"es": "NASA", "en": "NASA"},
		"mars_facts": {"es": "NASA Science", "en": "NASA Science"},
		"nssdc_mars": {"es": "NASA NSSDC", "en": "NASA NSSDC"},
		"jpl_glance": {"es": "NASA JPL", "en": "NASA JPL"},
		"relay": {"es": "NASA, Mars Relay", "en": "NASA, Mars Relay"},
		"nasa_comms_pdf": {"es": "NASA", "en": "NASA"},
		"bone_muscle": {"es": "NASA", "en": "NASA"},
		"rad_comparison": {"es": "NASA Science", "en": "NASA Science"},
		"nasa_std_3001": {"es": "NASA-STD-3001", "en": "NASA-STD-3001"},
		"csa_tomatosphere": {"es": "CSA, Tomatosphere", "en": "CSA, Tomatosphere"},
		"csa_eating": {"es": "CSA", "en": "CSA"},
		"csa_growing": {"es": "CSA", "en": "CSA"},
		"csa_exercise": {"es": "CSA", "en": "CSA"},
		"moxie": {"es": "NASA, MOXIE", "en": "NASA, MOXIE"},
		"oppy_end": {"es": "NASA, Opportunity", "en": "NASA, Opportunity"},
		"spirit": {"es": "NASA, Spirit", "en": "NASA, Spirit"},
	}
	if known.has(clean):
		var row: Dictionary = known[clean]
		return String(row.get(Settings.lang, row.get("es", clean)))
	if clean.begins_with("osd"):
		return "NASA OSDR, %s" % clean.to_upper().replace("OSD", "OSD-")
	if clean.begins_with("img_"):
		return "NASA/JPL-Caltech"
	var full := String(source(clean).get("name", clean))
	if full.length() > 48:
		return full.substr(0, 46)
	return full


func source_line(capsule_id: String) -> String:
	var raw := String(_capsules.get(capsule_id, {}).get("src", ""))
	var parts := raw.split(",")
	var names: PackedStringArray = []
	for part in parts:
		var bit := short_source(String(part))
		if not bit.is_empty() and bit not in names:
			names.append(bit)
	var joined := ", ".join(names)
	if Settings.lang == "en":
		return "Source: %s" % joined
	return "Fuente: %s" % joined


func present_text(id: String) -> String:
	var text := capsule(id)
	if id == "particles":
		var seconds := int(_rule("warning_seconds", 30.0))
		if Settings.lang == "en":
			text += "\nOn Mars, the particles arrive in tens of minutes. In the game, in %d seconds." % seconds
		else:
			text += "\nEn Marte, las partículas llegan en decenas de minutos. En el juego, en %d segundos." % seconds
	elif id == "exercise":
		if Settings.lang == "en":
			text += "\nThe data comes from the Space Station (microgravity) and from bed-rest studies. On Mars gravity is 38% of Earth's and nobody knows yet how much bone is lost. In the game the effect shows up sooner so you can feel it: in space, the loss is about 1% of bone per month."
		else:
			text += "\nLos datos vienen de la Estación Espacial (microgravedad) y de estudios de reposo en cama. En Marte la gravedad es 38 % de la Tierra y todavía no se sabe cuánto hueso se pierde. En el juego el efecto llega antes para que se note: en el espacio, la pérdida es cerca de 1 % de hueso por mes."
	return text


func image_record(id: String) -> Dictionary:
	for row in _images:
		if row is Dictionary and String(row.get("id", "")) == id:
			return row
	return {}


func image_texture(id: String) -> Texture2D:
	var row := image_record(id)
	var path := String(row.get("file", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	return tex


func open_url(url: String) -> void:
	if url.begins_with("http://") or url.begins_with("https://"):
		OS.shell_open(url)


func num(value: float, digits: int = 1) -> String:
	var text := String.num(value, digits)
	if Settings.lang == "es":
		text = text.replace(".", ",")
	return text


func format_date(iso: String) -> String:
	var parts := iso.split("-")
	if parts.size() < 3:
		return iso
	var month := clampi(int(parts[1]), 1, 12)
	var day := int(parts[2])
	if Settings.lang == "en":
		return "%s %d, %s" % [MONTHS_EN[month - 1], day, parts[0]]
	return "%d de %s de %s" % [day, MONTHS_ES[month - 1], parts[0]]


func format_short(iso: String) -> String:
	var parts := iso.split("-")
	if parts.size() < 3:
		return iso
	var month := clampi(int(parts[1]), 1, 12)
	var day := int(parts[2])
	if Settings.lang == "en":
		return "%s %d, %s" % [MONTHS_SHORT_EN[month - 1], day, parts[0]]
	return "%d %s %s" % [day, MONTHS_SHORT_ES[month - 1], parts[0]]


func format_span(start: String, end: String) -> String:
	var a := start.split("-")
	var b := end.split("-")
	if a.size() < 3 or b.size() < 3:
		return "%s – %s" % [format_date(start), format_date(end)]
	var ma := clampi(int(a[1]), 1, 12)
	var mb := clampi(int(b[1]), 1, 12)
	if a[0] == b[0] and a[1] == b[1]:
		if Settings.lang == "en":
			return "%s %d to %d, %s" % [MONTHS_EN[ma - 1], int(a[2]), int(b[2]), a[0]]
		return "%d al %d de %s de %s" % [int(a[2]), int(b[2]), MONTHS_ES[ma - 1], a[0]]
	return "%s – %s" % [format_date(start), format_date(end)]


func place_line(spot: Dictionary) -> String:
	var lat := float(spot.get("lat", 0.0))
	var lon := float(spot.get("lon_e", 0.0))
	var ns := "S" if lat < 0.0 else "N"
	var east := lon >= 0.0
	var ew := ("E" if east else "W") if Settings.lang == "en" else ("E" if east else "O")
	var name := String(spot.get("name", "")).split(" (")[0]
	var coord := "%s, %s° %s, %s° %s" % [name, num(absf(lat), 2), ns, num(absf(lon), 2), ew]
	if Settings.lang == "en":
		return "Real place: %s (Mars Trek)." % coord
	return "Lugar real: %s (Mars Trek)." % coord


func _pump() -> void:
	if not SHOW_FACT_POPUPS:
		return
	if _card == null or _card.is_open():
		return
	if get_tree() != null and get_tree().paused:
		return
	if _phase == "countdown":
		var found := -1
		for i in _queue.size():
			if String(_queue[i].get("id", "")) == "particles":
				found = i
				break
		if found < 0:
			return
		var only: Dictionary = _queue.pop_at(found)
		if bool(only.get("auto", false)):
			_auto_today += 1
		_card.present(present_text("particles"), source_line("particles"), hazard_texture("radiation"))
		return
	while not _queue.is_empty():
		var item: Dictionary = _queue.pop_front()
		if bool(item.get("auto", false)) and _auto_today >= AUTO_CAP:
			continue
		if bool(item.get("auto", false)):
			_auto_today += 1
		if String(item.get("kind", "text")) == "photos":
			_show_photo_item(item)
		elif String(item.get("kind", "")) == "place":
			var spot: Dictionary = item.get("place", {})
			var key := "en" if Settings.lang == "en" else "es"
			_card.present(String(spot.get(key, "")), source_line("distance"), hazard_texture("distance"))
		else:
			var id := String(item.get("id", ""))
			_card.present(present_text(id), source_line(id), hazard_texture(hazard_for(id)))
		return


func _on_card_dismissed() -> void:
	_pump()


func _process(_delta: float) -> void:
	if not SHOW_FACT_POPUPS:
		if _card != null and _card.is_open():
			_card.hide_card()
		return
	if get_tree().paused:
		return
	if _card != null and not _card.is_open() and not _queue.is_empty():
		_pump()


func _show_photo_item(item: Dictionary) -> void:
	var photos: Array = []
	for id in item.get("ids", []):
		var row := image_record(String(id))
		var tex := image_texture(String(id))
		if tex == null:
			continue
		var key := "en" if Settings.lang == "en" else "es"
		photos.append({
			"texture": tex,
			"caption": String(row.get(key, "")),
			"credit": String(row.get("credit", "NASA/JPL-Caltech")),
		})
	if photos.is_empty():
		_pump()
		return
	var credit := "NASA/JPL-Caltech"
	_card.present("", credit, null, photos)
	for capsule_id in item.get("then", []):
		_queue.append({"kind": "text", "id": String(capsule_id), "auto": false})


func _arm_storm(day: Dictionary) -> void:
	_storm_danger = 0.0
	_warned_danger = false
	_storm_level = int(day.get("level", 2))
	_storm_at = 0.30 if GameState.current_sol == SCRIPTED_SOLAR_STORM_SOL else _rng.randf_range(_rule("window_start_min", 0.25), _rule("window_start_max", 0.60))
	_phase = "wait"
	_zones = {"out": 0.0, "base": 0.0, "refuge": 0.0, "cave": 0.0}


func _finish_storm() -> void:
	_phase = "done"
	if GameState.current_sol == SCRIPTED_SOLAR_STORM_SOL:
		GameState.set_flag(&"sol3_solar_storm_resolved", true)
	var where := "out"
	var best := -1.0
	for key in _zones:
		if float(_zones[key]) > best:
			best = float(_zones[key])
			where = String(key)
	var day := today()
	GameState.storms_faced.append({
		"date": String(day.get("date", "")),
		"flare": String(day.get("flare", "")),
		"sep": int(day.get("sep", 0)),
		"where": where,
	})
	if _snow != null:
		_snow.active = false


func _note_zone(mult: float, delta: float) -> void:
	if GameState.interior_id == &"cave":
		_zones["cave"] = float(_zones["cave"]) + delta
	elif GameState.interior_id == &"habitat" and GameState.shelter_today == "bags":
		_zones["refuge"] = float(_zones["refuge"]) + delta
	elif GameState.interior_id != &"":
		_zones["base"] = float(_zones["base"]) + delta
	else:
		_zones["out"] = float(_zones["out"]) + delta
	if mult < 0.99:
		pass


func _hold_live_messages() -> void:
	if GameState.message_delay_left >= 0.0 and not GameState.message_text.is_empty():
		hold_message(GameState.message_delay_left, GameState.message_text, true)
		GameState.message_delay_left = -1.0
		GameState.message_text = ""
	while not GameState.message_queue.is_empty():
		var next: Dictionary = GameState.message_queue.pop_front()
		hold_message(float(next.get("delay", 0.0)), String(next.get("text", "")), true)


func _release_held() -> void:
	if GameState.held_messages.is_empty():
		return
	var waiting: Array = GameState.held_messages.duplicate()
	GameState.held_messages.clear()
	for item in waiting:
		if not item is Dictionary:
			continue
		GameState.enqueue_message(float(item.get("delay", 0.0)), String(item.get("text", "")), not bool(item.get("counted", false)))


func _level_one_line(day: Dictionary) -> String:
	var flare := String(day.get("flare", ""))
	if not flare.is_empty():
		if Settings.lang == "en":
			return Settings.pack("Llamarada %s. Hoy no llegó nada fuerte." % flare, "%s flare. Nothing strong arrived today." % flare)
		return Settings.pack("Llamarada %s. Hoy no llegó nada fuerte." % flare, "%s flare. Nothing strong arrived today." % flare)
	if int(day.get("cme_kms", 0)) > 0:
		var speed := int(day.get("cme_kms", 0))
		return Settings.pack(
			"Nube solar a %d km/s. Hoy no llegó nada fuerte." % speed,
			"Solar cloud at %d km/s. Nothing strong arrived today." % speed
		)
	return Settings.pack(
		"Aviso del Sol. Hoy no llegó nada fuerte.",
		"Sun notice. Nothing strong arrived today."
	)


func _kp_line(day: Dictionary) -> String:
	var kp := float(day.get("kp", 0.0))
	var shown := num(kp, 0 if is_equal_approx(kp, round(kp)) else 2)
	return Settings.pack(
		"Tormenta magnética en la Tierra (Kp %s). Marte no tiene ese escudo." % shown,
		"Magnetic storm on Earth (Kp %s). Mars has no shield like that." % shown
	)


func _storm_recap() -> String:
	if GameState.storms_faced.is_empty():
		if Settings.lang == "en":
			return "No particle storm reached the base on these 10 Days."
		return "En estos 10 Días no llegó una tormenta de partículas a la base."
	var bits: PackedStringArray = []
	for row in GameState.storms_faced:
		if not row is Dictionary:
			continue
		var flare := String(row.get("flare", ""))
		var kind := flare if not flare.is_empty() else "SEP"
		var where := _where_word(String(row.get("where", "out")))
		bits.append("%s, %s, %s" % [format_short(String(row.get("date", ""))), kind, where])
	if Settings.lang == "en":
		return "Storms: %s." % "; ".join(bits)
	return "Tormentas: %s." % "; ".join(bits)


func _where_word(where: String) -> String:
	var en := Settings.lang == "en"
	match where:
		"cave":
			return "in the cave" if en else "en la cueva"
		"refuge":
			return "in the shelter" if en else "en el refugio"
		"base":
			return "in the base" if en else "en la base"
		_:
			return "outside" if en else "afuera"


func _dose_recap() -> String:
	var dose := GameState.dose_msv
	var years := roundi(dose / 1.0)
	var year_text := ""
	if Settings.lang == "en":
		year_text = "less than 1 year" if years < 1 else ("%d years" % years)
		return "Your dose: %s mSv in %d Days. In Houston that would be %s of natural radiation. A real Mars mission: about 1,000 mSv." % [num(dose, 1), maxi(GameState.current_sol, 1), year_text]
	year_text = "menos de 1 año" if years < 1 else ("%d años" % years)
	return "Tu dosis: %s mSv en %d Días. En Houston serían %s de radiación natural. Una misión real a Marte: cerca de 1.000 mSv." % [num(dose, 1), maxi(GameState.current_sol, 1), year_text]


func _message_recap() -> String:
	if GameState.message_count <= 0:
		if Settings.lang == "en":
			return "You did not send a message to Earth."
		return "No enviaste un mensaje a la Tierra."
	var average := GameState.message_wait_sum / float(GameState.message_count)
	var minutes := average / maxf(_rule("light_seconds_per_minute", 2.0), 0.1)
	if Settings.lang == "en":
		return "You sent %d messages. Round trip, about %s minutes of light (in the game, %d s)." % [GameState.message_count, num(minutes, 1), roundi(average)]
	return "Enviaste %d mensajes. Ida y vuelta, unos %s minutos de luz (en el juego, %d s)." % [GameState.message_count, num(minutes, 1), roundi(average)]


func _notice_packed(text: String) -> void:
	if text.is_empty():
		return
	var hud := get_tree().get_first_node_in_group(&"hud") if get_tree() != null else null
	if hud != null and hud.has_method(&"show_notice"):
		hud.show_notice(text)


func _span(start: String, end: String, english: bool) -> String:
	var a := start.split("-")
	var b := end.split("-")
	if a.size() < 3 or b.size() < 3:
		return "%s – %s" % [start, end]
	var ma := clampi(int(a[1]), 1, 12)
	var mb := clampi(int(b[1]), 1, 12)
	if a[0] == b[0] and a[1] == b[1]:
		if english:
			return "%s %d to %d, %s" % [MONTHS_EN[ma - 1], int(a[2]), int(b[2]), a[0]]
		return "%d al %d de %s de %s" % [int(a[2]), int(b[2]), MONTHS_ES[ma - 1], a[0]]
	if english:
		return "%s %d, %s – %s %d, %s" % [MONTHS_EN[ma - 1], int(a[2]), a[0], MONTHS_EN[mb - 1], int(b[2]), b[0]]
	return "%d de %s de %s – %d de %s de %s" % [int(a[2]), MONTHS_ES[ma - 1], a[0], int(b[2]), MONTHS_ES[mb - 1], b[0]]


func _places_for(mission_id: String) -> Array:
	var wanted: PackedStringArray = []
	match mission_id:
		"recover_rovers":
			wanted = PackedStringArray(["gusev", "meridiani_planum"])
		"study_minerals":
			wanted = PackedStringArray(["meridiani_planum"])
		"search_biosignatures":
			wanted = PackedStringArray(["jezero"])
		"study_caves":
			wanted = PackedStringArray(["arsia_mons"])
		"study_glaciers":
			wanted = PackedStringArray(["hellas_planitia"])
		"find_water_ice":
			wanted = PackedStringArray(["planum_boreum"])
		"grow_potato":
			return []
		_:
			return []
	var found: Array = []
	for id in wanted:
		var row := place(id)
		if not row.is_empty():
			found.append(row)
	return found


func _reset_clock() -> void:
	_storm_danger = 0.0
	_warned_danger = false
	_phase = ""
	_countdown = 0.0
	_window = 0.0
	_storm_at = 1.0
	if _snow != null:
		_snow.active = false


func _scenario_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for row in _scenarios:
		if row is Dictionary:
			ids.append(String(row.get("id", "")))
	return ids


func _rule(key: String, fallback: float) -> float:
	return float(_rules.get(key, fallback))


func _ensure() -> void:
	if _ready_data:
		return
	_ready_data = true
	var sources: Variant = _read("sources.json")
	if sources is Dictionary:
		_accessed = String(sources.get("accessed", _accessed))
		for row in sources.get("sources", []):
			if row is Dictionary:
				_sources[String(row.get("id", ""))] = row
	var caps: Variant = _read("capsules.json")
	if caps is Dictionary:
		for row in caps.get("capsules", []):
			if row is Dictionary:
				_capsules[String(row.get("id", ""))] = row
	var weather: Variant = _read("space_weather_scenarios.json")
	if weather is Dictionary:
		_scenarios = weather.get("scenarios", [])
	var places: Variant = _read("mars_places.json")
	if places is Dictionary:
		for row in places.get("places", []):
			if row is Dictionary:
				_places[String(row.get("id", ""))] = row
	var studies: Variant = _read("osdr_studies.json")
	if studies is Dictionary:
		for row in studies.get("studies", []):
			if row is Dictionary:
				_studies[String(row.get("id", ""))] = row
	var photos: Variant = _read("rover_images.json")
	if photos is Dictionary:
		_images = photos.get("images", [])
	var loop: Variant = _read_path(LOOP_PATH)
	if loop is Dictionary:
		var block: Variant = loop.get("radiation", {})
		if block is Dictionary:
			_rules = block


func _read(file_name: String) -> Variant:
	return _read_path(DIR + file_name)


func _read_path(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("NasaData: could not read %s" % path)
		return null
	return JSON.parse_string(file.get_as_text())
