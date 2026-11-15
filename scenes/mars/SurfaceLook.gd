class_name SurfaceLook
extends Node
## Outdoor picture: dust shadows, contact ovals and warm lights.
## Perspective, curvature and tilt-shift default to 0, so the world is a
## 1:1 nearest blit (WorldFrame drops the material when all strengths are 0).
## The toggles and strength exports stay so each one can be turned back on.
## While the game is running, select this node on MarsMap to turn each one off.
## world_warp_enabled turns off perspective and curvature together.
## perspective_enabled and curvature_enabled are the separate switches.
## tilt_shift_enabled, dust_shadows_enabled, shadows_enabled, warm_lights_enabled stay from S16.
## Indoors, in cutscenes and in menus the whole picture effect is off.

@export var shadows_enabled := true
@export var tilt_shift_enabled := true
@export_range(0.0, 120.0, 1.0) var tilt_band_px := 20.0
@export_range(0.0, 1.0, 0.01) var tilt_strength := 0.0
@export var world_warp_enabled := true
@export var perspective_enabled := true
@export_range(0.0, 0.25, 0.005) var perspective_strength := 0.0
@export var curvature_enabled := true
@export_range(0.0, 0.12, 0.005) var curvature_strength := 0.0
@export var dust_shadows_enabled := true
@export var warm_lights_enabled := true

var _veil: DustVeil
var _fallback: CanvasLayer
var _fallback_mat: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = DustVeil.new()
	_veil.name = "DustShadows"
	get_parent().add_child(_veil)
	var motes := preload("res://scenes/mars/DustMotes.gd").new()
	motes.name = "DustMotes"
	get_parent().add_child(motes)


func _process(_delta: float) -> void:
	GroundShadow.enabled = shadows_enabled
	WarmLight.all_on = warm_lights_enabled
	if _veil != null:
		_veil.enabled = dust_shadows_enabled
	var outside := _outdoor()
	var warp := world_warp_enabled and outside
	var persp := perspective_strength if warp and perspective_enabled else 0.0
	var curve := curvature_strength if warp and curvature_enabled else 0.0
	var tilt_on := tilt_shift_enabled and outside
	var band := tilt_band_px if tilt_on else 0.0
	var strength := tilt_strength if tilt_on else 0.0
	var on := persp > 0.001 or curve > 0.001 or (tilt_on and strength > 0.001)
	var frame := get_tree().get_first_node_in_group(&"world_frame")
	if frame != null and frame.has_method(&"apply_look"):
		_drop_fallback()
		frame.call(&"apply_look", on, persp, curve, band, strength)
		return
	_ensure_fallback()
	if _fallback != null:
		_fallback.visible = on
	if _fallback_mat != null:
		_fallback_mat.set_shader_parameter("perspective", persp)
		_fallback_mat.set_shader_parameter("curvature", curve)
		_fallback_mat.set_shader_parameter("band_px", band)
		_fallback_mat.set_shader_parameter("tilt_strength", strength)


func _outdoor() -> bool:
	if GameState.interior_id != &"":
		return false
	if Cutscenes.is_playing() or get_tree().paused or DayNightSystem.is_journal_open():
		return false
	return true


func _drop_fallback() -> void:
	if _fallback == null:
		return
	_fallback.queue_free()
	_fallback = null
	_fallback_mat = null


## MarsMap opened on its own, with no WorldFrame. Same shader, sampling the screen.
func _ensure_fallback() -> void:
	if _fallback != null:
		return
	var shader := load("res://assets/shaders/world_view.gdshader") as Shader
	if shader == null:
		push_warning("SurfaceLook: world shader missing.")
		return
	_fallback_mat = ShaderMaterial.new()
	_fallback_mat.shader = shader
	_fallback_mat.set_shader_parameter("use_screen", true)
	_fallback_mat.set_shader_parameter("view_size", Vector2(640, 360))
	var blank := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	blank.fill(Color.BLACK)
	_fallback_mat.set_shader_parameter("world_tex", ImageTexture.create_from_image(blank))
	var layer := CanvasLayer.new()
	layer.name = "WorldView"
	layer.layer = 1
	var copy := BackBufferCopy.new()
	copy.name = "Copy"
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	var root := Control.new()
	root.name = "Full"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect := ColorRect.new()
	rect.name = "Band"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color.WHITE
	rect.material = _fallback_mat
	root.add_child(rect)
	layer.add_child(copy)
	layer.add_child(root)
	add_child(layer)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fallback = layer
