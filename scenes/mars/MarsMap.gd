class_name MarsMap
extends Node2D
## Five biomes around the lander, painted from the PixelLab Wang sheets,
## recolored to the game palette. Same map_seed = same map.
## Paths run from the lander to the ice, to the landmarks, and to the main-mission sites.
## With the lander at (784, 552): Opportunity (1312, 628), Spirit (220, 430),
## cave mouth (584, 152), glacier goal (1000, 200), hematite goal (820, 780),
## olivine goal (700, 800), lakebed (960, 980). Rocks sit a step beside the path.
## IceSite stays at (424, 776). Flag (716, 568) and lander (784, 552) are not moved.
##
## Ground sources (see tools/build_tileset.gd):
##   1 dust→regolith, 2 regolith→basalt, 3 dust→ice, 4 dust→path, 5 dust→dune.
## Not in the project, and not downloaded: packs/tiny-rpg-mountain,
## packs/industrial-mars (no alexwh credit), mars_basalt_to_crater_rim.png.
## mars_dust_to_ice.png has no ice in it (orange blob, yellow edge). The ice
## biome is that sheet remapped to frost colors, plus ice_deposit / crater_rim
## props and the decal sheet. There is still no real ice Wang tile.
## The legacy atlas stays as source 0 and is not used for the ground.
## Decals (assets/art/tiles/mars_decals_16.png) are drawn for this project
## from the same 32-color palette: gravel, ripples, cracks, crater lip, frost.

enum Biome { CAMP, REGOLITH, DUNE, BASALT, ICE }

const SRC_REGOLITH := 1
const SRC_BASALT := 2
const SRC_ICE := 3
const SRC_PATH := 4
const SRC_DUNE := 5

const N := Vector2i(0, -1)
const E := Vector2i(1, 0)
const S := Vector2i(0, 1)
const W := Vector2i(-1, 0)
const NE := Vector2i(1, -1)
const NW := Vector2i(-1, -1)
const SE := Vector2i(1, 1)
const SW := Vector2i(-1, 1)
const EIGHT: Array[Vector2i] = [N, E, S, W, NE, NW, SE, SW]

const PROP_SCENE := preload("res://scenes/mars/MarsProp.tscn")
const ROVER_TEX := preload("res://assets/art/base/rover.png")
const ROVER_SCRIPT := preload("res://scenes/mars/PushRover.gd")
const TEX_ROCK_S := preload("res://assets/art/tiles/pixellab/props/rock_small.png")
const TEX_ROCK_M := preload("res://assets/art/tiles/pixellab/props/rock_medium.png")
const TEX_ROCK_L := preload("res://assets/art/tiles/pixellab/props/rock_large.png")
const TEX_DUNE := preload("res://assets/art/tiles/pixellab/props/dune.png")
const TEX_ICE := preload("res://assets/art/tiles/pixellab/props/ice_deposit.png")
const TEX_RIM := preload("res://assets/art/tiles/pixellab/props/crater_rim.png")
const TEX_SPIRE := preload("res://assets/art/tiles/pixellab/props/spire_rock.png")
const TEX_ANTENNA := preload("res://assets/art/tiles/pixellab/props/antenna_landmark.png")
# Individual rover artwork supplied by the team in sprites.zip.
const TEX_SOJOURNER := preload("res://assets/art/rovers/sojourner.png")
const TEX_SPIRIT := preload("res://assets/art/rovers/spirit.png")
const TEX_OPPORTUNITY := preload("res://assets/art/rovers/opportunity.png")
const TEX_CURIOSITY := preload("res://assets/art/rovers/curiosity.png")
const TEX_PERSEVERANCE := preload("res://assets/art/rovers/perseverance.png")

const FOOT_SMALL := Rect2(-7, -4, 14, 5)
const FOOT_MED := Rect2(-8, -5, 16, 6)
const FOOT_LARGE := Rect2(-14, -6, 28, 7)
const FOOT_DUNE := Rect2(-16, -4, 32, 5)
const FOOT_ICE := Rect2(-8, -4, 16, 5)
const FOOT_RIM := Rect2(-10, -4, 20, 5)
const FOOT_SPIRE := Rect2(-6, -5, 12, 6)
const FOOT_ANTENNA := Rect2(-6, -4, 12, 5)
const FOOT_PROBE := Rect2(-8, -4, 16, 5)
const FOOT_WRECK := Rect2(-16, -6, 32, 7)
const FOOT_ROVER := Rect2(-20, -8, 40, 10)

const ROVER_OFFSET := Vector2(180, 70)
const CAMP_CORE := 8.0
const CAMP_REACH := 11.0
const EDGE_WALL_INSET := 32.0
const EDGE_BAND_TILES := 2
const JEZERO_WIDTH_TILES := 96
const JEZERO_HEIGHT_TILES := 72

@export var map_size := Vector2i(96, 72)
@export var map_seed: int = 2026
@export var noise_frequency: float = 0.04
@export var prop_min_spacing: float = 40.0
@export var path_width: int = 2
## Tiles kept free of obstacles around the player spawn.
@export var clear_radius: int = 5
## Tiles kept free around the lander so the base can be placed.
@export var base_clear_radius: int = 10
## Tiles kept free around the ice site.
@export var ice_clear_radius: int = 5

@onready var ground: TileMapLayer = $Ground
@onready var decals: TileMapLayer = $Decals
@onready var entities: Node2D = $Entities
@onready var player: Node2D = $Entities/Player
@onready var lander: Node2D = $Entities/Lander
@onready var ice_site: Node2D = $Entities/IceSite
@onready var bounds: StaticBody2D = $Bounds
@onready var camera: CameraRig = $CameraRig

var _reserved: Dictionary[Vector2i, bool] = {}
var _path: Dictionary[Vector2i, bool] = {}
var _lake: Dictionary[Vector2i, bool] = {}
var _dressing: Node2D
var _biome := PackedByteArray()
var _prop_spots: Array[Vector2] = []
var _lander_cell := Vector2i.ZERO
var _rover_pos := Vector2.ZERO


