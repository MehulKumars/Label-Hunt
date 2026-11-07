## Where the player is and what they've earned, as pure functions over a Catalog and the save dictionary
## (save["solved"] = {id: {"slips": best, "stars": best 1-3, "gold": stars == 3}}). Levels unlock in order; solved
## ones can be replayed for more stars.
class_name Progression
extends RefCounted


## The level Play should open: the first unsolved room level, or "" when every shipped room is done.
static func next_level(cat: Catalog, save: Dictionary) -> String:
	var solved: Dictionary = save.get("solved", {})
	for id in cat.play_order():
		if not solved.has(id):
			return id
	return ""


## Room levels open in order: the first level, any solved level, and the one after a solved level. (A player whose
## old levels moved later in the order keeps them playable.)
static func is_unlocked(cat: Catalog, save: Dictionary, id: String) -> bool:
	if not cat.has(id):
		return false
	if cat.entry(id)["track"] != "room":
		return true
	var solved: Dictionary = save.get("solved", {})
	if solved.has(id) or next_level(cat, save) == id:
		return true
	var order := cat.play_order()
	var i := cat.order_index(id)
	return i == 0 or (i > 0 and solved.has(order[i - 1]))


## Stars for a win on this level with this many slips (Economy.star_limits). Stars count slips only.
static func stars_for_win(cat: Catalog, id: String, slips: int) -> int:
	return Economy.stars_for(slips, Economy.entry_limits(cat.entry(id)))


## Records a win and returns what it unlocked, for the Win card:
## {first_solve, stars (this win), best (after it), gained (stars over the old best, which pay coins),
##  gold (3 stars: the gold lid), new_gold, first_gold, shelf_full: -1 or shelf index, room_done, next}.
static func record_win(cat: Catalog, save: Dictionary, id: String, slips: int) -> Dictionary:
	var solved: Dictionary = save.get("solved", {})
	save["solved"] = solved
	var e := cat.entry(id)
	var out := {"first_solve": false, "stars": 0, "best": 0, "gained": 0, "gold": false, "new_gold": false,
		"first_gold": false, "shelf_full": -1, "room_done": false, "next": ""}
	if e.is_empty() or e["track"] != "room":
		return out
	var had_any_gold := gold_count(cat, save, -1) > 0
	var prev: Dictionary = solved.get(id, {})
	var stars := stars_for_win(cat, id, slips)
	var old_best := int(prev.get("stars", 0))
	var best := maxi(stars, old_best)
	out["first_solve"] = prev.is_empty()
	out["stars"] = stars
	out["best"] = best
	out["gained"] = best - old_best
	out["gold"] = stars == 3
	out["new_gold"] = best == 3 and old_best < 3
	out["first_gold"] = out["new_gold"] and not had_any_gold
	solved[id] = {"slips": mini(slips, int(prev.get("slips", slips))), "stars": best, "gold": best == 3}
	if out["first_solve"]:
		var room: int = e["room"]
		var shelf := cat.shelf_of(id)
		if _shelf_done(cat, save, room, shelf):
			out["shelf_full"] = shelf
		out["room_done"] = solved_count(cat, save, room) == cat.room_ids(room).size()
	out["next"] = next_level(cat, save)
	return out


static func solved_count(cat: Catalog, save: Dictionary, room: int) -> int:
	var solved: Dictionary = save.get("solved", {})
	var n := 0
	for id in cat.room_ids(room):
		if solved.has(id):
			n += 1
	return n


## Stars collected in one room, or in every room when room is -1 (best per level).
static func star_count(cat: Catalog, save: Dictionary, room: int) -> int:
	var solved: Dictionary = save.get("solved", {})
	var ids := cat.play_order() if room < 0 else cat.room_ids(room)
	var n := 0
	for id in ids:
		n += int(solved.get(id, {}).get("stars", 0))
	return n


## Sets every solved level's stars from its stored best slips (once, for saves from before stars). A level that had
## a gold lid keeps it as 3 stars. Returns how many levels changed.
static func backdate_stars(cat: Catalog, save: Dictionary) -> int:
	var solved: Dictionary = save.get("solved", {})
	var n := 0
	for id in solved:
		if not cat.has(id):
			continue
		var rec: Dictionary = solved[id]
		var stars := 3 if bool(rec.get("gold", false)) else stars_for_win(cat, id, int(rec.get("slips", 0)))
		if int(rec.get("stars", 0)) != stars:
			n += 1
		rec["stars"] = stars
		rec["gold"] = stars == 3
	return n


## Gold lids (3-star levels) in one room, or in every room when room is -1.
static func gold_count(cat: Catalog, save: Dictionary, room: int) -> int:
	var solved: Dictionary = save.get("solved", {})
	var ids := cat.play_order() if room < 0 else cat.room_ids(room)
	var n := 0
	for id in ids:
		if bool(solved.get(id, {}).get("gold", false)):
			n += 1
	return n


## The room Home shows: the one holding the next level, else the last room.
static func current_room(cat: Catalog, save: Dictionary) -> int:
	var next := next_level(cat, save)
	if next != "":
		return cat.entry(next)["room"]
	var rooms := cat.room_numbers()
	return rooms.back() if not rooms.is_empty() else 1


static func _shelf_done(cat: Catalog, save: Dictionary, room: int, shelf: int) -> bool:
	var solved: Dictionary = save.get("solved", {})
	var ids := cat.room_ids(room)
	var from := shelf * Catalog.SHELF
	for i in range(from, mini(from + Catalog.SHELF, ids.size())):
		if not solved.has(ids[i]):
			return false
	return true
