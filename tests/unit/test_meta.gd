extends GutTest


func _save() -> Dictionary:
	return SaveSchema.defaults()


# --- economy -------------------------------------------------------------------------------------------------------

func test_win_rewards_grow_with_size_and_kind() -> void:
	assert_eq(Economy.win_coins(3, "normal"), 14)
	assert_eq(Economy.win_coins(6, "hard"), 34)
	assert_eq(Economy.win_coins(6, "hard", 17), 66, "+2 a room: late rooms pay more than a Hint")
	assert_true(Economy.win_xp(5, "tricky") > Economy.win_xp(5, "normal"))


func test_stars_pay_coins_per_star() -> void:
	assert_eq(Economy.per_star(2, "normal"), 4, "a 2-group Room 1 level: 4, 8 or 12 coins")
	assert_eq(Economy.per_star(5, "hard", 10), 22, "Room 10, hard: 22 a star")
	assert_eq(Economy.per_star(6, "hard", 17), 33, "the hardest levels: 33 a star, 99 for 3 stars")
	assert_true(Economy.per_star(4, "normal", 14) * 1.0 / Economy.win_coins(4, "normal", 14) > Economy.per_star(4, "normal", 3) * 1.0 / Economy.win_coins(4, "normal", 3), "late rooms pay more per star")
	for groups in range(2, 7):
		assert_true(Economy.per_star(groups, "normal") >= 1)


func test_diamonds_anchor_and_value() -> void:
	# The anchor: 1 Hint = 50 coins = 10 diamonds; bigger boosters are a little better value in diamonds.
	var rate := float(Economy.PRICES["hint"]) / Economy.DIAMOND_PRICES["hint"]
	for item in Economy.DIAMOND_PRICES:
		assert_true(Economy.DIAMOND_PRICES[item] * rate <= Economy.PRICES[item], "%s is never dearer in diamonds" % item)
	assert_true(int(Economy.PACKS[0]["diamonds"]) / int(Economy.DIAMOND_PRICES["hint"]) >= 10, "the $0.99 pack buys 10 Hints")
	var per_dollar := 0.0
	for p: Dictionary in Economy.PACKS:
		var v := float(p["diamonds"]) / float(p["usd"])
		assert_true(v >= per_dollar, "bigger packs are never worse value")
		per_dollar = v
	assert_true(float(Economy.PACKS.back()["usd"]) <= 9.99, "no big-spender pack")
	assert_true(Economy.AD_DIAMONDS * 2 <= Economy.DIAMOND_PRICES["hint"], "a shop ad banks half a Hint at most")
	for b: Dictionary in Economy.BUNDLES:
		assert_true(int(b["diamonds"]) < int(b["count"]) * int(Economy.DIAMOND_PRICES[b["item"]]), "bundles are cheaper")


func test_diamonds_pay_grant_and_clamp() -> void:
	var s := SaveSchema.defaults()
	assert_false(Economy.can_pay_diamonds(s, "hint"))
	assert_false(Economy.pay_diamonds(s, 10), "can't go below zero")
	Economy.grant(s, {"diamonds": 25})
	assert_true(Economy.can_pay_diamonds(s, "continue"))
	assert_false(Economy.can_pay_diamonds(s, "complete"))
	assert_true(Economy.pay_diamonds(s, 25))
	assert_eq(Economy.diamonds(s), 0)
	Economy.grant(s, {"diamonds": 99999999})
	assert_eq(Economy.diamonds(s), Economy.MAX_DIAMONDS)
	assert_eq(int(s["coins"]), 0, "diamonds never touch coins")


func test_streak_bonuses_follow_the_road_and_never_end() -> void:
	assert_eq(Economy.next_streak_bonuses(0, 5), [10, 15, 20, 30, 45] as Array[int])
	assert_eq(Economy.next_streak_bonuses(10, 1), [15] as Array[int])
	assert_eq(Economy.next_streak_bonuses(100, 2), [150, 200] as Array[int])
	assert_true(Economy.streak_bonus(7).is_empty(), "day 7 is the top of the gift week")
	assert_eq(int(Economy.streak_bonus(10)["coins"]), 150)
	assert_eq(int(Economy.streak_bonus(250)["coins"]), 1000)
	assert_true(Economy.streak_bonus(101).is_empty())


func test_the_coin_pill_never_shortens_a_balance_a_player_can_read() -> void:
	assert_eq(CoinPill.text_for(8184), "8,184")
	assert_eq(CoinPill.text_for(48221), "48,221")
	assert_eq(CoinPill.text_for(125400), "125K")
	assert_eq(CoinPill.text_for(1250000), "1.2M")