func _ready() -> void:
	add_to_group(&"mars_map")
	if ground.tile_set == null or ground.tile_set.get_source_count() < 6:
		push_error("Mars tileset is missing the PixelLab sources. Run tools/build_tileset.gd.")
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	_lander_cell = ground.local_to_map(lander.position)
	var ice_cell := ground.local_to_map(ice_site.position)
	var spawn_cell := ground.local_to_map(player.position)

	var dune_goal := lander.position + Vector2(340, 20)
	var spire_goal := lander.position + Vector2(16, -300)
	var probe_goal := lander.position + Vector2(-300, -70)
	var dune_at := _beside(dune_goal, lander.position)
	var spire_at := _beside(spire_goal, lander.position)
	var probe_at := _beside(probe_goal, lander.position)
	var wreck_at := _clamp_pos(Vector2(1312, 628))
	# The communication mast is integrated into the ship deck.
	var antenna_at := lander.position + Vector2(82, -26)
	var spots := _mission_spots(wreck_at)

	_reserve_area(spawn_cell, clear_radius)
	_reserve_area(_lander_cell, base_clear_radius)
	_reserve_area(ice_cell, ice_clear_radius)
	_reserve_landmarks(dune_at, spire_at, probe_at, wreck_at, antenna_at)
	_reserve_mission_spots(spots)
	_trace_path(spawn_cell, _lander_cell)
	_trace_path(_lander_cell, ice_cell)
	_trace_path(_lander_cell, ground.local_to_map(dune_goal))
	_trace_path(_lander_cell, ground.local_to_map(spire_goal))
	_trace_path(_lander_cell, ground.local_to_map(probe_goal))
	_trace_mission_paths(spots)
	# The old north border is closed. An east-west trail guides the player to Jezero.
	_trace_path(_lander_cell, ground.local_to_map(Vector2(48, lander.position.y)))

	_assign_biomes(ice_cell)
	_paint_ground(rng)
	_paint_world_edge()
	_paint_jezero_zone()
	_place_landmarks(dune_at, spire_at, probe_at, wreck_at, antenna_at)
	_place_mission_sites(spots)
	_place_jezero_zone(spots)
	_place_mountain_ridges()
	_scatter_props(rng)
	_scatter_jezero_props()
	_ring_ice(rng)
	_build_bounds()
	var safe_rect := get_map_rect()
	var inset := roundi(EDGE_WALL_INSET)
	camera.set_bounds(Rect2i(safe_rect.position + Vector2i(inset, inset), safe_rect.size - Vector2i(inset * 2, inset * 2)))
	var look := SurfaceLook.new()
	look.name = "SurfaceLook"
	add_child(look)


func _physics_process(_delta: float) -> void:
	# Jezero and Isidis are adjacent parts of one tilemap. There is no fade,
	# teleport, camera snap, or transition trigger at their shared border.
	refresh_outside()


func set_bounds_enabled(enabled: bool) -> void:
	bounds.collision_layer = 1 if enabled else 0


func refresh_outside() -> void:
	if GameState.interior_id != &"" or BasePlacer.active or GameState.run_over:
		ResourceSystem.set_outside(false)
		return
	var tiles := float(BaseCatalog.get_rule("build_radius_tiles", 10))
	var outside := player.global_position.distance_to(lander.global_position) > tiles * 16.0
	ResourceSystem.set_outside(outside)


func _exit_tree() -> void:
	ResourceSystem.set_outside(false)


func get_map_rect() -> Rect2i:
	var tile := ground.tile_set.tile_size
	return Rect2i(Vector2i(-JEZERO_WIDTH_TILES * tile.x, 0), Vector2i((map_size.x + JEZERO_WIDTH_TILES) * tile.x, map_size.y * tile.y))


func biome_at(cell: Vector2i) -> int:
	if _inside_jezero(cell):
		# Jezero's cratered, mountainous geology contrasts with flat Isidis.
		return Biome.BASALT if cell.y < 16 or cell.y > 54 else Biome.REGOLITH
	if not _inside(cell):
		return -1
	return int(_biome[_index(cell)])


func is_path_cell(cell: Vector2i) -> bool:
	return _path.has(cell)


func is_lake_cell(cell: Vector2i) -> bool:
	return _lake.has(cell)


func _assign_biomes(ice_cell: Vector2i) -> void:
	_biome.resize(map_size.x * map_size.y)
	_biome.fill(Biome.CAMP)
	var noise := FastNoiseLite.new()
	noise.seed = map_seed
	noise.frequency = noise_frequency
	for y in map_size.y:
		for x in map_size.x:
			var cell := Vector2i(x, y)
			var rel := Vector2(cell - _lander_cell)
			var dist := rel.length()
			var n := noise.get_noise_2d(float(x), float(y))
			var biome := Biome.CAMP
			# Isidis Planitia is a flat, open plain: dust and shallow regolith,
			# never the tall basalt ridges reserved for Jezero.
			if dist > CAMP_CORE and dist > CAMP_REACH + n * 2.4:
				biome = Biome.DUNE if n > 0.15 else Biome.REGOLITH
			var ice_dist := Vector2(cell - ice_cell).length()
			if dist > CAMP_CORE + 2.0 and (ice_dist < 8.0 or ice_dist < 12.0 + n * 2.2):
				biome = Biome.ICE
			_biome[_index(cell)] = biome


func _sector(angle: float) -> int:
	var ang := wrapf(angle, -PI, PI)
	if ang >= -0.7 and ang < 1.25:
		return Biome.DUNE
	if ang >= -2.4 and ang < -0.7:
		return Biome.BASALT
	return Biome.REGOLITH


func _paint_ground(rng: RandomNumberGenerator) -> void:
	for y in map_size.y:
		for x in map_size.x:
			var cell := Vector2i(x, y)
			match biome_at(cell):
				Biome.CAMP:
					_paint_camp(cell, rng)
				Biome.BASALT:
					ground.set_cell(cell, SRC_BASALT, Vector2i(1, 3))
				Biome.REGOLITH:
					ground.set_cell(cell, SRC_REGOLITH, Vector2i(1, 1))
				Biome.DUNE:
					ground.set_cell(cell, SRC_DUNE, Vector2i(0, 3))
				Biome.ICE:
					ground.set_cell(cell, SRC_ICE, Vector2i(0, 3))
				_:
					ground.set_cell(cell, SRC_PATH, Vector2i(1, 3))
	for y in map_size.y:
		for x in map_size.x:
			var cell := Vector2i(x, y)
			if _path.has(cell) or biome_at(cell) == Biome.BASALT:
				continue
			if biome_at(cell) == Biome.REGOLITH and _touches(cell, Biome.BASALT):
				continue
			match biome_at(cell):
				Biome.REGOLITH:
					_paint_blob(cell, Biome.REGOLITH, SRC_REGOLITH, true)
				Biome.DUNE:
					_paint_blob(cell, Biome.DUNE, SRC_DUNE, true)
				Biome.ICE:
					_paint_blob(cell, Biome.ICE, SRC_ICE, true)
	for y in map_size.y:
		for x in map_size.x:
			var cell := Vector2i(x, y)
			if _path.has(cell) or biome_at(cell) == Biome.BASALT:
				continue
			if _touches(cell, Biome.BASALT):
				_paint_mask(cell, SRC_BASALT, Callable(self, "_open_from_basalt"))
	for key in _path:
		var cell := key as Vector2i
		if _inside(cell):
			_paint_blob(cell, -1, SRC_PATH, false)
	_vary_fills()
	_paint_decals()


