## Weighted A* over the true groups. It proves a board solvable, gives par and powers Tidy up.
## Cards in the same group are interchangeable, so a state stores groups only. Plain jars are sorted to form the
## canonical key; labelled and corked jars keep their positions.
class_name Solver
extends RefCounted

const CAP := LevelData.CAPACITY


## Returns {solved, path: Array[Vector2i], cost, expanded, hit_cap, branching}. `hit_cap` means "gave up" (node
## cap, the `deadline_ms` tick, or `cancel[0]` set by another thread), never "unsolvable".
static func solve(board: BoardState, max_expanded: int = 20000, weight: float = 1.5, deadline_ms: int = 0,
		cancel: Array = []) -> Dictionary:
	var ctx := _Ctx.new(board)
	var start := ctx.encode(board)
	var states: Array[PackedByteArray] = [start]
	var g_cost := PackedInt32Array([0])
	var parent := PackedInt32Array([-1])
	var via := PackedInt32Array([-1])
	var best := {ctx.key(start): 0}
	var heap := _Heap.new()
	heap.push(weight * ctx.h(start), 0)
	var expanded := 0
	var successors := 0
	while not heap.is_empty():
		var id := heap.pop()
		var s := states[id]
		if ctx.lids(s) >= ctx.groups:
			return {
				"solved": true, "path": _path(id, parent, via), "cost": g_cost[id], "expanded": expanded,
				"hit_cap": false, "branching": float(successors) / maxi(expanded, 1),
			}
		var give_up := expanded >= max_expanded
		if not give_up and expanded & 255 == 255:
			give_up = (deadline_ms > 0 and Time.get_ticks_msec() > deadline_ms) or (not cancel.is_empty() and cancel[0])
		if give_up:
			return {"solved": false, "path": [], "cost": -1, "expanded": expanded, "hit_cap": true, "branching": 0.0}
		expanded += 1
		for mv in ctx.moves(s):
			var ns := ctx.apply(s, mv.x, mv.y)
			var k := ctx.key(ns)
			var ng := g_cost[id] + 1
			if best.has(k) and best[k] <= ng:
				continue
			best[k] = ng
			successors += 1
			states.append(ns)
			g_cost.append(ng)
			parent.append(id)
			via.append(mv.x * 64 + mv.y)
			heap.push(ng + weight * ctx.h(ns), states.size() - 1)
	return {"solved": false, "path": [], "cost": -1, "expanded": expanded, "hit_cap": false, "branching": 0.0}


