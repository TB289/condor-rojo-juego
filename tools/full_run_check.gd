extends Node
## Headless Día 1–10. Every mission must be reachable, marked, and finishable.
## Swapping away the solar panel must leave that mission locked, not active with no target.
## Play again must clear the previous run. Debrief titles stay cream and pending stays gray.


var _failed := 0
var _events: Dictionary = {}


func apply_look(_on: bool, _perspective: float, _curvature: float, _band: float, _tilt: float) -> void:
	pass


func _ready() -> void:
	var saved_lang := Settings.lang
	_failed += _run()
	if Settings.lang != saved_lang:
		Settings.set_lang(saved_lang)
	get_tree().paused = false
	print("FULL_RUN_RESULT ", _failed)
	if _failed > 0:
		push_error("full_run_check: %d assertion(s) failed" % _failed)
	else:
		print("full_run_check: all cases passed")
	get_tree().quit(1 if _failed > 0 else 0)


func _run() -> int:
	var bad := 0
	if EventBus.mission_completed.is_connected(Cutscenes._on_mission_completed):
		EventBus.mission_completed.disconnect(Cutscenes._on_mission_completed)
	_load_events()
	var oxygen_start := _boot_world()
	bad += _audit_rules()
	bad += _debrief_colors()
	MissionSystem.start_run()
	DayNightSystem.start_mission()
	MissionSystem._waiting_start = false
	MissionSystem._unlock_ready()
	bad += _sign_and_drain()
	bad += _play_ten_days()
	bad += _expect(not GameState.run_over, "finishing the missions ended the run")
	bad += _expect(not EndingSystem.try_end(&"mission"), "try_end(mission) ended the run")
	bad += _solar_stays_locked()
	bad += _play_again(oxygen_start)
	bad += _touch_smoke()
	bad += _nasa_data()
	return bad


func _boot_world() -> float:
	add_to_group(&"world_frame")
	var map := (load("res://scenes/mars/MarsMap.tscn") as PackedScene).instantiate()
	add_child(map)
	BasePlacer.active = false
	GameState.reset()
	ResourceSystem.reset()
	DayNightSystem.reset_cycle()
	var entities := map.get_node("Entities") as Node2D
	var spot := 0
	for id in ["habitat", "greenhouse", "solar_panel", "oxygen_tank", "antenna_dish"]:
		var data := BaseCatalog.get_module(StringName(id))
		if data == null:
			_fail("missing module %s" % id)
			continue
		var module := (load("res://scenes/base/BaseModule.tscn") as PackedScene).instantiate() as BaseModule
		module.data = data
		module.position = Vector2(80 + spot * 90, 80)
		entities.add_child(module)
		spot += 1
	for room_id in ["habitat", "greenhouse", "cave"]:
		var room := InteriorRoom.new()
		room.room_id = StringName(room_id)
		room.name = "Room_%s" % room_id
		add_child(room)
	var look := map.get_node_or_null("SurfaceLook")
	if look == null:
		_fail("SurfaceLook was not created")
	elif look.perspective_strength != 0.0 or look.curvature_strength != 0.0 or look.tilt_strength != 0.0:
		_fail("SurfaceLook strengths are not 0")
	return ResourceSystem.get_value(&"oxygen")


func _load_events() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/events/events.json"))
	if not parsed is Dictionary:
		return
	for event in parsed.get("events", []):
		if event is Dictionary:
			_events[String(event.get("id", ""))] = true


func _audit_rules() -> int:
	var bad := 0
	var known := {}
	for id in MissionSystem.all_ids():
		known[String(id)] = true
	bad += _expect(EndingSystem.MAIN_MISSIONS.size() == 5, "expected 5 main missions")
	for id in EndingSystem.MAIN_MISSIONS:
		bad += _expect(known.has(String(id)), "main %s is not a mission" % id)
	var source := FileAccess.get_file_as_string("res://scenes/ui/PixelTitle.gd")
	bad += _expect(not source.contains("title_fill"), "PixelTitle still references the gradient shader")
	for id in MissionSystem.all_ids():
		var mission := MissionSystem.get_mission(id)
		var unlock: Variant = mission.get("unlock", "")
		var rules: Array = unlock if unlock is Array else [unlock]
		if rules.is_empty():
			bad += _fail("%s has no unlock" % id)
		for rule in rules:
			bad += _rule(id, String(rule), known)
		var need := String(mission.get("requires_module", ""))
		if not need.is_empty() and BaseCatalog.get_module(StringName(need)) == null:
			bad += _fail("%s requires a missing module %s" % [id, need])
		for objective in mission.get("objectives", []):
			bad += _mark(id, objective)
	return bad


