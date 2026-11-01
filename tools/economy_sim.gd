## Plays the coin economy over every shipped room level (in order, 10 levels a day) for three players, using each
## level's baked bot numbers for how often a player would want help:
##   free: never pays, never watches ads; takes a Hint when it wants one and can afford it.
##   ads: the same, but watches ads when short (a free hint, shop coins, doubled wins), within the caps.
##   once: like free, but buys the smallest pack the first time it can't afford a Hint.
## Gates (docs/plan-m3.md section 3): a free player can afford a Hint at the start of at least 1 level in 3; the ad
## player is never short of a Hint for more than 3 levels in a row; the free player's median balance stays between 100
## and 2,000 (no runaway inflation). Nobody needs coins to win: that is the level design, checked elsewhere.
## Writes reports/economy.md.
## Run: godot --headless --path . -s res://tools/economy_sim.gd
extends SceneTree

const LEVELS := preload("res://src/core/levels.gd")
const PER_DAY := 10


func _init() -> void:
	var cat := Catalog.from_files(LEVELS.files())
	var order := cat.play_order()
	var players := {"free": _player(), "ads": _player(), "once": _player()}
	var rows: Array[String] = []
	var worst_free_share := 1.0
	for i in order.size():
		var id := order[i]
		var e := cat.entry(id)
		var d: Dictionary = e["data"]
		var meta: Dictionary = d.get("meta", {})
		var groups := (d["groups"] as Array).size()
		var kind := str(e["kind"])
		# Help wanted: about one Hint per two slips the average player makes here, more on tricky and hard levels.
		var want := roundi(float(meta.get("avg_slips", 0.5)) * 0.5 + (0.5 if kind in ["tricky", "hard"] else 0.0))
		var day := i / PER_DAY
		for name in players:
			var p: Dictionary = players[name]
			if p["day"] != day:
				_new_day(p, day)
			p["start_afford"].append(Economy.can_afford(p["save"], "hint"))
			for k in want:
				p["wanted"] += 1
				p["room_wanted"] += 1
				var got := false
				if Economy.spend(p["save"], "hint") != "":
					got = true
				elif name == "ads" and p["ads"] < AdPolicy.DAILY_CAP and p["free_hint"] < 3:
					p["ads"] += 1
					p["free_hint"] += 1
					got = true
				elif name == "once" and not p["bought"]:
					p["bought"] = true
					Economy.grant(p["save"], {"coins": 500})
					got = Economy.spend(p["save"], "hint") != ""
				if got:
					p["used"] += 1
					p["room_used"] += 1
			var short := not Economy.can_afford(p["save"], "hint")
			p["short_run"] = p["short_run"] + 1 if short else 0
			p["worst_run"] = maxi(p["worst_run"], p["short_run"])
			var coins := Economy.win_coins(groups, kind, int(e["room"]))
			if name == "ads" and p["ads"] < AdPolicy.DAILY_CAP:
				p["ads"] += 1
				coins *= 2
			Economy.grant(p["save"], {"coins": coins})
			Economy.add_xp(p["save"], Economy.win_xp(groups, kind))
			if int(e["number"]) == cat.room_ids(int(e["room"])).size():
				Economy.grant(p["save"], {"coins": Economy.ROOM_COINS})
			if name == "ads":
				while p["ads"] < AdPolicy.DAILY_CAP and p["shop"] < 5 and int(p["save"]["coins"]) < 200:
					p["ads"] += 1
					p["shop"] += 1
					Economy.grant(p["save"], {"coins": Economy.AD_COINS})
			p["balances"].append(int(p["save"]["coins"]))
		if (i + 1) % 30 == 0 or i == order.size() - 1:
			rows.append("| %d | %s | %d | %d | %d | %s | %s |" % [i + 1, cat.room_name(int(e["room"])), players["free"]["save"]["coins"],
				players["ads"]["save"]["coins"], players["once"]["save"]["coins"], _room_share(players["free"]), _room_share(players["ads"])])
			worst_free_share = minf(worst_free_share, float(players["free"]["room_used"]) / maxi(players["free"]["room_wanted"], 1))
			for name in players:
				players[name]["room_wanted"] = 0
				players[name]["room_used"] = 0
	var md: Array[String] = ["# Economy simulation", "",
		"%d levels, %d a day. Prices: Hint %d, Complete %d, Continue %d. Ads: %d a day at most." % [order.size(), PER_DAY,
			Economy.PRICES["hint"], Economy.PRICES["complete"], Economy.PRICES["continue"], AdPolicy.DAILY_CAP], "",
		"| after level | room | free player coins | ad player coins | one-purchase coins | free: Hints got | ads: Hints got |",
		"|---|---|---|---|---|---|---|"]
	md.append_array(rows)
	md.append("")
	var gates: Array[String] = []
	var free: Dictionary = players["free"]
	var afford_share := float(free["start_afford"].count(true)) / maxf(free["start_afford"].size(), 1)
	var sorted: Array = free["balances"].duplicate()
	sorted.sort()
	var median: int = sorted[sorted.size() / 2] if not sorted.is_empty() else 0
	gates.append("%s free player can afford a Hint at the start of %d%% of levels (gate: 33%% or more)" % [
		"PASS" if afford_share >= 0.33 else "FAIL", roundi(afford_share * 100)])
	gates.append("%s ad player is never short of a Hint for more than 3 levels in a row (worst run %d)" % [
		"PASS" if players["ads"]["worst_run"] <= 3 else "FAIL", players["ads"]["worst_run"]])
	gates.append("%s free player's median balance is %d (gate: 100 to 2,000)" % [
		"PASS" if median >= 100 and median <= 2000 else "FAIL", median])
	for name in players:
		var p: Dictionary = players[name]
		md.append("- %s: wanted %d Hints, got %d (%d%%); player level %d at the end." % [name, p["wanted"], p["used"],
			roundi(100.0 * p["used"] / maxi(p["wanted"], 1)), Economy.level_for_xp(int(p["save"]["xp"]))["level"]])
	md.append_array(["", "## Gates", ""])
	md.append_array(gates.map(func(g: String) -> String: return "- " + g))
	DirAccess.make_dir_recursive_absolute("res://reports")
	var f := FileAccess.open("res://reports/economy.md", FileAccess.WRITE)
	f.store_string("\n".join(md) + "\n")
	for g in gates:
		print(g)
	quit(0 if gates.all(func(g: String) -> bool: return g.begins_with("PASS")) else 1)


func _player() -> Dictionary:
	var s := SaveSchema.defaults()
	s["coins"] = Economy.STARTER_COINS
	s["inventory"]["hint"] = 3
	s["inventory"]["complete"] = 1
	return {"save": s, "day": -1, "ads": 0, "free_hint": 0, "shop": 0, "wanted": 0, "used": 0, "bought": false,
		"short_run": 0, "worst_run": 0, "balances": [], "start_afford": [], "streak": 0, "room_wanted": 0, "room_used": 0}


func _room_share(p: Dictionary) -> String:
	return "%d%%" % roundi(100.0 * p["room_used"] / maxi(p["room_wanted"], 1))


## A new day: the daily gift by streak day (the simulated player plays every day), and the ad caps reset.
func _new_day(p: Dictionary, day: int) -> void:
	p["day"] = day
	p["ads"] = 0
	p["free_hint"] = 0
	p["shop"] = 0
	p["streak"] += 1
	Economy.grant(p["save"], Economy.gift_for_day(p["streak"]))
