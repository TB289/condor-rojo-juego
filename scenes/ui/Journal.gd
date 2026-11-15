class_name Journal
extends CanvasLayer
## Night page. The player picks dinner, who gets panel power, and the day's event.
## Sleep applies the page through DayNightSystem; this scene never spends resources itself.

const ICONS: Dictionary[StringName, Texture2D] = {
	&"oxygen": preload("res://assets/art/ui/icon_oxygen.png"),
	&"energy": preload("res://assets/art/ui/icon_energy.png"),
	&"food": preload("res://assets/art/ui/icon_food.png"),
}
const INK := Palette.CREMA
const GAIN := Palette.OK
const LOSS := Palette.PELIGRO
const DETAIL := Palette.METAL

var _ration_group := ButtonGroup.new()
var _event_group := ButtonGroup.new()
var _power_buttons: Array[Button] = []
var _power_hint: Label
var _budget := 0
var _choose_power := false
var _locked_power: Array[StringName] = []
var _report: Dictionary = {}

@onready var title_label: Label = %Title
@onready var day_card: PanelContainer = %DayCard
@onready var resources_label: Label = %Resources
@onready var mission_label: Label = %MissionLine
@onready var summary_label: Label = %Summary
@onready var decisions: VBoxContainer = %Decisions
@onready var sleep_button: Button = %Sleep


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Page.modulate.a = 0.0
	sleep_button.pressed.connect(_on_sleep)
	_style_day_card()
	_build_close_button()
	_fit_page()
	get_viewport().size_changed.connect(_fit_page)
	Settings.language_changed.connect(_on_language)


func _build_close_button() -> void:
	var layout := $Page/Margin/Layout as VBoxContainer
	layout.remove_child(title_label)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	layout.add_child(header)
	layout.move_child(header, 0)
	header.add_child(title_label)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if title_label.label_settings != null:
		var title_style := title_label.label_settings.duplicate() as LabelSettings
		title_style.font_size = 16
		title_style.outline_size = 2
		title_label.label_settings = title_style
	var close_button := Button.new()
	close_button.name = "CloseSleep"
	close_button.text = "×"
	close_button.tooltip_text = Settings.text("journal.cancel")
	close_button.custom_minimum_size = Vector2(30, 30)
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.pressed.connect(DayNightSystem.cancel_sleep)
	header.add_child(close_button)
	Settings.language_changed.connect(func(lang: String) -> void:
		if is_instance_valid(close_button):
			close_button.tooltip_text = Settings.text("journal.cancel")
	)


func _fit_page() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var page := $Page as PanelContainer
	var page_w := minf(420.0, maxf(260.0, viewport_size.x - 96.0))
	var page_h := minf(236.0, maxf(168.0, viewport_size.y - 88.0))
	var shift := 14.0
	page.offset_left = -page_w * 0.5
	page.offset_right = page_w * 0.5
	page.offset_top = -page_h * 0.5 + shift
	page.offset_bottom = page_h * 0.5 + shift
	var body := $Page/Margin/Layout/Scroll/Body as VBoxContainer
	if body != null:
		body.custom_minimum_size.x = maxf(140.0, page_w - 40.0)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _style_day_card() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.NAVY
	box.border_color = Palette.ORO
	box.set_border_width_all(1)
	box.set_corner_radius_all(0)
	box.set_content_margin_all(3)
	box.anti_aliasing = false
	day_card.add_theme_stylebox_override("panel", box)


func _fill_day_card() -> void:
	var parts: PackedStringArray = []
	for id in ResourceSystem.get_ids():
		parts.append("%s %d" % [Settings.text("res.%s" % String(id)), roundi(ResourceSystem.get_value(id))])
	resources_label.text = " · ".join(parts)
	var shown := MissionSystem.get_shown()
	var mission_name := ""
	if shown != &"":
		mission_name = Settings.pick(MissionSystem.get_mission(shown), "title")
	if mission_name.is_empty():
		mission_name = Settings.text("hud.to_bed")
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_label.text = Settings.text("journal.mission") % mission_name


func _on_language(_lang: String) -> void:
	if _report.is_empty():
		return
	_render(_ration_id(), _option_id(), _powered_ids())


