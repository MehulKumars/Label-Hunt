## Picks the next good move for a Hint, from the hidden truth. Cheap rules first, the solver only when needed:
## 1. a move that finishes a lid; 2. a move onto a jar holding only that card's group (never wrong, no search);
## 3. the first step of a solver path, within a time budget. If none (the board is lost or the search gave up), the
## hint is "Undo a few moves" and costs nothing. Pure: runs on a worker thread with a board copy.
class_name Advisor
extends RefCounted

const SOLVER_CAP := 30000
const SOLVER_WEIGHT := 3.0


## {move: Vector2i (-1, -1 = none), kind: "lid" | "pure" | "solver" | "none", path: Array[Vector2i]}
static func next_move(board: BoardState, budget_ms: int = 150, cancel: Array = []) -> Dictionary:
	var lid := _lid_move(board)
	if lid.x >= 0:
		return {"move": lid, "kind": "lid", "path": [lid]}
	var pure := _pure_move(board)
	if pure.x >= 0:
		return {"move": pure, "kind": "pure", "path": [pure]}
	var deadline := Time.get_ticks_msec() + budget_ms if budget_ms > 0 else 0
	var res := Solver.solve(board, SOLVER_CAP, SOLVER_WEIGHT, deadline, cancel)
	if res["solved"] and not (res["path"] as Array).is_empty():
		return {"move": res["path"][0], "kind": "solver", "path": res["path"]}
	return {"move": Vector2i(-1, -1), "kind": "none", "path": []}


## A stable text key of the jars, to tell whether the board changed since a hint was computed.
static func board_key(board: BoardState) -> String:
	var parts := PackedStringArray()
	for jar in board.jars:
		parts.append(str(jar))
	return "|".join(parts) + "#" + str(board.sealed)


static func _lid_move(b: BoardState) -> Vector2i:
	for a in b.jar_count():
		if not b.can_take(a):
			continue
		var c := b.top(a)
		var g := LevelData.group_of(c)
		for t in b.jar_count():
			if t == a or b.size(t) != LevelData.CAPACITY - 1 or b.drop_check(c, t) != BoardState.Drop.OK:
				continue
			if _all_group(b, t, g):
				return Vector2i(a, t)
	return Vector2i(-1, -1)


## Onto the longest jar that holds only this card's group, unless the card already sits in an equal or longer run.
static func _pure_move(b: BoardState) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_len := 0
	for a in b.jar_count():
		if not b.can_take(a):
			continue
		var c := b.top(a)
		var g := LevelData.group_of(c)
		var own := _run(b, a)
		for t in b.jar_count():
			if t == a or b.size(t) == 0 or b.drop_check(c, t) != BoardState.Drop.OK or not _all_group(b, t, g):
				continue
			if _all_group(b, a, g) and b.size(a) >= b.size(t):
				continue
			if own > 1 and own >= b.size(t):
				continue
			if b.size(t) > best_len:
				best_len = b.size(t)
				best = Vector2i(a, t)
	return best


static func _all_group(b: BoardState, j: int, g: int) -> bool:
	if b.size(j) == 0:
		return false
	for c in b.jars[j]:
		if LevelData.group_of(c) != g:
			return false
	return true


## How many cards of the top card's group sit together at the top of jar j.
static func _run(b: BoardState, j: int) -> int:
	var jar := b.jars[j]
	var g := LevelData.group_of(jar[jar.size() - 1])
	var n := 0
	for k in range(jar.size() - 1, -1, -1):
		if LevelData.group_of(jar[k]) != g:
			break
		n += 1
	return n
