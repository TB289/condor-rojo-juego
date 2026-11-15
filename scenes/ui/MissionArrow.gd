class_name MissionArrow
extends Control
## Edge arrow for the followed mission when it is off the 640x360 view.
## 16 world pixels read as one meter. Hidden indoors and once the mark is on screen.

const FONT := preload("res://assets/fonts/m5x7.ttf")
const MARGIN := 18.0
const TILE := 16.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var world := MissionSystem.goal_world()
	if not world.is_finite() or not _allowed():
		return
	var screen := _screen(world)
	if not screen.is_finite():
		return
	var view := get_viewport_rect().size
	var center := view * 0.5
	var half := center - Vector2(MARGIN, MARGIN)
	var delta := screen - center
	if absf(delta.x) <= half.x and absf(delta.y) <= half.y:
		return
	var fit := 1.0
	if absf(delta.x) > 0.001:
		fit = minf(fit, half.x / absf(delta.x))
	if absf(delta.y) > 0.001:
		fit = minf(fit, half.y / absf(delta.y))
	var tip := center + delta * fit
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	var main := MissionSystem.get_category(MissionSystem.get_shown()) == "main"
	var color := Palette.ORO if main else Palette.INTI
	_arrow(tip, delta, color)
	var meters := int(round(player.global_position.distance_to(world) / TILE))
	var label := "%d m" % meters
	var inward := delta.normalized()
	if inward == Vector2.ZERO:
		inward = Vector2.DOWN
	var at := tip - inward * 16.0
	var text_size := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var ascent := FONT.get_ascent(16)
	at.x = clampf(at.x, 8.0, view.x - text_size.x - 8.0)
	at.y = clampf(at.y, ascent + 8.0, view.y - 8.0)
	var plate := Rect2(at.x - 3.0, at.y - ascent - 2.0, text_size.x + 6.0, ascent + 5.0)
	draw_rect(plate, Color(0.051, 0.071, 0.11, 0.84))
	for step in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		FONT.draw_string(get_canvas_item(), at + step, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.ESPACIO)
	FONT.draw_string(get_canvas_item(), at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.CREMA)


func _allowed() -> bool:
	if get_tree().paused or GameState.run_over or GameState.interior_id != &"":
		return false
	if BasePlacer.active or Cutscenes.is_playing() or DayNightSystem.is_journal_open():
		return false
	return true


func _screen(world: Vector2) -> Vector2:
	var frame := get_tree().get_first_node_in_group(&"world_frame") as WorldFrame
	if frame == null or frame.world == null:
		return Vector2(INF, INF)
	var local := frame.world.get_canvas_transform() * world
	return frame.position + Vector2(local.x * frame.scale.x, local.y * frame.scale.y)


func _arrow(at: Vector2, dir: Vector2, color: Color) -> void:
	var n := dir.normalized()
	if n == Vector2.ZERO:
		return
	var side := n.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		at + n * 7.0,
		at - n * 5.0 + side * 5.0,
		at - n * 5.0 - side * 5.0,
	]), Palette.SOMBRA)
	draw_colored_polygon(PackedVector2Array([
		at + n * 5.0,
		at - n * 3.0 + side * 3.0,
		at - n * 3.0 - side * 3.0,
	]), color)
