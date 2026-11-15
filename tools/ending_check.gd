extends Node
## Headless regression for the run ending. Loads with the project autoloads.
## A safe kit is habitat + oxygen tank + solar panel: no greenhouse, no antenna.


func _ready() -> void:
	var failed := 0
	failed += _case_panel_does_not_end()
	failed += _case_second_secondary_does_not_end()
	failed += _case_one_main_does_not_end()
	failed += _case_partial_mains_use_reserve()
	failed += _case_all_five_mains_can_end()
	failed += _case_four_mains_day_ten()
	failed += _case_reserve_needs_every_key()
	failed += _case_rescue_and_day_ten()
	failed += _case_play_again_clears_run_over()
	print("ENDING_CHECK_RESULT ", failed)
	if failed > 0:
		push_error("ending_check: %d assertion(s) failed" % failed)
	else:
		print("ending_check: all cases passed")
	get_tree().quit(1 if failed > 0 else 0)


func _case_panel_does_not_end() -> int:
	_boot(true)
	print("CASE panel mains=", _main_count(), " closing=", _text(EndingSystem._closing_ids()), " uses_mains=", EndingSystem._uses_mains())
	if not _finish(&"fix_solar_panel"):
		return _fail("panel objectives did not complete")
	var scene := ""
	if get_tree().current_scene != null:
		scene = get_tree().current_scene.scene_file_path
	var bad := 0
	bad += _expect(not GameState.run_over, "panel set run_over")
	bad += _expect(GameState.ending_id == &"", "panel set an ending")
	bad += _expect(not scene.ends_with("Debrief.tscn"), "panel changed to Debrief (%s)" % scene)
	bad += _expect(MissionSystem.get_state(&"find_water_ice") == MissionSystem.ACTIVE, "ice did not unlock")
	bad += _expect(MissionSystem.get_state(&"sort_supplies") == MissionSystem.ACTIVE, "boxes did not unlock")
	bad += _expect(EndingSystem._closing_ids().size() == 5, "closing set after the panel should be the five mains, got %s" % _text(EndingSystem._closing_ids()))
	bad += _expect(not EndingSystem.try_end(&"mission"), "try_end(mission) was true after only the panel")
	_stop_cutscene()
	return bad


func _case_second_secondary_does_not_end() -> int:
	_boot(true)
	if not _finish(&"fix_solar_panel") or not _finish(&"find_water_ice"):
		return _fail("could not complete panel then ice")
	var bad := 0
	bad += _expect(not GameState.run_over, "ice ended the run")
	bad += _expect(not EndingSystem.try_end(&"mission"), "try_end(mission) was true after ice")
	_stop_cutscene()
	if not _finish(&"sort_supplies"):
		return bad + _fail("boxes did not complete")
	bad += _expect(not GameState.run_over, "boxes ended the run")
	_stop_cutscene()
	return bad


func _case_one_main_does_not_end() -> int:
	_boot(true)
	if not _finish(&"fix_solar_panel") or not _finish(&"study_minerals"):
		return _fail("could not complete the first main")
	var bad := 0
	bad += _expect(not GameState.run_over, "first main ended the run")
	bad += _expect(not EndingSystem.try_end(&"mission"), "try_end(mission) was true after one main")
	bad += _expect(EndingSystem._closing_ids().size() != 1, "one main became the whole closing set")
	_stop_cutscene()
	return bad


func _case_partial_mains_use_reserve() -> int:
	var saved := _drop_mains([&"recover_rovers", &"search_biosignatures", &"study_caves", &"study_glaciers"])
	_boot(true)
	var bad := 0
	bad += _expect(not EndingSystem._uses_mains(), "a partial main set was treated as the closing set")
	var ids := EndingSystem._closing_ids()
	bad += _expect(ids.size() >= 2, "reserve closing set has fewer than two ids: %s" % _text(ids))
	bad += _expect(&"fix_solar_panel" in ids and &"find_water_ice" in ids, "safe reserve is not panel+ice: %s" % _text(ids))
	bad += _expect(&"study_minerals" not in ids, "a leftover main is in the reserve set")
	if not _finish(&"fix_solar_panel"):
		bad += _fail("panel did not complete on the reserve path")
	else:
		bad += _expect(not GameState.run_over, "reserve path ended on the panel alone")
		bad += _expect(EndingSystem._closing_ids().size() != 1, "reserve closing set shrank to one id after the panel")
	_stop_cutscene()
	# The old close: one loaded main made _key_done() == ids.size() inside try_end("mission").
	if bad == 0 and not _finish(&"study_minerals"):
		bad += _fail("lone main did not complete")
	else:
		bad += _expect(not GameState.run_over, "the only loaded main ended the run")
		bad += _expect(EndingSystem._closing_ids().size() != 1, "closing set is still a single id")
	_stop_cutscene()
	_restore_mains(saved)
	return bad


