extends CanvasLayer
## NASA rover fact cards. Triggered by MissionArea when E/touch interact is used.
## The world-positioned mission targets remain untouched when showing a card.

const DATA_PATH := "res://data/rovers.json"
const FONT := preload("res://assets/fonts/m5x7.ttf")
const THEME := preload("res://ui/theme/condor_theme.tres")
const WIDTH := 306.0
const HEIGHT := 220.0

var _data: Dictionary = {}
var _active_id: StringName = &""
var _origin: Node2D
var _panel: PanelContainer
var _title: Label
var _icon: TextureRect
var _body: RichTextLabel
var _close_button: Button


func _ready() -> void:
	add_to_group(&"rover_info_panel")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		_data = parsed
	else:
		push_error("RoverInfoPanel: could not load data/rovers.json")
	_build_panel()
	Settings.language_changed.connect(_on_language_changed)


func _exit_tree() -> void:
	if Settings.language_changed.is_connected(_on_language_changed):
		Settings.language_changed.disconnect(_on_language_changed)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "RoverCard"
	_panel.theme = THEME
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -WIDTH * 0.5
	_panel.offset_right = WIDTH * 0.5
	_panel.offset_top = -HEIGHT - 9.0
	_panel.offset_bottom = -9.0
	add_child(_panel)

	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 5)
	outer.add_theme_constant_override("margin_right", 5)
	outer.add_theme_constant_override("margin_top", 3)
	outer.add_theme_constant_override("margin_bottom", 3)
	_panel.add_child(outer)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	outer.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	column.add_child(header)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(36, 27)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	header.add_child(_icon)

	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_override("font", FONT)
	_title.add_theme_font_size_override("font_size", 19)
	_title.add_theme_color_override("font_color", Color("ffe000"))
	header.add_child(_title)

	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.custom_minimum_size = Vector2(23, 23)
	_close_button.pressed.connect(_dismiss)
	header.add_child(_close_button)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.scroll_active = true
	_body.scroll_following = false
	_body.fit_content = false
	_body.custom_minimum_size = Vector2(0, 168)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_override("normal_font", FONT)
	_body.add_theme_font_override("bold_font", FONT)
	_body.add_theme_font_size_override("normal_font_size", 15)
	_body.add_theme_font_size_override("bold_font_size", 15)
	_body.add_theme_color_override("default_color", Color("fffce8"))
	column.add_child(_body)
	_panel.hide()


func inspect_rover(id: StringName, source: Node2D) -> void:
	var key := String(id)
	if not _data.has(key):
		return
	if _active_id == id and _panel.visible:
		_dismiss()
		return
	_active_id = id
	_origin = source
	_fill()
	_panel.show()


func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	if not is_instance_valid(_origin) or Cutscenes.is_playing() or GameState.run_over:
		_dismiss()
		return
	var astronaut := get_tree().get_first_node_in_group(&"player") as Node2D
	if astronaut == null or astronaut.global_position.distance_to(_origin.global_position) > 105.0:
		_dismiss()


func _on_language_changed(_new_lang: String) -> void:
	if _panel.visible:
		_fill()


func _text_value(entry: Dictionary, field: String) -> String:
	var localized: Dictionary = entry.get(field, {})
	return String(localized.get(Settings.lang, localized.get("en", "")))


func _years_since(landing_iso: String) -> int:
	if landing_iso.length() < 10:
		return 0
	var d := Time.get_date_dict_from_system()
	var years := int(d["year"]) - int(landing_iso.substr(0, 4))
	var m := int(landing_iso.substr(5, 2))
	var day := int(landing_iso.substr(8, 2))
	if int(d["month"]) < m or (int(d["month"]) == m and int(d["day"]) < day):
		years -= 1
	return maxi(years, 0)


func _fill() -> void:
	var item: Dictionary = _data.get(String(_active_id), {})
	if item.is_empty():
		return
	_title.text = String(item.get("name", ""))
	var texture_path := String(item.get("texture", ""))
	if ResourceLoader.exists(texture_path):
		_icon.texture = load(texture_path) as Texture2D
	else:
		_icon.texture = null
	var es := Settings.lang == "es"
	var years := _years_since(String(item.get("landing_date", "")))
	var elapsed := "%d años" % years if es else "%d years" % years
	if item.has("time_on_mars"):
		elapsed = _text_value(item, "time_on_mars")
	var line_purpose := "Propósito" if es else "Purpose"
	var line_did := "Qué hizo" if es else "What it did"
	var line_time := "Tiempo en Marte" if es else "Time on Mars"
	var line_launch := "Enviado" if es else "Sent"
	var text := "[color=#ffe000]%s[/color]\n%s\n\n" % [line_purpose, _text_value(item, "purpose")]
	text += "[color=#ffe000]%s[/color]\n%s\n\n" % [line_did, _text_value(item, "achievement")]
	text += "[color=#ffe000]%s:[/color] %s\n" % [line_time, elapsed]
	var sent := _text_value(item, "sent") if item.has("sent") else _text_value(item, "launched")
	text += "[color=#ffe000]%s:[/color] %s\n" % [line_launch, sent]
	_body.text = text
	_body.scroll_to_line(0)


func _dismiss() -> void:
	_panel.hide()
	_origin = null
	_active_id = &""
