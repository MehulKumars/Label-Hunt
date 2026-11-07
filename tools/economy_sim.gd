## Plays the coin economy over every shipped room level (in order, 10 levels a day) for three players, using each
## level's baked bot numbers for how often a player would want help:
##   free: never pays, never watches ads; takes a Hint when it wants one and can afford it.
##   ads: the same, but watches ads when short (a free hint; shop diamonds while coins are low), within the caps, pays
##   Hints in diamonds when coins run out, and doubles a win's coins only while coins are still worth having (under
##   AD_WANT: people stop watching for coins they can't use).
##   once: like free, but buys the smallest diamond pack the first time it can't afford a Hint, then pays in diamonds.
## Win coins are per star (Economy.per_star) times the stars the average bot's wins earn (reports/stars.csv).
## Gates (docs/plan-m3.md section 3): a free player can afford a Hint at the start of at least 1 level in 3; the ad
## player is never short of a Hint for more than 3 levels in a row; the free player's median balance stays between 100
## and 2,000 (no runaway inflation); the ad player's coins keep their value late; the free player's worst room gets
## at least 68% of the Hints it wants; diamonds from ads stay under 25 a day and get spent. Also reports ads a day, the
## income: it is limited by what coins can buy. Nobody needs coins to win: that is the level design, checked elsewhere.
## Writes reports/economy.md.
## Run: godot --headless --path . -s res://tools/economy_sim.gd
extends SceneTree

const LEVELS := preload("res://src/core/levels.gd")
const PER_DAY := 10
## Above this balance (30 Hints' worth) the ad player stops watching optional "x2 coins" ads (v2 economy review: with
## every win doubled regardless, the sim hoarded 8,000+ coins no real player would keep watching for).
const AD_WANT := 1500


