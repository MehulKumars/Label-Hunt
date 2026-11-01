## Random deals with fairness constraints, proven solvable by the solver.
class_name Dealer
extends RefCounted

const CAP := LevelData.CAPACITY


## Deals every card into the first group_count jars (4 each) and leaves `empties` empty jars after them.
## Constraints: no two same-group cards touch in a jar, no jar holds 3+ of one group, no jar is pre-solved.
## Returns jars (bottom -> top) or [] if no valid deal was found.
static func deal(group_count: int, empties: int, rng: RandomNumberGenerator, attempts: int = 2000) -> Array[PackedInt32Array]:
	var cards := PackedInt32Array()
	for c in group_count * CAP:
		cards.append(c)
	for _attempt in attempts:
		_shuffle(cards, rng)
		var jars: Array[PackedInt32Array] = []
		var ok := true
		for j in group_count:
			var jar := cards.slice(j * CAP, j * CAP + CAP)
			if not _jar_ok(jar):
				ok = false
				break
			jars.append(jar)
		if not ok:
			continue
		for e in empties:
			jars.append(PackedInt32Array())
		return jars
	return []


## Deals `lvl` in place from a deal spec, with its special jars, until the solver proves the deal:
## {empties = 2, frost = k (the bottom k cards of every filled jar start frosted), labelled = n (n of the empty jars
## come printed with a group's label), corked = n (n filled jars start corked)}. Returns false if no proven deal.
static func deal_spec(lvl: LevelData, spec: Dictionary, rng: RandomNumberGenerator, solver_cap: int = 200000) -> bool:
	var groups := lvl.group_count()
	var empties := int(spec.get("empties", 2))
	var n_label := mini(int(spec.get("labelled", 0)), empties)
	var n_cork := mini(int(spec.get("corked", 0)), groups - 1)
	var frost_k := int(spec.get("frost", 0))
	for _attempt in 50:
		var jars := deal(groups, empties, rng)
		if jars.is_empty():
			return false
		lvl.jars = jars
		lvl.labelled = {}
		var label_groups := range(groups)
		_shuffle_array(label_groups, rng)
		for k in n_label:
			lvl.labelled[groups + empties - 1 - k] = label_groups[k]
		lvl.corked = PackedInt32Array()
		var cork_jars := range(groups)
		_shuffle_array(cork_jars, rng)
		for k in n_cork:
			lvl.corked.append(cork_jars[k])
		lvl.frost = PackedInt32Array()
		for j in groups:
			for k in mini(frost_k, jars[j].size() - 1):
				lvl.frost.append(jars[j][k])
		if Solver.solve(BoardState.from_level(lvl), solver_cap)["solved"]:
			return true
	return false


static func _shuffle_array(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


static func _jar_ok(jar: PackedInt32Array) -> bool:
	var counts := {}
	for k in jar.size():
		var g := LevelData.group_of(jar[k])
		counts[g] = counts.get(g, 0) + 1
		if counts[g] >= 3:
			return false
		if k > 0 and LevelData.group_of(jar[k - 1]) == g:
			return false
	return true


## True if no two same-group cards touch anywhere (the "every pair is the player's work" rule).
static func no_adjacent_pairs(jars: Array[PackedInt32Array]) -> bool:
	for jar in jars:
		for k in range(1, jar.size()):
			if LevelData.group_of(jar[k - 1]) == LevelData.group_of(jar[k]):
				return false
	return true


static func _shuffle(a: PackedInt32Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := a[i]
		a[i] = a[j]
		a[j] = t
