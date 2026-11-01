## When ads may be offered. Pure, so the rules are tested. Rewarded ads only, always opt-in; no interstitials
## (Mehul's call, 2026-10-31). Caps per day and per placement, and a short cooldown between ads.
## The state is the save's "ads" dictionary: {day, total, by_placement: {placement: n}, last_s}.
class_name AdPolicy
extends RefCounted

const CONTINUES_PER_ATTEMPT := 1
const DAILY_CAP := 12
const COOLDOWN_S := 30
## Placements with their own daily caps (others only count toward DAILY_CAP).
const PLACEMENT_CAPS := {"shop_coins": 5, "free_hint": 3, "gift_double": 1}


static func can_offer_continue(continues_used: int) -> bool:
	return continues_used < CONTINUES_PER_ATTEMPT


static func fresh() -> Dictionary:
	return {"day": -1, "total": 0, "by_placement": {}, "last_s": 0}


## True if an ad for `placement` may be offered now.
static func can_show(ads: Dictionary, placement: String, day: int, now_s: int) -> bool:
	if left_today(ads, placement, day) <= 0:
		return false
	return now_s - int(ads.get("last_s", 0)) >= COOLDOWN_S or now_s < int(ads.get("last_s", 0))


## Ads of this placement still allowed today (the daily total also limits it).
static func left_today(ads: Dictionary, placement: String, day: int) -> int:
	var same_day := int(ads.get("day", -1)) == day
	var total := int(ads.get("total", 0)) if same_day else 0
	var used := int((ads.get("by_placement", {}) as Dictionary).get(placement, 0)) if same_day else 0
	var left := DAILY_CAP - total
	if PLACEMENT_CAPS.has(placement):
		left = mini(left, int(PLACEMENT_CAPS[placement]) - used)
	return maxi(left, 0)


## Counts a watched ad (only call when the reward was earned).
static func record(ads: Dictionary, placement: String, day: int, now_s: int) -> void:
	if int(ads.get("day", -1)) != day:
		ads["day"] = day
		ads["total"] = 0
		ads["by_placement"] = {}
	ads["total"] = int(ads["total"]) + 1
	var bp: Dictionary = ads["by_placement"]
	bp[placement] = int(bp.get(placement, 0)) + 1
	ads["last_s"] = now_s
