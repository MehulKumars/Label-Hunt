## Persistent profile (autoload "Save"). The shape lives in SaveSchema; every load is size-capped and sanitised.
## Written atomically (tmp file -> rename, keeping the previous copy as .bak). Writes during play are debounced;
## pausing or quitting the app flushes at once.
extends Node

const PATH := "user://save.json"
const SHOTS_PATH := "user://shots_save.json"
const LOG_PATH := "user://playtest.json"
const LOG_CAP := 500
const DEBOUNCE := 0.5

## Screenshot runs use their own fresh save, so they never touch the player's progress.
var path := PATH
var data: Dictionary = {}
var log_entries: Array = []
var _dirty_at := -1.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			path = SHOTS_PATH
			DirAccess.remove_absolute(path)
			DirAccess.remove_absolute(path + ".bak")
	var raw: Variant = _read(path)
	if raw == null:
		raw = _read(path + ".bak")
	data = SaveSchema.sanitize(raw, Levels.valid_ids())
	data["launches"] = int(data["launches"]) + 1
	var parsed: Variant = _read(LOG_PATH)
	log_entries = parsed if parsed is Array else []
	write()


func _process(_delta: float) -> void:
	if _dirty_at >= 0.0 and Time.get_ticks_msec() / 1000.0 - _dirty_at >= DEBOUNCE:
		write()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		if _dirty_at >= 0.0:
			write()


func setting(key: String) -> Variant:
	return data["settings"].get(key)


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	write()


## Marks the save as changed; it's written once things settle (or at once when the app pauses).
func touch() -> void:
	if _dirty_at < 0.0:
		_dirty_at = Time.get_ticks_msec() / 1000.0


func write() -> void:
	_dirty_at = -1.0
	_atomic(path, JSON.stringify(data))


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
	data = SaveSchema.defaults()
	write()


## Parsed JSON, or null when the file is missing, oversized or unreadable.
static func _read(file: String) -> Variant:
	if not FileAccess.file_exists(file):
		return null
	var f := FileAccess.open(file, FileAccess.READ)
	if f == null or f.get_length() > SaveSchema.MAX_BYTES:
		return null
	return JSON.parse_string(f.get_as_text())


static func _atomic(file: String, text: String) -> void:
	var tmp := file + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("save: can't write %s" % tmp)
		return
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file + ".bak")
		DirAccess.rename_absolute(file, file + ".bak")
	DirAccess.rename_absolute(tmp, file)
