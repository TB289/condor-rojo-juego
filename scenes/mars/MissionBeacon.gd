class_name MissionBeacon
extends Node2D
## A short mark above the followed mission. One target, the one on the tracker.

const LIFT := 28.0

var _t := 0.0


func _ready() -> void:
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t += delta
	var at := MissionSystem.goal_world()
	var show := at.is_finite() and _allowed()
	visible = show
	if not show:
		return
	global_position = at + Vector2(0, -LIFT)
	queue_redraw()


func _allowed() -> bool:
	if GameState.interior_id != &"" or GameState.run_over or BasePlacer.active:
		return false
	if Cutscenes.is_playing() or DayNightSystem.is_journal_open():
		return false
	return true


func _draw() -> void:
	var bob: int = int(round(sin(_t * 3.2) * 2.0))
	var main := MissionSystem.get_category(MissionSystem.get_shown()) == "main"
	var color := Palette.ORO if main else Palette.INTI
	var origin := Vector2(0, bob)
	draw_rect(Rect2(origin + Vector2(-1, -12), Vector2(2, 10)), color)
	draw_colored_polygon(PackedVector2Array([
		origin + Vector2(0, -18),
		origin + Vector2(5, -12),
		origin + Vector2(0, -6),
		origin + Vector2(-5, -12),
	]), Palette.SOMBRA)
	draw_colored_polygon(PackedVector2Array([
		origin + Vector2(0, -16),
		origin + Vector2(3, -12),
		origin + Vector2(0, -8),
		origin + Vector2(-3, -12),
	]), color)
