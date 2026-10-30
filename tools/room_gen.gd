## Generates a room's levels from the category bank and the room spec, then proves and measures each one.
## Per level: pick categories (the spec's tier mix, one per domain, reuse caps, no phantom groups, herrings only where
## asked), pick 4 words each, require a unique cover, then try seeded deals and keep the one whose bot-measured
## difficulty is nearest the room's sawtooth target (the aha after >= 40% of moves from L3, little post-aha
## busywork). Budgets come from the novice bot's p90 (+1), gold thresholds from the average bot (25-45% earn it).
## Writes data/levels/roomN.json and reports/roomN_gen.md (+ .csv).
## Run: godot --headless --path . -s res://tools/room_gen.gd -- --room=1 [--seed=1 --cands=10 --deals=3 --n=30 --final=200]
extends SceneTree

const SPEC := "res://data/rooms/room%d_spec.json"
const BANK := "res://data/bank/categories.txt"
const PAIRS := "res://data/bank/pairs.txt"
const TUTORIAL := "res://data/levels/tutorial.json"
## Reuse caps: a category at most twice, this many levels apart; a word not again within WORD_GAP levels. When a
## level can't be built, the search widens (more candidates), then the gaps relax (logged in the report).
const REUSE_GAP := 25
const WORD_GAP := 15
const RELAXED_GAPS := [Vector2i(25, 15), Vector2i(25, 15), Vector2i(15, 8)]
const MAX_WORD := 9

var bank: Bank
var rng := RandomNumberGenerator.new()
## category index -> Array of level numbers that used it (the tutorial counts as level 0)
var used := {}
## lower-case word -> last level number that used it
var word_used := {}
var room := 1
var cands := 10
var deals := 3
var n := 30
var n_final := 200
## Why candidate picks failed, per level (printed when a level can't be built).
var rejects := {}
var reuse_gap := REUSE_GAP
var word_gap := WORD_GAP


