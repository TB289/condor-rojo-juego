class_name BaseCatalog
extends RefCounted
## Loads base modules, kits and base rules from res://data/. Ids map to files:
## data/modules/<id>.tres and data/kits/<id>.tres. Order comes from data/base.json.

const RULES_PATH := "res://data/base.json"
const MODULE_PATH := "res://data/modules/%s.tres"
const KIT_PATH := "res://data/kits/%s.tres"

static var _rules: Dictionary = {}


static func rules() -> Dictionary:
	if _rules.is_empty():
		var file := FileAccess.open(RULES_PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
		if parsed is Dictionary:
			_rules = parsed
		else:
			push_error("BaseCatalog: could not read %s" % RULES_PATH)
	return _rules


static func get_rule(key: String, default: Variant = null) -> Variant:
	return rules().get(key, default)


static func get_module(id: StringName) -> ModuleData:
	var module := load(MODULE_PATH % id) as ModuleData
	if module == null:
		push_error("BaseCatalog: unknown module '%s'" % id)
	return module


static func get_kit(id: StringName) -> KitData:
	var kit := load(KIT_PATH % id) as KitData
	if kit == null:
		push_error("BaseCatalog: unknown kit '%s'" % id)
	return kit


static func all_modules() -> Array[ModuleData]:
	var result: Array[ModuleData] = []
	for id in get_rule("modules", []):
		var module := get_module(StringName(id))
		if module:
			result.append(module)
	return result


static func all_kits() -> Array[KitData]:
	var result: Array[KitData] = []
	for id in get_rule("kits", []):
		var kit := get_kit(StringName(id))
		if kit:
			result.append(kit)
	return result


static func is_locked(module_id: StringName) -> bool:
	return String(module_id) in get_rule("locked_modules", [])
