## Every shipped level, by stable id, with its place in the game: the tutorial boards, the rooms (30 levels each,
## 3 shelves of 10) and the playtest boards. Pure, so tools and tests can load it without autoloads.
## A level file is {"track": "tutorial"|"room"|"test", "room": n, "levels": [...]}; each level may carry
## "kind" (normal, tricky, rest, hard), "introduces" (feature names) and "gold" (max slips for a gold lid).
class_name Catalog
extends RefCounted

const SHELF := 10
const ROOM_SIZE := 30

## id -> entry {id, track, room, number, kind, introduces: PackedStringArray, gold: int, data: Dictionary}
var entries: Dictionary = {}
var tutorial: PackedStringArray = []
## room number -> PackedStringArray of ids in play order
var rooms: Dictionary = {}
var test: PackedStringArray = []


static func from_files(paths: PackedStringArray) -> Catalog:
	var c := Catalog.new()
	for p in paths:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
		if parsed is Dictionary:
			c.add_file(parsed)
		else:
			push_error("catalog: can't parse %s" % p)
	return c


func add_file(file: Dictionary) -> void:
	var track := str(file.get("track", "room"))
	var room := int(file.get("room", 0))
	var order: PackedStringArray = []
	for d: Dictionary in file.get("levels", []):
		var id := str(d.get("id", ""))
		assert(id != "" and not entries.has(id), "catalog: missing or duplicate id %s" % id)
		order.append(id)
		entries[id] = {
			"id": id, "track": track, "room": room, "number": order.size(),
			"kind": str(d.get("kind", "normal")),
			"introduces": PackedStringArray(d.get("introduces", [])),
			"gold": int(d.get("gold", -1)),
			"data": d,
		}
	match track:
		"tutorial":
			tutorial.append_array(order)
		"test":
			test.append_array(order)
		_:
			var ids: PackedStringArray = rooms.get(room, PackedStringArray())
			ids.append_array(order)
			rooms[room] = ids


func has(id: String) -> bool:
	return entries.has(id)


func entry(id: String) -> Dictionary:
	return entries.get(id, {})


func level(id: String) -> LevelData:
	return LevelData.from_dict(entries[id]["data"])


func room_ids(room: int) -> PackedStringArray:
	return rooms.get(room, PackedStringArray())


func room_numbers() -> Array:
	var r := rooms.keys()
	r.sort()
	return r


## Every room level in play order, across rooms.
func play_order() -> PackedStringArray:
	var out: PackedStringArray = []
	for r in room_numbers():
		out.append_array(rooms[r])
	return out


## 0-based shelf of a room level.
func shelf_of(id: String) -> int:
	return (int(entries[id]["number"]) - 1) / SHELF


## Features the player has been taught by the time they play this level: everything introduced by the tutorial
## and by every room level up to and including this one. Tutorial and test boards use their own lists.
func features_at(id: String) -> Dictionary:
	var out := {}
	var e: Dictionary = entries.get(id, {})
	if e.is_empty():
		return out
	if e["track"] != "room":
		for f in e["introduces"]:
			out[f] = true
		if e["track"] == "test":
			for f in ["undo", "jar", "peek", "tidy", "budget"]:
				out[f] = true
		return out
	for t in tutorial:
		for f in entries[t]["introduces"]:
			out[f] = true
	for other in play_order():
		for f in entries[other]["introduces"]:
			out[f] = true
		if other == id:
			break
	return out


## Player-facing name, e.g. "Level 13" (numbered across rooms), "Tutorial 2" or "Test board 3".
func title(id: String) -> String:
	var e: Dictionary = entries.get(id, {})
	match e.get("track", ""):
		"tutorial":
			return "Tutorial %d" % e["number"]
		"test":
			return "Test board %d" % e["number"]
	return "Level %d" % (play_order().find(id) + 1)
