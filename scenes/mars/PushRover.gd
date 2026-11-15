extends CharacterBody2D
## Cóndor Support Rover: pushable until Sol 1 repair, drivable from Sol 2.
## All interaction uses the existing interact action (E / touch Interact).
## The player's camera follows the rover while occupied; the suit still consumes oxygen.

const PUSH_SPEED := 25.0
const PUSH_REACH := 48.0
const DRIVE_SPEED := 94.0
const DRIVE_ACCEL := 185.0
const DRIVE_FRICTION := 255.0
const TEST_DRIVE_DISTANCE := 240.0
const ENTER_REACH := 66.0
const PILOT_FRAMES: SpriteFrames = preload("res://scenes/player/astronaut_frames.tres")

var _travel := 0.0
var _test_distance := 0.0
var _player: Player
var _sprite: Sprite2D
var _pilot: Sprite2D
var _indicator: Polygon2D
var _seated := false
var _player_layer: int = 0
var _player_mask: int = 0
var _camera: CameraRig


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_player = get_tree().get_first_node_in_group(&"player") as Player
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	_pilot = Sprite2D.new()
	_pilot.name = "SeatedPilot"
	_pilot.texture = PILOT_FRAMES.get_frame_texture(&"idle_down", 0)
	_pilot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pilot.position = Vector2(-9, -29)
	_pilot.scale = Vector2(0.44, 0.44)
	_pilot.visible = false
	_pilot.z_index = 2
	add_child(_pilot)
	_indicator = Polygon2D.new()
	_indicator.name = "RepairIndicator"
	_indicator.polygon = PackedVector2Array([
		Vector2(-22, -26), Vector2(-17, -26),
		Vector2(-17, -22), Vector2(-22, -22),
	])
	_indicator.z_index = 2
	add_child(_indicator)
	_update_indicator()
	var world := get_parent().get_parent()
	_camera = world.get_node_or_null("CameraRig") as CameraRig
	EventBus.sol_started.connect(_on_sol_started)
	EventBus.mission_completed.connect(_on_mission_completed)
	queue_redraw()


func _on_sol_started(sol: int) -> void:
	_update_indicator()
	queue_redraw()
	if sol == 2 and can_drive():
		_notice("¡Cóndor listo! E para subir y conducir.", "Cóndor ready! Press E to board and drive.")


func _on_mission_completed(mission_id: StringName) -> void:
	if mission_id == &"repair_support_rover":
		_update_indicator()
		queue_redraw()
		_notice("Rover reparado. Podrás conducirlo desde el Sol 2.", "Rover repaired. Driving unlocks on Sol 2.")


func _update_indicator() -> void:
	if _indicator != null:
		_indicator.color = Color("8ce846") if is_repaired() else Color("ff6a20")


func is_driving() -> bool:
	return _seated


func is_repaired() -> bool:
	return bool(GameState.get_flag(&"support_rover_repaired"))


func can_drive() -> bool:
	return GameState.current_sol >= 2 and is_repaired()


func rover_prompt() -> String:
	var es := Settings.lang == "es"
	if _seated:
		return "E: bajar del rover" if es else "E: exit rover"
	if GameState.current_sol >= 1 and not is_repaired():
		return "E: reparar rover" if es else "E: repair rover"
	if is_repaired() and GameState.current_sol < 2:
		return "Rover listo en Sol 2" if es else "Drive available on Sol 2"
	if can_drive():
		return "E: conducir rover" if es else "E: drive rover"
	return "E: ver rover" if es else "E: inspect rover"


func handle_support_interact() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _blocked():
		return
	if _seated:
		_leave_rover()
		return
	if _player.global_position.distance_to(global_position) > ENTER_REACH:
		return
	if GameState.current_sol >= 1 and not is_repaired():
		# The timed Sol 1 repair is a normal MissionSystem objective; pressing E
		# beside the rover starts its work bar and holding E completes the repair.
		if MissionSystem.get_state(&"repair_support_rover") == MissionSystem.ACTIVE:
			MissionSystem.complete_objective(&"repair_support_rover", "obj_1")
			MissionSystem.try_interact(&"rover_support")
		else:
			_notice("Completa el mantenimiento del rover.", "Complete the rover repair mission.")
		return
	if not can_drive():
		_inspect()
		if is_repaired():
			_notice("Podrás conducirlo desde el Sol 2.", "Driving unlocks on Sol 2.")
		return
	# After it is drivable, sprint + interact still opens the fact card without
	# interfering with the one-button enter/exit controls (including on touch).
	if Input.is_action_pressed(&"sprint") or Input.is_physical_key_pressed(KEY_SHIFT):
		_inspect()
		return
	_board_rover()


func _inspect() -> void:
	var card := get_tree().get_first_node_in_group(&"rover_info_panel")
	if card != null:
		card.call("inspect_rover", &"rover_support", self)


func _blocked() -> bool:
	return GameState.run_over or BasePlacer.active or GameState.interior_id != &"" \
		or Cutscenes.is_playing() or DayNightSystem.is_journal_open() or get_tree().paused \
		or IntiBrain.typing


