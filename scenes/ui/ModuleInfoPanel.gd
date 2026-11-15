class_name ModuleInfoPanel
extends CanvasLayer
## Shows name, what it does and status of the module the player interacted with.
## Interact again or walk away to close.

@onready var panel: Control = $Panel
@onready var icon_rect: TextureRect = $Panel/Content/Header/Icon
@onready var title: Label = $Panel/Content/Header/Title
@onready var description: Label = $Panel/Content/Description
@onready var effects: Label = $Panel/Content/Effects
@onready var functions: Label = $Panel/Content/Functions
@onready var status: Label = $Panel/Content/Status

const PANEL_WIDTH := 208.0

var _module: BaseModule


func _ready() -> void:
	panel.hide()
	EventBus.module_inspected.connect(_on_module_inspected)
	Settings.language_changed.connect(_on_language)


func _on_language(_lang: String) -> void:
	if _module != null and is_instance_valid(_module) and panel.visible:
		_fill(_module)
		_fit_panel()


func _process(_delta: float) -> void:
	if _module and (not is_instance_valid(_module) or not _module.is_player_near()):
		_close()


func _on_module_inspected(module: Node) -> void:
	if module == null or module == _module:
		_close()
		return
	_module = module as BaseModule
	_fill(_module)
	panel.show()
	_fit_panel.call_deferred()


func _fill(module: BaseModule) -> void:
	var data := module.data
	# Match the actual clean/dirty solar-panel sprite shown in the world.
	icon_rect.texture = module.sprite.texture if module.sprite != null else data.texture
	title.text = data.localized_name()
	description.text = data.localized_description()
	if data.id == &"antenna_dish":
		description.text += "\n" + NasaData.antenna_line()
		if not GameState.has_flag(&"saw_delay_capsule"):
			GameState.set_flag(&"saw_delay_capsule", true)
			NasaData.show_capsule("delay", true)
	elif data.id == &"greenhouse" and not GameState.has_flag(&"saw_plants_air"):
		GameState.set_flag(&"saw_plants_air", true)
		NasaData.show_capsule("plants_air", true)
	elif data.id == &"oxygen_tank" and not GameState.has_flag(&"saw_moxie"):
		GameState.set_flag(&"saw_moxie", true)
		NasaData.show_capsule("moxie", true)
	var effect_text := data.describe_effects()
	effects.text = Settings.text("module.daily") % effect_text
	effects.visible = not effect_text.is_empty()
	functions.text = data.describe_functions()
	functions.visible = not functions.text.is_empty()
	status.text = Settings.text("module.status") % module.get_status_text()


func _close() -> void:
	_module = null
	panel.hide()


## Short card at the bottom. Long lines wrap inside it.
func _fit_panel() -> void:
	panel.offset_left = -PANEL_WIDTH / 2.0
	panel.offset_right = PANEL_WIDTH / 2.0
	var style := panel.get_theme_stylebox("panel")
	var inner := PANEL_WIDTH
	var extra := 0.0
	if style:
		inner -= style.content_margin_left + style.content_margin_right
		extra = style.content_margin_top + style.content_margin_bottom
	var content := panel.get_node("Content") as VBoxContainer
	var height := _column_height(content, inner) + extra
	var bottom := -8.0
	var inti := get_tree().get_first_node_in_group(&"inti_panel")
	var box := inti.get("box") as IntiBox if inti != null else null
	if box != null:
		if box.is_open() and box.panel != null and box.panel.visible:
			var top := box.panel.get_global_rect().position.y
			if box.portrait != null and box.portrait.visible:
				top = minf(top, box.portrait.get_global_rect().position.y)
			bottom = -(360.0 - top + 6.0)
	bottom = minf(bottom, -8.0)
	panel.offset_bottom = bottom
	panel.offset_top = bottom - height


func _column_height(box: VBoxContainer, width: float) -> float:
	var total := 0.0
	var shown := 0
	for child in box.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		if control is HBoxContainer:
			total += _row_height(control as HBoxContainer, width)
		elif control is Label:
			total += _label_height(control as Label, width)
		else:
			total += control.get_combined_minimum_size().y
		shown += 1
	if shown > 1:
		total += box.get_theme_constant("separation") * (shown - 1)
	return total


func _row_height(row: HBoxContainer, width: float) -> float:
	var row_h := 0.0
	var used := 0.0
	var labels: Array[Label] = []
	for child in row.get_children():
		var item := child as Control
		if item == null or not item.visible:
			continue
		if item is Label:
			labels.append(item)
		else:
			used += item.get_combined_minimum_size().x + row.get_theme_constant("separation")
			row_h = maxf(row_h, item.get_combined_minimum_size().y)
	var remain := maxf(width - used, 32.0)
	for label in labels:
		row_h = maxf(row_h, _label_height(label, remain))
	return row_h


func _label_height(label: Label, width: float) -> float:
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	if label.label_settings:
		if label.label_settings.font:
			font = label.label_settings.font
		if label.label_settings.font_size > 0:
			size = label.label_settings.font_size
	if font == null or label.text.is_empty():
		return float(size)
	return font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, width, size).y
