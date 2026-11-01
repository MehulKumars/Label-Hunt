## A once-a-day gift that opens after the day's first play and climbs a fixed ladder with the streak.
## Game-agnostic: the game owns the reward table; this only decides when and which rung.
class_name GiftLadder
extends RefCounted


## True if today's gift is waiting: played today, not yet claimed today.
static func ready(claimed_day: int, played_today: bool, day: int) -> bool:
	return played_today and claimed_day != day


## The rung (0-based) for a streak count on a ladder of `length` rungs.
static func rung(streak_count: int, length: int) -> int:
	return (maxi(streak_count, 1) - 1) % length
