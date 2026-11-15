extends Node
## Immersive daytime Martian dust storms. Uses the existing HUD, repair, and weather systems.
## Storms fade in/out; only their *visible* intensity reduces movement and visibility.

const LIVE_STORM_DURATION := 34.0
const STORM_RAMP_IN := 5.0
const STORM_RAMP_OUT := 6.0
const STORM_PANEL_DUST := 48.0
const SCRIPTED_DUST_STORM_SOL := 1
const STORM_AFTER_SETUP_HOURS := 5.0
const STORM_NOTICE_HOURS_BEFORE := 1.0

var _roll_sol := -1
var _event_fired := false
var _rng := RandomNumberGenerator.new()
var _live_storm_left := 0.0
var _live_storm_elapsed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()


func reset_run() -> void:
	_roll_sol = -1
	_event_fired = false
	_live_storm_left = 0.0
	_live_storm_elapsed = 0.0
	GameState.live_sandstorm_left = 0.0


func _process(delta: float) -> void:
	if RunSession.is_suspended():
		return
	# Do not silently finish a storm during menus, paused journals or cutscenes.
	if GameState.run_over or BasePlacer.active or Cutscenes.is_playing() or get_tree().paused or DayNightSystem.is_journal_open():
		return
	if _live_storm_left > 0.0:
		_live_storm_elapsed += delta
		_live_storm_left = maxf(_live_storm_left - delta, 0.0)
		GameState.live_sandstorm_left = _live_storm_left
		if is_zero_approx(_live_storm_left):
			_finish_sandstorm()
	if not DayNightSystem.has_started():
		return
	if get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		return
	if GameState.current_sol != _roll_sol:
		_roll_sol = GameState.current_sol
		_event_fired = false
	# The landing/setup clock stays at 06:00 until the Ecuadorian flag and
	# solar panel are placed. Five Martian game-clock hours later = 11:00 on Sol 1.
	if _event_fired or GameState.current_sol != SCRIPTED_DUST_STORM_SOL:
		return
	if bool(GameState.get_flag(&"sol1_sandstorm_started", false)):
		_event_fired = true
		return
	if not _first_sol_setup_complete():
		return
	var daytime_hours := (DayNightSystem.sol_progress() / DayNightSystem.DUSK_AT) * 12.0
	if daytime_hours >= STORM_AFTER_SETUP_HOURS - STORM_NOTICE_HOURS_BEFORE and not bool(GameState.get_flag(&"sol1_storm_warning", false)):
		GameState.set_flag(&"sol1_storm_warning", true)
		var hud := get_tree().get_first_node_in_group(&"hud")
		if hud != null and hud.has_method(&"show_notice"):
			hud.call(&"show_notice", Settings.pack(
				"INTI: Tormenta de polvo en una hora. Prepara refugio.",
				"INTI: Dust storm in one hour. Prepare shelter."))
	if daytime_hours < STORM_AFTER_SETUP_HOURS:
		return
	_event_fired = true
	trigger_sandstorm()


func _first_sol_setup_complete() -> bool:
	if not bool(GameState.get_flag(&"ecuador_flag_planted", false)):
		return false
	if BasePlacer.active:
		return false
	for module in ResourceSystem.get_modules():
		if module.data != null and module.data.id == &"solar_panel":
			return true
	return false


func is_sandstorm_live() -> bool:
	return _live_storm_left > 0.0


func sandstorm_strength() -> float:
	if not is_sandstorm_live():
		return 0.0
	var rising := smoothstep(0.0, STORM_RAMP_IN, _live_storm_elapsed)
	var falling := smoothstep(0.0, STORM_RAMP_OUT, _live_storm_left)
	return clampf(minf(rising, falling), 0.0, 1.0)


