extends Node2D
## Game root. The sol clock and the missions start here, after the kit is chosen.
## Debug keys only work in debug builds.
## F2 = oxygen to 0 (rescue). F3 = tonight's journal. Shift+F3 = journal of the last day.
## F4 = finish the next objective of the mission shown on the HUD.
## F7 = play the after_fix_panel cutscene (F5/F6 belong to the editor).
## F8 = cycle the saved space-weather scenario for this run.
## F9 = trigger sandstorm, F10 = preview solar-storm warning and exposure.


func _ready() -> void:
	MissionSystem.start_run()
	DayNightSystem.start_mission()
	AudioManager.enter_gameplay()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F2:
			ResourceSystem.debug_empty(&"oxygen")
		KEY_F3:
			if key.shift_pressed:
				DayNightSystem.skip_to_last_night()
			else:
				DayNightSystem.skip_to_night()
		KEY_F4:
			MissionSystem.debug_complete_current()
		KEY_F7:
			Cutscenes.play(&"after_fix_panel")
		KEY_F8:
			print("space weather: ", NasaData.cycle_scenario())
		KEY_F9:
			WorldEventDirector.trigger_sandstorm()
		KEY_F10:
			NasaData.debug_trigger_solar_storm()
		_:
			return
	get_viewport().set_input_as_handled()
