extends Control
## Oxygen, energy and radiation shielding hug the minimap. Indoors, the same three sit in that corner.
## A tap still opens the data capsule for that resource. Water stays hidden.

const LOW := 0.25
const PAD := 16.0
const BAND := 5.0
const ICON := 12.0
const IDS: Array[StringName] = [&"oxygen", &"energy", &"shielding"]
const COLORS: Array[Color] = [Palette.INTI, Palette.ORO, Palette.OK]
## Clockwise from the right. Energy wraps past 0 so it stays on the right side.
const STARTS: Array[float] = [3.55, 5.40, 1.20]
const ENDS: Array[float] = [5.15, 0.95, 2.90]

const ICONS: Array[Texture2D] = [
	preload("res://assets/art/ui/icon_oxygen.png"),
	preload("res://assets/art/ui/icon_energy.png"),
	preload("res://assets/art/ui/icon_shielding.png"),
]

var _around := true


func _ready() -> void:
	name = "ResourceRing"
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_delta: float) -> void:
	var map := get_parent().get_node_or_null("Minimap") as Control
	if map != null and map.visible:
		_around = true
		position = map.position - Vector2(PAD, PAD)
		size = map.size + Vector2(PAD * 2.0, PAD * 2.0)
	else:
		_around = false
		var view := get_viewport_rect().size
		size = Vector2(84, 54)
		position = Vector2(view.x - 6.0 - size.x, view.y - 6.0 - size.y)
	queue_redraw()


func covers_resource(global_point: Vector2) -> bool:
	var local := get_global_transform().affine_inverse() * global_point
	return _segment_at(local) >= 0

func resource_rect(id: StringName) -> Rect2:
	var index := IDS.find(id)
	if index < 0:
		return Rect2()
	if not _around:
		var row_h := size.y / float(IDS.size())
		return Rect2(global_position + Vector2(0.0, float(index) * row_h), Vector2(size.x, row_h)).grow(4.0)
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - PAD + 2.0
	var start := STARTS[index]
	var finish := ENDS[index]
	var mid := _mid(start, finish)
	var icon_at := center + Vector2.from_angle(mid) * (radius + BAND + 2.0) - Vector2(ICON, ICON) * 0.5
	var arc_a := center + Vector2.from_angle(start) * (radius + BAND * 0.5)
	var arc_b := center + Vector2.from_angle(finish) * (radius + BAND * 0.5)
	var arc_mid := center + Vector2.from_angle(mid) * (radius + BAND * 0.5)
	var local_rect := Rect2(icon_at, Vector2(ICON, ICON))
	local_rect = local_rect.expand(arc_a)
	local_rect = local_rect.expand(arc_b)
	local_rect = local_rect.expand(arc_mid)
	return Rect2(global_position + local_rect.position, local_rect.size).grow(8.0)


func _has_point(point: Vector2) -> bool:
	return _segment_at(point) >= 0


func _gui_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	var pressed := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		point = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pressed = true
		point = (event as InputEventScreenTouch).position
	if not pressed:
		return
	var index := _segment_at(point)
	if index < 0:
		return
	accept_event()
	_open(index)


func _draw() -> void:
	if _around:
		_draw_arcs()
	else:
		_draw_bars()


func _draw_arcs() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - PAD + 2.0
	for i in IDS.size():
		var ratio := _ratio(IDS[i])
		var color := _live_color(COLORS[i], ratio, IDS[i] == &"energy")
		var start := STARTS[i]
		var finish := ENDS[i]
		_arc(center, radius, start, finish, Palette.CONTORNO, BAND + 2.0)
		_arc(center, radius, start, finish, Palette.NAVY, BAND)
		_arc(center, radius, start, _fill_end(start, finish, maxf(ratio, 0.04)), color, BAND)
		var mid := _mid(start, finish)
		var at := center + Vector2.from_angle(mid) * (radius + BAND + 2.0) - Vector2(ICON, ICON) * 0.5
		var box := Rect2(at, Vector2(ICON, ICON))
		if ratio < LOW:
			draw_rect(box.grow(1.0), Palette.PELIGRO)
		draw_texture_rect(ICONS[i], box, false)


