extends Node
## Missions from res://data/missions/*.json: locked -> active -> completed. Progress lives in GameState.
## Objectives finish in order unless "optional": true.
## Types: go_to, enter, collect, repair, scan, sample, recover, survive_days.
## enter finishes when GameState.interior_id equals the target (habitat, greenhouse, cave).
## scan, sample and recover use the same bar as repair. Walking away cancels it.
## The prompt is short ("E: escanear", "E: tomar muestra", "E: recuperar datos").
## The tracker keeps the longer label. An optional "note" is a HUD line, not an INTI line.
## "unlock" is "start", a mission id, "day:N", "event:<id>" or "flag:<name>"; an array means any of them.
## A mission with "requires_module" stays locked for the whole run if that module was not placed.
## "category" is "main" or "secondary". Missing means secondary. S21 adds the five mains as new JSON files.
## Targets are nodes in the "mission_target" group with get_target_id() and is_player_near().
## "start" missions wait until BasePlacer.active is false, so a module cannot be finished before it exists.

## 0..1 while a repair, scan, sample or recover is in progress, -1 when it stops.
signal work_progress(ratio: float)
## The tracker target changed because the player pinned another active mission.
signal focus_changed

## Empty unless the player pinned a mission with cycle_mission. Cleared when that mission ends.
var _pinned: StringName = &""

const DIR := "res://data/missions/"
const LOCKED := "locked"
const ACTIVE := "active"
const COMPLETED := "completed"
const TARGET_GROUP := &"mission_target"
const FIELD_SECONDS := 1.5

var _defs: Dictionary = {}
var _ids: Array[StringName] = []
## True from start_run() until the base is placed; nothing unlocks meanwhile.
var _waiting_start := false
## {kind, mission, objective, target, left, total} while the player is working.
## kind "service" repairs a damaged module or shakes dust off the solar panel.
var _work: Dictionary = {}


func _ready() -> void:
	_load()
	EventBus.sol_started.connect(_on_sol_started)
	EventBus.event_triggered.connect(_on_event_triggered)
	EventBus.module_placed.connect(_on_module_placed)


func _process(delta: float) -> void:
	if RunSession.is_suspended():
		return
	if GameState.missions.is_empty() or GameState.run_over:
		if not _work.is_empty() or _pinned != &"":
			abandon_run()
		return
	if _waiting_start:
		if BasePlacer.active:
			return
		_waiting_start = false
		_unlock_ready()
	_check_go_to()
	_tick_work(delta)


## Drops a repair in progress and a pinned mission. The run data lives in GameState.
func abandon_run() -> void:
	_cancel_work()
	_pinned = &""
	_waiting_start = false


## Called by Main when a run begins. "start" missions open once the base is placed.
func start_run() -> void:
	_cancel_work()
	_pinned = &""
	GameState.missions.clear()
	GameState.mission_order.clear()
	for id in _ids:
		GameState.missions[id] = {"state": LOCKED, "done": [], "since": {}}
	_waiting_start = true
	# Flag planting is the first interactive setup step, before placing any modules.
	# Other missions still wait until the setup queue is finished.
	if _defs.has(&"plant_flag"):
		_activate(&"plant_flag")


func all_ids() -> Array[StringName]:
	return _ids.duplicate()


func get_active() -> Array[StringName]:
	return GameState.mission_order.duplicate()


func get_completed() -> Array[StringName]:
	var list: Array[StringName] = []
	for id in _ids:
		if get_state(id) == COMPLETED:
			list.append(id)
	return list


func get_state(id: StringName) -> String:
	return String(GameState.missions.get(id, {}).get("state", LOCKED))


func get_mission(id: StringName) -> Dictionary:
	return _defs.get(id, {})


## "main" or "secondary". A missing field stays secondary, so old files keep working.
func get_category(id: StringName) -> String:
	var cat := String(get_mission(id).get("category", "secondary"))
	return "main" if cat == "main" else "secondary"


