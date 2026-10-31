## The global reuse ledger: which categories, words and category pairs each level used, by global level number
## (room r, level n -> (r - 1) * 30 + n; the tutorial counts as level 0). Uses are checked by distance to *any* use,
## so levels can be added in any order (a room can be re-made between rooms that are already baked).
class_name Ledger
extends RefCounted

const ROOM_SIZE := 30
## A category pairing may repeat only this many levels apart.
const PAIR_GAP := 150
## A new use of a category may share at most this many words with an earlier use of it, or MAX_SHARED_FAR when
## that use is at least FAR levels back (nobody remembers a word list from 150 levels ago).
const MAX_SHARED := 2
const MAX_SHARED_FAR := 3
const FAR := 150

var bank: Bank
## category index -> Array[int] of global level numbers
var cat_uses := {}
## category index -> Array of [global level, lower-case word set (Dictionary word -> true)], one per use
var cat_words := {}
## lower-case word -> Array[int]
var word_uses := {}
## "a,b" (sorted indices) -> Array[int]
var pair_uses := {}
var gap := 60
var word_gap := 30


func _init(b: Bank) -> void:
	bank = b


static func global_number(room: int, number: int) -> int:
	return (room - 1) * ROOM_SIZE + number


## How many times a category may appear in the whole game: two uses per 5 members, 2 to 5 (a 13-word category about
## once per 100 levels; words_ok limits how many words a repeat may share).
func max_uses(idx: int) -> int:
	return clampi((bank.categories[idx]["words"] as PackedStringArray).size() * 2 / 5, 2, 5)


func uses(idx: int) -> int:
	return (cat_uses.get(idx, []) as Array).size()


func cat_ok(idx: int, at: int) -> bool:
	var u: Array = cat_uses.get(idx, [])
	return u.size() < max_uses(idx) and _far(u, at, gap)


func word_ok(word: String, at: int) -> bool:
	return _far(word_uses.get(word.to_lower(), []), at, word_gap)


func pair_ok(a: int, b: int, at: int) -> bool:
	return _far(pair_uses.get(_pair(a, b), []), at, PAIR_GAP)


## True if `chosen` shares at most MAX_SHARED words with every earlier use of the category (MAX_SHARED_FAR with a
## use at least FAR levels away).
func words_ok(idx: int, chosen: PackedStringArray, at: int = 0) -> bool:
	for prev: Array in cat_words.get(idx, []):
		var shared := 0
		for w in chosen:
			if (prev[1] as Dictionary).has(w.to_lower()):
				shared += 1
		if shared > (MAX_SHARED_FAR if absi(at - int(prev[0])) >= FAR else MAX_SHARED):
			return false
	return true


## True if `word` appeared in an earlier use of this category (fresh words are preferred).
func used_in(idx: int, word: String) -> bool:
	for prev: Array in cat_words.get(idx, []):
		if (prev[1] as Dictionary).has(word.to_lower()):
			return true
	return false


func add(at: int, cats: Array, words: Array) -> void:
	for a in cats.size():
		var idx: int = cats[a]
		var set := {}
		for w in words[a]:
			set[(w as String).to_lower()] = true
			_push(word_uses, (w as String).to_lower(), at)
		if idx < 0:
			continue
		_push(cat_uses, idx, at)
		var ws: Array = cat_words.get(idx, [])
		ws.append([at, set])
		cat_words[idx] = ws
		for b in range(a + 1, cats.size()):
			if int(cats[b]) >= 0:
				_push(pair_uses, _pair(idx, cats[b]), at)


## Adds every level of a baked level file. `skip` holds level numbers (1-based positions) to leave out, for a re-make.
## Returns the labels that aren't in the bank (they still block their words).
func add_file(path: String, skip: Array = []) -> PackedStringArray:
	var missing := PackedStringArray()
	if not FileAccess.file_exists(path):
		return missing
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var room := int(data.get("room", 0))
	var tutorial := str(data.get("track", "room")) == "tutorial"
	var levels: Array = data["levels"]
	for i in levels.size():
		if skip.has(i + 1):
			continue
		var at := 0 if tutorial else global_number(room, i + 1)
		var cats: Array = []
		var words: Array = []
		for g: Dictionary in levels[i]["groups"]:
			var idx := bank.find_label(str(g["label"]))
			if idx < 0:
				missing.append(str(g["label"]))
			cats.append(idx)
			words.append(Array(g["words"]))
		add(at, cats, words)
	return missing


static func _far(u: Array, at: int, min_gap: int) -> bool:
	for x in u:
		if absi(at - int(x)) < min_gap:
			return false
	return true


static func _push(d: Dictionary, key: Variant, at: int) -> void:
	var u: Array = d.get(key, [])
	u.append(at)
	d[key] = u


static func _pair(a: int, b: int) -> String:
	return "%d,%d" % [mini(a, b), maxi(a, b)]
