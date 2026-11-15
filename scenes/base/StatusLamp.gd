class_name StatusLamp
extends Node2D
## A 4 px blink, or a short bar for a panel that is "on". Drawn, not a light node, so Compatibility stays cheap.

@export var lamp_color: Color = Color("ffe000")
@export var wide: bool = false
@export var blink_hz: float = 2.0

var lit: bool = true

var _time := 0.0


func _ready() -> void:
	# Stay in the parent's Y-sort slot. A higher z_index would draw the blink on top of the player.
	z_index = 0
	z_as_relative = true


func _process(delta: float) -> void:
	if not lit:
		visible = false
		return
	visible = true
	_time += delta
	var on := fmod(_time * blink_hz, 1.0) < 0.62
	modulate.a = 1.0 if on else 0.18
	queue_redraw()


func _draw() -> void:
	if wide:
		draw_rect(Rect2(-14, -1, 28, 3), lamp_color)
		draw_rect(Rect2(-14, -1, 7, 3), Color("fffce8"))
	else:
		draw_rect(Rect2(-2, -2, 4, 4), lamp_color)
		draw_rect(Rect2(-1, -1, 2, 2), Color("fffce8"))
