extends GutTest

# A tutorial of 2 boards and a room of 12 levels (shelf 1 = r01..r10). r01-r02 have no slip budget (3 stars up to
# 3 slips); from r03 a budget of 6 and gold 0, so in Room 1 (offset +2) 3 stars up to 2 slips and 2 stars up to 4.


func _catalog() -> Catalog:
	var c := Catalog.new()
	c.add_file({"track": "tutorial", "levels": [
		{"id": "tut1", "introduces": ["move"]},
		{"id": "tut2", "introduces": ["dig"]},
	]})
	var levels: Array = []
	for i in 12:
		var d := {"id": "r%02d" % (i + 1)}
		if i == 1:
			d["introduces"] = ["undo"]
		if i == 3:
			d["introduces"] = ["jar"]
		if i >= 2:
			d["gold"] = 0
			d["budget"] = 6
		levels.append(d)
	c.add_file({"track": "room", "room": 1, "levels": levels})
	c.add_file({"track": "test", "levels": [{"id": "m01"}]})
	return c


func _save() -> Dictionary:
	return SaveSchema.defaults()


# --- catalog -----------------------------------------------------------------------------------------------------

func test_catalog_orders_and_titles() -> void:
	var c := _catalog()
	assert_eq(c.play_order().size(), 12)
	assert_eq(c.title("r03"), "Level 3")
	assert_eq(c.title("tut2"), "Tutorial 2")
	assert_eq(c.title("m01"), "Test board 1")
	assert_eq(c.shelf_of("r10"), 0)
	assert_eq(c.shelf_of("r11"), 1)


func test_features_accumulate_in_play_order() -> void:
	var c := _catalog()
	var f1 := c.features_at("r01")
	assert_true(f1.has("move") and f1.has("dig"), "tutorial features carry into the rooms")
	assert_false(f1.has("undo"))
	assert_true(c.features_at("r02").has("undo"))
	assert_false(c.features_at("r03").has("jar"))
	assert_true(c.features_at("r12").has("jar"))
	assert_true(c.features_at("m01").has("hint") and c.features_at("m01").has("complete"), "test boards get every tool")


# --- progression -------------------------------------------------------------------------------------------------

func test_levels_unlock_in_order() -> void:
	var c := _catalog()
	var s := _save()
	assert_eq(Progression.next_level(c, s), "r01")
	assert_true(Progression.is_unlocked(c, s, "r01"))
	assert_false(Progression.is_unlocked(c, s, "r02"))
	Progression.record_win(c, s, "r01", 0)
	assert_eq(Progression.next_level(c, s), "r02")
	assert_true(Progression.is_unlocked(c, s, "r01"), "solved levels stay replayable")
	assert_false(Progression.is_unlocked(c, s, "nope"))


func test_stars_best_and_gain() -> void:
	var c := _catalog()
	var s := _save()
	var w := Progression.record_win(c, s, "r01", 4)
	assert_eq(w["stars"], 2, "no budget: 2 stars for 4 or 5 slips")
	assert_eq(w["gained"], 2, "a first solve pays every star")
	Progression.record_win(c, s, "r02", 4)
	w = Progression.record_win(c, s, "r03", 5)
	assert_eq([w["stars"], w["gained"], w["gold"]], [1, 1, false], "past the 2-star limit: 1 star")
	w = Progression.record_win(c, s, "r03", 3)
	assert_eq([w["stars"], w["best"], w["gained"]], [2, 2, 1], "a better replay pays the star it adds")
	assert_false(w["first_solve"])
	w = Progression.record_win(c, s, "r03", 2)
	assert_true(w["gold"] and w["new_gold"] and w["first_gold"], "3 stars is the gold lid")
	assert_eq(w["gained"], 1)
	assert_eq(s["solved"]["r03"]["slips"], 2, "best slips kept")
	w = Progression.record_win(c, s, "r03", 7)
	assert_eq([w["stars"], w["best"], w["gained"]], [1, 3, 0], "a worse replay (here after a Continue) takes nothing")
	assert_true(s["solved"]["r03"]["gold"] and not w["new_gold"])
	assert_eq(Progression.star_count(c, s, 1), 2 + 2 + 3)