func _draw_bars() -> void:
	var row_h := size.y / float(IDS.size())
	for i in IDS.size():
		var ratio := _ratio(IDS[i])
		var color := _live_color(COLORS[i], ratio, IDS[i] == &"energy")
		var y := i * row_h
		var box := Rect2(1, y + (row_h - ICON) * 0.5, ICON, ICON)
		if ratio < LOW:
			draw_rect(box.grow(1.0), Palette.PELIGRO)
		draw_texture_rect(ICONS[i], box, false)
		var track := Rect2(ICON + 4.0, y + row_h * 0.5 - 3.0, size.x - ICON - 6.0, 6.0)
		draw_rect(track, Palette.NAVY)
		draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(ratio, 0.0, 1.0), track.size.y)), color)
		draw_rect(track, Palette.CONTORNO, false, 1.0)


func _arc(center: Vector2, radius: float, start: float, finish: float, color: Color, width: float) -> void:
	var end := finish
	if end < start:
		end += TAU
	var points := maxi(int((end - start) * 8.0), 8)
	draw_arc(center, radius, start, end, points, color, width, false)


func _segment_at(point: Vector2) -> int:
	if size.x < 1.0 or size.y < 1.0:
		return -1
	if not _around:
		if point.x < 0.0 or point.y < 0.0 or point.x > size.x or point.y > size.y:
			return -1
		return clampi(int(point.y / (size.y / float(IDS.size()))), 0, IDS.size() - 1)
	var center := size * 0.5
	var delta := point - center
	var dist := delta.length()
	var radius := minf(size.x, size.y) * 0.5 - PAD + 2.0
	var ang := fposmod(delta.angle(), TAU)
	if dist >= radius - BAND and dist <= radius + BAND + ICON + 4.0:
		for i in IDS.size():
			if _angle_in(ang, STARTS[i], ENDS[i]):
				return i
	for i in IDS.size():
		var mid := _mid(STARTS[i], ENDS[i])
		var at := center + Vector2.from_angle(mid) * (radius + BAND + 2.0)
		if point.distance_to(at) <= ICON:
			return i
	return -1


func _angle_in(ang: float, start: float, finish: float) -> bool:
	var a := fposmod(start, TAU)
	var b := fposmod(finish, TAU)
	if a <= b:
		return ang >= a and ang <= b
	return ang >= a or ang <= b


func _mid(start: float, finish: float) -> float:
	var a := fposmod(start, TAU)
	var b := fposmod(finish, TAU)
	if b < a:
		b += TAU
	return fposmod((a + b) * 0.5, TAU)


func _fill_end(start: float, finish: float, ratio: float) -> float:
	var end := finish
	if end < start:
		end += TAU
	return start + (end - start) * clampf(ratio, 0.0, 1.0)


func _ratio(id: StringName) -> float:
	if id == &"shielding":
		return clampf(NasaData.radiation_shielding() / 100.0, 0.0, 1.0)
	var max_value := maxf(ResourceSystem.get_max(id), 0.001)
	return clampf(ResourceSystem.get_value(id) / max_value, 0.0, 1.0)


func _live_color(base: Color, ratio: float, sprint: bool) -> Color:
	if ratio < LOW:
		var pulse: float = 0.62 + 0.38 * absf(sin(float(Time.get_ticks_msec()) / 180.0))
		var danger := Palette.PELIGRO
		danger.a = pulse
		return danger
	if sprint and _sprinting():
		return base.lerp(Palette.CREMA, 0.45)
	return base


func _sprinting() -> bool:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	return player != null and player.is_sprinting


func _open(index: int) -> void:
	match IDS[index]:
		&"oxygen":
			NasaData.show_manual("air")
		&"energy":
			NasaData.show_manual(NasaData.energy_capsule())
		&"shielding":
			NasaData.show_manual("shield_gcr")
