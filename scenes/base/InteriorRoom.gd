class_name InteriorRoom
extends Node2D
## One screen inside a base module. Tiles are 16x16, painted from the game palette at runtime.
## The player, props and the exit door live on Entities so they Y-sort. Walls block the border.

const TILE := 16
const SIZE := Vector2i(20, 8)
const CAVE_SIZE := Vector2i(64, 36) # 2304 cells: one third of Isidis Planitia
const SPAWN := Vector2(160, 88)
const EXIT_AT := Vector2(160, 104)
## Shared interior zoom. 2.5 fits tighter, but on the 640-wide viewport each texel
## became 2 or 3 pixels and looked uneven. 2x stays sharp and still shows the room.
const CAMERA_ZOOM := Vector2(2, 2)
const TEX_SOJOURNER := preload("res://assets/art/rovers/sojourner.png")
const TEX_CAVE_SHEET := preload("res://assets/art/base/volcanic_cave_sheet.png")
const TEX_ROOM_BG := preload("res://assets/art/base/interior_room_bg.png")
const TEX_PLANT_POT := preload("res://assets/art/base/interior_plantpot.png")
const FONT_UI := preload("res://assets/fonts/m5x7.ttf")

@export var room_id: StringName = &"habitat"
## The room is one screen. The camera stays put so the walls fill the view.
var lock_camera: bool = true
var room_size: Vector2i = SIZE

var entities: Node2D
var camera: CameraRig
var spawn_position: Vector2 = SPAWN

var _walls: StaticBody2D


func _ready() -> void:
	room_size = CAVE_SIZE if room_id == &"cave" else SIZE
	lock_camera = room_id != &"cave"
	spawn_position = Vector2(room_size.x * TILE * 0.5, room_size.y * TILE - 96.0) if room_id == &"cave" else SPAWN
	_add_backdrop()
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.tile_set = _make_tileset()
	add_child(ground)
	_paint(ground)
	if room_id != &"cave":
		_add_room_art()
	_add_walls()
	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	entities.z_index = 1
	add_child(entities)
	_add_props()
	if room_id == &"habitat" or room_id == &"cave":
		var door := BuildingDoor.new()
		door.mode = BuildingDoor.Mode.EXIT
		# A cave exit is a terrain teleport, NOT a painted ship door.
		door.cave_mouth = room_id == &"cave"
		door.position = Vector2(room_size.x * TILE * 0.5, room_size.y * TILE - 24.0) if room_id == &"cave" else EXIT_AT
		entities.add_child(door)
	if room_id != &"cave":
		_add_ship_passages()
	camera = CameraRig.new()
	camera.name = "CameraRig"
	camera.enabled = false
	camera.zoom = CAMERA_ZOOM
	camera.position_smoothing_enabled = false
	camera.position = view_center()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)


func _add_ship_passages() -> void:
	if room_id == &"habitat":
		# Wider main room so the interior uses the full viewport.
		_passage(&"lab", Vector2(304, 64))
		if GameState.start_modules.has(&"greenhouse"):
			_passage(&"greenhouse", Vector2(16, 64))
	elif room_id == &"greenhouse":
		_passage(&"habitat", Vector2(304, 64))
	else:
		_passage(&"habitat", Vector2(16, 64))


func _passage(to: StringName, at: Vector2) -> void:
	var passage := ShipPassage.new()
	passage.name = "PassageTo_" + String(to)
	passage.destination = to
	passage.position = at
	entities.add_child(passage)


func view_center() -> Vector2:
	return Vector2(room_size * TILE) * 0.5


func _add_backdrop() -> void:
	var pad := 48.0
	var size := Vector2(room_size * TILE)
	var backdrop := Polygon2D.new()
	backdrop.color = Color("1a0c14")
	backdrop.z_index = -10
	backdrop.polygon = PackedVector2Array([
		Vector2(-pad, -pad),
		Vector2(size.x + pad, -pad),
		Vector2(size.x + pad, size.y + pad),
		Vector2(-pad, size.y + pad),
	])
	add_child(backdrop)


func _add_room_art() -> void:
	var bg := Sprite2D.new()
	bg.texture = TEX_ROOM_BG
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.centered = false
	bg.position = Vector2.ZERO
	bg.z_index = 0
	add_child(bg)