func open(report: Dictionary) -> void:
	if int(report.get("sol", 0)) == 1 and not GameState.has_flag(&"resupply_said"):
		GameState.set_flag(&"resupply_said", true)
		NasaData.show_capsule("resupply", true)
	_report = report
	_render("", "", [])
	UiMotion.fade_in($Page)


func _render(keep_ration: String, keep_option: String, keep_power: Array[StringName]) -> void:
	var report := _report
	title_label.text = Settings.text("journal.title")
	sleep_button.text = Settings.text("journal.sleep")
	sleep_button.custom_minimum_size = Vector2(0, 28)
	_fill_day_card()
	var lines: PackedStringArray = []
	for raw in report.get("summary_lines", []):
		var shown := Settings.visible_text(String(raw))
		if not shown.is_empty():
			lines.append(shown)
	if lines.is_empty():
		lines.append(Settings.visible_text(String(report.get("summary", ""))))
	while lines.size() > 3:
		lines.remove_at(0)
	summary_label.text = "\n".join(lines)
	for child in decisions.get_children():
		decisions.remove_child(child)
		child.free()
	_power_buttons.clear()
	_power_hint = null
	_ration_group = ButtonGroup.new()
	_event_group = ButtonGroup.new()
	var event: Dictionary = report.get("event", {})
	if not event.is_empty():
		_build_event(event, keep_option)
	_build_power(report.get("power", {}), keep_power)
	var ration_id := keep_ration if not keep_ration.is_empty() else String(report.get("default_ration", "half"))
	_build_rations(report.get("rations", []), ration_id)
	_refresh_power_hint()
	var focus_me: BaseButton = _event_group.get_pressed_button()
	if focus_me == null and not _power_buttons.is_empty():
		focus_me = _power_buttons[0]
	if focus_me == null:
		focus_me = _ration_group.get_pressed_button()
	if keep_ration.is_empty() and focus_me:
		focus_me.grab_focus()


func _build_rations(rations: Array, default_id: String) -> void:
	var dinner_row := HBoxContainer.new()
	dinner_row.add_theme_constant_override("separation", 4)
	dinner_row.add_child(_hazard_icon("environment"))
	dinner_row.mouse_filter = Control.MOUSE_FILTER_STOP
	dinner_row.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			NasaData.show_manual("calories")
			dinner_row.accept_event()
	)
	var dinner := _header(Settings.text("journal.dinner"))
	dinner_row.add_child(dinner)
	decisions.add_child(dinner_row)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	decisions.add_child(stack)
	for ration in rations:
		var button := _choice_button(
			Settings.pick(ration, "label"),
			Settings.pick(ration, "detail"),
			ration.get("effects", {}),
			_ration_group,
			String(ration.get("id", "")),
			Vector2(0, 0)
		)
		button.toggled.connect(func(_on: bool) -> void: _refresh_sleep())
		if String(ration.get("id", "")) == default_id:
			button.button_pressed = true
		stack.add_child(button)


func _build_power(power: Dictionary, keep_power: Array[StringName]) -> void:
	_choose_power = String(power.get("mode", "all")) == "choose"
	_budget = int(power.get("budget", 0))
	_locked_power.clear()
	for id in power.get("locked_ids", []):
		_locked_power.append(StringName(String(id)))
	var power_head := HBoxContainer.new()
	power_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_head.add_theme_constant_override("separation", 4)
	power_head.add_child(_icon(ICONS[&"energy"]))
	power_head.add_child(_header(Settings.text("journal.power")))
	decisions.add_child(power_head)
	decisions.add_child(_header(_power_note(power)))
	if not _choose_power:
		return
	_power_hint = _header("")
	for entry in power.get("modules", []):
		var effects: Dictionary = entry.get("effects", {}).duplicate()
		var button := _choice_button(
			_module_name(entry),
			_module_blurb(entry),
			effects,
			null,
			String(entry.get("id", "")),
			Vector2(0, 0)
		)
		button.set_meta("cost", int(entry.get("cost", 0)))
		button.disabled = not bool(entry.get("enabled", true))
		var picked := bool(entry.get("selected", false))
		if not keep_power.is_empty():
			picked = StringName(String(entry.get("id", ""))) in keep_power
		button.button_pressed = picked and not button.disabled
		button.toggled.connect(func(_on: bool) -> void: _refresh_power_hint())
		_power_buttons.append(button)
		decisions.add_child(button)
	decisions.add_child(_power_hint)


