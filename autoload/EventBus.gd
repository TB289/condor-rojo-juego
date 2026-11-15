extends Node
## Global signal hub. Only signals live here; no state, no logic.

signal resource_changed(id: StringName, value: float, max_value: float)
signal resource_empty(id: StringName)
signal sol_started(n: int)
signal event_triggered(id: StringName)
signal decision_made(event_id: StringName, option_id: StringName)
signal inti_say(text: String, mood: StringName)
signal module_placed(module_id: StringName)
signal module_inspected(module: Node)
signal mission_started(id: StringName)
signal mission_objective_done(mission_id: StringName, objective_id: StringName)
signal mission_completed(id: StringName)
