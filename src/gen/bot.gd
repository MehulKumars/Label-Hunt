## A bot that plays like a person, not a solver. It measures how hard a level is.
## Each game it samples which words it "knows" (by category tier), falls for herrings with some pull, and keeps one
## belief per card. It plays moves by heuristic plus noise through the real Session, learning from slips, pairs and
## label steps via the same Knowledge model the player gets. The "prober" profile is an exploit bot that guesses at
## random among drops it hasn't ruled out.
class_name Bot
extends RefCounted

const PROFILES := {
	"novice": {"know": [0.9, 0.7, 0.5, 0.35], "guess": 0.45, "herring": 0.65, "noise": 1.6, "step_learn": 0.35, "undo": 0.4},
	"average": {"know": [0.96, 0.82, 0.62, 0.48], "guess": 0.5, "herring": 0.5, "noise": 1.0, "step_learn": 0.5, "undo": 0.6},
	"expert": {"know": [0.99, 0.92, 0.8, 0.68], "guess": 0.55, "herring": 0.3, "noise": 0.4, "step_learn": 0.7, "undo": 0.8},
	"prober": {"random": true},
}
const MAX_ACTIONS := 400
## The game's +Jar limit (see the play screen).
const MAX_JARS := 9
const UNSURE := -1

var level: LevelData
var profile: Dictionary
var rng: RandomNumberGenerator
var s: Session
var belief: PackedInt32Array
var sure: PackedByteArray
## Beliefs about frosted words wait here until the word is first seen (a person can't read a frosted card).
var _frosted := {}
var _last := Vector2i(-1, -1)
var _known_at_move := -1
var dead_ends := 0
var trace := false
## Board states already visited (to avoid cycles) and states we backed out of.
var _seen := {}
var _tabu := {}


## Plays one game. Returns {won, slips, moves, undos, dead_ends, after_known, secs}.
static func play(lvl: LevelData, prof: String, game_seed: int, rules: Dictionary = {}) -> Dictionary:
	var b := Bot.new()
	b.level = lvl
	b.profile = PROFILES[prof]
	b.rng = RandomNumberGenerator.new()
	b.rng.seed = game_seed
	return b._run(rules)


func _run(rules: Dictionary) -> Dictionary:
	s = Session.new(level, rules)
	_sample_beliefs()
	var think := 0.0
	var actions := 0
	while not s.is_over() and actions < MAX_ACTIONS:
		actions += 1
		_absorb_knowledge()
		if _known_at_move < 0 and _beliefs_right():
			_known_at_move = s.moves
		_seen[_key()] = true
		var mv := _choose()
		think += 1.2 + 0.15 * level.group_count()
		if mv == Vector2i(-1, -1):
			# Dead end: a person either takes a guess or backs up. Backing up marks the move as tried.
			dead_ends += 1
			var guess := _probe(true)
			if guess != Vector2i(-1, -1) and (rng.randf() < 0.6 or not s.can_undo()):
				mv = guess
			elif s.can_undo():
				_tabu[_key()] = true
				s.undo()
				continue
			elif s.jars_added == 0 and s.board.jar_count() < MAX_JARS:
				# Stuck past the last lid: the free +Jar is what a person reaches for.
				s.add_jar()
				continue
			else:
				mv = _probe(false)
				if mv == Vector2i(-1, -1):
					break
		var card := s.board.top(mv.x)
		var g_before := s.know.step.duplicate()
		var r := s.try_move(mv.x, mv.y)
		if trace:
			print("%3d %-10s -> jar%d  %s  slips=%d" % [actions, level.word(card), mv.y, Session.Result.keys()[r["result"]], s.slips])
		_last = mv
		if r["result"] == Session.Result.SLIP:
			think += 2.0
		_learn_from_steps(g_before)
	var after := s.moves - _known_at_move if _known_at_move >= 0 else 0
	return {
		"won": s.won, "slips": s.slips, "moves": s.moves, "undos": s.undos, "dead_ends": dead_ends,
		"after_known": after, "secs": think + s.moves * 1.1,
	}


