class_name BasePlacer
extends Node2D
## Start-of-game placement: the chosen modules go down one by one on a 16 px grid around the lander.
## The ghost follows the mouse (once it moves) or sits in front of the player; click or "interact" confirms.
## Green = fits, red = overlaps something (rock, lander, module, player) or is too far from the lander.

const MODULE_SCENE := preload("res://scenes/base/BaseModule.tscn")
const FLAG_TEXTURE := preload("res://assets/art/base/flag_ecuador.png")
const FLAG_FOOTPRINT := Vector2(16.0, 10.0)
const GRID := 16
const VALID_TINT := Color(0.45, 1.0, 0.5, 0.7)
const BLOCKED_TINT := Color(1.0, 0.45, 0.35, 0.7)
const ZONE_COLOR := Color(1.0, 0.98, 0.91, 0.35)
const FACING_VECTORS: Dictionary[StringName, Vector2] = {
	&"down": Vector2.DOWN, &"up": Vector2.UP, &"left": Vector2.LEFT, &"right": Vector2.RIGHT,
	&"down_right": Vector2(0.70710678, 0.70710678),
	&"down_left": Vector2(-0.70710678, 0.70710678),
	&"up_right": Vector2(0.70710678, -0.70710678),
	&"up_left": Vector2(-0.70710678, -0.70710678),
}
## Gap (px) between the player's feet and the ghost when placing with keyboard/gamepad.
const FRONT_GAP := 16.0
## Shrinks the overlap test so modules can sit side by side on the grid.
const OVERLAP_INSET := 2.0

## True while placing; BaseModule ignores "interact" meanwhile.
static var active: bool = false

@export var entities: Node2D
@export var player: Player
@export var lander: Node2D

var _queue: Array[ModuleData] = []
var _flag_pending: bool = true
var _total: int = 0
var _use_mouse: bool = false
var _origin := Vector2.ZERO
var _valid: bool = false
var _blocked: bool = false
var _build_radius: float = 0.0
var _query := PhysicsShapeQueryParameters2D.new()
var _query_shape := RectangleShape2D.new()

@onready var ghost: Sprite2D = $Ghost
@onready var hint_panel: Control = $HintLayer/HintPanel
@onready var hint: Label = $HintLayer/HintPanel/Hint


func _ready() -> void:
	add_to_group(&"base_placer")
	var name_style := LabelSettings.new()
	name_style.font = preload("res://assets/fonts/m5x7.ttf")
	name_style.font_size = 16
	name_style.font_color = Palette.CREMA
	name_style.outline_size = 1
	name_style.outline_color = Palette.ESPACIO
	hint.label_settings = name_style
	hint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hint.scale = Vector2.ONE
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.051, 0.071, 0.11, 0.9)
	plate.border_color = Palette.CONTORNO
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(2)
	plate.set_content_margin_all(3)
	plate.anti_aliasing = false
	hint_panel.add_theme_stylebox_override("panel", plate)
	_build_radius = float(BaseCatalog.get_rule("build_radius_tiles", 10)) * GRID
	# The flag is not visible until the astronaut actually plants it.
	var placed_flag := entities.get_node_or_null("Flag") as Sprite2D
	_flag_pending = not bool(GameState.get_flag(&"ecuador_flag_planted"))
	if placed_flag != null:
		placed_flag.visible = not _flag_pending
	_query.shape = _query_shape
	if GameState.start_modules.is_empty():
		_use_default_kit()
	for id in GameState.start_modules:
		# The landed ship contains its living and science sections; no disconnected
		# habitat/greenhouse/antenna buildings appear on the surface any longer.
		if id in [&"habitat", &"greenhouse", &"antenna_dish"]:
			_dock_module(id)
			continue
		# The oxygen reserve is an actual, usable device inside the living area.
		if id == &"oxygen_tank":
			continue
		var module := BaseCatalog.get_module(id)
		if module:
			_queue.append(module)
	_total = _queue.size()
	_lift_hint.call_deferred()
	Settings.language_changed.connect(_on_language)
	_set_active(_flag_pending or not _queue.is_empty())


