## The physical board: what is in each jar, and which jars are lidded, corked or labelled.
## Knows the hidden truth (card groups); the player's view lives in Knowledge.
class_name BoardState
extends RefCounted

enum Drop { OK, FULL, CLOSED, WRONG }

const CAPACITY := LevelData.CAPACITY

var jars: Array[PackedInt32Array] = []
var lidded: PackedByteArray = PackedByteArray()
var corked: PackedByteArray = PackedByteArray()
## Group printed on the jar, or -1.
var label_group: PackedInt32Array = PackedInt32Array()
var group_count: int = 0
## Per group: 1 once the Complete booster has sealed it (its cards left the board).
var sealed: PackedByteArray = PackedByteArray()


static func from_level(level: LevelData) -> BoardState:
	var b := BoardState.new()
	b.group_count = level.group_count()
	b.sealed.resize(b.group_count)
	for jar in level.jars:
		b.jars.append(jar.duplicate())
	b.lidded.resize(b.jars.size())
	b.corked.resize(b.jars.size())
	b.label_group.resize(b.jars.size())
	b.label_group.fill(-1)
	for j in level.corked:
		b.corked[j] = 1
	for j in level.labelled:
		b.label_group[j] = level.labelled[j]
	return b


func copy() -> BoardState:
	var b := BoardState.new()
	b.group_count = group_count
	for jar in jars:
		b.jars.append(jar.duplicate())
	b.lidded = lidded.duplicate()
	b.corked = corked.duplicate()
	b.label_group = label_group.duplicate()
	b.sealed = sealed.duplicate()
	return b


## Takes group g's cards out of every jar, buried ones too, and seals the group. Returns the cards with where they
## were: [{card, jar, index}] (index before any card left that jar).
func seal(g: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for j in jars.size():
		var jar := jars[j]
		for k in range(jar.size() - 1, -1, -1):
			if LevelData.group_of(jar[k]) == g:
				out.append({"card": jar[k], "jar": j, "index": k})
				jar.remove_at(k)
		jars[j] = jar
	sealed[g] = 1
	return out


func sealed_count() -> int:
	return sealed.count(1)


## Lidded in a jar or sealed by Complete.
func is_solved(g: int) -> bool:
	if sealed[g] == 1:
		return true
	for j in jars.size():
		if lidded[j] == 1 and LevelData.group_of(jars[j][0]) == g:
			return true
	return false


func jar_count() -> int:
	return jars.size()


func size(j: int) -> int:
	return jars[j].size()


func top(j: int) -> int:
	var jar := jars[j]
	return jar[jar.size() - 1] if jar.size() > 0 else -1


func is_full(j: int) -> bool:
	return jars[j].size() >= CAPACITY


func is_closed(j: int) -> bool:
	return lidded[j] == 1 or corked[j] == 1


func can_take(j: int) -> bool:
	return not is_closed(j) and jars[j].size() > 0


## Checks a drop against the hidden truth.
func drop_check(card: int, to: int) -> Drop:
	if is_closed(to):
		return Drop.CLOSED
	if is_full(to):
		return Drop.FULL
	var g := LevelData.group_of(card)
	if label_group[to] >= 0 and label_group[to] != g:
		return Drop.WRONG
	var t := top(to)
	if t >= 0 and LevelData.group_of(t) != g:
		return Drop.WRONG
	return Drop.OK


func move(from: int, to: int) -> int:
	var src := jars[from]
	var card := src[src.size() - 1]
	src.resize(src.size() - 1)
	jars[from] = src
	var dst := jars[to]
	dst.append(card)
	jars[to] = dst
	return card


## True if jar j just became a complete group (and marks it lidded).
func check_lid(j: int) -> bool:
	if lidded[j] == 1 or jars[j].size() != CAPACITY:
		return false
	var g := LevelData.group_of(jars[j][0])
	for c in jars[j]:
		if LevelData.group_of(c) != g:
			return false
	lidded[j] = 1
	return true


## Unseals every corked jar; returns the jars that opened.
func uncork_all() -> PackedInt32Array:
	var opened := PackedInt32Array()
	for j in corked.size():
		if corked[j] == 1:
			corked[j] = 0
			opened.append(j)
	return opened


func lid_count() -> int:
	return lidded.count(1)


func is_won() -> bool:
	return lid_count() + sealed_count() >= group_count


func add_empty_jar() -> int:
	jars.append(PackedInt32Array())
	lidded.append(0)
	corked.append(0)
	label_group.append(-1)
	return jars.size() - 1
