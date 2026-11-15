class_name BuildingDoor
extends Area2D
## Front door of a habitat or greenhouse, or the way out of an interior.
## The player presses interact while standing here. The prompt is "E: entrar" / "E: salir".

enum Mode { ENTER, EXIT }

@export var mode: Mode = Mode.ENTER
## Which interior this outside door opens. Ignored on the way out.
@export var interior_id: StringName = &"habitat"
## Cave terrain portals: walking into the exterior skylight or interior exit travels.
@export var cave_mouth: bool = false

var _player: Player


func _ready() -> void:
	add_to_group(&"building_door")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	# Draw with the module (or this node) so Y-sort hides it behind the player.
	# A higher z_index would paint the hatch over the astronaut and look like they are inside.
	z_index = 0
	z_as_relative = true

	var shape := RectangleShape2D.new()
	if cave_mouth and mode == Mode.ENTER:
		shape.size = Vector2(62, 48)
	elif mode == Mode.EXIT:
		shape.size = Vector2(44, 20)
	else:
		shape.size = Vector2(36, 18)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	if cave_mouth and mode == Mode.ENTER:
		collision.position = Vector2(0, -3)
	else:
		collision.position = Vector2.ZERO if mode == Mode.EXIT else Vector2(0, 10)
	add_child(collision)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()


func is_player_near() -> bool:
	if cave_mouth:
		return _cave_player_near()
	return _player != null


func _cave_player_near() -> bool:
	if not cave_mouth:
		return false
	if mode == Mode.ENTER and GameState.interior_id != &"":
		return false
	if mode == Mode.EXIT and GameState.interior_id != &"cave":
		return false
	var player := get_tree().get_first_node_in_group(&"player") as Player
	# A seated astronaut stays at the rover's position for camera/survival logic,
	# but driving across a cave mouth must never teleport the vehicle's pilot.
	return player != null and not player.driving_rover and global_position.distance_to(player.global_position) <= 31.0


func _physics_process(_delta: float) -> void:
	if cave_mouth and _cave_player_near() and not _blocked():
		# Cave entrance and exit teleport by walking onto them. E also works,
		# but is never required. The cave spawn and outdoor return sit outside
		# this radius to prevent immediate ping-pong teleporting.
		_on_interact(&"down")


func release_player() -> void:
	if _player != null and _player.interacted.is_connected(_on_interact):
		_player.interacted.disconnect(_on_interact)
	_player = null


## A free spot just south of the door, never inside the module's collision.
func outside_point() -> Vector2:
	var space := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.collision_mask = 1
	params.collide_with_areas = false
	params.collide_with_bodies = true
	if _player != null:
		params.exclude = [_player]
	var return_offsets := [Vector2(0, 72), Vector2(-25, 72), Vector2(25, 72), Vector2(0, 90)] if cave_mouth else [Vector2(0, 22), Vector2(26, 18), Vector2(-26, 18), Vector2(0, 36), Vector2(40, 12), Vector2(-40, 12)]
	for offset in return_offsets:
		var point := to_global(offset)
		params.transform = Transform2D(0.0, point)
		if space.intersect_shape(params, 1).is_empty():
			return point
	return to_global(Vector2(0, 90) if cave_mouth else Vector2(0, 22))


func sign_top() -> Vector2:
	var top := -18.0
	if cave_mouth:
		top = -16.0
	elif mode == Mode.EXIT:
		top = -6.0
	return to_global(Vector2(0.0, top))


func prompt_line() -> String:
	# Cave portals are automatic, with no misleading E/ship-door prompt.
	if cave_mouth:
		return ""
	if not _wants_prompt():
		return ""
	return Settings.text("door.exit" if mode == Mode.EXIT else "door.enter")


func _wants_prompt() -> bool:
	var inside := GameState.interior_id != &""
	var show := is_player_near() and not _blocked()
	if mode == Mode.ENTER:
		return show and not inside
	return show and inside


func _draw() -> void:
	# All visuals come from the ship background / the natural cave skylight.
	# The interactive Area2D is invisible, so it never renders a fake door.
	pass


func _blocked() -> bool:
	if BasePlacer.active or GameState.run_over or Cutscenes.is_playing() or DayNightSystem.is_journal_open():
		return true
	var travel := get_tree().get_first_node_in_group(&"interior_travel") as InteriorTravel
	return travel != null and travel.busy


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	_player = body
	if not _player.interacted.is_connected(_on_interact):
		_player.interacted.connect(_on_interact)


func _on_body_exited(body: Node2D) -> void:
	if body != _player:
		return
	if _player.interacted.is_connected(_on_interact):
		_player.interacted.disconnect(_on_interact)
	_player = null


func _on_interact(_dir: StringName) -> void:
	if _blocked() or (cave_mouth and not _cave_player_near()):
		return
	var travel := get_tree().get_first_node_in_group(&"interior_travel") as InteriorTravel
	if travel == null:
		return
	if mode == Mode.ENTER:
		travel.enter(self)
	else:
		travel.leave()