func _paint_world_edge() -> void:
	# A two-tile basalt rim marks the OUTER map border, not the western
	# Isidis/Jezero seam; both areas are connected within the same tilemap.
	for y in map_size.y:
		for x in map_size.x:
			# Isidis is not bounded at x=0; the Jezero crater continues west.
			if x < EDGE_BAND_TILES and y >= EDGE_BAND_TILES and y < map_size.y - EDGE_BAND_TILES:
				continue
			if x >= EDGE_BAND_TILES and x < map_size.x - EDGE_BAND_TILES and y >= EDGE_BAND_TILES and y < map_size.y - EDGE_BAND_TILES:
				continue
			var cell := Vector2i(x, y)
			ground.set_cell(cell, SRC_BASALT, Vector2i(1, 3))
			decals.erase_cell(cell)


func _paint_camp(cell: Vector2i, rng: RandomNumberGenerator) -> void:
	var dist := Vector2(cell - _lander_cell).length()
	if dist > 3.0 and not _path.has(cell) and rng.randf() < 0.045:
		ground.set_cell(cell, SRC_PATH, Vector2i(3, 2))
	else:
		var options: Array[Vector2i] = [Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)]
		ground.set_cell(cell, SRC_PATH, options[_cell_hash(cell) % options.size()])


## Interior tiles swap among the recolored fill variants. Edges keep the Wang shape.
func _vary_fills() -> void:
	var regolith: Array[Vector2i] = [Vector2i(1, 1), Vector2i(0, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)]
	var dune: Array[Vector2i] = [Vector2i(1, 1), Vector2i(0, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)]
	var ice: Array[Vector2i] = [Vector2i(1, 1), Vector2i(0, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)]
	var basalt: Array[Vector2i] = [Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)]
	for y in map_size.y:
		for x in map_size.x:
			var cell := Vector2i(x, y)
			if _path.has(cell):
				continue
			var biome := biome_at(cell)
			var source := -1
			var options: Array[Vector2i] = []
			match biome:
				Biome.BASALT:
					source = SRC_BASALT
					options = basalt
				Biome.REGOLITH, Biome.DUNE, Biome.ICE:
					if not _fill_core(cell, biome):
						continue
					if biome == Biome.REGOLITH:
						source = SRC_REGOLITH
						options = regolith
					elif biome == Biome.DUNE:
						source = SRC_DUNE
						options = dune
					else:
						source = SRC_ICE
						options = ice
				_:
					continue
			ground.set_cell(cell, source, options[_cell_hash(cell) % options.size()])


func _fill_core(cell: Vector2i, biome: int) -> bool:
	for step in EIGHT:
		var neighbor := cell + step
		if not _inside(neighbor):
			continue
		if _path.has(neighbor) or biome_at(neighbor) != biome:
			return false
	return true


func _paint_decals() -> void:
	if not _use_decal_tiles():
		return
	for y in map_size.y:
		for x in map_size.x:
			var cell := Vector2i(x, y)
			if _path.has(cell):
				continue
			var roll := _cell_hash(cell) % 100
			match biome_at(cell):
				Biome.REGOLITH:
					if roll < 28:
						decals.set_cell(cell, 0, Vector2i(0 if roll < 18 else 1, 0))
				Biome.DUNE:
					if roll < 36:
						decals.set_cell(cell, 0, Vector2i(2, 0))
				Biome.BASALT:
					if _biome_edge(cell, Biome.BASALT) and roll < 24:
						decals.set_cell(cell, 0, Vector2i(4 if roll % 2 == 0 else 5, 0))
					elif roll < 22:
						decals.set_cell(cell, 0, Vector2i(3, 0))
				Biome.ICE:
					if _biome_edge(cell, Biome.ICE) and roll < 58:
						decals.set_cell(cell, 0, Vector2i(4 if roll % 2 == 0 else 5, 0))
					elif roll < 50:
						decals.set_cell(cell, 0, Vector2i(6 if roll < 30 else 7, 0))
				Biome.CAMP:
					if roll < 8:
						decals.set_cell(cell, 0, Vector2i(0, 0))
				_:
					pass


func _biome_edge(cell: Vector2i, biome: int) -> bool:
	for step in EIGHT:
		var neighbor := cell + step
		if _inside(neighbor) and biome_at(neighbor) != biome and not _path.has(neighbor):
			return true
	return false


func _use_decal_tiles() -> bool:
	var tex := load("res://assets/art/tiles/mars_decals_16.png") as Texture2D
	if tex == null:
		push_warning("MarsMap: decal sheet missing. Ground keeps the recolored Wang tiles.")
		return false
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(16, 16)
	var cols := maxi(tex.get_width() / 16, 1)
	for x in cols:
		source.create_tile(Vector2i(x, 0))
	tile_set.add_source(source, 0)
	decals.tile_set = tile_set
	return true


func _cell_hash(cell: Vector2i) -> int:
	var n: int = cell.x * 374761393 ^ cell.y * 668265263 ^ map_seed * 1274126177
	n = n ^ (n >> 13)
	n = n * 1274126177
	return absi(n)


func _paint_blob(cell: Vector2i, biome: int, source: int, halo: bool) -> void:
	if biome < 0:
		_paint_mask(cell, source, Callable(self, "_is_path_match"))
	else:
		_paint_mask(cell, source, Callable(self, "_same_biome").bind(biome))
	if not halo:
		return
	var sides: Array[Vector2i] = [N, E, S, W]
	for step in sides:
		var neighbor: Vector2i = cell + step
		if _inside(neighbor) and not _path.has(neighbor) and biome_at(neighbor) == Biome.CAMP:
			ground.set_cell(neighbor, source, Vector2i(1, 3))


