extends Control
## Outdoor map, bottom-right, round. Drawn by hand so Compatibility does not need
## a second camera. M toggles 80 px and 160 px. Hidden indoors, in cutscenes,
## and while a menu has paused the game. clip_contents only clips a rectangle,
## so the circle is the image mask, the hit test, and the arc.

const SMALL := 80.0
const LARGE := 160.0
## Room for the resource arcs that sit just outside the circle.
const MARGIN := 20.0
const GAP := 8.0
const HINT_LEFT := -168.0
const HINT_RIGHT := 168.0
const HINT_TOP := -72.0
const HINT_BOTTOM := -8.0
## World pixels covered by one minimap pixel. A 16 px tile is 4 px here.
const WORLD_PER_PX := 4.0

const FRAME := Color("3a1a28")
const VOID := Color("1a0c14")
const SAND := Color("e8893a")
const SAND_B := Color("d4a05a")
const STONE := Color("c47848")
const PATH := Color("f6c878")
const CRATER := Color("8a2e14")
const ROCK := Color("a84828")
const HABITAT := Color("fff8ec")
const GREEN := Color("8ce846")
const LANDER := Color("f0f4f8")
const PLAYER := Color("fffce8")
const NOSE := Color("ff6a20")

const FACE: Dictionary[StringName, Vector2] = {
	&"down": Vector2.DOWN,
	&"up": Vector2.UP,
	&"left": Vector2.LEFT,
	&"right": Vector2.RIGHT,
	&"down_right": Vector2(0.70710678, 0.70710678),
	&"down_left": Vector2(-0.70710678, 0.70710678),
	&"up_right": Vector2(0.70710678, -0.70710678),
	&"up_left": Vector2(-0.70710678, -0.70710678),
}

var _expanded := false
var _image: Image
var _texture: ImageTexture


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"minimap"):
		return
	if get_tree().paused or Cutscenes.is_playing():
		return
	_expanded = not _expanded
	_place()
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var show := _allowed()
	if visible != show:
		visible = show
	if not show:
		_restore_hint()
		return
	_place()
	_paint_terrain()
	queue_redraw()


func _allowed() -> bool:
	if get_tree().paused or GameState.run_over:
		return false
	if GameState.interior_id != &"" or Cutscenes.is_playing():
		return false
	return _player() != null and _map() != null


func _place() -> void:
	var side := LARGE if _expanded else SMALL
	var view := get_viewport_rect().size
	var rect := Rect2(view.x - MARGIN - side, view.y - MARGIN - side, side, side)
	_fit_hint(rect.position.x)
	rect = _avoid(rect)
	var mission := get_parent().get_node_or_null("MissionPanel") as Control
	if mission != null and mission.visible:
		var floor_y := mission.get_global_rect().end.y + GAP
		if rect.position.y < floor_y:
			rect.position.y = floor_y
	rect.position.x = view.x - MARGIN - side
	rect.position.y = clampf(rect.position.y, GAP, view.y - MARGIN - side)
	position = rect.position
	size = Vector2(side, side)


func _draw() -> void:
	if _texture != null:
		draw_texture(_texture, Vector2.ZERO)
	var player := _player()
	if player == null:
		return
	var origin := _origin_for(player)
	_draw_buildings(origin)
	_draw_landmarks(origin)
	_draw_goals(origin)
	_draw_base_arrow(origin, player)
	_draw_player(player)
	var radius := minf(size.x, size.y) * 0.5 - 1.5
	draw_arc(size * 0.5, radius, 0.0, TAU, maxi(int(radius), 28), FRAME, 2.0, false)


func _paint_terrain() -> void:
	var side := int(size.x)
	if side < 8:
		return
	var map := _map()
	var ground := map.ground
	if _image == null or _image.get_width() != side:
		_image = Image.create(side, side, false, Image.FORMAT_RGBA8)
		_texture = ImageTexture.create_from_image(_image)
	_image.fill(VOID)
	var player := _player()
	if player == null:
		return
	var origin := _origin_for(player)
	var view := Vector2(side, side) * WORLD_PER_PX
	var tile := Vector2(ground.tile_set.tile_size)
	var local_a := ground.to_local(origin)
	var local_b := ground.to_local(origin + view)
	var first := ground.local_to_map(local_a)
	var last := ground.local_to_map(local_b)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			var color := _cell_color(ground, cell)
			var corner := ground.to_global(ground.map_to_local(cell) - tile * 0.5)
			var p := (corner - origin) / WORLD_PER_PX
			var rect := Rect2i(int(floor(p.x)), int(floor(p.y)), int(ceil(tile.x / WORLD_PER_PX)) + 1, int(ceil(tile.y / WORLD_PER_PX)) + 1)
			rect = rect.intersection(Rect2i(0, 0, side, side))
			if rect.size.x > 0 and rect.size.y > 0:
				_image.fill_rect(rect, color)
	_punch_circle(side)
	_texture.update(_image)


