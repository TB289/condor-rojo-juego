extends Node
## Owns oxygen, energy, food (and optional water). Values 0..100; tuning lives in data/resources.json.
## Every change goes out through EventBus.resource_changed / resource_empty.

const DATA_PATH := "res://data/resources.json"
const MAX_VALUE := 100.0
const CORE_IDS: Array[StringName] = [&"oxygen", &"energy", &"food"]
const WATER_ID := &"water"
## Suit oxygen per real minute on the surface. Idle is about a third of walking.
const O2_IDLE_DRAIN := 14.0
const O2_WALK_DRAIN := 42.0
const O2_RUN_DRAIN := 78.0
## A cave is unpressurized: suit oxygen drains at 75% of the surface rate and never refills automatically.
const O2_CAVE_SCALE := 0.75
## Stamina lost per real minute while awake. Sleep and mission rewards are what fill it back.
const ENERGY_DRAIN_PER_MIN := 10.0
const ENERGY_LOW_AT := 30.0

## Water is the optional 4th resource; off by default per sprint specs.
@export var use_water: bool = false

## 1 = clear sky. Dust and a weak panel lower it before solar_budget() / apply_night().
var solar_multiplier: float = 1.0

var _values: Dictionary[StringName, float] = {}
var _config: Dictionary = {}
var _outside: bool = false
var _outside_seconds: float = 0.0
var _modules: Array[BaseModule] = []
var _batch: bool = false
## Extra from the opening grab. The bars start full, so this is spent on the first night.
var _opening: Dictionary[StringName, float] = {}
var _energy_hint_said := false
## Persist between habitat room instances. The reserve charges over 120 game minutes.
var habitat_tank_stock: float = 100.0
var habitat_tank_in_use: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_config = _load_config()
	reset()


func _process(delta: float) -> void:
	if RunSession.is_suspended():
		return
	if not DayNightSystem.has_started() or GameState.run_over or BasePlacer.active:
		return
	if get_tree().paused or DayNightSystem.is_journal_open():
		return
	# Survival ticks follow the visible clock speed, including at night, but not while night is held.
	var elapsed := delta
	if DayNightSystem.can_fast_forward():
		elapsed *= float(DayNightSystem.time_speed)
	var in_cave := GameState.interior_id == &"cave"
	var in_shelter := GameState.interior_id != &"" and not in_cave
	if in_shelter:
		# Inside the pressurized ship, oxygen is preserved. Only the O2 tank
		# can actively refill it. Energy STILL drains each second below.
		pass
	else:
		# Surface, including camp, and the cave. Standing still still spends a little.
		if _outside:
			_outside_seconds += elapsed
		add(&"oxygen", -_suit_oxygen_rate() * elapsed / 60.0)
	# The charging station is physically INSIDE the habitat. Charge its reserve even
	# while exploring, so leaving/re-entering cannot reset it to 100%.
	if not habitat_tank_in_use:
		habitat_tank_stock = minf(100.0, habitat_tank_stock + 100.0 * DayNightSystem.minutes_per_real_second() * delta / 120.0)
	# Energy drains continuously in EVERY location: surface, ship, and cave.
	# Only suit oxygen is exempt inside the pressurized ship.
	add(&"energy", -ENERGY_DRAIN_PER_MIN * elapsed / 60.0)


func reset() -> void:
	_modules.clear()
	_values.clear()
	_outside = false
	_outside_seconds = 0.0
	solar_multiplier = 1.0
	_opening.clear()
	_energy_hint_said = false
	habitat_tank_stock = 100.0
	habitat_tank_in_use = false
	for id in get_ids():
		_set_value(id, _config[id].get("start", MAX_VALUE))


func get_ids() -> Array[StringName]:
	var ids := CORE_IDS.duplicate()
	if use_water:
		ids.append(WATER_ID)
	return ids


func has_resource(id: StringName) -> bool:
	return _values.has(id)


func get_value(id: StringName) -> float:
	return _values.get(id, 0.0)


func get_max(_id: StringName) -> float:
	return MAX_VALUE


## What the astronaut uses per sol (data/resources.json), before modules.
func get_daily_use(id: StringName) -> float:
	return float(_config.get(id, {}).get("per_sol", 0.0))


