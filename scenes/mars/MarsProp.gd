class_name MarsProp
extends StaticBody2D
## Rock, dune or landmark. Origin at the base so Y-sort on Entities matches the feet.
## texture_override uses a PixelLab prop. Without it, the sprite is a frame of mars_props_32.png.

enum Kind { CRATER, ROCK_MEDIUM, ROCK_LARGE }

const FRAME_SIZE := 32
const FOOTPRINTS := {
	Kind.CRATER: Rect2(-12, -15, 24, 12),
	Kind.ROCK_MEDIUM: Rect2(-9, -7, 18, 6),
	Kind.ROCK_LARGE: Rect2(-12, -6, 24, 7),
}

@export var kind: Kind = Kind.ROCK_MEDIUM
@export var texture_override: Texture2D
## Footprint in world pixels, top-left relative to the origin. Used with texture_override.
@export var footprint: Rect2 = Rect2(-8, -5, 16, 6)
@export var solid: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	if texture_override != null:
		_seat(texture_override)
		_apply_hitbox(footprint, solid)
	else:
		sprite.region_enabled = true
		sprite.region_rect = Rect2(int(kind) * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		sprite.offset = Vector2(0, -14)
		_apply_hitbox(FOOTPRINTS[kind], true)
	var width := 10.0
	if solid and footprint.size.x > 1.0 and texture_override != null:
		width = maxf(footprint.size.x * 0.42, 6.0)
	elif kind == Kind.CRATER:
		width = 14.0
	elif kind == Kind.ROCK_LARGE:
		width = 12.0
	GroundShadow.attach(self, Vector2(width, 3.2))


func _seat(tex: Texture2D) -> void:
	sprite.region_enabled = false
	sprite.texture = tex
	var h := tex.get_height()
	var bottom := h - 1
	var image := tex.get_image()
	if image != null and not image.is_empty():
		var found := false
		for y in range(image.get_height() - 1, -1, -1):
			for x in image.get_width():
				if image.get_pixel(x, y).a > 0.1:
					bottom = y
					found = true
					break
			if found:
				break
		h = image.get_height()
	# Bottom of the opaque pixels sits on the node origin.
	sprite.offset = Vector2(0, float(h) * 0.5 - float(bottom + 1))


func _apply_hitbox(box: Rect2, blocks: bool) -> void:
	if not blocks or box.size.x < 1.0 or box.size.y < 1.0:
		collision.disabled = true
		collision_layer = 0
		collision_mask = 0
		return
	var shape := RectangleShape2D.new()
	shape.size = box.size
	collision.shape = shape
	collision.position = box.position + box.size * 0.5
	collision.disabled = false
