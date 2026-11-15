extends Node
## Continuous sol clock and gradual day-night tint. The clock wraps automatically at dawn.
## The journal opens when the player sleeps, or when a debug skip asks for it.
## Length and mission rules live in data/loop.json. The export is the fallback if that file is missing.

const LOOP_PATH := "res://data/loop.json"
const JOURNAL_SCENE := preload("res://scenes/ui/Journal.tscn")
## Sol progress where the sky starts going dark. The clock uses the same cut so
## 18:00 lines up with dusk and night hours keep going after that.
const DUSK_AT := 12.0 / 23.0

## Real seconds for one sol. Overwritten from data/loop.json on ready.
@export var sol_duration_seconds: float = 211.765

var _day_color := Color(1.0, 0.84, 0.66)
var _night_color := Color(0.20, 0.22, 0.36)
var _dust_mult := 0.5
var _weak_mult := 0.5
var _mission_sols := 10
var _rations: Array = []

var _started := false
var _running := false
var _night_held := false
var _journal_open := false
var _applying := false
var _elapsed := 0.0
const TIME_BOOST_MULTIPLIER := 4
var time_speed := 1
var _tonight_multiplier := 1.0
var _tonight_event: Dictionary = {}
var _power_mode := "all"

var _modulate: CanvasModulate
var _journal: Journal
var _sleep_overlay: CanvasLayer
var _sleep_requested := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_loop()
	_modulate = CanvasModulate.new()
	_modulate.color = Color.WHITE
	add_child(_modulate)


func _process(delta: float) -> void:
	if RunSession.is_suspended():
		return
	if not _running or GameState.run_over or get_tree().paused:
		return
	# Placement is the opening sequence, before the clock starts counting.
	if BasePlacer.active:
		return
	var duration := maxf(sol_duration_seconds, 1.0)
	if _night_held:
		# Explicit sleep/debug actions may hold the sol only while the journal is open.
		return
	_advance_sol_time(delta * float(time_speed), duration)
	_update_light(clampf(_elapsed / duration, 0.0, 1.0))
	_tick_message(delta * float(time_speed))
	NasaData.tick(delta * float(time_speed), clampf(_elapsed / duration, 0.0, 1.0))
	if _elapsed >= duration:
		_auto_dawn()


func _advance_sol_time(delta: float, _duration: float) -> void:
	# All sols, daylight and night, share the same real-seconds-to-game-minutes rate.
	_elapsed += delta


