class_name DustDrift
extends Node2D
## A short gust of dust crosses the camera every few seconds. One moving shape, no particles.

var _wait := 1.6
var _t := -1.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO


func _ready() -> void:
	z_index = 20


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	if _t < 0.0:
		_wait -= delta
		if _wait > 0.0:
			return
		var center := camera.get_screen_center_position()
		_from = center + Vector2(-220, randf_range(-50, 30))
		_to = center + Vector2(240, randf_range(-24, 36))
		_t = 0.0
		_wait = randf_range(1.0, 2.2) if WorldEventDirector.is_sandstorm_live() else randf_range(8.0, 14.0)
		global_position = _from
	var strength := WorldEventDirector.sandstorm_strength()
	_t += delta / lerpf(3.2, 1.15, strength)
	global_position = _from.lerp(_to, clampf(_t, 0.0, 1.0))
	queue_redraw()
	if _t >= 1.0:
		_t = -1.0
		queue_redraw()


func _draw() -> void:
	if _t < 0.0 or _t > 1.0:
		return
	var strength := WorldEventDirector.sandstorm_strength()
	var alpha := sin(clampf(_t, 0.0, 1.0) * PI) * lerpf(0.38, 0.77, strength)
	draw_circle(Vector2(-8, 2), 8.0, Color("c47848", alpha))
	draw_circle(Vector2(2, -3), 6.0, Color("e8893a", alpha * 0.85))
	draw_circle(Vector2(11, 1), 4.0, Color("ffc0a8", alpha * 0.7))
