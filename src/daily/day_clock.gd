## Local calendar days as integers, with a guard against clocks that move backwards. Game-agnostic: no game imports.
class_name DayClock
extends RefCounted

## A clock this many days behind the furthest day seen is trusted again (it was wrong before, not now).
const REANCHOR_DAYS := 2


## Days since 1970-01-01 for the device's local date.
static func today() -> int:
	var d := Time.get_date_dict_from_system()
	return day_number(int(d["year"]), int(d["month"]), int(d["day"]))


static func day_number(year: int, month: int, day: int) -> int:
	return int(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": 0,
		"minute": 0, "second": 0}) / 86400)


## The day to act on given the clock and the furthest day ever seen: {day, max_seen}. A clock moved back a little
## freezes time at max_seen (nothing new until it catches up); a clock far behind re-anchors to today.
static func effective(today_day: int, max_seen: int) -> Dictionary:
	if today_day >= max_seen:
		return {"day": today_day, "max_seen": today_day}
	if max_seen - today_day > REANCHOR_DAYS:
		return {"day": today_day, "max_seen": today_day}
	return {"day": max_seen, "max_seen": max_seen}
