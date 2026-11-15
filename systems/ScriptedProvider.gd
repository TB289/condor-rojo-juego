class_name ScriptedProvider
extends INTIProvider
## Written lines. Spanish is the full script. English (inti_en.json) overrides the keys it has.

const PATH_ES := "res://data/dialogue/inti_es.json"
const PATH_EN := "res://data/dialogue/inti_en.json"

var _es: Dictionary = {}
var _en: Dictionary = {}
var _last_index: Dictionary = {}
var _last_tip_id := ""


func _init() -> void:
	_es = _read(PATH_ES)
	_en = _read(PATH_EN)


func get_line(trigger_id: String, state: Dictionary) -> String:
	_last_tip_id = ""
	var lines := _trigger_lines(trigger_id)
	if lines.is_empty():
		push_warning("ScriptedProvider: no lines for '%s'" % trigger_id)
		return ""
	var index := _pick_index(trigger_id, lines.size())
	var entry: Variant = lines[index]
	if not entry is Dictionary:
		return ""
	var record: Dictionary = entry
	_last_tip_id = String(record.get("tip", ""))
	var day := str(maxi(int(state.get("day", 1)), 1))
	var spanish := String(record.get("text", "")).replace("{day}", day)
	var english := spanish
	var en_lines := _lines_in(_en, trigger_id)
	if index < en_lines.size() and en_lines[index] is Dictionary:
		english = String((en_lines[index] as Dictionary).get("text", "")).replace("{day}", day)
		if english.is_empty():
			english = spanish
	return Settings.pack(spanish, english)


func get_hint(state: Dictionary) -> String:
	_last_tip_id = ""
	var chosen := _match_hint(state)
	if chosen.is_empty():
		return ""
	_last_tip_id = String(chosen.get("tip", ""))
	var spanish := String(chosen.get("text", ""))
	var english := spanish
	if _en.get("hints", []) is Array:
		var when: Dictionary = chosen.get("when", {})
		for hint in _en.get("hints", []):
			if hint is Dictionary and (hint as Dictionary).get("when", {}) == when:
				english = String((hint as Dictionary).get("text", ""))
				if english.is_empty():
					english = spanish
				break
	return Settings.pack(spanish, english)


func get_last_tip() -> String:
	if not NasaData.SHOW_FACT_POPUPS:
		return ""
	if _last_tip_id == "glossary":
		return NasaData.glossary_line()
	if _last_tip_id.is_empty():
		return ""
	var tips: Dictionary = _es.get("tips", {})
	var tip: Dictionary = tips.get(_last_tip_id, {})
	var spanish := String(tip.get("text", ""))
	var en_tips: Dictionary = _en.get("tips", {})
	var en_tip: Dictionary = en_tips.get(_last_tip_id, {})
	var english := String(en_tip.get("text", ""))
	if english.is_empty():
		english = spanish
	if spanish.is_empty() and english.is_empty():
		return ""
	return Settings.pack(spanish, english)


## Random line, never the one used last time for this trigger when another exists.
func _pick_index(trigger_id: String, count: int) -> int:
	if count <= 1:
		_last_index[trigger_id] = 0
		return 0
	var last := int(_last_index.get(trigger_id, -1))
	var index := randi() % count
	if index == last:
		index = (index + 1 + (randi() % (count - 1))) % count
	_last_index[trigger_id] = index
	return index


## Event first, then the lowest resource under its threshold, then being outside, then default.
func _match_hint(state: Dictionary) -> Dictionary:
	return _match_in(_es.get("hints", []), state)


func _match_in(hints: Array, state: Dictionary) -> Dictionary:
	var event_hint: Dictionary = {}
	var resource_hint: Dictionary = {}
	var resource_value := 101.0
	var outside_hint: Dictionary = {}
	var default_hint: Dictionary = {}
	var active := String(state.get("active_event", ""))
	for hint in hints:
		if not hint is Dictionary:
			continue
		var when: Dictionary = hint.get("when", {})
		if bool(when.get("default", false)):
			default_hint = hint
			continue
		if when.has("event"):
			if active != "" and String(when.get("event", "")) == active and event_hint.is_empty():
				event_hint = hint
			continue
		if when.has("resource"):
			var id := String(when.get("resource", ""))
			var below := float(when.get("below", 25.0))
			var value := float(state.get(id, 100.0))
			if value < below and value < resource_value:
				resource_hint = hint
				resource_value = value
			continue
		if bool(when.get("outside", false)) and bool(state.get("outside", false)):
			outside_hint = hint
	if not event_hint.is_empty():
		return event_hint
	if not resource_hint.is_empty():
		return resource_hint
	if not outside_hint.is_empty():
		return outside_hint
	return default_hint


func _use_english() -> bool:
	return Settings != null and Settings.lang == "en"


func _trigger_lines(trigger_id: String) -> Array:
	return _lines_in(_es, trigger_id)


func _lines_in(book: Dictionary, trigger_id: String) -> Array:
	var triggers: Dictionary = book.get("triggers", {})
	return triggers.get(trigger_id, [])


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ScriptedProvider: could not open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("ScriptedProvider: invalid JSON in %s" % path)
		return {}
	return parsed
