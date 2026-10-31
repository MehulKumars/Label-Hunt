## Makes rooms of levels from the category bank and the room specs, in two phases.
##
## 1. --pick (fast, no bots): for every level of the given rooms, in order, pick categories (the spec's tier mix,
##    one per domain, herrings from real crossings, no phantom groups, no label clashes, a unique cover) and 4 words
##    each, checked against the global reuse ledger (every other baked room counts). Writes data/rooms/picks/roomN.json
##    and reports/pick.md. With --dry nothing is written but the report: the bank shortfall in minutes.
## 2. --settle (one room per process; run several at once): deal each picked level a few seeded ways (with its special
##    jars), keep the deal whose bot-measured slips are nearest the target, then set the budget (the tightest slip limit
##    at which the average bot still wins at the level's floor rate) and the gold threshold. Writes
##    data/levels/roomN.json, data/levels/index.json and reports/roomN_gen.md (+ .csv).
## --rebudget re-settles budgets and gold of existing levels (keeping words and deals).
##
## Run:
##   godot --headless --path . -s res://tools/room_gen.gd -- --pick --rooms=1,3-17 [--dry] [--only=1,2] [--seed=1]
##   godot --headless --path . -s res://tools/room_gen.gd -- --settle --room=3 [--only=1,2] [--deals=6 --n=30 --final=200]
##   godot --headless --path . -s res://tools/room_gen.gd -- --rebudget --room=2 --levels=1-10
extends SceneTree

const SPEC := "res://data/rooms/room%d_spec.json"
const PICKS := "res://data/rooms/picks/room%d.json"
const LEVELS := "res://data/levels/room%d.json"
const INDEX := "res://data/levels/index.json"
const BANK := "res://data/bank/categories.txt"
const PAIRS := "res://data/bank/pairs.txt"
const TUTORIAL := "res://data/levels/tutorial.json"
const MAX_WORD := 9
## Stands for "never won" in a sorted list of slips.
const STUCK := 999
## Sampling noise allowed when checking a budget against its floor (the curve report allows the same).
const FLOOR_TOLERANCE := 0.03
## When a level can't be picked the gaps relax step by step: (category gap, word gap, tries).
const RELAX := [Vector3i(60, 30, 60), Vector3i(40, 20, 120), Vector3i(25, 12, 160), Vector3i(15, 8, 240)]
## Domains whose categories cut across every other domain: two of them share a level only with different patterns.
const PATTERN_DOMAINS := ["lateral", "abstract", "wordplay"]

var bank: Bank
var ledger: Ledger
var rng := RandomNumberGenerator.new()
var base_seed := 1
var deals := 6
var n := 30
var n_final := 200
var rejects := {}
var _crossings: Array = []


func _init() -> void:
	var mode := ""
	var rooms: Array[int] = []
	var only: Array[int] = []
	var dry := false
	for a in OS.get_cmdline_user_args():
		var v := a.get_slice("=", 1)
		match a.get_slice("=", 0):
			"--pick": mode = "pick"
			"--settle": mode = "settle"
			"--rebudget": mode = "rebudget"
			"--dry": dry = true
			"--rooms", "--room": rooms = _ranges(v)
			"--only", "--levels": only = _ranges(v)
			"--seed": base_seed = int(v)
			"--deals": deals = int(v)
			"--n": n = int(v)
			"--final": n_final = int(v)
	bank = Bank.load_csv(BANK)
	bank.load_pairs(PAIRS)
	bank.load_targets("res://data/bank/wordplay_targets.txt")
	bank.load_hard("res://data/bank/hard_words.txt")
	match mode:
		"pick":
			quit(_pick_rooms(rooms, only, dry))
		"settle":
			quit(_settle_room(rooms[0], only))
		"rebudget":
			quit(_rebudget(rooms[0], only))
		_:
			push_error("room_gen: say --pick, --settle or --rebudget")
			quit(1)


# --- phase 1: pick ------------------------------------------------------------------------------------------------

