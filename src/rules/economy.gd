## Jarful's economy, stars and player levels: every price, reward and curve in one place (docs/plan-m3.md sections 3
## and 5, docs/DESIGN.md "Stars, coins and diamonds"). Pure functions over plain dictionaries; src/core/wallet.gd
## applies them to the save and writes it.
##
## Two currencies. Coins are earned by play (stars, gifts, rank-ups, room completes) and never sold. Diamonds are
## bought or earned from an optional shop ad, and are the fallback when coins run short. The anchor:
## 1 Hint = 50 coins = 10 diamonds (about $0.10 in the smallest pack); a shop ad banks half a Hint (5 diamonds).
class_name Economy
extends RefCounted

const PRICES := {"hint": 50, "complete": 250, "continue": 150}
## The same boosters for diamonds: a little better value on the bigger ones (Continue 17%, Complete 20%).
const DIAMOND_PRICES := {"hint": 10, "complete": 40, "continue": 25}
## Boosters that can sit in the inventory (gifts, level-ups, intros, shop bundles). +Jar and Undo stay free.
const ITEMS := ["hint", "complete"]
const STARTER_COINS := 150
## An optional shop ad banks half a Hint in diamonds. (The free-Hint ad, at the moment of need, is worth a whole one.)
const AD_DIAMONDS := 5
const MAX_DIAMONDS := 999999
const LEVEL_UP_COINS := 20
const ROOM_COINS := 150
## The 7-day daily gift, by streak day (repeats after day 7).
const GIFT_LADDER := [
	{"coins": 20}, {"coins": 25}, {"coins": 30}, {"coins": 40}, {"coins": 50}, {"coins": 60},
	{"coins": 100, "complete": 1},
]
const STREAK_SAVER_EVERY := 7
const MAX_SAVERS := 2
## Bonuses for reaching a streak length, on top of the week's gifts (day 7 is the top of that week). The whole road is
## shown in advance, and a broken streak can earn them again. Past the table, every 50 days pays STREAK_LATE.
const STREAK_MILESTONES := {
	10: {"coins": 150}, 15: {"coins": 200}, 20: {"coins": 250}, 30: {"coins": 400, "avatar": "trophy"}, 45: {"coins": 500},
	60: {"coins": 600, "complete": 1}, 75: {"coins": 700}, 100: {"coins": 1000, "avatar": "crown"},
}
const STREAK_LATE_EVERY := 50
const STREAK_LATE := {"coins": 1000, "complete": 1}
## Free samples when a booster is first introduced (by the level's `introduces` tag).
const INTRO_GIFTS := {"hint": {"hint": 3}, "complete": {"complete": 1}}
## Diamond packs (USD base; the store sets local prices), with a bonus that grows with the pack. The largest is
## $9.99: a calm game has no big-spender pack. The smallest buys 10 Hints.
const PACKS := [
	{"id": "diamonds_100", "diamonds": 100, "usd": "0.99", "bonus": 0},
	{"id": "diamonds_220", "diamonds": 220, "usd": "1.99", "bonus": 10},
	{"id": "diamonds_600", "diamonds": 600, "usd": "4.99", "bonus": 20},
	{"id": "diamonds_1300", "diamonds": 1300, "usd": "9.99", "bonus": 30},
]
## Booster bundles for diamonds in the shop, cheaper than one at a time (Hints 20% off, Completes 17% off).
const BUNDLES := [
	{"id": "hints_5", "item": "hint", "count": 5, "diamonds": 40},
	{"id": "completes_3", "item": "complete", "count": 3, "diamonds": 100},
]

## Stars count slips, nothing else: Hints, +Jar, Undo, Complete and the help ladder never cost a star. A level's
## limits come from its baked gold G (a strong average-bot run: 20-50% of its runs stay within it) plus an offset
## that tightens by room, generous early and strict late: [first room, offset]. Tuned with tools/star_report.gd so the
## average bot earns 3 stars on about 93% of its wins in rooms 1-4, 62% in rooms 5-13 (a step at room 8) and 47% in
## rooms 14-17, where a slip under the strong-run mark already costs a star.
const STAR_OFFSETS := [[1, 2], [5, 1], [8, 0], [14, -1]]
## Levels without a slip budget (Room 1, L1-10): 3 stars up to 3 slips, 2 stars up to 5.
const FREE_STAR_LIMITS := Vector2i(3, 5)
## Coins per star, as a share of win_coins, by room ([first room, rate]). Late rooms pay more per star because 3 stars
## is rarer there: with one rate for all, either early coins piled up or late rooms ran short of Hints
## (tools/economy_sim.gd, reports/economy.md).
const STAR_COIN_RATES := [[1, 0.4], [8, 0.45], [14, 0.5]]
const TITLES := [[1, "Apprentice"], [5, "Jam Maker"], [10, "Pickler"], [15, "Preserver"], [20, "Pantry Keeper"],
	[30, "Larder Master"], [40, "Grand Preserver"], [50, "Legend of the Larder"]]
