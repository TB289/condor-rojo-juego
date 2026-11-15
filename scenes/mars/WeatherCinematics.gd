class_name WeatherCinematics
extends CanvasLayer
## Screen-space sunlight, wind-blown dust and radiation color grading.
## Lives inside the 640x360 world viewport, never over the HUD or touch controls.
## All effects adapt smoothly to the existing clock and NASA storm data.

const SCREEN := Vector2(640.0, 360.0)
const GUST_COUNT := 95

var _canvas: Control
var _grade: ColorRect
var _material: ShaderMaterial
var _grain: Array[Dictionary] = []
var _seconds := 0.0
var _dust := 0.0
var _radiation := 0.0
var _day_phase := 0.0
var _outside := false
var _warning: Label


func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_ALWAYS
	_grade = ColorRect.new()
	_grade.name = "StormColorGrade"
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade.color = Color.WHITE
	_material = ShaderMaterial.new()
	_material.shader = preload("res://assets/shaders/mars_weather.gdshader")
	_grade.material = _material
	add_child(_grade)
	_grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas = Control.new()
	_canvas.name = "SunAndDust"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_paint)
	_warning = Label.new()
	_warning.name = "StormWarning"
	_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning.add_theme_font_override("font", preload("res://assets/fonts/m5x7.ttf"))
	_warning.add_theme_font_size_override("font_size", 17)
	_warning.add_theme_color_override("font_color", Color("fff3bd"))
	_warning.add_theme_color_override("font_outline_color", Color("341024"))
	_warning.add_theme_constant_override("outline_size", 4)
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.position = Vector2(95.0, 308.0)
	_warning.size = Vector2(450.0, 26.0)
	_warning.hide()
	_canvas.add_child(_warning)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1894
	for i in GUST_COUNT:
		_grain.append({
			"x": rng.randf_range(-40.0, 680.0),
			"y": rng.randf_range(0.0, SCREEN.y),
			"size": rng.randf_range(1.0, 2.5),
			"speed": rng.randf_range(100.0, 250.0),
			"phase": rng.randf_range(0.0, 6.283),
		})


func _process(delta: float) -> void:
	var active := DayNightSystem.has_started() and not GameState.run_over and not BasePlacer.active
	active = active and not Cutscenes.is_playing() and not DayNightSystem.is_journal_open()
	_outside = active and GameState.interior_id == &""
	var running := _outside and not get_tree().paused
	if running:
		_seconds += delta
	var wanted_dust := WorldEventDirector.sandstorm_strength() if _outside else 0.0
	_dust = move_toward(_dust, wanted_dust, delta * 0.45)
	var flare_live := _outside and NasaData.solar_storm_active()
	var wanted_radiation := 1.0 if flare_live else 0.0
	# The flare reaches full strength quickly, then the vivid grading settles
	# gradually over the evening rather than switching off instantly.
	_radiation = move_toward(_radiation, wanted_radiation, delta * (0.45 if flare_live else 0.055))
	_day_phase = clampf(DayNightSystem.sol_progress() / DayNightSystem.DUSK_AT, 0.0, 1.0)
	_grade.visible = _outside and (_dust > 0.005 or _radiation > 0.005)
	_material.set_shader_parameter("dust_strength", _dust)
	_material.set_shader_parameter("radiation_strength", _radiation)
	_material.set_shader_parameter("seconds", _seconds)
	var screen := Vector2(0.5, 0.5)
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player != null:
		screen = get_viewport().get_canvas_transform() * player.global_position / SCREEN
	_material.set_shader_parameter("player_screen", screen)
	_canvas.visible = _outside
	if not _outside:
		_warning.hide()
		return
	if _radiation > 0.01 or NasaData.solar_storm_countdown_active():
		_warning.show()
		var left := NasaData.visible_storm_countdown()
		if left > 0:
			_warning.text = ("SOLAR STORM IN %ds - SHELTER!" if Settings.lang == "en" else "TORMENTA SOLAR EN %ds - REFUGIO!") % left
		elif NasaData.solar_storm_countdown_active():
			_warning.text = "SOLAR WARNING - RETURN TO BASE!" if Settings.lang == "en" else "ALERTA SOLAR - VUELVE A LA BASE!"
		else:
			_warning.text = ("RADIATION! GET INSIDE THE HABITAT" if Settings.lang == "en" else "RADIACION! VUELVE AL HABITAT")
	elif _dust > 0.18:
		_warning.show()
		_warning.text = "SANDSTORM - LOW VISIBILITY" if Settings.lang == "en" else "TORMENTA DE ARENA - POCA VISION"
	else:
		_warning.hide()
	if running:
		for speck in _grain:
			speck["x"] = fposmod(float(speck["x"]) + delta * float(speck["speed"]) * (0.28 + _dust * 1.85) + 60.0, 740.0) - 60.0
			speck["y"] = fposmod(float(speck["y"]) + sin(_seconds * 4.0 + float(speck["phase"])) * delta * (16.0 + 45.0 * _dust), SCREEN.y)
	_canvas.queue_redraw()


