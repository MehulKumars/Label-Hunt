extends GutTest

# A tutorial of 2 boards and a room of 12 levels (shelf 1 = r01..r10), gold from r03.


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
			d["gold"] = 1
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
	assert_true(c.features_at("m01").has("peek"), "test boards get every tool")


# --- progression -------------------------------------------------------------------------------------------------

func test_levels_unlock_in_order() -> void:
	var c := _catalog()
	var s := _save()
	assert_eq(Progression.next_level(c, s), "r01")
	assert_true(Progression.is_unlocked(c, s, "r01"))
	assert_false(Progression.is_unlocked(c, s, "r02"))
	Progression.record_win(c, s, "r01", 0, false)
	assert_eq(Progression.next_level(c, s), "r02")
	assert_true(Progression.is_unlocked(c, s, "r01"), "solved levels stay replayable")
	assert_false(Progression.is_unlocked(c, s, "nope"))


func test_gold_needs_threshold_clean_and_unassisted() -> void:
	var c := _catalog()
	var s := _save()
	assert_false(Progression.record_win(c, s, "r01", 0, false)["gold"], "no gold before the threshold levels")
	Progression.record_win(c, s, "r02", 0, false)
	var w := Progression.record_win(c, s, "r03", 2, false)
	assert_false(w["gold"], "2 slips > threshold 1")
	w = Progression.record_win(c, s, "r03", 1, true)
	assert_false(w["gold"], "assisted wins never earn gold")
	w = Progression.record_win(c, s, "r03", 1, false)
	assert_true(w["new_gold"] and w["first_gold"])
	assert_false(w["first_solve"])
	assert_eq(s["solved"]["r03"]["slips"], 1, "best slips kept")
	w = Progression.record_win(c, s, "r03", 3, false)
	assert_true(s["solved"]["r03"]["gold"], "a worse replay never takes gold away")
	assert_false(w["new_gold"])


func test_shelf_and_room_completion_fire_once() -> void:
	var c := _catalog()
	var s := _save()
	for i in 9:
		assert_eq(Progression.record_win(c, s, "r%02d" % (i + 1), 0, false)["shelf_full"], -1)
	var w := Progression.record_win(c, s, "r10", 0, false)
	assert_eq(w["shelf_full"], 0)
	assert_eq(Progression.record_win(c, s, "r10", 0, false)["shelf_full"], -1, "replays don't refire")
	Progression.record_win(c, s, "r11", 0, false)
	w = Progression.record_win(c, s, "r12", 0, false)
	assert_true(w["room_done"])
	assert_eq(w["next"], "")
	assert_eq(Progression.solved_count(c, s, 1), 12)


func test_tutorial_and_test_boards_never_record() -> void:
	var c := _catalog()
	var s := _save()
	Progression.record_win(c, s, "tut1", 0, false)
	Progression.record_win(c, s, "m01", 0, false)
	assert_true(s["solved"].is_empty())


# --- save schema -------------------------------------------------------------------------------------------------

func test_v1_save_migrates() -> void:
	var v1 := {"version": 1, "level": 5, "launches": 3.0,
		"settings": {"sound": false, "haptics": true, "reduce_motion": true, "fps": false},
		"rules": {"mode": "stars", "pour": true}, "seen_captions": {"budget": true}}
	var s := SaveSchema.sanitize(v1, {})
	assert_eq(s["version"], 2)
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
	assert_eq(s["solved"]["r01"], {"slips": 99, "gold": false})
	assert_eq(s["solved"]["r02"], {"slips": 0, "gold": false})


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