## Avatars (Phosphor food icons on a lid disc): [id, icon, colour, unlocked at player level (0 = by milestone)].
const AVATARS := [
	["lemon", "orange-slice", "#E8C14A", 1], ["pepper", "pepper", "#C6553A", 1], ["carrot", "carrot", "#E8A04A", 1],
	["avocado", "avocado", "#8A9A4B", 5], ["cheese", "cheese", "#EBD3A2", 10], ["bread", "bread", "#B98A5A", 15],
	["egg", "egg", "#F2E6C9", 20], ["fish", "fish", "#5E7F9A", 25], ["cookie", "cookie", "#9C6B43", 30],
	["coffee", "coffee", "#6D4C3D", 40], ["trophy", "trophy", "#D9A441", 0], ["crown", "crown", "#7B3F61", 0],
]


## First-solve coins: 10 + 4 per group above 2; tricky +4, hard +8; +2 per room after the first, since help is wanted
## more often as rooms get harder while groups stop at 6 (at +1, free players got only 55-66% of the Hints they wanted
## in late rooms; at +2, 68-74%; reports/economy.md). A hard level in Room 17 pays 66. Replays and gold lids pay no
## coins.
static func win_coins(groups: int, kind: String, room: int = 1) -> int:
	return 10 + 4 * maxi(groups - 2, 0) + {"tricky": 4, "hard": 8}.get(kind, 0) + 2 * maxi(room - 1, 0)


## Coins one star is worth on this level. A win pays per star; a replay pays only the stars it adds.
static func per_star(groups: int, kind: String, room: int = 1) -> int:
	var rate: float = STAR_COIN_RATES[0][1]
	for row: Array in STAR_COIN_RATES:
		if room >= int(row[0]):
			rate = float(row[1])
	return maxi(1, roundi(rate * win_coins(groups, kind, room)))


## The star offset for a room (see STAR_OFFSETS).
static func star_offset(room: int) -> int:
	var off: int = STAR_OFFSETS[0][1]
	for row: Array in STAR_OFFSETS:
		if room >= int(row[0]):
			off = int(row[1])
	return off


## The slip limits for 3 and 2 stars: Vector2i(l3, l2), any win past l2 is 1 star. With a budget both stay below it,
## so a win after a Continue (slips >= budget) is always 1 star; l2 == l3 means 2 stars can't happen on this level.
static func star_limits(room: int, gold: int, budget: int) -> Vector2i:
	if budget <= 0:
		return FREE_STAR_LIMITS
	var l3 := clampi(maxi(gold, 0) + star_offset(room), 0, budget - 1)
	var l2 := maxi(l3, mini(l3 + 2, budget - 1))
	return Vector2i(l3, l2)


## The limits of a catalog entry (its baked budget, not a session's, which the help ladder raises).
static func entry_limits(entry: Dictionary) -> Vector2i:
	var d: Dictionary = entry.get("data", {})
	return star_limits(int(entry.get("room", 1)), int(entry.get("gold", -1)), int(d.get("budget", 0)))


static func stars_for(slips: int, limits: Vector2i) -> int:
	if slips <= limits.x:
		return 3
	return 2 if slips <= limits.y else 1


## First-solve XP: 10 + 5 per group above 2; tricky +5, hard +10. A first gold lid adds GOLD_XP.
static func win_xp(groups: int, kind: String) -> int:
	return 10 + 5 * maxi(groups - 2, 0) + {"tricky": 5, "hard": 10}.get(kind, 0)


const GOLD_XP := 15


## XP needed to go from player level `level` to the next.
static func xp_to_next(level: int) -> int:
	return 60 + 15 * (level - 1)


## {level, into (XP into this level), need (XP for the next)} for a total XP.
static func level_for_xp(xp: int) -> Dictionary:
	var level := 1
	var left := maxi(xp, 0)
	while left >= xp_to_next(level):
		left -= xp_to_next(level)
		level += 1
	return {"level": level, "into": left, "need": xp_to_next(level)}


static func title_for(level: int) -> String:
	var t: String = TITLES[0][1]
	for row: Array in TITLES:
		if level >= int(row[0]):
			t = row[1]
	return t


## What reaching player level `level` gives: coins every time, every 5th level two Hints, and any avatar it unlocks.
static func level_rewards(level: int) -> Dictionary:
	var r := {"coins": LEVEL_UP_COINS}
	if level % 5 == 0:
		r["hint"] = 2
	for a: Array in AVATARS:
		if int(a[3]) == level and level > 1:
			r["avatar"] = a[0]
	return r