## The mission the HUD features.
## A pin from cycle_focus wins until that mission is completed or no longer active.
## Otherwise active mains come first. With none, secondaries do.
## Lowest order, unless the player is already on another one's go_to, enter or interact step.
func get_shown() -> StringName:
	if _pinned != &"":
		if get_state(_pinned) == ACTIVE:
			return _pinned
		_pinned = &""
	# Give the Sol 1 repair and Sol 2 test drive priority in the default tracker.
	# Players can still cycle/pin another mission whenever they want.
	if GameState.current_sol >= 1 and get_state(&"repair_support_rover") == ACTIVE:
		return &"repair_support_rover"
	if GameState.current_sol >= 2 and get_state(&"drive_support_rover") == ACTIVE:
		return &"drive_support_rover"
	var pool := _active_where("main")
	if pool.is_empty():
		pool = _active_where("secondary")
	if pool.is_empty():
		return &""
	var here := _engaged_in(pool)
	if here != &"":
		return here
	return pool[0]


## Q / L1, or a click on the tracker. Steps through active missions and pins the next one.
func cycle_focus() -> void:
	if GameState.run_over or not DayNightSystem.has_started():
		return
	var ids := get_active()
	if ids.is_empty():
		return
	var current := get_shown()
	var index := ids.find(current)
	var next: StringName = ids[(index + 1) % ids.size()] if index >= 0 else ids[0]
	if _pinned == next:
		return
	_pinned = next
	focus_changed.emit()


## World position of the current objective. INF when there is nothing to mark.
## enter, and a target that only exists indoors, use the door or the cave mouth.
func goal_world(mission_id: StringName = &"") -> Vector2:
	if mission_id == &"":
		mission_id = get_shown()
	if mission_id == &"" or get_state(mission_id) != ACTIVE:
		return Vector2(INF, INF)
	var objectives: Array = get_mission(mission_id).get("objectives", [])
	for objective in objectives:
		if bool(objective.get("optional", false)):
			continue
		if is_objective_done(mission_id, String(objective.get("id", ""))):
			continue
		return _objective_mark(objective)
	return Vector2(INF, INF)


func _objective_mark(objective: Dictionary) -> Vector2:
	var type := String(objective.get("type", ""))
	if type == "survive_days":
		return Vector2(INF, INF)
	var target := StringName(String(objective.get("target", "")))
	if target == &"":
		return Vector2(INF, INF)
	if type == "enter":
		var door := _exterior_for(target)
		if door.is_finite():
			return door
	if target == &"cave":
		target = &"cave_mouth"
	var at := _target_position(target)
	if at.is_finite():
		return at
	return _exterior_for(_interior_of(target))


func _interior_of(target: StringName) -> StringName:
	var text := String(target)
	if text.begins_with("cave"):
		return &"cave"
	if target == &"rover_sojourner":
		return &"cave"
	if text.begins_with("habitat"):
		return &"habitat"
	if text.begins_with("greenhouse"):
		return &"greenhouse"
	return &""


func _target_position(target: StringName) -> Vector2:
	for node in get_tree().get_nodes_in_group(TARGET_GROUP):
		if node.has_method(&"get_target_id") and node.get_target_id() == target and node is Node2D:
			return (node as Node2D).global_position
	return Vector2(INF, INF)


func _exterior_for(interior: StringName) -> Vector2:
	if interior == &"":
		return Vector2(INF, INF)
	# The greenhouse is a bay INSIDE the landed spacecraft. The mission compass
	# therefore points to its internal passage, or the ship airlock when outside.
	if interior == &"greenhouse":
		if GameState.interior_id == &"habitat" or GameState.interior_id == &"lab":
			var next_room := &"greenhouse" if GameState.interior_id == &"habitat" else &"habitat"
			for node in get_tree().get_nodes_in_group(&"ship_passage"):
				if node is ShipPassage and (node as ShipPassage).destination == next_room:
					return (node as ShipPassage).global_position
		if GameState.interior_id == &"":
			return _exterior_for(&"habitat")
	for node in get_tree().get_nodes_in_group(&"building_door"):
		if not node is BuildingDoor:
			continue
		var door := node as BuildingDoor
		if door.mode != BuildingDoor.Mode.ENTER:
			continue
		if interior == &"cave" and door.cave_mouth:
			return door.global_position
		if door.interior_id == interior and not door.cave_mouth:
			return door.global_position
	if interior == &"cave":
		return _target_position(&"cave_mouth")
	return _target_position(interior)


func is_objective_done(mission_id: StringName, objective_id: String) -> bool:
	return objective_id in GameState.missions.get(mission_id, {}).get("done", [])


