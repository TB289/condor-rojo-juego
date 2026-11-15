class_name INTIProvider
extends RefCounted
## Source of INTI's lines. The game only talks to IntiBrain, which holds one of these.
## Another provider can replace ScriptedProvider later without touching the UI.

## One written line for a trigger. Empty if this provider has nothing to say.
func get_line(_trigger_id: String, _state: Dictionary) -> String:
	return ""


## One hint for the current state. Empty if this provider has nothing to say.
func get_hint(_state: Dictionary) -> String:
	return ""


## NASA fact attached to the line just returned by get_line() or get_hint(). Empty if none.
func get_last_tip() -> String:
	return ""
