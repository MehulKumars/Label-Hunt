## The generator's fairness rules: wordplay checks and the global reuse ledger.
extends GutTest

const BANK := "res://data/bank/categories.txt"
const TARGETS := "res://data/bank/wordplay_targets.txt"


func _bank_with(kind: String, words := PackedStringArray()) -> Bank:
	var b := Bank.new()
	b.add({"id": "rule", "label": "Rule", "key": "rule", "tier": 4, "domain": "wordplay", "words": PackedStringArray(["Xyz"])})
	b.add({"id": "other", "label": "Other", "key": "other", "tier": 1, "domain": "food", "words": PackedStringArray(["Top", "Pot"])})
	b.targets[0] = {"kind": kind, "words": words}
	return b


func test_hidden_targets_and_anchors() -> void:
	var b := _bank_with("hidden", PackedStringArray(["kn", "^wr", "mb$"]))
	assert_true(b.trips(0, "Unknown"), "contains")
	assert_true(b.trips(0, "Write"), "starts with")
	assert_false(b.trips(0, "Awry"), "only at the start")
	assert_true(b.trips(0, "Thumb"), "ends with")
	assert_false(b.trips(0, "Timber"), "only at the end")


func test_anagram() -> void:
	var b := _bank_with("anagram", PackedStringArray(["elbow"]))
	assert_true(b.trips(0, "Below"))
	assert_false(b.trips(0, "Bellow"))


func test_palindrome() -> void:
	var b := _bank_with("palindrome")
	assert_true(b.trips(0, "Kayak"))
	assert_false(b.trips(0, "Kayaks"))
	assert_false(b.trips(0, "Aa"), "too short")


func test_reverse_needs_another_word() -> void:
	var b := _bank_with("reverse", PackedStringArray(["reward"]))
	assert_true(b.trips(0, "Top"), "backwards is a bank word")
	assert_true(b.trips(0, "Drawer"), "backwards is a listed word")
	assert_false(b.trips(0, "Table"), "backwards is nothing")
	assert_false(b.trips(0, "Noon"), "a palindrome isn't a new word")


func test_y_only() -> void:
	var b := _bank_with("y_only")
	assert_true(b.trips(0, "Rhythm"))
	assert_false(b.trips(0, "Yellow"))
	assert_false(b.trips(0, "Crypto"))


func test_two_double_letters() -> void:
	var b := _bank_with("double2")
	assert_true(b.trips(0, "Coffee"))
	assert_true(b.trips(0, "Success"))
	assert_false(b.trips(0, "Apple"), "one double")
	assert_false(b.trips(0, "Committee"), "three doubles")


func test_roman() -> void:
	var b := _bank_with("roman")
	assert_true(b.trips(0, "Civic"))
	assert_false(b.trips(0, "Civils"))


func test_a_category_without_a_rule_never_trips() -> void:
	assert_false(_bank_with("palindrome").trips(1, "Kayak"))


## Every member of a rule-checked category obeys its own rule (a bad target list once passed unnoticed).
func test_real_bank_members_obey_their_rules() -> void:
	var b := Bank.load_csv(BANK)
	b.load_targets(TARGETS)
	assert_gt(b.targets.size(), 20)
	for idx: int in b.targets:
		for w in b.categories[idx]["words"]:
			assert_true(b.trips(idx, w), "%s should obey %s" % [w, b.categories[idx]["label"]])


func _ledger_bank(n: int) -> Bank:
	var b := Bank.new()
	var words := PackedStringArray()
	for i in n:
		words.append("Word%d" % i)
	b.add({"id": "c", "label": "C", "key": "c", "tier": 1, "domain": "food", "words": words})
	return b


func test_max_uses_grow_with_the_category() -> void:
	assert_eq(Ledger.new(_ledger_bank(6)).max_uses(0), 2)
	assert_eq(Ledger.new(_ledger_bank(10)).max_uses(0), 4)
	assert_eq(Ledger.new(_ledger_bank(13)).max_uses(0), 5)
	assert_eq(Ledger.new(_ledger_bank(30)).max_uses(0), 5)


func test_a_category_waits_for_its_gap_on_both_sides() -> void:
	var l := Ledger.new(_ledger_bank(13))
	l.add(100, [0], [["Word0", "Word1", "Word2", "Word3"]])
	assert_false(l.cat_ok(0, 130))
	assert_false(l.cat_ok(0, 70), "an earlier level counts too")
	assert_true(l.cat_ok(0, 160))
	assert_true(l.cat_ok(0, 40))


func test_a_category_stops_at_max_uses() -> void:
	var l := Ledger.new(_ledger_bank(6))
	l.add(100, [0], [["Word0", "Word1", "Word2", "Word3"]])
	l.add(300, [0], [["Word2", "Word3", "Word4", "Word5"]])
	assert_false(l.cat_ok(0, 500))


func test_shared_words_limit_is_looser_far_away() -> void:
	var l := Ledger.new(_ledger_bank(13))
	l.add(100, [0], [["Word0", "Word1", "Word2", "Word3"]])
	var three := PackedStringArray(["Word0", "Word1", "Word2", "Word9"])
	var two := PackedStringArray(["Word0", "Word1", "Word8", "Word9"])
	assert_true(l.words_ok(0, two, 170))
	assert_false(l.words_ok(0, three, 170), "only 70 levels on")
	assert_true(l.words_ok(0, three, 250), "150 levels on")
