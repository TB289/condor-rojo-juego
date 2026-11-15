class_name NasaDataPanel
extends Control
## Saved NASA facts. Links open in the browser. Nothing here downloads data.

signal closed

const FONT := preload("res://assets/fonts/m5x7.ttf")
const THEME := preload("res://ui/theme/condor_theme.tres")

var _back: Button
var _scroll: ScrollContainer
var _body: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = THEME
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(Palette.ESPACIO, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 320)
	panel.theme = THEME
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	var title := Label.new()
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Palette.CREMA)
	column.add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(560, 240)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 3)
	_scroll.add_child(_body)
	_back = Button.new()
	_back.pressed.connect(_on_back)
	column.add_child(_back)
	Settings.language_changed.connect(func(_lang: String) -> void:
		if visible:
			_fill()
	)
	hide()


func back_button() -> Button:
	return _back


func open() -> void:
	_fill()
	show()
	_back.grab_focus()


func _on_back() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		_on_back()
		get_viewport().set_input_as_handled()


func _fill() -> void:
	for node in get_children():
		var title := _find_title(node)
		if title != null:
			title.text = Settings.text("nasa.title")
			break
	_back.text = Settings.text("common.back")
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_add(banner_text(), Palette.CREMA)
	_add(NasaData.honesty(), Palette.CREMA)
	_add(NasaData.places_note(), Palette.METAL)
	_add(Settings.text("nasa.mission"), Palette.CREMA)
	_fill_mission()
	_add(Settings.text("nasa.hazards"), Palette.CREMA)
	for row in NasaData.hazard_rows():
		_hazard(row)
	_add(Settings.text("nasa.sources"), Palette.CREMA)
	_fill_sources()
	_add(Settings.text("nasa.glossary"), Palette.CREMA)
	for item in NasaData.glossary():
		var term := String(item.get("en" if Settings.lang == "en" else "es", ""))
		_add("%s — %s" % [term, NasaData.capsule(String(item.get("capsule", "")))], Palette.CREMA)
	_add(Settings.text("nasa.photos"), Palette.CREMA)
	_fill_photos()
	_wire_focus()


func _fill_mission() -> void:
	var row := NasaData.display_scenario()
	if NasaData.scenario_is_example():
		_add(Settings.text("nasa.example"), Palette.METAL)
	if row.is_empty():
		return
	var name := String(row.get("name_en" if Settings.lang == "en" else "name", ""))
	_add("%s. %s." % [name, NasaData.format_span(String(row.get("start", "")), String(row.get("end", "")))], Palette.CREMA)
	for day in row.get("days", []):
		if not day is Dictionary:
			continue
		var bits := _day_bits(day)
		if bits.is_empty():
			continue
		_add(bits, Palette.CREMA)
		for url in day.get("donki", []):
			_link(String(url), String(url))


func _day_bits(day: Dictionary) -> String:
	var interesting := int(day.get("level", 0)) > 0 or bool(day.get("storm", false)) or day.has("kp") or bool(day.get("blackout", false))
	if not interesting:
		return ""
	var when := NasaData.format_short(String(day.get("date", "")))
	var parts: PackedStringArray = [when]
	if bool(day.get("blackout", false)):
		parts.append("conjunción" if Settings.lang != "en" else "conjunction")
	var flare := String(day.get("flare", ""))
	if not flare.is_empty():
		parts.append(flare)
	if int(day.get("sep", 0)) > 0:
		parts.append("SEP")
	if day.has("kp"):
		parts.append("Kp %s" % NasaData.num(float(day.get("kp", 0.0)), 2))
	if bool(day.get("storm", false)):
		parts.append("tormenta" if Settings.lang != "en" else "storm")
	return " · ".join(parts)


func _fill_sources() -> void:
	var file := FileAccess.open("res://data/nasa/sources.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
	if not parsed is Dictionary:
		return
	for row in parsed.get("sources", []):
		if not row is Dictionary:
			continue
		_add(String(row.get("name", "")), Palette.CREMA)
		_add(NasaData.accessed_line(), Palette.METAL)
		_link(Settings.text("nasa.open"), String(row.get("url", "")))


func _fill_photos() -> void:
	for row in NasaData.images():
		if not row is Dictionary:
			continue
		var tex := NasaData.image_texture(String(row.get("id", "")))
		if tex != null:
			var rect := TextureRect.new()
			rect.texture = tex
			rect.custom_minimum_size = Vector2(220, 88)
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_body.add_child(rect)
		var key := "en" if Settings.lang == "en" else "es"
		_add(String(row.get(key, "")), Palette.CREMA)
		_add(String(row.get("credit", "NASA/JPL-Caltech")), Palette.METAL)
		_link(Settings.text("nasa.open"), String(row.get("page", "")))


func _hazard(row: Dictionary) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.texture = NasaData.hazard_texture(String(row.get("id", "")))
	icon.custom_minimum_size = Vector2(12, 12)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	line.add_child(icon)
	var key := "en" if Settings.lang == "en" else "es"
	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_override("font", FONT)
	text.add_theme_font_size_override("font_size", 16)
	text.add_theme_color_override("font_color", Palette.CREMA)
	text.text = "%s — %s %s" % [String(row.get(key, "")), String(row.get("game_" + key, "")), String(row.get("fact_" + key, ""))]
	line.add_child(text)
	_body.add_child(line)


func _link(label: String, url: String) -> void:
	if url.is_empty():
		return
	var button := Button.new()
	button.text = label
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Palette.INTI)
	button.add_theme_color_override("font_hover_color", Palette.CREMA)
	button.add_theme_color_override("font_focus_color", Palette.ORO)
	button.pressed.connect(func() -> void: NasaData.open_url(url))
	_body.add_child(button)


func _add(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	_body.add_child(label)


func banner_text() -> String:
	return NasaData.banner()


func _find_title(node: Node) -> Label:
	if node.name == "Title" and node is Label:
		return node
	for child in node.get_children():
		var found := _find_title(child)
		if found != null:
			return found
	return null


func _wire_focus() -> void:
	var buttons: Array[Button] = []
	for child in _body.get_children():
		if child is Button:
			buttons.append(child)
	buttons.append(_back)
	_scroll.focus_mode = Control.FOCUS_ALL
	for i in buttons.size():
		var up: Control = _scroll if i == 0 else buttons[i - 1]
		var down: Control = buttons[i] if i + 1 >= buttons.size() else buttons[i + 1]
		if i == 0:
			up = _scroll
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(up)
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(down)
		buttons[i].focus_neighbor_left = buttons[i].get_path_to(buttons[i])
		buttons[i].focus_neighbor_right = buttons[i].get_path_to(buttons[i])
	_scroll.focus_neighbor_bottom = _scroll.get_path_to(buttons[0] if not buttons.is_empty() else _back)
	_scroll.focus_neighbor_top = _scroll.get_path_to(_scroll)
