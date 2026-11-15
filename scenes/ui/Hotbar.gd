class_name Hotbar
extends Control
## Three tools for the greenhouse: hand, watering can, seed. Hidden everywhere else.

const ICONS: Array[Texture2D] = [
	preload("res://assets/art/ui/icon_hand.png"),
	preload("res://assets/art/ui/icon_can.png"),
	preload("res://assets/art/ui/icon_seed.png"),
]
const TOOLS: Array[String] = ["hand", "water", "seed"]
const CELL := 20.0
const GAP := 2.0
const PAD := 3.0

var tool_id: String = "hand"

var _index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"hotbar")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	var width := PAD * 2.0 + CELL * 3.0 + GAP * 2.0
	var height := PAD * 2.0 + CELL
	custom_minimum_size = Vector2(width, height)
	size = custom_minimum_size
	z_index = 4
	_select(0)


func _process(_delta: float) -> void:
	# The tool selector was removed; the greenhouse bed is contextual now.
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _should_show() -> bool:
	if GameState.interior_id != &"greenhouse" or GameState.run_over or BasePlacer.active:
		return false
	if Cutscenes.is_playing() or DayNightSystem.is_journal_open() or get_tree().paused:
		return false
	return true


func _place() -> void:
	var reserve := 28.0
	var panel := get_tree().get_first_node_in_group(&"inti_panel")
	if panel != null and panel.has_method(&"bottom_reserve"):
		reserve = float(panel.call(&"bottom_reserve"))
	var view_h := get_viewport_rect().size.y
	if view_h < 2.0:
		view_h = 360.0
	position = Vector2(8, view_h - reserve - size.y)


func _select(index: int) -> void:
	_index = posmod(index, TOOLS.size())
	tool_id = TOOLS[_index]
	queue_redraw()


func _cell_rect(index: int) -> Rect2:
	return Rect2(PAD + float(index) * (CELL + GAP), PAD, CELL, CELL)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.NAVY)
	draw_rect(Rect2(0, 0, size.x, 1), Palette.CONTORNO)
	draw_rect(Rect2(0, size.y - 1, size.x, 1), Palette.CONTORNO)
	draw_rect(Rect2(0, 0, 1, size.y), Palette.CONTORNO)
	draw_rect(Rect2(size.x - 1, 0, 1, size.y), Palette.CONTORNO)
	for i in TOOLS.size():
		var rect := _cell_rect(i)
		var selected := i == _index
		if selected:
			draw_rect(rect.grow(1.0), Palette.ORO)
			draw_rect(rect, Palette.NAVY)
		var icon := ICONS[i]
		if icon != null:
			draw_texture_rect(icon, Rect2(rect.position + Vector2(2, 2), Vector2(16, 16)), false)
		var number_color := Palette.NARANJA if selected else Palette.ORO
		_draw_digit(i + 1, rect.position + Vector2(1, 1), Palette.SOMBRA)
		_draw_digit(i + 1, rect.position, number_color)


func _draw_digit(n: int, at: Vector2, color: Color) -> void:
	var rows: Array[String] = []
	match n:
		1:
			rows = ["010", "110", "010", "010", "111"]
		2:
			rows = ["111", "001", "111", "100", "111"]
		_:
			rows = ["111", "001", "111", "001", "111"]
	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			if row[x] == "1":
				draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), color)