## The gift for a streak day (1-based).
static func gift_for_day(streak_day: int) -> Dictionary:
	return GIFT_LADDER[(maxi(streak_day, 1) - 1) % GIFT_LADDER.size()]


## What reaching a streak length pays ({} if nothing).
static func streak_bonus(days: int) -> Dictionary:
	if STREAK_MILESTONES.has(days):
		return STREAK_MILESTONES[days]
	if days > 100 and days % STREAK_LATE_EVERY == 0:
		return STREAK_LATE
	return {}


## The next `n` streak lengths after `days` that pay a bonus.
static func next_streak_bonuses(days: int, n: int) -> Array[int]:
	var out: Array[int] = []
	var d := maxi(days, 0) + 1
	while out.size() < n:
		if not streak_bonus(d).is_empty():
			out.append(d)
		d += 1
	return out


## The avatars unlocked from the start.
static func starter_avatars() -> Array[String]:
	var out: Array[String] = []
	for a: Array in AVATARS:
		if int(a[3]) == 1:
			out.append(a[0])
	return out


static func avatar(id: String) -> Array:
	for a: Array in AVATARS:
		if a[0] == id:
			return a
	return AVATARS[0]


static func pack(id: String) -> Dictionary:
	for p: Dictionary in PACKS:
		if p["id"] == id:
			return p
	return {}


static func bundle(id: String) -> Dictionary:
	for b: Dictionary in BUNDLES:
		if b["id"] == id:
			return b
	return {}


# --- wallet arithmetic on the save dictionary ---------------------------------------------------------------------

static func count(save: Dictionary, item: String) -> int:
	return int((save.get("inventory", {}) as Dictionary).get(item, 0))


## True if the item can be used now: one in the inventory, or enough coins for its price.
static func can_afford(save: Dictionary, item: String) -> bool:
	return count(save, item) > 0 or int(save.get("coins", 0)) >= int(PRICES.get(item, 1 << 30))


## Uses one of the item: from the inventory first, else its price in coins. Returns "inventory", "coins" or "".
static func spend(save: Dictionary, item: String) -> String:
	if count(save, item) > 0:
		save["inventory"][item] = count(save, item) - 1
		return "inventory"
	var price := int(PRICES.get(item, -1))
	if price < 0 or int(save.get("coins", 0)) < price:
		return ""
	save["coins"] = int(save["coins"]) - price
	return "coins"


static func diamonds(save: Dictionary) -> int:
	return int(save.get("diamonds", 0))


## True if the save holds enough diamonds for this booster (or Continue).
static func can_pay_diamonds(save: Dictionary, item: String) -> bool:
	return DIAMOND_PRICES.has(item) and diamonds(save) >= int(DIAMOND_PRICES[item])


## Pays a booster (or Continue) in diamonds. False if it can't be paid; nothing changes then.
static func pay_diamonds(save: Dictionary, amount: int) -> bool:
	if amount < 0 or diamonds(save) < amount:
		return false
	save["diamonds"] = diamonds(save) - amount
	return true


## Adds rewards {coins, diamonds, hint, complete, saver, avatar} to the save.
static func grant(save: Dictionary, rewards: Dictionary) -> void:
	save["coins"] = clampi(int(save.get("coins", 0)) + int(rewards.get("coins", 0)), 0, 9999999)
	if rewards.has("diamonds"):
		save["diamonds"] = clampi(diamonds(save) + int(rewards["diamonds"]), 0, MAX_DIAMONDS)
	for item in ITEMS:
		if rewards.has(item):
			save["inventory"][item] = clampi(count(save, item) + int(rewards[item]), 0, 999)
	if rewards.has("saver"):
		save["streak"]["savers"] = mini(int(save["streak"]["savers"]) + int(rewards["saver"]), MAX_SAVERS)
	if rewards.has("avatar"):
		save["avatars"][str(rewards["avatar"])] = true


## Adds XP; returns the player levels reached on the way (each with its rewards, already granted).
static func add_xp(save: Dictionary, amount: int) -> Array[Dictionary]:
	var before := int(level_for_xp(int(save.get("xp", 0)))["level"])
	save["xp"] = clampi(int(save.get("xp", 0)) + amount, 0, 99999999)
	var after := int(level_for_xp(int(save["xp"]))["level"])
	var ups: Array[Dictionary] = []
	for lv in range(before + 1, after + 1):
		var r := level_rewards(lv)
		grant(save, r)
		ups.append({"level": lv, "rewards": r})
	return ups
