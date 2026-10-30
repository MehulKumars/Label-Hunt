## A level as authored or baked: its groups, starting jars and jar types.
## Cards are ids g * CAPACITY + i, so a card's group is card >> 2.
class_name LevelData
extends RefCounted

const CAPACITY := 4

var id: String = ""
## Each group: {label: String, key: String, words: PackedStringArray}
var groups: Array[Dictionary] = []
## Bottom -> top card ids per jar.
var jars: Array[PackedInt32Array] = []
## card id -> PackedInt32Array of other level groups the word plausibly fits (herrings).
var also: Dictionary = {}
var frost: PackedInt32Array = PackedInt32Array()
## jar index -> group index printed on that jar.
var labelled: Dictionary = {}
var corked: PackedInt32Array = PackedInt32Array()
## 0 = no slip budget.
var budget: int = 0
var tutorial: String = ""
var meta: Dictionary = {}


static func group_of(card: int) -> int:
	return card >> 2


func group_count() -> int:
	return groups.size()


func card_count() -> int:
	return groups.size() * CAPACITY


func word(card: int) -> String:
	return groups[group_of(card)]["words"][card % CAPACITY]


func memberships(card: int) -> PackedInt32Array:
	var m := PackedInt32Array([group_of(card)])
	if also.has(card):
		m.append_array(also[card])
	return m


func card_of_word(w: String) -> int:
	for g in groups.size():
		var idx: int = (groups[g]["words"] as PackedStringArray).find(w)
		if idx >= 0:
			return g * CAPACITY + idx
	return -1


## Parses the authored form, where jars, also and frost name words, not ids.
static func from_dict(d: Dictionary) -> LevelData:
	var l := LevelData.new()
	l.id = str(d.get("id", ""))
	for gd in d.get("groups", []):
		l.groups.append({
			"label": str(gd["label"]),
			"key": str(gd.get("key", gd["label"])),
			"words": PackedStringArray(gd["words"]),
			"tier": int(gd.get("tier", 1)),
		})
	for jar_words in d.get("jars", []):
		var jar := PackedInt32Array()
		for w in jar_words:
			var c := l.card_of_word(str(w))
			assert(c >= 0, "level %s: unknown word %s" % [l.id, w])
			jar.append(c)
		l.jars.append(jar)
	for i in int(d.get("empty", 0)):
		l.jars.append(PackedInt32Array())
	var also_d: Dictionary = d.get("also", {})
	for w in also_d:
		var extra := PackedInt32Array()
		for g in also_d[w]:
			extra.append(int(g))
		l.also[l.card_of_word(str(w))] = extra
	for w in d.get("frost", []):
		l.frost.append(l.card_of_word(str(w)))
	var lab: Dictionary = d.get("labelled", {})
	for j in lab:
		l.labelled[int(j)] = int(lab[j])
	for j in d.get("corked", []):
		l.corked.append(int(j))
	l.budget = int(d.get("budget", 0))
	l.tutorial = str(d.get("tutorial", ""))
	l.meta = d.get("meta", {})
	return l


func to_dict() -> Dictionary:
	var gs: Array = []
	for g in groups:
		var gd := {"label": g["label"], "key": g["key"], "words": Array(g["words"])}
		if int(g.get("tier", 1)) != 1:
			gd["tier"] = g["tier"]
		gs.append(gd)
	var js: Array = []
	for jar in jars:
		var ws: Array = []
		for c in jar:
			ws.append(word(c))
		js.append(ws)
	var also_d := {}
	for c in also:
		also_d[word(c)] = Array(also[c])
	var frost_w: Array = []
	for c in frost:
		frost_w.append(word(c))
	var lab := {}
	for j in labelled:
		lab[str(j)] = labelled[j]
	return {
		"id": id, "groups": gs, "jars": js, "also": also_d, "frost": frost_w,
		"labelled": lab, "corked": Array(corked), "budget": budget, "tutorial": tutorial,
	}


## Stable hash of everything that defines play (not meta), used to detect re-bakes under a saved board.
func fingerprint() -> String:
	var d := to_dict()
	d.erase("id")
	return JSON.stringify(d, "", true).sha256_text().substr(0, 16)