func _pick_rooms(rooms: Array[int], only: Array[int], dry: bool) -> int:
	rooms.sort()
	ledger = Ledger.new(bank)
	ledger.add_file(TUTORIAL)
	# Every baked room counts, except the levels this run re-picks.
	for path in _room_files():
		var r := int(path.get_file().trim_prefix("room").trim_suffix(".json"))
		if rooms.has(r):
			if only.is_empty():
				continue
			ledger.add_file(path, only)
		else:
			ledger.add_file(path)
	var md: Array[String] = ["# Category picks%s" % (" (dry run)" if dry else ""), "",
		"Bank: %d categories (%s). Seed %d." % [bank.categories.size(), _tier_counts(), base_seed], "",
		"| room | L | kind | groups (tier) | herrings | relax | rejects |", "|---|---|---|---|---|---|---|"]
	var failed := 0
	var t0 := Time.get_ticks_msec()
	for room in rooms:
		var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPEC % room))
		var out: Array = []
		var levels: Array = spec["levels"]
		for i in levels.size():
			var number := i + 1
			var ls: Dictionary = levels[i]
			if ls.get("keep", false) or (not only.is_empty() and not only.has(number)):
				continue
			var at := Ledger.global_number(room, number)
			var res := _pick_level(room, number, ls, at)
			var pick: Dictionary = res["pick"]
			if pick.is_empty():
				failed += 1
				md.append("| %d | %d | %s | **none** | %d | - | %s |" % [room, number, ls["kind"], int(ls.get("herrings", 0)), rejects])
				print(md.back())
				continue
			ledger.add(at, pick["cats"], pick["words"])
			var lvl := _level_dict(room, number, ls, pick, spec)
			out.append({"number": number, "level": lvl, "spec": ls})
			var names: Array = []
			for g: Dictionary in lvl["groups"]:
				names.append("%s (%d)" % [g["label"], g["tier"]])
			md.append("| %d | %d | %s | %s | %d | %d | %s |" % [room, number, ls["kind"], ", ".join(names),
				(lvl["also"] as Dictionary).size(), res["relax"], rejects if res["relax"] > 0 else ""])
			print(md.back())
		if not dry:
			DirAccess.make_dir_recursive_absolute("res://data/rooms/picks")
			JsonOut.write(PICKS % room, {"room": room, "name": spec.get("name", ""), "seed": base_seed,
				"bank": FileAccess.get_md5(BANK).left(12), "levels": out})
	md.append("")
	md.append("%d levels could not be picked. Took %.0f s." % [failed, (Time.get_ticks_msec() - t0) / 1000.0])
	md.append_array(_reuse_report())
	DirAccess.make_dir_recursive_absolute("res://reports")
	_write("res://reports/pick%s.md" % ("_dry" if dry else ""), "\n".join(md))
	print("%d levels could not be picked" % failed)
	return 1 if failed > 0 and not dry else 0


## {pick: {cats, words, also} or {}, relax: the relax step that worked}
func _pick_level(room: int, number: int, ls: Dictionary, at: int) -> Dictionary:
	rejects.clear()
	for step in RELAX.size():
		ledger.gap = RELAX[step].x
		ledger.word_gap = RELAX[step].y
		for t in RELAX[step].z:
			rng.seed = hash([base_seed, room, number, step, t])
			var pick := _pick(ls, at)
			if not pick.is_empty():
				return {"pick": pick, "relax": step}
	return {"pick": {}, "relax": RELAX.size()}


