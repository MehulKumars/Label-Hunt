## One attempt at a level: applies the rules to moves, slips, hints, undo, lids and seals, and reports what happened
## as events. The UI animates the events; the bot reads them. Knows the hidden truth through BoardState.
## Every action that changes the attempt is kept in `log`, so a killed app can replay the attempt exactly (`replay`).
class_name Session
extends RefCounted

enum Result { MOVED, SLIP, REFUSE_FULL, REFUSE_CLOSED, REFUSE_PROVEN, NOOP }

## Rule toggles exposed in the dev menu for M1 playtests.
const DEFAULT_RULES := {
	"tag_on_slip": true,
	"pair_reveal": true,
	"pour": false,
	"mode": "budget", # "budget" (fail when slips run out) or "stars" (no fail; stars from slips)
}

var level: LevelData
var board: BoardState
var know: Knowledge
var rules: Dictionary
var budget: int = 0
var slips: int = 0
var moves: int = 0
var undos: int = 0
var hints: int = 0
var completes: int = 0
var jars_added: int = 0
var continues: int = 0
var won: bool = false
var lost: bool = false
## Undo snapshots since the last lid or seal.
var history: Array[Dictionary] = []
## [moved word, target word or "#label"] per slip, for the playtest log.
var slip_log: Array = []
## Replayable actions: ["m", from, to] (a move or slip), ["u"], ["h", card], ["j"], ["c", group], ["s", slips].
var log: Array = []


func _init(lvl: LevelData, rule_overrides: Dictionary = {}) -> void:
	level = lvl
	rules = DEFAULT_RULES.duplicate()
	rules.merge(rule_overrides, true)
	board = BoardState.from_level(lvl)
	know = Knowledge.new(lvl.card_count(), lvl.group_count())
	budget = lvl.budget
	for c in lvl.frost:
		know.seen[c] = 0
	for j in lvl.labelled:
		know.step[lvl.labelled[j]] = Knowledge.FULL_STEP
	_mark_seen([])


func has_budget() -> bool:
	return rules["mode"] == "budget" and budget > 0


func slips_left() -> int:
	return maxi(budget - slips, 0) if has_budget() else -1


func is_over() -> bool:
	return won or lost


func try_move(from: int, to: int) -> Dictionary:
	var ev: Array[Dictionary] = []
	if is_over() or from == to or not board.can_take(from):
		return {"result": Result.NOOP, "events": ev}
	var card := board.top(from)
	if board.is_closed(to):
		return {"result": Result.REFUSE_CLOSED, "events": ev}
	if board.is_full(to):
		return {"result": Result.REFUSE_FULL, "events": ev}
	if is_proven_wrong(card, to):
		ev.append({"type": "refuse", "card": card, "to": to})
		return {"result": Result.REFUSE_PROVEN, "events": ev}
	log.append(["m", from, to])
	if board.drop_check(card, to) == BoardState.Drop.WRONG:
		_slip(card, to, ev)
		return {"result": Result.SLIP, "events": ev}
	_push_history()
	_move(from, to, ev)
	if rules["pour"]:
		while not is_over() and board.can_take(from) and not board.is_full(to) and not board.is_closed(to) \
				and know.proven_same(board.top(from), card):
			_move(from, to, ev)
	return {"result": Result.MOVED, "events": ev}


## True when the board already proves this drop wrong (so it is refused for free).
func is_proven_wrong(card: int, to: int) -> bool:
	var lg := board.label_group[to]
	if lg >= 0 and know.proven_not_in(card, lg):
		return true
	var t := board.top(to)
	return t >= 0 and know.proven_diff(card, t)


## A Hint was shown for `card`: tags only that card (the label moves on at most one step); the move it points at
## builds the pair when the player makes it.
func hint(card: int) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	if is_over() or card < 0 or know.seen[card] == 0:
		return ev
	hints += 1
	log.append(["h", card])
	if know.class_tag(card) < 0:
		_reveal(card, ev)
	return ev


## The Complete booster: group g's cards leave their jars (buried ones too) and the group is sealed with its full
## label. Like a lid it is an undo barrier and pops corks.
func complete(g: int) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	if is_over() or g < 0 or g >= board.group_count or board.is_solved(g):
		return ev
	completes += 1
	log.append(["c", g])
	var cards := board.seal(g)
	var first := g * LevelData.CAPACITY
	for k in LevelData.CAPACITY:
		know.union(first + k, first)
		know.seen[first + k] = 1
	know.set_tag(first, g)
	know.step[g] = Knowledge.FULL_STEP
	ev.append({"type": "seal", "group": g, "cards": cards})
	history.clear()
	var opened := board.uncork_all()
	if not opened.is_empty():
		ev.append({"type": "uncork", "jars": opened})
	_mark_seen(ev)
	if board.is_won():
		won = true
		ev.append({"type": "won"})
	return ev


func add_jar() -> Array[Dictionary]:
	var j := board.add_empty_jar()
	jars_added += 1
	log.append(["j"])
	for snap in history:
		(snap["jars"] as Array).append(PackedInt32Array())
	return [{"type": "jar_added", "jar": j}]


func can_undo() -> bool:
	return not is_over() and not history.is_empty()


func undo() -> Array[Dictionary]:
	if not can_undo():
		return []
	var snap: Dictionary = history.pop_back()
	var restored: Array[PackedInt32Array] = []
	for jar in snap["jars"]:
		restored.append((jar as PackedInt32Array).duplicate())
	board.jars = restored
	undos += 1
	log.append(["u"])
	return [{"type": "undo"}]


