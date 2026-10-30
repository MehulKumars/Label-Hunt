## Shipped levels (autoload "Levels"). Loads baked/hand-made JSON; never generates levels at runtime.
extends Node

const HANDMADE := "res://data/levels/handmade.json"

var levels: Array[LevelData] = []


func _ready() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(HANDMADE))
	if data is Dictionary:
		for d in data["levels"]:
			levels.append(LevelData.from_dict(d))


func count() -> int:
	return levels.size()


func level_at(i: int) -> LevelData:
	return levels[clampi(i, 0, levels.size() - 1)]


## Player-facing title. M1 ships tutorials as levels 1-10 and the mid-game test boards after them.
func title(i: int) -> String:
	var l := level_at(i)
	if l.id.begins_with("m"):
		return "Test board %d" % (int(l.id.substr(1)))
	return "Level %d" % (i + 1)


## A fresh copy for one attempt, with the dev "one empty jar" toggle applied.
func make_level(i: int, one_empty: bool = false) -> LevelData:
	var l := LevelData.from_dict(level_at(i).to_dict())
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
