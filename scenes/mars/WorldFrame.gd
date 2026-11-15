class_name WorldFrame
extends SubViewportContainer
## Renders the world at the current logical viewport size, preserving aspect ratio on resize.
## HUD, menus and the minimap stay on the root viewport, so they are not warped.
## Mouse, physics and Y-sort stay in the SubViewport, in undistorted world space.

const VIEW := Vector2i(640, 360)

var _mat: ShaderMaterial

@onready var world: SubViewport = $World


func _enter_tree() -> void:
	add_to_group(&"world_frame")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	# Preserve a manually sized SubViewport; _fit_to_viewport expands the visible world
	# instead of squeezing it into a letterboxed or horizontally distorted image.
	stretch = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = Vector2(VIEW)
	world.size = VIEW
	world.disable_3d = true
	world.transparent_bg = false
	world.handle_input_locally = true
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world.snap_2d_transforms_to_pixel = true
	world.snap_2d_vertices_to_pixel = true
	world.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var night := preload("res://scenes/mars/NightVision.gd").new()
	night.name = "NightVision"
	world.add_child(night)
	var weather := preload("res://scenes/mars/WeatherCinematics.gd").new()
	weather.name = "WeatherCinematics"
	world.add_child(weather)
	var sign := WorldSign.new()
	sign.name = "WorldSign"
	world.add_child(sign)
	# Above the night mask, still in world space, so the mission mark stays bright.
	var marks := CanvasLayer.new()
	marks.name = "MissionMarks"
	marks.layer = 2
	marks.follow_viewport_enabled = true
	world.add_child(marks)
	var beacon := MissionBeacon.new()
	beacon.name = "MissionBeacon"
	marks.add_child(beacon)
	var shader := load("res://assets/shaders/world_view.gdshader") as Shader
	if shader == null:
		push_error("WorldFrame: world_view shader missing.")
	else:
		_mat = ShaderMaterial.new()
		_mat.shader = shader
		_mat.set_shader_parameter("use_screen", false)
		_mat.set_shader_parameter("world_tex", world.get_texture())
		_mat.set_shader_parameter("view_size", Vector2(VIEW))
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_fit_to_viewport):
		vp.size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()


## Fit to any display aspect ratio without black sidebars or stretched pixels.
## Godot's `expand` stretch grows the logical root viewport on wider/taller screens.
## The world SubViewport follows that logical size instead of stretching 640x360.
func _fit_to_viewport() -> void:
	var view := get_viewport_rect().size
	if view.x < 2.0 or view.y < 2.0:
		view = Vector2(VIEW)
	var logical := Vector2i(maxi(2, roundi(view.x)), maxi(2, roundi(view.y)))
	if world != null and world.size != logical:
		world.size = logical
	position = Vector2.ZERO
	size = Vector2(logical)
	scale = Vector2.ONE
	if _mat != null:
		_mat.set_shader_parameter("view_size", Vector2(logical))


## SurfaceLook calls this every frame. on = false clears the warp (raw nearest blit).
func apply_look(on: bool, perspective: float, curvature: float, band: float, tilt: float) -> void:
	if _mat == null:
		return
	if not on:
		material = null
		return
	_mat.set_shader_parameter("perspective", perspective)
	_mat.set_shader_parameter("curvature", curvature)
	_mat.set_shader_parameter("band_px", band)
	_mat.set_shader_parameter("tilt_strength", tilt)
	_mat.set_shader_parameter("view_size", Vector2(world.size))
	material = _mat


func get_world_root() -> Node:
	return world


func current_camera() -> Camera2D:
	return world.get_camera_2d()
