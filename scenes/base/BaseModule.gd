class_name BaseModule
extends StaticBody2D
## A placed base module. Origin at the base of the sprite (Y-sort on Entities).
## Collision = ModuleData.size_tiles footprint; InteractArea opens the info panel on "interact".
## Habitat and greenhouse also grow a door. Standing in that door, interact enters instead.

const UNPOWERED_TINT := Color(0.55, 0.55, 0.65)
const DAMAGED_TINT := Color(0.72, 0.38, 0.32)
const DUSTY_TINT := Color(0.78, 0.55, 0.4)
const DIRTY_SOLAR_TEX := preload("res://assets/art/base/solar_panel_dirty.png")

@export var data: ModuleData
## Built into the landed ship instead of an extra freestanding dome.
@export var docked: bool = false
## Extra reach (px) around the footprint where the player can interact.
@export var interact_margin: float = 10.0

var powered: bool = true
var damaged: bool = false

var _player: Player
var _door: BuildingDoor
var _lamp: StatusLamp
var _glows: Array[WarmLight] = []
var _was_dirty := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var interact_area: Area2D = $InteractArea
@onready var interact_shape: CollisionShape2D = $InteractArea/CollisionShape2D


func _ready() -> void:
	sprite.texture = data.texture
	var tex_h := float(data.texture.get_height())
	# Node origin sits on the ground line, so Y-sort hides the player behind the roof.
	sprite.offset = Vector2(0, -tex_h / 2.0)

	var footprint := data.get_footprint_px()
	# Front wall only. The roof stays walkable so the player can pass behind the dome.
	# Habitat and greenhouse are 64x48: the facade is rows 29-46, about 19 px above the
	# ground line, so 20 px reaches the eaves. Flatter modules stay on their footprint.
	var body_h := minf(20.0, footprint.y)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(footprint.x, body_h)
	collision.shape = shape
	collision.position = Vector2(0, -body_h / 2.0)

	var reach := RectangleShape2D.new()
	reach.size = footprint + Vector2.ONE * interact_margin * 2.0
	interact_shape.shape = reach
	# Docked bays are behind the ship wall. Their exterior mission/contact area
	# extends onto the safe apron in front of the common airlock.
	interact_shape.position = Vector2(0, 18.0) if docked else collision.position

	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	add_to_group(MissionSystem.TARGET_GROUP)
	ResourceSystem.register_module(self)
	if docked:
		# A single ship shell provides the actual exterior art/collider/entrance.
		sprite.hide()
		collision.disabled = true
		collision_layer = 0
		collision_mask = 0
	else:
		GroundShadow.attach(self, Vector2(footprint.x * 0.32, clampf(footprint.y * 0.18, 3.0, 6.0)))
		_add_lamp()
		_add_glow(tex_h)
	if not docked and (data.id == &"habitat" or data.id == &"greenhouse"):
		_door = BuildingDoor.new()
		_door.interior_id = data.id
		add_child(_door)
	set_process(data.id == &"solar_panel")
	_was_dirty = _panel_dirty()


func _exit_tree() -> void:
	ResourceSystem.unregister_module(self)


func _process(_delta: float) -> void:
	var dirty := _panel_dirty()
	if dirty == _was_dirty:
		return
	_was_dirty = dirty
	_refresh_tint()


func set_powered(value: bool) -> void:
	powered = value and not damaged
	_refresh_tint()


func set_damaged(value: bool) -> void:
	damaged = value
	if damaged:
		powered = false
	_refresh_tint()


func _refresh_tint() -> void:
	if data != null and data.id == &"solar_panel":
		sprite.texture = DIRTY_SOLAR_TEX if _panel_dirty() else data.texture
	if damaged:
		sprite.modulate = DAMAGED_TINT
	elif _panel_dirty():
		sprite.modulate = Color.WHITE
	elif powered:
		sprite.modulate = Color.WHITE
	else:
		sprite.modulate = UNPOWERED_TINT
	if _lamp != null:
		_lamp.lit = powered and not damaged
	for glow in _glows:
		glow.lit = powered and not damaged
	_was_dirty = _panel_dirty()


