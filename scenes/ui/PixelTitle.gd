class_name PixelTitle
extends Control
## Big m5x7 title: thick dark outline, drop shadow, solid cream fill.

const FONT := preload("res://assets/fonts/m5x7.ttf")

@export var text := "CÓNDOR ROJO"
@export var font_size := 48
@export var centered := false

var _shadow: Label
var _outline: Label
var _fill: Label
var _laying := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	_layout()


func set_text(value: String) -> void:
	text = value
	_layout()


func _layout() -> void:
	if _laying:
		return
	_laying = true
	for child in get_children():
		remove_child(child)
		child.free()
	var px := font_size
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if not centered and width > 240.0 and px > 32:
		px = 32
		width = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	custom_minimum_size = Vector2(width + 14.0, float(px) + 12.0)
	var x := 4.0
	if centered and size.x > 1.0:
		x = maxf((size.x - width) * 0.5, 0.0)
	_shadow = _make(px, Palette.SOMBRA, 0, Palette.SOMBRA)
	_shadow.position = Vector2(x + 3.0, 5.0)
	_outline = _make(px, Palette.CONTORNO, 4, Palette.SOMBRA)
	_outline.position = Vector2(x, 2.0)
	# Solid cream fill. The old gradient shader read the font atlas UVs, so accented glyphs like Ó came out a different color.
	_fill = _make(px, Palette.CREMA, 0, Palette.CREMA)
	_fill.position = Vector2(x, 2.0)
	_laying = false


func _make(size: int, color: Color, outline: int, outline_color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.text = text
	var settings := LabelSettings.new()
	settings.font = FONT
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = outline
	settings.outline_color = outline_color
	label.label_settings = settings
	add_child(label)
	return label