# --- beliefs ------------------------------------------------------------------------------------------------------

func _sample_beliefs() -> void:
	var n := level.card_count()
	belief.resize(n)
	sure.resize(n)
	if profile.get("random", false):
		belief.fill(UNSURE)
		return
	var know: Array = profile["know"]
	for c in n:
		var g := LevelData.group_of(c)
		var tier := clampi(int(level.groups[g].get("tier", 1)), 1, 4)
		var knows := rng.randf() < float(know[tier - 1])
		var alts := level.also.get(c, PackedInt32Array()) as PackedInt32Array
		if not alts.is_empty() and rng.randf() < float(profile["herring"]) * (0.6 if knows else 1.0):
			belief[c] = alts[rng.randi() % alts.size()]
		elif knows:
			belief[c] = g
			sure[c] = 1
		elif rng.randf() < float(profile["guess"]):
			belief[c] = g
		else:
			belief[c] = _other_group(g)
	_cap_groups()
	for c in n:
		if s.know.seen[c] == 0:
			_frosted[c] = Vector2i(belief[c], sure[c])
			belief[c] = UNSURE
			sure[c] = 0


## A person expects four cards per group: unsure extras beyond four become "no idea".
func _cap_groups() -> void:
	for g in level.group_count():
		var members: Array[int] = []
		for c in belief.size():
			if belief[c] == g:
				members.append(c)
		if members.size() <= LevelData.CAPACITY:
			continue
		Dealer._shuffle_array(members, rng)
		members.sort_custom(func(a: int, b: int) -> bool: return sure[a] > sure[b])
		for i in range(LevelData.CAPACITY, members.size()):
			if sure[members[i]] == 0:
				belief[members[i]] = UNSURE


func _other_group(g: int) -> int:
	var o := rng.randi_range(0, level.group_count() - 2)
	return o + 1 if o >= g else o


## Proven facts override guesses: tagged classes are certain, proven pairs share a belief.
func _absorb_knowledge() -> void:
	for c in _frosted.keys():
		if s.know.seen[c] == 1:
			var v: Vector2i = _frosted[c]
			belief[c] = v.x
			sure[c] = v.y
			_frosted.erase(c)
	for c in belief.size():
		var t := s.know.class_tag(c)
		if t >= 0:
			belief[c] = t
			sure[c] = 1
	for c in belief.size():
		if sure[c] == 1:
			continue
		var r := s.know.find(c)
		for o in belief.size():
			if o != c and s.know.find(o) == r and sure[o] == 1:
				belief[c] = belief[o]
				sure[c] = 1
				break


## A label hint jogs memory: unknown cards of that group may click into place.
func _learn_from_steps(before: PackedInt32Array) -> void:
	if profile.get("random", false):
		return
	for g in level.group_count():
		if s.know.step[g] > before[g] and s.know.step[g] < Knowledge.FULL_STEP:
			for c in belief.size():
				if LevelData.group_of(c) == g and sure[c] == 0 and rng.randf() < float(profile["step_learn"]):
					belief[c] = g
					sure[c] = 1




# --- moves --------------------------------------------------------------------------------------------------------

func _choose() -> Vector2i:
	if profile.get("random", false):
		return _probe(false)
	var b := s.board
	var best := Vector2i(-1, -1)
	var best_score := 0.5
	var empties := 0
	for j in b.jar_count():
		if b.size(j) == 0 and not b.is_closed(j) and b.label_group[j] < 0:
			empties += 1
	for a in b.jar_count():
		if not b.can_take(a):
			continue
		var c := b.top(a)
		var below := b.jars[a][b.size(a) - 2] if b.size(a) > 1 else -1
		var in_run := below >= 0 and belief[below] == belief[c] and belief[c] != UNSURE
		for t in b.jar_count():
			if t == a or b.is_closed(t) or b.is_full(t) or s.is_proven_wrong(c, t):
				continue
			var score := _score(a, t, c, below, in_run, empties)
			if score == -INF:
				continue
			var k := _key_after(a, t)
			if _tabu.has(k):
				continue
			if _seen.has(k):
				score -= 6.0
			score += rng.randfn(0.0, float(profile["noise"]))
			if score > best_score:
				best_score = score
				best = Vector2i(a, t)
	return best


