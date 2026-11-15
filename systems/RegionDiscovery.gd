extends Node
## Contextual, nonmodal location discovery. Existing cave/glacier/lake mission nodes
## supply the positions; this does not invent new geography.

const REGIONS := {
	"cave_mouth": ["CUEVA", "CAVE", "Entra y mira las capas de roca.", "Go in and look at the rock layers."],
	"glacier_lobe": ["GLACIAR", "GLACIER", "Busca hielo de agua bajo el polvo.", "Look for water ice under the dust."],
	"lakebed": ["ANTIGUO LAGO", "ANCIENT LAKE", "Busca arcillas del agua antigua.", "Look for clays from ancient water."],
	"mineral_hematite": ["MINERALES", "MINERALS", "La hematita puede estar ligada al agua.", "Hematite can be tied to water."],
}
var _seen: Dictionary = {}
var _last_sol := -1


func _process(_delta: float) -> void:
	if not DayNightSystem.has_started() or GameState.run_over or BasePlacer.active or GameState.interior_id != &"":
		return
	if get_tree().current_scene == null or get_tree().current_scene.name != "Main":
		return
	if GameState.current_sol < _last_sol:
		_seen.clear()
	_last_sol = GameState.current_sol
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return
	for node in get_tree().get_nodes_in_group(&"mission_target"):
		if not node.has_method(&"get_target_id") or not node is Node2D:
			continue
		var id := String(node.call(&"get_target_id"))
		if not REGIONS.has(id) or _seen.has(id):
			continue
		if player.global_position.distance_to((node as Node2D).global_position) > 75.0:
			continue
		_seen[id] = true
		GameState.set_flag(StringName("visited_" + id))
		if not NasaData.SHOW_FACT_POPUPS:
			continue
		var info: Array = REGIONS[id]
		var es := "%s: %s" % [info[0], info[2]]
		var en := "%s: %s" % [info[1], info[3]]
		var hud := get_tree().get_first_node_in_group(&"hud")
		if hud != null and hud.has_method(&"show_notice"):
			hud.call(&"show_notice", Settings.pack(es, en))
		return
