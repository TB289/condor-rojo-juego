class_name IntiBox
extends Control
## Compact INTI line: small sun, short name, and the same pixel type as the world sign.
## IntiPanel, the intro, cutscenes and the debrief all instance this scene.

signal panel_pressed
signal close_pressed
signal typing_finished

const THEME := preload("res://ui/theme/condor_theme.tres")
const SUN := preload("res://assets/art/ui/inti_avatar.png")
const FONT: Font = preload("res://assets/fonts/m5x7.ttf")
const PORTRAIT_W := 28.0
const PAD_X := 5.0
const PAD_Y := 4.0
const GAP := 4.0
const NAME_H := 16.0
const FADE := 0.16
const MAX_RATIO := 0.52

@export var show_close: bool = true
@export var embedded: bool = false
@export var bottom_margin: float = 8.0
@export var right_inset: float = 8.0

var compact: bool = false

var _body := ""
var _tip := ""
var _count := 0
var _phase := 0
var _done := true
var _open := false
var _closing := false
var _fade := 0.0
var _elapsed := 0.0
var _step := 0.025
var _capture := false
var _text_width := 180.0
var _body_lines := 1

var portrait: PanelContainer
var name_chip: PanelContainer
var panel: PanelContainer
var line_label: Ink
var tip_label: Label
var status_label: Label
var close_button: Button
var arrow: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = THEME
	_build()
	_style_portrait()
	_style_chip()
	_style_panel()
	_style_close()
	_style_tip()
	_hide_widgets()
	Settings.language_changed.connect(_on_language)


func _exit_tree() -> void:
	if Settings.language_changed.is_connected(_on_language):
		Settings.language_changed.disconnect(_on_language)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _open and not _closing:
		_place()


func _process(delta: float) -> void:
	_refresh_hint()
	if _closing:
		_fade = maxf(0.0, _fade - delta / FADE)
		_apply_fade()
		if _fade <= 0.0:
			_closing = false
			_open = false
			_hide_widgets()
		return
	if _open:
		_fade = minf(1.0, _fade + delta / FADE)
		_apply_fade()
	if not _open or _done or not is_visible_in_tree():
		return
	_elapsed += delta
	var step := maxf(_step, 0.005)
	while _elapsed >= step and not _done:
		_elapsed -= step
		_advance()


func is_open() -> bool:
	return _open


func is_done() -> bool:
	return _open and _done


func is_compact() -> bool:
	return compact


func body_lines() -> int:
	return _body_lines


func set_compact(value: bool) -> void:
	if compact == value:
		return
	compact = value
	if _open and not _closing:
		_place()


func set_right_inset(value: float) -> void:
	if absf(value - right_inset) < 0.5:
		return
	right_inset = value
	if _open and not compact and not embedded and not _closing:
		_place()


func present(body: String, tip: String = "", step: float = 0.025, capture: bool = true) -> void:
	_body = body
	_tip = tip
	_count = 0
	_phase = 0
	_done = false
	_open = true
	_closing = false
	_fade = 0.0
	_elapsed = 0.0
	_step = step
	_capture = capture
	_apply_labels()
	line_label.visible_characters = 0
	tip_label.visible_characters = 0
	tip_label.hide()
	status_label.visible = false
	close_button.visible = show_close
	if arrow != null:
		arrow.hide()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if capture else Control.MOUSE_FILTER_IGNORE
	_show_widgets()
	_apply_fade()
	_place()
	if size.x < 2.0:
		_place.call_deferred()
	if _shown(_body).is_empty():
		_advance()


func retarget(body: String, tip: String = "") -> void:
	if not _open:
		return
	var count := _count
	var phase := _phase
	var done := _done
	_body = body
	_tip = tip
	_apply_labels()
	if done:
		_show_finished()
		return
	_count = count
	_phase = phase
	if phase == 0:
		line_label.visible_characters = mini(count, _shown(_body).length())
		tip_label.hide()
	else:
		line_label.visible_characters = -1
		tip_label.show()
		tip_label.visible_characters = mini(count, _shown(_tip).length())
	_place()


func finish_typing() -> void:
	if not _open or _done:
		return
	_show_finished()


func dismiss() -> void:
	if not _open:
		_hide_widgets()
		return
	_done = true
	_closing = true


func _advance() -> void:
	var body := _shown(_body)
	var tip := _shown(_tip)
	if _phase == 0:
		if _count < body.length():
			_count += 1
			line_label.visible_characters = _count
			return
		if tip.is_empty():
			_show_finished()
			return
		_phase = 1
		_count = 0
		tip_label.show()
		tip_label.visible_characters = 0
		_place()
		return
	if _count < tip.length():
		_count += 1
		tip_label.visible_characters = _count
		return
	_show_finished()