func test_star_limits_tighten_by_room_and_stay_below_budget() -> void:
	assert_eq(Economy.star_limits(1, 0, 6), Vector2i(2, 4), "rooms 1-4: gold + 2")
	assert_eq(Economy.star_limits(5, 0, 6), Vector2i(1, 3), "rooms 5-7: gold + 1")
	assert_eq(Economy.star_limits(8, 2, 6), Vector2i(2, 4), "rooms 8-13: gold")
	assert_eq(Economy.star_limits(14, 0, 6), Vector2i(0, 2), "rooms 14-17: gold - 1, never below 0")
	assert_eq(Economy.star_limits(17, 4, 7), Vector2i(3, 5), "rooms 14-17: gold - 1")
	assert_eq(Economy.star_limits(17, 6, 7), Vector2i(5, 6), "2 stars capped below the budget")
	assert_eq(Economy.star_limits(1, 0, 2), Vector2i(1, 1), "tight budget: every clean win is 3 stars")
	assert_eq(Economy.star_limits(14, 0, 2), Vector2i(0, 1))
	assert_eq(Economy.star_limits(3, -1, 4), Vector2i(2, 3), "no gold value counts as 0")
	assert_eq(Economy.star_limits(1, -1, 0), Economy.FREE_STAR_LIMITS, "no budget: 3 and 5 slips")


func test_every_shipped_level_has_sane_stars() -> void:
	var cat := Catalog.from_files(preload("res://src/core/levels.gd").files())
	var n := 0
	for id in cat.play_order():
		var e := cat.entry(id)
		var budget := int(e["data"].get("budget", 0))
		var lim := Economy.entry_limits(e)
		var last := 3
		for slips in range(0, maxi(budget, 6) + 4):
			var st := Economy.stars_for(slips, lim)
			assert_true(st >= 1 and st <= last, "%s: stars never rise with slips (%d slips)" % [id, slips])
			if budget > 0 and slips >= budget:
				assert_eq(st, 1, "%s: a win after a Continue is 1 star" % id)
			last = st
		assert_eq(Economy.stars_for(0, lim), 3, "%s: a clean sort is 3 stars" % id)
		n += 1
	assert_eq(n, 510)


func test_backdate_stars_from_best_slips() -> void:
	var c := _catalog()
	var s := _save()
	s["solved"] = {"r01": {"slips": 6}, "r03": {"slips": 3, "gold": false}, "r04": {"slips": 5, "gold": true},
		"gone": {"slips": 0}}
	Progression.backdate_stars(c, s)
	assert_eq(s["solved"]["r01"]["stars"], 1)
	assert_eq(s["solved"]["r03"]["stars"], 2)
	assert_eq(s["solved"]["r04"]["stars"], 3, "a gold lid stays 3 stars")
	assert_false(s["solved"]["gone"].has("stars"), "levels no longer shipped are left alone")


func test_v3_save_migrates_to_stars_and_diamonds() -> void:
	var v3 := {"version": 3, "coins": 420, "solved": {"r03": {"slips": 1, "gold": true}, "r04": {"slips": 2, "gold": false}},
		"ads": {"day": 5, "total": 2, "by_placement": {"shop_coins": 2}, "last_s": 10}}
	var s := SaveSchema.sanitize(v3, {})
	assert_eq(s["version"], SaveSchema.VERSION)
	assert_eq(s["diamonds"], 0)
	assert_true(s["stars_backdate"], "stars are derived once the catalog loads")
	assert_eq(s["solved"]["r03"]["stars"], 3, "gold already means 3 stars")
	assert_eq(s["solved"]["r04"]["stars"], 1, "at least 1 star until the backdate")
	assert_eq(s["ads"]["by_placement"].get("shop_diamonds", 0), 2, "today's shop ads still count toward the cap")
	assert_false(s["ads"]["by_placement"].has("shop_coins"))
	var bad := SaveSchema.sanitize({"version": 4, "diamonds": -50, "solved": {"r03": {"slips": 0, "stars": 9}}}, {})
	assert_eq(bad["diamonds"], 0)
	assert_eq(bad["solved"]["r03"]["stars"], 3)
	assert_true(bad["solved"]["r03"]["gold"], "gold follows stars")


func test_shelf_and_room_completion_fire_once() -> void:
	var c := _catalog()
	var s := _save()
	for i in 9:
		assert_eq(Progression.record_win(c, s, "r%02d" % (i + 1), 0)["shelf_full"], -1)
	var w := Progression.record_win(c, s, "r10", 0)
	assert_eq(w["shelf_full"], 0)
	assert_eq(Progression.record_win(c, s, "r10", 0)["shelf_full"], -1, "replays don't refire")
	Progression.record_win(c, s, "r11", 0)
	w = Progression.record_win(c, s, "r12", 0)
	assert_true(w["room_done"])
	assert_eq(w["next"], "")
	assert_eq(Progression.solved_count(c, s, 1), 12)


func test_tutorial_and_test_boards_never_record() -> void:
	var c := _catalog()
	var s := _save()
	Progression.record_win(c, s, "tut1", 0)
	Progression.record_win(c, s, "m01", 0)
	assert_true(s["solved"].is_empty())


# --- save schema -------------------------------------------------------------------------------------------------