## Marks one objective. Returns false if the mission isn't active or an earlier objective is missing.
func complete_objective(mission_id: StringName, objective_id: String) -> bool:
	if get_state(mission_id) != ACTIVE:
		return false
	var objectives: Array = get_mission(mission_id).get("objectives", [])
	var index := -1
	for i in objectives.size():
		if String(objectives[i].get("id", "")) == objective_id:
			index = i
			break
	if index < 0 or is_objective_done(mission_id, objective_id) or not _can_do(mission_id, index):
		return false
	if _contact_blocked(mission_id, objectives[index]):
		return false
	var entry: Dictionary = GameState.missions[mission_id]
	entry["done"].append(objective_id)
	if mission_id == &"fix_solar_panel" and objective_id == "obj_2":
		_clean_solar_panel()
	var flag := String(objectives[index].get("flag", ""))
	if not flag.is_empty():
		GameState.set_flag(StringName(flag))
	_flash_note(objectives[index], String(objectives[index].get("type", "")))
	EventBus.mission_objective_done.emit(mission_id, StringName(objective_id))
	_sync_bed(mission_id, objective_id)
	if _required_done(mission_id):
		_complete(mission_id)
		_refresh_plants()
	else:
		_start_timers(mission_id)
	return true


func apply_rewards(mission_id: StringName) -> void:
	var rewards: Dictionary = get_mission(mission_id).get("rewards", {})
	for id in ResourceSystem.CORE_IDS:
		var amount := float(rewards.get(String(id), 0.0))
		if not is_zero_approx(amount):
			ResourceSystem.add(id, amount)
	var flag := String(rewards.get("flag", ""))
	if not flag.is_empty():
		GameState.set_flag(StringName(flag))


## Called by a target when the player presses "interact" next to it. True = the mission used the press.
func try_interact(target_id: StringName) -> bool:
	if door_has_player():
		return false
	if not _work.is_empty():
		return _work.target == target_id
	if not accepts_interact(target_id):
		return false
	for mission_id in _focus_first():
		for objective in _workable(mission_id):
			if StringName(String(objective.get("target", ""))) != target_id:
				continue
			var type := String(objective.get("type", ""))
			if not _tool_block(objective).is_empty():
				return false
			if type == "collect":
				complete_objective(mission_id, String(objective.id))
				return true
			if _contact_blocked(mission_id, objective):
				_flash_blackout()
				return true
			if _is_timed(type):
				var seconds := maxf(float(objective.get("seconds", _default_seconds(type))), 0.1)
				if type == "repair" and bool(GameState.get_flag(&"has_repair_tool")):
					seconds *= 0.7
				_work = {
					"kind": "mission",
					"mission": mission_id,
					"objective": String(objective.id),
					"target": target_id,
					"left": seconds,
					"total": seconds,
				}
				work_progress.emit(0.0)
				return true
	return false


## E on a damaged module, or on a dusty solar panel, when no mission wants that target.
## Same 1.5 s bar as a mission repair. Walking away cancels it. Skipping it does not block the run.
func try_service(module: BaseModule) -> bool:
	if module == null or door_has_player():
		return false
	if not _work.is_empty():
		return String(_work.get("kind", "")) == "service" and _work.target == module.get_target_id()
	if wants(module.get_target_id()):
		return false
	var shake := module.panel_needs_shake()
	if not module.damaged and not shake:
		return false
	var repairing := module.damaged
	_work = {
		"kind": "service",
		"target": module.get_target_id(),
		"module": module,
		"left": FIELD_SECONDS,
		"total": FIELD_SECONDS,
		"label": Settings.text("prompt.repairing" if repairing else "prompt.shaking"),
		"service": "repair" if repairing else "shake",
	}
	work_progress.emit(0.0)
	return true


## True if an active objective wants the player to press "interact" on this target.
func wants(target_id: StringName) -> bool:
	return not _interact_objective(target_id).is_empty()


## The door wins. Otherwise the target the tracker is asking for, if the player is next to it.
func accepts_interact(target_id: StringName) -> bool:
	if door_has_player():
		return false
	var preferred := preferred_interact_target()
	if preferred == &"":
		return true
	return preferred == target_id