## Stored until the first night. Shown on the HUD as "100+12" while the bar is still full.
func add_opening_bonus(id: StringName, amount: float) -> void:
	if amount <= 0.0 or not _check(id):
		return
	_opening[id] = float(_opening.get(id, 0.0)) + amount
	EventBus.resource_changed.emit(id, get_value(id), MAX_VALUE)


func get_opening_bonus(id: StringName) -> float:
	return float(_opening.get(id, 0.0))


func _take_opening_bonus() -> Dictionary:
	var copy := _opening.duplicate()
	_opening.clear()
	return copy


func add(id: StringName, amount: float) -> void:
	if not _check(id):
		return
	_set_value(id, _values[id] + amount)


func recharge_from_sleep() -> void:
	_set_value(&"energy", MAX_VALUE)


## Takes the amount only if there is enough. Returns false (and changes nothing) otherwise.
func spend(id: StringName, amount: float) -> bool:
	if not _check(id) or _values[id] < amount:
		return false
	_set_value(id, _values[id] - amount)
	return true


func set_outside(outside: bool) -> void:
	_outside = outside


func is_outside() -> bool:
	return _outside


func get_outside_seconds() -> float:
	return _outside_seconds


func reset_outside_seconds() -> void:
	_outside_seconds = 0.0


func set_solar_multiplier(value: float) -> void:
	solar_multiplier = maxf(value, 0.0)


## Debug: drop one bar to 0. Hitting 0 asks EndingSystem to rescue.
func debug_empty(id: StringName) -> void:
	_set_value(id, 0.0)


## First resource sitting at 0, or empty if every bar is above 0.
func first_empty() -> StringName:
	for id in get_ids():
		if get_value(id) <= 0.0:
			return id
	return &""


func register_module(module: BaseModule) -> void:
	if module not in _modules:
		_modules.append(module)


func unregister_module(module: BaseModule) -> void:
	_modules.erase(module)


func get_modules() -> Array[BaseModule]:
	var live: Array[BaseModule] = []
	for module in _modules:
		if is_instance_valid(module):
			live.append(module)
	if live.size() != _modules.size():
		_modules = live
	return _modules.duplicate()


## Whole points the panels can spend on modules tonight. Dust and damage are already in the multiplier.
## The battery is not part of this budget: it pays life support, and leftover panel power charges it.
func solar_budget() -> int:
	var produced := 0.0
	for module in _modules:
		produced += _energy_gain(module)
	return maxi(roundi(produced), 0)


## Modules that need energy tonight, in placement order. Damaged ones are skipped.
func night_consumers() -> Array[BaseModule]:
	var list: Array[BaseModule] = []
	for module in _modules:
		if module.damaged:
			continue
		if module.data.energy_cost_per_sol > 0.0:
			list.append(module)
	return list


## Applies one night. Food per_sol is not spent here: dinner is the journal ration inside extras.
## Panel power pays module costs; the leftover, minus daily energy, hits the battery in a single step
## so a full battery doesn't lose the surplus and then pay life support on top.
func apply_night(powered_ids: Array[StringName], extras: Dictionary) -> void:
	_batch = true
	var budget := solar_budget()
	var spent := 0
	var opening := _take_opening_bonus()
	var oxygen_delta := -get_daily_use(&"oxygen") + float(opening.get(&"oxygen", 0.0))
	var food_delta := float(opening.get(&"food", 0.0))
	for module in _modules:
		var cost := roundi(module.data.energy_cost_per_sol)
		if cost <= 0.0:
			module.set_powered(not module.damaged)
			continue
		var selected := not module.damaged and module.data.id in powered_ids and spent + cost <= budget
		if not selected:
			module.set_powered(false)
			continue
		spent += cost
		module.set_powered(true)
		oxygen_delta += module.data.oxygen_per_sol
		food_delta += module.data.food_per_sol
	# Safe-kit oxygen equipment is integrated into the habitat rather than
	# placed outside. It retains its energy demand and daily oxygen output.
	if GameState.start_modules.has(&"oxygen_tank"):
		var installed := BaseCatalog.get_module(&"oxygen_tank")
		if installed != null:
			var cost := maxi(0, roundi(installed.energy_cost_per_sol))
			if spent + cost <= budget:
				spent += cost
				oxygen_delta += installed.oxygen_per_sol
	if not is_zero_approx(GameState.bonus_food):
		food_delta += GameState.bonus_food
		GameState.bonus_food = 0.0
	# Solar panels feed modules, not the astronaut's stamina. Sleep and mission rewards restore energy.
	# The overnight daily cost still applies. Opening-kit energy is not a mid-sol refill.
	var energy_delta := -get_daily_use(&"energy")
	for key in extras:
		var id := StringName(String(key))
		var amount := float(extras[key])
		match id:
			&"oxygen":
				oxygen_delta += amount
			&"energy":
				# Journal extras must not refill stamina; sleep already does that after this call.
				if amount < 0.0:
					energy_delta += amount
			&"food":
				food_delta += amount
	add(&"energy", energy_delta)
	add(&"oxygen", oxygen_delta)
	add(&"food", food_delta)
	for id in opening:
		EventBus.resource_changed.emit(StringName(id), get_value(StringName(id)), MAX_VALUE)
	_batch = false
	var core_empty := false
	for id in get_ids():
		if get_value(id) <= 0.0:
			EventBus.resource_empty.emit(id)
			if id in CORE_IDS:
				core_empty = true
	if core_empty:
		EndingSystem.try_end(&"resource")