static func _path(id: int, parent: PackedInt32Array, via: PackedInt32Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	while parent[id] >= 0:
		out.push_front(Vector2i(via[id] >> 6, via[id] & 63))
		id = parent[id]
	return out


## Board geometry shared by every state of one search.
class _Ctx:
	var jar_count: int
	var groups: int
	var label: PackedInt32Array
	var cork: PackedByteArray
	var has_cork := false
	var special: PackedByteArray

	func _init(b: BoardState) -> void:
		jar_count = b.jar_count()
		groups = b.group_count - b.sealed_count()  # sealed groups have left the board
		label = b.label_group.duplicate()
		cork = b.corked.duplicate()
		special.resize(jar_count)
		for j in jar_count:
			if cork[j] == 1:
				has_cork = true
			special[j] = 1 if (label[j] >= 0 or cork[j] == 1) else 0

	## Slots hold group + 1 (0 = empty), bottom to top; the last byte is 1 once corks have popped.
	func encode(b: BoardState) -> PackedByteArray:
		var s := PackedByteArray()
		s.resize(jar_count * CAP + 1)
		for j in jar_count:
			var jar := b.jars[j]
			for k in jar.size():
				s[j * CAP + k] = LevelData.group_of(jar[k]) + 1
		s[jar_count * CAP] = 0 if has_cork else 1
		return s

	func size(s: PackedByteArray, j: int) -> int:
		var n := 0
		while n < CAP and s[j * CAP + n] != 0:
			n += 1
		return n

	func corked(s: PackedByteArray, j: int) -> bool:
		return cork[j] == 1 and s[jar_count * CAP] == 0

	func lidded(s: PackedByteArray, j: int) -> bool:
		var base := j * CAP
		var g := s[base]
		return g != 0 and s[base + 1] == g and s[base + 2] == g and s[base + 3] == g

	func lids(s: PackedByteArray) -> int:
		var n := 0
		for j in jar_count:
			if lidded(s, j):
				n += 1
		return n

	func moves(s: PackedByteArray) -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		for a in jar_count:
			if corked(s, a) or lidded(s, a):
				continue
			var na := size(s, a)
			if na == 0:
				continue
			var ga := s[a * CAP + na - 1]
			var pure := true
			for k in na:
				if s[a * CAP + k] != ga:
					pure = false
					break
			var tried_plain_empty := false
			for b in jar_count:
				if b == a or corked(s, b):
					continue
				var nb := size(s, b)
				if nb >= CAP:
					continue
				if label[b] >= 0 and label[b] + 1 != ga:
					continue
				if nb == 0:
					if label[b] < 0:
						if pure or tried_plain_empty:
							continue
						tried_plain_empty = true
				elif s[b * CAP + nb - 1] != ga:
					continue
				out.append(Vector2i(a, b))
		return out

	func apply(s: PackedByteArray, a: int, b: int) -> PackedByteArray:
		var ns := s.duplicate()
		var na := size(ns, a)
		var nb := size(ns, b)
		ns[b * CAP + nb] = ns[a * CAP + na - 1]
		ns[a * CAP + na - 1] = 0
		if has_cork and ns[jar_count * CAP] == 0 and lidded(ns, b):
			ns[jar_count * CAP] = 1
		return ns

	## Two bytes per jar (special jars in place, plain jars sorted) plus the cork byte. Packed arrays hash and
	## compare by value as dictionary keys, and stay small (a hex String cost ~10x the memory on big searches).
	func key(s: PackedByteArray) -> PackedByteArray:
		var fixed := PackedInt32Array()
		var plain := PackedInt32Array()
		for j in jar_count:
			var base := j * CAP
			var code := (s[base] << 9) | (s[base + 1] << 6) | (s[base + 2] << 3) | s[base + 3]
			if special[j] == 1:
				fixed.append(code)
			else:
				plain.append(code)
		plain.sort()
		fixed.append_array(plain)
		var k := PackedByteArray()
		k.resize(fixed.size() * 2 + 1)
		for i in fixed.size():
			k[i * 2] = fixed[i] >> 8
			k[i * 2 + 1] = fixed[i] & 255
		k[fixed.size() * 2] = s[jar_count * CAP]
		return k

	## Cards above each jar's bottom run must move at least once; split runs of one group cost their smaller parts.
	func h(s: PackedByteArray) -> float:
		var cost := 0
		var run_total := {}
		var run_max := {}
		for j in jar_count:
			var n := size(s, j)
			if n == 0:
				continue
			var base := j * CAP
			var g := s[base]
			var r := 1
			while r < n and s[base + r] == g:
				r += 1
			cost += n - r
			if label[j] >= 0 and label[j] + 1 != g:
				cost += r
				continue
			run_total[g] = run_total.get(g, 0) + r
			run_max[g] = maxi(run_max.get(g, 0), r)
		for g in run_total:
			cost += run_total[g] - run_max[g]
		return float(cost)


## Binary min-heap of (priority, id).
class _Heap:
	var pri := PackedFloat32Array()
	var ids := PackedInt32Array()

	func is_empty() -> bool:
		return ids.is_empty()

	func push(p: float, id: int) -> void:
		pri.append(p)
		ids.append(id)
		var i := ids.size() - 1
		while i > 0:
			var up := (i - 1) >> 1
			if pri[up] <= pri[i]:
				break
			_swap(i, up)
			i = up

	func pop() -> int:
		var top := ids[0]
		var last := ids.size() - 1
		_swap(0, last)
		pri.resize(last)
		ids.resize(last)
		var i := 0
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < last and pri[l] < pri[m]:
				m = l
			if r < last and pri[r] < pri[m]:
				m = r
			if m == i:
				break
			_swap(i, m)
			i = m
		return top

	func _swap(a: int, b: int) -> void:
		var tp := pri[a]
		pri[a] = pri[b]
		pri[b] = tp
		var ti := ids[a]
		ids[a] = ids[b]
		ids[b] = ti