## Collect, repair, scan, sample or recover target the player is standing on.
## The shown mission wins ties.
func preferred_interact_target() -> StringName:
	if not _work.is_empty():
		return _work.target
	for mission_id in _focus_first():
		for objective in _workable(mission_id):
			var type := String(objective.get("type", ""))
			if not _is_interact(type):
				continue
			var target := StringName(String(objective.get("target", "")))
			if target != &"" and _near_for_interact(target):
				return target
	return &""


func door_has_player() -> bool:
	for node in get_tree().get_nodes_in_group(&"building_door"):
		if node.has_method(&"is_player_near") and node.is_player_near():
			return true
	return false


## "E: <label>" when the player stands next to something a mission wants them to use.
func prompt_text() -> String:
	if not _work.is_empty() and String(_work.get("kind", "")) == "service":
		var service_key := "prompt.repairing" if String(_work.get("service", "")) == "repair" else "prompt.shaking"
		return "%s..." % Settings.text(service_key)
	if not _work.is_empty():
		return _prompt_for_target(_work.target)
	var preferred := preferred_interact_target()
	if preferred != &"":
		var line := _prompt_for_target(preferred)
		if not line.is_empty():
			return line
	for node in get_tree().get_nodes_in_group(TARGET_GROUP):
		if not node is BaseModule:
			continue
		var module := node as BaseModule
		if not module.is_player_near() or module.hides_mission_prompt():
			continue
		if wants(module.get_target_id()):
			continue
		if module.damaged:
			return Settings.text("module.repair")
		if module.panel_needs_shake():
			return Settings.text("module.shake")
	return ""


## The one interact line to draw above its object. Empty when nothing nearby can be used.
func prompt_focus() -> Dictionary:
	if GameState.run_over or Cutscenes.is_playing() or BasePlacer.active or DayNightSystem.is_journal_open():
		return {}
	if not _work.is_empty():
		var working := _target_node(_work.target)
		var busy := prompt_text()
		if working != null and not busy.is_empty():
			return {"text": busy, "node": working, "work": true}
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return {}
	var best := {}
	var best_d := 100000000.0
	for door in get_tree().get_nodes_in_group(&"building_door"):
		if not door.has_method(&"prompt_line") or not door is Node2D:
			continue
		var door_line := String(door.call(&"prompt_line"))
		if door_line.is_empty():
			continue
		var door_d := player.global_position.distance_squared_to((door as Node2D).global_position)
		if door_d < best_d:
			best_d = door_d
			best = {"text": door_line, "node": door}
	var mission_line := prompt_text()
	if not mission_line.is_empty():
		var node := _prompt_node()
		if node != null:
			var mission_d := player.global_position.distance_squared_to(node.global_position)
			if mission_d < best_d:
				best_d = mission_d
				best = {"text": mission_line, "node": node}
	for prop in get_tree().get_nodes_in_group(&"interior_prop"):
		if not prop.has_method(&"local_prompt") or not prop is Node2D:
			continue
		var local := String(prop.call(&"local_prompt"))
		if local.is_empty():
			continue
		var local_d := player.global_position.distance_squared_to((prop as Node2D).global_position)
		if local_d < best_d:
			best_d = local_d
			best = {"text": local, "node": prop}
	# Informational cards work outside assigned missions. Show a distinct E prompt
	# on rovers instead of forcing the user to guess when they can inspect them.
	for area in get_tree().get_nodes_in_group(TARGET_GROUP):
		if not area is MissionArea or not (area as MissionArea).is_player_near():
			continue
		var rover_id := String((area as MissionArea).target_id)
		if not rover_id.begins_with("rover_"):
			continue
		var rover_d := player.global_position.distance_squared_to((area as Node2D).global_position)
		if rover_d < best_d:
			var line := "E: ver información" if Settings.lang == "es" else "E: inspect rover"
			if rover_id == "rover_support" and area.get_parent().has_method(&"rover_prompt"):
				line = String(area.get_parent().call(&"rover_prompt"))
			best_d = rover_d
			best = {"text": line, "node": area}
	return best


func _prompt_node() -> Node2D:
	if not _work.is_empty():
		return _target_node(_work.target)
	var preferred := preferred_interact_target()
	if preferred != &"":
		return _target_node(preferred)
	for node in get_tree().get_nodes_in_group(TARGET_GROUP):
		if not node is BaseModule:
			continue
		var module := node as BaseModule
		if not module.is_player_near() or module.hides_mission_prompt():
			continue
		if wants(module.get_target_id()):
			continue
		if module.damaged or module.panel_needs_shake():
			return module
	return null


