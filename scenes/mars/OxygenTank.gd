class_name OxygenTank
extends Node2D
## Habitat suit-refill station. Two seconds per fill; stored stock persists
## between room transitions and recharges over two in-game hours.

const TANK_TEX := preload("res://assets/art/base/oxygen_tank.png")
const TRANSFER_SECONDS := 2.0
const FONT := preload("res://assets/fonts/m5x7.ttf")

@export var reach: float = 38.0
var _player: Player
var _transferring := false
var _fill_amount := 0.0
var _delivered := 0.0
var _elapsed := 0.0
var _bar: ProgressBar
var _text: Label


func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = TANK_TEX
	sprite.offset = Vector2(0.0, -float(TANK_TEX.get_height()) * 0.5)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	var blocker := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 10)
	collision.shape = shape
	collision.position = Vector2(0, -5)
	blocker.add_child(collision)
	add_child(blocker)
	GroundShadow.attach(self, Vector2(12, 3))

	_bar = ProgressBar.new()
	_bar.name = "ReserveBar"
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.show_percentage = false
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.size = Vector2(38, 4)
	_bar.position = Vector2(-19, -39)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("3ed4e8")
	_bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color("1a0c14")
	_bar.add_theme_stylebox_override("background", back)
	add_child(_bar)

	_text = Label.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_override("font", FONT)
	_text.add_theme_font_size_override("font_size", 12)
	_text.add_theme_color_override("font_color", Color("fffce8"))
	_text.add_theme_color_override("font_outline_color", Color("1a0c14"))
	_text.add_theme_constant_override("outline_size", 3)
	_text.z_index = 10
	_text.position = Vector2(-38, -61)
	_text.size = Vector2(76, 18)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_text)

	# Player is reparented into this interior on entry. Connect to that same instance.
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player != null and not _player.interacted.is_connected(_on_interacted):
		_player.interacted.connect(_on_interacted)
	_refresh()


func _exit_tree() -> void:
	ResourceSystem.habitat_tank_in_use = false
	if is_instance_valid(_player) and _player.interacted.is_connected(_on_interacted):
		_player.interacted.disconnect(_on_interacted)


func _process(delta: float) -> void:
	if GameState.run_over or BasePlacer.active or DayNightSystem.is_journal_open():
		return
	if _transferring:
		if not _in_range():
			_transferring = false
			ResourceSystem.habitat_tank_in_use = false
		else:
			_elapsed = minf(_elapsed + delta, TRANSFER_SECONDS)
			var target := _fill_amount * (_elapsed / TRANSFER_SECONDS)
			var amount := maxf(target - _delivered, 0.0)
			amount = minf(amount, ResourceSystem.habitat_tank_stock)
			amount = minf(amount, 100.0 - ResourceSystem.get_value(&"oxygen"))
			if amount > 0.0:
				ResourceSystem.add(&"oxygen", amount)
				ResourceSystem.habitat_tank_stock -= amount
				_delivered += amount
			if _elapsed >= TRANSFER_SECONDS or _delivered >= _fill_amount - 0.001:
				_transferring = false
				ResourceSystem.habitat_tank_in_use = false
				_notice(Settings.pack("Oxígeno recargado.", "Oxygen refilled."))
	_refresh()


func _in_range() -> bool:
	return is_instance_valid(_player) and GameState.interior_id == &"habitat" and _player.global_position.distance_to(global_position) <= reach


func begin_fill() -> bool:
	if not _in_range() or BasePlacer.active or GameState.run_over:
		return false
	if _transferring:
		return true
	var needed := 100.0 - ResourceSystem.get_value(&"oxygen")
	if needed < 0.5:
		_notice(Settings.pack("El traje ya tiene 100% de oxígeno.", "Suit oxygen already at 100%."))
		return true
	var reserve := ResourceSystem.habitat_tank_stock
	if reserve < 0.5:
		_notice(Settings.pack("Reserva vacía; recargando poco a poco.", "Reserve empty; charging slowly."))
		return true
	_fill_amount = minf(needed, reserve)
	_delivered = 0.0
	_elapsed = 0.0
	_transferring = true
	ResourceSystem.habitat_tank_in_use = true
	_notice(Settings.pack("Recargando traje: 2 segundos…", "Refilling suit: 2 seconds…"))
	return true


func _on_interacted(_dir: StringName) -> void:
	begin_fill()


func _notice(message: String) -> void:
	var hud := get_tree().get_first_node_in_group(&"hud")
	if hud != null and hud.has_method(&"show_notice"):
		hud.show_notice(message)


func _refresh() -> void:
	if _bar == null or _text == null:
		return
	var visible_near := _in_range() or _transferring
	_bar.visible = visible_near
	_text.visible = visible_near
	_bar.value = ResourceSystem.habitat_tank_stock
	# Labels do not decode Settings.pack's bilingual separator. Display only
	# the chosen language to avoid rendering stray glyphs over the ship roof.
	if _transferring:
		_text.text = "Filling O2..." if Settings.lang == "en" else "Llenando O2..."
	else:
		_text.text = "%s: O2 %d%%" % [Settings.interact_name(), roundi(ResourceSystem.habitat_tank_stock)]
