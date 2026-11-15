class_name DustMotes
extends Node2D
## A few slow specks over the surface. Not a storm, and not inside the rooms.

@export var enabled := true

var _motes: Array[Dictionary] = []


func _ready() -> void:
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	var colors: Array[Color] = [Color("e8893a"), Color("c47848"), Color("f6c878")]
	for i in 8:
		_motes.append({
			"p": Vector2(rng.randf_range(-200.0, 200.0), rng.randf_range(-120.0, 120.0)),
			"v": Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(5.0, 11.0)),
			"s": 1 if i % 3 else 2,
			"c": colors[i % colors.size()],
		})


func _process(delta: float) -> void:
	var outside := GameState.interior_id == &""
	var busy: bool = Cutscenes.is_playing()
	var show: bool = enabled and outside and not busy
	visible = show
	if not show:
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var center := camera.get_screen_center_position()
	var view := Rect2(center - Vector2(340, 200), Vector2(680, 400))
	var storm_mult := 1.0 + WorldEventDirector.sandstorm_strength() * 2.8
	for mote in _motes:
		mote["p"] = mote["p"] + mote["v"] * delta * storm_mult
		if not view.grow(12.0).has_point(mote["p"]):
			mote["p"] = Vector2(
				randf_range(view.position.x, view.position.x + view.size.x),
				view.position.y - 2.0
			)
	queue_redraw()


func _draw() -> void:
	for mote in _motes:
		var p: Vector2 = mote["p"]
		var s := float(mote["s"])
		var c: Color = mote["c"]
		c.a = 0.28 + WorldEventDirector.sandstorm_strength() * 0.24
		draw_rect(Rect2(Vector2(floor(p.x), floor(p.y)), Vector2(s, s)), c)
