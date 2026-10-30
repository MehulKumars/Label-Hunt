## Persistent profile (autoload "Save"). Written atomically: tmp file -> rename, keeping the previous copy as .bak.
extends Node

const PATH := "user://save.json"
const LOG_PATH := "user://playtest.json"
const VERSION := 1
const LOG_CAP := 500

var data: Dictionary = {}
var log_entries: Array = []


func _ready() -> void:
	data = _read(PATH)
	if data.is_empty():
		data = _read(PATH + ".bak")
	data = _with_defaults(data)
	data["launches"] = int(data.get("launches", 0)) + 1
	var log_text := FileAccess.get_file_as_string(LOG_PATH)
	var parsed: Variant = JSON.parse_string(log_text) if log_text != "" else null
	log_entries = parsed if parsed is Array else []
	write()


func setting(key: String) -> Variant:
	return data["settings"].get(key)


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	write()


func write() -> void:
	_atomic(PATH, JSON.stringify(data))


func log_attempt(entry: Dictionary) -> void:
	log_entries.append(entry)
	if log_entries.size() > LOG_CAP:
		log_entries = log_entries.slice(log_entries.size() - LOG_CAP)
	_atomic(LOG_PATH, JSON.stringify(log_entries))


func flush_log() -> void:
	_atomic(LOG_PATH, JSON.stringify(log_entries))


func clear_log() -> void:
	log_entries.clear()
	_atomic(LOG_PATH, "[]")


func reset() -> void:
	data = _with_defaults({})
	write()


static func _with_defaults(d: Dictionary) -> Dictionary:
	var out := {
		"version": VERSION,
		"level": 0,
		"launches": 0,
		"settings": {"sound": true, "haptics": true, "reduce_motion": false, "fps": false},
		"rules": {},
		"seen_captions": {},
	}
	for k in d:
		if out.has(k) and out[k] is Dictionary and d[k] is Dictionary:
			(out[k] as Dictionary).merge(d[k], true)
		else:
			out[k] = d[k]
	out["level"] = int(out["level"])
	return out


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func _atomic(path: String, text: String) -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("save: can't write %s" % tmp)
		return
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	DirAccess.rename_absolute(tmp, path)