func _cell_color(ground: TileMapLayer, cell: Vector2i) -> Color:
	var map := _map()
	if map == null or ground.get_cell_source_id(cell) == -1:
		return VOID
	if map.is_path_cell(cell):
		return Color("fff0c0")
	if map.is_lake_cell(cell):
		return Color("7a8c9a")
	match map.biome_at(cell):
		MarsMap.Biome.CAMP:
			return Color("f0b060")
		MarsMap.Biome.REGOLITH:
			return Color("e07030")
		MarsMap.Biome.DUNE:
			return Color("a85a38")
		MarsMap.Biome.BASALT:
			return Color("4a1814")
		MarsMap.Biome.ICE:
			return Color("8fd4e0")
		_:
			return SAND


func _draw_buildings(origin: Vector2) -> void:
	var lander := _map().lander
	if lander != null and _inside(origin, lander.global_position):
		_blip(_to_map(origin, lander.global_position), LANDER, 5, true)
	for module in ResourceSystem.get_modules():
		if module.data == null or not _inside(origin, module.global_position):
			continue
		if module.data.id == &"habitat":
			_dome(_to_map(origin, module.global_position), HABITAT)
		elif module.data.id == &"greenhouse":
			_dome(_to_map(origin, module.global_position), GREEN)


func _draw_landmarks(origin: Vector2) -> void:
	for node in get_tree().get_nodes_in_group(&"map_landmark"):
		if not node is Node2D:
			continue
		var at := (node as Node2D).global_position
		if not _inside(origin, at):
			continue
		var color: Color = node.get_meta(&"blip_color", Color("ffe000"))
		_blip(_to_map(origin, at), color, 3, false)


func _draw_goals(origin: Vector2) -> void:
	var shown := MissionSystem.get_shown()
	var marks: Array[Dictionary] = []
	for id in MissionSystem.get_active():
		var at := MissionSystem.goal_world(id)
		if not at.is_finite() or not _inside(origin, at):
			continue
		marks.append({"id": id, "at": at})
	for mark in marks:
		if mark.id == shown:
			continue
		_goal_blip(_to_map(origin, mark.at), mark.id, false)
	for mark in marks:
		if mark.id != shown:
			continue
		_goal_blip(_to_map(origin, mark.at), mark.id, true)


func _goal_blip(at: Vector2, id: StringName, followed: bool) -> void:
	var main := MissionSystem.get_category(id) == "main"
	var color := Palette.ORO if main else Palette.INTI
	var extent := 5.0 if followed else 3.0
	draw_rect(Rect2(at - Vector2(extent + 1.0, extent + 1.0), Vector2(extent * 2.0 + 2.0, extent * 2.0 + 2.0)), FRAME)
	if main:
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(0, -extent),
			at + Vector2(extent, 0),
			at + Vector2(0, extent),
			at + Vector2(-extent, 0),
		]), color)
	else:
		draw_rect(Rect2(at - Vector2(extent, extent) * 0.5, Vector2(extent, extent)), color)


func _draw_base_arrow(origin: Vector2, player: Player) -> void:
	var lander := _map().lander
	if lander == null:
		return
	var base := lander.global_position
	if _inside(origin, base):
		return
	var delta := base - player.global_position
	if delta.length_squared() < 1.0:
		return
	var reach := _radius() - 8.0
	var tip := size * 0.5 + delta.normalized() * reach
	_arrow(tip, delta, NOSE)


func _draw_player(player: Player) -> void:
	var center := size * 0.5
	var dir := Vector2.DOWN
	if FACE.has(player.facing):
		dir = FACE[player.facing]
	draw_rect(Rect2(center - Vector2(2, 2), Vector2(4, 4)), FRAME)
	draw_rect(Rect2(center - Vector2(1, 1), Vector2(2, 2)), PLAYER)
	_arrow(center + dir * 4.0, dir, NOSE)


