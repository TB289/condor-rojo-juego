class_name ModuleData
extends Resource
## One base module (habitat, greenhouse...). Game values, not NASA data.
## At night, panels pay the module costs (ResourceSystem.apply_night). What is left charges the battery.
## A module without energy that night is off and produces nothing.

const TILE_SIZE := 16
const RESOURCE_NAMES: Dictionary[StringName, String] = {
	&"oxygen": "oxígeno",
	&"energy": "energía",
	&"food": "comida",
}

@export var id: StringName
@export var display_name: String
@export var display_name_en: String
## Short, kid-friendly line shown in the kit cards and the info panel.
@export_multiline var description: String
@export_multiline var description_en: String
@export var texture: Texture2D
## Ground footprint in 16 px tiles. The sprite can be taller (3/4 view); only this part blocks.
@export var size_tiles := Vector2i(2, 1)

@export_group("Por sol")
@export var energy_cost_per_sol: float = 0.0
@export var energy_per_sol: float = 0.0
@export var oxygen_per_sol: float = 0.0
@export var food_per_sol: float = 0.0

@export_group("Funciones")
## Safe place during dust and solar storms.
@export var is_shelter: bool = false
## Allows messages to and from Earth.
@export var enables_comms: bool = false


func get_footprint_px() -> Vector2:
	return Vector2(size_tiles * TILE_SIZE)


## Net change per sol for each resource, assuming the module has energy.
func get_effects() -> Dictionary[StringName, float]:
	return {
		&"oxygen": oxygen_per_sol,
		&"energy": energy_per_sol - energy_cost_per_sol,
		&"food": food_per_sol,
	}


## "+14 comida, -8 energía". Empty when the module doesn't move any bar.
func describe_effects() -> String:
	return describe(get_effects())


func localized_name() -> String:
	if Settings != null and Settings.lang == "en" and not display_name_en.is_empty():
		return display_name_en
	return display_name


func name_en() -> String:
	return display_name_en if not display_name_en.is_empty() else display_name


func localized_description() -> String:
	if Settings != null and Settings.lang == "en" and not description_en.is_empty():
		return description_en
	return description


func describe_functions() -> String:
	var parts: PackedStringArray = []
	if is_shelter:
		parts.append(Settings.text("module.shelter"))
	if enables_comms:
		parts.append(Settings.text("module.comms"))
	return ", ".join(parts)


static func resource_label(id: StringName) -> String:
	if Settings != null and Settings.lang == "en":
		match id:
			&"oxygen":
				return "oxygen"
			&"energy":
				return "energy"
			&"food":
				return "food"
	return String(RESOURCE_NAMES.get(id, id))


static func describe(effects: Dictionary[StringName, float]) -> String:
	var parts: PackedStringArray = []
	for id in RESOURCE_NAMES:
		var amount: float = effects.get(id, 0.0)
		if not is_zero_approx(amount):
			parts.append("%+d %s" % [roundi(amount), resource_label(id)])
	return ", ".join(parts)
