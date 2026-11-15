class_name WorldSign
extends Node2D
## The one interact line. It lives in the world, above the nearest usable object.
## It is not on a CanvasLayer, so the camera and the map carry it with the sprite.

const FONT: Font = preload("res://assets/fonts/m5x7.ttf")
const FONT_SIZE := 16
const GAP := 4.0
const FADE := 0.14
const PAD := 2
const ARROW := 3.0

var _action := ""
var _key := ""
var _show_icon := false
var _work := -1.0
var _alpha := 0.0
var _size := Vector2.ZERO
var _key_box := Vector2.ZERO
var _action_size := Vector2.ZERO


func _ready() -> void:
	z_as_relative = false
	z_index = 40
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2.ONE
	if not MissionSystem.work_progress.is_connected(_on_work):
		MissionSystem.work_progress.connect(_on_work)
	visible = false


func _exit_tree() -> void:
	if MissionSystem.work_progress.is_connected(_on_work):
		MissionSystem.work_progress.disconnect(_on_work)


func _process(delta: float) -> void:
	var focus: Dictionary = MissionSystem.prompt_focus()
	var raw := String(focus.get("text", ""))
	var node := focus.get("node") as Node2D
	var show := not raw.is_empty() and node != null and is_instance_valid(node)
	if show:
		_apply_line(raw)
		_layout()
		var top := anchor_for(node)
		global_position = (top + Vector2(0.0, -GAP)).round()
		_alpha = minf(1.0, _alpha + delta / FADE)
	else:
		_alpha = maxf(0.0, _alpha - delta / FADE)
	visible = _alpha > 0.01 and _size.x > 1.0
	modulate.a = _alpha
	queue_redraw()


## World point at the top-center of the object's sprite.
func anchor_for(node: Node2D) -> Vector2:
	# Doors know the exact location of their hatch. Query them BEFORE walking
	# up to a parent Entity that may contain unrelated decorative sprites.
	if node.has_method(&"sign_top"):
		var anchor: Vector2 = node.call(&"sign_top")
		if anchor.is_finite():
			return anchor
	var host := node
	if host is Area2D and host.get_parent() is Node2D:
		host = host.get_parent() as Node2D
	if host.has_method(&"sign_top"):
		var parent_anchor: Vector2 = host.call(&"sign_top")
		if parent_anchor.is_finite():
			return parent_anchor
	var sprite_top := _sprite_top(host)
	if sprite_top.is_finite():
		return sprite_top
	return host.global_position + Vector2(0.0, -22.0)


func _on_work(ratio: float) -> void:
	_work = ratio


func _apply_line(raw: String) -> void:
	var body := raw
	var keyed := false
	if body.begins_with("E: "):
		body = body.substr(3)
		keyed = true
	elif body.begins_with("E:"):
		body = body.substr(2).strip_edges()
		keyed = true
	_action = body
	_show_icon = false
	_key = ""
	if not keyed:
		return
	var device := "key"
	if TouchControls != null and TouchControls.has_method(&"prompt_device"):
		device = String(TouchControls.call(&"prompt_device"))
	if device == "touch":
		_show_icon = true
		return
	_key = Settings.interact_name()


func _layout() -> void:
	_action_size = FONT.get_string_size(_action, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE)
	var chip := Vector2.ZERO
	if _show_icon:
		chip = Vector2(9, 9)
	elif not _key.is_empty():
		var key_size := FONT.get_string_size(_key, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE)
		chip = Vector2(maxf(ceili(key_size.x) + 4.0, 9.0), maxf(ceili(key_size.y) + 2.0, 9.0))
	_key_box = chip
	var row := maxf(chip.y, _action_size.y)
	var gap := 2.0 if chip.x > 0.0 else 0.0
	var bar := 3.0 if _work >= 0.0 else 0.0
	var width := float(PAD) * 2.0 + chip.x + gap + _action_size.x
	var height := float(PAD) * 2.0 + row + bar
	_size = Vector2(ceili(width), ceili(height))