func _show_finished() -> void:
	if _done and _open and not _closing:
		line_label.visible_characters = -1
		return
	_done = true
	line_label.visible_characters = -1
	if _shown(_tip).is_empty():
		tip_label.hide()
	else:
		tip_label.show()
		tip_label.visible_characters = -1
	status_label.hide()
	close_button.visible = show_close
	if arrow != null:
		arrow.hide()
	_place()
	typing_finished.emit()


func _on_language(_lang: String) -> void:
	_refresh_hint()
	if status_label != null:
		status_label.text = ""
	if not _open:
		return
	var count := _count
	var phase := _phase
	var done := _done
	_apply_labels()
	if done:
		line_label.visible_characters = -1
		if _shown(_tip).is_empty():
			tip_label.hide()
		else:
			tip_label.show()
			tip_label.visible_characters = -1
		close_button.visible = show_close
		_place()
		return
	_done = false
	_count = count
	_phase = phase
	if phase == 0:
		line_label.visible_characters = mini(count, _shown(_body).length())
	elif tip_label.visible:
		line_label.visible_characters = -1
		tip_label.visible_characters = mini(count, _shown(_tip).length())


func _shown(stored: String) -> String:
	if stored.begins_with("intro.") and not stored.contains(" "):
		var line := Settings.text(stored)
		if line != stored:
			return line
	return Settings.visible_text(stored)


func _apply_labels() -> void:
	line_label.text = _shown(_body)
	tip_label.text = _shown(_tip)


func _show_widgets() -> void:
	portrait.show()
	name_chip.show()
	panel.show()
	if show_close:
		close_button.show()


func _hide_widgets() -> void:
	if portrait != null:
		portrait.hide()
	if name_chip != null:
		name_chip.hide()
	if panel != null:
		panel.hide()
	if close_button != null:
		close_button.hide()


func _place() -> void:
	if not _open:
		return
	_show_widgets()
	line_label.max_lines = 6 if embedded else 3
	if embedded:
		_place_embedded()
	elif compact:
		_place_compact()
	else:
		_place_dock()


func _place_dock() -> void:
	var view := _view_size()
	var margin := maxf(bottom_margin, 8.0)
	var left := margin
	var right := view.x - margin
	if right_inset > margin:
		right = minf(right, view.x - right_inset)
	for block in _avoid_rects(view):
		if block.position.y < view.y * 0.42 and block.end.y < view.y * 0.55:
			continue
		if block.end.x <= view.x * 0.46:
			left = maxf(left, block.end.x + 8.0)
		elif block.position.x >= view.x * 0.46:
			right = minf(right, block.position.x - 8.0)
	var room := maxf(right - left, 96.0)
	var max_w := minf(view.x * MAX_RATIO, room)
	var width := _width_for(max_w)
	var height := _height_for(width)
	var x := clampf(left, margin, maxf(margin, view.x - margin - width))
	if x + width > right and right - width >= margin:
		x = right - width
	var y := maxf(8.0, view.y - margin - height)
	_apply_panel(x, y, width, height)


func _place_compact() -> void:
	var view := _view_size()
	var max_w := minf(view.x * MAX_RATIO, view.x - 16.0)
	var width := _width_for(max_w)
	var height := _height_for(width)
	var x := clampf((view.x - width) * 0.5, 8.0, maxf(8.0, view.x - width - 8.0))
	_apply_panel(x, 8.0, width, height)


func _place_embedded() -> void:
	var width := maxf(size.x, 280.0)
	var height := _height_for(width)
	portrait.custom_minimum_size = Vector2(PORTRAIT_W, PORTRAIT_W)
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = height
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_END
	custom_minimum_size = Vector2(0, height)


func _apply_panel(x: float, y: float, width: float, height: float) -> void:
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = x
	panel.offset_top = y
	panel.offset_right = x + width
	panel.offset_bottom = y + height
	panel.grow_horizontal = Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.custom_minimum_size = Vector2(width, height)
	panel.size = Vector2(width, height)
	custom_minimum_size = Vector2.ZERO


func _width_for(max_w: float) -> float:
	var inner := maxf(max_w - _chrome(), 64.0)
	var natural := line_label.measure(8000.0).x
	var text_w := clampf(maxf(natural, 72.0), 72.0, inner)
	return minf(text_w + _chrome(), max_w)


