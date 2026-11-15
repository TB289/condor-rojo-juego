class_name KitSelect
extends Control
## Pre-game screen: pick one of the kits from data/kits/, optionally make one change
## (swap a module, or add one while under max_start_modules), then land.

const NEXT_SCENE := "res://scenes/Main.tscn"
const TITLE_COLOR := Palette.ORO
const GAIN_COLOR := Palette.OK
const LOSS_COLOR := Palette.PELIGRO
const CARD_MIN_HEIGHT := 176.0

var _kit: KitData
var _remove_id: StringName = &""
var _add_id: StringName = &""
var _max_modules: int = 4

@onready var cards: HBoxContainer = %Cards
@onready var change_panel: Control = %ChangePanel
@onready var remove_row: FlowContainer = %RemoveRow
@onready var add_row: FlowContainer = %AddRow
@onready var summary: Label = %Summary
@onready var start_button: Button = %StartButton


func _ready() -> void:
	_max_modules = int(BaseCatalog.get_rule("max_start_modules", 4))
	change_panel.modulate.a = 0.0
	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)
	Settings.language_changed.connect(_apply_language)
	_apply_language(Settings.lang)
	if cards.get_child_count() > 0:
		(cards.get_child(0) as Control).grab_focus()


func _apply_language(_lang: String) -> void:
	$Margin/Layout/Title.text = Settings.text("kit.title")
	$Margin/Layout/Subtitle.text = Settings.text("kit.subtitle")
	start_button.text = Settings.text("kit.start")
	$Margin/Layout/Scroll/Inner/ChangePanel/Rows/RemoveRow/Label.text = Settings.text("kit.remove")
	$Margin/Layout/Scroll/Inner/ChangePanel/Rows/AddRow/Label.text = Settings.text("kit.add")
	_rebuild_cards()
	_refresh_module_buttons(remove_row)
	_refresh_module_buttons(add_row)
	if _kit:
		_update_summary()
	_wire_focus()


func _rebuild_cards() -> void:
	var selected: StringName = _kit.id if _kit else &""
	for child in cards.get_children():
		cards.remove_child(child)
		child.free()
	var group := ButtonGroup.new()
	for kit in BaseCatalog.all_kits():
		var card := _build_card(kit)
		card.button_group = group
		card.toggled.connect(func(on: bool) -> void:
			if on:
				_select_kit(kit))
		cards.add_child(card)
		if kit.id == selected:
			card.set_pressed_no_signal(true)


func _build_card(kit: KitData) -> Button:
	var card := Button.new()
	card.toggle_mode = true
	card.custom_minimum_size.y = CARD_MIN_HEIGHT
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)

	var modules := _modules_for(kit.module_ids)
	box.add_child(_make_label(kit.localized_name(), TITLE_COLOR))
	var icons := HBoxContainer.new()
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for module in modules:
		icons.add_child(_make_icon(module))
	box.add_child(icons)
	box.add_child(_make_label(_names(modules)))
	box.add_child(_make_label("+ " + kit.localized_gain(), GAIN_COLOR))
	box.add_child(_make_label("- " + kit.localized_loss(), LOSS_COLOR))
	return card


func _make_label(text: String, color: Color = Color.TRANSPARENT) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if color.a > 0.0:
		label.add_theme_color_override("font_color", color)
	return label


## Module sprites at half size so 4 fit in a card.
func _make_icon(module: ModuleData) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = module.texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = module.texture.get_size() / 2.0
	icon.size_flags_vertical = Control.SIZE_SHRINK_END
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _select_kit(kit: KitData) -> void:
	_kit = kit
	_remove_id = &""
	_add_id = &""
	var removable: Array[ModuleData] = []
	for module in _modules_for(kit.module_ids):
		if not BaseCatalog.is_locked(module.id):
			removable.append(module)
	var addable: Array[ModuleData] = []
	for module in BaseCatalog.all_modules():
		if module.id not in kit.module_ids:
			addable.append(module)
	_fill_row(remove_row, removable, func(id: StringName) -> void: _remove_id = id)
	_fill_row(add_row, addable, func(id: StringName) -> void: _add_id = id)
	change_panel.modulate.a = 1.0
	start_button.disabled = false
	_update_summary()
	_wire_focus()


