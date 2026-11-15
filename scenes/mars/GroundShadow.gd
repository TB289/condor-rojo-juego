class_name GroundShadow
extends Node2D
## Flat contact oval. Sits on the entity origin (the feet) and draws behind the sprite.
## One pixel up so it sorts behind the boots. Turn them all off from SurfaceLook.

const COLOR := Color("8a3058")

static var enabled := true

@export var radius := Vector2(8, 3)
@export var alpha := 0.4

var _was_visible := true


static func attach(parent: Node2D, radius: Vector2, alpha: float = 0.4) -> GroundShadow:
	var shadow := GroundShadow.new()
	shadow.name = "GroundShadow"
	shadow.radius = radius
	shadow.alpha = alpha
	parent.add_child(shadow)
	parent.move_child(shadow, 0)
	return shadow


func _ready() -> void:
	# Same Z as the sprite so the oval stays above the ground. Tree order draws it first,
	# and the sprite covers the part that would sit on the boots.
	position = Vector2(2, 1)
	z_index = 0
	z_as_relative = true
	show_behind_parent = true
	_was_visible = _should_show()
	visible = _was_visible
	queue_redraw()


func _process(_delta: float) -> void:
	var show := _should_show()
	if show == _was_visible:
		return
	_was_visible = show
	visible = show
	if show:
		queue_redraw()


func _should_show() -> bool:
	# Indoors the floor is busy enough. The ovals stay outside.
	return enabled and GameState.interior_id == &""


func _draw() -> void:
	var rx := maxi(int(round(radius.x)), 2)
	var ry := maxi(int(round(radius.y)), 1)
	for y in range(-ry, ry + 1):
		var ny := float(y) / float(ry)
		var span := sqrt(maxf(1.0 - ny * ny, 0.0))
		var hx := maxi(int(round(float(rx) * span)), 1)
		var row := alpha * (0.35 + 0.65 * (1.0 - absf(ny)))
		draw_rect(Rect2(-hx, y, hx * 2, 1), Color(COLOR, row))