func _draw() -> void:
	if _size.x < 2.0:
		return
	var plate := Rect2(roundf(-_size.x * 0.5), -(ARROW + _size.y), _size.x, _size.y)
	var ink := Color(0.051, 0.071, 0.11, 0.88)
	_chamfer(plate, ink)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, plate.end.y),
		Vector2(2, plate.end.y),
		Vector2(0, plate.end.y + ARROW),
	]), ink)
	var row_h := plate.size.y - float(PAD) * 2.0 - (3.0 if _work >= 0.0 else 0.0)
	var row_top := plate.position.y + float(PAD)
	var text_x := plate.position.x + float(PAD)
	if _key_box.x > 0.0:
		var chip := Rect2(text_x, row_top + (row_h - _key_box.y) * 0.5, _key_box.x, _key_box.y)
		chip.position = chip.position.round()
		_chamfer(chip, Palette.CREMA)
		if _show_icon:
			_draw_hand(chip.position + Vector2(1, 1))
		else:
			var key_size := FONT.get_string_size(_key, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE)
			var key_at := chip.position + Vector2((chip.size.x - key_size.x) * 0.5, (chip.size.y - key_size.y) * 0.5)
			_ink(key_at.round(), _key, Palette.ESPACIO, false)
		text_x += _key_box.x + 2.0
	var action_at := Vector2(text_x, row_top + (row_h - _action_size.y) * 0.5)
	_ink(action_at.round(), _action, Palette.CREMA, true)
	if _work < 0.0:
		return
	var bar := Rect2(plate.position.x + 2.0, plate.end.y - 3.0, plate.size.x - 4.0, 2.0)
	draw_rect(bar, Palette.NAVY)
	draw_rect(Rect2(bar.position, Vector2(maxf(bar.size.x * clampf(_work, 0.0, 1.0), 1.0), bar.size.y)), Palette.INTI)


func _ink(at: Vector2, text: String, color: Color, outline: bool) -> void:
	var baseline := at + Vector2(0.0, FONT.get_ascent(FONT_SIZE))
	if outline:
		for step in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			FONT.draw_string(get_canvas_item(), baseline + step, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, Palette.ESPACIO)
	FONT.draw_string(get_canvas_item(), baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, color)


func _chamfer(rect: Rect2, color: Color) -> void:
	if rect.size.x < 3.0 or rect.size.y < 3.0:
		draw_rect(rect, color)
		return
	draw_rect(Rect2(rect.position.x + 1.0, rect.position.y, rect.size.x - 2.0, rect.size.y), color)
	draw_rect(Rect2(rect.position.x, rect.position.y + 1.0, 1.0, rect.size.y - 2.0), color)
	draw_rect(Rect2(rect.end.x - 1.0, rect.position.y + 1.0, 1.0, rect.size.y - 2.0), color)


func _draw_hand(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(1, 3), Vector2(5, 4)), Palette.ESPACIO)
	draw_rect(Rect2(at + Vector2(2, 1), Vector2(3, 2)), Palette.ESPACIO)


func _sprite_top(host: Node2D) -> Vector2:
	var best_y := 0.0
	var best_x := 0.0
	var found := false
	var items: Array[CanvasItem] = []
	if host is Sprite2D:
		items.append(host)
	for child in host.get_children():
		if child is Sprite2D:
			items.append(child)
	for item in items:
		var local := _sprite_local_top(item as Sprite2D)
		if not local.is_finite():
			continue
		if not found or local.y < best_y:
			found = true
			best_y = local.y
			best_x = local.x
	if not found:
		return Vector2(INF, INF)
	return host.to_global(Vector2(best_x, best_y))


func _sprite_local_top(sprite: Sprite2D) -> Vector2:
	var size := Vector2.ZERO
	if sprite.region_enabled:
		size = sprite.region_rect.size
	elif sprite.texture != null:
		size = sprite.texture.get_size()
	if size.y < 1.0:
		return Vector2(INF, INF)
	var scale := Vector2(absf(sprite.scale.x), absf(sprite.scale.y))
	var center_x := sprite.position.x + sprite.offset.x
	var top_y := sprite.position.y + sprite.offset.y
	if sprite.centered:
		top_y -= size.y * 0.5 * scale.y
	else:
		center_x += size.x * 0.5 * scale.x
	return Vector2(center_x, top_y)