func _paint_mask(cell: Vector2i, source: int, matches: Callable) -> void:
	var n: bool = matches.call(cell + N)
	var e: bool = matches.call(cell + E)
	var s: bool = matches.call(cell + S)
	var w: bool = matches.call(cell + W)
	var nw: bool = matches.call(cell + NW)
	var ne: bool = matches.call(cell + NE)
	var sw: bool = matches.call(cell + SW)
	var se: bool = matches.call(cell + SE)
	ground.set_cell(cell, source, _blob_atlas(n, e, s, w, nw, ne, sw, se))


## Bits: N=1 E=2 S=4 W=8, set when that side continues the foreground.
## Layout of each PixelLab sheet: 3x3 blob, then four inner corners.
func _blob_atlas(n: bool, e: bool, s: bool, w: bool, nw: bool, ne: bool, sw: bool, se: bool) -> Vector2i:
	var mask := (1 if n else 0) | (2 if e else 0) | (4 if s else 0) | (8 if w else 0)
	match mask:
		15:
			if not nw:
				return Vector2i(4, 1)
			if not ne:
				return Vector2i(3, 1)
			if not sw:
				return Vector2i(4, 0)
			if not se:
				return Vector2i(3, 0)
			return Vector2i(1, 1)
		14:
			return Vector2i(1, 0)
		13:
			return Vector2i(1, 2)
		11:
			return Vector2i(2, 1)
		7:
			return Vector2i(0, 1)
		6:
			return Vector2i(0, 0)
		12:
			return Vector2i(2, 0)
		3:
			return Vector2i(0, 2)
		9:
			return Vector2i(2, 2)
		5, 10:
			return Vector2i(1, 1)
		1:
			return Vector2i(1, 2)
		2:
			return Vector2i(0, 1)
		4:
			return Vector2i(1, 0)
		8:
			return Vector2i(2, 1)
		_:
			return Vector2i(0, 3)


func _same_biome(cell: Vector2i, biome: int) -> bool:
	if not _inside(cell):
		return true
	return biome_at(cell) == biome


func _is_path_match(cell: Vector2i) -> bool:
	if not _inside(cell):
		return true
	return _path.has(cell)


func _open_from_basalt(cell: Vector2i) -> bool:
	if not _inside(cell):
		return true
	return biome_at(cell) != Biome.BASALT


func _touches(cell: Vector2i, biome: int) -> bool:
	for step in EIGHT:
		var neighbor := cell + step
		if _inside(neighbor) and biome_at(neighbor) == biome:
			return true
	return false


## Candidate ridges are tested against ALL reserved routes, landing facilities and
## mission landmarks. They remain solid, so exploration means navigating around.
func _place_mountain_ridges() -> void:
	# Jezero's rugged western highland and crater rim; none cross Isidis.
	# Keep the cave and the marked exploration paths unobstructed.
	var candidates: Array[Vector2] = [
		# North rim: raised, broken highlands visible from the basin floor.
		Vector2(-1435, 155), Vector2(-1210, 112), Vector2(-970, 93),
		Vector2(-730, 125), Vector2(-505, 92), Vector2(-280, 128),
		# Western ridge and south rim, with open passage to the cave and rovers.
		Vector2(-1430, 360), Vector2(-1430, 595), Vector2(-1430, 820),
		Vector2(-1375, 1020), Vector2(-1145, 1055), Vector2(-900, 1040),
		Vector2(-670, 1010), Vector2(-430, 1030), Vector2(-260, 910),
		# Distant interior escarpments with space around mission landmarks.
		Vector2(-1140, 680), Vector2(-625, 810), Vector2(-475, 240),
	]
	var index := 0
	for at in candidates:
		var ridge := MountainRidge.new()
		ridge.name = "JezeroRidge%d" % (index + 1)
		ridge.position = at
		ridge.span = 174.0 + float(index % 3) * 17.0
		ridge.height = 115.0 + float(index % 2) * 20.0
		entities.add_child(ridge)
		index += 1

func _ridge_area_clear(pos: Vector2, rx: int, ry: int) -> bool:
	var center := ground.local_to_map(pos)
	for y in range(-ry, ry + 1):
		for x in range(-rx, rx + 1):
			var cell := center + Vector2i(x, y)
			if not _inside(cell) or _reserved.has(cell) or _path.has(cell):
				return false
	return true


func _reserve_ridge(pos: Vector2, rx: int, ry: int) -> void:
	var center := ground.local_to_map(pos)
	for y in range(-ry, ry + 1):
		for x in range(-rx, rx + 1):
			_reserved[center + Vector2i(x, y)] = true


func _scatter_props(rng: RandomNumberGenerator) -> void:
	# ISIDIS PLANITIA: broad, nearly level landing plain. Shallow dune ripples
	# and only a few scattered stones. No towering ridges or dense obstacles.
	_scatter(rng, Biome.DUNE, 9, [TEX_DUNE], [FOOT_DUNE], [false], 70.0, 2)
	_scatter(rng, Biome.REGOLITH, 8, [TEX_ROCK_S], [FOOT_SMALL], [false], 80.0, 2)
	_scatter(rng, Biome.CAMP, 2, [TEX_ROCK_S], [FOOT_SMALL], [false], 110.0, 2)
	# A localized ice-science site is still present for existing missions.
	_scatter(rng, Biome.ICE, 7, [TEX_ICE], [FOOT_ICE], [false], 52.0, 2)


func _scatter_jezero_props() -> void:
	# JEZERO: deliberately much rockier than Isidis, with exposed boulders,
	# crater debris, and isolated spires. Most small stones are decorative so
	# paths to both rover archives, the cave and the glacier remain walkable.
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed + 9173
	var protected: Array[Vector2] = [
		Vector2(-1000, 385), Vector2(-1050, 865), Vector2(-780, 640),
		Vector2(-535, 430), Vector2(-410, 730), Vector2(-88, lander.position.y),
	]
	var placed := 0
	for attempt in 420:
		if placed >= 96:
			break
		var cell := Vector2i(rng.randi_range(-JEZERO_WIDTH_TILES + 5, -6), rng.randi_range(4, JEZERO_HEIGHT_TILES - 5))
		if _path.has(cell):
			continue
		var at := ground.map_to_local(cell) + Vector2(0, 7)
		var clear := true
		for goal in protected:
			if at.distance_to(goal) < 82.0:
				clear = false
				break
		if not clear or not _far(at, 33.0):
			continue
		var roll := rng.randi_range(0, 9)
		if roll == 0:
			_add_prop(TEX_SPIRE, at, FOOT_SPIRE, true, Color("b86d45"))
		elif roll < 4:
			_add_prop(TEX_ROCK_M, at, FOOT_MED, false, Color("a85b3d"))
		elif roll < 7:
			_add_prop(TEX_ROCK_S, at, FOOT_SMALL, false, Color("c47848"))
		else:
			_add_prop(TEX_RIM, at, FOOT_RIM, false, Color("8a5746"))
		placed += 1