## {cats: Array[int], words: Array[PackedStringArray], also: {word: [group]}} or {} when this try fails.
func _pick(ls: Dictionary, at: int) -> Dictionary:
	var cats: Array[int] = []
	var domains := {}
	var exclude: Array = ls.get("exclude", [])
	var tiers: Array = (ls["tiers"] as Array).map(func(t: Variant) -> int: return int(t))  # JSON numbers are floats
	Dealer._shuffle_array(tiers, rng)
	var want := int(ls.get("herrings", 0))
	var familiar: bool = ls.get("familiar", false)
	# A level that needs a herring starts from a real crossing: two categories sharing a word.
	if want > 0:
		var pair := _crossing_pair(at, tiers, exclude, familiar)
		if pair.is_empty():
			_reject("no crossing pair")
			return {}
		for idx in pair:
			cats.append(idx)
			domains[_domain_key(idx)] = true
			tiers.erase(int(bank.categories[idx]["tier"]))
	for t in tiers:
		var pool: Array[int] = []
		for i in bank.categories.size():
			var c: Dictionary = bank.categories[i]
			if int(c["tier"]) != int(t) or cats.has(i) or exclude.has(c["domain"]) or domains.has(_domain_key(i)):
				continue
			if not ledger.cat_ok(i, at) or not cats.all(func(k: int) -> bool: return bank.compatible(i, k) and ledger.pair_ok(i, k, at)):
				continue
			pool.append(i)
			if ledger.uses(i) == 0:
				pool.append(i)  # never-used categories are twice as likely
			if want > 1 and _crosses(i, cats):
				for k in 6:
					pool.append(i)  # a second herring needs another crossing
		if pool.is_empty():
			_reject("no category for tier %d" % t)
			return {}
		var pick: int = pool[rng.randi_range(0, pool.size() - 1)]
		cats.append(pick)
		domains[_domain_key(pick)] = true
	# Words that belong to two picked categories are herrings; keep exactly as many as the spec asks.
	var crossings: Array = []
	for a in cats.size():
		for w in bank.categories[cats[a]]["words"]:
			if w.length() > MAX_WORD or not ledger.word_ok(w, at) or (familiar and bank.hard.has(w.to_lower())):
				continue
			for h in bank.homes(w):
				var b := cats.find(h)
				if b >= 0 and b != a:
					crossings.append([w, a, b])
	Dealer._shuffle_array(crossings, rng)
	var herrings: Array = []
	for x: Array in crossings:
		if herrings.size() >= want:
			break
		if herrings.all(func(y: Array) -> bool: return (y[0] as String).to_lower() != (x[0] as String).to_lower()):
			herrings.append(x)
	if herrings.size() < want:
		_reject("too few crossings")
		return {}
	var herring_words := {}
	for x: Array in herrings:
		herring_words[(x[0] as String).to_lower()] = x
	var words: Array[PackedStringArray] = []
	for a in cats.size():
		var chosen := _choose_words(cats, a, herrings, herring_words, at, familiar)
		if chosen.is_empty():
			return {}
		words.append(chosen)
	# Wordplay: no other group's word may obey a wordplay group's rule, unless it is that group's declared herring.
	for a in cats.size():
		if not bank.targets.has(cats[a]):
			continue
		for b in words.size():
			if b == a:
				continue
			for w in words[b]:
				var hx: Array = herring_words.get(w.to_lower(), [])
				if bank.trips(cats[a], w) and not (not hx.is_empty() and hx[2] == a):
					_reject("wordplay overlap")
					return {}
	# Label clashes: a card must not read as naming another group's jar ("Gear" beside "Sports gear").
	for a in words.size():
		for b in cats.size():
			if a == b:
				continue
			for token in _label_tokens(cats[b]):
				for w in words[a]:
					var lw := w.to_lower()
					if lw.contains(token) or (lw.length() >= 3 and token.contains(lw)):
						_reject("label clash")
						return {}
	# Phantom groups: no category outside the level (with its children's words) may hold 3 or more of its words from
	# two or more groups (three from one group mislead nobody: they belong together anyway).
	# A parent of a picked category may hold none outside that category's own group (Fruit next to Citrus fruit).
	var all_words: Array = []
	for ws in words:
		all_words.append_array(Array(ws))
	for i: int in bank.families_holding(all_words):
		if cats.has(i):
			continue
		var family := bank.family_words(i)
		var own := -1
		for a in cats.size():
			if (bank.children.get(i, PackedInt32Array()) as PackedInt32Array).has(cats[a]):
				own = a
		var hits := 0
		var groups_hit := 0
		for a in words.size():
			if a == own:
				continue
			var here := 0
			for w in words[a]:
				if family.has(w.to_lower()):
					here += 1
			hits += here
			if here > 0:
				groups_hit += 1
		if (own >= 0 and hits >= 1) or (hits >= 3 and groups_hit >= 2):
			_reject("phantom")
			return {}
	var also := {}
	for x: Array in herrings:
		also[x[0]] = [x[2]]
	# A fair level splits into its groups exactly one way, herrings included.
	var probe := LevelData.from_dict({"groups": _groups(cats, words), "also": also})
	if ExactCover.count(probe) != 1:
		_reject("cover")
		return {}
	return {"cats": cats, "words": words, "also": also}


