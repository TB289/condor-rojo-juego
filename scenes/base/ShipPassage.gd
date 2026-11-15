class_name ShipPassage
extends Area2D
## Pressurised passage between decks of the landed spacecraft. It is not an
## exterior door: going to the lab/greenhouse never teleports back onto Mars.

@export var destination: StringName = &"lab"
const DOOR_TEX := preload("res://assets/art/base/interior_door.png")

var _player: Player
var _text: Label
var _door_sprite: Sprite2D


func _ready() -> void:
	add_to_group(&"ship_passage")
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	monitoring = true
	var shape := CircleShape2D.new()
	shape.radius = 23.0
	var hitbox := CollisionShape2D.new()
	hitbox.shape = shape
	add_child(hitbox)
	_door_sprite = Sprite2D.new()
	_door_sprite.texture = DOOR_TEX
	_door_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_door_sprite.offset = Vector2(0, -DOOR_TEX.get_height() / 2.0)
	add_child(_door_sprite)
	_text = Label.new()
	# Side-wall doors need the caption immediately above their own frame.
	# Anchor text inward on each side so it cannot spill across the room.
	var right_wall := position.x > 160.0
	_text.position = Vector2(-140, -43) if right_wall else Vector2(-14, -43)
	_text.size = Vector2(140, 19)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right_wall else HORIZONTAL_ALIGNMENT_LEFT
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_override("font", preload("res://assets/fonts/m5x7.ttf"))
	_text.add_theme_font_size_override("font_size", 13)
	_text.add_theme_color_override("font_color", Color("fffce8"))
	_text.add_theme_color_override("font_outline_color", Color("142030"))
	_text.add_theme_constant_override("outline_size", 3)
	_text.z_index = 10
	_text.hide()
	add_child(_text)
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	queue_redraw()


func _process(_delta: float) -> void:
	# A room is created before Player is reparented into it. The distance fallback
	# catches those first-frame overlaps and prevents unresponsive E prompts.
	var room := get_parent().get_parent() as InteriorRoom
	if room == null:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	var near := player != null and GameState.interior_id == room.room_id and player.global_position.distance_to(global_position) < 27.0
	if near and _player != player:
		_on_entered(player)
	elif not near and _player != null:
		_on_exited(_player)
	_text.visible = near and not travel_blocked()
	if _text.visible:
		_text.text = "%s: %s" % [Settings.interact_name(), _label(Settings.lang == "en")]


func travel_blocked() -> bool:
	var travel := get_tree().get_first_node_in_group(&"interior_travel") as InteriorTravel
	return travel != null and travel.busy


func _label(en: bool) -> String:
	match destination:
		&"greenhouse":
			return "Greenhouse" if en else "Cultivos"
		&"habitat":
			return "Living" if en else "Habitar"
		_:
			return "Lab" if en else "Lab"


func _draw() -> void:
	# A small down-pointing indicator connects the label to the real doorway.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3, -21), Vector2(3, -21), Vector2(0, -17)
	]), Color("ffe000"))


func _on_entered(body: Node2D) -> void:
	if not body is Player:
		return
	if _player != null and _player != body:
		_on_exited(_player)
	_player = body as Player
	if not _player.interacted.is_connected(_interact):
		_player.interacted.connect(_interact)


func _on_exited(body: Node2D) -> void:
	if body != _player:
		return
	if _player.interacted.is_connected(_interact):
		_player.interacted.disconnect(_interact)
	_player = null


func release_player() -> void:
	if _player != null:
		_on_exited(_player)


func _interact(_facing: StringName) -> void:
	var travel := get_tree().get_first_node_in_group(&"interior_travel") as InteriorTravel
	if travel != null and _player != null and _text.visible:
		travel.switch_to(destination)