func _scatter(
	rng: RandomNumberGenerator,
	biome: int,
	count: int,
	texs: Array,
	boxes: Array,
	solids: Array,
	spacing: float,
	margin: int,
) -> void:
	var tile := Vector2(ground.tile_set.tile_size)
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 70:
		attempts += 1
		var cell := Vector2i(rng.randi_range(EDGE_BAND_TILES + 1, map_size.x - EDGE_BAND_TILES - 2), rng.randi_range(EDGE_BAND_TILES + 1, map_size.y - EDGE_BAND_TILES - 2))
		if biome_at(cell) != biome or _blocked(cell, margin):
			continue
		var pos := ground.map_to_local(cell) + Vector2(0, tile.y * 0.5)
		if not _far(pos, spacing):
			continue
		var pick := rng.randi_range(0, texs.size() - 1)
		_add_prop(texs[pick], pos, boxes[pick], bool(solids[pick]))
		placed += 1


func _ring_ice(rng: RandomNumberGenerator) -> void:
	for i in 5:
		var ang := float(i) * TAU / 5.0 + rng.randf_range(-0.15, 0.15)
		var at := ice_site.position + Vector2(cos(ang), sin(ang)) * rng.randf_range(120.0, 168.0)
		at = _clamp_pos(at)
		var cell := ground.local_to_map(at)
		if _blocked(cell, 1):
			continue
		_add_prop(TEX_RIM if i % 2 == 0 else TEX_ICE, at, FOOT_RIM if i % 2 == 0 else FOOT_ICE, true)


func _place_landmarks(dune_at: Vector2, spire_at: Vector2, probe_at: Vector2, wreck_at: Vector2, antenna_at: Vector2) -> void:
	_add_rover(_rover_pos)
	_seat_lander()
	_add_prop(TEX_DUNE, dune_at, FOOT_DUNE, true, Color("c47848"))
	_add_prop(TEX_DUNE, spire_at, FOOT_DUNE, false, Color("c47848"))
	var beacon_probe := _add_prop(TEX_ROCK_M, probe_at, FOOT_MED, true, Color("7a8c9a"))
	beacon_probe.name = "OldProbe"
	var opp := _add_prop(TEX_OPPORTUNITY, wreck_at, FOOT_ROVER, true, Color("ff6a20"))
	opp.name = "Opportunity"
	_attach_target(opp, &"rover_opportunity", 46.0)
	# Antenna graphic is part of the united ship texture, not a separate prop.
	ice_site.add_to_group(&"map_landmark")
	ice_site.set_meta(&"blip_color", Color("7ee7f2"))
	var beacon := StatusLamp.new()
	beacon.lamp_color = Color("ffe000")
	beacon.position = Vector2(18, -54)
	beacon.blink_hz = 1.7
	lander.add_child(beacon)
	WarmLight.attach(lander, Vector2(10, -46), Color("ffe000"), 3.2, 0.22, 0.9, Color("ffe8b0"), true)
	GroundShadow.attach(lander, Vector2(20, 5))
	var flag := entities.get_node_or_null("Flag") as Node2D
	if flag != null:
		GroundShadow.attach(flag, Vector2(4, 2))
		flag.add_to_group(&"map_landmark")
		flag.set_meta(&"blip_color", Color("e81030"))
	var dust := DustDrift.new()
	dust.name = "Weather"
	add_child(dust)


func _reserve_landmarks(dune_at: Vector2, spire_at: Vector2, probe_at: Vector2, wreck_at: Vector2, antenna_at: Vector2) -> void:
	_rover_pos = lander.position + ROVER_OFFSET
	_reserve_area(ground.local_to_map(_rover_pos), 3)
	for at in [dune_at, spire_at, probe_at, wreck_at, antenna_at]:
		_reserve_area(ground.local_to_map(at), 2)


## Goals, not the shifted props. Opportunity is in the east; Spirit stays west.
## Spirit (220, 430), Opportunity (1312, 628), cave (western Jezero), glacier (western Jezero),
## hematite goal (820, 780), olivine goal (700, 800), lake (960, 980).
func _mission_spots(wreck_at: Vector2) -> Dictionary:
	var origin := lander.position
	return {
		"opportunity": wreck_at,
		"spirit": _clamp_pos(origin + Vector2(-564, -122)),
		"cave": Vector2(-1000, 385),
		"glacier": Vector2(-1050, 865),
		"hematite": _clamp_pos(origin + Vector2(36, 228)),
		"olivine": _clamp_pos(origin + Vector2(-84, 248)),
		"lake": Vector2(-780, 640),
	}


func _reserve_mission_spots(spots: Dictionary) -> void:
	_reserve_area(ground.local_to_map(spots["spirit"]), 3)
	_reserve_area(ground.local_to_map(spots["cave"]), 4)
	_reserve_area(ground.local_to_map(spots["glacier"]), 4)
	_reserve_area(ground.local_to_map(spots["hematite"]), 3)
	_reserve_area(ground.local_to_map(spots["olivine"]), 3)
	_reserve_area(ground.local_to_map(spots["lake"]), 6)


func _trace_mission_paths(spots: Dictionary) -> void:
	_trace_path(_lander_cell, ground.local_to_map(spots["opportunity"]))
	_trace_path(_lander_cell, ground.local_to_map(spots["spirit"]))
	# Across the western edge, explore Jezero to reach the cave and glacier.
	# Keep the open Isidis trails directed at its local science sites.
	_trace_path(_lander_cell, ground.local_to_map(spots["hematite"]))
	_trace_path(_lander_cell, ground.local_to_map(spots["olivine"]))


