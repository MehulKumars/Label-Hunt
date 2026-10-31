## Merges the drafted bank slices (data/bank/drafts/*.txt) into data/bank/categories.txt and pairs.txt.
## Draft lines: "id,label,key,tier,domain,W|W|..." (new), "+id,W|W" (extend), "-id,W|W" (remove), "TIER: id,n",
## "DEL: id", "PAIR: A | B" / "PAIR: A < B" /
## "PAIR: A ! domain", "# WEAK: id Word - reason" (drop a weak member). The merge drops what can't ship (words that
## aren't single 3-9 letter words, banned words, a lateral or wordplay member containing its own key, duplicates),
## skips duplicate labels, and drops categories left with fewer than 6 members. Everything it did is listed in
## reports/bank_merge.md. Run tools/lint_bank.gd afterwards.
## Run: godot --headless --path . -s res://tools/merge_bank.gd [-- --dry] [--only=<file prefix, e.g. review>]
extends SceneTree

const LINT := preload("res://tools/lint_bank.gd")
const BANK := "res://data/bank/categories.txt"
const PAIRS := "res://data/bank/pairs.txt"
const DRAFTS := "res://data/bank/drafts"
const MIN_WORDS := 6


func _init() -> void:
	var dry := OS.get_cmdline_user_args().has("--dry")
	var prefix := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			prefix = a.substr(7)
	var errs: Array[String] = []
	var cats: Array = LINT.read_rows(BANK, errs)
	var by_id := {}
	var by_label := {}
	## Categories that were in the bank before this merge: never dropped for being small (Card suits has 4).
	var original := {}
	for c: Dictionary in cats:
		by_id[c["id"]] = c
		by_label[(c["label"] as String).to_lower()] = c
		original[c["id"]] = true
	var log: Array[String] = []
	var pairs: Array[String] = []
	var weak: Array = []
	var extends_: Array = []
	var removals: Array = []
	var tiers: Array = []
	var deletions: Array = []
	var added := 0
	var files := Array(DirAccess.get_files_at(DRAFTS)).filter(func(f: String) -> bool: return f.ends_with(".txt"))
	files = files.filter(func(f: String) -> bool: return prefix == "" or f.begins_with(prefix))
	files.sort()
	for f: String in files:
		var n_before := added
		for raw in FileAccess.get_file_as_string(DRAFTS + "/" + f).split("\n"):
			var line := raw.strip_edges()
			if line == "":
				continue
			if line.begins_with("# WEAK:"):
				weak.append([f, line.substr(7).strip_edges()])
				continue
			if line.begins_with("#"):
				continue
			if line.begins_with("PAIR:"):
				pairs.append(line.substr(5).get_slice("#", 0).strip_edges())
				continue
			if line.begins_with("-"):
				removals.append([f, line.substr(1).get_slice("#", 0).strip_edges()])
				continue
			if line.begins_with("TIER:"):
				tiers.append([f, line.substr(5).get_slice("#", 0).strip_edges()])
				continue
			if line.begins_with("DEL:"):
				deletions.append([f, line.substr(4).get_slice("#", 0).strip_edges()])
				continue
			if line.begins_with("+"):
				extends_.append([f, line.substr(1).get_slice("#", 0).strip_edges()])
				continue
			var cols := line.split(",")
			if cols.size() != 6:
				log.append("%s: skipped malformed line: %s" % [f, line.left(70)])
				continue
			var c := {"id": cols[0].strip_edges(), "label": cols[1].strip_edges(), "key": cols[2].strip_edges(),
				"tier": int(cols[3]), "domain": cols[4].strip_edges(), "words": Array(cols[5].split("|", false))}
			var ll := (c["label"] as String).to_lower()
			if by_label.has(ll):
				log.append("%s: skipped '%s': the label already exists (%s)" % [f, c["label"], by_label[ll]["id"]])
				continue
			while by_id.has(c["id"]):
				c["id"] = c["id"] + "_b"
			c["words"] = _clean(c, c["words"], log, f)
			if (c["words"] as Array).size() < MIN_WORDS:
				log.append("%s: dropped '%s': only %d members left" % [f, c["label"], (c["words"] as Array).size()])
				continue
			cats.append(c)
			by_id[c["id"]] = c
			by_label[ll] = c
			added += 1
		log.append("%s: %d new categories" % [f, added - n_before])
	# Extensions and weak-member removals apply after every new category exists (a draft may extend another's).
	for e: Array in extends_:
		var id := (e[1] as String).get_slice(",", 0).strip_edges()
		if not by_id.has(id):
			log.append("%s: extension of unknown id %s" % [e[0], id])
			continue
		var c: Dictionary = by_id[id]
		var add := _clean(c, Array((e[1] as String).get_slice(",", 1).split("|", false)), log, e[0])
		for w in add:
			if not (c["words"] as Array).any(func(x: String) -> bool: return x.to_lower() == (w as String).to_lower()):
				(c["words"] as Array).append(w)
	for wk: Array in weak:
		var parts := (wk[1] as String).split(" ", false)
		if parts.size() >= 2 and by_id.has(parts[0]):
			var c: Dictionary = by_id[parts[0]]
			var before := (c["words"] as Array).size()
			c["words"] = (c["words"] as Array).filter(func(x: String) -> bool: return x.to_lower() != parts[1].to_lower())
			if (c["words"] as Array).size() < before:
				log.append("%s: removed weak member %s from %s (%s)" % [wk[0], parts[1], parts[0], wk[1]])
	# Review patches: removals, tier changes, deletions.
	for rm: Array in removals:
		var id := (rm[1] as String).get_slice(",", 0).strip_edges()
		if not by_id.has(id):
			log.append("%s: removal from unknown id %s" % [rm[0], id])
			continue
		var c: Dictionary = by_id[id]
		var gone := {}
		for w in (rm[1] as String).get_slice(",", 1).split("|", false):
			gone[w.strip_edges().to_lower()] = true
		c["words"] = (c["words"] as Array).filter(func(x: String) -> bool: return not gone.has(x.to_lower()))
		log.append("%s: removed %s from %s" % [rm[0], ", ".join(gone.keys()), id])
	for t: Array in tiers:
		var id := (t[1] as String).get_slice(",", 0).strip_edges()
		if by_id.has(id):
			by_id[id]["tier"] = clampi(int((t[1] as String).get_slice(",", 1)), 1, 4)
			log.append("%s: %s is now tier %d" % [t[0], id, by_id[id]["tier"]])
	for dl: Array in deletions:
		var id := str(dl[1]).strip_edges()
		if by_id.has(id):
			cats.erase(by_id[id])
			by_label.erase((by_id[id]["label"] as String).to_lower())
			by_id.erase(id)
			log.append("%s: deleted %s" % [dl[0], id])
	for c: Dictionary in cats.duplicate():
		if (c["words"] as Array).size() < (4 if original.has(c["id"]) else MIN_WORDS):
			cats.erase(c)
			by_label.erase((c["label"] as String).to_lower())
			by_id.erase(c["id"])
			log.append("dropped %s: fewer than %d members after fixes" % [c["id"], MIN_WORDS])
	var pair_added := 0
	var existing_pairs := FileAccess.get_file_as_string(PAIRS)
	var new_pairs: Array[String] = []
	for p in pairs:
		var ok := true
		for op in [" < ", " | ", " ! "]:
			if p.contains(op):
				for side in [p.get_slice(op, 0).strip_edges(), p.get_slice(op, 1).strip_edges()]:
					if op == " ! " and side == p.get_slice(op, 1).strip_edges():
						continue
					if not by_label.has(side.to_lower()):
						ok = false
		if not ok:
			log.append("pair rule names an unknown label: " + p)
			continue
		if not existing_pairs.contains(p) and not new_pairs.has(p):
			new_pairs.append(p)
			pair_added += 1
	log.append("%d categories now (%d new), %d pair rules added" % [cats.size(), added, pair_added])
	if not dry:
		var out: Array[String] = ["id,label,key,tier,domain,words"]
		for c: Dictionary in cats:
			out.append("%s,%s,%s,%d,%s,%s" % [c["id"], c["label"], c["key"], c["tier"], c["domain"], "|".join(c["words"])])
		var fb := FileAccess.open(BANK, FileAccess.WRITE)
		fb.store_string("\n".join(out) + "\n")
		if not new_pairs.is_empty():
			var fp := FileAccess.open(PAIRS, FileAccess.READ_WRITE)
			fp.seek_end()
			fp.store_string("# Merged from data/bank/drafts\n" + "\n".join(new_pairs) + "\n")
	DirAccess.make_dir_recursive_absolute("res://reports")
	var fr := FileAccess.open("res://reports/bank_merge.md", FileAccess.WRITE)
	fr.store_string("# Bank merge%s\n\n" % (" (dry run)" if dry else "") + "\n".join(log.map(func(l: String) -> String: return "- " + l)) + "\n")
	print(log.back())
	quit()


## The members that can ship: single 3-9 letter words in sentence case, not banned, not repeating, and (for lateral
## and wordplay categories) not containing their own key.
func _clean(c: Dictionary, words: Array, log: Array[String], f: String) -> Array:
	var out: Array = []
	var tokens: Array[String] = []
	if int(c["tier"]) >= 3:
		tokens = LINT.own_tokens(c)
	for raw: String in words:
		var w := raw.strip_edges()
		if w == "":
			continue
		w = w[0].to_upper() + w.substr(1)
		var lw := w.to_lower()
		var why := ""
		if w.length() < 3 or w.length() > 9 or w.contains(" ") or w.contains("-") or w.contains("'"):
			why = "not a single 3-9 letter word"
		elif LINT.BANNED.has(lw):
			why = "banned word"
		elif tokens.any(func(t: String) -> bool: return lw.contains(t)):
			why = "contains its own key"
		elif out.any(func(x: String) -> bool: return x.to_lower() == lw):
			why = "duplicate"
		if why != "":
			log.append("%s: %s dropped '%s' (%s)" % [f, c["id"], w, why])
			continue
		out.append(w)
	return out