## Four words for group `a`: its herrings first, then fresh words (not in earlier uses of the category) before
## reused ones, never a word of another picked category, and at most 2 shared with any earlier use. A `familiar` level
## leaves out the hard-word list (early levels and breathers test thinking, not vocabulary).
func _choose_words(cats: Array[int], a: int, herrings: Array, herring_words: Dictionary, at: int, familiar: bool) -> PackedStringArray:
	var idx := cats[a]
	var chosen := PackedStringArray()
	for x: Array in herrings:
		if x[1] == a:
			chosen.append(x[0])
	var fresh: Array = []
	var reused: Array = []
	for w in bank.categories[idx]["words"]:
		var lw := (w as String).to_lower()
		if herring_words.has(lw) or w.length() > MAX_WORD or w.length() < 3 or not ledger.word_ok(w, at):
			continue
		if familiar and bank.hard.has(lw):
			continue
		if Array(bank.homes(w)).any(func(h: int) -> bool: return h != idx and cats.has(h)):
			continue
		if cats.any(func(h: int) -> bool: return h != idx and bank.trips(h, w)):
			continue  # it obeys another group's wordplay rule
		(reused if ledger.used_in(idx, w) else fresh).append(w)
	Dealer._shuffle_array(fresh, rng)
	Dealer._shuffle_array(reused, rng)
	for w in fresh + reused:
		if chosen.size() >= 4:
			break
		chosen.append(w)
	if chosen.size() < 4:
		_reject("too few free words")
		return PackedStringArray()
	if not ledger.words_ok(idx, chosen, at):
		_reject("same words as before")
		return PackedStringArray()
	return chosen


func _groups(cats: Array, words: Array) -> Array:
	var groups: Array = []
	for a in cats.size():
		var c: Dictionary = bank.categories[cats[a]]
		groups.append({"label": c["label"], "key": c["key"], "tier": c["tier"], "words": Array(words[a])})
	return groups


func _level_dict(room: int, number: int, ls: Dictionary, pick: Dictionary, spec: Dictionary) -> Dictionary:
	var prefix: String = spec.get("id_prefix", "l%d" % room)
	return {
		"id": "%s-%02d" % [prefix, number], "kind": ls["kind"], "introduces": ls.get("introduces", []),
		"budget": 0, "groups": _groups(pick["cats"], pick["words"]), "also": pick["also"],
	}


## Two allowed categories from different domains whose tiers fit the spec and that share a word, or [].
func _crossing_pair(at: int, tiers: Array, exclude: Array, familiar: bool) -> Array:
	if _crossings.is_empty():
		# Every (word, a, b) that could ever be a herring, worked out once: the ledger and spec filter it per try.
		for w in bank.by_word:
			var hs: PackedInt32Array = bank.by_word[w]
			if hs.size() < 2 or (w as String).length() > MAX_WORD:
				continue
			for x in hs.size():
				for y in hs.size():
					var a := hs[x]
					var b := hs[y]
					if a != b and _domain_key(a) != _domain_key(b) and bank.compatible(a, b):
						_crossings.append([w, a, b])
	var pairs: Array = []
	for cr: Array in _crossings:
		var a: int = cr[1]
		var b: int = cr[2]
		var ca: Dictionary = bank.categories[a]
		var cb: Dictionary = bank.categories[b]
		if exclude.has(ca["domain"]) or exclude.has(cb["domain"]):
			continue
		var left := tiers.duplicate()
		if not left.has(int(ca["tier"])):
			continue
		left.erase(int(ca["tier"]))
		if not left.has(int(cb["tier"])):
			continue
		if not ledger.word_ok(cr[0], at) or not ledger.cat_ok(a, at) or not ledger.cat_ok(b, at) or not ledger.pair_ok(a, b, at):
			continue
		if familiar and bank.hard.has(cr[0]):
			continue
		pairs.append([a, b])
	return [] if pairs.is_empty() else pairs[rng.randi_range(0, pairs.size() - 1)]