func _place_mission_sites(spots: Dictionary) -> void:
	_dressing = Node2D.new()
	_dressing.name = "SitesDressing"
	add_child(_dressing)
	move_child(_dressing, entities.get_index())

	var spirit := _add_prop(TEX_SPIRIT, spots["spirit"], FOOT_ROVER, true, Color("ff6a20"))
	spirit.name = "Spirit"
	spirit.modulate = Color.WHITE
	spirit.sprite.flip_h = true
	_attach_target(spirit, &"rover_spirit", 46.0)

	var hem_at := _beside(spots["hematite"], lander.position)
	var hematite := _add_prop(TEX_ROCK_L, hem_at, FOOT_LARGE, true, Color("c24a1c"))
	hematite.name = "Hematite"
	hematite.modulate = Color(0.92, 0.48, 0.4)
	_attach_target(hematite, &"mineral_hematite", 44.0)
	var chip := _add_prop(TEX_ROCK_S, hem_at + Vector2(20, -14), FOOT_SMALL, false)
	chip.modulate = Color(0.72, 0.4, 0.42)

	var oli_at := _beside(spots["olivine"], lander.position)
	var olivine := _add_prop(TEX_ROCK_M, oli_at, FOOT_MED, true, Color("d4a05a"))
	olivine.name = "Olivine"
	olivine.modulate = Color(0.9, 0.75, 0.48)
	_attach_target(olivine, &"mineral_olivine", 42.0)

	# Cave, glacier and ancient lakebed are now in western Jezero.
	# Two rover archives (Spirit and Opportunity) remain on Isidis Planitia.


func _place_cave(at: Vector2) -> void:
	var lip := Polygon2D.new()
	lip.color = Color("8a2e14")
	lip.polygon = _ellipse(58, 33, 18)
	lip.position = at
	_dressing.add_child(lip)
	var hole := Polygon2D.new()
	hole.color = Color("1a0c14")
	hole.polygon = _ellipse(30, 18, 16)
	hole.position = at + Vector2(0, -2)
	_dressing.add_child(hole)
	for i in 5:
		var ang := PI + float(i) * (PI / 4.0)
		var rim_at := at + Vector2(cos(ang), sin(ang)) * 72.0
		if rim_at.y > at.y + 8.0:
			continue
		_add_prop(TEX_RIM, rim_at, FOOT_RIM, true)
	var door := BuildingDoor.new()
	door.name = "CaveDoor"
	door.mode = BuildingDoor.Mode.ENTER
	door.interior_id = &"cave"
	door.cave_mouth = true
	# Put the interact area on the skylight itself so the player can press E at the mouth.
	door.position = at + Vector2(0, 2)
	entities.add_child(door)
	var mark := Node2D.new()
	mark.name = "CaveMouth"
	mark.position = at + Vector2(0, 6)
	mark.add_to_group(&"map_landmark")
	mark.set_meta(&"blip_color", Color("8a3058"))
	entities.add_child(mark)
	_attach_target(mark, &"cave_mouth", 86.0)
	# Distinct cyan beacon makes the actual interaction spot identifiable at night.
	var beacon := StatusLamp.new()
	beacon.position = at + Vector2(0, -36)
	beacon.lamp_color = Color("3ed4e8")
	beacon.blink_hz = 1.5
	_dressing.add_child(beacon)
	WarmLight.attach(entities, at + Vector2(0, 4), Color("ff8a58"), 1.5, 0.06, 0.35, Color("c47848"), true)


func _place_glacier(goal: Vector2) -> void:
	var at := goal if goal.x < 0.0 else _beside(goal, lander.position)
	var lobe := _add_prop(TEX_ICE, at, FOOT_ICE, false, Color("2a8ab8"))
	lobe.name = "Glacier"
	_attach_target(lobe, &"glacier_lobe", 42.0)
	var cap := _add_prop(TEX_ROCK_M, at + Vector2(-8, -12), FOOT_MED, false)
	cap.modulate = Color(0.55, 0.32, 0.28)
	var dust := _add_prop(TEX_ROCK_S, at + Vector2(10, -8), FOOT_SMALL, false)
	dust.modulate = Color(0.62, 0.48, 0.36)
	var flank := _add_prop(TEX_ICE, at + Vector2(16, 2), FOOT_ICE, false)
	flank.modulate = Color(0.82, 0.9, 0.94)


func _place_lake(at: Vector2) -> void:
	_mark_lake(at, 88.0, 62.0)
	var wash := Polygon2D.new()
	var tint := Color("7a8c9a")
	tint.a = 0.5
	wash.color = tint
	wash.polygon = _ellipse(88, 62, 16)
	wash.position = at
	_dressing.add_child(wash)
	var mark := Node2D.new()
	mark.name = "AncientLakebed"
	mark.position = at
	mark.add_to_group(&"map_landmark")
	mark.set_meta(&"blip_color", Color("7a8c9a"))
	entities.add_child(mark)
	_attach_target(mark, &"lakebed", 84.0)
	var clay := _add_prop(TEX_ROCK_M, at + Vector2(-36, 18), FOOT_MED, false, Color("d4a05a"))
	clay.name = "LakeClay"
	clay.modulate = Color(0.86, 0.7, 0.46)
	_attach_target(clay, &"lake_clay", 34.0)
	var layers := _add_prop(TEX_ROCK_S, at + Vector2(42, -16), FOOT_SMALL, false, Color("7a8c9a"))
	layers.name = "LakeLayers"
	layers.modulate = Color(0.7, 0.78, 0.72)
	_attach_target(layers, &"lake_layers", 34.0)
	var silica := _add_prop(TEX_ROCK_S, at + Vector2(-58, -20), FOOT_SMALL, false, Color("d4a05a"))
	silica.modulate = Color("f0d28a")
	_attach_target(silica, &"sample_silica", 28.0)
	var phyllo := _add_prop(TEX_ROCK_M, at + Vector2(-10, -28), FOOT_MED, false, Color("8ce846"))
	phyllo.modulate = Color("92b978")
	_attach_target(phyllo, &"sample_phyllosilicates", 30.0)
	var sulfate := _add_prop(TEX_ROCK_S, at + Vector2(54, 22), FOOT_SMALL, false, Color("fffce8"))
	sulfate.modulate = Color("fff0a8")
	_attach_target(sulfate, &"sample_sulfates", 28.0)
	var chloride := _add_prop(TEX_ROCK_S, at + Vector2(4, 30), FOOT_SMALL, false, Color("f0f4f8"))
	chloride.modulate = Color("d8e2ea")
	_attach_target(chloride, &"sample_chlorides", 28.0)
	var carbonates := _add_prop(TEX_ROCK_M, at + Vector2(62, -34), FOOT_MED, false, Color("b8f4ff"))
	carbonates.modulate = Color("a8d0c2")
	_attach_target(carbonates, &"sample_carbonates", 30.0)