func offer_sleep() -> void:
	if not _running or _journal_open or GameState.run_over or BasePlacer.active:
		return
	# Keep the mandatory Sol 1 / Sol 3 hazards playable rather than allowing
	# the player to sleep at 06:00 and silently skip them.
	if _scheduled_storm_pending():
		return
	if is_instance_valid(_sleep_overlay):
		return
	_sleep_overlay = CanvasLayer.new()
	_sleep_overlay.layer = 60
	_sleep_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(_sleep_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.10, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_sleep_overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_sleep_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	var title := Label.new()
	title.text = "¿Dormir y recuperar energía?" if Settings.lang == "es" else "Sleep to recover energy?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(title)
	var yes := Button.new()
	yes.text = "DORMIR" if Settings.lang == "es" else "SLEEP"
	stack.add_child(yes)
	var no := Button.new()
	no.text = "CANCELAR" if Settings.lang == "es" else "CANCEL"
	stack.add_child(no)
	yes.pressed.connect(func() -> void:
		_close_sleep_overlay()
		request_sleep()
	)
	no.pressed.connect(_close_sleep_overlay)
	no.grab_focus()


func _scheduled_storm_pending() -> bool:
	var es := ""
	var en := ""
	if GameState.current_sol == 1 and (not bool(GameState.get_flag(&"sol1_sandstorm_started", false)) or WorldEventDirector.is_sandstorm_live()):
		es = "Primero debes superar la tormenta de polvo de hoy."
		en = "Survive today's dust storm before sleeping."
	elif GameState.current_sol == 3 and not bool(GameState.get_flag(&"sol3_solar_storm_resolved", false)):
		es = "Espera a que pase la alerta de radiación solar antes de dormir."
		en = "Wait until the solar radiation alert has passed before sleeping."
	else:
		return false
	var hud := get_tree().get_first_node_in_group(&"hud")
	if hud != null and hud.has_method(&"show_notice"):
		hud.call(&"show_notice", Settings.pack(es, en))
	return true


func is_sleep_confirmation_open() -> bool:
	return is_instance_valid(_sleep_overlay)


func _input(event: InputEvent) -> void:
	if is_sleep_confirmation_open() and event.is_action_pressed(&"pause"):
		_close_sleep_overlay()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	# T toggles game time, not movement speed. Repeated key-down events are ignored.
	if not event.is_action_pressed(&"time_boost") or event.is_echo():
		return
	if not can_fast_forward():
		return
	time_speed = 1 if time_speed == TIME_BOOST_MULTIPLIER else TIME_BOOST_MULTIPLIER
	get_viewport().set_input_as_handled()


func _close_sleep_overlay() -> void:
	if is_instance_valid(_sleep_overlay):
		_sleep_overlay.queue_free()
	_sleep_overlay = null


func cancel_sleep() -> void:
	if not _journal_open or _applying:
		return
	_sleep_requested = false
	ResourceSystem.set_solar_multiplier(_weather_multiplier(""))
	_close_journal()
	# Cancelling the sleep journal does not permanently lock the clock at 05:00.
	# The next active frame will roll into the next sol automatically.
	_night_held = false
	_elapsed = maxf(_elapsed, sol_duration_seconds)
	_running = true
	_update_light(1.0)


## The bed calls this. Same night as a debug skip: journal, rations, events, next day.
func request_sleep() -> void:
	if not _running or _journal_open or GameState.run_over or BasePlacer.active:
		return
	if _scheduled_storm_pending():
		return
	_night_held = true
	_elapsed = maxf(_elapsed, sol_duration_seconds)
	_update_light(1.0)
	_running = false
	_sleep_requested = true
	_open_journal()


## Display clock for the active sol. The playable daylight runs from 06:00 to 18:00.
## It is derived from the same elapsed timer as the lighting, so the display stays in sync.
func sol_progress() -> float:
	if not _started:
		return 0.0
	var duration := maxf(sol_duration_seconds, 1.0)
	return 1.0 if _night_held else clampf(_elapsed / duration, 0.0, 1.0)


func clock_text() -> String:
	if not _started:
		return "--:--"
	var duration: float = maxf(sol_duration_seconds, 1.0)
	var progress: float = clampf(_elapsed / duration, 0.0, 1.0)
	# 06:00 to the following 05:00 is displayed at one fixed rate. The same
	# progress also drives lighting, so day/night no longer jump in speed.
	var minutes := int(floor(6.0 * 60.0 + progress * 23.0 * 60.0 + 0.00001)) % (24 * 60)
	var hour: int = floori(float(minutes) / 60.0)
	var minute: int = minutes % 60
	return "%02d:%02d" % [hour, minute]


func can_fast_forward() -> bool:
	return _running and not _night_held and not _journal_open and not BasePlacer.active and not GameState.run_over and not RunSession.is_suspended() and not get_tree().paused and not Cutscenes.is_playing()


func is_night_held() -> bool:
	return _night_held


func start_mission() -> void:
	if _started:
		return
	_started = true
	time_speed = 1
	GameState.run_over = false
	GameState.current_sol = 0
	EventSystem.reset_run()
	IntiBrain.reset_run()
	_load_loop()
	_start_sol(1)


## Debug: open tonight's journal without waiting out the sol.
func skip_to_night() -> void:
	if not _running or _journal_open or GameState.run_over:
		return
	_night_held = true
	_elapsed = sol_duration_seconds
	_update_light(1.0)
	_running = false
	_open_journal()


## Debug: open the journal of the last day. Skipped nights are not spent, so bars stay as they are.
func skip_to_last_night() -> void:
	if not _running or _journal_open or GameState.run_over:
		return
	GameState.current_sol = _mission_sols
	_night_held = true
	_elapsed = sol_duration_seconds
	_update_light(1.0)
	_running = false
	_open_journal()


func has_started() -> bool:
	return _started


func is_journal_open() -> bool:
	return _journal_open


## False while the night page is open or the night is being applied, so an ending waits for that step.
func accepts_live_end() -> bool:
	return _started and not _journal_open and not _applying


func mission_length() -> int:
	return _mission_sols


func sols_left() -> int:
	return maxi(_mission_sols - GameState.current_sol, 0)


func halt_for_ending() -> void:
	reset_cycle()
	if get_tree().paused:
		get_tree().paused = false


func commit_night(ration_id: String, powered_ids: Array[StringName], option_id: String) -> void:
	if _applying or not _journal_open:
		return
	_applying = true
	var extras: Dictionary = {}
	var ration := _ration_by_id(ration_id)
	if ration.is_empty():
		push_error("DayNightSystem: unknown ration '%s'" % ration_id)
		_applying = false
		return
	_merge_effects(extras, ration.get("effects", {}))
	GameState.log_decision(Settings.format_both(
		"journal.dinner_log",
		[String(ration.get("label", ration_id))],
		[String(ration.get("label_en", ration.get("label", ration_id)))]
	))
	if String(ration.get("id", "")) == "none":
		GameState.meals_skipped += 1

	if _power_mode == "choose":
		var pair := _name_pair(powered_ids)
		GameState.log_decision(Settings.format_both("journal.power_log", [pair[0]], [pair[1]]))
	elif _power_mode == "none":
		GameState.log_decision(Settings.format_both("journal.power_nobody"))

	var event_id := String(_tonight_event.get("id", ""))
	var weakened := false
	if not event_id.is_empty():
		var option := _option_by_id(option_id)
		if option.is_empty():
			push_warning("DayNightSystem: journal closed without an event choice.")
		else:
			_merge_effects(extras, option.get("effects", {}))
			var flags: Dictionary = option.get("effects", {}).get("flags", {})
			weakened = int(flags.get("panel_weak_sols", 0)) > 0
			EventBus.decision_made.emit(StringName(event_id), StringName(String(option.get("id", option_id))))
			GameState.log_decision(Settings.pack(
				String(option.get("label", option_id)) + ".",
				String(option.get("label_en", option.get("label", option_id))) + "."
			))
		GameState.last_event_id = StringName(event_id)
		if event_id == "radiation_alert":
			NasaData.adopt_plan(String(option.get("id", option_id)))
		if event_id == "harvest":
			NasaData.on_harvest()

	# Resources first, then flags. A harvest saved for tomorrow must not be eaten tonight,
	# and a module hit by a meteor still got to work today.
	ResourceSystem.set_solar_multiplier(_tonight_multiplier)
	ResourceSystem.apply_night(powered_ids, extras)
	# Debug-night shortcuts open a journal without sleeping: never recharge there.
	if _sleep_requested:
		ResourceSystem.recharge_from_sleep()
	_sleep_requested = false
	if not event_id.is_empty():
		var chosen := _option_by_id(option_id)
		if not chosen.is_empty():
			EventSystem.apply_flags(_tonight_event, chosen)
	_advance_weather(event_id, weakened)
	_applying = false
	_close_journal()
	if event_id == "meteor":
		CameraRig.nudge_current()
	# If an ending already started, don't open the next day on top of it.
	if GameState.run_over or EndingSystem.try_end(&"journal"):
		return
	_start_sol(GameState.current_sol + 1)


func reset_cycle() -> void:
	_close_sleep_overlay()
	_sleep_requested = false
	time_speed = 1
	_started = false
	_running = false
	_night_held = false
	_journal_open = false
	_applying = false
	_elapsed = 0.0
	_tonight_event = {}
	_tonight_multiplier = 1.0
	EventSystem.reset_run()
	WorldEventDirector.reset_run()
	MissionSystem.abandon_run()
	IntiBrain.reset_run()
	if Cutscenes.is_playing():
		Cutscenes.skip()
	get_tree().paused = false
	ResourceSystem.set_solar_multiplier(1.0)
	if _modulate:
		_modulate.color = Color.WHITE
	if is_instance_valid(_journal):
		_journal.queue_free()
	_journal = null
	GameState.active_event = ""


func _start_sol(n: int) -> void:
	_sleep_requested = false
	# Preserve the player's x1/x4 toggle across sols; reset only on a fresh run.
	GameState.current_sol = n
	_elapsed = 0.0
	_night_held = false
	_running = true
	_journal_open = false
	ResourceSystem.reset_outside_seconds()
	# A little Martian dust accumulates each sol. Cleaning is therefore useful
	# even between major storms; the deposit is not erased at the next dawn.
	if n > 1:
		for module in ResourceSystem.get_modules():
			if module.data != null and module.data.id == &"solar_panel":
				GameState.solar_panel_dust = minf(100.0, GameState.solar_panel_dust + 8.0)
				break
	ResourceSystem.set_solar_multiplier(_weather_multiplier(""))
	_update_light(0.0)
	EventBus.sol_started.emit(n)
	NasaData.on_sol_started(n)
	if not GameState.run_over:
		var line := EventSystem.check_day(n)
		if not line.is_empty():
			_notify(line)


func _open_journal() -> void:
	if _journal_open or GameState.run_over:
		return
	_journal_open = true
	_tonight_event = EventSystem.roll(GameState.current_sol)
	var event_id := String(_tonight_event.get("id", ""))
	_tonight_multiplier = _weather_multiplier(event_id)
	ResourceSystem.set_solar_multiplier(_tonight_multiplier)
	GameState.active_event = event_id
	var report := _build_report()
	_journal = JOURNAL_SCENE.instantiate()
	_journal.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(_journal)
	_journal.open(report)
	get_tree().paused = true
	if not event_id.is_empty():
		EventBus.event_triggered.emit(StringName(event_id))


func _close_journal() -> void:
	_journal_open = false
	_tonight_event = {}
	GameState.active_event = ""
	if get_tree().paused:
		get_tree().paused = false
	if is_instance_valid(_journal):
		_journal.queue_free()
	_journal = null


func _build_report() -> Dictionary:
	var consumers := ResourceSystem.night_consumers()
	var budget := ResourceSystem.solar_budget()
	var total := 0
	for module in consumers:
		total += roundi(module.data.energy_cost_per_sol)
	var fits_some := false
	for module in consumers:
		if roundi(module.data.energy_cost_per_sol) <= budget:
			fits_some = true
			break
	if consumers.is_empty() or budget <= 0 or not fits_some:
		_power_mode = "none"
	elif total > budget:
		_power_mode = "choose"
	else:
		_power_mode = "all"

	var greedy := _greedy(consumers, budget)
	var modules: Array = []
	for module in consumers:
		var cost := roundi(module.data.energy_cost_per_sol)
		var effects: Dictionary = {}
		for resource_id in module.data.get_effects():
			effects[String(resource_id)] = module.data.get_effects()[resource_id]
		var role := module.data.describe_functions()
		modules.append({
			"id": String(module.data.id),
			"name": module.data.localized_name(),
			"detail": role if not role.is_empty() else Settings.text("journal.spend") % cost,
			"cost": cost,
			"effects": effects,
			"selected": module.data.id in greedy,
			"enabled": cost <= budget,
			"shelter": module.data.is_shelter,
			"comms": module.data.enables_comms,
		})

	var note := ""
	if _power_mode == "all":
		note = Settings.text("journal.power_all") % budget
	elif _power_mode == "none":
		note = Settings.text("journal.power_none") % budget
	else:
		note = Settings.text("journal.power_choose") % [budget, total]

	var locked: Array[StringName] = []
	if _power_mode == "all":
		for module in consumers:
			locked.append(module.data.id)

	return {
		"sol": GameState.current_sol,
		"mission_sols": _mission_sols,
		"summary_lines": _summary_lines(),
		"rations": _rations,
		"default_ration": "half",
		"power": {
			"mode": _power_mode,
			"budget": budget,
			"note": note,
			"modules": modules,
			"locked_ids": locked,
		},
		"event": _tonight_event,
	}


func _summary_lines() -> Array:
	var lines: Array = []
	lines.append(Settings.format_both("journal.summary", [GameState.current_sol]))
	for note in GameState.pending_notes:
		lines.append(String(note))
	GameState.pending_notes = PackedStringArray()
	if ResourceSystem.get_outside_seconds() >= 30.0:
		lines.append(Settings.format_both("journal.walked"))
	var budget := ResourceSystem.solar_budget()
	var event_id := String(_tonight_event.get("id", ""))
	# A dust storm already explains the panels. Other nights get a one-line note.
	if event_id != "dust_storm" and GameState.dust_sols_left > 0:
		lines.append(Settings.format_both("journal.dust", [budget]))
	elif event_id != "dust_storm" and GameState.panel_weak_sols_left > 0:
		lines.append(Settings.format_both("journal.weak", [budget]))
	elif event_id != "dust_storm":
		lines.append(Settings.format_both("journal.panels", [budget]))
	if ResourceSystem.get_value(&"food") < 30.0:
		lines.append(Settings.format_both("journal.food_low"))
	if ResourceSystem.get_value(&"oxygen") < 30.0:
		lines.append(Settings.format_both("journal.o2_low"))
	if ResourceSystem.get_value(&"energy") < 30.0:
		lines.append(Settings.format_both("journal.battery"))
	for note in NasaData.journal_lines(GameState.current_sol):
		lines.append(String(note))
	var broken_es: PackedStringArray = []
	var broken_en: PackedStringArray = []
	for module in ResourceSystem.get_modules():
		if module.damaged:
			broken_es.append(module.data.display_name)
			broken_en.append(module.data.name_en())
	if broken_es.size() > 0:
		lines.append(Settings.format_both("journal.broken", [", ".join(broken_es)], [", ".join(broken_en)]))
	if GameState.current_sol >= _mission_sols:
		lines.append(Settings.format_both("journal.last"))
	return lines


func _greedy(consumers: Array[BaseModule], budget: int) -> Array[StringName]:
	var sorted: Array = consumers.duplicate()
	sorted.sort_custom(func(a: BaseModule, b: BaseModule) -> bool:
		var a_rank := 0 if a.data.is_shelter else 1
		var b_rank := 0 if b.data.is_shelter else 1
		if a_rank != b_rank:
			return a_rank < b_rank
		return a.data.energy_cost_per_sol < b.data.energy_cost_per_sol
	)
	var ids: Array[StringName] = []
	var used := 0
	for module in sorted:
		var cost := roundi(module.data.energy_cost_per_sol)
		if used + cost <= budget:
			ids.append(module.data.id)
			used += cost
	return ids


func _advance_weather(event_id: String, panel_just_set: bool) -> void:
	# Shaking the panels keeps tonight dusty and skips the extra day. Shelter leaves one more.
	if event_id == "dust_storm":
		if bool(GameState.get_flag(&"cleaned_panels")):
			# The player chose the costly overnight maintenance option.
			GameState.dust_sols_left = 0
			GameState.panel_weak_sols_left = 0
			GameState.solar_panel_dust = 0.0
			GameState.set_flag(&"cleaned_panels", false)
		else:
			GameState.dust_sols_left = maxi(GameState.dust_sols_left, 1)
			GameState.solar_panel_dust = minf(100.0, GameState.solar_panel_dust + 42.0)
	elif GameState.dust_sols_left > 0:
		GameState.dust_sols_left -= 1
	if not panel_just_set and GameState.panel_weak_sols_left > 0:
		GameState.panel_weak_sols_left -= 1


## After a daytime shake, the next night should read the cleared dust and the firm panel.
func refresh_weather() -> void:
	if _journal_open:
		return
	ResourceSystem.set_solar_multiplier(_weather_multiplier(""))
	refresh_light()


func _weather_multiplier(event_id: String) -> float:
	var dusty := GameState.dust_sols_left > 0 or event_id == "dust_storm"
	var weak := GameState.panel_weak_sols_left > 0
	var multiplier := 1.0
	if dusty:
		multiplier = _dust_mult
	if weak:
		multiplier = minf(multiplier, _weak_mult)
	# Dust builds up independently from transient storm flags. At 100% dust,
	# panels still produce some power, but substantially less than when clean.
	var dust_efficiency := lerpf(1.0, 0.38, clampf(GameState.solar_panel_dust / 100.0, 0.0, 1.0))
	return minf(multiplier, dust_efficiency)


func _tick_message(delta: float) -> void:
	if GameState.message_delay_left < 0.0:
		return
	GameState.message_delay_left -= delta
	if GameState.message_delay_left > 0.0:
		return
	var text := GameState.take_arrived_message()
	if text.is_empty():
		return
	GameState.pending_notes.append(text)
	_notify(text)
	NasaData.on_message_arrived()


func _notify(text: String) -> void:
	var hud := get_tree().get_first_node_in_group(&"hud")
	if hud != null and hud.has_method(&"show_notice"):
		hud.show_notice(text)


## 0 at morning, 1 once the night tint is fully in. Lights read this; the modulate stays in charge of the sky.
func night_amount() -> float:
	if not _started:
		return 0.0
	var duration := maxf(sol_duration_seconds, 1.0)
	var t := 1.0 if _journal_open or not _running else clampf(_elapsed / duration, 0.0, 1.0)
	return _night_blend(t)


## Call after entering or leaving a room so the tint matches before the next clock tick.
func refresh_light() -> void:
	if not _started:
		return
	var duration := maxf(sol_duration_seconds, 1.0)
	var t := 1.0 if _journal_open or not _running else clampf(_elapsed / duration, 0.0, 1.0)
	_update_light(t)


## Dusk grows darker, and the last quarter of night gradually brightens into dawn.
func _night_blend(t: float) -> float:
	var dusk := smoothstep(DUSK_AT, 0.67, t)
	var dawn := 1.0 - smoothstep(0.79, 1.0, t)
	return clampf(dusk * dawn, 0.0, 1.0)


## Game-time minutes each real second, at the current speed and phase.
## Used by refill tanks for their two-in-game-hour recharge cycle.
func minutes_per_real_second() -> float:
	if not _running or _night_held or _journal_open or get_tree().paused or BasePlacer.active:
		return 0.0
	return (23.0 * 60.0) / maxf(sol_duration_seconds, 1.0) * float(time_speed)


## Continue into the next day without trapping the clock at 05:00.
## The optional bed/journal still applies player choices; an unattended night
## uses a conservative half-ration and available powered modules.
func _auto_dawn() -> void:
	if _journal_open or GameState.run_over:
		return
	var half := _ration_by_id("half")
	var extras: Dictionary = {}
	_merge_effects(extras, half.get("effects", {}))
	var powered_ids := _greedy(ResourceSystem.night_consumers(), ResourceSystem.solar_budget())
	ResourceSystem.apply_night(powered_ids, extras)
	_advance_weather("", false)
	if GameState.run_over or EndingSystem.try_end(&"journal"):
		return
	_start_sol(GameState.current_sol + 1)
	_notify(Settings.pack("Amaneció. Otro día empieza.", "Dawn has arrived. Another day begins."))


func _update_light(t: float) -> void:
	if _modulate == null:
		return
	var fade := _night_blend(t)
	# Caves have no sunlight. World-only NightVision supplies the real darkness and
	# helmet cone; avoid tinting the lamp's tiny illuminated area to near-black.
	if GameState.interior_id == &"cave":
		_modulate.color = Color(0.91, 0.82, 0.72)
	elif GameState.interior_id != &"":
		var indoor_day := Color(1.0, 0.94, 0.86)
		var indoor_night := Color(0.58, 0.62, 0.76)
		_modulate.color = indoor_day.lerp(indoor_night, fade)
	else:
		var day_phase := clampf(t / DUSK_AT, 0.0, 1.0)
		var sunrise := 1.0 - smoothstep(0.03, 0.24, day_phase)
		var sunset := smoothstep(0.68, 1.0, day_phase)
		var golden := maxf(sunrise, sunset) * (1.0 - fade)
		var sunlit := _day_color.lerp(Color("ffc393"), golden * 0.46)
		_modulate.color = sunlit.lerp(_night_color, fade)


func _ration_by_id(id: String) -> Dictionary:
	for ration in _rations:
		if String(ration.get("id", "")) == id:
			return ration
	return {}


func _option_by_id(id: String) -> Dictionary:
	for option in _tonight_event.get("options", []):
		if String(option.get("id", "")) == id:
			return option
	return {}


func _merge_effects(into: Dictionary, effects: Dictionary) -> void:
	for key in [&"oxygen", &"energy", &"food"]:
		var text := String(key)
		if effects.has(text):
			into[key] = float(into.get(key, 0.0)) + float(effects[text])


func _name_pair(ids: Array[StringName]) -> PackedStringArray:
	if ids.is_empty():
		var row: Dictionary = Settings.UI.get("journal.nobody", {})
		return PackedStringArray([String(row.get("es", "")), String(row.get("en", ""))])
	var spanish: PackedStringArray = []
	var english: PackedStringArray = []
	for id in ids:
		var data := BaseCatalog.get_module(id)
		if data:
			spanish.append(data.display_name)
			english.append(data.name_en())
		else:
			spanish.append(String(id))
			english.append(String(id))
	return PackedStringArray([", ".join(spanish), ", ".join(english)])


func _load_loop() -> void:
	var file := FileAccess.open(LOOP_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
	if not parsed is Dictionary:
		push_error("DayNightSystem: could not read %s" % LOOP_PATH)
		return
	sol_duration_seconds = float(parsed.get("sol_seconds", sol_duration_seconds))
	_mission_sols = int(parsed.get("mission_sols", _mission_sols))
	_dust_mult = float(parsed.get("dust_solar_multiplier", _dust_mult))
	_weak_mult = float(parsed.get("panel_weak_multiplier", _weak_mult))
	_day_color = _color_from(parsed.get("day_color"), _day_color)
	_night_color = _color_from(parsed.get("night_color"), _night_color)
	_rations = parsed.get("rations", [])


func _color_from(value: Variant, fallback: Color) -> Color:
	if value is Array and value.size() >= 3:
		return Color(float(value[0]), float(value[1]), float(value[2]))
	return fallback