func _init() -> void:
	var base_seed := 1
	for a in OS.get_cmdline_user_args():
		var v := a.get_slice("=", 1)
		match a.get_slice("=", 0):
			"--room": room = int(v)
			"--seed": base_seed = int(v)
			"--cands": cands = int(v)
			"--deals": deals = int(v)
			"--n": n = int(v)
			"--final": n_final = int(v)
	rng.seed = hash([room, base_seed])
	bank = Bank.load_csv(BANK)
	bank.load_pairs(PAIRS)
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPEC % room))
	_mark_tutorial()
	var out: Array = []
	var md: Array[String] = ["# Room %d generation" % room, "",
		"Bank: %d categories. Seed %d, %d candidates x %d deals x %d games each; finals %d games per profile." % [
			bank.categories.size(), base_seed, cands, deals, n, n_final], "",
		"Target = the average bot's mean slips on the sawtooth (rest x0.6, tricky x1.35, hard x1.6). Win rates are with the level's budget.", "",
		"| L | kind | groups (tier) | herrings | budget | gold | target | avg slips | avg win | novice win | prober win | after-aha | aha at |",
		"|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
	var csv: Array[String] = ["level,kind,groups,herrings,budget,gold,target,avg_slips,avg_win,novice_win,prober_win,after_med,aha_frac"]
	var t0 := Time.get_ticks_msec()
	for i in (spec["levels"] as Array).size():
		var number := i + 1
		var ls: Dictionary = spec["levels"][i]
		var target := _target(number, str(ls["kind"]))
		var best := {}
		rejects.clear()
		var relax := 0
		while best.is_empty() and relax < RELAXED_GAPS.size():
			reuse_gap = RELAXED_GAPS[relax].x
			word_gap = RELAXED_GAPS[relax].y
			for c in cands * (1 if relax == 0 else 3):
				var pick := _pick(number, ls)
				if pick.is_empty():
					continue
				var d := _level_dict(number, ls, pick)
				var lvl := LevelData.from_dict(d)
				if ExactCover.count(lvl) != 1:
					_reject("cover")
					continue
				for k in deals:
					if not _deal(lvl, hash([room, number, c, k, base_seed, relax])):
						continue
					var m := _measure(lvl, "average", n, 0)
					var score := absf(m["slips_mean"] - target)
					if number >= 3 and m["aha_frac"] < 0.4:
						score += 1.5
					score += maxf(0.0, m["after_med"] - 8.0) * 0.25
					if best.is_empty() or score < best["score"]:
						best = {"score": score, "d": d.duplicate(true), "jars": lvl.jars.duplicate(), "pick": pick, "m": m}
			relax += 1
		if relax > 1:
			md.append("> Level %d needed a wider search (step %d of %d): %s" % [number, relax, RELAXED_GAPS.size(), rejects])
		reuse_gap = REUSE_GAP
		word_gap = WORD_GAP
		if best.is_empty():
			push_error("room_gen: no valid level %d: %s" % [number, rejects])
			quit(1)
			return
		var lvl := LevelData.from_dict(best["d"])
		lvl.jars = best["jars"]
		var d: Dictionary = best["d"]
		d["jars"] = _jar_words(lvl)
		d.erase("empty")
		_commit(number, best["pick"])
		# Budget and gold from the bots' slip distributions with no budget.
		var nov := _measure(lvl, "novice", n_final, 0)
		var avg := _measure(lvl, "average", n_final, 0)
		var budget := 0
		var gold := -1
		if ls.get("budget", false):
			var tight: bool = ls["kind"] in ["tricky", "hard"]
			budget = maxi(2, int(nov["p75" if tight else "p90"]) + 1)
			gold = _gold(avg["slips"], budget)
		d["budget"] = budget
		d["gold"] = gold
		lvl.budget = budget
		var avg_w := _measure(lvl, "average", n_final / 2, budget)
		var nov_w := _measure(lvl, "novice", n_final / 2, budget)
		var pro_w := _measure(lvl, "prober", n_final / 2, budget)
		d["meta"] = {"target": snappedf(target, 0.01), "avg_slips": snappedf(avg["slips_mean"], 0.01),
			"avg_win": snappedf(avg_w["win"], 0.01), "novice_win": snappedf(nov_w["win"], 0.01),
			"after_med": avg["after_med"], "aha_frac": snappedf(avg["aha_frac"], 0.01)}
		out.append(d)
		var names: Array = []
		for g: Dictionary in d["groups"]:
			names.append("%s (%d)" % [g["label"], g["tier"]])
		md.append("| %d | %s | %s | %d | %s | %s | %.2f | %.2f | %s | %s | %s | %d | %d%% |" % [number, ls["kind"], ", ".join(names),
			(d["also"] as Dictionary).size(), str(budget) if budget > 0 else "-", str(gold) if gold >= 0 else "-", target,
			avg["slips_mean"], _pct(avg_w["win"]), _pct(nov_w["win"]), _pct(pro_w["win"]), avg["after_med"], roundi(avg["aha_frac"] * 100)])
		csv.append("%d,%s,%d,%d,%d,%d,%.2f,%.2f,%.3f,%.3f,%.3f,%d,%.2f" % [number, ls["kind"], d["groups"].size(),
			(d["also"] as Dictionary).size(), budget, gold, target, avg["slips_mean"], avg_w["win"], nov_w["win"], pro_w["win"],
			avg["after_med"], avg["aha_frac"]])
		print(md.back())
	var file := {"version": 2, "track": "room", "room": room, "name": spec.get("name", ""),
		"gen": {"seed": base_seed, "bank": FileAccess.get_md5(BANK).left(12)}, "levels": out}
	JsonOut.write("res://data/levels/room%d.json" % room, file)
	md.append("")
	md.append("Generated in %.0f s." % ((Time.get_ticks_msec() - t0) / 1000.0))
	DirAccess.make_dir_recursive_absolute("res://reports")
	_write("res://reports/room%d_gen.md" % room, "\n".join(md))
	_write("res://reports/room%d_gen.csv" % room, "\n".join(csv))
	print(md.back())
	quit()


## The sawtooth: the average bot's mean slips should rise through the room, dip on rest levels and spike on tricky
## and hard ones. L1-2 are near-perfect warm-ups.
func _target(number: int, kind: String) -> float:
	if number <= 2:
		return 0.1
	var base := 0.25 + 0.075 * (number - 1)
	match kind:
		"rest":
			return base * 0.6
		"tricky":
			return base * 1.35
		"hard":
			return base * 1.6
	return base


func _mark_tutorial() -> void:
	var tut: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TUTORIAL))
	for l: Dictionary in tut["levels"]:
		for g: Dictionary in l["groups"]:
			var idx := bank.find_label(str(g["label"]))
			if idx >= 0:
				used[idx] = [0]
			for w in g["words"]:
				word_used[str(w).to_lower()] = 0