func _target_node(target_id: StringName) -> Node2D:
	var fallback: Node2D = null
	for node in get_tree().get_nodes_in_group(TARGET_GROUP):
		if not node.has_method(&"get_target_id") or node.get_target_id() != target_id or not node is Node2D:
			continue
		if fallback == null:
			fallback = node
		if node.has_method(&"is_player_near") and node.is_player_near():
			return node
	return fallback


## World prompt for one target. Empty when another interact should win.
func prompt_for(target_id: StringName) -> String:
	if not _work.is_empty():
		if _work.target != target_id or String(_work.get("kind", "")) == "service":
			return ""
		return _prompt_for_target(target_id)
	if not accepts_interact(target_id):
		return ""
	return _prompt_for_target(target_id)


func work_target() -> StringName:
	if _work.is_empty():
		return &""
	return _work.target


func _prompt_for_target(target_id: StringName) -> String:
	if not _work.is_empty() and _work.target == target_id and String(_work.get("kind", "")) == "mission":
		return "%s..." % _prompt_verb(_objective(_work.mission, _work.objective))
	var objective := _interact_objective(target_id)
	if objective.is_empty():
		return ""
	var blocked := _tool_block(objective)
	if not blocked.is_empty():
		return blocked
	return "E: %s" % _prompt_verb(objective)


func _tool_block(objective: Dictionary) -> String:
	var need := String(objective.get("tool", ""))
	if need.is_empty() or _equipped_tool() == need:
		return ""
	if need == "water":
		return Settings.text("prompt.need_water")
	return Settings.text("prompt.need_seed")


func _equipped_tool() -> String:
	var node := get_tree().get_first_node_in_group(&"hotbar")
	if node != null and "tool_id" in node:
		return String(node.get("tool_id"))
	return "hand"


func _sync_bed(mission_id: StringName, objective_id: String) -> void:
	var stage := -1
	if mission_id == &"grow_potato" and objective_id == "obj_2":
		stage = 0
	elif mission_id == &"grow_potato" and objective_id == "obj_3":
		stage = 2
	elif mission_id == &"grow_potato" and objective_id == "obj_4":
		stage = 3
	elif mission_id == &"tend_plants" and objective_id == "obj_2":
		stage = 1
	if stage < 0:
		return
	GameState.bed_stage = stage
	_refresh_plants()


func _refresh_plants() -> void:
	for node in get_tree().get_nodes_in_group(&"interior_prop"):
		if node.has_method(&"sync_growth"):
			node.sync_growth()


## True when something besides "wait until tomorrow" is still to do today.
## Sleep stays available either way, so a "survive the day" task can finish.
func has_tasks_left() -> bool:
	for mission_id in GameState.mission_order:
		for objective in _workable(mission_id):
			if String(objective.get("type", "")) != "survive_days":
				return true
	return false


## Debug (F4): finishes the next objective of the mission on the HUD.
func debug_complete_current() -> void:
	_cancel_work()
	var id := get_shown()
	if id == &"":
		return
	var workable := _workable(id)
	if not workable.is_empty():
		complete_objective(id, String(workable[0].id))


func _complete(id: StringName) -> void:
	if _pinned == id:
		_pinned = &""
	var entry: Dictionary = GameState.missions[id]
	entry["state"] = COMPLETED
	GameState.mission_order.erase(id)
	if not _work.is_empty() and _work.get("mission") == id:
		_cancel_work()
	apply_rewards(id)
	var mission := get_mission(id)
	var title_es := String(mission.get("title", id))
	var title_en := String(mission.get("title_en", title_es))
	GameState.add_note("journal.note_done", [title_es], [title_en])
	GameState.add_raw(String(mission.get("done", "")), String(mission.get("done_en", "")))
	GameState.add_raw(String(mission.get("science", "")), String(mission.get("science_en", "")))
	_send_reply(mission.get("reply", {}))
	EventBus.mission_completed.emit(id)
	if id == &"recover_rovers":
		NasaData.on_rovers_done()
	if id == &"grow_potato":
		NasaData.on_harvest()
	# Unlock the next task first, so a side mission that opens off this one is already on the tracker.
	# Completing a mission never opens the debrief. The run lasts until day 10.
	_unlock_ready()
	_announce_mains_if_ready()


