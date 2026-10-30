## Counts the ways a level's cards can be split into its groups of 4, using every plausible membership.
## A fair level has exactly one: then every herring's home can be deduced.
class_name ExactCover
extends RefCounted


static func count(level: LevelData, cap: int = 2) -> int:
	var cards := level.card_count()
	var options: Array[PackedInt32Array] = []
	for c in cards:
		options.append(level.memberships(c))
	# Most constrained cards first keeps the search tiny.
	var order := range(cards)
	order.sort_custom(func(a, b): return options[a].size() < options[b].size())
	var room := PackedInt32Array()
	room.resize(level.group_count())
	room.fill(LevelData.CAPACITY)
	return _count(order, 0, options, room, cap)


static func _count(order: Array, i: int, options: Array[PackedInt32Array], room: PackedInt32Array, cap: int) -> int:
	if i == order.size():
		return 1
	var total := 0
	for g in options[order[i]]:
		if room[g] == 0:
			continue
		room[g] -= 1
		total += _count(order, i + 1, options, room, cap)
		room[g] += 1
		if total >= cap:
			break
	return total
