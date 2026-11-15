class_name SurfaceHotbar
extends Control
## Backpack / flashlight / cargo, always visible on the Martian surface.
## Slot 3 enables rover pushing with Q (or the touch mission-action button).

const FONT: Font = preload("res://assets/fonts/m5x7.ttf")
const LABELS_ES := ["MOCHILA", "LINTERNA", "CARGA"]
const LABELS_EN := ["BACKPACK", "FLASHLIGHT", "CARGO"]
const CELL := Vector2(66, 42)
const GAP := 4.0

var selected_slot := 0


func _ready() -> void:
	add_to_group(&"surface_hotbar")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(CELL.x * 3.0 + GAP * 2.0, CELL.y)
	custom_minimum_size = size
	z_index = 8


func _process(_delta: float) -> void:
	var active := GameState.interior_id == &"" and not GameState.run_over and not BasePlacer.active
	# Legacy slot selector is disabled; keyboard, mouse and touch do not switch tools.
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if visible:
		var view := get_viewport_rect().size
		position = Vector2((view.x - size.x) * 0.5, view.y - size.y - 6.0)
		queue_redraw()


func select_slot(index: int) -> void:
	selected_slot = clampi(index, 0, 2)
	if selected_slot == 1:
		var player := get_tree().get_first_node_in_group(&"player") as Player
		if player != null and player.has_method(&"toggle_flashlight"):
			player.toggle_flashlight()
	queue_redraw()


func rover_available() -> bool:
	if selected_slot != 2:
		return false
	for rover in get_tree().get_nodes_in_group(&"pushable_rover"):
		if rover.has_method(&"player_is_near") and rover.call("player_is_near"):
			return true
	return false


func _draw() -> void:
	var labels: Array = LABELS_ES if Settings.lang == "es" else LABELS_EN
	for index in 3:
		var pos := Vector2(index * (CELL.x + GAP), 0)
		var rect := Rect2(pos, CELL)
		draw_rect(rect, Palette.NAVY)
		draw_rect(rect, Palette.ORO if index == selected_slot else Palette.METAL, false, 2.0 if index == selected_slot else 1.0)
		var text_pos := pos + Vector2(6, 12)
		draw_string(FONT, text_pos, str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.ORO)
		match index:
			0:
				draw_rect(Rect2(pos + Vector2(27, 10), Vector2(13, 13)), Palette.TERRACOTA)
				draw_rect(Rect2(pos + Vector2(31, 7), Vector2(5, 4)), Palette.ARENA)
			1:
				draw_rect(Rect2(pos + Vector2(26, 12), Vector2(14, 6)), Palette.METAL)
				draw_rect(Rect2(pos + Vector2(40, 10), Vector2(5, 10)), Palette.ORO)
			2:
				draw_rect(Rect2(pos + Vector2(27, 10), Vector2(15, 12)), Palette.METAL)
				draw_rect(Rect2(pos + Vector2(30, 7), Vector2(9, 4)), Palette.INTI)
		draw_string(FONT, pos + Vector2(3, 36), str(labels[index]), HORIZONTAL_ALIGNMENT_CENTER, CELL.x - 6.0, 10, Palette.CREMA)
