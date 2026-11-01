## One-off (M3): moves the v0.2 Room 1 (ids r1-01..r1-30, kept stable for saves and playtest logs) to Room 2,
## "The Kitchen", strips its teaching intros (the new Room 1 teaches), swaps the weak "Things with keys" words in
## r1-04 (Map and Lock -> Piano and Computer), and writes data/rooms/room2_spec.json: levels 3-30 kept, the two
## 2-group openers re-made as 3-group levels (ids l2-01, l2-02), slip limits on every level.
## Run once: godot --headless --path . -s res://tools/convert_room2.gd
extends SceneTree

const SRC := "res://data/levels/room1.json"
const DST := "res://data/levels/room2.json"
const SPEC := "res://data/rooms/room2_spec.json"
const SWAP := {"Map": "Piano", "Lock": "Computer"}
const FLOOR := {"rest": 0.94, "normal": 0.85, "tricky": 0.75, "hard": 0.65}


func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SRC))
	if int(data.get("room", 0)) != 1 or not str(data["levels"][0]["id"]).begins_with("r1-"):
		push_error("convert_room2: %s is not the v0.2 room" % SRC)
		quit(1)
		return
	data["room"] = 2
	data["name"] = "The Kitchen"
	var spec_levels: Array = []
	for i in (data["levels"] as Array).size():
		var d: Dictionary = data["levels"][i]
		d["introduces"] = []
		if d["id"] == "r1-04":
			_swap(d)
		var kind := str(d["kind"])
		var ls := {"kind": kind, "budget": true, "floor": FLOOR[kind], "novice_floor": 0.7,
			"target": float((d.get("meta", {}) as Dictionary).get("target", 1.0))}
		if i < 2:
			ls.merge({"tiers": [1, 2, 3], "herrings": 0, "target": 0.6 + 0.05 * i, "exclude": ["abstract", "wordplay"]}, true)
		else:
			ls["keep"] = true
		spec_levels.append(ls)
	JsonOut.write(DST, data)
	JsonOut.write(SPEC, {"room": 2, "name": "The Kitchen", "id_prefix": "l2",
		"note": "The v0.2 Room 1, kept (docs/plan-m3.md section 7). Levels marked keep are never re-picked; L1-2 are re-made as 3-group levels.",
		"levels": spec_levels})
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SRC))
	print("room 1 -> room 2 done")
	quit()


func _swap(d: Dictionary) -> void:
	for g: Dictionary in d["groups"]:
		g["words"] = (g["words"] as Array).map(func(w: Variant) -> String: return SWAP.get(str(w), str(w)))
	var jars: Array = []
	for jar: Array in d["jars"]:
		jars.append(jar.map(func(w: Variant) -> String: return SWAP.get(str(w), str(w))))
	d["jars"] = jars
