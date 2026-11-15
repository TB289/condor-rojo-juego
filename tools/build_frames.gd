extends SceneTree
## Builds scenes/player/astronaut_frames.tres and astronaut_frames_bare.tres.
## Run from the project root:
##   godot --headless --path . --script res://tools/build_frames.gd
## Cardinal sheets are required. Diagonal and jump sheets are optional:
## if a file is missing, that set is skipped and the script still exits 0.

const FRAME_SIZE := Vector2i(32, 32)
const CARDINALS: Array[String] = ["down", "left", "right", "up"]
const DIAGONALS: Array[String] = ["down_right", "down_left", "up_right", "up_left"]

const OUTPUT_PATH := "res://scenes/player/astronaut_frames.tres"
const BARE_OUTPUT_PATH := "res://scenes/player/astronaut_frames_bare.tres"

## Approved copies. Same pixels as pixellab/helmet; do not retarget them.
const SUIT_IDLE := "res://assets/art/characters/astronaut_idle.png"
const SUIT_WALK := "res://assets/art/characters/astronaut_walk.png"
const SUIT_INTERACT := "res://assets/art/characters/astronaut_interact.png"
const HELMET := "res://assets/art/characters/pixellab/helmet/"
const BARE := "res://assets/art/characters/pixellab/nohelmet/"


func _initialize() -> void:
	var err := _save_suit()
	if err != OK:
		quit(err)
		return
	err = _save_bare()
	quit(err)


func _save_suit() -> int:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	if _add_required(frames, SUIT_IDLE, "idle", CARDINALS, 2, 3.0, true) != OK:
		return 1
	if _add_required(frames, SUIT_WALK, "walk", CARDINALS, 4, 8.0, true) != OK:
		return 1
	if _add_required(frames, SUIT_INTERACT, "interact", CARDINALS, 3, 10.0, false) != OK:
		return 1
	_add_optional(frames, HELMET + "astronaut_idle_diag.png", "idle", DIAGONALS, 2, 3.0, true)
	_add_optional(frames, HELMET + "astronaut_walk_diag.png", "walk", DIAGONALS, 4, 8.0, true)
	_add_optional(frames, HELMET + "astronaut_jump.png", "jump", CARDINALS, 5, 12.5, false)
	_add_optional(frames, HELMET + "astronaut_jump_diag.png", "jump", DIAGONALS, 5, 12.5, false)
	_add_optional(frames, HELMET + "astronaut_interact_diag.png", "interact", DIAGONALS, 3, 10.0, false)
	return _write(frames, OUTPUT_PATH)


func _save_bare() -> int:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var idle := _load_required(BARE + "astronaut_idle.png")
	if idle == null:
		return 1
	var walk := _load_required(BARE + "astronaut_walk.png")
	if walk == null:
		return 1
	_add_sheet(frames, idle, "idle", CARDINALS, 2, 3.0, true)
	_add_sheet(frames, walk, "walk", CARDINALS, 4, 8.0, true)
	# No bare interact sheet yet: breathe on the idle frames, cardinals only.
	if not _add_optional(frames, BARE + "astronaut_interact.png", "interact", CARDINALS, 3, 10.0, false):
		for row in CARDINALS.size():
			var anim := StringName("interact_%s" % CARDINALS[row])
			frames.add_animation(anim)
			frames.set_animation_speed(anim, 10.0)
			frames.set_animation_loop(anim, false)
			for col in [0, 1, 0]:
				frames.add_frame(anim, _frame(idle, col, row))
	# Bare suit stays on the cardinal fallback (S17), even if a diagonal sheet is on disk.
	_add_optional(frames, BARE + "astronaut_interact_diag.png", "interact", DIAGONALS, 3, 10.0, false)
	return _write(frames, BARE_OUTPUT_PATH)


func _add_required(frames: SpriteFrames, path: String, action: String, dirs: Array[String], count: int, fps: float, loop: bool) -> int:
	var texture := _load_required(path)
	if texture == null:
		return 1
	_add_sheet(frames, texture, action, dirs, count, fps, loop)
	return OK


func _load_required(path: String) -> Texture2D:
	var texture: Texture2D = load(path)
	if texture == null:
		push_error("Missing sheet: %s" % path)
	return texture


## Returns true when the sheet was added. Missing files are skipped.
func _add_optional(frames: SpriteFrames, path: String, action: String, dirs: Array[String], count: int, fps: float, loop: bool) -> bool:
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		return false
	var texture: Texture2D = load(path)
	if texture == null:
		push_warning("Optional sheet could not be loaded, skipped: %s" % path)
		return false
	var need_w := count * FRAME_SIZE.x
	var need_h := dirs.size() * FRAME_SIZE.y
	if texture.get_width() < need_w or texture.get_height() < need_h:
		push_warning("Optional sheet too small (%dx%d, need %dx%d), skipped: %s" % [texture.get_width(), texture.get_height(), need_w, need_h, path])
		return false
	_add_sheet(frames, texture, action, dirs, count, fps, loop)
	print("Added optional %s" % path)
	return true


func _add_sheet(frames: SpriteFrames, texture: Texture2D, action: String, dirs: Array[String], count: int, fps: float, loop: bool) -> void:
	for row in dirs.size():
		var anim := StringName("%s_%s" % [action, dirs[row]])
		if frames.has_animation(anim):
			push_warning("Duplicate animation %s, skipped" % anim)
			continue
		frames.add_animation(anim)
		frames.set_animation_speed(anim, fps)
		frames.set_animation_loop(anim, loop)
		for col in count:
			frames.add_frame(anim, _frame(texture, col, row))


func _frame(texture: Texture2D, col: int, row: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(Vector2(col, row) * Vector2(FRAME_SIZE), Vector2(FRAME_SIZE))
	return atlas


func _write(frames: SpriteFrames, output_path: String) -> int:
	var err := ResourceSaver.save(frames, output_path)
	if err != OK:
		push_error("Could not save %s (error %d)" % [output_path, err])
	else:
		print("Saved %s with %d animations" % [output_path, frames.get_animation_names().size()])
	return err