## Each real module still participates in night power, mission targets and
## weather events. Only their standalone sprites and physics are eliminated.
func _dock_module(id: StringName) -> void:
	var module: BaseModule = MODULE_SCENE.instantiate()
	module.data = BaseCatalog.get_module(id)
	if module.data == null:
		module.queue_free()
		return
	module.docked = true
	var offset := Vector2.ZERO
	match id:
		&"greenhouse":
			offset = Vector2(-61, -4)
		&"antenna_dish":
			offset = Vector2(77, -10)
		_:
			offset = Vector2(4, 0)
	module.position = lander.position + offset
	entities.add_child(module)
	EventBus.module_placed.emit(id)


func _on_language(_lang: String) -> void:
	if not active:
		return
	var blocked := _blocked
	_set_hint(Settings.text("place.blocked") if blocked else "")


func _exit_tree() -> void:
	active = false


## The hint is UI text. Lift it out of the world viewport so the warp does not bend it.
func _lift_hint() -> void:
	var frame := get_tree().get_first_node_in_group(&"world_frame")
	if frame == null:
		return
	var host := frame.get_parent()
	if host == null:
		return
	var layer := get_node_or_null("HintLayer") as CanvasLayer
	if layer != null and layer.get_parent() != host:
		layer.reparent(host)
	_park_hint()


func _physics_process(_delta: float) -> void:
	if not active:
		return
	if Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO:
		_use_mouse = false
	_refresh()
	_park_hint()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion:
		_use_mouse = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_use_mouse = true
		_try_place()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_try_place()


func _draw() -> void:
	if not active:
		return
	draw_arc(to_local(lander.global_position), _build_radius, 0.0, TAU, 64, ZONE_COLOR, 1.0)
	var size := FLAG_FOOTPRINT if _flag_pending else _queue[0].get_footprint_px()
	var rect := Rect2(to_local(_origin) - Vector2(size.x / 2.0, size.y), size)
	var tint := VALID_TINT if _valid else BLOCKED_TINT
	draw_rect(rect, Color(tint, 0.25))
	draw_rect(rect, tint, false, 1.0)


func _use_default_kit() -> void:
	var kit := BaseCatalog.get_kit(StringName(BaseCatalog.get_rule("default_kit", "")))
	if kit:
		GameState.chosen_kit = kit.id
		GameState.start_modules = kit.module_ids.duplicate()


func _set_active(value: bool) -> void:
	active = value
	ghost.visible = value
	hint_panel.visible = value
	if value:
		_show_current()
	queue_redraw()


func _show_current() -> void:
	if _flag_pending:
		ghost.texture = FLAG_TEXTURE
		ghost.offset = Vector2(0, -FLAG_TEXTURE.get_height() / 2.0)
	elif not _queue.is_empty():
		var module := _queue[0]
		ghost.texture = module.texture
		ghost.offset = Vector2(0, -module.texture.get_height() / 2.0)
	_set_hint()
	_refresh()


func _set_hint(problem: String = "") -> void:
	_blocked = not problem.is_empty()
	var text := ""
	if _flag_pending:
		# Plain Labels must show one language, not the bilingual Settings.pack() string.
		if Settings.lang == "es":
			text = "1. Bandera ecuatoriana: mueve y pulsa E o clic para plantar."
		else:
			text = "1. Ecuadorian flag: move, then press E or click to plant."
	elif not _queue.is_empty():
		var module := _queue[0]
		text = Settings.text("place.hint") % [
			module.localized_name(), _total - _queue.size() + 1, _total]
	hint.text = text if problem.is_empty() else "%s\n%s" % [text, problem]
	_park_hint()