func _rule(mission_id: StringName, text: String, known: Dictionary) -> int:
	if text == "start" or text.begins_with("flag:"):
		return 0
	if text.begins_with("day:"):
		var day := text.trim_prefix("day:").to_int()
		return _expect(day >= 1 and day <= DayNightSystem.mission_length(), "%s unlock %s is outside the run" % [mission_id, text])
	if text.begins_with("event:"):
		return _expect(_events.has(text.trim_prefix("event:")), "%s unlocks on an unknown event %s" % [mission_id, text])
	return _expect(known.has(text), "%s unlocks on an unknown mission %s" % [mission_id, text])


func _mark(mission_id: StringName, objective: Dictionary) -> int:
	var type := String(objective.get("type", ""))
	var tool := String(objective.get("tool", ""))
	if not tool.is_empty() and tool not in Hotbar.TOOLS:
		return _fail("%s uses an unknown tool %s" % [mission_id, tool])
	if type == "survive_days":
		return _expect(int(objective.get("days", 0)) >= 1, "%s survive_days has no days" % mission_id)
	if MissionSystem._objective_mark(objective).is_finite():
		return 0
	return _fail("%s %s has no world mark" % [mission_id, objective.get("id", "")])


func _sign_and_drain() -> int:
	var bad := 0
	bad += _expect(not NasaData.SHOW_FACT_POPUPS, "fact popups are still on")
	NasaData.show_capsule("blackout", true)
	NasaData.show_capsule("hazards", true)
	NasaData.on_main_started(&"find_water_ice")
	NasaData._process(0.2)
	bad += _expect(NasaData._card != null and not NasaData._card.is_open(), "a NASA fact card opened")
	var hud := (load("res://scenes/ui/HUD.tscn") as PackedScene).instantiate()
	add_child(hud)
	bad += _expect(hud.find_child("Prompt", true, false) == null, "HUD still has a screen prompt")
	bad += _expect(hud.find_child("WorldPrompt", true, false) == null, "HUD still has a screen world prompt")
	remove_child(hud)
	hud.free()
	var map := get_tree().get_first_node_in_group(&"mars_map") as Node2D
	if map == null:
		return bad + _fail("no map for the world sign")
	var sign := WorldSign.new()
	map.add_child(sign)
	bad += _expect(not (sign.get_parent() is CanvasLayer), "the interact sign was parented to a screen layer")
	var panel: BaseModule = null
	var rock: Node2D = null
	for node in map.get_node("Entities").get_children():
		if node is BaseModule and (node as BaseModule).data != null and (node as BaseModule).data.id == &"solar_panel":
			panel = node
		elif node is MarsProp and String(node.name) == "Hematite":
			rock = node
	if panel == null:
		bad += _fail("no panel for the world sign")
	else:
		var top := sign.anchor_for(panel)
		var sprite := panel.get_node("Sprite2D") as Sprite2D
		var local_top := sprite.position.y + sprite.offset.y - float(sprite.texture.get_height()) * 0.5
		var expected := panel.to_global(Vector2(sprite.position.x + sprite.offset.x, local_top))
		bad += _expect(is_equal_approx(top.y, expected.y), "panel sign is not on the sprite top")
		bad += _expect(top.y <= panel.global_position.y - 4.0, "panel sign is not above the panel")
	if rock == null:
		bad += _fail("hematite rock missing")
	else:
		var rock_top := sign.anchor_for(rock)
		bad += _expect(rock_top.y <= rock.global_position.y - 4.0, "mineral sign is not above the rock")
	map.remove_child(sign)
	sign.free()
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return bad + _fail("no player for the oxygen check")
	player.velocity = Vector2.ZERO
	player.is_sprinting = false
	GameState.interior_id = &""
	ResourceSystem.set_outside(false)
	ResourceSystem.reset()
	var oxygen := ResourceSystem.get_value(&"oxygen")
	var energy := ResourceSystem.get_value(&"energy")
	ResourceSystem._process(60.0)
	bad += _expect(is_equal_approx(ResourceSystem.get_value(&"oxygen"), oxygen - ResourceSystem.O2_IDLE_DRAIN), "idle oxygen did not drain on the surface")
	bad += _expect(is_equal_approx(ResourceSystem.get_value(&"energy"), energy - ResourceSystem.ENERGY_DRAIN_PER_MIN), "energy is not 6 per minute")
	player.velocity = Vector2(40.0, 0.0)
	ResourceSystem._process(10.0)
	bad += _expect(is_equal_approx(ResourceSystem.get_value(&"oxygen"), oxygen - ResourceSystem.O2_IDLE_DRAIN - ResourceSystem.O2_WALK_DRAIN * 10.0 / 60.0), "walking did not spend more oxygen")
	player.is_sprinting = true
	ResourceSystem._process(10.0)
	var ran := oxygen - ResourceSystem.O2_IDLE_DRAIN - ResourceSystem.O2_WALK_DRAIN * 10.0 / 60.0 - ResourceSystem.O2_RUN_DRAIN * 10.0 / 60.0
	bad += _expect(is_equal_approx(ResourceSystem.get_value(&"oxygen"), ran), "running did not spend more oxygen")
	GameState.interior_id = &"habitat"
	var before_inside := ResourceSystem.get_value(&"oxygen")
	ResourceSystem._process(10.0)
	var regen := 40.0 * 10.0 / 60.0
	bad += _expect(is_equal_approx(ResourceSystem.get_value(&"oxygen"), minf(before_inside + regen, 100.0)), "the habitat did not refill oxygen")
	player.velocity = Vector2.ZERO
	player.is_sprinting = false
	GameState.interior_id = &""
	ResourceSystem.reset()
	return bad


