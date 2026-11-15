class_name MarsVista
extends Control
## Shared dusk and night backdrop. Wide pyramidal ridges, not blocks and not needles.
## Camp uses the project's own sprites. Nothing here is copied from another game.

const VIEW_W := 640
const TEX_W := 672
const TEX_H := 360
const SLOPE := 0.52

@export var night := false
@export var show_camp := false
@export var veil := false
@export var drift := true
## Smaller planet, high in the sky, so the debrief card does not cover it.
@export var debrief_sky := false

var _t := 0.0
var _far: TextureRect
var _mid: TextureRect
var _near: TextureRect
var _dust: Control
var _camp: Control
var _motes: Array[Vector3] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _camp != null:
		# Keep the foreground artwork centered on ultrawide windows.
		_camp.position.x = maxf(0.0, (size.x - float(VIEW_W)) * 0.5)


func _process(delta: float) -> void:
	if not drift:
		return
	_t += delta
	if _far != null:
		_far.position.x = round(-16.0 + sin(_t * 0.18) * 5.0)
	if _mid != null:
		_mid.position.x = round(-16.0 + sin(_t * 0.31 + 1.2) * 8.0)
	if _near != null:
		_near.position.x = round(-16.0 + sin(_t * 0.46 + 0.4) * 11.0)
	_step_dust(delta)
	if _dust != null:
		_dust.queue_redraw()


func _build() -> void:
	var sky := _sky_image()
	_layer(sky, -8.0)
	_layer(_blink_image(), -8.0, true)
	var far_h := _mask([90, 340, 590], [28, 36, 30])
	var mid_h := _mask([40, 280, 520], [46, 58, 50])
	var near_h := _mask([160, 430], [34, 40])
	if night:
		_far = _layer(_ridge(far_h, 206, Palette.TERRACOTA.lerp(Palette.BRUMA, 0.55), Palette.PURPURA.lerp(Palette.NAVY, 0.4), Palette.NARANJA, 0.9), -16.0)
		_mid = _layer(_ridge(mid_h, 230, Palette.CONTORNO, Palette.SOMBRA, Palette.NARANJA, 1.0), -16.0)
		_near = _layer(_ridge(near_h, 254, Palette.SOMBRA, Palette.CONTORNO, Palette.SOL, 1.0), -16.0)
	else:
		_far = _layer(_ridge(far_h, 198, Palette.ARENA.lerp(Palette.BRUMA, 0.28), Palette.TERRACOTA.lerp(Palette.BRUMA, 0.35), Palette.SOL, 0.92), -16.0)
		_mid = _layer(_ridge(mid_h, 224, Palette.CONTORNO, Palette.PURPURA, Palette.NARANJA, 1.0), -16.0)
		_near = _layer(_ridge(near_h, 250, Palette.SOMBRA, Palette.CONTORNO, Palette.SOL, 1.0), -16.0)
	_layer(_plain_image(), 0.0)
	if show_camp:
		_build_camp()
	_layer(_rocks_image(), 0.0)
	if veil:
		_layer(_veil_image(), 0.0)
	_dust = Control.new()
	_dust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dust.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dust.draw.connect(_draw_dust)
	add_child(_dust)
	_seed_dust()


func _sky_image() -> Image:
	var image := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	for y in range(0, TEX_H, 2):
		var t := float(y) / float(TEX_H - 1)
		var color := _sky_color(t)
		image.fill_rect(Rect2i(0, y, TEX_W, 2), color)
	_stars(image, night)
	if night:
		if debrief_sky:
			_planet(image, Vector2i(548, 28), 16)
			_sphere(image, Vector2i(470, 22), 5, Palette.METAL, Palette.CREMA, Palette.SOMBRA)
		else:
			_planet(image, Vector2i(534, 78), 40)
			_sphere(image, Vector2i(468, 56), 6, Palette.METAL, Palette.CREMA, Palette.SOMBRA)
		image.fill_rect(Rect2i(0, 236, TEX_W, 10), Color(Palette.BRUMA, 0.55))
	else:
		_sun(image, Vector2i(118, 154), 54)
		_sphere(image, Vector2i(548, 34), 7, Palette.TERRACOTA, Palette.POLVO, Palette.SOMBRA)
		_sphere(image, Vector2i(582, 26), 5, Palette.METAL, Palette.CREMA, Palette.NAVY)
		_sphere(image, Vector2i(604, 48), 4, Palette.PURPURA, Palette.ARENA, Palette.SOMBRA)
	return image