## Keeps the placement line above the INTI box, so the two never share the same pixels.
func _park_hint() -> void:
	# Never render the placement banner behind/through INTI dialogue.
	var inti := get_tree().get_first_node_in_group(&"inti_panel")
	var inti_box := inti.get("box") as IntiBox if inti != null else null
	var inti_open := inti_box != null and inti_box.is_open()
	hint_panel.visible = active and not inti_open
	if not hint_panel.visible:
		return
	var height := hint_panel.get_combined_minimum_size().y
	if height < 16.0:
		height = 28.0
	var view_h := get_viewport().get_visible_rect().size.y
	if view_h < 32.0:
		view_h = 360.0
	var floor_y := view_h - 8.0
	var panel := get_tree().get_first_node_in_group(&"inti_panel")
	var box := panel.get("box") as IntiBox if panel != null else null
	if box != null:
		if box.is_open() and box.panel != null and box.panel.visible:
			var top := box.panel.get_global_rect().position.y
			if box.portrait != null and box.portrait.visible:
				top = minf(top, box.portrait.get_global_rect().position.y)
			if box.name_chip != null and box.name_chip.visible:
				top = minf(top, box.name_chip.get_global_rect().position.y)
			if top > 48.0:
				floor_y = top - 6.0
	floor_y = clampf(floor_y, height + 8.0, view_h - 8.0)
	hint_panel.offset_bottom = floor_y - view_h
	hint_panel.offset_top = hint_panel.offset_bottom - height


func _refresh() -> void:
	_origin = _snap(_desired_origin())
	_valid = _can_place(_origin)
	ghost.global_position = _origin
	ghost.modulate = VALID_TINT if _valid else BLOCKED_TINT
	queue_redraw()


## Origin = bottom-center of the footprint, same as BaseModule.
func _desired_origin() -> Vector2:
	var size := FLAG_FOOTPRINT if _flag_pending else _queue[0].get_footprint_px()
	if _use_mouse:
		return get_global_mouse_position() + Vector2(0, size.y / 2.0)
	var dir: Vector2 = FACING_VECTORS.get(player.facing, Vector2.DOWN)
	var reach := (size.x if dir.x != 0.0 else size.y) / 2.0 + FRONT_GAP
	return player.global_position + dir * reach + Vector2(0, size.y / 2.0)


func _snap(origin: Vector2) -> Vector2:
	var size := FLAG_FOOTPRINT if _flag_pending else _queue[0].get_footprint_px()
	var left := snappedf(origin.x - size.x / 2.0, GRID)
	return Vector2(left + size.x / 2.0, snappedf(origin.y, GRID))


func _can_place(origin: Vector2) -> bool:
	var size := FLAG_FOOTPRINT if _flag_pending else _queue[0].get_footprint_px()
	var center := origin - Vector2(0, size.y / 2.0)
	if center.distance_to(lander.global_position) > _build_radius:
		return false
	_query_shape.size = size - Vector2.ONE * OVERLAP_INSET * 2.0
	_query.transform = Transform2D(0.0, center)
	return get_world_2d().direct_space_state.intersect_shape(_query, 1).is_empty()


func _try_place() -> void:
	_refresh()
	if not _valid:
		_set_hint(Settings.text("place.blocked"))
		return
	if _flag_pending:
		var flag := entities.get_node_or_null("Flag") as Sprite2D
		if flag == null:
			push_error("BasePlacer: the Ecuadorian flag is missing from MarsMap.")
			return
		flag.global_position = _origin
		flag.show()
		GameState.set_flag(&"ecuador_flag_planted", true)
		_flag_pending = false
		# This mission is unlocked before the build queue. Complete it only on a
		# real flag placement, then let the player set down the solar panel.
		MissionSystem.complete_objective(&"plant_flag", "obj_1")
		if _queue.is_empty():
			_set_active(false)
		else:
			_show_current()
		return
	var module: BaseModule = MODULE_SCENE.instantiate()
	module.data = _queue.pop_front()
	module.position = entities.to_local(_origin)
	entities.add_child(module)
	if module.data.id == &"solar_panel":
		# Unpacked equipment starts dusty. The first cleaning mission now has a
		# matching in-world dirty sprite instead of a falsely spotless panel.
		GameState.solar_panel_dust = maxf(GameState.solar_panel_dust, 25.0)
		module.refresh_look()
		DayNightSystem.refresh_weather()
	EventBus.module_placed.emit(module.data.id)
	if _queue.is_empty():
		_set_active(false)
	else:
		_show_current()