# --- phase 2: settle ----------------------------------------------------------------------------------------------

func _settle_room(room: int, only: Array[int]) -> int:
	var picks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PICKS % room))
	var existing := {}
	if not only.is_empty() and FileAccess.file_exists(LEVELS % room):
		existing = JSON.parse_string(FileAccess.get_file_as_string(LEVELS % room))
	var levels: Array = existing.get("levels", [])
	var md: Array[String] = ["# Room %d settle" % room, "",
		"Seed %d, %d deals x %d games each; finals %d games per profile. Budget = the tightest slip limit at which the average bot still wins at the level's floor rate. Win rates are with the budget." % [
			base_seed, deals, n, n_final], "",
		"| L | kind | groups (tier) | herrings | jars | budget | gold | target | avg slips | floor | avg win | novice win | prober win | after-aha | aha at |",
		"|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
	var csv: Array[String] = ["level,kind,groups,herrings,budget,gold,target,avg_slips,floor,avg_win,novice_win,prober_win,after_med,aha_frac"]
	var t0 := Time.get_ticks_msec()
	var failed := 0
	for p: Dictionary in picks["levels"]:
		var number := int(p["number"])
		if not only.is_empty() and not only.has(number):
			continue
		var ls: Dictionary = p["spec"]
		var res := _settle_level(room, number, p["level"], ls)
		if res.is_empty():
			failed += 1
			push_error("room_gen: no solvable deal for room %d level %d" % [room, number])
			continue
		var d: Dictionary = res["d"]
		while levels.size() < number:
			levels.append({})
		levels[number - 1] = d
		var names: Array = []
		for g: Dictionary in d["groups"]:
			names.append("%s (%d)" % [g["label"], g["tier"]])
		var m: Dictionary = d["meta"]
		md.append("| %d | %s | %s | %d | %s | %s | %s | %.2f | %.2f | %.2f | %s | %s | %s | %d | %d%% |" % [number, ls["kind"],
			", ".join(names), (d["also"] as Dictionary).size(), _jar_note(d), str(d["budget"]) if int(d["budget"]) > 0 else "-",
			str(d["gold"]) if int(d["gold"]) >= 0 else "-", m["target"], m["avg_slips"], m["floor"], _pct(m["avg_win"]),
			_pct(m["novice_win"]), _pct(m["prober_win"]), m["after_med"], roundi(float(m["aha_frac"]) * 100)])
		csv.append("%d,%s,%d,%d,%d,%d,%.2f,%.2f,%.2f,%.3f,%.3f,%.3f,%d,%.2f" % [number, ls["kind"], d["groups"].size(),
			(d["also"] as Dictionary).size(), d["budget"], d["gold"], m["target"], m["avg_slips"], m["floor"], m["avg_win"],
			m["novice_win"], m["prober_win"], m["after_med"], m["aha_frac"]])
		print(md.back())
	var file := {"version": 3, "track": "room", "room": room, "name": picks.get("name", ""),
		"gen": {"seed": base_seed, "bank": picks.get("bank", "")}, "levels": levels}
	JsonOut.write(LEVELS % room, file)
	write_index()
	md.append("")
	md.append("Settled in %.0f s." % ((Time.get_ticks_msec() - t0) / 1000.0))
	DirAccess.make_dir_recursive_absolute("res://reports")
	var suffix := "" if only.is_empty() else "_part"
	_write("res://reports/room%d_gen%s.md" % [room, suffix], "\n".join(md))
	_write("res://reports/room%d_gen%s.csv" % [room, suffix], "\n".join(csv))
	print(md.back())
	return 1 if failed > 0 else 0


## Deals a picked level `deals` ways, keeps the deal nearest the target, then budgets it. {} if no deal is solvable.
func _settle_level(room: int, number: int, level: Dictionary, ls: Dictionary) -> Dictionary:
	var target := float(ls.get("target", 1.0))
	var best := {}
	for k in deals:
		var lvl := LevelData.from_dict(level)
		var r := RandomNumberGenerator.new()
		r.seed = hash([base_seed, room, number, k])
		if not Dealer.deal_spec(lvl, ls, r):
			continue
		var m := _measure(lvl, "average", n, 0)
		var score := absf(m["slips_mean"] - target)
		# A deal that strands players (stuck past Undo and +Jar) can't meet its floor at any slip limit.
		score += maxf(0.0, float(ls.get("floor", 0.8)) + 0.05 - m["win"]) * 10.0
		if number >= 3 and ls["kind"] != "rest" and m["aha_frac"] < 0.4:
			score += 1.5
		score += maxf(0.0, m["after_med"] - 8.0) * 0.25
		if best.is_empty() or score < best["score"]:
			best = {"score": score, "lvl": lvl}
	if best.is_empty():
		return {}
	var d := level.duplicate(true)
	_write_deal(d, best["lvl"])
	return {"d": _budget(d, best["lvl"], ls)}


func _write_deal(d: Dictionary, lvl: LevelData) -> void:
	d["jars"] = _jar_words(lvl)
	d.erase("empty")
	var frost: Array = []
	for c in lvl.frost:
		frost.append(lvl.word(c))
	if not frost.is_empty():
		d["frost"] = frost
	if not lvl.labelled.is_empty():
		var lab := {}
		for j in lvl.labelled:
			lab[str(j)] = lvl.labelled[j]
		d["labelled"] = lab
	if not lvl.corked.is_empty():
		d["corked"] = Array(lvl.corked)


## Sets budget, gold and meta from the bots. The budget is the smallest slip limit at which the average bot wins at
## least `floor` of the time (and the novice at least `novice_floor`), never below 2. Gold is the largest slip count
## below the budget that 20-50% of average runs stay within (else the one nearest 35%).
func _budget(d: Dictionary, lvl: LevelData, ls: Dictionary) -> Dictionary:
	var nov := _measure(lvl, "novice", n_final, 0)
	var avg := _measure(lvl, "average", n_final, 0)
	var floor_avg := float(ls.get("floor", 0.8))
	var floor_nov := float(ls.get("novice_floor", 0.0))
	var budget := 0
	var gold := -1
	if ls.get("budget", false):
		budget = maxi(2, _floor_slips(avg["slips"], floor_avg) + 1)
		if floor_nov > 0.0:
			budget = maxi(budget, _floor_slips(nov["slips"], floor_nov) + 1)
		# That count comes from games without a limit, and a limit changes the play: check it, give room if needed.
		for extra in 3:
			if _measure(lvl, "average", n_final / 2, budget, 7)["win"] >= floor_avg - FLOOR_TOLERANCE:
				break
			budget += 1
		gold = _gold(avg["slips"], budget)
	d["budget"] = budget
	d["gold"] = gold
	lvl.budget = budget
	var avg_w := _measure(lvl, "average", n_final / 2, budget, 7)
	var nov_w := _measure(lvl, "novice", n_final / 2, budget, 7)
	var pro_w := _measure(lvl, "prober", n_final / 2, budget, 7)
	d["meta"] = {"target": snappedf(float(ls.get("target", 0.0)), 0.01), "floor": floor_avg,
		"avg_slips": snappedf(avg["slips_mean"], 0.01), "avg_win": snappedf(avg_w["win"], 0.01),
		"novice_win": snappedf(nov_w["win"], 0.01), "prober_win": snappedf(pro_w["win"], 0.01),
		"after_med": avg["after_med"], "aha_frac": snappedf(avg["aha_frac"], 0.01)}
	return d


func _rebudget(room: int, only: Array[int]) -> int:
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPEC % room))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEVELS % room))
	for i in (data["levels"] as Array).size():
		if not only.is_empty() and not only.has(i + 1):
			continue
		var d: Dictionary = data["levels"][i]
		var lvl := LevelData.from_dict(d)
		var ls: Dictionary = spec["levels"][i]
		_budget(d, lvl, ls)
		print("%s budget=%d gold=%d avg_win=%.2f novice_win=%.2f" % [d["id"], d["budget"], d["gold"],
			d["meta"]["avg_win"], d["meta"]["novice_win"]])
	JsonOut.write(LEVELS % room, data)
	return 0


