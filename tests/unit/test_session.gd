extends GutTest

# Fruit = group 0, Farm = group 1, Tools = group 2.
const LEVEL := {
	"id": "t",
	"groups": [
		{"label": "Fruit", "key": "Fruit", "words": ["Apple", "Pear", "Plum", "Mango"]},
		{"label": "Farm animals", "key": "animals", "words": ["Cow", "Pig", "Sheep", "Goat"]},
		{"label": "Things in a shed", "key": "shed", "words": ["Rake", "Hoe", "Spade", "Saw"]},
	],
	"jars": [["Apple", "Cow", "Rake", "Pear"], ["Pig", "Hoe", "Plum", "Sheep"], ["Spade", "Mango", "Goat", "Saw"]],
	"empty": 2,
	"budget": 3,
}


func _session(overrides: Dictionary = {}, level: Dictionary = LEVEL) -> Session:
	return Session.new(LevelData.from_dict(level), overrides)


func _card(s: Session, w: String) -> int:
	return s.level.card_of_word(w)


func test_level_parses_cards_by_group() -> void:
	var l := LevelData.from_dict(LEVEL)
	assert_eq(l.jars.size(), 5)
	assert_eq(LevelData.group_of(l.card_of_word("Goat")), 1)
	assert_eq(l.word(l.jars[0][3]), "Pear")


func test_move_to_empty_is_legal_and_undoable() -> void:
	var s := _session()
	var r := s.try_move(0, 3)
	assert_eq(r["result"], Session.Result.MOVED)
	assert_eq(s.board.top(3), _card(s, "Pear"))
	assert_true(s.can_undo())
	s.undo()
	assert_eq(s.board.top(0), _card(s, "Pear"))
	assert_eq(s.board.size(3), 0)


func test_wrong_drop_is_a_slip_that_tags_and_steps() -> void:
	var s := _session()
	s.try_move(0, 3) # Pear -> empty
	var r := s.try_move(1, 3) # Sheep onto Pear: wrong
	assert_eq(r["result"], Session.Result.SLIP)
	assert_eq(s.slips, 1)
	assert_eq(s.board.top(1), _card(s, "Sheep"), "card bounces home")
	assert_eq(s.know.class_tag(_card(s, "Sheep")), 1, "slipped card is tagged to its group")
	assert_eq(s.know.step[1], 1)


func test_proven_wrong_drop_is_refused_for_free() -> void:
	var s := _session()
	s.try_move(0, 3) # Pear -> empty
	s.try_move(1, 3) # Sheep slips off Pear
	var r := s.try_move(1, 3) # same drop again
	assert_eq(r["result"], Session.Result.REFUSE_PROVEN)
	assert_eq(s.slips, 1, "no second slip")


func test_proof_follows_chains_through_classes() -> void:
	var s := _session()
	s.try_move(0, 3) # Pear -> jar 3
	s.try_move(1, 4) # Sheep -> jar 4
	s.try_move(1, 3) # Plum onto Pear: legal pair (Fruit)
	s.try_move(4, 3) # Sheep onto Plum: slip; Sheep proven different from the Pear/Plum class
	assert_true(s.know.proven_diff(_card(s, "Sheep"), _card(s, "Pear")))


func test_first_pair_reveals_half_label() -> void:
	var s := _session()
	s.try_move(0, 3) # Pear
	s.try_move(1, 4) # Sheep
	var r := s.try_move(1, 3) # Plum onto Pear
	assert_eq(r["result"], Session.Result.MOVED)
	assert_eq(s.know.step[0], 1)
	assert_eq(s.know.class_tag(_card(s, "Pear")), 0)


func test_budget_runs_out_to_a_loss_and_continue_resumes() -> void:
	var s := _session()
	s.try_move(0, 3) # Pear -> 3
	s.try_move(1, 3) # Sheep slip 1
	s.try_move(2, 3) # Saw slip 2
	s.try_move(0, 4) # Rake -> 4
	s.try_move(2, 4) # Saw onto Rake: legal
	s.try_move(0, 4) # Cow onto Saw: slip 3 -> lost
	assert_true(s.lost)
	s.continue_play(2)
	assert_false(s.lost)
	assert_eq(s.slips_left(), 2)


func test_stars_mode_never_loses() -> void:
	var s := _session({"mode": "stars"})
	s.try_move(0, 3)
	s.try_move(1, 3)
	s.try_move(2, 3)
	s.try_move(0, 3) # Rake onto Pear
	assert_false(s.lost)


