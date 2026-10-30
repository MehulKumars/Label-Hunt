## What the player has proven: which cards share a group, which don't, and which group slot a card is tagged to.
## The single source for free refusals, the stuck notice, Tidy up and the bot's learning.
class_name Knowledge
extends RefCounted

const FULL_STEP := 3
const MAX_HINT_STEP := 2

var parent: PackedInt32Array = PackedInt32Array()
## Tag (group index or -1), valid at class roots.
var tag: PackedInt32Array = PackedInt32Array()
var class_size: PackedInt32Array = PackedInt32Array()
## Pairs of cards proven to be in different groups (checked through their classes).
var diff_pairs: Array[Vector2i] = []
## Label reveal step per group: 0 blank, 1 context + key length, 2 key initial, 3 full (lidded).
var step: PackedInt32Array = PackedInt32Array()
var paired_once: PackedByteArray = PackedByteArray()
## Frosted cards stay seen once uncovered, even after undo.
var seen: PackedByteArray = PackedByteArray()


func _init(card_count: int = 0, group_count: int = 0) -> void:
	parent.resize(card_count)
	tag.resize(card_count)
	class_size.resize(card_count)
	seen.resize(card_count)
	for c in card_count:
		parent[c] = c
		tag[c] = -1
		class_size[c] = 1
		seen[c] = 1
	step.resize(group_count)
	paired_once.resize(group_count)


func find(c: int) -> int:
	var r := c
	while parent[r] != r:
		r = parent[r]
	while parent[c] != r:
		var next := parent[c]
		parent[c] = r
		c = next
	return r


func union(a: int, b: int) -> int:
	var ra := find(a)
	var rb := find(b)
	if ra == rb:
		return ra
	if class_size[ra] < class_size[rb]:
		var t := ra
		ra = rb
		rb = t
	parent[rb] = ra
	class_size[ra] += class_size[rb]
	if tag[ra] < 0:
		tag[ra] = tag[rb]
	return ra


func class_tag(c: int) -> int:
	return tag[find(c)]


func class_of_size(c: int) -> int:
	return class_size[find(c)]


## Links c's class to group slot g, merging it with any class already linked to g.
func set_tag(c: int, g: int) -> void:
	var r := find(c)
	tag[r] = g
	for other in parent.size():
		if find(other) != r and class_tag(other) == g:
			r = union(r, other)
	tag[find(c)] = g


func add_diff(a: int, b: int) -> void:
	diff_pairs.append(Vector2i(a, b))


func proven_same(a: int, b: int) -> bool:
	if find(a) == find(b):
		return true
	var ta := class_tag(a)
	return ta >= 0 and ta == class_tag(b)


func proven_diff(a: int, b: int) -> bool:
	var ta := class_tag(a)
	var tb := class_tag(b)
	if ta >= 0 and tb >= 0 and ta != tb:
		return true
	var ra := find(a)
	var rb := find(b)
	if ra == rb:
		return false
	for p in diff_pairs:
		var px := find(p.x)
		var py := find(p.y)
		if (px == ra and py == rb) or (px == rb and py == ra):
			return true
	return false


## True when the board proves card c can't belong to group g.
func proven_not_in(c: int, g: int) -> bool:
	var t := class_tag(c)
	if t >= 0:
		return t != g
	for other in parent.size():
		if class_tag(other) == g and proven_diff(c, other):
			return true
	return false


## Moves group g's label one hint step on (never past the last hint). Returns true if it changed.
func advance_step(g: int) -> bool:
	if step[g] >= MAX_HINT_STEP:
		return false
	step[g] += 1
	return true


func to_dict() -> Dictionary:
	var pairs: Array = []
	for p in diff_pairs:
		pairs.append([p.x, p.y])
	return {
		"parent": Array(parent), "tag": Array(tag), "size": Array(class_size), "diff": pairs,
		"step": Array(step), "paired": Array(paired_once), "seen": Array(seen),
	}


static func from_dict(d: Dictionary) -> Knowledge:
	var k := Knowledge.new()
	k.parent = _ints(d["parent"])
	k.tag = _ints(d["tag"])
	k.class_size = _ints(d["size"])
	for p in d["diff"]:
		k.diff_pairs.append(Vector2i(int(p[0]), int(p[1])))
	k.step = _ints(d["step"])
	k.paired_once = _bytes(d["paired"])
	k.seen = _bytes(d["seen"])
	return k


func copy() -> Knowledge:
	return Knowledge.from_dict(to_dict())


static func _ints(a: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for v in a:
		out.append(int(v))
	return out


static func _bytes(a: Array) -> PackedByteArray:
	var out := PackedByteArray()
	for v in a:
		out.append(int(v))
	return out