## Plays `games` games with one bot profile under `budget` (0 = can't lose).
func _measure(lvl: LevelData, prof: String, games: int, budget: int, salt: int = 0) -> Dictionary:
	var keep := lvl.budget
	lvl.budget = budget
	var slips: Array[int] = []
	var after: Array[int] = []
	var fracs: Array[float] = []
	var wins := 0
	var total := 0.0
	for g in games:
		var r := Bot.play(lvl, prof, hash([lvl.id, prof, budget, g, salt]))
		wins += 1 if r["won"] else 0
		# A run that got stuck never won at any slip limit.
		slips.append(r["slips"] if r["won"] or budget > 0 else STUCK)
		total += r["slips"]
		after.append(r["after_known"])
		fracs.append(1.0 - float(r["after_known"]) / maxf(r["moves"], 1.0))
	lvl.budget = keep
	slips.sort()
	after.sort()
	fracs.sort()
	return {"win": float(wins) / games, "slips": slips, "slips_mean": total / games, "after_med": after[games / 2],
		"aha_frac": fracs[games / 2]}


## The smallest slip count s with at least `q` of runs at or below it.
static func _quantile(sorted_slips: Array[int], q: float) -> int:
	var need := ceili(q * sorted_slips.size())
	return sorted_slips[clampi(need - 1, 0, sorted_slips.size() - 1)]


