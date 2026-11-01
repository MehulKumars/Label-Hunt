## A play streak: consecutive days with at least one play, with optional savers that cover a missed day each.
## Game-agnostic: the state is a plain dictionary {count, best, last_day, savers}; days are integers (DayClock).
class_name Streak
extends RefCounted


static func fresh() -> Dictionary:
	return {"count": 0, "best": 0, "last_day": -1, "savers": 0}


## Records a play on `day`. Returns {state, kind: "same_day" | "continued" | "saved" | "started", savers_used,
## saver_earned}. A saver is earned every `earn_every` days of streak (holding at most `max_savers`).
static func record(state: Dictionary, day: int, earn_every: int = 7, max_savers: int = 2) -> Dictionary:
	var s := state.duplicate()
	var last := int(s["last_day"])
	var kind := "started"
	var used := 0
	if last == day:
		return {"state": s, "kind": "same_day", "savers_used": 0, "saver_earned": false}
	if last >= 0 and day - last == 1:
		kind = "continued"
	elif last >= 0 and day > last and day - last - 1 <= int(s["savers"]):
		used = day - last - 1
		s["savers"] = int(s["savers"]) - used
		kind = "saved"
	if kind == "started":
		s["count"] = 1
	else:
		s["count"] = int(s["count"]) + 1
	s["last_day"] = day
	s["best"] = maxi(int(s["best"]), int(s["count"]))
	var earned := false
	if earn_every > 0 and int(s["count"]) % earn_every == 0 and int(s["savers"]) < max_savers:
		s["savers"] = int(s["savers"]) + 1
		earned = true
	return {"state": s, "kind": kind, "savers_used": used, "saver_earned": earned}


## The streak to show on `day` before today's play: alive if yesterday was played or savers cover the gap.
static func shown(state: Dictionary, day: int) -> int:
	var last := int(state["last_day"])
	if last < 0:
		return 0
	if day - last <= 1 or day - last - 1 <= int(state["savers"]):
		return int(state["count"])
	return 0


static func played_on(state: Dictionary, day: int) -> bool:
	return int(state["last_day"]) == day