func _dome(at: Vector2, color: Color) -> void:
	draw_rect(Rect2(at + Vector2(-3, -1), Vector2(6, 4)), FRAME)
	draw_rect(Rect2(at + Vector2(-2, 0), Vector2(4, 2)), color)
	draw_rect(Rect2(at + Vector2(-2, -3), Vector2(4, 3)), color)


func _blip(at: Vector2, color: Color, extent: int, diamond: bool) -> void:
	draw_rect(Rect2(at - Vector2(extent / 2.0 + 1, extent / 2.0 + 1), Vector2(extent + 2, extent + 2)), FRAME)
	if diamond:
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(0, -extent),
			at + Vector2(extent, 0),
			at + Vector2(0, extent),
			at + Vector2(-extent, 0),
		]), color)
	else:
		draw_rect(Rect2(at - Vector2(extent, extent) * 0.5, Vector2(extent, extent)), color)


func _arrow(at: Vector2, dir: Vector2, color: Color) -> void:
	var n := dir.normalized()
	if n == Vector2.ZERO:
		return
	var side := n.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		at + n * 6.4,
		at - n * 4.2 + side * 4.6,
		at - n * 4.2 - side * 4.6,
	]), FRAME)
	draw_colored_polygon(PackedVector2Array([
		at + n * 5.0,
		at - n * 3.0 + side * 3.5,
		at - n * 3.0 - side * 3.5,
	]), color)


func _radius() -> float:
	return minf(size.x, size.y) * 0.5 - 1.5


func _punch_circle(side: int) -> void:
	var center := (float(side) - 1.0) * 0.5
	var radius := float(side) * 0.5 - 1.0
	var r2 := radius * radius
	var clear := Color(0, 0, 0, 0)
	for y in side:
		var dy := float(y) - center
		var span := r2 - dy * dy
		if span <= 0.0:
			_image.fill_rect(Rect2i(0, y, side, 1), clear)
			continue
		var dx := sqrt(span)
		var x0 := int(ceil(center - dx))
		var x1 := int(floor(center + dx))
		if x0 > 0:
			_image.fill_rect(Rect2i(0, y, x0, 1), clear)
		if x1 + 1 < side:
			_image.fill_rect(Rect2i(x1 + 1, y, side - (x1 + 1), 1), clear)


## Keep 8 px between the circle and the cards that share the bottom of the screen.
func _avoid(rect: Rect2) -> Rect2:
	for blocker in _bottom_blockers():
		var padded := blocker.grow(GAP)
		if rect.intersects(padded):
			rect.position.y = padded.position.y - rect.size.y
	return rect


func _bottom_blockers() -> Array[Rect2]:
	var found: Array[Rect2] = []
	var module_panel := _layer_panel("ModuleInfoPanel")
	if module_panel != null and module_panel.visible:
		found.append(module_panel.get_global_rect())
	return found


func _layer_panel(layer_name: String) -> Control:
	var layer := get_tree().root.find_child(layer_name, true, false)
	if layer == null:
		return null
	return layer.get_node_or_null("Panel") as Control


## The placement hint is centered and 336 px wide. The large map overlaps it.
func _fit_hint(map_left: float) -> void:
	var hint := get_tree().root.find_child("HintPanel", true, false) as Control
	if hint == null:
		return
	var right := hint.get_viewport_rect().size.x * 0.5 + HINT_RIGHT
	var limit := map_left - GAP
	hint.offset_left = HINT_LEFT
	hint.offset_bottom = HINT_BOTTOM
	if not hint.visible or right <= limit:
		hint.offset_top = HINT_TOP
		hint.offset_right = HINT_RIGHT
		return
	hint.offset_right = HINT_RIGHT - (right - limit)
	hint.offset_top = HINT_TOP - 24.0


func _restore_hint() -> void:
	var hint := get_tree().root.find_child("HintPanel", true, false) as Control
	if hint == null:
		return
	hint.offset_left = HINT_LEFT
	hint.offset_top = HINT_TOP
	hint.offset_right = HINT_RIGHT
	hint.offset_bottom = HINT_BOTTOM


func _inside(origin: Vector2, world: Vector2) -> bool:
	var p := (world - origin) / WORLD_PER_PX
	return p.distance_to(size * 0.5) <= _radius() - 3.0


func _to_map(origin: Vector2, world: Vector2) -> Vector2:
	return (world - origin) / WORLD_PER_PX


func _origin_for(player: Player) -> Vector2:
	return player.global_position - size * WORLD_PER_PX * 0.5


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func _map() -> MarsMap:
	return get_tree().get_first_node_in_group(&"mars_map") as MarsMap