func test_spending_uses_the_inventory_first_and_never_goes_negative() -> void:
	var s := _save()
	s["coins"] = 60
	s["inventory"]["hint"] = 1
	assert_eq(Economy.spend(s, "hint"), "inventory")
	assert_eq(s["coins"], 60)
	assert_eq(Economy.spend(s, "hint"), "coins")
	assert_eq(s["coins"], 10)
	assert_eq(Economy.spend(s, "hint"), "", "can't afford: nothing changes")
	assert_eq(s["coins"], 10)
	assert_false(Economy.can_afford(s, "complete"))


func test_grants_are_clamped() -> void:
	var s := _save()
	Economy.grant(s, {"coins": 99999999, "hint": 5000, "saver": 9})
	assert_eq(s["coins"], 9999999)
	assert_eq(s["inventory"]["hint"], 999)
	assert_eq(s["streak"]["savers"], Economy.MAX_SAVERS)


func test_xp_levels_climb_and_reward_once() -> void:
	var s := _save()
	assert_eq(Economy.level_for_xp(0)["level"], 1)
	assert_eq(Economy.level_for_xp(59)["level"], 1)
	assert_eq(Economy.level_for_xp(60)["level"], 2)
	var prev := 0
	for xp in range(0, 20000, 250):
		var lv: int = Economy.level_for_xp(xp)["level"]
		assert_true(lv >= prev)
		prev = lv
	var ups := Economy.add_xp(s, 60 + 75 + 90 + 105 + 120)
	assert_eq(ups.size(), 5, "levels 2 to 6")
	assert_eq(s["coins"], Economy.LEVEL_UP_COINS * 5)
	assert_eq(s["inventory"]["hint"], 2, "level 5 gives two Hints")
	assert_true(s["avatars"].has("avocado"), "level 5 unlocks an avatar")
	assert_true(Economy.add_xp(s, 0).is_empty())


func test_titles_follow_level() -> void:
	assert_eq(Economy.title_for(1), "Apprentice")
	assert_eq(Economy.title_for(12), "Pickler")
	assert_eq(Economy.title_for(99), "Legend of the Larder")


func test_gift_ladder_repeats_weekly() -> void:
	assert_eq(Economy.gift_for_day(1)["coins"], 20)
	assert_true(Economy.gift_for_day(7).has("complete"))
	assert_eq(Economy.gift_for_day(8), Economy.gift_for_day(1))
	assert_eq(GiftLadder.rung(0, 7), 0)
	assert_eq(GiftLadder.rung(9, 7), 1)


# --- streak, clock, gift ---------------------------------------------------------------------------------------------

func test_streak_counts_consecutive_days() -> void:
	var st := Streak.fresh()
	st = Streak.record(st, 100)["state"]
	assert_eq(st["count"], 1)
	var r := Streak.record(st, 100)
	assert_eq(r["kind"], "same_day")
	st = Streak.record(st, 101)["state"]
	assert_eq(st["count"], 2)
	assert_eq(Streak.shown(st, 102), 2, "still alive the next day")
	assert_eq(Streak.shown(st, 103), 0, "a missed day with no saver ends it")
	st = Streak.record(st, 104)["state"]
	assert_eq(st["count"], 1)
	assert_eq(st["best"], 2)


func test_savers_are_earned_weekly_and_cover_a_missed_day() -> void:
	var st := Streak.fresh()
	for d in range(1, 8):
		st = Streak.record(st, d)["state"]
	assert_eq(st["savers"], 1, "seven days earn a saver")
	var r := Streak.record(st, 9)
	assert_eq(r["kind"], "saved")
	assert_eq(r["state"]["count"], 8)
	assert_eq(r["state"]["savers"], 0)
	assert_eq(Streak.record(r["state"], 12)["state"]["count"], 1, "two missed days and no saver: a new streak")


func test_clock_rollback_freezes_then_reanchors() -> void:
	assert_eq(DayClock.effective(100, 98)["day"], 100)
	assert_eq(DayClock.effective(99, 100)["day"], 100, "a day back: frozen at the furthest day seen")
	var far := DayClock.effective(90, 100)
	assert_eq(far["day"], 90, "far behind: trust the clock again")
	assert_eq(far["max_seen"], 90)
	assert_eq(DayClock.day_number(2026, 3, 1) - DayClock.day_number(2026, 2, 28), 1)
	assert_eq(DayClock.day_number(2027, 1, 1) - DayClock.day_number(2026, 12, 31), 1)