func _init() -> void:
	var cat := Catalog.from_files(LEVELS.files())
	var order := cat.play_order()
	var players := {"free": _player(), "ads": _player(), "once": _player()}
	var rows: Array[String] = []
	var worst_free_share := 1.0
	var stars := _star_rates()
	var gems_at_300 := 0
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
				elif name == "ads" and p["ads"] < AdPolicy.DAILY_CAP and p["free_hint"] < int(AdPolicy.PLACEMENT_CAPS["free_hint"]):
					p["ads"] += 1
					p["ads_total"] += 1
					p["free_hint"] += 1
					got = true
				elif name != "free" and Economy.pay_diamonds(p["save"], int(Economy.DIAMOND_PRICES["hint"])):
					got = true
				elif name == "once" and not p["bought"]:
					# The smallest diamond pack, the first time a Hint is out of reach; then Hints in diamonds.
					p["bought"] = true
					Economy.grant(p["save"], {"diamonds": int(Economy.PACKS[0]["diamonds"])})
					got = Economy.pay_diamonds(p["save"], int(Economy.DIAMOND_PRICES["hint"]))
				if got:
					p["used"] += 1
					p["room_used"] += 1
			var short: bool = not Economy.can_afford(p["save"], "hint") and not (name != "free" and Economy.can_pay_diamonds(p["save"], "hint"))
			p["short_run"] = p["short_run"] + 1 if short else 0
			p["worst_run"] = maxi(p["worst_run"], p["short_run"])
			# Coins per star times the stars the average bot's wins earn here (2 stars if there is no star report).
			var coins := roundi(Economy.per_star(groups, kind, int(e["room"])) * float(stars.get(id, 2.0)))
			if name == "ads" and p["ads"] < AdPolicy.DAILY_CAP and p["dbl"] < int(AdPolicy.PLACEMENT_CAPS.get("win_double", 99)) \
					and int(p["save"]["coins"]) < AD_WANT:
				p["ads"] += 1
				p["ads_total"] += 1
				p["dbl"] += 1
				coins *= 2
			Economy.grant(p["save"], {"coins": coins})
			Economy.add_xp(p["save"], Economy.win_xp(groups, kind))
			if int(e["number"]) == cat.room_ids(int(e["room"])).size():
				Economy.grant(p["save"], {"coins": Economy.ROOM_COINS})
			if name == "ads":
				# Banks diamonds from the shop ad while coins are low and the diamonds would be spent.
				var gem_cap := int(AdPolicy.PLACEMENT_CAPS["shop_diamonds"])
				while p["ads"] < AdPolicy.DAILY_CAP and p["shop"] < gem_cap and int(p["save"]["coins"]) < 200 and Economy.diamonds(p["save"]) < 100:
					p["ads"] += 1
					p["ads_total"] += 1
					p["shop"] += 1
					Economy.grant(p["save"], {"diamonds": Economy.AD_DIAMONDS})
					p["gems_day"] += Economy.AD_DIAMONDS
					p["gems_day_max"] = maxi(p["gems_day_max"], p["gems_day"])
				if i == 299:
					gems_at_300 = Economy.diamonds(p["save"])
			p["balances"].append(int(p["save"]["coins"]))
		if (i + 1) % 30 == 0 or i == order.size() - 1:
			rows.append("| %d | %s | %d | %d (%d diamonds) | %d (%d diamonds) | %s | %s |" % [i + 1, cat.room_name(int(e["room"])),
				players["free"]["save"]["coins"], players["ads"]["save"]["coins"], Economy.diamonds(players["ads"]["save"]),
				players["once"]["save"]["coins"], Economy.diamonds(players["once"]["save"]), _room_share(players["free"]),
				_room_share(players["ads"])])
			worst_free_share = minf(worst_free_share, float(players["free"]["room_used"]) / maxi(players["free"]["room_wanted"], 1))
			for name in players:
				players[name]["room_wanted"] = 0
				players[name]["room_used"] = 0
	var md: Array[String] = ["# Economy simulation", "",
		"%d levels, %d a day. Prices: Hint %d, Complete %d, Continue %d coins (or %d, %d, %d diamonds). Ads: %d a day at most. " % [
			order.size(), PER_DAY, Economy.PRICES["hint"], Economy.PRICES["complete"], Economy.PRICES["continue"],
			Economy.DIAMOND_PRICES["hint"], Economy.DIAMOND_PRICES["complete"], Economy.DIAMOND_PRICES["continue"], AdPolicy.DAILY_CAP] +
			"Win coins: per star, a share of win_coins by room %s, times the stars the average bot earns (reports/stars.csv%s)." % [
			str(Economy.STAR_COIN_RATES), "" if not stars.is_empty() else " missing: 2 stars assumed"], "",
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
	# Coins must stay worth earning for ad watchers too: a hoard of 100 Hints' worth means rewards stop mattering, and
	# rewarded ads (the income) stop being watched.
	var late: Array = (players["ads"]["balances"] as Array).slice(300)
	var late_max: int = late.max() if not late.is_empty() else 0
	gates.append("%s ad player's coins keep their value: at most %d after level 300 (gate: 5,000 or less)" % [
		"PASS" if late_max <= 5000 else "FAIL", late_max])
	# Stars must not starve free players late: no room worse than the coin-only economy's worst (68%).
	gates.append("%s free player gets %d%% of the Hints it wants in its worst room (gate: 68%% or more)" % [
		"PASS" if worst_free_share >= 0.675 else "FAIL", roundi(100 * worst_free_share)])
	var pack_hints := int(Economy.PACKS[0]["diamonds"]) / int(Economy.DIAMOND_PRICES["hint"])
	gates.append("%s the $%s pack buys %d Hints (gate: 10 or more)" % ["PASS" if pack_hints >= 10 else "FAIL",
		Economy.PACKS[0]["usd"], pack_hints])
	var gems_day: int = players["ads"]["gems_day_max"]
	gates.append("%s ad player banks at most %d diamonds a day from ads (gate: 25 or less)" % [
		"PASS" if gems_day <= 25 else "FAIL", gems_day])
	gates.append("%s ad player's diamonds get spent: %d held at level 300 (gate: under 500)" % [
		"PASS" if gems_at_300 < 500 else "FAIL", gems_at_300])
	for name in players:
		var p: Dictionary = players[name]
		md.append("- %s: wanted %d Hints, got %d (%d%%); player level %d at the end." % [name, p["wanted"], p["used"],
			roundi(100.0 * p["used"] / maxi(p["wanted"], 1)), Economy.level_for_xp(int(p["save"]["xp"]))["level"]])
	md.append("- ad player watched %d ads in %d days (%.1f a day)." % [players["ads"]["ads_total"], players["ads"]["day"] + 1,
		float(players["ads"]["ads_total"]) / (players["ads"]["day"] + 1)])
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
	return {"save": s, "day": -1, "ads": 0, "ads_total": 0, "dbl": 0, "free_hint": 0, "shop": 0, "wanted": 0, "used": 0, "bought": false,
		"short_run": 0, "worst_run": 0, "balances": [], "start_afford": [], "streak": 0, "room_wanted": 0, "room_used": 0,
		"gems_day": 0, "gems_day_max": 0}


func _room_share(p: Dictionary) -> String:
	return "%d%%" % roundi(100.0 * p["room_used"] / maxi(p["room_wanted"], 1))


## A new day: the daily gift by streak day (the simulated player plays every day), and the ad caps reset.
func _new_day(p: Dictionary, day: int) -> void:
	p["day"] = day
	p["ads"] = 0
	p["free_hint"] = 0
	p["shop"] = 0
	p["dbl"] = 0
	p["gems_day"] = 0
	p["streak"] += 1
	Economy.grant(p["save"], Economy.gift_for_day(p["streak"]))
	Economy.grant(p["save"], Economy.streak_bonus(p["streak"]))


## Expected stars per level id from reports/stars.csv (3*p3 + 2*p2 + p1 of the average bot's wins), or {} if absent.
func _star_rates() -> Dictionary:
	var out := {}
	if not FileAccess.file_exists("res://reports/stars.csv"):
		return out
	var lines := FileAccess.get_file_as_string("res://reports/stars.csv").split("\n", false)
	for l in lines.slice(1):
		var f := l.split(",")
		if f.size() >= 13:
			out[f[0]] = 3.0 * float(f[10]) + 2.0 * float(f[11]) + float(f[12])
	return out