func _mark_lake(center: Vector2, rx: float, ry: float) -> void:
	var origin := ground.local_to_map(center)
	var reach := int(ceil(maxf(rx, ry) / 16.0)) + 1
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			var cell := origin + Vector2i(x, y)
			if not _inside(cell) and not _inside_jezero(cell):
				continue
			var p := ground.map_to_local(cell) - center
			if (p.x * p.x) / (rx * rx) + (p.y * p.y) / (ry * ry) <= 1.0:
				_lake[cell] = true


func _ellipse(rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * float(i) / float(n)
		pts.append(Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts


func _attach_target(host: Node2D, target: StringName, radius: float) -> void:
	var area := MissionArea.new()
	area.name = "Target_%s" % target
	area.target_id = target
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitorable = false
	var shape := CircleShape2D.new()
	shape.radius = radius
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, 4)
	area.add_child(col)
	host.add_child(area)


func _add_prop(tex: Texture2D, at: Vector2, box: Rect2, blocks: bool, blip: Color = Color(0, 0, 0, 0)) -> MarsProp:
	var prop: MarsProp = PROP_SCENE.instantiate()
	prop.texture_override = tex
	prop.footprint = box
	prop.solid = blocks
	prop.position = at
	entities.add_child(prop)
	_prop_spots.append(at)
	if blip.a > 0.01:
		prop.add_to_group(&"map_landmark")
		prop.set_meta(&"blip_color", blip)
	return prop


func _add_rover(at: Vector2) -> void:
	var body := CharacterBody2D.new()
	body.name = "Rover"
	body.set_script(ROVER_SCRIPT)
	body.position = at
	var sprite := Sprite2D.new()
	sprite.texture = ROVER_TEX
	sprite.offset = Vector2(0, -ROVER_TEX.get_height() / 2.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(sprite)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 12)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -6)
	body.add_child(collision)
	GroundShadow.attach(body, Vector2(16, 4))
	# The movable support rover is its own interactive artifact. Do not give it
	# Spirit/Opportunity's target ID: those mission rovers remain far apart.
	var info_area := MissionArea.new()
	info_area.name = "SupportRoverInfo"
	info_area.target_id = &"rover_support"
	info_area.collision_layer = 0
	info_area.collision_mask = 1
	info_area.monitorable = false
	var info_shape := CircleShape2D.new()
	info_shape.radius = 50.0
	var info_collision := CollisionShape2D.new()
	info_collision.name = "CollisionShape2D"
	info_collision.shape = info_shape
	info_collision.position = Vector2(0, -6)
	info_area.add_child(info_collision)
	body.add_child(info_area)
	body.add_to_group(&"map_landmark")
	body.set_meta(&"blip_color", Color("f0f4f8"))
	entities.add_child(body)
	_prop_spots.append(at)


func _seat_lander() -> void:
	var sprite := lander.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and sprite.texture != null:
		sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0)
	var col := lander.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var shape := col.shape as RectangleShape2D if col != null else null
	if shape != null:
		shape.size = Vector2(208.0, 14.0)
		col.position = Vector2(0, -7.0)
	var reach := lander.get_node_or_null("MissionArea/CollisionShape2D") as CollisionShape2D
	if reach != null:
		reach.position = Vector2(0, 12.0)
	# The spacecraft's airlock is now the one outdoor entry point for all its rooms.
	# Habitat mission target remains attached to the docked living module.
	var door := BuildingDoor.new()
	door.name = "ShipAirlock"
	door.mode = BuildingDoor.Mode.ENTER
	door.interior_id = &"habitat"
	door.position = Vector2(14, 4)
	lander.add_child(door)


func _beside(at: Vector2, from: Vector2) -> Vector2:
	var dir := at - from
	if dir.length_squared() < 1.0:
		return _clamp_pos(at)
	dir = dir.normalized()
	var side := Vector2(-dir.y, dir.x)
	return _clamp_pos(at + side * 36.0)


func _clamp_pos(at: Vector2) -> Vector2:
	var limit := Vector2(map_size * ground.tile_set.tile_size)
	return Vector2(clampf(at.x, 48.0, limit.x - 48.0), clampf(at.y, 48.0, limit.y - 48.0))


func _far(pos: Vector2, spacing: float) -> bool:
	for spot in _prop_spots:
		if spot.distance_to(pos) < spacing:
			return false
	return true


func _blocked(cell: Vector2i, margin: int) -> bool:
	if not _inside(cell):
		return true
	for y in range(-margin, margin + 1):
		for x in range(-margin, margin + 1):
			var neighbor := cell + Vector2i(x, y)
			if _reserved.has(neighbor) or _path.has(neighbor):
				return true
	return false


func _reserve_area(center: Vector2i, radius: int) -> void:
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			if x * x + y * y <= radius * radius:
				_reserved[center + Vector2i(x, y)] = true


func _trace_path(from: Vector2i, to: Vector2i) -> void:
	var steps := maxi(absi(to.x - from.x), absi(to.y - from.y))
	for i in steps + 1:
		var t := 0.0 if steps == 0 else float(i) / float(steps)
		var cell := Vector2i(Vector2(from).lerp(Vector2(to), t).round())
		for w in path_width:
			var offsets: Array[Vector2i] = [Vector2i(0, w), Vector2i(w, 0)]
			for offset in offsets:
				var step: Vector2i = cell + offset
				if _inside(step):
					_path[step] = true
					_reserved[step] = true


func _build_bounds() -> void:
	var rect := get_map_rect()
	var inset := EDGE_WALL_INSET
	var edges := [
		[Vector2(0, rect.position.y + inset), Vector2.DOWN],
		[Vector2(0, rect.end.y - inset), Vector2.UP],
		[Vector2(rect.position.x + inset, 0), Vector2.RIGHT],
		[Vector2(rect.end.x - inset, 0), Vector2.LEFT],
	]
	for edge in edges:
		var shape := WorldBoundaryShape2D.new()
		shape.normal = edge[1]
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = edge[0]
		bounds.add_child(collision)


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < map_size.x and cell.y < map_size.y


func _index(cell: Vector2i) -> int:
	return cell.y * map_size.x + cell.x


func _inside_jezero(cell: Vector2i) -> bool:
	return cell.x >= -JEZERO_WIDTH_TILES and cell.x < 0 and cell.y >= 0 and cell.y < JEZERO_HEIGHT_TILES


