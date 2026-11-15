extends CanvasLayer
## Esc / Start on the map. The tree pauses; this layer stays awake so the buttons work.
## Returning to the menu suspends the live run; Continue restores it unchanged.

const MENU_SCENE := "res://scenes/ui/MainMenu.tscn"

@onready var _root: Control = $Root
@onready var _panel: Control = %Panel
@onready var _confirm: Control = %Confirm
@onready var _options: OptionsPanel = %Options

var _paused_here := false
var _closing := false
var _restart_tutorial_after_options := false
var _arranging := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.hide()
	_confirm.hide()
	%Resume.pressed.connect(_resume)
	%OpenOptions.pressed.connect(_open_options)
	%ToMenu.pressed.connect(_ask_menu)
	%Yes.pressed.connect(_to_menu)
	%No.pressed.connect(_close_confirm)
	_options.closed.connect(_on_options_closed)
	_options.tutorial_restart_requested.connect(_on_tutorial_restart_requested)
	_options.touch_arrange_requested.connect(_begin_arrange)
	TouchControls.arrange_finished.connect(_on_arrange_finished)
	Settings.language_changed.connect(_apply_language)
	_apply_language(Settings.lang)
	_wire_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if Cutscenes.is_playing():
		return
	var travel := get_tree().get_first_node_in_group(&"interior_travel") as InteriorTravel
	if travel != null and travel.busy:
		return
	if _options.visible:
		_options.close()
		get_viewport().set_input_as_handled()
		return
	if _confirm.visible:
		_close_confirm()
		get_viewport().set_input_as_handled()
		return
	if _root.visible:
		_resume()
		get_viewport().set_input_as_handled()
		return
	# The journal already paused the tree. Pause can still open on top of it.
	# Anything else that paused the tree (a cutscene, an ending) keeps Esc.
	if get_tree().paused and not DayNightSystem.is_journal_open():
		return
	_open()
	get_viewport().set_input_as_handled()


func _apply_language(_lang: String) -> void:
	%Title.text = Settings.text("pause.title")
	%Resume.text = Settings.text("pause.resume")
	%OpenOptions.text = Settings.text("menu.options")
	%ToMenu.text = Settings.text("pause.menu")
	%Sure.text = Settings.text("pause.sure")
	%Yes.text = Settings.text("pause.yes")
	%No.text = Settings.text("pause.no")


func _open() -> void:
	_closing = false
	_paused_here = not get_tree().paused
	_confirm.hide()
	_options.hide()
	_panel.show()
	_root.modulate.a = 0.0
	_root.show()
	UiMotion.fade_in(_root)
	get_tree().paused = true
	%Resume.grab_focus()


func _resume() -> void:
	if _closing:
		return
	_closing = true
	_confirm.hide()
	_options.hide()
	UiMotion.fade_out(_root, func() -> void:
		_closing = false
		_root.hide()
		_root.modulate.a = 1.0
		if _paused_here:
			get_tree().paused = false
		_paused_here = false
	)


func _open_options() -> void:
	_panel.hide()
	_options.open()


func _begin_arrange() -> void:
	_arranging = true
	_options.close()


func _on_arrange_finished() -> void:
	if not _arranging:
		return
	_arranging = false
	_options.hide()
	_confirm.hide()
	_panel.show()
	_root.modulate.a = 1.0
	_root.show()
	%Resume.grab_focus()


func _on_options_closed() -> void:
	if _arranging:
		_root.hide()
		TouchControls.begin_arrange()
		return
	_panel.show()
	if _restart_tutorial_after_options:
		_restart_tutorial_after_options = false
		_resume() # restore the world so the replay actually appears
	else:
		%Resume.grab_focus()


func _on_tutorial_restart_requested() -> void:
	_restart_tutorial_after_options = true


func _ask_menu() -> void:
	_panel.hide()
	_confirm.show()
	%No.grab_focus()


func _close_confirm() -> void:
	_confirm.hide()
	_panel.show()
	%ToMenu.grab_focus()


func _to_menu() -> void:
	# Keep the exact world / placed buildings / mission state / interior / rover
	# in memory. This is a session resume, not a disk save.
	_confirm.hide()
	_options.hide()
	_root.hide()
	_paused_here = false
	get_tree().paused = false
	SceneFade.park_to_menu()


func _wire_focus() -> void:
	var row: Array[Button] = [%Resume, %OpenOptions, %ToMenu]
	for i in row.size():
		var up := row[i - 1] if i > 0 else row[i]
		var down := row[i + 1] if i + 1 < row.size() else row[i]
		row[i].focus_neighbor_top = row[i].get_path_to(up)
		row[i].focus_neighbor_bottom = row[i].get_path_to(down)
		row[i].focus_neighbor_left = row[i].get_path_to(row[i])
		row[i].focus_neighbor_right = row[i].get_path_to(row[i])
	%Yes.focus_neighbor_left = %Yes.get_path_to(%Yes)
	%Yes.focus_neighbor_right = %Yes.get_path_to(%No)
	%Yes.focus_neighbor_top = %Yes.get_path_to(%Yes)
	%Yes.focus_neighbor_bottom = %Yes.get_path_to(%Yes)
	%No.focus_neighbor_left = %No.get_path_to(%Yes)
	%No.focus_neighbor_right = %No.get_path_to(%No)
	%No.focus_neighbor_top = %No.get_path_to(%No)
	%No.focus_neighbor_bottom = %No.get_path_to(%No)