func _score(a: int, t: int, c: int, below: int, in_run: bool, empties: int) -> float:
	var b := s.board
	var lg := b.label_group[t]
	if lg >= 0:
		return 7.0 if belief[c] == lg else -INF
	if b.size(t) == 0:
		if b.size(a) == 1 or _pure(a):
			return -INF
		# Digging: worth it when the card underneath has a home waiting elsewhere.
		var v := 0.8
		if below >= 0 and belief[below] != UNSURE and belief[below] != belief[c] and _top_with_belief(belief[below], a) >= 0:
			v += 2.5
		if in_run:
			v -= 1.0
		if empties <= 1:
			v -= 1.5
		return v
	var under := b.top(t)
	if belief[c] == UNSURE or belief[c] != belief[under]:
		return -INF
	var run := _run_len(t)
	var v := 5.0 + 1.5 * run + (2.0 if sure[c] == 1 and sure[under] == 1 else 0.0)
	if _pure(t):
		v += 1.5
	if in_run and _run_len(a) >= run:
		v -= 4.0 # breaking a run to join a shorter one goes backwards
	return v


func _pure(j: int) -> bool:
	var jar := s.board.jars[j]
	var g := belief[jar[0]]
	if g == UNSURE:
		return false
	for c in jar:
		if belief[c] != g:
			return false
	return true


func _top_with_belief(g: int, except: int) -> int:
	for j in s.board.jar_count():
		if j != except and not s.board.is_full(j) and not s.board.is_closed(j):
			var t := s.board.top(j)
			if t >= 0 and belief[t] == g:
				return j
	return -1


func _run_len(j: int) -> int:
	var jar := s.board.jars[j]
	var n := 1
	var g := belief[jar[jar.size() - 1]]
	for k in range(jar.size() - 2, -1, -1):
		if belief[jar[k]] != g or g == UNSURE:
			break
		n += 1
	return n


## A guess among drops not yet ruled out. A person guesses onto a top card when one of the two is a card they're
## unsure about; they don't drop a card they're sure of onto a top they're sure is different.
func _probe(plausible_only: bool) -> Vector2i:
	var b := s.board
	var options: Array[Vector2i] = []
	for a in b.jar_count():
		if not b.can_take(a):
			continue
		var c := b.top(a)
		for t in b.jar_count():
			if t == a or b.is_closed(t) or b.is_full(t) or s.is_proven_wrong(c, t):
				continue
			if b.size(t) == 0:
				if plausible_only or (b.size(a) == 1 and b.label_group[t] < 0):
					continue
			elif plausible_only:
				var under := b.top(t)
				if sure[c] == 1 and sure[under] == 1 and belief[c] != belief[under]:
					continue
			if _tabu.has(_key_after(a, t)):
				continue
			options.append(Vector2i(a, t))
	if options.is_empty():
		return Vector2i(-1, -1)
	return options[rng.randi() % options.size()]


func _key() -> String:
	var parts := PackedStringArray()
	for jar in s.board.jars:
		parts.append(str(jar))
	return "|".join(parts)


func _key_after(a: int, t: int) -> String:
	s.board.move(a, t)
	var k := _key()
	s.board.move(t, a)
	return k


## The bot's "aha": every card still in play is believed in its true group.
func _beliefs_right() -> bool:
	for j in s.board.jar_count():
		if s.board.lidded[j] == 1:
			continue
		for c in s.board.jars[j]:
			if belief[c] != LevelData.group_of(c):
				return false
	return true