func _paint_jezero_zone() -> void:
	# Jezero occupies the full western 96 x 72 tiles. Crater rims, exposed
	# darker highland, and the ancient low-lying delta contrast with the smooth
	# desert of Isidis Planitia at x >= 0.
	for y in range(JEZERO_HEIGHT_TILES):
		for x in range(-JEZERO_WIDTH_TILES, 0):
			var cell := Vector2i(x, y)
			var dx := float(x + 49) / 31.0
			var dy := float(y - 39) / 22.0
			var radius := sqrt(dx * dx + dy * dy)
			var sample := absi(x * 13 + y * 37 + x * y * 3) % 29
			var outer_rim := y < 12 or y > 59 or x < -85
			var crater_rim := absf(radius - 1.0) < 0.16
			if outer_rim or crater_rim or (sample < 4 and radius > 0.64):
				ground.set_cell(cell, SRC_BASALT, Vector2i(1, 3))
			elif radius < 0.73:
				ground.set_cell(cell, SRC_PATH, Vector2i(3, 2) if sample < 19 else Vector2i(2, 3))
			else:
				ground.set_cell(cell, SRC_REGOLITH, Vector2i(1, 1) if sample < 20 else Vector2i(2, 3))
	# Natural cliff at the three OUTER edges, while the east edge is walkable.
	for y in range(JEZERO_HEIGHT_TILES):
		for x in range(-JEZERO_WIDTH_TILES, -JEZERO_WIDTH_TILES + EDGE_BAND_TILES):
			ground.set_cell(Vector2i(x, y), SRC_BASALT, Vector2i(1, 3))
	for x in range(-JEZERO_WIDTH_TILES, 0):
		for y in [0, 1, JEZERO_HEIGHT_TILES - 2, JEZERO_HEIGHT_TILES - 1]:
			ground.set_cell(Vector2i(x, y), SRC_BASALT, Vector2i(1, 3))
	# Wide ochre foot trail from Isidis through Jezero and towards the cave.
	var crossing_y := lander.position.y
	_trace_jezero_path(Vector2(-35, crossing_y), Vector2(-430, 510))
	_trace_jezero_path(Vector2(-430, 510), Vector2(-960, 401))
	_trace_jezero_path(Vector2(-960, 401), Vector2(-1000, 385))
	_trace_jezero_path(Vector2(-430, 510), Vector2(-535, 430))
	_trace_jezero_path(Vector2(-430, 510), Vector2(-410, 730))
	_trace_jezero_path(Vector2(-960, 401), Vector2(-780, 640))
	_trace_jezero_path(Vector2(-780, 640), Vector2(-1050, 865))
	# Blend the western Jezero trail into the eastern Isidis trail.
	var gate_cell := ground.local_to_map(Vector2(0, crossing_y))
	for x in range(-4, 5):
		for y in range(gate_cell.y - 2, gate_cell.y + 3):
			ground.set_cell(Vector2i(x, y), SRC_PATH, Vector2i(3, 2))
			_path[Vector2i(x, y)] = true


func _trace_jezero_path(start: Vector2, finish: Vector2) -> void:
	var begin := ground.local_to_map(start)
	var end := ground.local_to_map(finish)
	var steps := maxi(absi(end.x - begin.x), absi(end.y - begin.y))
	for i in range(steps + 1):
		var t := float(i) / float(maxi(steps, 1))
		var mid := Vector2i(Vector2(begin).lerp(Vector2(end), t).round())
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var cell := mid + Vector2i(dx, dy)
				if not _inside_jezero(cell):
					continue
				ground.set_cell(cell, SRC_PATH, Vector2i(2, 3) if ((cell.x + cell.y) & 3) == 0 else Vector2i(3, 2))
				_path[cell] = true


func _place_jezero_zone(spots: Dictionary) -> void:
	# Relocated cave, glacial deposits and Jezero's ancient lakebed.
	_place_cave(spots["cave"])
	_add_zone_sign(spots["cave"] + Vector2(-16, -67), "CAVE" if Settings.lang == "en" else "CUEVA")
	_add_zone_sign(Vector2(-350, 474), "CAVE  <")
	_place_glacier(spots["glacier"])
	_place_lake(spots["lake"])
	# Rover archives: two at Jezero, two on Isidis and Sojourner in the cave.
	var curiosity := _add_prop(TEX_CURIOSITY, Vector2(-535, 430), FOOT_ROVER, true, Color("c4a878"))
	curiosity.name = "CuriosityArchive"
	curiosity.modulate = Color.WHITE
	_attach_target(curiosity, &"rover_curiosity", 46.0)
	var perseverance := _add_prop(TEX_PERSEVERANCE, Vector2(-410, 730), FOOT_ROVER, true, Color("7aa0b8"))
	perseverance.name = "PerseveranceArchive"
	perseverance.modulate = Color.WHITE
	_attach_target(perseverance, &"rover_perseverance", 46.0)
	# Small rocky remnants and spires around the basin, not in the rover routes.
	for at in [Vector2(-1240, 590), Vector2(-320, 295), Vector2(-460, 985), Vector2(-910, 480)]:
		_add_prop(TEX_ROCK_M, at, FOOT_MED, false, Color("d4a05a"))
	for at in [Vector2(-1190, 125), Vector2(-700, 980), Vector2(-1300, 400)]:
		_add_prop(TEX_SPIRE, at, FOOT_SPIRE, true, Color("c47848"))
	# Named directional signs are in world space, avoiding changes to team UI.
	_add_zone_sign(Vector2(100, lander.position.y - 50.0), "< JEZERO")
	_add_zone_sign(Vector2(-136, lander.position.y - 50.0), "ISIDIS PLANITIA >")
	_add_zone_sign(Vector2(lander.position.x, lander.position.y - 105.0), "ISIDIS PLANITIA")
	_add_zone_sign(Vector2(-760, 495), "JEZERO CRATER")


func _add_zone_sign(at: Vector2, line: String) -> void:
	var sign := Label.new()
	sign.name = "ZoneSign"
	sign.text = line
	sign.position = at
	sign.add_theme_font_override("font", preload("res://assets/fonts/m5x7.ttf"))
	sign.add_theme_font_size_override("font_size", 14)
	sign.add_theme_color_override("font_color", Color("fffce8"))
	sign.add_theme_color_override("font_outline_color", Color("142030"))
	sign.add_theme_constant_override("outline_size", 3)
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entities.add_child(sign)