func _play_ten_days() -> int:
	var bad := 0
	var length := DayNightSystem.mission_length()
	for sol in range(1, length + 1):
		GameState.current_sol = sol
		if sol > 1:
			MissionSystem._on_sol_started(sol)
		_drain()
		bad += _audit_active(sol)
	for id in MissionSystem.all_ids():
		if MissionSystem.get_state(id) == MissionSystem.ACTIVE:
			bad += _fail("still active on day %d: %s" % [length, id])
	return bad


func _drain() -> void:
	for _i in 80:
		var progressed := false
		for id in MissionSystem.all_ids():
			if MissionSystem.get_state(id) != MissionSystem.ACTIVE:
				continue
			for objective in MissionSystem.get_mission(id).get("objectives", []):
				if bool(objective.get("optional", false)):
					continue
				if String(objective.get("type", "")) == "survive_days":
					continue
				var objective_id := String(objective.get("id", ""))
				if MissionSystem.is_objective_done(id, objective_id):
					continue
				if MissionSystem.complete_objective(id, objective_id):
					progressed = true
					if Cutscenes.is_playing():
						Cutscenes.skip()
					get_tree().paused = false
					break
			if progressed:
				break
		if not progressed:
			return


func _audit_active(sol: int) -> int:
	var bad := 0
	for id in MissionSystem.all_ids():
		if MissionSystem.get_state(id) != MissionSystem.ACTIVE:
			continue
		var workable: Array = MissionSystem._workable(id)
		if workable.is_empty():
			bad += _fail("day %d: %s is active with nothing left to do" % [sol, id])
			continue
		var possible := false
		for objective in workable:
			var type := String(objective.get("type", ""))
			if type == "survive_days":
				possible = int(objective.get("days", 0)) >= 1
				if not possible:
					bad += _fail("day %d: %s survive_days cannot finish" % [sol, id])
				continue
			if MissionSystem._objective_mark(objective).is_finite():
				possible = true
			else:
				bad += _fail("day %d: %s %s has no mark" % [sol, id, objective.get("id", "")])
		if not possible:
			bad += _fail("day %d: %s is impossible" % [sol, id])
		elif MissionSystem.get_shown() == id:
			var goal := MissionSystem.goal_world(id)
			var current_type := String(workable[0].get("type", ""))
			if current_type != "survive_days":
				bad += _expect(goal.is_finite(), "day %d: arrow for %s is not finite" % [sol, id])
	return bad


