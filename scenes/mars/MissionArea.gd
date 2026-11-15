class_name MissionArea
extends Area2D
## Marks a spot on the map as a mission target (lander, ice_site, ...).
## "interact" while the player is inside goes to MissionSystem.

@export var target_id: StringName

var _player: Player
var _last_activation_frame := -1
var _last_rover_activation_ms := -1000000


func _is_rover() -> bool:
	return String(target_id).begins_with("rover_")


func _nearby_rover_player() -> Player:
	if not _is_rover() or GameState.interior_id != &"" and target_id != &"rover_sojourner":
		return null
	var candidate := get_tree().get_first_node_in_group(&"player") as Player
	if candidate == null:
		return null
	if candidate.driving_rover and target_id != &"rover_support":
		return null
	# Sprites are larger than their foot collision; a little extra reach makes
	# interacting at the visible rover's side reliably possible.
	var radius := 64.0
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape is CircleShape2D:
		radius = maxf(64.0, (shape.shape as CircleShape2D).radius + 14.0)
	return candidate if candidate.global_position.distance_to(global_position) <= radius else null


func _physics_process(_delta: float) -> void:
	if _nearby_rover_player() != null and Input.is_action_just_pressed(&"interact"):
		_on_player_interacted(&"down")


func _ready() -> void:
	add_to_group(MissionSystem.TARGET_GROUP)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func get_target_id() -> StringName:
	return target_id


func is_player_near() -> bool:
	return _player != null or _nearby_rover_player() != null


func release_player() -> void:
	if _player != null and _player.interacted.is_connected(_on_player_interacted):
		_player.interacted.disconnect(_on_player_interacted)
	_player = null


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		if _player != null and _player != body:
			release_player()
		_player = body as Player
		if not _player.interacted.is_connected(_on_player_interacted):
			_player.interacted.connect(_on_player_interacted)


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player.interacted.disconnect(_on_player_interacted)
		_player = null


func _on_player_interacted(_dir: StringName) -> void:
	var leaving_vehicle := target_id == &"rover_support" and get_parent().has_method(&"is_driving") \
		and bool(get_parent().call(&"is_driving"))
	if BasePlacer.active or (MissionSystem.door_has_player() and not leaving_vehicle) or Cutscenes.is_playing() or GameState.run_over or get_tree().paused:
		return
	# A rover may have both a body_entered signal and the distance fallback
	# firing on the same input frame. Only open/toggle the card ONCE.
	var frame := Engine.get_physics_frames()
	if frame == _last_activation_frame:
		return
	if _is_rover() and _nearby_rover_player() == null:
		return
	if _is_rover():
		# A key press can be seen once in _physics_process and again via the
		# player's signal on a neighboring physics tick. Do not toggle it closed.
		var now := Time.get_ticks_msec()
		if now - _last_rover_activation_ms < 200:
			return
		_last_rover_activation_ms = now
	_last_activation_frame = frame
	# The local support rover has Sol 1 repairs and Sol 2 seat/exit controls.
	# Delegate it to the vehicle; other NASA rover archive cards stay unchanged.
	if target_id == &"rover_support" and get_parent().has_method(&"handle_support_interact"):
		get_parent().call(&"handle_support_interact")
		return
	if _is_rover():
		var info := get_tree().get_first_node_in_group(&"rover_info_panel")
		if info != null:
			info.call("inspect_rover", target_id, self)
	# Keep mission completion exactly as it was before; inspecting is optional.
	if MissionSystem.accepts_interact(target_id):
		MissionSystem.try_interact(target_id)
