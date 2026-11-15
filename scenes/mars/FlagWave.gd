extends Sprite2D
## Plants the mast on this node's origin and waves only the cloth.
## The texture is the short flag: pole 2 px, cloth 26x14, canvas 32x24.
## pole_u is POLE_PX / width. Do not stretch the cloth.


const POLE_PX := 2.0

var _time := 0.0
var _shader_on := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if texture == null:
		return
	var width := float(texture.get_width())
	var height := float(texture.get_height())
	# Center of the 2 px mast stays on the node. The cloth hangs to the right.
	offset = Vector2(width * 0.5 - POLE_PX * 0.5, -height * 0.5)
	var shader := load("res://assets/shaders/flag_wave.gdshader") as Shader
	if shader == null:
		return
	var wave := ShaderMaterial.new()
	wave.shader = shader
	wave.set_shader_parameter("pole_u", POLE_PX / maxf(width, 1.0))
	material = wave
	_shader_on = true


func _process(delta: float) -> void:
	if _shader_on:
		return
	_time += delta
	rotation = sin(_time * 5.2) * 0.08
