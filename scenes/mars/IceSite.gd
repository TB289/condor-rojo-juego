class_name IceSite
extends StaticBody2D
## Patch of water ice for find_water_ice. Drawn with palette colors until there is a sprite.
## The world sign says "recoger" while a mission wants it and the player is close.

const OUTLINE := Color("3a1a28")
const ICE_LIGHT := Color("f0f4f8")
const ICE_GLINT := Color("b8f4ff")
const ICE := Color("3ed4e8")
const ICE_SHADE := Color("5a2468")
const TAKEN_TINT := Color(0.8, 0.8, 0.85)

func _ready() -> void:
	GroundShadow.attach(self, Vector2(12, 3))


func sign_top() -> Vector2:
	return to_global(Vector2(0.0, -18.0))


func _process(_delta: float) -> void:
	modulate = TAKEN_TINT if GameState.has_flag(&"has_ice") else Color.WHITE


func _draw() -> void:
	draw_rect(Rect2(-13, -6, 26, 6), OUTLINE)
	draw_rect(Rect2(-12, -5, 24, 4), ICE_GLINT)
	draw_rect(Rect2(-12, -2, 24, 1), ICE)
	_shard([Vector2(-9, -5), Vector2(-6, -13), Vector2(-3, -5)])
	_shard([Vector2(-3, -5), Vector2(1, -18), Vector2(5, -5)])
	_shard([Vector2(4, -5), Vector2(8, -11), Vector2(10, -5)])


## Lit on the left, shaded on the right (light comes from the top-left).
func _shard(points: Array[Vector2]) -> void:
	var base_mid := (points[0] + points[2]) / 2.0
	draw_colored_polygon(PackedVector2Array([points[0], points[1], base_mid]), ICE_LIGHT)
	draw_colored_polygon(PackedVector2Array([base_mid, points[1], points[2]]), ICE)
	draw_line(base_mid + Vector2(1, 0), points[2], ICE_SHADE)
	draw_polyline(PackedVector2Array(points), OUTLINE)
