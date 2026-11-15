class_name Player
extends CharacterBody2D
## Top-down astronaut. Node origin = feet, so Y-sort works on the Entities layer.
## The body never leaves the ground. A jump only lifts the sprite.

signal interacted(dir: StringName)

@export var max_speed: float = 40.0
## A little softer than Earth, so a stop still happens before a doorway.
@export var acceleration: float = 330.0
@export var friction: float = 450.0
## The interact sheet stays in the project. Turn this on later if the pose looks right.
@export var use_interact_animation: bool = false
## Peak of the fake hop, in pixels above the resting sprite offset.
@export var jump_height: float = 18.0
## Seconds from takeoff to the landing pose. The fall is the longer half.
@export var jump_duration: float = 0.82
## Share of jump_duration spent rising. The rest is the slower fall.
@export_range(0.25, 0.55, 0.01) var jump_rise_ratio: float = 0.34
## Seconds held on the land frame after the feet touch.
@export var land_settle: float = 0.16
## Speed while the sprite is in the air. The body is still on the ground.
@export var air_speed_scale: float = 0.85
## Left off. The collision shape stays on the ground, so a hop cannot clear a wall.
@export var allow_obstacle_jump: bool = false
## Held sprint outdoors, clearly faster than the 40 px/s walk.
@export var sprint_scale: float = 1.65
## Energy per real minute while actually sprinting.
## About 34: a few seconds toward the ice shows on the bar; a full tank lasts well over a minute and a half.
@export var sprint_energy_per_minute: float = 62.0
## Energy per real minute while the helmet lamp is on at night.
@export var flashlight_energy_per_minute: float = 12.0
## Visor, in pixels above the feet. The sprite is 32 px with a rest offset near (0, -15).
@export var helmet_light_offset := Vector2(0, -26)

## Degrees inside a facing boundary where the previous face is kept, so a stick
## sitting on a sector edge does not swap animations every frame.
## Eight sectors are half as wide as the old four, so the sticky band uses half of this.
const FACING_MARGIN_DEG := 12.0

const SUIT_FRAMES: SpriteFrames = preload("res://scenes/player/astronaut_frames.tres")
const BARE_FRAMES: SpriteFrames = preload("res://scenes/player/astronaut_frames_bare.tres")

## Lower diagonals fall back to down, upper ones to up, until those sheets exist.
const DIAGONAL_FALLBACK: Dictionary[StringName, StringName] = {
	&"down_right": &"down",
	&"down_left": &"down",
	&"up_right": &"up",
	&"up_left": &"up",
}

## Index 0 is east. Each step is 45° clockwise (screen down is +Y).
const FACINGS: Array[StringName] = [
	&"right",
	&"down_right",
	&"down",
	&"down_left",
	&"left",
	&"up_left",
	&"up",
	&"up_right",
]

const SHADOW_AIR_SCALE := 0.62
## Half of a walk cycle at max_speed. The walk sheet is 4 frames at 8 fps (0.5 s).
const STEP_DISTANCE := 22.5

const FACING_VECTOR: Dictionary[StringName, Vector2] = {
	&"right": Vector2.RIGHT,
	&"down_right": Vector2(1, 1),
	&"down": Vector2.DOWN,
	&"down_left": Vector2(-1, 1),
	&"left": Vector2.LEFT,
	&"up_left": Vector2(-1, -1),
	&"up": Vector2.UP,
	&"up_right": Vector2(1, -1),
}

var facing: StringName = &"down"
var is_interacting: bool = false
var helmet_on: bool = true
var flashlight_on: bool = false
## True only while the body is actually sprinting this frame. The energy bar reads it.
var is_sprinting: bool = false
## Hidden while seated in the support rover; the rover owns movement and camera.
var driving_rover: bool = false
var _lamp: WarmLight

var _base_offset := Vector2(0, -15)
var _jump_t := -1.0
var _puffed := false
var _shadow: GroundShadow
var _step_left := 0.0
var _was_stepping := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group(&"player")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base_offset = sprite.offset
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play(&"idle_down")
	_shadow = GroundShadow.attach(self, Vector2(10.0, 3.5))
	_lamp = WarmLight.attach(self, helmet_light_offset, Color("ffe8b0"), 0.48, 0.0, 1.0, Color("ffe8b0"), false)
	_lamp.lit = false


## Seat or dismount without changing the existing astronaut scene or controls.
func set_rover_seated(seated: bool) -> void:
	driving_rover = seated
	is_interacting = false
	is_sprinting = false
	velocity = Vector2.ZERO
	_end_jump()
	flashlight_on = false
	visible = not seated
	_sync_lamp()


