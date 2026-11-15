class_name UiMotion
extends RefCounted
## Fade a panel in or out. Position stays where the layout put it.


static func fade_in(node: CanvasItem, seconds: float = 0.16) -> void:
	if node == null:
		return
	_kill(node)
	node.modulate.a = 0.0
	var tween := node.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(node, "modulate:a", 1.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	node.set_meta(&"_ui_tween", tween)


static func fade_out(node: CanvasItem, then: Callable, seconds: float = 0.12) -> void:
	if node == null:
		then.call()
		return
	_kill(node)
	var tween := node.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(node, "modulate:a", 0.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(then)
	node.set_meta(&"_ui_tween", tween)


static func _kill(node: CanvasItem) -> void:
	if not node.has_meta(&"_ui_tween"):
		return
	var old: Variant = node.get_meta(&"_ui_tween")
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