## Earth's reply shares the delayed-message queue with the earth_message event.
## A second text waits its own delay. Neither one overwrites the other.
func _contact_blocked(mission_id: StringName, objective: Dictionary) -> bool:
	return mission_id == &"contact_earth" and String(objective.get("type", "")) == "repair" and NasaData.is_blackout()


func _flash_blackout() -> void:
	var hud := get_tree().get_first_node_in_group(&"hud")
	if hud != null and hud.has_method(&"show_notice"):
		hud.show_notice(NasaData.antenna_line())


func _send_reply(reply: Dictionary) -> void:
	var spanish := String(reply.get("text", ""))
	if spanish.is_empty():
		return
	var english := String(reply.get("text_en", spanish))
	var delay := NasaData.round_trip_seconds()
	GameState.enqueue_message(delay, Settings.pack(spanish, english))


## One short line when the five mains are done. The run keeps going until day 10.
func _announce_mains_if_ready() -> void:
	if not all_mains_done() or GameState.has_flag(&"mains_clear_said"):
		return
	GameState.set_flag(&"mains_clear_said", true)
	if Cutscenes.is_playing():
		await Cutscenes.cutscene_finished
	if GameState.run_over or not all_mains_done():
		return
	IntiBrain.announce_mains_clear()


## True when all main campaign missions are loaded and completed.
func all_mains_done() -> bool:
	for id in EndingSystem.MAIN_MISSIONS:
		if get_mission(id).is_empty() or get_category(id) != "main":
			return false
		if get_state(id) != COMPLETED:
			return false
	return true


func _activate(id: StringName) -> void:
	GameState.missions[id]["state"] = ACTIVE
	GameState.mission_order.append(id)
	_start_timers(id)
	EventBus.mission_started.emit(id)
	if get_category(id) == "main" or id == &"find_water_ice" or id == &"grow_potato":
		NasaData.on_main_started(id)


func _unlock_ready(event_id: String = "") -> void:
	if _waiting_start or GameState.missions.is_empty():
		return
	for id in _ids:
		if get_state(id) != LOCKED:
			continue
		var mission := get_mission(id)
		# A prerequisite may be finished early, but scheduled story chapters must
		# not open until their intended sol. All previous mission progress is kept.
		if GameState.current_sol < int(mission.get("min_sol", 1)):
			continue
		if not _has_module(StringName(String(mission.get("requires_module", "")))):
			continue
		if _unlock_met(mission.get("unlock", "start"), event_id):
			_activate(id)


func _unlock_met(rule: Variant, event_id: String) -> bool:
	if rule is Array:
		return rule.any(func(r: Variant) -> bool: return _unlock_met(r, event_id))
	var text := String(rule)
	if text == "start":
		return true
	if text.begins_with("day:"):
		return GameState.current_sol >= int(text.trim_prefix("day:"))
	if text.begins_with("event:"):
		var id := text.trim_prefix("event:")
		return id == event_id or GameState.has_flag(StringName("saw_" + id))
	if text.begins_with("flag:"):
		return bool(GameState.get_flag(StringName(text.trim_prefix("flag:"))))
	return get_state(StringName(text)) == COMPLETED


func _has_module(id: StringName) -> bool:
	if id == &"":
		return true
	for module in ResourceSystem.get_modules():
		if module.data.id == id:
			return true
	return false


## An objective can be marked once every earlier non-optional one is done.
func _can_do(mission_id: StringName, index: int) -> bool:
	var objectives: Array = get_mission(mission_id).get("objectives", [])
	if bool(objectives[index].get("optional", false)):
		return true
	for i in index:
		if not bool(objectives[i].get("optional", false)) and not is_objective_done(mission_id, String(objectives[i].id)):
			return false
	return true


func _required_done(mission_id: StringName) -> bool:
	for objective in get_mission(mission_id).get("objectives", []):
		if not bool(objective.get("optional", false)) and not is_objective_done(mission_id, String(objective.id)):
			return false
	return true


func _workable(mission_id: StringName) -> Array:
	var list: Array = []
	var objectives: Array = get_mission(mission_id).get("objectives", [])
	for i in objectives.size():
		if not is_objective_done(mission_id, String(objectives[i].id)) and _can_do(mission_id, i):
			list.append(objectives[i])
	return list