func test_v1_save_migrates() -> void:
	var v1 := {"version": 1, "level": 5, "launches": 3.0,
		"settings": {"sound": false, "haptics": true, "reduce_motion": true, "fps": false},
		"rules": {"mode": "stars", "pour": true}, "seen_captions": {"budget": true}}
	var s := SaveSchema.sanitize(v1, {})
	assert_eq(s["version"], SaveSchema.VERSION)
	assert_true(s["tutorial"]["done"], "past the old tutorial levels")
	assert_eq(s["settings"]["sound"], 0.0)
	assert_eq(s["settings"]["music"], 0.7)
	assert_true(s["settings"]["reduce_motion"])
	assert_eq(s["rules"]["mode"], "stars")
	assert_eq(s["launches"], 3)
	assert_false(s.has("level"))
	assert_false(SaveSchema.sanitize({"version": 1, "level": 1}, {})["tutorial"]["done"])


func test_sanitize_survives_garbage() -> void:
	var junk: Array = [null, 7, "save", [], {"settings": "loud"}, {"solved": [1, 2]}, {"tutorial": {"board": NAN}},
		{"launches": INF}, {"settings": {"sound": 99, "music": -4, "haptics": "yes"}},
		{"solved": {"r01": {"slips": 1e12, "gold": "true"}, "ghost": {"slips": 0}, "r02": 5}},
		{"rules": {"mode": "god", "pour": 1, "evil": true}, "seen_captions": {"x".repeat(100): true}},
		{"board": {"id": 42}}, {"board": {"id": "ghost"}}]
	var valid := {"r01": true, "r02": true}
	for raw: Variant in junk:
		var s := SaveSchema.sanitize(raw, valid)
		assert_eq(s.keys().size(), SaveSchema.defaults().keys().size(), "shape for %s" % str(raw))
		assert_true(s["settings"]["sound"] >= 0.0 and s["settings"]["sound"] <= 1.0)
		assert_true(s["settings"]["haptics"] is bool)
		assert_true(s["tutorial"]["board"] >= 0 and s["tutorial"]["board"] <= 9)
		assert_false(s["solved"].has("ghost"))
		assert_false(s["rules"].has("evil"))
		assert_true(s["board"].is_empty())
	var s := SaveSchema.sanitize(junk[9], valid)
	assert_eq(s["solved"]["r01"], {"slips": 99, "stars": 1, "gold": false})
	assert_eq(s["solved"]["r02"], {"slips": 0, "stars": 1, "gold": false})


func test_a_saved_board_keeps_the_rules_it_was_played_under() -> void:
	var raw := {"version": SaveSchema.VERSION, "board": {"id": "r01", "fingerprint": "abc", "log": [["m", 0, 3], ["n", 3, 0]],
		"rules": {"pour": true, "mode": "budget", "evil": 1}}}
	var b: Dictionary = SaveSchema.sanitize(raw, {"r01": true})["board"]
	assert_eq(b["rules"], {"pour": true, "mode": "budget"}, "known rule keys only")
	assert_eq(b["log"], [["m", 0, 3], ["n", 3, 0]])
	var old: Dictionary = SaveSchema.sanitize({"version": SaveSchema.VERSION, "board": {"id": "r01", "fingerprint": "abc", "log": []}},
		{"r01": true})["board"]
	assert_ne(SaveSchema.rules(old["rules"]), SaveSchema.rules(Session.rules_with({})), "a board saved before pour won't resume")


func test_sanitize_is_idempotent() -> void:
	var s := SaveSchema.defaults()
	s["solved"] = {"r01": {"slips": 2, "gold": true}}
	s["tutorial"] = {"done": true, "board": 0}
	var once := SaveSchema.sanitize(s, {})
	assert_eq(SaveSchema.sanitize(JSON.parse_string(JSON.stringify(once)), {}), once)


# --- back --------------------------------------------------------------------------------------------------------

func test_back_policy() -> void:
	var cases := [
		[{"screen": "play", "sheet": "utility"}, &"close_sheet"],
		[{"screen": "play", "sheet": "result"}, &"home"],
		[{"screen": "play", "sheet": "blocking"}, &"ignore"],
		[{"screen": "play", "lifted": true}, &"drop_card"],
		[{"screen": "play"}, &"pause"],
		[{"screen": "tutorial", "lifted": true}, &"drop_card"],
		[{"screen": "tutorial"}, &"skip_prompt"],
		[{"screen": "room"}, &"home"],
		[{"screen": "home"}, &"background"],
		[{"screen": "home", "sheet": "utility"}, &"close_sheet"],
	]
	for c: Array in cases:
		assert_eq(BackPolicy.decide(c[0]), c[1], str(c[0]))
