extends CanvasLayer
## Screen-space visual filters. Lives above game, HUD and menus, but never eats input.
var _overlay: ColorRect
var _mat: ShaderMaterial

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	_overlay = ColorRect.new()
	_overlay.name = "VisualAccessibilityFilter"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color.WHITE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://assets/shaders/accessibility.gdshader")
	_overlay.material = _mat
	Settings.accessibility_changed.connect(_apply)
	_apply()

func _apply() -> void:
	_overlay.visible = Settings.accessibility_mode != 0
	_mat.set_shader_parameter("vision_mode", Settings.accessibility_mode)