func _solar_stays_locked() -> int:
	for module in ResourceSystem.get_modules():
		if module.data != null and module.data.id == &"solar_panel":
			ResourceSystem.unregister_module(module)
			module.free()
	GameState.reset()
	DayNightSystem.reset_cycle()
	MissionSystem.start_run()
	DayNightSystem.start_mission()
	MissionSystem._waiting_start = false
	MissionSystem._unlock_ready()
	var bad := 0
	bad += _expect(MissionSystem.get_state(&"fix_solar_panel") == MissionSystem.LOCKED, "panel mission went active with no panel")
	GameState.current_sol = 2
	MissionSystem._unlock_ready()
	bad += _expect(MissionSystem.get_state(&"study_caves") == MissionSystem.ACTIVE, "caves did not unlock on day 2")
	bad += _expect(MissionSystem.goal_world(&"study_caves").is_finite(), "caves have no arrow")
	bad += _expect(MissionSystem.get_state(&"fix_solar_panel") == MissionSystem.LOCKED, "panel mission unlocked later without a panel")
	bad += _expect(MissionSystem.get_state(&"study_minerals") == MissionSystem.LOCKED, "minerals unlocked without the panel")
	return bad


func _play_again(oxygen_start: float) -> int:
	GameState.current_sol = 6
	GameState.run_over = true
	GameState.ending_id = &"justo"
	GameState.set_flag(&"inti_arrived")
	IntiBrain.ui_busy = true
	IntiBrain.typing = true
	IntiBrain._auto_used = 2
	ResourceSystem.add(&"oxygen", -40.0)
	GameState.reset()
	ResourceSystem.reset()
	DayNightSystem.reset_cycle()
	var bad := 0
	bad += _expect(not GameState.run_over, "play again left run_over")
	bad += _expect(GameState.ending_id == &"", "play again left an ending")
	bad += _expect(not GameState.has_flag(&"inti_arrived"), "play again left the arrival flag")
	bad += _expect(not IntiBrain.ui_busy and not IntiBrain.typing, "play again left INTI busy")
	bad += _expect(IntiBrain._auto_used == 0, "play again left the daily line count")
	bad += _expect(is_equal_approx(ResourceSystem.get_value(&"oxygen"), oxygen_start), "play again did not restore oxygen")
	bad += _expect(GameState.missions.is_empty(), "play again left mission progress")
	DayNightSystem.start_mission()
	bad += _expect(GameState.current_sol == 1, "play again did not start on day 1")
	bad += _expect(DayNightSystem.has_started(), "play again did not start the clock")
	bad += _expect(DayNightSystem.night_amount() < 0.05, "play again started at night")
	bad += _expect(not DayNightSystem.is_journal_open(), "play again left the journal open")
	return bad


