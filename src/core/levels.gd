## Shipped levels (autoload "Levels"): the Catalog of tutorial, room and test boards, loaded from baked JSON.
## Never generates levels at runtime.
extends Node

## The level files in load order (tutorial, rooms, test), written by tools/room_gen.gd.
const INDEX := "res://data/levels/index.json"

var catalog: Catalog


func _ready() -> void:
	catalog = Catalog.from_files(files())


static func files() -> PackedStringArray:
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX)) if FileAccess.file_exists(INDEX) else null
	var out := PackedStringArray()
	if not index is Dictionary:
		push_error("Levels: %s is missing or broken" % INDEX)
		return out
	for f in (index as Dictionary).get("files", []):
		if FileAccess.file_exists(str(f)):
			out.append(str(f))
	return out


func valid_ids() -> Dictionary:
	var out := {}
	for id in catalog.entries:
		out[id] = true
	return out


func title(id: String) -> String:
	return catalog.title(id)


## A fresh copy for one attempt, with the playtest "one empty jar" toggle applied.
func make_level(id: String, one_empty: bool = false) -> LevelData:
	var l := catalog.level(id)
	if one_empty:
		for j in range(l.jars.size() - 1, -1, -1):
			if l.jars[j].is_empty() and not l.labelled.has(j) and _plain_empty_count(l) > 1:
				l.jars.remove_at(j)
				var shifted := {}
				for k in l.labelled:
					shifted[k - 1 if k > j else k] = l.labelled[k]
				l.labelled = shifted
				for n in l.corked.size():
					if l.corked[n] > j:
						l.corked[n] -= 1
				break
	return l


static func _plain_empty_count(l: LevelData) -> int:
	var n := 0
	for j in l.jars.size():
		if l.jars[j].is_empty() and not l.labelled.has(j):
			n += 1
	return n