func _build_event(event: Dictionary, keep_option: String) -> void:
	var title := Settings.pick(event, "title")
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	var hazard := String(event.get("hazard", ""))
	if not hazard.is_empty():
		head.add_child(_hazard_icon(hazard))
	head.add_child(_header(title if not title.is_empty() else Settings.text("journal.event")))
	decisions.add_child(head)
	decisions.add_child(_header(Settings.pick(event, "text")))
	var photo := String(event.get("photo", ""))
	if not photo.is_empty():
		decisions.add_child(_nasa_photo(photo))
	var first := true
	for option in event.get("options", []):
		var button := _choice_button(
			Settings.pick(option, "label"),
			Settings.pick(option, "detail"),
			option.get("effects", {}),
			_event_group,
			String(option.get("id", "")),
			Vector2(0, 0),
			String(option.get("hazard", event.get("hazard", "")))
		)
		button.toggled.connect(func(_on: bool) -> void: _refresh_sleep())
		var option_id := String(option.get("id", ""))
		if (keep_option.is_empty() and first) or option_id == keep_option:
			button.button_pressed = true
			first = false
		decisions.add_child(button)


func _choice_button(
	title: String,
	detail: String,
	effects: Dictionary,
	group: ButtonGroup,
	id: String,
	min_size: Vector2,
	hazard: String = ""
) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = group
	button.set_meta("choice_id", id)
	var effect_rows := 0
	var flags: Dictionary = effects.get("flags", {})
	var bonus := float(flags.get("bonus_food", 0.0)) if flags is Dictionary else 0.0
	for effect_id in [&"oxygen", &"energy", &"food"]:
		var amount := float(effects.get(effect_id, effects.get(String(effect_id), 0.0)))
		if effect_id == &"food" and is_zero_approx(amount):
			amount = bonus
		if not is_zero_approx(amount):
			effect_rows += 1
	var detail_lines := 0
	if not detail.is_empty():
		detail_lines = 1 + detail.length() / 36
	var block_h := 24.0 + 20.0 + float(detail_lines) * 16.0 + float(effect_rows) * 18.0
	if not hazard.is_empty():
		block_h += 16.0
	button.custom_minimum_size = Vector2(min_size.x, maxf(min_size.y, maxf(block_h, 58.0)))
	button.clip_contents = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 6.0
	box.offset_top = 3.0
	box.offset_right = -6.0
	box.offset_bottom = -3.0
	button.add_child(box)
	var name := Label.new()
	name.text = title
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name)
	if not detail.is_empty():
		var info := Label.new()
		info.text = detail
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_color_override("font_color", DETAIL)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(info)
	if not hazard.is_empty():
		box.add_child(_hazard_icon(hazard))
	box.add_child(_chips(effects))
	return button


func _chips(effects: Dictionary) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	var flags: Dictionary = effects.get("flags", {})
	var bonus := float(flags.get("bonus_food", 0.0)) if flags is Dictionary else 0.0
	for id in [&"oxygen", &"energy", &"food"]:
		var amount := float(effects.get(id, effects.get(String(id), 0.0)))
		if id == &"food" and is_zero_approx(amount):
			amount = bonus
		if is_zero_approx(amount):
			continue
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 4)
		line.add_child(_icon(ICONS[id], 14.0))
		var name := Label.new()
		name.text = ModuleData.resource_label(id)
		name.autowrap_mode = TextServer.AUTOWRAP_OFF
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(name)
		var value := Label.new()
		value.text = "%+d" % roundi(amount)
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.add_theme_color_override("font_color", GAIN if amount > 0.0 else LOSS)
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(value)
		column.add_child(line)
	return column


