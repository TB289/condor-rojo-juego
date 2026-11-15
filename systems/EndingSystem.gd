extends Node
## One door out of a run. A core bar at 0, or the night journal of day mission_sols, calls try_end()
## so two endings cannot start. Copy for the screen lives in data/dialogue/debrief.json.
## Ids stay ejemplar / justo / rescate. The player reads "Día"; current_sol is unchanged.
## Finishing the main missions, or the reserve keys, does not end the run. The only win is
## closing the journal on day mission_sols (10). Rescue still happens any day a core bar hits 0.
## On that last night, _score() is ejemplar only when the closing set is complete and the
## other thresholds hold. Otherwise it is justo. A key whose module was never placed does not count.
## A closing set of one id is rejected. Secondaries never decide the score by themselves.

const DEBRIEF_SCENE := "res://scenes/ui/Debrief.tscn"
const LOOP_PATH := "res://data/loop.json"
const MAIN_MISSIONS: Array[StringName] = [
	&"repair_support_rover",
	&"drive_support_rover",
	&"recover_rovers",
	&"search_biosignatures",
	&"study_minerals",
	&"study_caves",
	&"study_glaciers",
]
const KEY_MISSIONS: Array[StringName] = [
	&"fix_solar_panel",
	&"find_water_ice",
	&"grow_potato",
	&"contact_earth",
]

var _mission_sols := 10
var _min_resource := 25.0
var _max_skipped := 2
var _max_dose := 12.0


func _ready() -> void:
	# The tree pauses while INTI reads the closing line. This node still has to resume.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_loop()


## reason: "resource" (a bar hit 0 during the day) or "journal" (the night page just closed).
## "mission" is accepted and does not end the run. Returns true if this call started the ending.
func try_end(reason: StringName) -> bool:
	if GameState.run_over or not DayNightSystem.has_started():
		return false
	# The journal is one step. A bar hitting 0 waits until it closes.
	# Closing the journal on the last day is the win. Missions do not open the debrief.
	if reason != &"journal" and not DayNightSystem.accepts_live_end():
		return false
	var ending := _choose(reason)
	if ending.is_empty():
		return false
	_play(ending)
	return true


func _choose(reason: StringName) -> StringName:
	if reason == &"radiation" and GameState.has_flag(&"lethal_solar_exposure"):
		GameState.rescue_resource = &"radiation"
		return &"radiation"
	var empty := _empty_core()
	if not empty.is_empty():
		GameState.rescue_resource = empty
		return &"rescate"
	if reason != &"journal" or GameState.current_sol < _mission_sols:
		return &""
	GameState.rescue_resource = &""
	return _score()


## Day 10 is the win. "ejemplar" needs the whole closing set: all main missions,
## or every reserve key this run can actually do. Fewer than that is "justo".
func _score() -> StringName:
	if GameState.get_flag(&"exposed_solar") or GameState.get_flag(&"abandoned_module"):
		return &"justo"
	if GameState.meals_skipped > _max_skipped:
		return &"justo"
	if GameState.dose_msv > _max_dose:
		return &"justo"
	for id in ResourceSystem.CORE_IDS:
		if ResourceSystem.get_value(id) <= _min_resource:
			return &"justo"
	var closing := _closing_ids()
	if closing.is_empty() or _key_done() < closing.size():
		return &"justo"
	return &"ejemplar"


func _play(ending: StringName) -> void:
	GameState.ending_id = ending
	GameState.run_over = true
	DayNightSystem.halt_for_ending()
	if ending == &"rescate" or ending == &"radiation":
		CameraRig.nudge_current()
	# The mission that closed the run may have its own cutscene. It plays before the debrief.
	while Cutscenes.is_playing():
		await Cutscenes.cutscene_finished
	if not is_inside_tree():
		return
	var cutscene: StringName = Cutscenes.for_trigger("ending:%s" % ending)
	if cutscene != &"":
		await Cutscenes.play(cutscene, true)
		if not is_inside_tree():
			return
	get_tree().change_scene_to_file(DEBRIEF_SCENE)
	if cutscene != &"":
		Cutscenes.release_cover()


func _empty_core() -> StringName:
	for id in ResourceSystem.CORE_IDS:
		if ResourceSystem.get_value(id) <= 0.0:
			return id
	return &""


## True only when all named mains are on disk and marked main.
## A partial set must not close the run by itself.
func _uses_mains() -> bool:
	for id in MAIN_MISSIONS:
		if MissionSystem.get_mission(id).is_empty():
			return false
		if MissionSystem.get_category(id) != "main":
			return false
	return true


## The main missions, unfiltered, once they all exist. Otherwise the reserve keys
## this kit can do. Never a list of one: the first finished mission is not the ending.
func _closing_ids() -> Array[StringName]:
	if _uses_mains():
		return MAIN_MISSIONS.duplicate()
	var ids: Array[StringName] = []
	for id in KEY_MISSIONS:
		if _counts_for_run(id):
			ids.append(id)
	if ids.size() < 2:
		return []
	return ids


## A mission that needs a module this kit never placed is not part of the score.
func _counts_for_run(id: StringName) -> bool:
	var mission := MissionSystem.get_mission(id)
	if mission.is_empty():
		return false
	var module := StringName(String(mission.get("requires_module", "")))
	if module == &"":
		return true
	for placed in ResourceSystem.get_modules():
		if placed.data != null and placed.data.id == module:
			return true
	return false


func _key_done() -> int:
	var count := 0
	for id in _closing_ids():
		if MissionSystem.get_state(id) == MissionSystem.COMPLETED:
			count += 1
	return count


func _all_key_done() -> bool:
	var ids := _closing_ids()
	if ids.size() < 2 or _key_done() != ids.size():
		return false
	if _uses_mains() and ids.size() != MAIN_MISSIONS.size():
		return false
	# Not a win condition. Day 10 scoring uses _key_done against _closing_ids.
	# The reserve used to wait while a side mission was still on the tracker.
	if not _uses_mains() and not GameState.mission_order.is_empty():
		return false
	return true


func _load_loop() -> void:
	var file := FileAccess.open(LOOP_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
	if not parsed is Dictionary:
		push_error("EndingSystem: could not read %s" % LOOP_PATH)
		return
	_mission_sols = int(parsed.get("mission_sols", _mission_sols))
	_min_resource = float(parsed.get("exemplary_min_resource", _min_resource))
	_max_skipped = int(parsed.get("exemplary_max_skipped_meals", _max_skipped))
	_max_dose = float(parsed.get("exemplary_max_dose_msv", _max_dose))
