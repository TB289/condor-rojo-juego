class_name CameraRig
extends Camera2D
## Don't Starve-style follow: smoothed, with a short lookahead toward where the target moves.

@export var target_path: NodePath
@export var lookahead_max: float = 24.0
## Target speed (px/s) at which the lookahead reaches its max.
@export var lookahead_full_speed: float = 90.0
## How fast the lookahead catches up with the movement direction.
@export var lookahead_response: float = 4.0

var _target: Node2D
var _lookahead := Vector2.ZERO
var _focused := false
var _focus_point := Vector2.ZERO
var _shake_left := 0.0
var _shake_dur := 0.16
var _shake_mag := 0.0
var _shake_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node2D
	_shake_rng.seed = 1904
	snap_to_target()


## A few pixels, for a meteor or the rescue close. Not for walking, jumping, or menus.
func bump(amount: float = 1.6, duration: float = 0.16) -> void:
	_shake_mag = amount
	_shake_dur = maxf(duration, 0.05)
	_shake_left = _shake_dur


static func nudge_current(amount: float = 1.6, duration: float = 0.16) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var frame := tree.get_first_node_in_group(&"world_frame")
	if frame == null or not frame.has_method(&"current_camera"):
		return
	var cam := frame.call(&"current_camera") as CameraRig
	if cam != null:
		cam.bump(amount, duration)


func _physics_process(delta: float) -> void:
	var pos := global_position
	if _focused:
		pos = _focus_point
	elif _target != null:
		var velocity := Vector2.ZERO
		if _target is CharacterBody2D:
			velocity = (_target as CharacterBody2D).velocity
		var desired := velocity.limit_length(lookahead_full_speed) / lookahead_full_speed * lookahead_max
		_lookahead = _lookahead.lerp(desired, 1.0 - exp(-lookahead_response * delta))
		pos = _target.global_position + _lookahead
	pos += _shake_kick(delta)
	global_position = pos


func _shake_kick(delta: float) -> Vector2:
	if _shake_left <= 0.0:
		return Vector2.ZERO
	_shake_left = maxf(_shake_left - delta, 0.0)
	var falloff := _shake_left / _shake_dur
	return Vector2(_shake_rng.randf_range(-1.0, 1.0), _shake_rng.randf_range(-1.0, 1.0)) * _shake_mag * falloff


## A one-room interior: stay on this point instead of following the player.
func lock_to(point: Vector2) -> void:
	_focused = true
	_focus_point = point
	global_position = point
	reset_smoothing()


func clear_limits() -> void:
	limit_left = -10000000
	limit_top = -10000000
	limit_right = 10000000
	limit_bottom = 10000000


func set_bounds(rect: Rect2i) -> void:
	limit_left = rect.position.x
	limit_top = rect.position.y
	limit_right = rect.end.x
	limit_bottom = rect.end.y
	snap_to_target()


## Cutscenes: glide to a point while the tree is paused. release_focus() goes back to following.
func focus_on(point: Vector2) -> void:
	_focused = true
	_focus_point = point
	process_mode = Node.PROCESS_MODE_ALWAYS


func release_focus() -> void:
	_focused = false
	process_mode = Node.PROCESS_MODE_INHERIT


func retarget(node: Node2D) -> void:
	_target = node
	snap_to_target()


func snap_to_target() -> void:
	if _target == null:
		return
	_lookahead = Vector2.ZERO
	global_position = _target.global_position
	reset_smoothing()
