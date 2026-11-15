class_name ParticleSnow
extends CanvasLayer
## Faint white specks while a solar-particle window is open.
## Curiosity's camera saw the same kind of "snow" in 2024 (PIA26302). It stays off the HUD.

const COUNT := 18

var _dots: Array[Vector2] = []
var _seeds: Array[float] = []
var active := false
var _rect: ColorRect


func _ready() -> void:
	layer = 4
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color(0, 0, 0, 0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.draw.connect(_draw_dots)
	add_child(_rect)
	for i in COUNT:
		_dots.append(Vector2(randf() * 640.0, randf() * 360.0))
		_seeds.append(randf() * TAU)


func _process(delta: float) -> void:
	var show := active and not Settings.reduce_effects and not get_tree().paused
	_rect.visible = show
	if not show:
		return
	for i in _dots.size():
		var dot := _dots[i]
		dot.y += delta * (6.0 + _seeds[i])
		dot.x += sin(_seeds[i] + Time.get_ticks_msec() * 0.001) * delta * 4.0
		if dot.y > 360.0:
			dot.y = -2.0
			dot.x = randf() * 640.0
		_dots[i] = dot
	_rect.queue_redraw()


func _draw_dots() -> void:
	for dot in _dots:
		_rect.draw_rect(Rect2(dot, Vector2(1, 1)), Color(1, 1, 1, 0.45))
