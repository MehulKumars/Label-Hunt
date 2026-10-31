## Lints the category bank (data/bank/categories.txt and pairs.txt) and writes reports/lint_bank.md.
## Errors (exit 1): bad rows, duplicate ids or labels, a key not in its label, a label over 22 characters, words that
## aren't single 3-9 letter words, a member containing its own key or label word (Keyboard in "Things with keys"),
## duplicate members, regional or spelling-variant words, taste words, pair rules naming unknown labels.
## Warnings: fewer than 8 members, singular/plural twins in one category, contested words, near-duplicate categories
## (half their words shared) without a pair rule.
## Run: godot --headless --path . -s res://tools/lint_bank.gd [-- --bank=res://data/bank/categories.txt]
extends SceneTree

const DOMAINS := ["food", "drink", "animals", "nature", "home", "objects", "clothing", "culture", "music", "sport",
	"games", "people", "school", "science", "body", "travel", "places", "time", "colour", "tech", "shapes", "lateral",
	"abstract", "wordplay"]
const MAX_LABEL := 22
## Regional (US/UK) words, spelling variants, taste and trademarks (data/bank/notes.md section 2): never ship.
const BANNED := ["chips", "crisps", "cookie", "biscuit", "jelly", "pants", "jumper", "torch", "trainer", "sneaker",
	"eraser", "rubber", "zip", "zipper", "fringe", "bangs", "plait", "yard", "soda", "lemonade", "ladybird", "ladybug",
	"sultana", "prawn", "shrimp", "porridge", "oatmeal", "grey", "gray", "yoghurt", "yogurt", "doughnut", "donut",
	"lasagne", "lasagna", "chilli", "chili", "omelette", "omelet", "coriander", "cilantro", "aubergine", "eggplant",
	"courgette", "zucchini", "metre", "litre", "liter", "tonne", "racket", "racquet", "kebab", "kabob", "caddie",
	"caddy", "chamomile", "camomile", "lychee", "litchi", "liquorice", "licorice", "jewellery", "jewelry", "aluminium",
	"aluminum", "tyre", "pyjamas", "pajamas", "mum", "mom", "nappy", "diaper", "lorry", "petrol", "colour", "color",
	"flavour", "flavor", "gin", "rum", "wine", "beer", "vodka", "whisky", "whiskey", "burgundy", "gun", "rifle",
	"pistol", "bomb", "bullet", "sword", "stiletto", "cracker", "tart", "bogey", "uranus", "frisbee", "velcro", "nylon",
	"stetson", "visa", "lego", "jacuzzi", "hoover", "sellotape", "biro", "kleenex"]
## Words that are fine in one sense and contested in another: flagged for a human look, not refused.
const CONTESTED := ["tomato", "avocado", "coconut", "peanut", "strawberry", "mushroom", "spider", "bat", "koala",
	"orca", "turkey", "china", "congo", "boot", "trunk", "angel", "monk", "cardinal", "turban", "cross", "arrow",
	"knife", "pike", "whale", "jam", "squash", "football", "soccer", "pudding", "candy", "sweets", "pepper", "corn"]

var errors: Array[String] = []
var warnings: Array[String] = []


func _init() -> void:
	var path := "res://data/bank/categories.txt"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bank="):
			path = a.substr(7)
	var cats := read_rows(path, errors)
	lint(cats, "res://data/bank/pairs.txt")
	var md: Array[String] = ["# Bank lint", "", "%d categories, %d errors, %d warnings." % [cats.size(), errors.size(), warnings.size()], ""]
	md.append_array(_summary(cats))
	md.append_array(["", "## Errors", ""])
	md.append_array(errors.map(func(e: String) -> String: return "- " + e))
	md.append_array(["", "## Warnings", ""])
	md.append_array(warnings.map(func(w: String) -> String: return "- " + w))
	DirAccess.make_dir_recursive_absolute("res://reports")
	var f := FileAccess.open("res://reports/lint_bank.md", FileAccess.WRITE)
	f.store_string("\n".join(md) + "\n")
	print("lint: %d categories, %d errors, %d warnings (reports/lint_bank.md)" % [cats.size(), errors.size(), warnings.size()])
	for e in errors.slice(0, 40):
		print("  ERROR " + e)
	quit(1 if not errors.is_empty() else 0)


## Rows of the bank as dictionaries {id, label, key, tier, domain, words: Array[String]}.
static func read_rows(path: String, errs: Array[String]) -> Array:
	var out: Array = []
	var text := FileAccess.get_file_as_string(path)
	var lines := text.split("\n")
	for i in range(1, lines.size()):
		var line := lines[i].strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var cols := line.split(",")
		if cols.size() != 6:
			errs.append("line %d: %d fields, not 6: %s" % [i + 1, cols.size(), line.left(60)])
			continue
		out.append({"id": cols[0], "label": cols[1], "key": cols[2], "tier": int(cols[3]), "domain": cols[4],
			"words": Array(cols[5].split("|", false))})
	return out