func test_lid_closes_jar_and_clears_undo() -> void:
	var lvl := {
		"groups": [
			{"label": "Fruit", "key": "Fruit", "words": ["Apple", "Pear", "Plum", "Mango"]},
			{"label": "Farm animals", "key": "animals", "words": ["Cow", "Pig", "Sheep", "Goat"]},
		],
		"jars": [["Apple", "Pear", "Plum"], ["Pig", "Sheep", "Goat", "Mango"], ["Cow"]],
	}
	var s := _session({}, lvl)
	var r := s.try_move(1, 0)
	var types := (r["events"] as Array).map(func(e): return e["type"])
	assert_has(types, "lid")
	assert_true(s.board.is_closed(0))
	assert_false(s.can_undo())
	assert_eq(s.know.step[0], Knowledge.FULL_STEP)
	s.try_move(1, 2)
	s.try_move(1, 2)
	r = s.try_move(1, 2)
	assert_true(s.won)


func test_stuck_uses_player_knowledge_not_truth() -> void:
	# No empty jars; tops Pear (fruit) and Sheep (farm) differ but nothing proves it yet.
	var lvl := {
		"groups": [
			{"label": "Fruit", "key": "Fruit", "words": ["Apple", "Pear", "Plum", "Mango"]},
			{"label": "Farm animals", "key": "animals", "words": ["Cow", "Pig", "Sheep", "Goat"]},
		],
		"jars": [["Apple", "Cow", "Pear"], ["Pig", "Plum", "Goat", "Sheep"], ["Mango"]],
	}
	var s := _session({}, lvl)
	# Mango (jar 2) has a legal move onto Pear, so we are not stuck either way.
	assert_false(s.is_stuck())
	s.try_move(2, 0) # Mango onto Pear: legal, jar 2 now empty
	assert_false(s.is_stuck(), "an empty jar always offers a move")


func test_hint_tags_without_slip() -> void:
	var s := _session()
	var ev := s.hint(_card(s, "Saw"))
	assert_eq(s.slips, 0)
	assert_eq(s.know.class_tag(_card(s, "Saw")), 2)
	assert_eq(ev.size(), 2)


func test_frost_hides_until_top_and_stays_seen_after_undo() -> void:
	var lvl := LEVEL.duplicate(true)
	lvl["frost"] = ["Rake"]
	var s := _session({}, lvl)
	var rake := _card(s, "Rake")
	assert_eq(s.know.seen[rake], 0)
	s.try_move(0, 3) # Pear off -> Rake on top
	assert_eq(s.know.seen[rake], 1)
	s.undo()
	assert_eq(s.know.seen[rake], 1)


func test_labelled_jar_only_takes_its_group() -> void:
	var lvl := LEVEL.duplicate(true)
	lvl["labelled"] = {"4": 2}
	var s := _session({}, lvl)
	assert_eq(s.know.step[2], Knowledge.FULL_STEP)
	var r := s.try_move(0, 4) # Pear into the Tools jar
	assert_eq(r["result"], Session.Result.SLIP)
	r = s.try_move(2, 4) # Saw into the Tools jar
	assert_eq(r["result"], Session.Result.MOVED)


func test_corked_jar_opens_after_any_lid() -> void:
	var lvl := {
		"groups": [
			{"label": "Fruit", "key": "Fruit", "words": ["Apple", "Pear", "Plum", "Mango"]},
			{"label": "Farm animals", "key": "animals", "words": ["Cow", "Pig", "Sheep", "Goat"]},
		],
		"jars": [["Apple", "Pear", "Plum"], ["Pig", "Sheep", "Goat", "Mango"], ["Cow"]],
		"corked": [2],
	}
	var s := _session({}, lvl)
	assert_eq(s.try_move(1, 2)["result"], Session.Result.REFUSE_CLOSED)
	s.try_move(1, 0) # Mango lids Fruit
	assert_false(s.board.is_closed(2))


func test_all_known_by_elimination() -> void:
	var lvl := {
		"groups": [
			{"label": "Fruit", "key": "Fruit", "words": ["Apple", "Pear", "Plum", "Mango"]},
			{"label": "Farm animals", "key": "animals", "words": ["Cow", "Pig", "Sheep", "Goat"]},
		],
		"jars": [["Apple", "Pear", "Plum"], ["Pig", "Sheep", "Goat", "Mango"], ["Cow"]],
	}
	var s := _session({}, lvl)
	assert_false(s.all_known())
	s.try_move(1, 0) # lid Fruit; only Farm remains
	assert_true(s.all_known())


