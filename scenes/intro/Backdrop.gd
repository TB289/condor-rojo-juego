extends Node2D
## Flat shapes for the intro backdrops. Colors come from the 32-color palette.

enum Kind { EARTH, EARTH_FAR, MARS_FAR, HILLS, CRATERS }

@export var kind: Kind = Kind.EARTH

const BLUE := Color("1A4CDC")
const GREEN := Color("2E8A28")
const LEAF := Color("8CE846")
const ROCK := Color("C47848")
const YELLOW := Color("FFE000")
const CREAM := Color("FFF8EC")
const RIM := Color("B8F4FF")
const MARS := Color("E8893A")
const TERRA := Color("C24A1C")
const PATCH := Color("A84828")
const OCHER := Color("D4A05A")


func _draw() -> void:
	match kind:
		Kind.EARTH:
			_earth()
		Kind.EARTH_FAR:
			_earth_far()
		Kind.MARS_FAR:
			_mars_far()
		Kind.HILLS:
			_hills()
		Kind.CRATERS:
			_craters()


func _earth() -> void:
	# Big enough that the curve fills the bottom of the 640x360 frame.
	var center := Vector2(320, 750)
	var radius := 520.0
	draw_circle(center, radius, BLUE)
	draw_arc(center, radius + 8.0, PI, TAU, 64, RIM, 5.0, false)
	draw_circle(Vector2(230, 310), 62.0, GREEN)
	draw_circle(Vector2(400, 330), 48.0, LEAF)
	draw_circle(Vector2(258, 250), 3.0, YELLOW)
	draw_circle(Vector2(268, 258), 2.0, YELLOW)
	draw_circle(Vector2(150, 120), 18.0, CREAM)
	draw_circle(Vector2(172, 112), 11.0, CREAM)
	draw_circle(Vector2(470, 96), 16.0, CREAM)


func _earth_far() -> void:
	draw_circle(Vector2.ZERO, 26.0, BLUE)
	draw_circle(Vector2(-8, 4), 12.0, GREEN)
	draw_circle(Vector2(6, 8), 7.0, LEAF)
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 28, RIM, 3.0, false)


func _mars_far() -> void:
	draw_circle(Vector2.ZERO, 22.0, MARS)
	draw_circle(Vector2(7, -5), 7.0, TERRA)
	draw_circle(Vector2(-6, 6), 5.0, PATCH)


func _hills() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 268), Vector2(0, 248), Vector2(70, 226), Vector2(140, 256), Vector2(140, 268),
	]), PATCH)
	draw_colored_polygon(PackedVector2Array([
		Vector2(160, 268), Vector2(210, 232), Vector2(280, 256), Vector2(360, 224), Vector2(430, 258), Vector2(430, 268),
	]), TERRA)
	draw_colored_polygon(PackedVector2Array([
		Vector2(470, 268), Vector2(520, 236), Vector2(580, 250), Vector2(640, 228), Vector2(640, 268),
	]), PATCH)


func _craters() -> void:
	draw_circle(Vector2(78, 304), 11.0, TERRA)
	draw_circle(Vector2(78, 304), 5.0, PATCH)
	draw_circle(Vector2(470, 312), 14.0, OCHER)
	draw_circle(Vector2(470, 312), 6.0, TERRA)
	draw_circle(Vector2(560, 294), 8.0, TERRA)