func _hazard_icon(id: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = NasaData.hazard_texture(id)
	icon.custom_minimum_size = Vector2(12, 12)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


func _nasa_photo(id: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := NasaData.image_texture(id)
	if tex != null:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(160, 72)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(rect)
	var row := NasaData.image_record(id)
	var caption := _header(String(row.get("en" if Settings.lang == "en" else "es", "")))
	box.add_child(caption)
	var credit := _header(String(row.get("credit", "NASA/JPL-Caltech")))
	credit.add_theme_color_override("font_color", Palette.METAL)
	box.add_child(credit)
	return box


func _icon(texture: Texture2D, side: float = 14.0) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(side, side)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


func _header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Palette.CREMA)
	label.add_theme_color_override("font_outline_color", Palette.CONTORNO)
	label.add_theme_constant_override("outline_size", 2)
	return label


func _power_note(power: Dictionary) -> String:
	var budget := int(power.get("budget", 0))
	var mode := String(power.get("mode", "all"))
	if mode == "all":
		return Settings.text("journal.power_all") % budget
	if mode == "none":
		return Settings.text("journal.power_none") % budget
	var total := 0
	for entry in power.get("modules", []):
		total += int(entry.get("cost", 0))
	return Settings.text("journal.power_choose") % [budget, total]


func _module_name(entry: Dictionary) -> String:
	var data := BaseCatalog.get_module(StringName(String(entry.get("id", ""))))
	if data:
		return data.localized_name()
	return String(entry.get("name", ""))


func _module_blurb(entry: Dictionary) -> String:
	var data := BaseCatalog.get_module(StringName(String(entry.get("id", ""))))
	if data:
		var role := data.describe_functions()
		if not role.is_empty():
			return role
	return Settings.text("journal.spend") % int(entry.get("cost", 0))


func _refresh_power_hint() -> void:
	if _power_hint != null and _choose_power:
		var used := _power_cost()
		_power_hint.text = Settings.text("journal.power_use") % [used, _budget]
		_power_hint.add_theme_color_override("font_color", LOSS if used > _budget else INK)
	_refresh_sleep()


func _refresh_sleep() -> void:
	var need_event := _event_group.get_buttons().size() > 0
	var over := _choose_power and _power_cost() > _budget
	sleep_button.disabled = _ration_id().is_empty() or (need_event and _option_id().is_empty()) or over


func _power_cost() -> int:
	var total := 0
	for button in _power_buttons:
		if button.button_pressed and not button.disabled:
			total += int(button.get_meta("cost"))
	return total


func _powered_ids() -> Array[StringName]:
	if not _choose_power:
		return _locked_power.duplicate()
	var ids: Array[StringName] = []
	for button in _power_buttons:
		if button.button_pressed and not button.disabled:
			ids.append(StringName(String(button.get_meta("choice_id"))))
	return ids


func _ration_id() -> String:
	var pressed := _ration_group.get_pressed_button()
	if pressed == null:
		return ""
	return String(pressed.get_meta("choice_id"))


func _option_id() -> String:
	var pressed := _event_group.get_pressed_button()
	if pressed == null:
		return ""
	return String(pressed.get_meta("choice_id"))


func _one_summary(lines: PackedStringArray) -> String:
	if lines.is_empty():
		return ""
	var generic := Settings.visible_text(Settings.format_both("journal.summary", [int(_report.get("sol", 1))]))
	var picked := ""
	for line in lines:
		if line == generic:
			continue
		var low := line.to_lower()
		var urgent := "poca" in low or "bajo" in low or "baja" in low or "low" in low or "dañ" in low or "damaged" in low or "último" in low or "last day" in low
		if picked.is_empty() or (urgent and not ("poca" in picked.to_lower() or "bajo" in picked.to_lower() or "baja" in picked.to_lower() or "low" in picked.to_lower() or "dañ" in picked.to_lower() or "damaged" in picked.to_lower())):
			picked = line
	return picked if not picked.is_empty() else generic


func _on_sleep() -> void:
	if sleep_button.disabled:
		return
	sleep_button.disabled = true
	UiMotion.fade_out($Page, func() -> void:
		DayNightSystem.commit_night(_ration_id(), _powered_ids(), _option_id())
	)