func test_gift_opens_after_a_play_once_a_day() -> void:
	assert_false(GiftLadder.ready(-1, false, 10), "not before playing")
	assert_true(GiftLadder.ready(-1, true, 10))
	assert_false(GiftLadder.ready(10, true, 10), "once a day")
	assert_true(GiftLadder.ready(9, true, 10))


# --- ads -----------------------------------------------------------------------------------------------------------

func test_ad_caps_and_cooldown() -> void:
	var ads := AdPolicy.fresh()
	assert_true(AdPolicy.can_show(ads, "free_hint", 5, 1000))
	AdPolicy.record(ads, "free_hint", 5, 1000)
	assert_false(AdPolicy.can_show(ads, "free_hint", 5, 1010), "cooldown")
	assert_true(AdPolicy.can_show(ads, "free_hint", 5, 1031))
	for i in 2:
		AdPolicy.record(ads, "free_hint", 5, 2000 + i * 100)
	assert_eq(AdPolicy.left_today(ads, "free_hint", 5), 0, "3 free hints a day")
	assert_false(AdPolicy.can_show(ads, "free_hint", 5, 9000))
	assert_true(AdPolicy.can_show(ads, "free_hint", 6, 9000), "a new day resets")
	for i in AdPolicy.DAILY_CAP - 3:
		AdPolicy.record(ads, "win_double", 5, 3000 + i * 100)
	assert_eq(AdPolicy.left_today(ads, "win_double", 5), 0, "the daily total caps every placement")


# --- save v3 -------------------------------------------------------------------------------------------------------

func test_v2_save_migrates_with_starter_coins_and_backdated_xp() -> void:
	var v2 := {"version": 2, "tutorial": {"done": true, "board": 0}, "solved": {"r1-01": {"slips": 0, "gold": true}},
		"board": {"id": "r1-02"}}
	var s := SaveSchema.sanitize(v2, {})
	assert_eq(s["version"], SaveSchema.VERSION)
	assert_eq(s["coins"], Economy.STARTER_COINS)
	assert_true(s["xp_backdate"])
	assert_true(s["solved"].has("r1-01"), "ids don't change")
	assert_true(s["board"].is_empty(), "v2 boards had no action log")


func test_sanitize_cleans_the_economy_fields() -> void:
	var junk := {"version": 3, "coins": -5, "inventory": {"hint": 1e12, "complete": "x", "gold": 3}, "xp": NAN,
		"profile": {"name": "  A\u0007very long name indeed!!  ", "avatar": "crown"},
		"avatars": {"crown": true, "bogus": true}, "streak": {"count": "7", "savers": 9},
		"ads": {"by_placement": {"free_hint": 2, 7: 1}}, "purchases": {"tokens": ["a", 5, "b"]},
		"board": {"id": "x", "fingerprint": "f", "log": [["m", 0, 1], ["m", "a", 1]]}}
	var s := SaveSchema.sanitize(junk, {})
	assert_eq(s["coins"], 0)
	assert_eq(s["inventory"]["hint"], 999)
	assert_eq(s["inventory"]["complete"], 0)
	assert_false(s["inventory"].has("gold"))
	assert_eq(s["xp"], 0)
	assert_eq(s["profile"]["name"], "Avery long name")
	assert_true(s["avatars"].has("crown"))
	assert_false(s["avatars"].has("bogus"))
	assert_eq(s["profile"]["avatar"], "crown")
	assert_eq(s["streak"]["count"], 0)
	assert_eq(s["streak"]["savers"], Economy.MAX_SAVERS)
	assert_eq(s["ads"]["by_placement"], {"free_hint": 2})
	assert_eq(s["purchases"]["tokens"], ["a", "b"])
	assert_true(s["board"].is_empty(), "a log with a bad step is dropped whole")
	assert_eq(SaveSchema.sanitize(s, {}), s, "sanitising twice changes nothing")


func test_back_from_a_room_goes_where_it_came_from() -> void:
	assert_eq(BackPolicy.decide({"screen": "room", "origin": "levels"}), &"levels")
	assert_eq(BackPolicy.decide({"screen": "room", "origin": "home"}), &"home")
	assert_eq(BackPolicy.decide({"screen": "levels"}), &"home")
	assert_eq(BackPolicy.decide({"screen": "profile"}), &"home")
	assert_eq(BackPolicy.decide({"screen": "play", "sheet": "utility"}), &"close_sheet", "the Shop over a level closes")