## The slip count that lets `q` of runs win, or the most any winning run needed when too many got stuck for that (no
## limit can reach the floor then: the settle report shows the miss).
static func _floor_slips(sorted_slips: Array[int], q: float) -> int:
	var s := _quantile(sorted_slips, q)
	if s < STUCK:
		return s
	var won := sorted_slips.filter(func(x: int) -> bool: return x < STUCK)
	return 0 if won.is_empty() else won.back()


static func _gold(sorted_slips: Array[int], budget: int) -> int:
	var best := -1
	var near := 0
	var near_gap := 9.0
	for k in budget:
		var frac := float(sorted_slips.filter(func(s: int) -> bool: return s <= k).size()) / sorted_slips.size()
		if frac >= 0.2 and frac <= 0.5:
			best = k
		if absf(frac - 0.35) < near_gap:
			near = k
			near_gap = absf(frac - 0.35)
	return best if best >= 0 else near


# --- shared -------------------------------------------------------------------------------------------------------

## Writes data/levels/index.json: the tutorial, every room file in room order, then the test boards.
static func write_index() -> void:
	var files: Array = ["res://data/levels/tutorial.json"]
	for path in _room_files():
		files.append(path)
	files.append("res://data/levels/test.json")
	JsonOut.write(INDEX, {"files": files})


static func _room_files() -> Array[String]:
	var out: Array[String] = []
	var nums: Array[int] = []
	for f in DirAccess.get_files_at("res://data/levels"):
		if f.begins_with("room") and f.ends_with(".json"):
			nums.append(int(f.trim_prefix("room").trim_suffix(".json")))
	nums.sort()
	for r in nums:
		out.append(LEVELS % r)
	return out


func _jar_words(lvl: LevelData) -> Array:
	var out: Array = []
	for jar in lvl.jars:
		out.append(Array(jar).map(func(c: int) -> String: return lvl.word(c)))
	return out