## Habitat uses the bare head. Same grid, so the animations do not move.
func set_helmet(on: bool) -> void:
	if on == helmet_on:
		return
	helmet_on = on
	var anim := sprite.animation
	var frame := sprite.frame
	sprite.sprite_frames = SUIT_FRAMES if on else BARE_FRAMES
	if anim == StringName() or not sprite.sprite_frames.has_animation(anim):
		anim = StringName("idle_%s" % facing)
	anim = _resolve_pose(anim)
	sprite.play(anim)
	sprite.frame = mini(frame, sprite.sprite_frames.get_frame_count(anim) - 1)


## Travel and other callers set a cardinal face and a grounded pose in one step.
func snap_facing(face: StringName) -> void:
	is_interacting = false
	facing = face
	_end_jump()
	_set_pose(StringName("idle_%s" % face), true)


func facing_vector() -> Vector2:
	var raw: Vector2 = FACING_VECTOR.get(facing, Vector2.DOWN)
	return raw.normalized()


## Night vision reads this. Indoors and in daylight the lamp stays off.
func is_flashlight_on() -> bool:
	return flashlight_on and _night_surface() and ResourceSystem.get_value(&"energy") > 0.0


## Local point of the visor, including the hop so the lamp stays on the helmet.
func helmet_light_local() -> Vector2:
	var lift := 0.0
	if sprite != null:
		lift = sprite.offset.y - _base_offset.y
	return helmet_light_offset + Vector2(0.0, lift)


func _notification(what: int) -> void:
	# Pause, the journal and cutscenes freeze the tree. Land so the hop does not resume later.
	if what == NOTIFICATION_PAUSED and _jump_t >= 0.0:
		_end_jump()
		if sprite != null:
			_set_pose(StringName("idle_%s" % facing))