func lint(cats: Array, pairs_path: String) -> void:
	var ids := {}
	var labels := {}
	var by_word := {}
	for c: Dictionary in cats:
		var where := "%s (%s)" % [c["id"], c["label"]]
		if ids.has(c["id"]):
			errors.append("duplicate id: " + c["id"])
		ids[c["id"]] = true
		var ll := (c["label"] as String).to_lower()
		if labels.has(ll):
			errors.append("duplicate label: " + c["label"])
		labels[ll] = c
		if not (c["label"] as String).split(" ").has(c["key"]):
			errors.append("%s: key '%s' is not a word of the label" % [where, c["key"]])
		if (c["label"] as String).length() > MAX_LABEL:
			errors.append("%s: label longer than %d characters" % [where, MAX_LABEL])
		if int(c["tier"]) < 1 or int(c["tier"]) > 4:
			errors.append("%s: tier %d" % [where, c["tier"]])
		if not DOMAINS.has(c["domain"]):
			errors.append("%s: unknown domain '%s'" % [where, c["domain"]])
		var words: Array = c["words"]
		if words.size() < 4:
			errors.append("%s: only %d words" % [where, words.size()])
		elif words.size() < 8:
			warnings.append("%s: only %d words (fewer uses)" % [where, words.size()])
		var seen := {}
		var tokens := own_tokens(c)
		for w: String in words:
			var lw := w.to_lower()
			if seen.has(lw):
				errors.append("%s: duplicate member %s" % [where, w])
			seen[lw] = true
			var lw_trim := lw.trim_suffix("s")
			if lw != lw_trim and seen.has(lw_trim) or seen.has(lw + "s"):
				warnings.append("%s: singular/plural twins around %s" % [where, w])
			if w.length() < 3 or w.length() > 9 or w.contains(" ") or w.contains("-") or w[0] != w[0].to_upper():
				errors.append("%s: '%s' is not a single 3-9 letter word in sentence case" % [where, w])
			# A member spelling out its own key gives the link away; that matters where the link is the puzzle.
			for t in tokens:
				if lw.contains(t):
					var msg := "%s: '%s' contains its own label word '%s'" % [where, w, t]
					if int(c["tier"]) >= 3:
						errors.append(msg)
					else:
						warnings.append(msg)
			if BANNED.has(lw):
				errors.append("%s: '%s' is regional, a spelling variant, a taste word or a trademark" % [where, w])
			elif CONTESTED.has(lw):
				warnings.append("%s: '%s' is contested; check its sense here" % [where, w])
			var homes: Array = by_word.get(lw, [])
			homes.append(c)
			by_word[lw] = homes
	# Pair rules must name real labels; near-duplicate categories need one.
	var ruled := {}
	if FileAccess.file_exists(pairs_path):
		for line in FileAccess.get_file_as_string(pairs_path).split("\n"):
			line = line.strip_edges()
			if line == "" or line.begins_with("#"):
				continue
			for op in [" < ", " | ", " ! "]:
				if line.contains(op):
					var a := line.get_slice(op, 0).strip_edges().to_lower()
					var b := line.get_slice(op, 1).strip_edges().to_lower()
					if not labels.has(a):
						errors.append("pairs.txt: unknown label '%s'" % a)
					if op != " ! " and not labels.has(b):
						errors.append("pairs.txt: unknown label '%s'" % b)
					ruled[a + "|" + b] = true
					ruled[b + "|" + a] = true
	var overlap := {}
	for w in by_word:
		var hs: Array = by_word[w]
		for x in hs.size():
			for y in range(x + 1, hs.size()):
				var k: String = hs[x]["id"] + "|" + hs[y]["id"]
				overlap[k] = int(overlap.get(k, 0)) + 1
	for k: String in overlap:
		var a: Dictionary = _find(cats, k.get_slice("|", 0))
		var b: Dictionary = _find(cats, k.get_slice("|", 1))
		var small := mini((a["words"] as Array).size(), (b["words"] as Array).size())
		var key: String = (a["label"] as String).to_lower() + "|" + (b["label"] as String).to_lower()
		if int(overlap[k]) * 2 >= small and not ruled.has(key):
			warnings.append("near-duplicates without a pair rule: %s / %s share %d words" % [a["label"], b["label"], overlap[k]])


## A category's key and label words (and their stems), lower case, that its own members must not contain.
static func own_tokens(c: Dictionary) -> Array[String]:
	const STOP := ["things", "words", "before", "after", "with", "that", "you", "can", "the", "of", "in", "a", "on",
		"at", "and", "kinds", "parts", "shades", "ways", "across", "are", "hidden", "sound", "like", "types", "for"]
	var out: Array[String] = []
	for t in [(c["key"] as String).to_lower()] + Array((c["label"] as String).to_lower().split(" ", false)):
		if t.length() < 3 or STOP.has(t):
			continue
		var stem: String = t.trim_suffix("es") if t.ends_with("ches") or t.ends_with("shes") else t.trim_suffix("s")
		for x in [t, stem]:
			if x.length() >= 3 and not out.has(x):
				out.append(x)
	return out


static func _find(cats: Array, id: String) -> Dictionary:
	for c: Dictionary in cats:
		if c["id"] == id:
			return c
	return {}


func _summary(cats: Array) -> Array[String]:
	var t := {}
	var d := {}
	var words := 0
	for c: Dictionary in cats:
		t[int(c["tier"])] = int(t.get(int(c["tier"]), 0)) + 1
		d[c["domain"]] = int(d.get(c["domain"], 0)) + 1
		words += (c["words"] as Array).size()
	var out: Array[String] = ["| tier | categories |", "|---|---|"]
	var tk := t.keys()
	tk.sort()
	for k in tk:
		out.append("| %d | %d |" % [k, t[k]])
	out.append("")
	out.append("Average members: %.1f. Domains: %s" % [float(words) / maxi(cats.size(), 1), d])
	return out