func _allowed(idx: int, number: int) -> bool:
	var uses: Array = used.get(idx, [])
	return uses.size() < 2 and (uses.is_empty() or number - int(uses.back()) >= reuse_gap)


## {cats: Array[int], words: Array[PackedStringArray], also: {word: [group]}} or {} when this try fails.
func _pick(number: int, ls: Dictionary) -> Dictionary:
	var cats: Array[int] = []
	var domains := {}
	var tiers: Array = (ls["tiers"] as Array).map(func(t: Variant) -> int: return int(t))  # JSON numbers are floats
	tiers.shuffle()
	# A level that needs a herring starts from a real crossing: two categories sharing a word.
	if int(ls.get("herrings", 0)) > 0:
		var pair := _crossing_pair(number, tiers)
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
			if int(c["tier"]) == int(t) and not cats.has(i) and not domains.has(_domain_key(i)) and _allowed(i, number) \
					and cats.all(func(k: int) -> bool: return bank.compatible(i, k)):
				pool.append(i)
				if not used.has(i):
					pool.append(i)  # never-used categories are twice as likely
				if int(ls.get("herrings", 0)) > 1 and _crosses(i, cats):
					for k in 6:
						pool.append(i)  # a second herring needs another crossing
		if pool.is_empty():
			_reject("no category for tier")
			return {}
		var pick: int = pool[rng.randi_range(0, pool.size() - 1)]
		cats.append(pick)
		domains[_domain_key(pick)] = true
	# Words that belong to two picked categories are herrings; keep exactly as many as the spec asks.
	var crossings: Array = []
	for a in cats.size():
		for w in bank.categories[cats[a]]["words"]:
			for h in bank.homes(w):
				var b := cats.find(h)
				if b >= 0 and b != a:
					crossings.append([w, a, b])
	var want: int = int(ls.get("herrings", 0))
	crossings.shuffle()
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
		var chosen := PackedStringArray()
		var fixed: Array = herrings.filter(func(x: Array) -> bool: return x[1] == a)
		for x: Array in fixed:
			chosen.append(x[0])
		var pool := PackedStringArray()
		for w in bank.categories[cats[a]]["words"]:
			var lw := (w as String).to_lower()
			if herring_words.has(lw) or w.length() > MAX_WORD or w.length() < 3:
				continue
			if number - int(word_used.get(lw, -999)) < word_gap:
				continue
			if Array(bank.homes(w)).any(func(h: int) -> bool: return h != cats[a] and cats.has(h)):
				continue
			pool.append(w)
		var arr := Array(pool)
		arr.shuffle()
		for w in arr:
			if chosen.size() >= 4:
				break
			chosen.append(w)
		if chosen.size() < 4:
			_reject("too few free words")
			return {}
		words.append(chosen)
	# Phantom groups: no category outside the level (with its children's words) may hold 3 or more of its words.
	# A parent of a picked category may hold none outside that category's own group (Fruit next to Citrus fruit).
	for i in bank.categories.size():
		if cats.has(i):
			continue
		var family := bank.family_words(i)
		var own := -1
		for a in cats.size():
			if (bank.children.get(i, PackedInt32Array()) as PackedInt32Array).has(cats[a]):
				own = a
		var hits := 0
		for a in words.size():
			if a == own:
				continue
			for w in words[a]:
				if family.has(w.to_lower()):
					hits += 1
		if hits >= (1 if own >= 0 else 3):
			_reject("phantom")
			return {}
	var also := {}
	for x: Array in herrings:
		also[x[0]] = [x[2]]
	return {"cats": cats, "words": words, "also": also}


func _level_dict(number: int, ls: Dictionary, pick: Dictionary) -> Dictionary:
	var groups: Array = []
	for a in (pick["cats"] as Array).size():
		var c: Dictionary = bank.categories[pick["cats"][a]]
		groups.append({"label": c["label"], "key": c["key"], "tier": c["tier"], "words": Array(pick["words"][a])})
	return {
		"id": "r%d-%02d" % [room, number], "kind": ls["kind"], "introduces": ls.get("introduces", []),
		"budget": 0, "groups": groups, "also": pick["also"], "empty": 2,
	}