func _height_for(width: float) -> float:
	var text_w := maxf(width - _chrome(), 64.0)
	_text_width = text_w
	_body_lines = line_label.lines_needed(text_w)
	var ink := line_label.measure(text_w)
	line_label.custom_minimum_size = Vector2(text_w, maxf(ink.y, NAME_H))
	var col := NAME_H + 2.0 + ink.y
	var tip := _shown(_tip)
	if not tip.is_empty() and tip_label.visible:
		col += 2.0 + _tip_height(tip, text_w)
	var inner := maxf(PORTRAIT_W, col)
	return inner + PAD_Y * 2.0


func _chrome() -> float:
	return PAD_X * 2.0 + PORTRAIT_W + GAP


func _tip_height(text: String, width: float) -> float:
	return FONT.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, 16).y


func _view_size() -> Vector2:
	var width := size.x
	var height := size.y
	if width < 2.0 or height < 2.0:
		var view := get_viewport_rect().size
		if width < 2.0:
			width = view.x
		if height < 2.0:
			height = view.y
	if width < 2.0:
		width = 640.0
	if height < 2.0:
		height = 360.0
	return Vector2(width, height)


func _avoid_rects(view: Vector2) -> Array[Rect2]:
	var found: Array[Rect2] = []
	var tree := get_tree()
	if tree == null:
		return found
	for node_name in ["ResourceRing", "Minimap"]:
		var node := tree.root.find_child(node_name, true, false) as Control
		if node != null and node.visible and node.size.x > 4.0 and node.size.y > 4.0:
			var rect := node.get_global_rect()
			if rect.position.y > view.y * 0.35:
				found.append(rect)
	if not _touch_shown():
		return found
	var stick := TouchControls._stick as Control
	if stick != null and stick.visible:
		found.append(stick.get_global_rect())
	var more := TouchControls._more as Control
	if more != null and more.visible:
		found.append(more.get_global_rect())
	for action in TouchControls._pads.keys():
		var pad := TouchControls._pads[action] as Control
		if pad != null and pad.visible:
			found.append(pad.get_global_rect())
	return found


func _touch_shown() -> bool:
	if TouchControls == null or not is_instance_valid(TouchControls):
		return false
	if not TouchControls.visible or not TouchControls._pads_visible:
		return false
	var root := TouchControls.get_node_or_null("Pads") as CanvasItem
	return root != null and root.visible


func _refresh_hint() -> void:
	if close_button == null:
		return
	close_button.text = _hint_text()


func _hint_text() -> String:
	var device := "key"
	if TouchControls != null and TouchControls.has_method(&"prompt_device"):
		device = String(TouchControls.call(&"prompt_device"))
	if device == "touch":
		return "×"
	return "E"


func _apply_fade() -> void:
	if panel != null:
		panel.modulate.a = _fade


func _build() -> void:
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	panel.gui_input.connect(_on_panel_input)
	add_child(panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(GAP))
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(row)

	portrait = PanelContainer.new()
	portrait.name = "Portrait"
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.clip_contents = true
	portrait.custom_minimum_size = Vector2(PORTRAIT_W, PORTRAIT_W)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait)
	var sun := TextureRect.new()
	sun.name = "Sun"
	sun.texture = SUN
	sun.custom_minimum_size = Vector2(PORTRAIT_W, PORTRAIT_W)
	sun.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sun.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sun.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sun.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(sun)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	row.add_child(column)

	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_theme_constant_override("separation", 4)
	column.add_child(name_row)

	name_chip = PanelContainer.new()
	name_chip.name = "NameChip"
	name_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(name_chip)
	var name_label := Label.new()
	name_label.text = "INTI"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_override("font", FONT)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Palette.ORO)
	name_label.add_theme_color_override("font_outline_color", Palette.ESPACIO)
	name_label.add_theme_constant_override("outline_size", 1)
	name_chip.add_child(name_label)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(spacer)

	close_button = Button.new()
	close_button.name = "Close"
	close_button.visible = false
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.flat = true
	close_button.text = "E"
	close_button.custom_minimum_size = Vector2(16, 14)
	close_button.pressed.connect(_on_corner)
	name_row.add_child(close_button)

	line_label = Ink.new()
	line_label.name = "Line"
	line_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_label.text = " "
	column.add_child(line_label)

	tip_label = Label.new()
	tip_label.name = "Tip"
	tip_label.visible = false
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(tip_label)

	status_label = Label.new()
	status_label.name = "Status"
	status_label.visible = false
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.text = ""

	arrow = null


func _on_corner() -> void:
	if not _done:
		panel_pressed.emit()
	else:
		close_pressed.emit()


func _on_panel_input(event: InputEvent) -> void:
	if not _capture:
		return
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed:
		panel_pressed.emit()
		panel.accept_event()
		return
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		panel_pressed.emit()
		panel.accept_event()


