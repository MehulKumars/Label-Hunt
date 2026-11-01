## Coins, boosters, XP, the play streak and the daily gift (autoload "Wallet"). Applies the pure rules in Economy,
## Streak, GiftLadder and AdPolicy to the save, and writes at once: a spend or a grant must survive a kill.
extends Node

## Coins, inventory or XP changed.
signal changed


func _ready() -> void:
	if Save.data.get("xp_backdate", false):
		_backdate()


func coins() -> int:
	return int(Save.data["coins"])


func count(item: String) -> int:
	return Economy.count(Save.data, item)


func can_afford(item: String) -> bool:
	return Economy.can_afford(Save.data, item)


## Uses one booster (inventory first, else coins). False if it can't be paid.
func spend(item: String) -> bool:
	var before := coins()
	var how := Economy.spend(Save.data, item)
	if how == "":
		return false
	Save.data["stats"]["coins_spent"] = int(Save.data["stats"]["coins_spent"]) + (before - coins())
	_commit()
	return true


## Spends coins directly (Continue). False if there aren't enough.
func pay(amount: int) -> bool:
	if coins() < amount:
		return false
	Save.data["coins"] = coins() - amount
	Save.data["stats"]["coins_spent"] = int(Save.data["stats"]["coins_spent"]) + amount
	_commit()
	return true


func grant(rewards: Dictionary) -> void:
	Economy.grant(Save.data, rewards)
	Save.data["stats"]["coins_earned"] = int(Save.data["stats"]["coins_earned"]) + int(rewards.get("coins", 0))
	_commit()


## Today as a day number, guarded against clocks moved back (DayClock).
func today() -> int:
	var e := DayClock.effective(DayClock.today(), int(Save.data["clock"]["max_day"]))
	Save.data["clock"]["max_day"] = e["max_seen"]
	return e["day"]


## {level, into, need, title, xp}
func level_info() -> Dictionary:
	var info := Economy.level_for_xp(int(Save.data["xp"]))
	info["title"] = Economy.title_for(info["level"])
	info["xp"] = int(Save.data["xp"])
	return info


## Applies a room win: coins and XP on a first solve, XP on a first gold lid, room coins, the streak day.
## `progress` is Progression.record_win's result. Returns what happened, for the Win card:
## {coins, xp, ups: [{level, rewards}], room_coins, streak: {count, kind, saver_earned}, milestone, gift_ready}
func record_win(entry: Dictionary, progress: Dictionary) -> Dictionary:
	var out := {"coins": 0, "xp": 0, "ups": [], "room_coins": 0, "streak": {}, "milestone": {}, "gift_ready": false}
	var groups := (entry["data"]["groups"] as Array).size()
	var kind := str(entry["kind"])
	if progress.get("first_solve", false):
		out["coins"] = Economy.win_coins(groups, kind, int(entry.get("room", 1)))
		out["xp"] = Economy.win_xp(groups, kind)
	if progress.get("new_gold", false):
		out["xp"] += Economy.GOLD_XP
	if progress.get("room_done", false):
		out["room_coins"] = Economy.ROOM_COINS
	Economy.grant(Save.data, {"coins": out["coins"] + out["room_coins"]})
	Save.data["stats"]["coins_earned"] = int(Save.data["stats"]["coins_earned"]) + out["coins"] + out["room_coins"]
	out["ups"] = Economy.add_xp(Save.data, out["xp"])
	var day := today()
	var rec := Streak.record(Save.data["streak"], day, Economy.STREAK_SAVER_EVERY, Economy.MAX_SAVERS)
	Save.data["streak"] = rec["state"]
	out["streak"] = {"count": rec["state"]["count"], "kind": rec["kind"], "saver_earned": rec["saver_earned"]}
	if rec["kind"] != "same_day" and not Economy.streak_bonus(int(rec["state"]["count"])).is_empty():
		out["milestone"] = Economy.streak_bonus(int(rec["state"]["count"]))
		Economy.grant(Save.data, out["milestone"])
	out["gift_ready"] = gift_ready()
	_commit()
	return out


## The free samples when a booster is introduced, once per tag. {} if already given or nothing to give.
func intro_gift(tag: String) -> Dictionary:
	if not Economy.INTRO_GIFTS.has(tag) or Save.data["intro_gifts"].has(tag):
		return {}
	Save.data["intro_gifts"][tag] = true
	var r: Dictionary = Economy.INTRO_GIFTS[tag]
	grant(r)
	return r


## The starter coins at the end of the tutorial (once).
func starter_gift() -> void:
	if Save.data["intro_gifts"].has("starter"):
		return
	Save.data["intro_gifts"]["starter"] = true
	grant({"coins": Economy.STARTER_COINS})


func streak_shown() -> int:
	return Streak.shown(Save.data["streak"], today())


func played_today() -> bool:
	return Streak.played_on(Save.data["streak"], today())


func gift_ready() -> bool:
	return GiftLadder.ready(int(Save.data["gift"]["claimed_day"]), played_today(), today())


## Today's gift by streak day (0-based rung and its rewards).
func gift_today() -> Dictionary:
	var rung := GiftLadder.rung(int(Save.data["streak"]["count"]), Economy.GIFT_LADDER.size())
	return {"rung": rung, "rewards": Economy.GIFT_LADDER[rung]}


## Claims today's gift (doubled after an optional ad). Returns the rewards granted, or {} if not ready.
func claim_gift(doubled: bool) -> Dictionary:
	if not gift_ready():
		return {}
	var r: Dictionary = (gift_today()["rewards"] as Dictionary).duplicate()
	if doubled:
		for k in r:
			r[k] = int(r[k]) * 2
	Save.data["gift"]["claimed_day"] = today()
	grant(r)
	return r


## Ads: whether one may be offered for this placement now, how many are left today, and counting a watched one.
func can_watch(placement: String) -> bool:
	return AdPolicy.can_show(Save.data["ads"], placement, today(), int(Time.get_unix_time_from_system()))


func ads_left(placement: String) -> int:
	return AdPolicy.left_today(Save.data["ads"], placement, today())


func ad_watched(placement: String) -> void:
	AdPolicy.record(Save.data["ads"], placement, today(), int(Time.get_unix_time_from_system()))
	Save.data["stats"]["ads"] = int(Save.data["stats"]["ads"]) + 1
	_commit()


## v2 saves had no XP: give it for the levels already solved (once), without coins or level-up rewards beyond
## the coins of reaching the levels (they were earned by play).
func _backdate() -> void:
	var cat: Catalog = Levels.catalog
	var xp := 0
	for id in Save.data["solved"]:
		if not cat.has(id):
			continue
		var e := cat.entry(id)
		xp += Economy.win_xp((e["data"]["groups"] as Array).size(), str(e["kind"]))
		if Save.data["solved"][id]["gold"]:
			xp += Economy.GOLD_XP
	Save.data["xp_backdate"] = false
	Economy.add_xp(Save.data, xp)
	_commit()


func _commit() -> void:
	Save.write()
	changed.emit()
