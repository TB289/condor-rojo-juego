class_name DustVeil
extends Node2D
## Slow dark patches crossing the ground. Separate from DustDrift, which is a small orange gust.
## Multiply blend, low strength, with a gap between passes so they feel occasional.

@export var enabled := true

var _t := 0.0


func _ready() -> void:
	z_index = 8
	z_as_relative = true
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	material = mat


func _process(delta: float) -> void:
	var show: bool = enabled and GameState.interior_id == &"" and not Cutscenes.is_playing()
	visible = show
	if not show:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var map := get_parent() as MarsMap
	if map == null:
		return
	var rect := Rect2(map.get_map_rect())
	var storm := 1.0
	if GameState.dust_sols_left > 0:
		storm = 1.75
	if WorldEventDirector.is_sandstorm_live():
		var strength := WorldEventDirector.sandstorm_strength()
		storm = maxf(storm, lerpf(1.0, 3.2, strength))
		var live_alpha := lerpf(0.0, 0.46, strength)
		draw_rect(rect, Color(0.84, 0.7, 0.56, live_alpha))
	elif storm > 1.0:
		draw_rect(rect, Color(0.84, 0.7, 0.56, 0.28))
	for i in 3:
		_blob(i, rect, storm)


func _blob(i: int, rect: Rect2, storm: float) -> void:
	var period := 34.0 + float(i) * 8.0
	var u := fposmod((_t + period * float(i) * 0.37) / period, 1.0)
	var presence := smoothstep(0.0, 0.1, u) * (1.0 - smoothstep(0.48, 0.62, u))
	if presence < 0.03:
		return
	var across := clampf(u / 0.62, 0.0, 1.0)
	var x := lerpf(-rect.size.x * 0.2, rect.size.x * 1.15, across)
	var y := rect.size.y * (0.2 + 0.28 * float(i)) + sin(_t * 0.1 + float(i) * 2.1) * 40.0
	var radius := Vector2(160.0 + float(i) * 28.0, 58.0 + float(i) * 12.0)
	var center := Vector2(x, y)
	# Multiply toward a light warm shade. Soft, not a dark disc, and not purple or grey.
	_ellipse(center, radius * 1.4, Color(0.97, 0.9, 0.8, presence * 0.4 * storm))
	_ellipse(center, radius, Color(0.92, 0.78, 0.62, presence * 0.48 * storm))
	_ellipse(center, radius * 0.5, Color(0.86, 0.68, 0.5, presence * 0.35 * storm))


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	var steps := 28
	for i in steps:
		var t := TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(t) * radius.x, sin(t) * radius.y))
	draw_colored_polygon(points, color)