## Rebuilds a row of toggle buttons (one pressed at most, can be unpressed). Keeps the row's first Label.
func _fill_row(row: FlowContainer, modules: Array[ModuleData], on_pick: Callable) -> void:
	for child in row.get_children().slice(1):
		child.queue_free()
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for module in modules:
		var button := Button.new()
		button.text = module.localized_name()
		button.toggle_mode = true
		button.button_group = group
		button.set_meta("module_id", module.id)
		button.custom_minimum_size = Vector2(0, 40)
		button.tooltip_text = module.localized_description()
		button.toggled.connect(func(on: bool) -> void:
			on_pick.call(module.id if on else &"")
			_update_summary())
		row.add_child(button)


func _final_module_ids() -> Array[StringName]:
	var ids: Array[StringName] = _kit.module_ids.duplicate()
	if _add_id.is_empty():
		return ids
	if not _remove_id.is_empty():
		ids[ids.find(_remove_id)] = _add_id
	elif ids.size() < _max_modules:
		ids.append(_add_id)
	return ids


func _update_summary() -> void:
	var modules := _modules_for(_final_module_ids())
	var balance: Dictionary[StringName, float] = {}
	for id in ModuleData.RESOURCE_NAMES:
		balance[id] = -ResourceSystem.get_daily_use(id)
	for module in modules:
		var effects := module.get_effects()
		for id in effects:
			balance[id] += effects[id]

	var parts: PackedStringArray = []
	for id in ModuleData.RESOURCE_NAMES:
		parts.append("%s %+d" % [ModuleData.resource_label(id), roundi(balance[id])])
	var lines: PackedStringArray = [
		Settings.text("kit.yours") % _names(modules),
		Settings.text("kit.daily") % ", ".join(parts),
	]
	if not _remove_id.is_empty() and _add_id.is_empty():
		lines.append(Settings.text("kit.pick"))
	summary.text = "\n".join(lines)


func _modules_for(ids: Array[StringName]) -> Array[ModuleData]:
	var result: Array[ModuleData] = []
	for id in ids:
		var module := BaseCatalog.get_module(id)
		if module:
			result.append(module)
	return result


func _names(modules: Array[ModuleData]) -> String:
	var names: PackedStringArray = []
	for module in modules:
		names.append(module.localized_name())
	return ", ".join(names)


func _on_start_pressed() -> void:
	GameState.chosen_kit = _kit.id
	GameState.start_modules = _final_module_ids()
	SceneFade.change_scene(NEXT_SCENE)


func _wire_focus() -> void:
	var card_buttons := _buttons_in(cards)
	var remove_buttons := _buttons_in(remove_row)
	var add_buttons := _buttons_in(add_row)
	var below_cards := start_button
	if not remove_buttons.is_empty():
		below_cards = remove_buttons[0]
	elif not add_buttons.is_empty():
		below_cards = add_buttons[0]
	var below_remove := start_button
	if not add_buttons.is_empty():
		below_remove = add_buttons[0]
	var above_remove: Button = card_buttons[0] if not card_buttons.is_empty() else null
	var above_add := above_remove
	if not remove_buttons.is_empty():
		above_add = remove_buttons[0]
	var above_start := above_add
	if not add_buttons.is_empty():
		above_start = add_buttons[0]
	_chain(card_buttons, null, below_cards)
	_chain(remove_buttons, above_remove, below_remove)
	_chain(add_buttons, above_add, start_button)
	if above_start:
		start_button.focus_neighbor_top = start_button.get_path_to(above_start)
	start_button.focus_neighbor_bottom = start_button.get_path_to(start_button)
	start_button.focus_neighbor_left = start_button.get_path_to(start_button)
	start_button.focus_neighbor_right = start_button.get_path_to(start_button)


func _refresh_module_buttons(row: FlowContainer) -> void:
	for child in row.get_children():
		if child is Button and child.has_meta("module_id"):
			var data := BaseCatalog.get_module(child.get_meta("module_id"))
			if data:
				child.text = data.localized_name()
				child.tooltip_text = data.localized_description()


func _buttons_in(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	for child in node.get_children():
		if child is Button and not child.is_queued_for_deletion():
			found.append(child)
	return found


func _chain(row: Array[Button], up: Button, down: Button) -> void:
	for i in row.size():
		var button := row[i]
		var left := row[i - 1] if i > 0 else button
		var right := row[i + 1] if i + 1 < row.size() else button
		button.focus_neighbor_left = button.get_path_to(left)
		button.focus_neighbor_right = button.get_path_to(right)
		button.focus_neighbor_top = button.get_path_to(up if up != null else button)
		button.focus_neighbor_bottom = button.get_path_to(down if down != null else button)