func _style_portrait() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.NAVY
	box.border_color = Palette.INTI
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.set_content_margin_all(0)
	box.anti_aliasing = false
	portrait.add_theme_stylebox_override("panel", box)


func _style_chip() -> void:
	var box := StyleBoxEmpty.new()
	name_chip.add_theme_stylebox_override("panel", box)


func _style_panel() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.051, 0.071, 0.11, 0.84)
	box.border_color = Color(Palette.INTI, 0.9)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = PAD_X
	box.content_margin_right = PAD_X
	box.content_margin_top = PAD_Y
	box.content_margin_bottom = PAD_Y
	box.anti_aliasing = false
	panel.add_theme_stylebox_override("panel", box)


func _style_close() -> void:
	var empty := StyleBoxEmpty.new()
	for kind in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		close_button.add_theme_stylebox_override(kind, empty)
	close_button.add_theme_font_override("font", FONT)
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.add_theme_color_override("font_color", Palette.METAL)
	close_button.add_theme_color_override("font_hover_color", Palette.CREMA)
	close_button.add_theme_color_override("font_pressed_color", Palette.CREMA)
	close_button.add_theme_color_override("font_outline_color", Palette.ESPACIO)
	close_button.add_theme_constant_override("outline_size", 1)


func _style_tip() -> void:
	tip_label.add_theme_font_override("font", FONT)
	tip_label.add_theme_font_size_override("font_size", 16)
	tip_label.add_theme_color_override("font_color", Palette.METAL)
	tip_label.add_theme_color_override("font_outline_color", Palette.ESPACIO)
	tip_label.add_theme_constant_override("outline_size", 1)