static func _jar_note(d: Dictionary) -> String:
	var bits: Array[String] = []
	if d.has("frost"):
		bits.append("frost")
	if d.has("labelled"):
		bits.append("label")
	if d.has("corked"):
		bits.append("cork")
	return "+".join(bits) if not bits.is_empty() else "-"


func _reuse_report() -> Array[String]:
	var hist := {}
	var by_tier := {}
	for idx in bank.categories.size():
		var u := ledger.uses(idx)
		hist[u] = int(hist.get(u, 0)) + 1
		var t := int(bank.categories[idx]["tier"])
		var row: Array = by_tier.get(t, [0, 0, 0])
		row[0] += 1
		row[1] += u
		row[2] += ledger.max_uses(idx)
		by_tier[t] = row
	var out: Array[String] = ["", "## Reuse", "", "| uses | categories |", "|---|---|"]
	var keys := hist.keys()
	keys.sort()
	for k in keys:
		out.append("| %d | %d |" % [k, hist[k]])
	out.append_array(["", "| tier | categories | slots used | slots possible |", "|---|---|---|---|"])
	var tiers := by_tier.keys()
	tiers.sort()
	for t in tiers:
		out.append("| %d | %d | %d | %d |" % [t, by_tier[t][0], by_tier[t][1], by_tier[t][2]])
	return out


func _tier_counts() -> String:
	var c := {}
	for cat in bank.categories:
		c[int(cat["tier"])] = int(c.get(int(cat["tier"]), 0)) + 1
	var parts: Array[String] = []
	var ks := c.keys()
	ks.sort()
	for k in ks:
		parts.append("tier %d: %d" % [k, c[k]])
	return ", ".join(parts)


static func _ranges(v: String) -> Array[int]:
	var out: Array[int] = []
	for part in v.split(",", false):
		if part.contains("-"):
			for x in range(int(part.get_slice("-", 0)), int(part.get_slice("-", 1)) + 1):
				out.append(x)
		else:
			out.append(int(part))
	return out


static func _pct(v: Variant) -> String:
	return "%d%%" % roundi(float(v) * 100.0)


static func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text + "\n")


func _reject(why: String) -> void:
	rejects[why] = int(rejects.get(why, 0)) + 1


## One category per domain in a level. Lateral, abstract and wordplay categories cross every domain, so they're keyed
## by their pattern instead ("Things with", "Words before"...): two of them may share a level only if patterns differ.
func _domain_key(idx: int) -> String:
	var c: Dictionary = bank.categories[idx]
	if not PATTERN_DOMAINS.has(c["domain"]):
		return c["domain"]
	var parts := (c["label"] as String).split(" ")
	return "pattern:" + " ".join(parts.slice(0, mini(2, parts.size()))).to_lower()


## True if category `i` shares a word with any of `cats`.
func _crosses(i: int, cats: Array[int]) -> bool:
	for w in bank.categories[i]["words"]:
		for h in bank.homes(w):
			if h != i and cats.has(h):
				return true
	return false


## The meaningful words of a category's label (its key plus content words), lower case.
func _label_tokens(idx: int) -> PackedStringArray:
	const STOP := ["things", "words", "before", "after", "with", "that", "you", "can", "the", "of", "in", "a", "on",
		"at", "and", "kinds", "parts", "shades", "ways", "across", "are", "hidden", "sound", "like"]
	var out := PackedStringArray()
	for t in ([(bank.categories[idx]["key"] as String).to_lower()] + Array((bank.categories[idx]["label"] as String).to_lower().split(" ", false))):
		if t.length() < 3 or STOP.has(t):
			continue
		# A plural's stem clashes too: "Keyboard" reads as naming "Things with keys".
		var stem: String = t.trim_suffix("es") if t.ends_with("ches") or t.ends_with("shes") else t.trim_suffix("s")
		for x in [t, stem]:
			if x.length() >= 3 and not out.has(x):
				out.append(x)
	return out
