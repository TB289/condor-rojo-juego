class_name LandDust
extends Node2D
## A short puff when the hop lands. A few 1–2 px specks, palette dust, gone quickly.
## Spawned only outdoors. Nearest, no particle material.

const LIFE := 0.38

var _t := 0.0
var _bits: Array[Dictionary] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var colors: Array[Color] = [Color("c47848"), Color("e8893a"), Color("a84828"), Color("f6c878")]
	for i in 7:
		_bits.append({
			"p": Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-1.0, 1.0)),
			"v": Vector2(rng.randf_range(-28.0, 28.0), rng.randf_range(-14.0, -3.0)),
			"s": rng.randi_range(1, 2),
			"c": colors[i % colors.size()],
		})


func _process(delta: float) -> void:
	_t += delta
	for bit in _bits:
		var vel: Vector2 = bit["v"]
		vel.y += 16.0 * delta
		bit["v"] = vel
		var at: Vector2 = bit["p"]
		bit["p"] = at + vel * delta
	queue_redraw()
	if _t >= LIFE:
		queue_free()


func _draw() -> void:
	var fade := 1.0 - clampf(_t / LIFE, 0.0, 1.0)
	for bit in _bits:
		var c: Color = bit["c"]
		c.a = fade
		var s := float(bit["s"])
		var p: Vector2 = bit["p"]
		draw_rect(Rect2(Vector2(floor(p.x), floor(p.y)), Vector2(s, s)), c)