func _add_walls() -> void:
	_walls = StaticBody2D.new()
	_walls.name = "Walls"
	add_child(_walls)
	var w := float(room_size.x * TILE)
	var h := float(room_size.y * TILE)
	var t := 16.0
	# The exit is painted on the south wall, but it stays solid. E is the only way out.
	# Side walls run the full height so the corners have no seam.
	_add_wall(Rect2(0, 0, w, t))
	_add_wall(Rect2(0, h - t, w, t))
	_add_wall(Rect2(0, 0, t, h))
	_add_wall(Rect2(w - t, 0, t, h))


func _add_wall(rect: Rect2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = rect.position + rect.size * 0.5
	_walls.add_child(collision)


func _add_props() -> void:
	if room_id == &"cave":
		# Visible wheel impressions hint at where the rover travelled in the dark.
		var tracks := CaveTracks.new()
		tracks.name = "SojournerWheelTracks"
		entities.add_child(tracks)
		# Large lava tube: keep the central exploration corridor clear. Sojourner's
		# archive lies beyond the geologic scan, far from the entrance.
		_prop(InteriorProp.Kind.STRIAE, Vector2(480, 300), &"cave_scan")
		for at in [Vector2(115, 110), Vector2(305, 155), Vector2(815, 130), Vector2(894, 335), Vector2(205, 380), Vector2(730, 435)]:
			_prop(InteriorProp.Kind.STRIAE, at, &"")
		_add_cave_decor()
		_add_cave_rover(Vector2(760, 205))
		_add_cave_exit_marker()
		# Low reflected minerals: cave remains pitch-black beyond the flashlight.
		WarmLight.attach(entities, Vector2(480, 300), Color("ff8a58"), 0.7, 0.01, 0.10, Color("c47848"), false)
		WarmLight.attach(entities, Vector2(760, 205), Color("b8f4ff"), 0.65, 0.01, 0.10, Color("7a8c9a"), false)
		return
	if room_id == &"lab":
		_prop(InteriorProp.Kind.SHELF, Vector2(58, 46), &"")
		_prop(InteriorProp.Kind.CONSOLE, Vector2(140, 42), &"")
		_prop(InteriorProp.Kind.CENTRIFUGE, Vector2(248, 44), &"")
		_prop(InteriorProp.Kind.ROBOT_ARM, Vector2(198, 78), &"")
		_prop(InteriorProp.Kind.TANK, Vector2(270, 84), &"")
		_lamp(Vector2(72, 22), Color("3ed4e8"))
		_lamp(Vector2(160, 20), Color("b8f4ff"))
		_lamp(Vector2(248, 22), Color("ffe000"))
		return
	if room_id == &"greenhouse":
		_prop(InteriorProp.Kind.PLANTS, Vector2(70, 44), &"", 0)
		_prop(InteriorProp.Kind.PLANTS, Vector2(158, 44), &"greenhouse_bed", 1)
		_prop(InteriorProp.Kind.PLANTS, Vector2(246, 44), &"", 1)
		_prop(InteriorProp.Kind.TANK, Vector2(254, 78), &"")
		_lamp(Vector2(118, 22), Color("8ce846"))
		_lamp(Vector2(214, 22), Color("b4f86a"))
		return
	_prop(InteriorProp.Kind.BUNK, Vector2(68, 68), &"")
	_prop(InteriorProp.Kind.CONSOLE, Vector2(160, 40), &"habitat_console")
	_prop(InteriorProp.Kind.CRATE, Vector2(244, 47), &"habitat_supplies")
	# Oxygen refill is a functional station INSIDE the habitat, not on the surface.
	var oxygen := OxygenTank.new()
	oxygen.name = "HabitatOxygenStation"
	oxygen.position = Vector2(256, 84)
	entities.add_child(oxygen)
	_lamp(Vector2(102, 24), Color("ffe000"))
	_lamp(Vector2(214, 24), Color("3ed4e8"))
	var plant := Sprite2D.new()
	plant.texture = TEX_PLANT_POT
	plant.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plant.offset = Vector2(0, -TEX_PLANT_POT.get_height() / 2.0)
	plant.position = Vector2(214, 86)
	entities.add_child(plant)


func _prop(kind: InteriorProp.Kind, at: Vector2, target: StringName, stage: int = 1) -> void:
	var prop := InteriorProp.new()
	prop.kind = kind
	prop.target_id = target
	prop.stage = stage
	prop.position = at
	entities.add_child(prop)




func _add_cave_exit_marker() -> void:
	var exit_at := Vector2(room_size.x * TILE * 0.5, room_size.y * TILE - 34.0)
	var marker := Node2D.new()
	marker.name = "CaveExitMarker"
	marker.position = exit_at
	entities.add_child(marker)

	var outer := Polygon2D.new()
	outer.color = Color("4a2023")
	outer.polygon = _ellipse_points(30.0, 12.0, 16)
	marker.add_child(outer)

	var ring := Polygon2D.new()
	ring.color = Color(0.72, 0.96, 1.0, 0.22)
	ring.polygon = _ellipse_points(22.0, 8.0, 16)
	marker.add_child(ring)

	var arrow := Polygon2D.new()
	arrow.color = Color("b8f4ff")
	arrow.polygon = PackedVector2Array([
		Vector2(0, -14),
		Vector2(10, -2),
		Vector2(4, -2),
		Vector2(4, 9),
		Vector2(-4, 9),
		Vector2(-4, -2),
		Vector2(-10, -2),
	])
	marker.add_child(arrow)

	var lamp := StatusLamp.new()
	lamp.position = Vector2(0, -18)
	lamp.lamp_color = Color("3ed4e8")
	lamp.blink_hz = 1.4
	marker.add_child(lamp)

	WarmLight.attach(entities, exit_at + Vector2(0, -6), Color("74dfff"), 0.9, 0.06, 0.18, Color("b8f4ff"), false)

	var label := Label.new()
	label.text = "EXIT"
	label.position = Vector2(-16, -34)
	label.add_theme_font_override("font", FONT_UI)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("fffce8"))
	label.add_theme_color_override("font_shadow_color", Color("1a0c14"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	marker.add_child(label)

func _add_cave_rover(at: Vector2) -> void:
	var rover := Node2D.new()
	rover.name = "SojournerCave"
	rover.position = at
	var sprite := Sprite2D.new()
	sprite.texture = TEX_SOJOURNER
	sprite.offset = Vector2(0, -TEX_SOJOURNER.get_height() / 2.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rover.add_child(sprite)
	var area := MissionArea.new()
	area.name = "Target_rover_sojourner"
	area.target_id = &"rover_sojourner"
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitorable = false
	var shape := CircleShape2D.new()
	shape.radius = 34.0
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, 4)
	area.add_child(col)
	rover.add_child(area)
	entities.add_child(rover)


func _add_cave_decor() -> void:
	# Natural props from the volcanic cave sprite sheet give Jezero's cave more context
	# without blocking the main exploration corridor or the exit.
	_cave_piece(Rect2(36, 32, 170, 153), Vector2(18, 10), 0.42, false, -1)
	_cave_piece(Rect2(212, 32, 97, 153), Vector2(190, 8), 0.40, false, -1)
	_cave_piece(Rect2(426, 32, 92, 144), Vector2(300, 8), 0.42, false, -1)
	_cave_piece(Rect2(552, 32, 166, 128), Vector2(410, 14), 0.42, false, -1)
	_cave_piece(Rect2(36, 32, 170, 153), Vector2(720, 14), 0.38, false, -1)
	_cave_piece(Rect2(212, 32, 97, 153), Vector2(888, 10), 0.38, false, -1)
	_cave_piece(Rect2(730, 32, 424, 233), Vector2(622, 122), 0.35, true, -1)
	_cave_piece(Rect2(32, 467, 191, 137), Vector2(420, 274), 0.46, true, 0)
	_cave_piece(Rect2(471, 473, 174, 131), Vector2(808, 160), 0.42, true, 0)
	_cave_piece(Rect2(796, 345, 164, 82), Vector2(540, 334), 0.50, true, 0)
	_cave_piece(Rect2(1006, 359, 124, 68), Vector2(252, 302), 0.55, true, 0)
	_cave_piece(Rect2(1067, 800, 124, 160), Vector2(902, 432), 0.38, true, 0)
	_cave_piece(Rect2(1254, 790, 259, 170), Vector2(706, 458), 0.32, true, 0)


func _cave_piece(region: Rect2, at: Vector2, scale_amount: float, centered: bool, z: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = TEX_CAVE_SHEET
	atlas.region = region
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = at
	sprite.scale = Vector2.ONE * scale_amount
	sprite.centered = centered
	sprite.z_index = z
	sprite.self_modulate = Color(1.0, 1.0, 1.0, 0.96)
	entities.add_child(sprite)




func _ellipse_points(rx: float, ry: float, segments: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _lamp(at: Vector2, color: Color) -> void:
	var lamp := StatusLamp.new()
	lamp.position = at
	lamp.lamp_color = color
	lamp.blink_hz = 1.3
	entities.add_child(lamp)
	var warm := room_id == &"habitat"
	WarmLight.attach(entities, at, color, 1.35, 0.55, 1.0, color.lightened(0.15) if warm else color, warm)


func _paint(ground: TileMapLayer) -> void:
	for y in room_size.y:
		for x in room_size.x:
			var cell := Vector2i(x, y)
			var atlas := _floor_atlas(cell)
			if _is_border(cell):
				if _is_door(cell):
					var mid := room_size.x / 2
					atlas = Vector2i(6, 0) if cell.x >= mid else Vector2i(4, 0)
				elif _is_window(cell):
					atlas = Vector2i(3, 0)
				else:
					atlas = Vector2i(2, 0)
			elif _is_soil(cell):
				atlas = Vector2i(5, 0)
			ground.set_cell(cell, 0, atlas)


func _floor_atlas(cell: Vector2i) -> Vector2i:
	if room_id == &"habitat" and cell.x >= 7 and cell.x <= 12 and cell.y >= 3 and cell.y <= 5:
		return Vector2i(7, 0)
	return Vector2i(1, 0) if (cell.x + cell.y) % 2 == 0 else Vector2i(0, 0)


func _is_border(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == room_size.x - 1 or cell.y == room_size.y - 1


func _is_door(cell: Vector2i) -> bool:
	# Only the habitat paints a literal door into the south wall. The cave exit is an
	# invisible teleport hotspot triggered with E, so its floor should stay natural.
	if room_id != &"habitat":
		return false
	var mid := room_size.x / 2
	return cell.y == room_size.y - 1 and (cell.x == mid - 1 or cell.x == mid)


func _is_window(cell: Vector2i) -> bool:
	if cell.y != 0:
		return false
	if room_id == &"cave":
		var mid := room_size.x / 2
		return cell.x == mid - 1 or cell.x == mid
	if room_id == &"greenhouse":
		return cell.x >= 2 and cell.x <= SIZE.x - 3
	return cell.x >= 5 and cell.x <= SIZE.x - 6


func _is_soil(cell: Vector2i) -> bool:
	if room_id != &"greenhouse":
		return false
	var in_top := cell.y >= 1 and cell.y <= 2 and cell.x >= 2 and cell.x <= SIZE.x - 3
	var in_left := cell.y >= 4 and cell.y <= 5 and cell.x >= 2 and cell.x <= 7
	var in_right := cell.y >= 4 and cell.y <= 5 and cell.x >= SIZE.x - 8 and cell.x <= SIZE.x - 3
	return in_top or in_left or in_right


func _make_tileset() -> TileSet:
	var image := Image.create(TILE * 8, TILE, false, Image.FORMAT_RGBA8)
	for index in 8:
		_paint_tile(image, index)
	var texture := ImageTexture.create_from_image(image)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	tile_set.add_source(source, 0)
	for index in 8:
		source.create_tile(Vector2i(index, 0))
	return tile_set


func _paint_tile(image: Image, index: int) -> void:
	var origin := Vector2i(index * TILE, 0)
	for y in TILE:
		for x in TILE:
			image.set_pixel(origin.x + x, origin.y + y, _pixel(index, x, y))


func _pixel(index: int, x: int, y: int) -> Color:
	match index:
		0, 1:
			return _floor_pixel(index == 1, x, y)
		2:
			return _wall_pixel(x, y)
		3:
			return _window_pixel(x, y)
		4:
			return _door_pixel(x, y, false)
		5:
			return _soil_pixel(x, y)
		6:
			return _door_pixel(x, y, true)
		_:
			return _mat_pixel(x, y)


func _floor_pixel(alt: bool, x: int, y: int) -> Color:
	if room_id == &"cave":
		return _cave_floor_pixel(alt, x, y)
	if room_id == &"lab":
		if (x * 3 + y * 7 + (3 if alt else 0)) % 13 == 0:
			return Color("3ed4e8")
		return Color("43546a") if alt else Color("697d8b")
	var salt := 3 if alt else 0
	if (x * 3 + y * 7 + salt) % 11 == 0:
		return Color("f0f4f8")
	if (x * 5 + y * 2 + salt) % 13 == 0:
		return Color("3a4854")
	return Color("7a8c9a")


func _wall_pixel(x: int, y: int) -> Color:
	if room_id == &"cave":
		if y > 12 or x + y > 26:
			return Color("1a0c14")
		if x < 2 or y < 2:
			return Color("8a2e14")
		return Color("3a1a28")
	if x + y < 4:
		return Color("7a8c9a")
	if x + y > 24:
		return Color("1a0c14")
	if x < 2:
		return Color("7a8c9a")
	return Color("3a4854")


func _window_pixel(x: int, y: int) -> Color:
	if room_id == &"cave":
		if x < 2 or x > 13:
			return Color("8a2e14")
		if y < 5:
			return Color("ffc0a8") if (x + y) % 3 == 0 else Color("ff8a58")
		if y < 9:
			return Color("5a2468")
		return Color("1a0c14")
	if y < 2:
		return Color("f0f4f8") if x > 1 else Color("7a8c9a")
	if y > 13:
		return Color("3a4854")
	if x == 0 or x == 15:
		return Color("3a1a28")
	if y < 7:
		return Color("ff8a58") if y < 4 else Color("ffc0a8")
	if y > 11:
		return Color("8a2e14")
	if (x + y) % 5 == 0:
		return Color("c24a1c")
	return Color("e8893a")


func _door_pixel(x: int, y: int, right: bool) -> Color:
	if room_id == &"cave":
		var rim := x > 12 if right else x < 3
		if rim:
			return Color("8a2e14")
		if y > 11:
			return Color("d4a05a")
		if y < 3:
			return Color("3a1a28")
		return Color("1a0c14")
	var outer := x > 12 if right else x < 3
	var seam := x < 2 if right else x > 13
	var handle := x < 5 if right else x > 10
	if y < 2:
		return Color("f0f4f8")
	if y > 13:
		return Color("ff6a20")
	if outer:
		return Color("7a8c9a")
	if seam:
		return Color("1a0c14")
	if handle and y > 6 and y < 10:
		return Color("ff6a20")
	if not right and x < 7 and y < 6:
		return Color("fffce8")
	return Color("b8b0a4") if right else Color("f0f4f8")


func _soil_pixel(x: int, y: int) -> Color:
	if y > 3 and y < 12 and (x == 4 or x == 5 or x == 10 or x == 11):
		if y < 7:
			return Color("b4f86a")
		return Color("8ce846")
	if y > 6 and y < 10 and (x == 6 or x == 9):
		return Color("2e8a28")
	if x + y < 5:
		return Color("c47848")
	if x > 12 and y > 12:
		return Color("8a2e14")
	return Color("a84828")


func _cave_floor_pixel(alt: bool, x: int, y: int) -> Color:
	var salt := 4 if alt else 0
	if (x * 3 + y * 5 + salt) % 11 == 0:
		return Color("8a2e14")
	if (x + y * 2 + salt) % 9 == 0:
		return Color("5a2468")
	if x > 12 and y > 11:
		return Color("1a0c14")
	return Color("3a1a28") if alt else Color("1a0c14")


func _mat_pixel(x: int, y: int) -> Color:
	if (x * 2 + y) % 5 == 0:
		return Color("f6c878")
	if x > 12 and y > 11:
		return Color("a84828")
	return Color("d4a05a")