func refresh_look() -> void:
	_refresh_tint()


## Dust or a loose panel. Shaking it is optional and does not block the run.
func panel_needs_shake() -> bool:
	if data == null or data.id != &"solar_panel":
		return false
	return GameState.solar_panel_dust >= 15.0 or GameState.dust_sols_left > 0 or GameState.panel_weak_sols_left > 0


func _panel_dirty() -> bool:
	return panel_needs_shake()


func is_player_near() -> bool:
	return _player != null


func _add_lamp() -> void:
	if data == null or data.texture == null:
		return
	if data.id != &"habitat" and data.id != &"solar_panel":
		return
	var height := float(data.texture.get_height())
	var lamp := StatusLamp.new()
	if data.id == &"habitat":
		lamp.position = Vector2(-14, -height + 16)
		lamp.lamp_color = Color("ffe000")
		lamp.blink_hz = 2.1
	else:
		lamp.wide = true
		lamp.position = Vector2(0, -height + 12)
		lamp.lamp_color = Color("b4f86a")
		lamp.blink_hz = 1.15
	lamp.lit = powered and not damaged
	add_child(lamp)
	_lamp = lamp


func _add_glow(height: float) -> void:
	if data == null:
		return
	match data.id:
		&"habitat":
			_glow(Vector2(-8, -height + 18), Color("ff8a58"), 2.6, 0.16, 0.85)
			_glow(Vector2(12, -height + 20), Color("ffe000"), 1.7, 0.1, 0.6)
		&"greenhouse":
			_glow(Vector2(0, -height + 16), Color("ffc0a8"), 2.8, 0.14, 0.75)
		&"solar_panel":
			_glow(Vector2(0, -height * 0.55), Color("3ed4e8"), 2.0, 0.05, 0.5, Color("2a8ab8"), false)
		&"antenna_dish":
			_glow(Vector2(0, -height + 8), Color("b8f4ff"), 1.6, 0.04, 0.45, Color("2a8ab8"), false)


func _glow(at: Vector2, night: Color, scale: float, day_energy: float, night_energy: float, day: Color = Color("ffe8b0"), sunset: bool = true) -> void:
	var light := WarmLight.attach(self, at, night, scale, day_energy, night_energy, day, sunset)
	light.lit = powered and not damaged
	_glows.append(light)


## At the door, "E" enters. Hide the mission prompt so it does not contradict "E: entrar".
func hides_mission_prompt() -> bool:
	return _door != null and _door.is_player_near()


func release_player() -> void:
	if _player != null and _player.interacted.is_connected(_on_player_interacted):
		_player.interacted.disconnect(_on_player_interacted)
	_player = null


## Mission targets use the module id (solar_panel, greenhouse, ...).
func get_target_id() -> StringName:
	return data.id


func get_status_text() -> String:
	var state := Settings.text("module.off")
	if damaged:
		state = Settings.text("module.damaged")
	elif powered:
		state = Settings.text("module.on")
	if data != null and data.id == &"solar_panel":
		var dust_label := "Dust" if Settings.lang == "en" else "Polvo"
		return "%s | %s: %d%%" % [state, dust_label, roundi(GameState.solar_panel_dust)]
	return state


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body
		_player.interacted.connect(_on_player_interacted)


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player.interacted.disconnect(_on_player_interacted)
		_player = null


func _on_player_interacted(_dir: StringName) -> void:
	if BasePlacer.active:
		return
	if _door != null and _door.is_player_near():
		return
	if not MissionSystem.accepts_interact(data.id):
		return
	if MissionSystem.try_interact(data.id):
		return
	if MissionSystem.try_service(self):
		return
	EventBus.module_inspected.emit(self)
