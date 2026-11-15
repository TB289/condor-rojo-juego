class_name NightVision
extends CanvasLayer
## Outdoor night: a near-black mask, a tight hole at the helmet, and a long cone when the lamp is on.
## Lives inside the world SubViewport, so the HUD, the minimap and the menus stay bright.
## Compatibility. The edge is a smoothstep on the mask, not a blur of the sprites.

## Full-night hole, in viewport pixels at 640x360. Dusk lerps down to this from a wide circle.
@export var radius_px: float = 44.0
@export var softness_px: float = 11.0
@export var beam_length_px: float = 160.0
@export var beam_width_px: float = 31.0
@export var dark := Color(0.0509804, 0.0705882, 0.109804, 0.96)

var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	layer = 1
	_rect = ColorRect.new()
	_rect.name = "Mask"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color.WHITE
	add_child(_rect)
	var shader := load("res://assets/shaders/night_vision.gdshader") as Shader
	if shader == null:
		push_error("NightVision: shader missing.")
		_rect.hide()
		return
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_rect.material = _mat
	_rect.hide()


func _process(_delta: float) -> void:
	if _mat == null:
		return
	var show := _should_show()
	_rect.visible = show
	if not show:
		return
	var view := get_viewport().get_visible_rect().size
	if view.x < 2.0 or view.y < 2.0:
		view = Vector2(640, 360)
	_rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_rect.position = Vector2.ZERO
	_rect.size = view
	var player := get_tree().get_first_node_in_group(&"player") as Player
	var cam := get_viewport().get_camera_2d()
	if player == null or cam == null:
		_rect.hide()
		return
	var xform := get_viewport().get_canvas_transform()
	var body := player.global_position + player.helmet_light_local()
	var screen := xform * body
	screen = Vector2(floor(screen.x), floor(screen.y))
	var facing := player.facing_vector()
	var visor := xform * (body + facing * 6.0)
	visor = Vector2(floor(visor.x), floor(visor.y))
	var ahead := xform * (body + facing * 32.0)
	var dir := ahead - screen
	if dir.length_squared() < 0.001:
		dir = Vector2.DOWN
	else:
		dir = dir.normalized()
	var in_cave := GameState.interior_id == &"cave"
	# A lava tube has NO daylight. The rest of the surface still tracks dusk/dawn.
	var night := 1.0 if in_cave else DayNightSystem.night_amount()
	var hole := (22.0 if in_cave else lerpf(240.0, radius_px, night))
	var soft := (8.0 if in_cave else lerpf(16.0, softness_px, night))
	if player.is_flashlight_on():
		hole += 6.0
	_mat.set_shader_parameter("view_size", view)
	_mat.set_shader_parameter("player_px", screen)
	_mat.set_shader_parameter("beam_px", visor)
	_mat.set_shader_parameter("radius_px", hole)
	_mat.set_shader_parameter("softness_px", soft)
	_mat.set_shader_parameter("beam_length_px", 188.0 if in_cave else beam_length_px)
	# The cave beam reveals more peripheral geology without lighting the whole tube.
	_mat.set_shader_parameter("beam_width_px", 74.0 if in_cave else beam_width_px)
	_mat.set_shader_parameter("beam_dir", dir)
	_mat.set_shader_parameter("beam_on", 1.0 if player.is_flashlight_on() else 0.0)
	_mat.set_shader_parameter("amount", night)
	_mat.set_shader_parameter("dark", Color(0.018, 0.012, 0.024, 0.992) if in_cave else dark)


func _should_show() -> bool:
	if (GameState.interior_id != &"" and GameState.interior_id != &"cave") or GameState.run_over or BasePlacer.active:
		return false
	if Cutscenes.is_playing() or DayNightSystem.is_journal_open():
		return false
	return GameState.interior_id == &"cave" or DayNightSystem.night_amount() > 0.02
