extends SceneTree
## Builds data/tiles/mars_tileset.tres.
## Source 0 is the legacy 16px atlas (small crater / rock collision).
## Sources 1-5 are the PixelLab Wang sheets (5x4 tiles of 16), in this order:
##   dust_to_regolith, regolith_to_basalt, dust_to_ice, dust_to_path, dust_to_dune.
## Not in the project, and not downloaded by this script:
##   assets/art/tiles/packs/tiny-rpg-mountain/
##   assets/art/tiles/packs/industrial-mars/
##   assets/art/tiles/pixellab/mars_basalt_to_crater_rim.png
## Run from the project root:
##   godot --headless --path . --script res://tools/build_tileset.gd

const TILE_SIZE := Vector2i(16, 16)
const LEGACY_PATH := "res://assets/art/tiles/mars_tiles_16.png"
const OUTPUT_PATH := "res://data/tiles/mars_tileset.tres"
const LEGACY_GRID := Vector2i(4, 2)
const WANG_GRID := Vector2i(5, 4)
const SOLID_TILES: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1)]
const SOLID_POLYGON := [Vector2(-6, 1), Vector2(6, 1), Vector2(6, 7), Vector2(-6, 7)]
const WANG: Array[String] = [
	"res://assets/art/tiles/pixellab/mars_dust_to_regolith.png",
	"res://assets/art/tiles/pixellab/mars_regolith_to_basalt.png",
	"res://assets/art/tiles/pixellab/mars_dust_to_ice.png",
	"res://assets/art/tiles/pixellab/mars_dust_to_path.png",
	"res://assets/art/tiles/pixellab/mars_dust_to_dune.png",
]


func _initialize() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 1)

	var legacy := _source(LEGACY_PATH, LEGACY_GRID)
	if legacy == null:
		quit(1)
		return
	# Collision only sticks once the source belongs to the TileSet.
	tile_set.add_source(legacy, 0)
	for coords in SOLID_TILES:
		var data := legacy.get_tile_data(coords, 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, PackedVector2Array(SOLID_POLYGON))

	for i in WANG.size():
		var source := _source(WANG[i], WANG_GRID)
		if source == null:
			quit(1)
			return
		tile_set.add_source(source, i + 1)

	DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
	var err := ResourceSaver.save(tile_set, OUTPUT_PATH)
	if err != OK:
		push_error("Could not save %s (error %d)" % [OUTPUT_PATH, err])
	else:
		print("Saved %s with %d sources" % [OUTPUT_PATH, tile_set.get_source_count()])
	quit(err)


func _source(path: String, grid: Vector2i) -> TileSetAtlasSource:
	var texture: Texture2D = load(path)
	if texture == null:
		push_error("Missing atlas: %s" % path)
		return null
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = TILE_SIZE
	for y in grid.y:
		for x in grid.x:
			source.create_tile(Vector2i(x, y))
	return source