func _sky_color(t: float) -> Color:
	if night:
		if t < 0.42:
			return Palette.ESPACIO.lerp(Palette.NAVY, t / 0.42)
		if t < 0.7:
			return Palette.NAVY.lerp(Palette.BRUMA, (t - 0.42) / 0.28)
		return Palette.BRUMA.lerp(Palette.SOMBRA, (t - 0.7) / 0.3)
	if t < 0.16:
		return Palette.ESPACIO.lerp(Palette.NAVY, t / 0.16)
	if t < 0.32:
		return Palette.NAVY.lerp(Palette.SOMBRA, (t - 0.16) / 0.16)
	if t < 0.46:
		return Palette.SOMBRA.lerp(Palette.CONTORNO, (t - 0.32) / 0.14)
	if t < 0.58:
		return Palette.CONTORNO.lerp(Palette.PURPURA, (t - 0.46) / 0.12)
	if t < 0.72:
		return Palette.PURPURA.lerp(Palette.NARANJA, (t - 0.58) / 0.14)
	if t < 0.84:
		return Palette.NARANJA.lerp(Palette.ARENA, (t - 0.72) / 0.12)
	return Palette.ARENA.lerp(Palette.TERRACOTA, (t - 0.84) / 0.16)


func _stars(image: Image, more: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var count := 70 if more else 42
	var limit := int(TEX_H * (0.62 if more else 0.48))
	for i in count:
		var x := rng.randi_range(2, TEX_W - 3)
		var y := rng.randi_range(2, limit)
		var color := Palette.CREMA if rng.randf() > 0.2 else Palette.SOL
		image.set_pixel(x, y, color)
		if rng.randf() > 0.82:
			image.set_pixel(x + 1, y, color)


func _blink_image() -> Image:
	var image := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for i in 8:
		var x := rng.randi_range(8, TEX_W - 8)
		var y := rng.randi_range(6, 120)
		image.set_pixel(x, y, Palette.CREMA)
		image.set_pixel(x, y + 1, Color(Palette.CREMA, 0.6))
	return image


func _sun(image: Image, center: Vector2i, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if not _inside(image, x, y):
				continue
			var d := Vector2(x - center.x, y - center.y).length()
			if d > float(radius):
				continue
			var color := Palette.SOL
			if y % 3 == 0:
				color = Palette.CREMA
			elif y % 3 == 1:
				color = Palette.SOL.lerp(Palette.NARANJA, 0.28)
			if d > float(radius) - 1.2:
				color = Palette.CONTORNO
			image.set_pixel(x, y, color)


func _planet(image: Image, center: Vector2i, radius: int) -> void:
	var seas: Array[Vector3] = [
		Vector3(-8, 8, 13),
		Vector3(11, -2, 7),
		Vector3(-1, -10, 5),
	]
	for y in range(center.y - radius - 1, center.y + radius + 2):
		for x in range(center.x - radius - 1, center.x + radius + 2):
			if not _inside(image, x, y):
				continue
			var rel := Vector2(x - center.x, y - center.y)
			var d := rel.length()
			if d > float(radius):
				continue
			var ny := rel.y / float(radius)
			var color := Palette.TERRACOTA
			if ny < -0.78:
				color = Palette.POLVO
			for sea in seas:
				var sd := Vector2(rel.x - sea.x, rel.y - sea.y).length()
				if sd < sea.z:
					color = Palette.TERRACOTA.lerp(Palette.PURPURA, 0.55 * (1.0 - sd / sea.z))
			if rel.x < float(-radius) * 0.55 and rel.y < float(-radius) * 0.15:
				color = color.lerp(Palette.ARENA, 0.4)
			elif rel.x > float(radius) * 0.72:
				color = color.lerp(Palette.SOMBRA, 0.65)
			if d > float(radius) - 1.1:
				color = Palette.CONTORNO
			image.set_pixel(x, y, color)
	_crater(image, center + Vector2i(-8, 2), 5)
	_crater(image, center + Vector2i(12, 8), 3)
	_crater(image, center + Vector2i(2, -8), 4)


func _crater(image: Image, center: Vector2i, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if not _inside(image, x, y):
				continue
			var d := Vector2(x - center.x, y - center.y).length()
			if d >= float(radius) - 1.2 and d <= float(radius):
				image.set_pixel(x, y, Palette.CONTORNO)


func _sphere(image: Image, center: Vector2i, radius: int, body: Color, light: Color, dark: Color) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if not _inside(image, x, y):
				continue
			var rel := Vector2(x - center.x, y - center.y)
			if rel.length() > float(radius):
				continue
			var color := body
			if rel.x < -radius * 0.15 and rel.y < radius * 0.2:
				color = light
			elif rel.x > radius * 0.3:
				color = dark
			image.set_pixel(x, y, color)


func _mask(peaks: Array, heights: Array) -> PackedInt32Array:
	var mask := PackedInt32Array()
	mask.resize(TEX_W)
	for i in peaks.size():
		var cx := int(peaks[i])
		var h := int(heights[i])
		var cap := 10
		var half := int(round(float(h) / SLOPE))
		var x0 := maxi(cx - half, 0)
		var x1 := mini(cx + half, TEX_W - 1)
		for x in range(x0, x1 + 1):
			var dx := absi(x - cx)
			var y := 0
			if dx <= cap:
				y = h - int(round(float(dx) * 0.35))
			else:
				var run := maxi(half - cap, 1)
				var t := float(dx - cap) / float(run)
				y = int(round(float(h - 2) * (1.0 - t)))
			if y > mask[x]:
				mask[x] = y
	return mask


func _ridge(mask: PackedInt32Array, baseline: int, body: Color, band: Color, rim: Color, alpha: float) -> Image:
	var image := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for x in TEX_W:
		var h := mask[x]
		if h <= 1:
			continue
		var climbing := x == 0 or mask[x] >= mask[x - 1]
		var top := baseline - h
		for y in range(top, mini(baseline + 8, TEX_H)):
			if y < 0:
				continue
			var down := y - top
			var color := body
			if down % 6 == 5:
				color = band
			if down == 0:
				color = Palette.CONTORNO
			elif down <= 2 and climbing:
				color = rim
			elif not climbing and down <= 2:
				color = band
			elif not climbing and down % 6 >= 4:
				color = band.lerp(Palette.SOMBRA, 0.55)
			color.a = alpha
			image.set_pixel(x, y, color)
	return image


func _plain_image() -> Image:
	var image := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var horizon := 256
	for y in range(horizon, TEX_H):
		var color := Palette.TERRACOTA
		if night:
			color = Palette.CONTORNO.lerp(Palette.TERRACOTA, 0.22)
			if y == horizon + 22 or y == horizon + 48:
				color = Palette.SOMBRA
			if y < horizon + 8:
				color = Palette.BRUMA
		else:
			if y < horizon + 5:
				color = Palette.POLVO if y % 2 == 0 else Palette.NARANJA
			elif y == horizon + 20 or y == horizon + 46:
				color = Palette.SOMBRA
		image.fill_rect(Rect2i(0, y, TEX_W, 1), color)
	return image


func _rocks_image() -> Image:
	var image := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var spots: Array[Vector3] = [
		Vector3(28, 338, 22),
		Vector3(70, 346, 14),
		Vector3(118, 342, 18),
		Vector3(168, 350, 10),
		Vector3(210, 340, 16),
		Vector3(262, 348, 12),
		Vector3(610, 344, 18),
		Vector3(648, 336, 20),
		Vector3(40, 352, 6),
		Vector3(96, 354, 4),
		Vector3(150, 356, 5),
		Vector3(230, 355, 4),
		Vector3(300, 350, 8),
		Vector3(560, 352, 7),
	]
	for spot in spots:
		_rock(image, int(spot.x), int(spot.y), int(spot.z), int(maxi(spot.z * 0.62, 4)))
	return image


func _rock(image: Image, cx: int, cy: int, rx: int, ry: int) -> void:
	var body := Palette.SOMBRA if night else Palette.CONTORNO
	var light := Palette.NARANJA if not night else Palette.TERRACOTA
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			if not _inside(image, x, y):
				continue
			var nx := float(x - cx) / float(maxi(rx, 1))
			var ny := float(y - cy) / float(maxi(ry, 1))
			if nx * nx + ny * ny > 1.0:
				continue
			var color := body
			if nx < -0.15 and ny < 0.2:
				color = light
			elif nx > 0.4:
				color = Palette.SOMBRA
			if ny < -0.72:
				color = Palette.CONTORNO
			image.set_pixel(x, y, color)


func _veil_image() -> Image:
	var image := Image.create(VIEW_W, TEX_H, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for x in 280:
		var a := 0.62 * (1.0 - float(x) / 280.0)
		a = a * a
		image.fill_rect(Rect2i(x, 0, 1, TEX_H), Color(Palette.ESPACIO, a))
	return image


func _build_camp() -> void:
	var camp := Control.new()
	camp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camp.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(camp)
	_camp = camp
	_camp.position.x = maxf(0.0, (size.x - float(VIEW_W)) * 0.5)
	# Menu and gameplay now share one contiguous landed spacecraft exterior.
	_sprite(camp, "res://assets/art/base/ship_integrated.png", Vector2(397, 175), 1)
	# Power generation stays a separate, exterior installation.
	_sprite(camp, "res://assets/art/base/solar_panel.png", Vector2(424, 259), 2)
	var flag := _sprite(camp, "res://assets/art/base/flag_ecuador.png", Vector2(381, 252), 2)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/flag_wave.gdshader") as Shader
	mat.set_shader_parameter("pole_u", 0.0625)
	flag.material = mat
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/art/characters/astronaut_idle.png")
	atlas.region = Rect2(0, 64, 32, 32)
	var astro := TextureRect.new()
	astro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	astro.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	astro.texture = atlas
	astro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	astro.stretch_mode = TextureRect.STRETCH_SCALE
	astro.position = Vector2(324, 236)
	astro.custom_minimum_size = Vector2(64, 64)
	astro.size = Vector2(64, 64)
	camp.add_child(astro)


func _sprite(parent: Control, path: String, at: Vector2, scale: int) -> TextureRect:
	var tex := load(path) as Texture2D
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.position = at
	var dims := tex.get_size() * float(scale)
	rect.custom_minimum_size = dims
	rect.size = dims
	parent.add_child(rect)
	return rect


func _layer(image: Image, x: float, blink: bool = false) -> TextureRect:
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.texture = ImageTexture.create_from_image(image)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	# These are BACKGROUND layers; anchor them to all four edges so expanding
	# the viewport doesn't reveal a dark empty strip on the right.
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.offset_left = x
	rect.offset_top = 0.0
	rect.offset_right = -x
	rect.offset_bottom = 0.0
	add_child(rect)
	if blink:
		var tween := create_tween().set_loops()
		tween.tween_property(rect, "modulate:a", 0.15, 0.7)
		tween.tween_property(rect, "modulate:a", 1.0, 0.7)
	return rect


func _seed_dust() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 16:
		_motes.append(Vector3(rng.randf_range(0, VIEW_W), rng.randf_range(180, 340), rng.randf_range(4, 10)))


func _step_dust(delta: float) -> void:
	for i in _motes.size():
		var mote := _motes[i]
		mote.x -= mote.z * delta
		if mote.x < -2.0:
			mote.x = VIEW_W + 2.0
		_motes[i] = mote


func _draw_dust() -> void:
	for mote in _motes:
		var w := 2 if int(mote.y) % 3 == 0 else 1
		_dust.draw_rect(Rect2(mote.x, mote.y, w, 1), Color(Palette.POLVO, 0.55))


func _inside(image: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height()
