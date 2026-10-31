## Re-checks every baked room level against the current bank (data/levels/index.json), so a bank edit can't quietly
## break a level that was baked before it. Errors (exit 1): more than one way to split the cards, an unsolvable deal,
## same-group cards touching, a phantom group (a bank category outside the level holding 3+ of its words), a card
## that reads as naming another group's label, a group word no longer in its bank category, and a Hint walk (always
## doing what the Hint says) that doesn't win. Warnings: a category reused within 25 levels, labels not in the bank.
## Writes reports/audit_content.md.
## Run: godot --headless --path . -s res://tools/audit_content.gd [-- --rooms=1,3-5 --no-hints]
extends SceneTree

const LEVELS := preload("res://src/core/levels.gd")
const BANK := "res://data/bank/categories.txt"
const PAIRS := "res://data/bank/pairs.txt"
const NEAR := 25

var bank: Bank
var errors: Array[String] = []
var warnings: Array[String] = []


func _init() -> void:
	var rooms: Array[int] = []
	var hints := true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rooms="):
			for part in a.substr(8).split(","):
				if part.contains("-"):
					for x in range(int(part.get_slice("-", 0)), int(part.get_slice("-", 1)) + 1):
						rooms.append(x)
				else:
					rooms.append(int(part))
		elif a == "--no-hints":
			hints = false
	bank = Bank.load_csv(BANK)
	bank.load_pairs(PAIRS)
	var cat := Catalog.from_files(LEVELS.files())
	var uses := {}
	var checked := 0
	var t0 := Time.get_ticks_msec()
	for r in cat.room_numbers():
		for id in cat.room_ids(r):
			var at := cat.order_index(id) + 1
			for g: Dictionary in cat.entry(id)["data"]["groups"]:
				var u: Array = uses.get(str(g["label"]), [])
				for x in u:
					if absi(at - int(x)) < NEAR:
						warnings.append("%s: %s again within %d levels (level %d)" % [id, g["label"], NEAR, x])
				u.append(at)
				uses[str(g["label"])] = u
			if not rooms.is_empty() and not rooms.has(r):
				continue
			_check(id, cat.level(id), cat.entry(id)["data"], hints)
			checked += 1
	var md: Array[String] = ["# Content audit", "", "%d levels checked in %.0f s: %d errors, %d warnings." % [
		checked, (Time.get_ticks_msec() - t0) / 1000.0, errors.size(), warnings.size()], "", "## Errors", ""]
	md.append_array(errors.map(func(e: String) -> String: return "- " + e))
	md.append_array(["", "## Warnings", ""])
	md.append_array(warnings.map(func(w: String) -> String: return "- " + w))
	DirAccess.make_dir_recursive_absolute("res://reports")
	var f := FileAccess.open("res://reports/audit_content.md", FileAccess.WRITE)
	f.store_string("\n".join(md) + "\n")
	print(md[2])
	for e in errors.slice(0, 30):
		print("  ERROR " + e)
	quit(1 if not errors.is_empty() else 0)


func _check(id: String, lvl: LevelData, d: Dictionary, hints: bool) -> void:
	if ExactCover.count(lvl) != 1:
		errors.append("%s: the cards split more than one way" % id)
	if not Dealer.no_adjacent_pairs(lvl.jars):
		errors.append("%s: same-group cards touch in the deal" % id)
	if not Solver.solve(BoardState.from_level(lvl), 200000)["solved"]:
		errors.append("%s: the deal is not solvable" % id)
	var cats: Array[int] = []
	var words: Array = []
	for g: Dictionary in d["groups"]:
		var idx := bank.find_label(str(g["label"]))
		cats.append(idx)
		words.append(Array(g["words"]))
		if idx < 0:
			warnings.append("%s: label '%s' is not in the bank" % [id, g["label"]])
			continue
		var members := {}
		for w in bank.family_words(idx):
			members[w] = true
		for w in g["words"]:
			if not members.has(str(w).to_lower()):
				errors.append("%s: '%s' is no longer in %s" % [id, w, g["label"]])
	# Phantom groups.
	for i in bank.categories.size():
		if cats.has(i):
			continue
		var family := bank.family_words(i)
		var own := -1
		for a in cats.size():
			if cats[a] >= 0 and (bank.children.get(i, PackedInt32Array()) as PackedInt32Array).has(cats[a]):
				own = a
		var hits: Array[String] = []
		for a in words.size():
			if a == own:
				continue
			for w in words[a]:
				if family.has(str(w).to_lower()):
					hits.append(str(w))
		if hits.size() >= (1 if own >= 0 else 3):
			errors.append("%s: phantom group %s (%s)" % [id, bank.categories[i]["label"], ", ".join(hits)])
	# A card that reads as naming another group's label.
	for a in words.size():
		for b in d["groups"].size():
			if a == b:
				continue
			var key := str(d["groups"][b]["key"]).to_lower()
			var stem := key.trim_suffix("s")
			for w in words[a]:
				var lw := str(w).to_lower()
				if key.length() >= 3 and (lw.contains(key) or (stem.length() >= 3 and lw.contains(stem))):
					errors.append("%s: '%s' reads as naming '%s'" % [id, w, d["groups"][b]["label"]])
	if hints:
		var s := Session.new(lvl, {})
		for step in 400:
			if s.won:
				break
			var adv := Advisor.next_move(s.board, 0)
			if adv["kind"] == "none":
				break
			var mv: Vector2i = adv["move"]
			s.try_move(mv.x, mv.y)
		if not s.won:
			errors.append("%s: following Hints alone doesn't win" % id)
