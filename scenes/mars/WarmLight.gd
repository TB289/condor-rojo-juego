class_name WarmLight
extends PointLight2D
## A small warm pool. Additive, no shadows, so Compatibility stays cheap.
## SurfaceLook.warm_lights_enabled turns every pool off.
## Named all_on so it does not clash with Light2D.enabled.

const TEX_SIZE := 64

static var all_on := true
static var _texture: Texture2D

@export var day_color := Color("ffe8b0")
@export var night_color := Color("ff8a58")
@export var day_energy := 0.2
@export var night_energy := 0.75
## Pink shift around sunset. Off for the cyan panel and antenna lights.
@export var sunset_tint := true

var lit := true


static func attach(
	parent: Node,
	at: Vector2,
	night: Color,
	scale: float,
	day_energy: float,
	night_energy: float,
	day: Color = Color("ffe8b0"),
	sunset: bool = true,
) -> WarmLight:
	var light := WarmLight.new()
	light.name = "WarmLight"
	light.position = at
	light.night_color = night
	light.day_color = day
	light.day_energy = day_energy
	light.night_energy = night_energy
	light.sunset_tint = sunset
	light.texture_scale = scale
	parent.add_child(light)
	return light


func _ready() -> void:
	blend_mode = Light2D.BLEND_MODE_ADD
	shadow_enabled = false
	texture = _soft_texture()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_apply()


func _process(_delta: float) -> void:
	_apply()


func _apply() -> void:
	var show := all_on and lit
	enabled = show
	visible = show
	if not show:
		return
	var night := DayNightSystem.night_amount()
	var glow := day_color.lerp(night_color, night)
	if sunset_tint:
		var sunset := smoothstep(0.2, 0.5, night) * (1.0 - smoothstep(0.72, 1.0, night))
		glow = glow.lerp(Color("ffc0a8"), sunset * 0.7)
	color = glow
	energy = lerpf(day_energy, night_energy, night)


static func _soft_texture() -> Texture2D:
	if _texture != null:
		return _texture
	var image := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(TEX_SIZE, TEX_SIZE) * 0.5
	var max_r := float(TEX_SIZE) * 0.5
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center) / max_r
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			image.set_pixel(x, y, Color(1, 1, 1, a))
	_texture = ImageTexture.create_from_image(image)
	return _texture