func _board_rover() -> void:
	if not can_drive() or _player.driving_rover:
		return
	# The boarding step can be completed after reaching the actual vehicle.
	if MissionSystem.get_state(&"drive_support_rover") == MissionSystem.ACTIVE:
		MissionSystem.complete_objective(&"drive_support_rover", "obj_1")
		MissionSystem.complete_objective(&"drive_support_rover", "obj_2")
	_player_layer = _player.collision_layer
	_player_mask = _player.collision_mask
	_player.set_rover_seated(true)
	_player.collision_layer = 0
	_player.collision_mask = 0
	_player.global_position = global_position
	_seated = true
	_pilot.visible = true
	velocity = Vector2.ZERO
	if _camera != null:
		_camera.retarget(self)
	_notice("WASD / palanca para conducir. E para bajar.", "Use WASD / joystick to drive. E to exit.")
	queue_redraw()


func _leave_rover() -> void:
	if not _seated:
		return
	_seated = false
	_pilot.visible = false
	velocity = Vector2.ZERO
	if is_instance_valid(_player):
		_player.global_position = _safe_disembark_position()
		_player.collision_layer = _player_layer
		_player.collision_mask = _player_mask
		_player.set_rover_seated(false)
		_player.snap_facing(&"down")
		if _camera != null:
			_camera.retarget(_player)
	if MissionSystem.get_state(&"drive_support_rover") == MissionSystem.ACTIVE:
		MissionSystem.complete_objective(&"drive_support_rover", "obj_4")
	queue_redraw()


func _safe_disembark_position() -> Vector2:
	if not is_instance_valid(_player):
		return global_position + Vector2(46, 8)
	var hit := _player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if hit == null or hit.shape == null:
		return global_position + Vector2(46, 8)
	var probe := PhysicsShapeQueryParameters2D.new()
	probe.shape = hit.shape
	probe.collision_mask = _player_mask
	probe.exclude = [get_rid()]
	var choices: Array[Vector2] = [
		Vector2(47, 8), Vector2(-47, 8), Vector2(0, 41), Vector2(0, -42),
		Vector2(47, 35), Vector2(-47, 35), Vector2(47, -35), Vector2(-47, -35),
	]
	for offset in choices:
		var candidate := global_position + offset
		probe.transform = Transform2D(0.0, candidate + hit.position)
		if get_world_2d().direct_space_state.intersect_shape(probe, 1).is_empty():
			return candidate
	return global_position + Vector2(46, 8)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player) or GameState.run_over:
		velocity = Vector2.ZERO
		return
	if _seated:
		_drive(delta)
		return
	velocity = Vector2.ZERO
	if _blocked() or is_repaired():
		return
	# While broken, this rover retains its older push mechanic. Its repair
	# interaction takes precedence on Sol 1.
	if MissionSystem.get_state(&"repair_support_rover") == MissionSystem.ACTIVE:
		return
	if not Input.is_action_pressed(&"interact"):
		return
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var toward: Vector2 = global_position - _player.global_position
	if dir.length_squared() < 0.1 or toward.length() > PUSH_REACH or toward.length_squared() < 1.0:
		return
	if dir.normalized().dot(toward.normalized()) < 0.25:
		return
	velocity = dir.normalized() * PUSH_SPEED
	move_and_slide()
	_travel += get_real_velocity().length() * delta
	_update_sprite()


func _drive(delta: float) -> void:
	if _blocked():
		velocity = Vector2.ZERO
		if is_instance_valid(_player):
			_player.global_position = global_position
		return
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var max_speed := DRIVE_SPEED
	if WorldEventDirector.is_sandstorm_live():
		max_speed *= lerpf(1.0, 0.55, WorldEventDirector.sandstorm_strength())
	if input.length_squared() > 0.02:
		velocity = velocity.move_toward(input.normalized() * max_speed, DRIVE_ACCEL * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, DRIVE_FRICTION * delta)
	var from := global_position
	move_and_slide()
	var moved := global_position.distance_to(from)
	_travel += moved
	_test_distance += moved
	_update_sprite()
	# Keep survival and positional systems focused on the seated astronaut.
	_player.global_position = global_position
	if MissionSystem.get_state(&"drive_support_rover") == MissionSystem.ACTIVE \
			and _test_distance >= TEST_DRIVE_DISTANCE:
		MissionSystem.complete_objective(&"drive_support_rover", "obj_3")


func _update_sprite() -> void:
	if _sprite == null:
		return
	if velocity.x < -4.0:
		_sprite.flip_h = true
	elif velocity.x > 4.0:
		_sprite.flip_h = false
	_sprite.rotation = sin(_travel * 0.14) * (0.022 if _seated else 0.035)


func _draw() -> void:
	# A small warning/ready lamp above the chassis signals the Sol 1 repair.
	var tint := Color("8ce846") if is_repaired() else Color("ff6a20")
	draw_rect(Rect2(-24, -29, 6, 4), Color("142030"))
	draw_rect(Rect2(-23, -28, 4, 2), tint)
	if _seated:
		draw_arc(Vector2(0, -23), 16.0, 0.0, TAU, 24, Color("3ed4e8", 0.8), 1.0)


func _notice(spanish: String, english: String) -> void:
	var hud := get_tree().get_first_node_in_group(&"hud")
	if hud != null:
		hud.call("show_notice", spanish if Settings.lang == "es" else english)