func _physics_process(delta: float) -> void:
	if driving_rover:
		velocity = Vector2.ZERO
		is_sprinting = false
		flashlight_on = false
		_sync_lamp()
		return
	if _interior_busy() or GameState.interior_id != &"":
		if _jump_t >= 0.0:
			_end_jump()
		# A cave is still EVA: keep the headlamp and its energy drain enabled.
		if GameState.interior_id != &"cave":
			flashlight_on = false
		if sprite != null and _jump_t < 0.0:
			sprite.speed_scale = 1.0

	if _interior_busy():
		is_sprinting = false
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		_sync_lamp()
		return

	_poll_flashlight()

	if is_interacting:
		is_sprinting = false
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		if sprite != null:
			sprite.speed_scale = 1.0
		_sync_lamp()
		return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if Input.is_action_just_pressed("interact"):
		if IntiBrain.typing:
			return
		_start_interact()
		return

	if Input.is_action_just_pressed("jump") and _can_start_jump():
		_begin_jump()

	var moving := input != Vector2.ZERO
	var sprinting := _is_sprinting(moving)
	is_sprinting = sprinting
	var speed := max_speed * (sprint_scale if sprinting else 1.0)
	if WorldEventDirector.is_sandstorm_live() and GameState.interior_id == &"":
		speed *= lerpf(1.0, 0.57, WorldEventDirector.sandstorm_strength())
	if sprinting and GameState.weak_muscles and GameState.interior_id == &"":
		speed *= NasaData.weak_run_scale()
	if _in_air():
		speed *= air_speed_scale
	if moving:
		# Same speed on a diagonal as on a cardinal. get_vector is already unit length.
		var wish := input.normalized()
		facing = _direction_from(wish)
		velocity = velocity.move_toward(wish * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	if sprinting:
		ResourceSystem.add(&"energy", -sprint_energy_per_minute * delta / 60.0)
	_drain_flashlight(delta)
	_tick_jump(delta)
	_update_pose(moving)
	_apply_jump_frame()
	_apply_locomotion_scale(sprinting)
	_tick_footsteps(moving, delta)
	# allow_obstacle_jump stays off, so the ground shape is what move_and_slide uses.
	move_and_slide()
	_sync_lamp()


## Eight 45° sectors. A stick inside the margin of a boundary keeps the previous face.
func _direction_from(v: Vector2) -> StringName:
	var angle := v.angle()
	var desired := _sector(angle)
	if desired == facing or _near_facing_boundary(angle):
		return facing
	return desired


func _sector(angle: float) -> StringName:
	var a := wrapf(angle + PI / 8.0, 0.0, TAU)
	var index := int(a / (PI / 4.0)) % FACINGS.size()
	return FACINGS[index]


func _near_facing_boundary(angle: float) -> bool:
	var margin := deg_to_rad(FACING_MARGIN_DEG * 0.5)
	var a := wrapf(angle, -PI, PI)
	for i in FACINGS.size():
		var edge := -7.0 * PI / 8.0 + float(i) * (PI / 4.0)
		var gap := absf(wrapf(a - edge, -PI, PI))
		if gap > 0.0001 and gap < margin:
			return true
	return false


func _can_start_jump() -> bool:
	if _jump_t >= 0.0 or is_interacting:
		return false
	if GameState.interior_id != &"" or _interior_busy():
		return false
	if Cutscenes.is_playing() or IntiBrain.typing:
		return false
	if DayNightSystem.is_journal_open() or get_tree().paused or BasePlacer.active:
		return false
	return true


func _begin_jump() -> void:
	_jump_t = 0.0
	_puffed = false
	var jump_pose := _resolve_pose(StringName("jump_%s" % facing))
	if not String(jump_pose).begins_with("jump_"):
		return
	sprite.speed_scale = 0.0
	_set_pose(jump_pose, true)
	sprite.speed_scale = 0.0
	sprite.frame = 0
	AudioManager.play_sfx("jump")


func _tick_jump(delta: float) -> void:
	if _jump_t < 0.0:
		return
	_jump_t += delta
	var duration := maxf(jump_duration, 0.05)
	var settle := maxf(land_settle, 0.0)
	if _jump_t < duration:
		var u := _jump_t / duration
		var lift := _jump_lift(u)
		var height := jump_height
		if GameState.weak_muscles and GameState.interior_id == &"":
			height *= NasaData.weak_jump_scale()
		sprite.offset = _base_offset + Vector2(0, -height * lift)
		if _shadow != null:
			var squat := lerpf(1.0, SHADOW_AIR_SCALE, lift)
			_shadow.scale = Vector2(squat, squat)
		return
	sprite.offset = _base_offset
	if _shadow != null:
		_shadow.scale = Vector2.ONE
	if not _puffed:
		_puffed = true
		_spawn_land_dust()
	if _jump_t >= duration + settle:
		_end_jump()


## Rise eases into the peak. The fall stays up longer, then settles.
func _jump_lift(u: float) -> float:
	var rise := clampf(jump_rise_ratio, 0.25, 0.55)
	if u <= rise:
		var t := u / rise
		return 1.0 - (1.0 - t) * (1.0 - t)
	var t := (u - rise) / (1.0 - rise)
	return pow(1.0 - t, 0.62)


func _in_air() -> bool:
	return _jump_t >= 0.0 and _jump_t < maxf(jump_duration, 0.05)


func _end_jump() -> void:
	_jump_t = -1.0
	if sprite != null:
		sprite.speed_scale = 1.0
		sprite.offset = _base_offset
	if _shadow != null:
		_shadow.scale = Vector2.ONE


func _apply_jump_frame() -> void:
	if _jump_t < 0.0 or sprite == null or sprite.sprite_frames == null:
		return
	var pose := _resolve_pose(StringName("jump_%s" % facing))
	if not String(pose).begins_with("jump_"):
		return
	var count := sprite.sprite_frames.get_frame_count(pose)
	if count <= 0:
		return
	if sprite.animation != pose:
		sprite.play(pose)
	sprite.speed_scale = 0.0
	# The last frame is the landing pose. Air time uses the frames before it.
	if _in_air() and count > 1:
		var u := clampf(_jump_t / maxf(jump_duration, 0.05), 0.0, 0.999)
		var air_frames := count - 1
		sprite.frame = mini(int(u * float(air_frames)), air_frames - 1)
	else:
		sprite.frame = count - 1


func _apply_locomotion_scale(_sprinting: bool) -> void:
	if sprite == null or _jump_t >= 0.0:
		return
	if not String(sprite.animation).begins_with("walk_"):
		sprite.speed_scale = 1.0
		return
	# The walk sheet is authored for max_speed. Scale by the live speed, capped at
	# sprint_scale, so the step stays with the faster walk and does not run ahead.
	var scale := velocity.length() / maxf(max_speed, 1.0)
	sprite.speed_scale = clampf(scale, 0.4, sprint_scale)


func _can_sprint() -> bool:
	if GameState.interior_id != &"" or _interior_busy():
		return false
	if is_interacting or Cutscenes.is_playing() or IntiBrain.typing:
		return false
	if DayNightSystem.is_journal_open() or get_tree().paused or BasePlacer.active:
		return false
	return true


func _is_sprinting(moving: bool) -> bool:
	# Keyboard Shift (either side), remappable sprint and touchscreen held pad.
	# Using physical Shift also covers imported layouts where its action was lost.
	if not moving or not (Input.is_action_pressed(&"sprint") or Input.is_physical_key_pressed(KEY_SHIFT)):
		return false
	if not _can_sprint():
		return false
	return ResourceSystem.get_value(&"energy") > 0.0


func _night_surface() -> bool:
	return not _interior_busy() and (GameState.interior_id == &"cave" or (GameState.interior_id == &"" and DayNightSystem.night_amount() > 0.35))


func _flashlight_blocked() -> bool:
	if is_interacting or Cutscenes.is_playing() or IntiBrain.typing:
		return true
	if DayNightSystem.is_journal_open() or get_tree().paused or BasePlacer.active:
		return true
	return (GameState.interior_id != &"" and GameState.interior_id != &"cave") or _interior_busy()


func _poll_flashlight() -> void:
	if (GameState.interior_id != &"" and GameState.interior_id != &"cave") or _interior_busy():
		flashlight_on = false
		return
	if not _night_surface():
		flashlight_on = false
	if not Input.is_action_just_pressed("flashlight") or _flashlight_blocked():
		return
	if flashlight_on:
		flashlight_on = false
		return
	if _night_surface() and ResourceSystem.get_value(&"energy") > 0.0:
		flashlight_on = true


func _sync_lamp() -> void:
	if _lamp == null:
		return
	_lamp.position = helmet_light_local()
	_lamp.lit = is_flashlight_on()


func _drain_flashlight(delta: float) -> void:
	if not is_flashlight_on():
		if flashlight_on and ResourceSystem.get_value(&"energy") <= 0.0:
			flashlight_on = false
		return
	ResourceSystem.add(&"energy", -flashlight_energy_per_minute * delta / 60.0)
	if ResourceSystem.get_value(&"energy") <= 0.0:
		flashlight_on = false


func _tick_footsteps(moving: bool, delta: float) -> void:
	var stepping := (
		moving
		and _jump_t < 0.0
		and not is_interacting
		and GameState.interior_id == &""
		and not _interior_busy()
		and velocity.length() >= 20.0
	)
	if not stepping:
		_was_stepping = false
		return
	if not _was_stepping:
		_was_stepping = true
		_step_left = STEP_DISTANCE * 0.45
	_step_left -= velocity.length() * delta
	if _step_left > 0.0:
		return
	_step_left = STEP_DISTANCE
	AudioManager.play_sfx("footstep")


func _spawn_land_dust() -> void:
	if GameState.interior_id != &"" or BasePlacer.active or Cutscenes.is_playing():
		return
	AudioManager.play_sfx("land")
	var parent := get_parent()
	if parent == null:
		return
	var puff := preload("res://scenes/player/LandDust.gd").new()
	parent.add_child(puff)
	puff.global_position = global_position


func _update_pose(moving: bool) -> void:
	if is_interacting:
		return
	if _jump_t >= 0.0:
		var jump_pose := _resolve_pose(StringName("jump_%s" % facing))
		if String(jump_pose).begins_with("jump_"):
			_set_pose(jump_pose)
			return
	var action := "walk" if moving else "idle"
	_set_pose(StringName("%s_%s" % [action, facing]))


func _interior_busy() -> bool:
	var travel := get_tree().get_first_node_in_group(&"interior_travel") as InteriorTravel
	return travel != null and travel.busy


func _resolve_pose(pose: StringName) -> StringName:
	var frames := sprite.sprite_frames
	if frames != null and frames.has_animation(pose):
		return pose
	var parts := String(pose).split("_", false, 1)
	if parts.size() < 2 or frames == null:
		return &"idle_down"
	var fallback_dir: StringName = DIAGONAL_FALLBACK.get(StringName(parts[1]), StringName(parts[1]))
	var fallback := StringName("%s_%s" % [parts[0], fallback_dir])
	if frames.has_animation(fallback):
		return fallback
	var idle := StringName("idle_%s" % fallback_dir)
	if frames.has_animation(idle):
		return idle
	return &"idle_down"


func _set_pose(pose: StringName, restart: bool = false) -> void:
	pose = _resolve_pose(pose)
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(pose):
		pose = &"idle_down"
	if not restart and sprite.animation == pose and sprite.is_playing():
		return
	var family := String(pose).get_slice("_", 0)
	var previous := String(sprite.animation).get_slice("_", 0)
	var carry := not restart and family == previous and family in ["walk", "idle", "jump"]
	var frame := sprite.frame
	var progress := sprite.frame_progress
	sprite.play(pose)
	if carry:
		var count := sprite.sprite_frames.get_frame_count(pose)
		sprite.frame = mini(frame, count - 1)
		sprite.frame_progress = progress


func _start_interact() -> void:
	_end_jump()
	interacted.emit(facing)
	if not use_interact_animation:
		_set_pose(StringName("idle_%s" % facing))
		return
	is_interacting = true
	_set_pose(StringName("interact_%s" % facing), true)


func _on_animation_finished() -> void:
	if is_interacting:
		is_interacting = false
		_set_pose(StringName("idle_%s" % facing))