func _deal(lvl: LevelData, seed: int) -> bool:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var jars := Dealer.deal(lvl.group_count(), 2, r)
	if jars.is_empty():
		return false
	lvl.jars = jars
	return Solver.solve(BoardState.from_level(lvl), 200000)["solved"]


## Plays `games` games with one bot profile under `budget` (0 = can't lose).
func _measure(lvl: LevelData, prof: String, games: int, budget: int) -> Dictionary:
	var keep := lvl.budget
	lvl.budget = budget
	var slips: Array[int] = []
	var after: Array[int] = []
	var fracs: Array[float] = []
	var wins := 0
	var total := 0.0
	for g in games:
		var r := Bot.play(lvl, prof, hash([lvl.id, prof, budget, g]))
		wins += 1 if r["won"] else 0
		slips.append(r["slips"])
		total += r["slips"]
		after.append(r["after_known"])
		fracs.append(1.0 - float(r["after_known"]) / maxf(r["moves"], 1.0))
	lvl.budget = keep
	slips.sort()
	after.sort()
	fracs.sort()
	return {"win": float(wins) / games, "slips": slips, "slips_mean": total / games, "after_med": after[games / 2],
		"aha_frac": fracs[games / 2], "p75": slips[int(games * 0.75)], "p90": slips[mini(games - 1, int(games * 0.9))]}


## The largest k (below the budget) that 25-45% of average-bot runs finish within; else the k nearest 35%.
func _gold(sorted_slips: Array[int], budget: int) -> int:
	var best := 0
	var best_gap := 9.0
	for k in budget:
		var frac := float(sorted_slips.filter(func(s: int) -> bool: return s <= k).size()) / sorted_slips.size()
		if frac >= 0.25 and frac <= 0.45:
			best = k
			best_gap = 0.0
		elif best_gap > 0.0 and absf(frac - 0.35) < best_gap:
			best = k
			best_gap = absf(frac - 0.35)
	return best


func _commit(number: int, pick: Dictionary) -> void:
	for idx in pick["cats"]:
		var uses: Array = used.get(idx, [])
		uses.append(number)
		used[idx] = uses
	for ws in pick["words"]:
		for w in ws:
			word_used[(w as String).to_lower()] = number


func _jar_words(lvl: LevelData) -> Array:
	var out: Array = []
	for jar in lvl.jars:
		out.append(Array(jar).map(func(c: int) -> String: return lvl.word(c)))
	return out


static func _pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


static func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text + "\n")


## Two allowed categories from different domains whose tiers fit the spec and that share a word, or [].
func _crossing_pair(number: int, tiers: Array) -> Array:
	var pairs: Array = []
	for w in bank.by_word:
		var hs: PackedInt32Array = bank.by_word[w]
		if hs.size() < 2 or (w as String).length() > MAX_WORD:
			continue
		for x in hs.size():
			for y in hs.size():
				var a := hs[x]
				var b := hs[y]
				var ca: Dictionary = bank.categories[a]
				var cb: Dictionary = bank.categories[b]
				if a == b or _domain_key(a) == _domain_key(b) or not _allowed(a, number) or not _allowed(b, number) \
						or not bank.compatible(a, b):
					continue
				var left := tiers.duplicate()
				if not left.has(int(ca["tier"])):
					continue
				left.erase(int(ca["tier"]))
				if left.has(int(cb["tier"])):
					pairs.append([a, b])
	return [] if pairs.is_empty() else pairs[rng.randi_range(0, pairs.size() - 1)]


func _reject(why: String) -> void:
	rejects[why] = int(rejects.get(why, 0)) + 1


## One category per domain in a level. Lateral categories cross every domain, so they're keyed by their pattern
## instead ("Things with", "Words before"...): two laterals may share a level only if the patterns differ.
func _domain_key(idx: int) -> String:
	var c: Dictionary = bank.categories[idx]
	if c["domain"] != "lateral":
		return c["domain"]
	var parts := (c["label"] as String).split(" ")
	return "lateral:" + " ".join(parts.slice(0, mini(2, parts.size())))


## True if category `i` shares a word with any of `cats`.
func _crosses(i: int, cats: Array[int]) -> bool:
	for w in bank.categories[i]["words"]:
		for h in bank.homes(w):
			if h != i and cats.has(h):
				return true
	return false
