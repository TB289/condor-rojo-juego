extends Node
## Session-only Continue: preserve the actual live Main scene, not an approximate
## reconstruction of mission progress. Exiting the application ends this session.

const MAIN_SCENE := "res://scenes/Main.tscn"
var _game: Node2D = null
var _saved_modes: Array[Dictionary] = []
var _saved_layers: Array[Dictionary] = []
var _game_visible := true
var _restore_journal_pause := false

func has_game() -> bool:
	return is_instance_valid(_game)

func is_suspended() -> bool:
	return has_game() and get_tree().current_scene != _game

func park() -> bool:
	var current := get_tree().current_scene as Node2D
	if current == null or current.scene_file_path != MAIN_SCENE:
		return false
	discard()
	_game = current
	_game_visible = current.visible
	# A journal was already modal before the pause/menu detour.
	_restore_journal_pause = DayNightSystem.is_journal_open()
	_saved_modes.clear()
	_saved_layers.clear()
	_freeze(current)
	# CanvasLayer does not inherit CanvasItem visibility from Main (Node2D).
	current.hide()
	return true

func resume() -> bool:
	if not has_game():
		return false
	var game := _game
	var menu := get_tree().current_scene
	_game = null
	get_tree().current_scene = game
	game.visible = _game_visible
	for saved in _saved_layers:
		var layer := saved.get("node") as CanvasLayer
		if is_instance_valid(layer):
			layer.visible = bool(saved.get("visible", true))
	for saved in _saved_modes:
		var node := saved.get("node") as Node
		if is_instance_valid(node):
			node.process_mode = int(saved.get("mode", Node.PROCESS_MODE_INHERIT))
	_saved_modes.clear()
	_saved_layers.clear()
	if menu != null and menu != game:
		menu.queue_free()
	get_tree().paused = _restore_journal_pause
	_restore_journal_pause = false
	AudioManager.enter_gameplay()
	return true

func discard() -> void:
	if is_instance_valid(_game):
		_game.queue_free()
	_game = null
	_saved_modes.clear()
	_saved_layers.clear()
	_restore_journal_pause = false

func _freeze(node: Node) -> void:
	_saved_modes.append({"node": node, "mode": node.process_mode})
	if node is CanvasLayer:
		_saved_layers.append({"node": node, "visible": (node as CanvasLayer).visible})
		(node as CanvasLayer).visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children(true):
		_freeze(child)
