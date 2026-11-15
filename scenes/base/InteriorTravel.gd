class_name InteriorTravel
extends Node
## Fades to a base interior and back. The interior is instanced under Main, not loaded with
## change_scene, so the HUD, INTI and the sol clock (which live on Main) keep running.
## While GameState.interior_id is set, the player is off the surface: no extra "outside" oxygen.

const FADE_SECONDS := 0.43
const INTERIOR_ORIGIN := Vector2(0, 4000)
const ROOMS := {
	&"habitat": preload("res://scenes/base/HabitatInterior.tscn"),
	&"greenhouse": preload("res://scenes/base/GreenhouseInterior.tscn"),
	&"lab": preload("res://scenes/base/LabInterior.tscn"),
	&"cave": preload("res://scenes/base/CaveInterior.tscn"),
}

var busy: bool = false

var _cover: ColorRect
var _room: InteriorRoom
var _return_position := Vector2.ZERO


func _ready() -> void:
	add_to_group(&"interior_travel")
	var layer := CanvasLayer.new()
	layer.layer = 20
	var cover := ColorRect.new()
	cover.color = Color(0.102, 0.047, 0.078, 0.0)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cover)
	add_child(layer)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover = cover


func enter(door: BuildingDoor) -> void:
	if not _can_travel() or GameState.interior_id != &"":
		return
	var packed: PackedScene = ROOMS.get(door.interior_id)
	if packed == null:
		return
	busy = true
	_return_position = door.outside_point()
	AudioManager.play_sfx("door")
	_fade(1.0, _open_then_fade.bind(packed))


func leave() -> void:
	if not _can_travel() or GameState.interior_id == &"":
		return
	busy = true
	AudioManager.play_sfx("door")
	_fade(1.0, _close_then_fade)


## The interior doors lead directly to the chosen bay; the player need not EVA.
func switch_to(destination: StringName) -> void:
	if not _can_travel() or GameState.interior_id not in [&"habitat", &"greenhouse", &"lab"]:
		return
	if destination == GameState.interior_id or destination not in [&"habitat", &"greenhouse", &"lab"]:
		return
	if destination == &"greenhouse" and not GameState.start_modules.has(&"greenhouse"):
		return
	var packed: PackedScene = ROOMS.get(destination)
	if packed == null:
		return
	busy = true
	AudioManager.play_sfx("door")
	_fade(1.0, _switch_then_fade.bind(packed))


func _switch_then_fade(packed: PackedScene) -> void:
	var prior := _room
	var player := _player()
	if prior == null or player == null:
		_fade(0.0, _end_travel)
		return
	prior.camera.enabled = false
	_release_overlaps()
	_room = packed.instantiate()
	_room.position = INTERIOR_ORIGIN
	_world_root().add_child(_room)
	_place_player(player, _room.entities, _room.spawn_position, &"down", false, false)
	GameState.interior_id = _room.room_id
	DayNightSystem.refresh_light()
	_room.camera.zoom = InteriorRoom.CAMERA_ZOOM
	_room.camera.clear_limits()
	_room.camera.lock_to(_room.to_global(_room.view_center()))
	_room.camera.enabled = true
	_room.camera.make_current()
	prior.queue_free()
	_fade(0.0, _end_travel)


func _can_travel() -> bool:
	if busy or GameState.run_over:
		return false
	if BasePlacer.active or DayNightSystem.is_journal_open() or Cutscenes.is_playing():
		return false
	var astronaut := _player()
	return astronaut != null and not astronaut.driving_rover and _map() != null


func _open_then_fade(packed: PackedScene) -> void:
	_open_room(packed)
	_fade(0.0, _end_travel)


func _close_then_fade() -> void:
	_close_room()
	_fade(0.0, _end_travel)


func _end_travel() -> void:
	busy = false
	if _cover != null:
		_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _open_room(packed: PackedScene) -> void:
	var map := _map()
	var player := _player()
	map.visible = false
	map.camera.enabled = false
	map.set_bounds_enabled(false)
	_room = packed.instantiate()
	_room.position = INTERIOR_ORIGIN
	_world_root().add_child(_room)
	_release_overlaps()
	_place_player(player, _room.entities, _room.spawn_position, &"up", false, _room.room_id == &"cave")
	GameState.interior_id = _room.room_id
	# Exploring a pitch-black lava tube switches on the suit torch on entry.
	player.flashlight_on = _room.room_id == &"cave"
	map.refresh_outside()
	DayNightSystem.refresh_light()
	_room.camera.zoom = InteriorRoom.CAMERA_ZOOM
	_room.camera.clear_limits()
	if _room.lock_camera:
		_room.camera.lock_to(_room.to_global(_room.view_center()))
	else:
		_room.camera.set_bounds(Rect2i(Vector2i(INTERIOR_ORIGIN), _room.room_size * InteriorRoom.TILE))
		_room.camera.retarget(player)
	_room.camera.enabled = true
	_room.camera.make_current()


func _close_room() -> void:
	var map := _map()
	var player := _player()
	_release_overlaps()
	_place_player(player, map.entities, _return_position, &"down", true, true)
	GameState.interior_id = &""
	DayNightSystem.refresh_light()
	map.visible = true
	map.set_bounds_enabled(true)
	map.camera.enabled = true
	map.camera.make_current()
	map.camera.snap_to_target()
	map.refresh_outside()
	if _room != null:
		_room.queue_free()
		_room = null


func _place_player(player: Player, parent: Node2D, pos: Vector2, face: StringName, use_global: bool, helmet: bool) -> void:
	player.velocity = Vector2.ZERO
	player.snap_facing(face)
	player.reparent(parent)
	if use_global:
		player.global_position = pos
	else:
		player.position = pos
	player.set_helmet(helmet)


func _fade(alpha: float, then: Callable) -> void:
	if _cover == null:
		then.call()
		return
	if alpha > 0.0:
		_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_cover, "color:a", alpha, FADE_SECONDS)
	tween.tween_callback(then)


func _release_overlaps() -> void:
	for node in get_tree().get_nodes_in_group(&"building_door"):
		if node.has_method(&"release_player"):
			node.release_player()
	for node in get_tree().get_nodes_in_group(&"ship_passage"):
		if node.has_method(&"release_player"):
			node.release_player()
	for node in get_tree().get_nodes_in_group(MissionSystem.TARGET_GROUP):
		if node.has_method(&"release_player"):
			node.release_player()


## Interiors share the world viewport so their camera replaces the map camera there.
func _world_root() -> Node:
	var frame := get_tree().get_first_node_in_group(&"world_frame")
	if frame != null and frame.has_method(&"get_world_root"):
		var world := frame.call(&"get_world_root") as Node
		if world != null:
			return world
	return get_parent()


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func _map() -> MarsMap:
	return get_tree().get_first_node_in_group(&"mars_map") as MarsMap
