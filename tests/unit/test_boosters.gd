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


func _session(level: Dictionary = LEVEL) -> Session:
	return Session.new(LevelData.from_dict(level), {})


func _card(s: Session, w: String) -> int:
	return s.level.card_of_word(w)


# --- Complete ------------------------------------------------------------------------------------------------------

func test_complete_pulls_buried_cards_and_seals_the_group() -> void:
	var s := _session()
	var ev := s.complete(0)
	assert_eq(s.board.sealed[0], 1)
	assert_eq(s.completes, 1)
	for j in s.board.jar_count():
		for c in s.board.jars[j]:
			assert_ne(LevelData.group_of(c), 0, "no Fruit card left on the board")
	assert_eq(s.board.jars[0], PackedInt32Array([_card(s, "Cow"), _card(s, "Rake")]), "cards above a buried one settle down")
	assert_eq(s.know.step[0], Knowledge.FULL_STEP)
	assert_eq(ev[0]["type"], "seal")
	assert_eq((ev[0]["cards"] as Array).size(), 4)


func test_complete_is_an_undo_barrier() -> void:
	var s := _session()
	s.try_move(0, 3)
	assert_true(s.can_undo())
	s.complete(1)
	assert_false(s.can_undo())


func test_completing_every_group_wins() -> void:
	var s := _session()
	s.complete(0)
	s.complete(1)
	var ev := s.complete(2)
	assert_true(s.won)
	assert_eq(ev.back()["type"], "won")
	assert_true(s.complete(0).is_empty(), "nothing more once won")


func test_solver_and_tidy_after_a_seal() -> void:
	var s := _session()
	s.complete(1)
	var res := Solver.solve(s.board, 20000)
	assert_true(res["solved"], "the solver's goal counts sealed groups as done")
	for mv: Vector2i in res["path"]:
		s.try_move(mv.x, mv.y)
	assert_true(s.won)


func test_all_known_counts_sealed_groups() -> void:
	var s := _session()
	s.complete(0)
	s.complete(1)
	# Only the shed group is left: its four cards are the last open group, so Tidy may finish.
	assert_true(s.all_known())


func test_a_labelled_jar_of_a_sealed_group_refuses_for_free() -> void:
	var lvl := LEVEL.duplicate(true)
	lvl["labelled"] = {"4": 0}
	var s := _session(lvl)
	s.complete(0)
	var r := s.try_move(0, 4)
	assert_eq(r["result"], Session.Result.REFUSE_PROVEN, "Fruit is sealed, so nothing else can go in its jar")
	assert_eq(s.slips, 0)


# --- Hint ----------------------------------------------------------------------------------------------------------

func test_hint_advances_a_label_at_most_one_step() -> void:
	var s := _session()
	s.hint(_card(s, "Pear"))
	assert_eq(s.know.step[0], 1)
	s.hint(_card(s, "Pear"))
	assert_eq(s.know.step[0], 1, "the same card again tags nothing new")
	assert_eq(s.hints, 2)


func test_advisor_finishes_lids_first() -> void:
	var lvl := LEVEL.duplicate(true)
	lvl["jars"] = [["Apple", "Pear", "Plum"], ["Cow", "Pig", "Sheep", "Goat"], ["Rake", "Hoe", "Spade", "Mango"], ["Saw"]]
	lvl["empty"] = 1
	var s := _session(lvl)
	var adv := Advisor.next_move(s.board, 0)
	assert_eq(adv["kind"], "lid")
	assert_eq(adv["move"], Vector2i(2, 0), "Mango finishes the Fruit jar")


func test_advisor_moves_are_legal_and_reach_the_win() -> void:
	var s := _session()
	for i in 40:
		if s.won:
			break
		var adv := Advisor.next_move(s.board, 0)
		assert_ne(adv["kind"], "none")
		var mv: Vector2i = adv["move"]
		assert_eq(s.board.drop_check(s.board.top(mv.x), mv.y), BoardState.Drop.OK)
		s.try_move(mv.x, mv.y)
	assert_true(s.won, "following hints alone solves the board")


func test_board_key_changes_with_the_board() -> void:
	var s := _session()
	var k := Advisor.board_key(s.board)
	s.try_move(0, 3)
	assert_ne(Advisor.board_key(s.board), k)


# --- action log and resume -----------------------------------------------------------------------------------------

func test_replay_rebuilds_the_attempt_exactly() -> void:
	var s := _session()
	s.try_move(0, 3)            # Pear to an empty jar
	s.try_move(1, 3)            # Sheep slips
	s.undo()
	s.hint(_card(s, "Saw"))
	s.add_jar()
	s.complete(1)
	s.grant_slips(1)
	var r := Session.replay(LevelData.from_dict(LEVEL), {}, s.log)
	assert_not_null(r)
	assert_eq(r.board.jars, s.board.jars)
	assert_eq(r.slips, s.slips)
	assert_eq(r.budget, s.budget)
	assert_eq(r.know.step, s.know.step)
	assert_eq(r.board.sealed, s.board.sealed)
	assert_eq(r.log, s.log)


func test_replay_refuses_a_log_that_does_not_apply() -> void:
	assert_null(Session.replay(LevelData.from_dict(LEVEL), {}, [["m", 3, 0]]), "nothing to take from an empty jar")
	assert_null(Session.replay(LevelData.from_dict(LEVEL), {}, [["x"]]))
	assert_null(Session.replay(LevelData.from_dict(LEVEL), {}, [["u"]]), "no undo at the start")
	assert_null(Session.replay(LevelData.from_dict(LEVEL), {}, ["m"]))