func _paint() -> void:
	if not _outside:
		return
	# Visible sun tracking dawn -> zenith -> sunset. Atmospheric band is faint
	# because gameplay is viewed top-down and it must not hide objective markers.
	var daylight := sin(_day_phase * PI)
	if DayNightSystem.sol_progress() <= DayNightSystem.DUSK_AT and daylight > 0.025:
		var sun_pos := Vector2(42.0 + _day_phase * 555.0, 68.0 - 52.0 * daylight)
		var opacity := daylight * (1.0 - _dust * 0.78)
		var warm := Color("fff0af").lerp(Color("ffb35f"), absf(_day_phase - 0.5) * 1.7)
		_canvas.draw_circle(sun_pos, 25.0, Color(warm.r, warm.g, warm.b, opacity * 0.045))
		_canvas.draw_circle(sun_pos, 16.0, Color(warm.r, warm.g, warm.b, opacity * 0.07))
		_canvas.draw_circle(sun_pos, 5.2, Color(warm.r, warm.g, warm.b, opacity * 0.77))
		_canvas.draw_circle(sun_pos, 2.5, Color(1.0, 0.99, 0.85, opacity * 0.90))
		for i in 8:
			var direction := Vector2.from_angle(float(i) * TAU / 8.0)
			_canvas.draw_line(sun_pos + direction * 7.5, sun_pos + direction * 11.5, Color(warm.r, warm.g, warm.b, opacity * 0.38), 1.0)
	if _radiation > 0.08:
		# A readable immediate-danger meter; this is not the real mSv dosimeter.
		var danger := NasaData.solar_storm_danger()
		_canvas.draw_rect(Rect2(174.0, 340.0, 292.0, 7.0), Color(0.12, 0.07, 0.13, 0.85))
		_canvas.draw_rect(Rect2(176.0, 342.0, 288.0 * danger, 3.0),
			Color("ffb347").lerp(Color("ff365f"), danger))
	if _dust < 0.02:
		return
	# Small wind-blown grains are kept in screen space, so gusts follow
	# the astronaut's view instead of vanishing when the camera walks away.
	var drift_color := Color(1.0, 0.78, 0.48, _dust * 0.64)
	var trail_color := Color(0.50, 0.26, 0.14, _dust * 0.27)
	var count := int(lerpf(12.0, float(_grain.size()), _dust))
	if Settings.reduce_effects:
		count = mini(count, 25)
	for i in count:
		var speck: Dictionary = _grain[i]
		var at := Vector2(float(speck["x"]), float(speck["y"]))
		var length := 4.0 + float(speck["size"]) * 6.0 * _dust
		_canvas.draw_line(at - Vector2(length, 2.0), at + Vector2(2.0, -0.5), trail_color, 1.0)
		_canvas.draw_rect(Rect2(at, Vector2(float(speck["size"]), 1.0)), drift_color)
