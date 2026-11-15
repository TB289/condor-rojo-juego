extends CanvasLayer
## Short fade between full scene changes. Interiors and cutscenes keep their own fades.
## The cover always comes back up, so the screen is not left dark.

const FADE := 0.32
const INK := Color(0.102, 0.047, 0.078, 1.0)

var _cover: ColorRect
var _busy := false


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cover = ColorRect.new()
	_cover.color = Color(INK.r, INK.g, INK.b, 0.0)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_cover)
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func change_scene(path: String) -> void:
	if _busy or path.is_empty():
		return
	_busy = true
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_cover, "color:a", 1.0, FADE)
	tween.tween_callback(_swap.bind(path))


func park_to_menu() -> void:
	if _busy:
		return
	_busy = true
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_cover, "color:a", 1.0, FADE)
	tween.tween_callback(_park_and_show_menu)


func resume_session() -> void:
	if _busy or not RunSession.has_game():
		return
	_busy = true
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_cover, "color:a", 1.0, FADE)
	tween.tween_callback(_resume_saved_scene)


func _park_and_show_menu() -> void:
	if not RunSession.park():
		push_error("Cannot preserve game scene for Continue")
		_reveal()
		return
	var packed := load("res://scenes/ui/MainMenu.tscn") as PackedScene
	var menu := packed.instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	_reveal.call_deferred()


func _resume_saved_scene() -> void:
	if not RunSession.resume():
		push_error("No suspended game to resume")
	_reveal.call_deferred()


func _swap(path: String) -> void:
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		_reveal()
		return
	_reveal.call_deferred()


func _reveal() -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(0.04)
	tween.tween_property(_cover, "color:a", 0.0, FADE)
	tween.tween_callback(func() -> void:
		if _cover != null:
			_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_busy = false
	)