func _case_all_five_mains_can_end() -> int:
	_boot(true)
	if _main_count() < 5:
		return _fail("expected five main defs, found %d" % _main_count())
	GameState.current_sol = 2
	if not _finish(&"fix_solar_panel"):
		return _fail("panel did not complete before the mains")
	_stop_cutscene()
	var mains: Array[StringName] = [
		&"study_minerals",
		&"recover_rovers",
		&"search_biosignatures",
		&"study_caves",
		&"study_glaciers",
	]
	for i in mains.size():
		if not _finish(mains[i]):
			return _fail("could not complete %s" % mains[i])
		_stop_cutscene()
		if i < mains.size() - 1:
			if GameState.run_over:
				return _fail("%s closed the run before the fifth main" % mains[i])
	var bad := 0
	bad += _expect(not GameState.run_over, "five mains closed the run on day 2")
	bad += _expect(GameState.ending_id == &"", "five mains set an ending on day 2")
	bad += _expect(not EndingSystem.try_end(&"mission"), "try_end(mission) was true after five mains")
	bad += _expect(GameState.has_flag(&"mains_clear_said"), "INTI was not told the mains are done")
	GameState.current_sol = 10
	var ended := EndingSystem.try_end(&"journal")
	bad += _expect(ended, "day 10 journal with five mains did not end the run")
	bad += _expect(GameState.ending_id == &"ejemplar", "safe kit with five mains on day 10 should be ejemplar, got %s" % GameState.ending_id)
	return bad


func _case_four_mains_day_ten() -> int:
	_boot(true)
	GameState.current_sol = 10
	if not _finish(&"fix_solar_panel"):
		return _fail("panel did not complete before the four mains")
	_stop_cutscene()
	for id in [&"study_minerals", &"recover_rovers", &"search_biosignatures", &"study_caves"]:
		if not _finish(id):
			return _fail("could not complete %s" % id)
		_stop_cutscene()
	var bad := 0
	bad += _expect(not GameState.run_over, "four mains closed the run")
	bad += _expect(MissionSystem.get_state(&"study_glaciers") != MissionSystem.COMPLETED, "the fifth main was completed")
	GameState.current_sol = 10
	var ended := EndingSystem.try_end(&"journal")
	bad += _expect(ended, "day 10 journal with four mains did not end")
	bad += _expect(GameState.ending_id == &"justo", "four mains on day 10 should be justo, got %s" % GameState.ending_id)
	return bad


func _case_reserve_needs_every_key() -> int:
	var saved := _drop_mains([
		&"recover_rovers",
		&"search_biosignatures",
		&"study_minerals",
		&"study_caves",
		&"study_glaciers",
	])
	_boot(true)
	var ids := EndingSystem._closing_ids()
	var bad := 0
	bad += _expect(ids.size() == 2, "safe reserve should be two keys, got %s" % _text(ids))
	bad += _expect(&"fix_solar_panel" in ids and &"find_water_ice" in ids, "safe reserve keys: %s" % _text(ids))
	bad += _expect(&"grow_potato" not in ids and &"contact_earth" not in ids, "kit modules leaked into the reserve: %s" % _text(ids))
	if not _finish(&"fix_solar_panel"):
		bad += _fail("reserve panel did not complete")
	else:
		bad += _expect(not GameState.run_over, "reserve ended after only the panel")
		bad += _expect(EndingSystem._closing_ids().size() != 1, "closing ids collapsed to one after the panel")
	_stop_cutscene()
	# Ice alone is the other key, but habitat chores are still on the tracker.
	if not _finish(&"find_water_ice"):
		bad += _fail("reserve ice did not complete")
	else:
		bad += _expect(not GameState.run_over, "reserve ended on ice while other tasks were open")
	_stop_cutscene()
	for id in [&"sort_supplies", &"read_log", &"stow_spare"]:
		if not _finish(id):
			bad += _fail("could not finish side mission %s" % id)
			_restore_mains(saved)
			return bad
		_stop_cutscene()
	bad += _expect(not GameState.run_over, "reserve keys closed the run before day 10")
	bad += _expect(not EndingSystem.try_end(&"mission"), "try_end(mission) closed the reserve")
	_restore_mains(saved)
	return bad


