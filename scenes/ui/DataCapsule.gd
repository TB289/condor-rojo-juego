class_name DataCapsule
extends CanvasLayer
## One small NASA fact card. It never speaks as INTI and never stacks.
## A tap, a click, E, or a gamepad button closes it. It also leaves after a few seconds.

signal dismissed

const FONT := preload("res://assets/fonts/m5x7.ttf")
const THEME := preload("res://ui/theme/condor_theme.tres")
const CARD_W := 268.0
const TOP := 62.0
const TEXT_SECONDS := 6.0
const PHOTO_SECONDS := 8.0

var _card: PanelContainer
var _icon: TextureRect
var _body: Label
var _source: Label
var _photos: HBoxContainer
var _left := 0.0
var _open := false


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	_card = PanelContainer.new()
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.theme = THEME
	_card.add_theme_stylebox_override("panel", _style())
	_card.gui_input.connect(_on_gui)
	add_child(_card)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	_card.add_child(margin)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	margin.add_child(col)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	col.add_child(row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(12, 12)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)
	_body = _label(Palette.CREMA)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_body)
	_photos = HBoxContainer.new()
	_photos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photos.add_theme_constant_override("separation", 4)
	_photos.visible = false
	col.add_child(_photos)
	_source = _label(Palette.METAL)
	col.add_child(_source)


func is_open() -> bool:
	return _open


func present(text: String, source_line: String, icon: Texture2D, photos: Array = []) -> void:
	if not NasaData.SHOW_FACT_POPUPS:
		return
	_clear_photos()
	_body.text = text
	_source.text = source_line
	_icon.texture = icon
	_icon.visible = icon != null
	var photo_mode := not photos.is_empty()
	_photos.visible = photo_mode
	for item in photos:
		if not item is Dictionary:
			continue
		_photos.add_child(_photo(item))
	_open = true
	_left = PHOTO_SECONDS if photo_mode else TEXT_SECONDS
	_card.visible = true
	_place()


func hide_card() -> void:
	if not _open:
		return
	_open = false
	_left = 0.0
	_card.visible = false
	_clear_photos()


func _process(delta: float) -> void:
	if not _open:
		return
	if get_tree().paused:
		return
	_place()
	_left -= delta
	if _left <= 0.0:
		_close()


func _unhandled_input(event: InputEvent) -> void:
	if not _open or get_tree().paused:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		_close()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		_close()
		get_viewport().set_input_as_handled()


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()
		_card.accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_close()
		_card.accept_event()


func _close() -> void:
	hide_card()
	dismissed.emit()


func _place() -> void:
	var height := _card.get_combined_minimum_size().y
	_card.offset_left = (640.0 - CARD_W) * 0.5
	_card.offset_right = _card.offset_left + CARD_W
	_card.offset_top = TOP
	_card.offset_bottom = TOP + height


func _photo(item: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rect := TextureRect.new()
	rect.texture = item.get("texture")
	rect.custom_minimum_size = Vector2(120, 68)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rect)
	var caption := _label(Palette.CREMA)
	caption.text = String(item.get("caption", ""))
	box.add_child(caption)
	var credit := _label(Palette.METAL)
	credit.text = String(item.get("credit", "NASA/JPL-Caltech"))
	box.add_child(credit)
	return box


func _clear_photos() -> void:
	for child in _photos.get_children():
		_photos.remove_child(child)
		child.queue_free()


func _label(color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	return label


func _style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.NAVY, 0.94)
	box.border_color = Palette.CONTORNO
	box.set_border_width_all(2)
	box.set_corner_radius_all(0)
	box.anti_aliasing = false
	box.content_margin_left = 2
	box.content_margin_right = 2
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box