## survive_days counts from the sol the objective became workable.
func _start_timers(mission_id: StringName) -> void:
	var since: Dictionary = GameState.missions[mission_id]["since"]
	for objective in _workable(mission_id):
		if String(objective.get("type", "")) == "survive_days" and not since.has(String(objective.id)):
			since[String(objective.id)] = GameState.current_sol


func _objective(mission_id: StringName, objective_id: String) -> Dictionary:
	for objective in get_mission(mission_id).get("objectives", []):
		if String(objective.get("id", "")) == objective_id:
			return objective
	return {}


func _interact_objective(target_id: StringName) -> Dictionary:
	for mission_id in _focus_first():
		for objective in _workable(mission_id):
			if StringName(String(objective.get("target", ""))) == target_id \
					and _is_interact(String(objective.get("type", ""))):
				return objective
	return {}


## Shown mission first, then the rest in order. One E cannot finish two steps.
func _focus_first() -> Array[StringName]:
	var list: Array[StringName] = []
	var shown := get_shown()
	if shown != &"" and get_state(shown) == ACTIVE:
		list.append(shown)
	for id in _ids:
		if id == shown:
			continue
		if get_state(id) == ACTIVE:
			list.append(id)
	return list


func _active_where(category: String) -> Array[StringName]:
	var list: Array[StringName] = []
	for id in _ids:
		if get_state(id) == ACTIVE and get_category(id) == category:
			list.append(id)
	return list


func _active_ids() -> Array[StringName]:
	var list: Array[StringName] = []
	for id in _ids:
		if get_state(id) == ACTIVE:
			list.append(id)
	return list


## The player is on this step: next to its target, or already inside for enter / go_to.
func _engaged_in(pool: Array[StringName]) -> StringName:
	for id in pool:
		for objective in _workable(id):
			var type := String(objective.get("type", ""))
			if type != "go_to" and type != "enter" and not _is_interact(type):
				continue
			var target := StringName(String(objective.get("target", "")))
			if type == "enter" and GameState.interior_id == target:
				return id
			if target != &"" and (_player_near(target) or (type == "go_to" and GameState.interior_id == target)):
				return id
	return &""


func _player_near(target_id: StringName) -> bool:
	for node in get_tree().get_nodes_in_group(TARGET_GROUP):
		if node.get_target_id() == target_id and node.is_player_near():
			return true
	return false


## Like _player_near, but a door that is hiding the prompt does not count.
## E at that door enters. The repair happens on the prop inside, or beside the module.
func _near_for_interact(target_id: StringName) -> bool:
	for node in get_tree().get_nodes_in_group(TARGET_GROUP):
		if node.get_target_id() != target_id or not node.is_player_near():
			continue
		if node.has_method(&"hides_mission_prompt") and node.hides_mission_prompt():
			continue
		return true
	return false


func _check_go_to() -> void:
	for mission_id in _active_ids():
		for objective in _workable(mission_id):
			var type := String(objective.get("type", ""))
			var target := StringName(String(objective.get("target", "")))
			var reached := false
			if type == "go_to":
				reached = _player_near(target) or GameState.interior_id == target
			elif type == "enter" and target != &"":
				reached = GameState.interior_id == target
			if reached:
				complete_objective(mission_id, String(objective.id))


func _tick_work(delta: float) -> void:
	if _work.is_empty():
		return
	if not _player_near(_work.target):
		_cancel_work()
		return
	if String(_work.get("kind", "")) != "service" and get_state(_work.mission) != ACTIVE:
		_cancel_work()
		return
	if String(_work.get("kind", "")) == "mission":
		var objective := _objective(_work.mission, _work.objective)
		if not String(objective.get("tool", "")).is_empty() and not Input.is_action_pressed(&"interact"):
			_cancel_work()
			return
	_work.left -= delta
	if _work.left > 0.0:
		work_progress.emit(1.0 - _work.left / _work.total)
		return
	var finished := _work
	_cancel_work()
	if String(finished.get("kind", "")) == "service":
		_finish_service(finished)
	else:
		var objective := _objective(finished.mission, finished.objective)
		var quiz_id := String(objective.get("quiz", ""))
		if not quiz_id.is_empty():
			_open_archive_quiz(quiz_id, finished.mission, String(finished.objective))
		else:
			complete_objective(finished.mission, finished.objective)


