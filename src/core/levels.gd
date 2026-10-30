## Shipped levels (autoload "Levels"): the Catalog of tutorial, room and test boards, loaded from baked JSON.
## Never generates levels at runtime.
extends Node

const FILES := [
	"res://data/levels/tutorial.json",
	"res://data/levels/room1.json",
	"res://data/levels/test.json",
]

var catalog: Catalog


func _ready() -> void:
	catalog = Catalog.from_files(PackedStringArray(FILES))


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
