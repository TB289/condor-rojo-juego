class_name RoverArchivePanel
extends CanvasLayer
## Fact card and quiz for a rover archive. Completes the mission objective only after a correct answer.

const FONT := preload("res://assets/fonts/m5x7.ttf")
const DATA_PATH := "res://data/mission1_rovers.json"

var _mission := &""
var _objective := ""
var _rover: Dictionary = {}
var _answers: Array = []
var _chosen := -1

@onready var _title: Label = $Shade/Center/Panel/Margin/Layout/Title
@onready var _lesson: Label = $Shade/Center/Panel/Margin/Layout/Scroll/Lesson
@onready var _question: Label = $Shade/Center/Panel/Margin/Layout/Question
@onready var _choices: VBoxContainer = $Shade/Center/Panel/Margin/Layout/Choices
@onready var _status: Label = $Shade/Center/Panel/Margin/Layout/Status
@onready var _confirm: Button = $Shade/Center/Panel/Margin/Layout/Buttons/Confirm
@onready var _close: Button = $Shade/Center/Panel/Margin/Layout/Buttons/CloseBtn


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 70
	_confirm.pressed.connect(_on_confirm)
	_close.pressed.connect(_on_close)
	Settings.language_changed.connect(_refresh_language)
	_refresh_language(Settings.lang)


func present(rover_id: String, mission_id: StringName, objective_id: String) -> void:
	_mission = mission_id
	_objective = objective_id
	_rover = _find_rover(rover_id)
	_chosen = -1
	visible = true
	get_tree().paused = true
	_refresh_language(Settings.lang)
	_close.grab_focus()


func _find_rover(rover_id: String) -> Dictionary:
	if not FileAccess.file_exists(DATA_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		for row in (parsed as Dictionary).get("rovers", []):
			if row is Dictionary and String(row.get("id", "")) == rover_id:
				return row
	return {}


func _refresh_language(_lang: String) -> void:
	_close.text = Settings.text("common.back")
	_confirm.text = Settings.text("archive.question")
	if _rover.is_empty():
		_title.text = Settings.text("archive.missing")
		_lesson.text = ""
		_question.text = ""
		_status.text = ""
		_clear_choices()
		_confirm.visible = false
		return
	var name := String(_rover.get("name", ""))
	var year := String(_rover.get("year", ""))
	_title.text = "%s  ·  %s" % [name, year] if not year.is_empty() else name
	_lesson.text = String(_rover.get("lesson_es" if Settings.lang == "es" else "lesson_en", ""))
	_question.text = String(_rover.get("question_es" if Settings.lang == "es" else "question_en", ""))
	_answers = _rover.get("answers_es" if Settings.lang == "es" else "answers_en", [])
	_build_choices()
	_status.text = ""
	_confirm.visible = true
	_confirm.text = Settings.text("archive.check")
	_confirm.disabled = _chosen < 0


func _clear_choices() -> void:
	for child in _choices.get_children():
		child.queue_free()


func _build_choices() -> void:
	_clear_choices()
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for i in _answers.size():
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.text = "  %s" % str(_answers[i])
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 28)
		button.set_pressed_no_signal(i == _chosen)
		var idx := i
		button.pressed.connect(func() -> void:
			_chosen = idx
			_confirm.disabled = false
			_status.text = ""
		)
		_choices.add_child(button)


func _on_confirm() -> void:
	if _rover.is_empty() or _chosen < 0:
		return
	var correct := int(_rover.get("correct", -1))
	if _chosen == correct:
		_status.text = Settings.text("archive.correct")
		_status.add_theme_color_override("font_color", Palette.OK)
		_confirm.disabled = true
		if _mission != &"" and not _objective.is_empty():
			MissionSystem.complete_objective(_mission, _objective)
		_finish()
	else:
		_status.text = Settings.text("archive.retry")
		_status.add_theme_color_override("font_color", Palette.ORO)


func _on_close() -> void:
	# Closing without a correct answer leaves the objective open so the player can try again.
	_finish()


func _finish() -> void:
	if get_tree().paused and not DayNightSystem.is_journal_open():
		get_tree().paused = false
	queue_free()