## Automatic night: every module the panels can afford, and a normal dinner from data/resources.json.
## The journal calls apply_night() instead, so the player picks the meal and who stays on.
func apply_sol_end() -> void:
	var ids: Array[StringName] = []
	var budget := solar_budget()
	var used := 0
	for module in night_consumers():
		var cost := roundi(module.data.energy_cost_per_sol)
		if used + cost <= budget:
			ids.append(module.data.id)
			used += cost
	apply_night(ids, {&"food": -get_daily_use(&"food")})


func _energy_gain(module: BaseModule) -> float:
	if module.damaged:
		return 0.0
	var gain := module.data.energy_per_sol
	if module.data.id == &"solar_panel":
		gain *= solar_multiplier
	return gain


func _set_value(id: StringName, value: float) -> void:
	var old: float = _values.get(id, -1.0)
	var clamped := clampf(value, 0.0, MAX_VALUE)
	if is_equal_approx(old, clamped):
		return
	_values[id] = clamped
	EventBus.resource_changed.emit(id, clamped, MAX_VALUE)
	if id == &"energy" and not _batch:
		_note_low_energy(old, clamped)
	if clamped <= 0.0 and old > 0.0 and not _batch:
		EventBus.resource_empty.emit(id)
		if id in CORE_IDS:
			EndingSystem.try_end(&"resource")


func _suit_oxygen_rate() -> float:
	var rate := O2_IDLE_DRAIN
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		if player.is_sprinting:
			rate = O2_RUN_DRAIN
		elif player.velocity.length() >= 20.0:
			rate = O2_WALK_DRAIN
	if GameState.interior_id == &"cave":
		rate *= O2_CAVE_SCALE
	return rate


func _note_low_energy(old: float, value: float) -> void:
	if value > ENERGY_LOW_AT + 15.0:
		_energy_hint_said = false
		return
	if _energy_hint_said or (old > ENERGY_LOW_AT and value > ENERGY_LOW_AT):
		return
	if value > ENERGY_LOW_AT or old <= ENERGY_LOW_AT:
		return
	_energy_hint_said = true
	if get_tree() == null:
		return
	var hud := get_tree().get_first_node_in_group(&"hud")
	if hud != null and hud.has_method(&"show_notice"):
		hud.call(&"show_notice", Settings.format_both("energy.sleep"))


func _check(id: StringName) -> bool:
	if _values.has(id):
		return true
	push_warning("ResourceSystem: unknown or disabled resource '%s'" % id)
	return false


func _load_config() -> Dictionary:
	var config: Dictionary = {}
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
	if not parsed is Dictionary or not parsed.has("resources"):
		push_error("ResourceSystem: could not read %s" % DATA_PATH)
		parsed = {"resources": {}}
	for id in CORE_IDS + [WATER_ID]:
		config[id] = parsed.resources.get(String(id), {})
	return config
