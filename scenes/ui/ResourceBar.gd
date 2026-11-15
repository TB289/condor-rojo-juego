class_name ResourceBar
extends HBoxContainer
## One HUD row: icon, name, bar and percent for a ResourceSystem resource.
## Below LOW_THRESHOLD the bar pulses softly and a down arrow shows up.

const LOW_THRESHOLD := 0.25
const BLINK_ALPHA := 0.45
const BLINK_HALF_PERIOD := 0.6
## Palette "destello". A quiet tint on the energy bar while sprinting, plus a short flash at the start.
const SPRINT_GLOW := Palette.CREMA
const SPRINT_HOLD := 0.28
const SPRINT_FLASH_SECONDS := 0.2

@export var resource_id: StringName
@export var title: String
@export var icon: Texture2D
@export var color: Color = Color.WHITE

var _blink: Tween
var _fill: StyleBoxFlat
var _sprint_flash := 0.0
var _was_sprinting := false

@onready var icon_rect: TextureRect = $Icon
@onready var name_label: Label = $Info/Header/Name
@onready var percent_label: Label = $Info/Header/Percent
@onready var arrow: Control = $Info/Header/Arrow
@onready var bar: ProgressBar = $Info/Bar


func _ready() -> void:
	icon_rect.texture = icon
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_language("")
	Settings.language_changed.connect(_apply_language)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(0)
	_fill = fill
	bar.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Palette.NAVY
	background.set_corner_radius_all(0)
	bar.add_theme_stylebox_override("background", background)
	arrow.draw.connect(_draw_arrow)
	arrow.hide()

	if resource_id != &"shielding" and not ResourceSystem.has_resource(resource_id):
		hide()
		return
	EventBus.resource_changed.connect(_on_resource_changed)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui)
	if resource_id == &"shielding":
		set_value(NasaData.radiation_shielding(), 100.0)
	else:
		set_value(ResourceSystem.get_value(resource_id), ResourceSystem.get_max(resource_id))


func _process(delta: float) -> void:
	if resource_id == &"shielding":
		if _fill != null:
			set_value(NasaData.radiation_shielding(), 100.0)
		return
	if resource_id != &"energy" or _fill == null:
		return
	var sprinting := _player_sprinting()
	if sprinting and not _was_sprinting:
		_sprint_flash = 1.0
	_was_sprinting = sprinting
	if _sprint_flash > 0.0:
		_sprint_flash = maxf(_sprint_flash - delta / SPRINT_FLASH_SECONDS, 0.0)
	var amount := _sprint_flash * 0.85
	if sprinting:
		amount = maxf(amount, SPRINT_HOLD)
	_fill.bg_color = _bar_color().lerp(SPRINT_GLOW, amount)


func _player_sprinting() -> bool:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	return player != null and player.is_sprinting


func _apply_language(_lang: String) -> void:
	var key := "res.%s" % String(resource_id)
	var translated := Settings.text(key)
	name_label.text = title if translated == key else translated


func set_value(value: float, max_value: float) -> void:
	bar.max_value = max_value
	bar.value = value
	var ratio := value / max_value
	var bonus := 0.0 if resource_id == &"shielding" else ResourceSystem.get_opening_bonus(resource_id)
	if bonus >= 1.0:
		percent_label.text = "%d+%d" % [ceili(ratio * 100.0), roundi(bonus)]
	else:
		percent_label.text = "%d%%" % ceili(ratio * 100.0)
	_fill.bg_color = _bar_color()
	_set_low(ratio < LOW_THRESHOLD)


func _set_low(low: bool) -> void:
	if low == (_blink != null):
		return
	arrow.visible = low
	if low:
		_blink = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		_blink.tween_property(bar, "modulate:a", BLINK_ALPHA, BLINK_HALF_PERIOD)
		_blink.tween_property(bar, "modulate:a", 1.0, BLINK_HALF_PERIOD)
	else:
		_blink.kill()
		_blink = null
		bar.modulate.a = 1.0


func _draw_arrow() -> void:
	var s := arrow.size
	arrow.draw_colored_polygon(PackedVector2Array([
		Vector2(0, s.y * 0.2), Vector2(s.x, s.y * 0.2), Vector2(s.x * 0.5, s.y),
	]), _bar_color())


func _bar_color() -> Color:
	var max_value := maxf(bar.max_value, 0.001)
	if bar.value / max_value < LOW_THRESHOLD:
		return Palette.PELIGRO
	return color


func _on_gui(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
	if not pressed:
		return
	accept_event()
	match resource_id:
		&"oxygen":
			NasaData.show_manual("air")
		&"energy":
			NasaData.show_manual(NasaData.energy_capsule())
		&"shielding":
			NasaData.show_manual("shield_gcr")


func _on_resource_changed(id: StringName, value: float, max_value: float) -> void:
	if id == resource_id:
		set_value(value, max_value)