func trigger_sandstorm() -> void:
	if GameState.run_over or BasePlacer.active or is_sandstorm_live():
		return
	_live_storm_left = LIVE_STORM_DURATION
	_live_storm_elapsed = 0.0
	if GameState.current_sol == SCRIPTED_DUST_STORM_SOL:
		GameState.set_flag(&"sol1_sandstorm_started", true)
	GameState.live_sandstorm_left = _live_storm_left
	GameState.dust_sols_left = maxi(GameState.dust_sols_left, 1)
	GameState.panel_weak_sols_left = maxi(GameState.panel_weak_sols_left, 1)
	GameState.solar_panel_dust = minf(100.0, GameState.solar_panel_dust + STORM_PANEL_DUST)
	GameState.set_flag(&"live_sandstorm", GameState.current_sol)
	GameState.set_flag(&"storm_aftermath_pending", true)
	ResourceSystem.set_solar_multiplier(0.42)
	var es := "¡Tormenta de polvo! Busca refugio: menos visibilidad y movimiento lento."
	var en := "Dust storm! Find shelter: reduced visibility and slower movement."
	GameState.add_raw(es, en)
	var hud := get_tree().get_first_node_in_group(&"hud")
	if hud != null and hud.has_method(&"show_notice"):
		hud.call(&"show_notice", Settings.pack(
			"¡Tormenta! Busca refugio.", "Dust storm! Find shelter."))
	EventBus.event_triggered.emit(&"live_dust_storm")


func _finish_sandstorm() -> void:
	if not bool(GameState.get_flag(&"storm_aftermath_pending", false)):
		return
	GameState.live_sandstorm_left = 0.0
	GameState.set_flag(&"storm_aftermath_pending", false)
	var panel: BaseModule = null
	var panel_exists := false
	var spare: BaseModule = null
	for module in ResourceSystem.get_modules():
		if module.data == null:
			continue
		if module.data.id == &"solar_panel":
			panel_exists = true
			if not module.damaged:
				panel = module
		elif not module.damaged and spare == null and not module.docked and module.data.id != &"habitat":
			spare = module
	var damaged_names_es: PackedStringArray = []
	var damaged_names_en: PackedStringArray = []
	# Dust is the common consequence. Mechanical failures are rarer and repairable.
	if panel != null and _rng.randf() < 0.28:
		_damage_module(panel, damaged_names_es, damaged_names_en)
	if spare != null and _rng.randf() < 0.15:
		_damage_module(spare, damaged_names_es, damaged_names_en)
	var es := "La tormenta terminó. Revisa el equipo exterior."
	var en := "Storm over. Inspect your equipment outdoors."
	if panel_exists:
		es = "Tormenta terminada. Panel con %d%% de polvo: acércate y pulsa E para limpiarlo." % roundi(GameState.solar_panel_dust)
		en = "Storm over. Panel dust: %d%%. Approach it and press E to clean it." % roundi(GameState.solar_panel_dust)
		if panel == null:
			es += " El panel ya estaba averiado; repáralo antes de limpiar."
			en += " The panel is already damaged; repair it before cleaning."
	if not damaged_names_es.is_empty():
		es += " Equipo averiado: %s. Repáralo primero." % ", ".join(damaged_names_es)
		en += " Damaged equipment: %s. Repair it first." % ", ".join(damaged_names_en)
	GameState.add_raw(es, en)
	var hud := get_tree().get_first_node_in_group(&"hud")
	if hud != null and hud.has_method(&"show_notice"):
		var notice_es := "Tormenta: revisa el equipo." if not panel_exists else "Tormenta: limpia el panel (%d%% polvo)." % roundi(GameState.solar_panel_dust)
		var notice_en := "Storm: inspect equipment." if not panel_exists else "Storm: clean panel (%d%% dust)." % roundi(GameState.solar_panel_dust)
		hud.call(&"show_notice", Settings.pack(notice_es, notice_en))
	DayNightSystem.refresh_weather()


func _damage_module(module: BaseModule, names_es: PackedStringArray, names_en: PackedStringArray) -> void:
	module.set_damaged(true)
	if module.data != null:
		if module.data.id not in GameState.damaged_module_ids:
			GameState.damaged_module_ids.append(module.data.id)
		names_es.append(module.data.display_name)
		names_en.append(module.data.name_en())
