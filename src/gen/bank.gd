## The category bank (data/bank/categories.txt): every category with its label, key word, tier, domain and member
## words. A word listed in two categories belongs to both (that is how herrings and phantom groups are found).
class_name Bank
extends RefCounted

## [{id, label, key, tier, domain, words: PackedStringArray}]
var categories: Array[Dictionary] = []
## id -> index into categories
var by_id := {}
## lower-case word -> PackedInt32Array of category indices
var by_word := {}
## "a,b" (sorted indices) -> true for pairs that may never share a level.
var never := {}
## parent index -> PackedInt32Array of child indices (a child's words are also the parent's).
var children := {}
## index -> Array of domains this category may never share a level with.
var never_domain := {}


## The bank is a .txt in CSV format: Godot imports any .csv as a translation table.
static func load_csv(path: String) -> Bank:
	var b := Bank.new()
	var lines := FileAccess.get_file_as_string(path).split("\n", false)
	for i in range(1, lines.size()):
		var cols := lines[i].strip_edges().split(",")
		if cols.size() < 6:
			continue
		var words := PackedStringArray()
		for w in cols[5].split("|", false):
			words.append(w.strip_edges())
		b.add({"id": cols[0], "label": cols[1], "key": cols[2], "tier": int(cols[3]), "domain": cols[4], "words": words})
	return b


func add(c: Dictionary) -> void:
	var i := categories.size()
	categories.append(c)
	by_id[c["id"]] = i
	for w in c["words"]:
		var k := (w as String).to_lower()
		var hits: PackedInt32Array = by_word.get(k, PackedInt32Array())
		hits.append(i)
		by_word[k] = hits


## Indices of every category a word belongs to.
func homes(word: String) -> PackedInt32Array:
	return by_word.get(word.to_lower(), PackedInt32Array())


## The bank category with this label, or -1 (levels written before the bank name categories by label).
func find_label(label: String) -> int:
	for i in categories.size():
		if (categories[i]["label"] as String).to_lower() == label.to_lower():
			return i
	return -1


## Reads data/bank/pairs.txt: "A < B" (B is part of A), "A | B" (never together), "A ! domain".
func load_pairs(path: String) -> void:
	for raw in FileAccess.get_file_as_string(path).split("\n", false):
		var line := raw.strip_edges()
		if line.begins_with("#") or line == "":
			continue
		for op in ["<", "|", "!"]:
			if not line.contains(" %s " % op):
				continue
			var a := find_label(line.get_slice(" %s " % op, 0).strip_edges())
			var rhs := line.get_slice(" %s " % op, 1).strip_edges()
			if a < 0:
				push_error("bank pairs: unknown category in '%s'" % line)
				break
			if op == "!":
				var ds: Array = never_domain.get(a, [])
				ds.append(rhs)
				never_domain[a] = ds
				break
			var b := find_label(rhs)
			if b < 0:
				push_error("bank pairs: unknown category in '%s'" % line)
				break
			never["%d,%d" % [mini(a, b), maxi(a, b)]] = true
			if op == "<":
				var kids: PackedInt32Array = children.get(a, PackedInt32Array())
				kids.append(b)
				children[a] = kids
			break


func compatible(a: int, b: int) -> bool:
	if never.has("%d,%d" % [mini(a, b), maxi(a, b)]):
		return false
	return not (never_domain.get(a, []) as Array).has(categories[b]["domain"]) \
		and not (never_domain.get(b, []) as Array).has(categories[a]["domain"])


## A category's words plus its children's, for phantom checks.
func family_words(i: int) -> Dictionary:
	var out := {}
	for w in categories[i]["words"]:
		out[(w as String).to_lower()] = true
	for k in children.get(i, PackedInt32Array()):
		for w in categories[k]["words"]:
			out[(w as String).to_lower()] = true
	return out