func _case_rescue_and_day_ten() -> int:
	_boot(true)
	GameState.current_sol = 3
	ResourceSystem.debug_empty(&"oxygen")
	var bad := 0
	bad += _expect(GameState.run_over, "oxygen at 0 did not rescue")
	bad += _expect(GameState.ending_id == &"rescate", "empty oxygen ending was %s" % GameState.ending_id)
	_boot(true)
	GameState.current_sol = 10
	var ended := EndingSystem.try_end(&"journal")
	bad += _expect(ended, "closing the day 10 journal did not end the run")
	bad += _expect(GameState.run_over, "day 10 left run_over false")
	bad += _expect(GameState.ending_id != &"", "day 10 did not pick an ending")
	return bad


func _case_play_again_clears_run_over() -> int:
	GameState.run_over = true
	GameState.ending_id = &"justo"
	GameState.reset()
	ResourceSystem.reset()
	DayNightSystem.reset_cycle()
	var bad := 0
	bad += _expect(not GameState.run_over, "play again kept run_over")
	bad += _expect(GameState.ending_id == &"", "play again kept the ending")
	bad += _expect(GameState.missions.is_empty(), "play again kept mission progress")
	return bad


func _boot(safe_kit: bool) -> void:
	_stop_cutscene()
	get_tree().paused = false
	for module in ResourceSystem.get_modules():
		ResourceSystem.unregister_module(module)
	GameState.reset()
	ResourceSystem.reset()
	DayNightSystem.reset_cycle()
	BasePlacer.active = false
	if safe_kit:
		for id in [&"habitat", &"oxygen_tank", &"solar_panel"]:
			var module := BaseModule.new()
			module.data = BaseCatalog.get_module(id)
			ResourceSystem.register_module(module)
	MissionSystem.start_run()
	MissionSystem._waiting_start = false
	DayNightSystem.start_mission()
	MissionSystem._unlock_ready()


func _finish(id: StringName) -> bool:
	if MissionSystem.get_state(id) == MissionSystem.LOCKED:
		MissionSystem._unlock_ready()
	if MissionSystem.get_state(id) != MissionSystem.ACTIVE:
		push_error("ending_check: %s is %s, not active" % [id, MissionSystem.get_state(id)])
		return false
	var objectives: Array = MissionSystem.get_mission(id).get("objectives", [])
	for objective in objectives:
		if bool(objective.get("optional", false)):
			continue
		if MissionSystem.is_objective_done(id, String(objective.get("id", ""))):
			continue
		if not MissionSystem.complete_objective(id, String(objective.get("id", ""))):
			push_error("ending_check: could not complete %s / %s" % [id, objective.get("id", "")])
			return false
		_stop_cutscene()
	return MissionSystem.get_state(id) == MissionSystem.COMPLETED


func _stop_cutscene() -> void:
	if Cutscenes.is_playing():
		Cutscenes.skip()
	get_tree().paused = false


func _drop_mains(ids: Array) -> Dictionary:
	var saved := {}
	for id in ids:
		var key := StringName(id)
		if MissionSystem._defs.has(key):
			saved[key] = MissionSystem._defs[key]
			MissionSystem._defs.erase(key)
		MissionSystem._ids.erase(key)
	return saved


func _restore_mains(saved: Dictionary) -> void:
	for key in saved:
		MissionSystem._defs[key] = saved[key]
		if key not in MissionSystem._ids:
			MissionSystem._ids.append(key)


func _main_count() -> int:
	var n := 0
	for id in MissionSystem.all_ids():
		if MissionSystem.get_category(id) == "main":
			n += 1
	return n


func _text(list: Array) -> String:
	var parts: PackedStringArray = []
	for id in list:
		parts.append(String(id))
	return ",".join(parts)


func _expect(ok: bool, message: String) -> int:
	if ok:
		return 0
	push_error("ending_check: %s" % message)
	return 1


func _fail(message: String) -> int:
	push_error("ending_check: %s" % message)
	return 1