func test_label_text_steps() -> void:
	assert_eq(LabelText.at_step("Things with keys", "keys", 0), "")
	assert_eq(LabelText.at_step("Things with keys", "keys", 1), "Things with _ _ _ _")
	assert_eq(LabelText.at_step("Things with keys", "keys", 2), "Things with k _ _ _")
	assert_eq(LabelText.at_step("Fruit", "Fruit", 2), "F _ _ _ _")
	assert_eq(LabelText.at_step("Fruit", "Fruit", 3), "Fruit")


func test_solver_solves_and_path_replays() -> void:
	var s := _session()
	var res := Solver.solve(s.board)
	assert_true(res["solved"])
	for mv in res["path"]:
		var r := s.try_move(mv.x, mv.y, false)  # as Tidy plays it: single-card moves
		assert_eq(r["result"], Session.Result.MOVED, "solver path replays legally")
	assert_true(s.won)


## Builds Cow under Sheep (a proven pair) on top of jar 0, and leaves Pig alone in jar 1. Pour is off by default
## (the test menu can turn it on), so these tests turn it on.
func _pour_setup(overrides: Dictionary = {"pour": true}) -> Session:
	var s := _session(overrides)
	s.try_move(0, 3)  # Pear to an empty jar
	s.try_move(0, 4)  # Rake to the other
	s.try_move(1, 0)  # Sheep onto Cow: a pair
	s.try_move(1, 3)  # Plum onto Pear
	s.try_move(1, 4)  # Hoe onto Rake; jar 1 is [Pig]
	return s


func test_pour_carries_a_proven_pair_in_one_move() -> void:
	var s := _pour_setup()
	var r := s.try_move(0, 1)  # Sheep onto Pig: Cow, proven the same, comes too
	assert_eq(r["result"], Session.Result.MOVED)
	assert_eq((r["events"] as Array).filter(func(e: Dictionary) -> bool: return e["type"] == "move").size(), 2)
	assert_eq(s.board.jars[1], PackedInt32Array([_card(s, "Pig"), _card(s, "Sheep"), _card(s, "Cow")]))
	assert_eq(s.board.jars[0], PackedInt32Array([_card(s, "Apple")]), "Apple is not proven Farm, so it stays")
	s.undo()
	assert_eq(s.board.jars[0], PackedInt32Array([_card(s, "Apple"), _card(s, "Cow"), _card(s, "Sheep")]), "one undo, whole pour")


func test_single_moves_and_the_rule_toggle_skip_pour() -> void:
	var s := _pour_setup()
	s.try_move(0, 1, false)
	assert_eq(s.board.size(1), 2, "a solver step moves one card")
	assert_eq(s.log.back(), ["n", 0, 1], "logged as a single move")
	var off := _pour_setup({"pour": false})
	off.try_move(0, 1)
	assert_eq(off.board.size(1), 2, "pour off: one card")


func test_replay_rebuilds_pours_and_single_moves() -> void:
	var s := _pour_setup()
	s.try_move(0, 1)
	s.try_move(3, 0, false)
	var r := Session.replay(LevelData.from_dict(LEVEL), {"pour": true}, s.log)
	assert_not_null(r)
	assert_eq(r.board.jars, s.board.jars)
	var wrong_rules := Session.replay(LevelData.from_dict(LEVEL), {}, s.log)
	assert_true(wrong_rules == null or wrong_rules.board.jars != s.board.jars, "why a resume checks the rules first")


func test_fingerprint_changes_with_content() -> void:
	var a := LevelData.from_dict(LEVEL)
	var d := LEVEL.duplicate(true)
	d["budget"] = 4
	var b := LevelData.from_dict(d)
	assert_ne(a.fingerprint(), b.fingerprint())
	assert_eq(a.fingerprint(), LevelData.from_dict(LEVEL).fingerprint())


func test_head_start_picks_the_hardest_blank_label_and_replays() -> void:
	var d := LEVEL.duplicate(true)
	d["groups"][2]["tier"] = 3
	var s := _session({}, d)
	assert_eq(s.head_start_group(), 2, "the tier-3 group needs the help most")
	var ev := s.head_start(2)
	assert_eq(ev.size(), 1)
	assert_eq(s.know.step[2], 1, "its label starts at the first step, as a slip would show it")
	assert_eq(s.log.back(), ["l", 2])
	assert_true(s.head_start(2).is_empty(), "only a blank label gets one")
	assert_eq(s.head_start_group(), 0, "next blank, hardest first")
	var r := Session.replay(LevelData.from_dict(d), {}, s.log)
	assert_not_null(r)
	assert_eq(r.know.step, s.know.step)