func _finish_service(work: Dictionary) -> void:
	var module := work.get("module") as BaseModule
	if module == null or not is_instance_valid(module):
		return
	if String(work.get("service", "")) == "repair" or module.damaged:
		module.set_damaged(false)
		GameState.damaged_module_ids.erase(module.data.id)
		module.refresh_look()
		GameState.add_note("journal.repaired", [module.data.display_name], [module.data.name_en()])
		return
	_clean_solar_panel()
	GameState.add_note("journal.shook")


## Only a real maintenance action removes accumulated panel dust.
func _clean_solar_panel() -> void:
	GameState.solar_panel_dust = 0.0
	GameState.dust_sols_left = 0
	GameState.panel_weak_sols_left = 0
	GameState.set_flag(&"cleaned_panels", false)
	DayNightSystem.refresh_weather()
	for module in ResourceSystem.get_modules():
		if module.data != null and module.data.id == &"solar_panel":
			module.refresh_look()


func _open_archive_quiz(quiz_id: String, mission_id: StringName, objective_id: String) -> void:
	var packed := load("res://scenes/ui/RoverArchivePanel.tscn") as PackedScene
	if packed == null:
		complete_objective(mission_id, objective_id)
		return
	var panel := packed.instantiate()
	var scene := get_tree().current_scene
	if scene == null:
		complete_objective(mission_id, objective_id)
		return
	scene.add_child(panel)
	if panel.has_method(&"present"):
		panel.call(&"present", quiz_id, mission_id, objective_id)
	else:
		complete_objective(mission_id, objective_id)


func _is_interact(type: String) -> bool:
	return type == "collect" or _is_timed(type)


func _is_timed(type: String) -> bool:
	return type == "repair" or type == "scan" or type == "sample" or type == "recover"


func _default_seconds(type: String) -> float:
	match type:
		"recover":
			return 2.5
		"sample":
			return 2.2
		"scan":
			return 2.0
		_:
			return FIELD_SECONDS


## Short verb for the new field actions. Repair and collect keep their objective label.
func _prompt_verb(objective: Dictionary) -> String:
	var short := Settings.pick(objective, "prompt")
	if not short.is_empty():
		return short
	match String(objective.get("type", "")):
		"scan":
			return Settings.text("prompt.scan")
		"sample":
			return Settings.text("prompt.sample")
		"recover":
			return Settings.text("prompt.recover")
		_:
			return Settings.pick(objective, "label")


func _flash_note(objective: Dictionary, type: String) -> void:
	var spanish := String(objective.get("note", ""))
	if spanish.is_empty() or type == "repair" or not _is_timed(type):
		return
	var english := String(objective.get("note_en", spanish))
	var hud := get_tree().get_first_node_in_group(&"hud")
	if hud != null and hud.has_method(&"show_notice"):
		hud.show_notice(Settings.pack(spanish, english))


func _cancel_work() -> void:
	if _work.is_empty():
		return
	_work = {}
	work_progress.emit(-1.0)


func _on_sol_started(n: int) -> void:
	if GameState.missions.is_empty():
		return
	for mission_id in _active_ids():
		var since: Dictionary = GameState.missions[mission_id]["since"]
		for objective in _workable(mission_id):
			if String(objective.get("type", "")) != "survive_days":
				continue
			var start := int(since.get(String(objective.id), n))
			if n - start >= int(objective.get("days", 1)):
				complete_objective(mission_id, String(objective.id))
	_unlock_ready()


func _on_event_triggered(id: StringName) -> void:
	_unlock_ready(String(id))


func _on_module_placed(_id: StringName) -> void:
	if _waiting_start and not BasePlacer.active:
		_waiting_start = false
		_unlock_ready()


func _load() -> void:
	var list: Array = []
	for file_name in DirAccess.get_files_at(DIR):
		if not file_name.ends_with(".json"):
			continue
		var file := FileAccess.open(DIR + file_name, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
		if not parsed is Dictionary or String(parsed.get("id", "")).is_empty():
			push_error("MissionSystem: could not read %s" % (DIR + file_name))
			continue
		list.append(parsed)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order", 99)) < int(b.get("order", 99)))
	for mission in list:
		var id := StringName(String(mission.id))
		_defs[id] = mission
		_ids.append(id)