## Adds slips after a loss (Continue) and resumes play.
func continue_play(extra: int = 2) -> void:
	continues += 1
	grant_slips(extra)


## More slips in the budget (Continue, or the assist after two fails).
func grant_slips(extra: int) -> void:
	budget += extra
	log.append(["s", extra])
	if not has_budget() or slips < budget:
		lost = false


## Rebuilds an attempt from its action log. Returns null if any step doesn't apply (a changed level, a tampered
## save): the caller then starts the level fresh.
static func replay(lvl: LevelData, rule_overrides: Dictionary, actions: Array) -> Session:
	var s := Session.new(lvl, rule_overrides)
	for a: Variant in actions:
		if not a is Array or (a as Array).is_empty():
			return null
		var act: Array = a
		var kind := str(act[0])
		var ok := true
		match kind:
			"m":
				ok = act.size() == 3 and _jar_ok(s, act[1]) and _jar_ok(s, act[2]) \
					and int(s.try_move(int(act[1]), int(act[2]))["result"]) in [Result.MOVED, Result.SLIP]
			"u":
				ok = s.can_undo() and not s.undo().is_empty()
			"h":
				ok = act.size() == 2 and int(act[1]) >= 0 and int(act[1]) < lvl.card_count() and not s.is_over()
				if ok:
					s.hint(int(act[1]))
			"j":
				ok = s.board.jar_count() < 9
				if ok:
					s.add_jar()
			"c":
				ok = act.size() == 2 and not s.complete(int(act[1])).is_empty()
			"s":
				ok = act.size() == 2 and int(act[1]) > 0 and int(act[1]) <= 4
				if ok:
					s.grant_slips(int(act[1]))
			_:
				ok = false
		if not ok:
			return null
	return s


static func _jar_ok(s: Session, j: Variant) -> bool:
	return (j is int or j is float) and int(j) >= 0 and int(j) < s.board.jar_count()


## No safe move left, judged only from what the player can know (never from the hidden truth).
func is_stuck() -> bool:
	if is_over():
		return false
	for a in board.jar_count():
		if not board.can_take(a):
			continue
		var c := board.top(a)
		for b in board.jar_count():
			if b == a or board.is_closed(b) or board.is_full(b):
				continue
			if board.size(b) == 0:
				if board.label_group[b] >= 0:
					if not know.proven_not_in(c, board.label_group[b]):
						return false
				elif board.size(a) > 1 or board.label_group[a] >= 0:
					return false
			elif not know.proven_diff(c, board.top(b)):
				return false
	return true


## Every card left on the board has a group the player has proven, so Tidy up may finish the level.
func all_known() -> bool:
	if is_over():
		return false
	var known_groups := {}
	var unknown_cards := 0
	var unknown_roots := {}
	for j in board.jar_count():
		if board.lidded[j] == 1:
			continue
		for c in board.jars[j]:
			if know.seen[c] == 0:
				return false
			var t := know.class_tag(c)
			if t >= 0:
				known_groups[t] = true
			elif know.class_of_size(c) < LevelData.CAPACITY:
				unknown_cards += 1
				unknown_roots[know.find(c)] = true
	if unknown_cards == 0:
		return true
	var open_groups := board.group_count - board.lid_count() - board.sealed_count()
	# Exactly one unlidded group lacks a proven class: the leftover cards must be it.
	return unknown_cards == LevelData.CAPACITY and open_groups - known_groups.size() == 1


func stars() -> int:
	if slips <= 1:
		return 3
	return 2 if slips <= 3 else 1


func _slip(card: int, to: int, ev: Array[Dictionary]) -> void:
	slips += 1
	var t := board.top(to)
	if t >= 0:
		know.add_diff(card, t)
	ev.append({"type": "slip", "card": card, "to": to, "target": t})
	slip_log.append([level.word(card), level.word(t) if t >= 0 else "#label"])
	if rules["tag_on_slip"]:
		_reveal(card, ev)
	if has_budget() and slips >= budget:
		lost = true
		ev.append({"type": "lost"})


func _reveal(card: int, ev: Array[Dictionary]) -> void:
	var g := LevelData.group_of(card)
	know.set_tag(card, g)
	ev.append({"type": "tag", "card": card, "group": g})
	if know.advance_step(g):
		ev.append({"type": "step", "group": g, "step": know.step[g]})


func _move(from: int, to: int, ev: Array[Dictionary]) -> void:
	var under := board.top(to)
	var card := board.move(from, to)
	var g := LevelData.group_of(card)
	moves += 1
	ev.append({"type": "move", "from": from, "to": to, "card": card})
	if under >= 0:
		know.union(card, under)
		if rules["pair_reveal"] and know.paired_once[g] == 0:
			know.paired_once[g] = 1
			_reveal(card, ev)
	elif board.label_group[to] >= 0:
		know.set_tag(card, g)
	if board.check_lid(to):
		for c in board.jars[to]:
			know.union(c, card)
		know.set_tag(card, g)
		know.step[g] = Knowledge.FULL_STEP
		ev.append({"type": "lid", "jar": to, "group": g})
		history.clear()
		var opened := board.uncork_all()
		if not opened.is_empty():
			ev.append({"type": "uncork", "jars": opened})
	_mark_seen(ev)
	if board.is_won():
		won = true
		ev.append({"type": "won"})


func _mark_seen(ev: Array) -> void:
	for j in board.jar_count():
		var t := board.top(j)
		if t >= 0 and know.seen[t] == 0:
			know.seen[t] = 1
			ev.append({"type": "seen", "card": t})


func _push_history() -> void:
	var jars: Array = []
	for jar in board.jars:
		jars.append(jar.duplicate())
	history.append({"jars": jars})
