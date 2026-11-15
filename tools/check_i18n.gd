extends Node
## Headless check: Spanish and English keys stay in step.
## INTI files are compared key by key. Data JSON needs a non-empty _en twin
## for every player-facing string. Prints the missing ones and quits 0 when none are left.

const TEXT_KEYS := {
	"title": true,
	"description": true,
	"science": true,
	"done": true,
	"label": true,
	"detail": true,
	"note": true,
	"text": true,
	"inti": true,
	"message_text": true,
}

var _missing := 0


func _ready() -> void:
	_settings()
	_inti()
	_json_dir("res://data/missions")
	_json_file("res://data/events/events.json")
	_json_file("res://data/cinematics/cinematics.json")
	_json_file("res://data/loop.json")
	_json_file("res://data/dialogue/debrief.json")
	_tres_dir("res://data/modules")
	_tres_dir("res://data/kits")
	print("I18N_CHECK_RESULT ", _missing)
	if _missing > 0:
		push_error("check_i18n: %d missing" % _missing)
	else:
		print("check_i18n: all keys present")
	get_tree().quit(1 if _missing > 0 else 0)


func _settings() -> void:
	for key in Settings.audit_ui():
		_miss("settings %s" % key)


func _inti() -> void:
	var spanish := _read("res://data/dialogue/inti_es.json")
	var english := _read("res://data/dialogue/inti_en.json")
	var es_triggers: Dictionary = spanish.get("triggers", {})
	var en_triggers: Dictionary = english.get("triggers", {})
	for id in es_triggers:
		if not en_triggers.has(id):
			_miss("inti trigger %s" % id)
			continue
		var es_lines: Array = es_triggers[id]
		var en_lines: Array = en_triggers[id]
		if es_lines.size() != en_lines.size():
			_miss("inti trigger %s count %d/%d" % [id, es_lines.size(), en_lines.size()])
		for i in es_lines.size():
			if i >= en_lines.size():
				break
			var es_line: Dictionary = es_lines[i]
			var en_line: Dictionary = en_lines[i]
			if String(en_line.get("text", "")).strip_edges().is_empty():
				_miss("inti trigger %s line %d" % [id, i])
			if String(es_line.get("tip", "")) != String(en_line.get("tip", "")):
				_miss("inti trigger %s line %d tip" % [id, i])
	for id in en_triggers:
		if not es_triggers.has(id):
			_miss("inti extra trigger %s" % id)
	var es_when := {}
	for hint in spanish.get("hints", []):
		if hint is Dictionary:
			es_when[_when_key(hint.get("when", {}))] = hint
	var en_when := {}
	for hint in english.get("hints", []):
		if hint is Dictionary:
			en_when[_when_key(hint.get("when", {}))] = hint
	for key in es_when:
		if not en_when.has(key) or String(en_when[key].get("text", "")).strip_edges().is_empty():
			_miss("inti hint %s" % key)
	for key in en_when:
		if not es_when.has(key):
			_miss("inti extra hint %s" % key)
	var es_tips: Dictionary = spanish.get("tips", {})
	var en_tips: Dictionary = english.get("tips", {})
	for id in es_tips:
		var tip: Dictionary = en_tips.get(id, {})
		if String(tip.get("text", "")).strip_edges().is_empty():
			_miss("inti tip %s" % id)
	for id in en_tips:
		if not es_tips.has(id):
			_miss("inti extra tip %s" % id)


func _json_dir(dir_path: String) -> void:
	for file_name in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".json"):
			_json_file(dir_path.path_join(file_name))


func _json_file(path: String) -> void:
	_walk(_read(path), path)


func _tres_dir(dir_path: String) -> void:
	for file_name in DirAccess.get_files_at(dir_path):
		if not file_name.ends_with(".tres"):
			continue
		var path := dir_path.path_join(file_name)
		var file := FileAccess.open(path, FileAccess.READ)
		var text := file.get_as_text() if file else ""
		for key in ["display_name", "description", "gain", "loss"]:
			if text.contains("%s =" % key) and not text.contains("%s_en" % key):
				_miss("%s %s" % [path, key])


func _walk(node: Variant, path: String) -> void:
	if node is Dictionary:
		var data: Dictionary = node
		for key in data.keys():
			var name := String(key)
			if name.begins_with("_") or name.ends_with("_en"):
				continue
			var value: Variant = data[key]
			if name == "rescue_lines" and value is Dictionary:
				var english: Dictionary = data.get("rescue_lines_en", {})
				for rid in (value as Dictionary).keys():
					if String(english.get(rid, "")).strip_edges().is_empty():
						_miss("%s.rescue_lines.%s" % [path, rid])
				continue
			if value is String and TEXT_KEYS.has(name) and not String(value).strip_edges().is_empty():
				if String(data.get(name + "_en", "")).strip_edges().is_empty():
					_miss("%s.%s" % [path, name])
			elif value is Array and TEXT_KEYS.has(name):
				var english: Variant = data.get(name + "_en", [])
				if not english is Array or (english as Array).size() != (value as Array).size():
					_miss("%s.%s_en" % [path, name])
				elif english is Array:
					for i in (english as Array).size():
						if String((english as Array)[i]).strip_edges().is_empty():
							_miss("%s.%s_en[%d]" % [path, name, i])
			elif value is Dictionary or value is Array:
				_walk(value, "%s.%s" % [path, name])
	elif node is Array:
		for i in node.size():
			_walk(node[i], "%s[%d]" % [path, i])


func _when_key(when: Dictionary) -> String:
	var keys: Array = when.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for key in keys:
		parts.append("%s=%s" % [key, when[key]])
	return "|".join(parts)


func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
	return parsed if parsed is Dictionary else {}


func _miss(message: String) -> void:
	_missing += 1
	print("MISSING ", message)
