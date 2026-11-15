class_name KitData
extends Resource
## Starting preset of base modules. The player can make one change before landing (see data/base.json).

@export var id: StringName
@export var display_name: String
@export var display_name_en: String
@export var module_ids: Array[StringName] = []
## One line: what this kit is good at.
@export var gain: String
@export var gain_en: String
## One line: what this kit gives up.
@export var loss: String
@export var loss_en: String


func localized_name() -> String:
	if Settings != null and Settings.lang == "en" and not display_name_en.is_empty():
		return display_name_en
	return display_name


func localized_gain() -> String:
	if Settings != null and Settings.lang == "en" and not gain_en.is_empty():
		return gain_en
	return gain


func localized_loss() -> String:
	if Settings != null and Settings.lang == "en" and not loss_en.is_empty():
		return loss_en
	return loss