class Ink extends Control:
	const FONT: Font = preload("res://assets/fonts/m5x7.ttf")
	const SIZE := 16
	const CHIP := 12.0
	const GAP := 2.0
	const ICONS: Array[String] = ["stick", "hand", "sprint", "lamp", "plus", "jump"]

	var max_lines := 3
	var font_color := Palette.CREMA
	var _text := ""
	var _shown := -1

	var text: String:
		get:
			return _text
		set(value):
			if _text == value:
				return
			_text = value
			queue_redraw()

	var visible_characters: int:
		get:
			return _shown
		set(value):
			if _shown == value:
				return
			_shown = value
			queue_redraw()


	func measure(width: float) -> Vector2:
		return _measure(width, max_lines, true)


	func lines_needed(width: float) -> int:
		return _rows(width, 8, true).size()


	func _measure(width: float, cap: int, full: bool) -> Vector2:
		var rows := _rows(width, cap, full)
		var line_h := _line_h()
		var h := 0.0
		var w := 0.0
		for row in rows:
			w = maxf(w, float(row["w"]))
			h += line_h
		if rows.size() > 1:
			h += float(rows.size() - 1) * GAP
		if h < 1.0:
			h = line_h
		return Vector2(ceili(w), ceili(h))


	func _line_h() -> float:
		return maxf(float(FONT.get_height(SIZE)), CHIP)


	func _draw() -> void:
		var rows := _rows(size.x, max_lines, false)
		var line_h := _line_h()
		var y := 0.0
		for row in rows:
			var x := 0.0
			var pieces: Array = row["pieces"]
			for piece in pieces:
				if bool(piece["chip"]):
					var box := Rect2(x, y + (line_h - CHIP) * 0.5, float(piece["w"]), CHIP)
					_chip(box, String(piece["label"]))
				else:
					var baseline := Vector2(x, y + FONT.get_ascent(SIZE))
					_ink(baseline, String(piece["label"]))
				x += float(piece["w"]) + GAP
			y += line_h + GAP


	func _rows(width: float, cap: int, full: bool) -> Array:
		var limit := maxf(width, CHIP)
		var visible := _text if full or _shown < 0 else _prefix(_text, _shown)
		var tokens := _tokens(visible)
		var rows: Array = []
		var pieces: Array = []
		var row_w := 0.0
		for token in tokens:
			if bool(token["nl"]):
				if not pieces.is_empty():
					rows.append({"w": row_w, "pieces": pieces})
					pieces = []
					row_w = 0.0
				if rows.size() >= cap:
					break
				continue
			var piece_w := float(token["w"])
			var next := piece_w if pieces.is_empty() else row_w + GAP + piece_w
			if next > limit and not pieces.is_empty():
				rows.append({"w": row_w, "pieces": pieces})
				pieces = []
				row_w = 0.0
				if rows.size() >= cap:
					break
				next = piece_w
			if rows.size() >= cap:
				break
			pieces.append(token)
			row_w = next
		if rows.size() < cap and not pieces.is_empty():
			rows.append({"w": row_w, "pieces": pieces})
		if rows.is_empty():
			rows.append({"w": 0.0, "pieces": []})
		return rows


	func _tokens(source: String) -> Array:
		var out: Array = []
		var word := ""
		var i := 0
		while i < source.length():
			var ch := source[i]
			if ch == "\n":
				_push_word(out, word)
				word = ""
				out.append({"nl": true, "chip": false, "label": "", "w": 0.0})
				i += 1
				continue
			if ch == "[":
				var end := source.find("]", i + 1)
				if end > i:
					_push_word(out, word)
					word = ""
					var label := source.substr(i + 1, end - i - 1)
					out.append({"nl": false, "chip": true, "label": label, "w": _chip_w(label)})
					i = end + 1
					continue
			if ch == " ":
				_push_word(out, word)
				word = ""
				var space_w := FONT.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, SIZE).x
				out.append({"nl": false, "chip": false, "label": " ", "w": space_w})
				i += 1
				continue
			word += ch
			i += 1
		_push_word(out, word)
		return out


	func _push_word(out: Array, word: String) -> void:
		if word.is_empty():
			return
		var w := FONT.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, SIZE).x
		out.append({"nl": false, "chip": false, "label": word, "w": w})


	func _prefix(source: String, count: int) -> String:
		var cut := source.substr(0, mini(count, source.length()))
		var open := cut.rfind("[")
		var close := cut.rfind("]")
		if open > close:
			cut = cut.substr(0, open)
		return cut


	func _chip_w(label: String) -> float:
		if label in ICONS or label.length() <= 1:
			return CHIP
		var tw := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, SIZE).x
		return clampf(tw * 0.72 + 4.0, CHIP, 28.0)


	func _chip(box: Rect2, label: String) -> void:
		draw_rect(box, Palette.CREMA)
		draw_rect(Rect2(box.position + Vector2(1, 1), box.size - Vector2(2, 2)), Palette.ESPACIO)
		var inner := Rect2(box.position + Vector2(1, 1), box.size - Vector2(2, 2))
		if label in ICONS:
			_glyph(inner, label)
			return
		var key_size := 8
		var tw := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, key_size)
		var at := (inner.position + Vector2(
			(inner.size.x - tw.x) * 0.5,
			(inner.size.y - tw.y) * 0.5
		)).round()
		FONT.draw_string(get_canvas_item(), at + Vector2(0.0, FONT.get_ascent(key_size)), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, key_size, Palette.CREMA)


	func _glyph(inner: Rect2, label: String) -> void:
		var c := inner.position + inner.size * 0.5
		match label:
			"stick":
				draw_arc(c, 3.5, 0.0, TAU, 12, Palette.CREMA, 1.0, true)
				draw_circle(c, 1.4, Palette.CREMA)
			"hand":
				draw_rect(Rect2(c + Vector2(-2, 0), Vector2(4, 3)), Palette.CREMA)
				draw_rect(Rect2(c + Vector2(-1, -3), Vector2(2, 2)), Palette.CREMA)
			"sprint":
				draw_line(c + Vector2(-3, -2), c + Vector2(0, 0), Palette.CREMA, 1.0)
				draw_line(c + Vector2(0, 0), c + Vector2(-3, 2), Palette.CREMA, 1.0)
				draw_line(c + Vector2(0, -2), c + Vector2(3, 0), Palette.CREMA, 1.0)
				draw_line(c + Vector2(3, 0), c + Vector2(0, 2), Palette.CREMA, 1.0)
			"lamp":
				draw_circle(c + Vector2(0, 1), 2.0, Palette.CREMA)
				draw_line(c + Vector2(0, -4), c + Vector2(0, -2), Palette.CREMA, 1.0)
			"plus":
				draw_line(c + Vector2(-3, 0), c + Vector2(3, 0), Palette.CREMA, 1.0)
				draw_line(c + Vector2(0, -3), c + Vector2(0, 3), Palette.CREMA, 1.0)
			"jump":
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(0, -3), c + Vector2(-3, 3), c + Vector2(3, 3),
				]), Palette.CREMA)
			_:
				draw_rect(Rect2(c + Vector2(-2, -2), Vector2(4, 4)), Palette.CREMA)


	func _ink(baseline: Vector2, value: String) -> void:
		if value.strip_edges().is_empty():
			return
		for step in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			FONT.draw_string(get_canvas_item(), baseline + step, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, SIZE, Palette.ESPACIO)
		FONT.draw_string(get_canvas_item(), baseline, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, SIZE, font_color)