func _touch_smoke() -> int:
	TouchControls._secondary_open = false
	TouchControls._editing = false
	TouchControls._layout()
	TouchControls._pads_visible = true
	var bad := 0
	var view: Vector2 = TouchControls._view_size()
	var stick: Rect2 = (TouchControls._stick as Control).get_global_rect()
	bad += _expect(stick.size.x < view.x * 0.34, "joystick covers too much of the screen (%s)" % stick.size)
	bad += _expect(stick.get_center().x < view.x * 0.4, "joystick is not on the left")
	var shown := 0
	for action in TouchControls._pads.keys():
		var pad := TouchControls._pads[action] as Control
		if pad.visible:
			shown += 1
			bad += _expect(pad.get_global_rect().get_center().x > view.x * 0.5, "primary %s is not on the right" % action)
	bad += _expect(shown == TouchControls.PRIMARY.size(), "primary layer shows %d buttons" % shown)
	bad += _expect((TouchControls._more as Control).visible, "more button is hidden")
	bad += _expect(not (TouchControls._edit as Control).visible, "edit strip is on during play")
	bad += _expect(not (TouchControls._smaller as Control).visible, "size buttons are on during play")
	bad += _expect(not (TouchControls._larger as Control).visible, "size buttons are on during play")
	for hidden_name in TouchControls.SECONDARY:
		bad += _expect(not (TouchControls._pads[StringName(hidden_name)] as Control).visible, "%s is on the primary layer" % hidden_name)
	TouchControls._press_at(1, stick.get_center() + Vector2(36, 0))
	var toward := (TouchControls._pads[&"jump"] as Control).get_global_rect().get_center()
	TouchControls._press_at(2, toward)
	var vector := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	bad += _expect(vector.x > 0.25, "joystick did not move right (%s)" % vector)
	bad += _expect(Input.is_action_pressed(&"jump"), "jump did not press while the joystick was held")
	TouchControls._release_finger(1)
	vector = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	bad += _expect(vector.length() < 0.05, "releasing the joystick left movement on")
	bad += _expect(Input.is_action_pressed(&"jump"), "releasing the joystick released jump")
	var sprint := (TouchControls._pads[&"sprint"] as Control).get_global_rect().get_center()
	TouchControls._press_at(3, sprint)
	bad += _expect(Input.is_action_pressed(&"sprint"), "sprint did not stay held")
	TouchControls._release_finger(3)
	bad += _expect(not Input.is_action_pressed(&"sprint"), "sprint stayed held after release")
	TouchControls._process(0.0)
	bad += _expect(not Input.is_action_pressed(&"jump"), "jump stayed pressed after the frame")
	bad += _expect(Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down").length() < 0.05, "touch left movement on")
	TouchControls._secondary_open = true
	TouchControls._layout()
	bad += _expect((TouchControls._pads[&"journal"] as Control).visible, "more did not open the journal")
	bad += _expect((TouchControls._pads[&"flashlight"] as Control).visible, "flashlight left the walking cluster")
	TouchControls._secondary_open = false
	TouchControls._layout()
	TouchControls._root.visible = false
	return bad


func _debrief_colors() -> int:
	var saved_lang := Settings.lang
	var saved_sol := GameState.current_sol
	GameState.ending_id = &"ejemplar"
	GameState.current_sol = 10
	Settings.set_lang("es")
	var scene := (load("res://scenes/ui/Debrief.tscn") as PackedScene).instantiate() as Debrief
	add_child(scene)
	var bad := 0
	var spanish := scene.title_label.text
	bad += _expect(not spanish.is_empty(), "debrief title is empty")
	bad += _title_colors(scene.title_label)
	bad += _pending(scene)
	bad += _header(scene.mains_title)
	Settings.set_lang("en")
	bad += _expect(scene.title_label.text != spanish and not scene.title_label.text.is_empty(), "debrief title did not switch to English")
	bad += _pending(scene)
	bad += _header(scene.mains_title)
	remove_child(scene)
	scene.free()
	GameState.ending_id = &""
	GameState.current_sol = saved_sol
	if Settings.lang != saved_lang:
		Settings.set_lang(saved_lang)
	return bad


func _title_colors(title: PixelTitle) -> int:
	var bad := 0
	bad += _expect(title.get_child_count() >= 3, "PixelTitle has no layers")
	for child in title.get_children():
		if child is CanvasItem and (child as CanvasItem).material != null:
			bad += _fail("PixelTitle is using a shader again")
		if child is Label and (child as Label).label_settings != null:
			var color := (child as Label).label_settings.font_color
			if color.is_equal_approx(Palette.ORO):
				bad += _fail("PixelTitle uses gold")
	return bad


func _pending(scene: Debrief) -> int:
	var word := Settings.text("debrief.pending").to_lower()
	var bad := 0
	var found := false
	for child in scene.mains.get_children():
		var label := child as Label
		if label == null or not word in label.text.to_lower():
			continue
		found = true
		var color := label.get_theme_color(&"font_color")
		bad += _expect(color.is_equal_approx(Palette.METAL), "pending line is not gray")
	return bad + _expect(found, "no pending line containing %s" % word)


func _header(label: Label) -> int:
	if label.label_settings == null:
		return _fail("section header has no color")
	return _expect(label.label_settings.font_color.is_equal_approx(Palette.CREMA), "section header is not cream")


func _expect(ok: bool, message: String) -> int:
	if ok:
		return 0
	return _fail(message)


func _nasa_data() -> int:
	var bad := 0
	var ids: PackedStringArray = ["feb2024", "may2024", "oct2024", "dec2024", "nov2025", "jan2026"]
	for id in ids:
		GameState.reset()
		bad += _expect(NasaData.force_scenario(id), "could not force %s" % id)
		var storms := 0
		bad += _expect(not bool(NasaData.day_row(1).get("storm", false)), "%s storms on Day 1" % id)
		for sol in range(1, 11):
			if bool(NasaData.day_row(sol).get("storm", false)):
				storms += 1
		bad += _expect(storms > 0 and storms <= 3, "%s has %d storms" % [id, storms])
	GameState.reset()
	NasaData.force_scenario("jan2026")
	for sol in range(1, 5):
		GameState.current_sol = sol
		bad += _expect(NasaData.is_blackout(sol), "jan2026 Day %d has contact" % sol)
		bad += _expect(
			not EventSystem._available({"id": "earth_message", "weight": 1}, sol, ""),
			"earth_message rolled on blackout day %d" % sol
		)
		bad += _expect(
			MissionSystem._contact_blocked(&"contact_earth", {"type": "repair"}),
			"contact_earth can finish on Day %d" % sol
		)
	GameState.current_sol = 5
	bad += _expect(not NasaData.is_blackout(5), "Day 5 is still a blackout")
	bad += _expect(
		not MissionSystem._contact_blocked(&"contact_earth", {"type": "repair"}),
		"contact_earth stays blocked on Day 5"
	)
	NasaData.force_scenario("oct2024")
	GameState.current_sol = 1
	GameState.dose_msv = 0.0
	NasaData.on_sol_started(1)
	bad += _expect(is_equal_approx(GameState.dose_msv, 0.67), "calm day dose is %s" % GameState.dose_msv)
	bad += _expect(is_equal_approx(NasaData.storm_full_dose(3), 5.0), "level 3 full dose")
	bad += _expect(is_equal_approx(NasaData.storm_dose(3, 60.0, 1.0), 5.0), "outside window")
	bad += _expect(is_equal_approx(NasaData.storm_dose(3, 60.0, 0.5), 2.5), "base window")
	bad += _expect(is_equal_approx(NasaData.storm_dose(3, 60.0, 0.25), 1.25), "refuge window")
	var warning := NasaData.warning_event(1)
	bad += _expect(not warning.is_empty(), "oct2024 night 1 has no storm warning")
	for option in warning.get("options", []):
		var effects: Dictionary = option.get("effects", {})
		var flags: Dictionary = effects.get("flags", {})
		var shown := absf(float(effects.get("food", 0.0))) + absf(float(effects.get("energy", 0.0)))
		shown += absf(float(flags.get("bonus_food", 0.0)))
		bad += _expect(shown > 0.0, "storm option %s has no chip" % option.get("id", ""))
	bad += _expect(is_equal_approx(NasaData.round_trip_seconds(1), 41.2), "oct2024 Day 1 delay")
	bad += _expect(is_equal_approx(EndingSystem._max_dose, 12.0), "exemplary dose cap is not 12")
	bad += _expect(not (12.0 > EndingSystem._max_dose), "12.0 mSv fails the exemplary dose")
	bad += _expect(12.1 > EndingSystem._max_dose, "12.1 mSv still passes the exemplary dose")
	var banned := ["4 a 24", "4 to 24", "entre 4 y 24"]
	for path in [
		"res://data/events/events.json",
		"res://data/missions/contact_earth.json",
		"res://data/dialogue/debrief.json",
		"res://data/cinematics/cinematics.json",
		"res://data/dialogue/inti_es.json",
		"res://data/dialogue/inti_en.json",
	]:
		var body := FileAccess.get_file_as_string(path)
		for phrase in banned:
			bad += _expect(not phrase in body, "%s still says %s" % [path, phrase])
	return bad


func _fail(message: String) -> int:
	push_error("full_run_check: " + message)
	return 1
