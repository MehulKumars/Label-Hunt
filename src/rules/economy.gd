## Jarful's coin economy and player levels: every price, reward and curve in one place (docs/plan-m3.md sections 3
## and 5). Pure functions over plain dictionaries; src/core/wallet.gd applies them to the save and writes it.
class_name Economy
extends RefCounted

const PRICES := {"hint": 50, "complete": 250, "continue": 150}
## Boosters that can sit in the inventory (gifts, level-ups, intros). +Jar and Undo stay free.
const ITEMS := ["hint", "complete"]
const STARTER_COINS := 150
const AD_COINS := 25
const LEVEL_UP_COINS := 20
const ROOM_COINS := 150
## The 7-day daily gift, by streak day (repeats after day 7).
const GIFT_LADDER := [
	{"coins": 20}, {"coins": 25}, {"coins": 30}, {"coins": 40}, {"coins": 50}, {"coins": 60},
	{"coins": 100, "complete": 1},
]
const STREAK_SAVER_EVERY := 7
const MAX_SAVERS := 2
const STREAK_MILESTONES := {30: {"coins": 400, "avatar": "trophy"}, 100: {"coins": 800, "avatar": "crown"}}
## Free samples when a booster is first introduced (by the level's `introduces` tag).
const INTRO_GIFTS := {"hint": {"hint": 3}, "complete": {"complete": 1}}
## Coin packs (USD base; the store sets local prices). The largest is $9.99: a calm game has no big-spender pack.
const PACKS := [
	{"id": "coins_500", "coins": 500, "usd": "0.99"},
	{"id": "coins_1200", "coins": 1200, "usd": "1.99"},
	{"id": "coins_3500", "coins": 3500, "usd": "4.99"},
	{"id": "coins_8000", "coins": 8000, "usd": "9.99"},
]
const TITLES := [[1, "Apprentice"], [5, "Jam Maker"], [10, "Pickler"], [15, "Preserver"], [20, "Pantry Keeper"],
	[30, "Larder Master"], [40, "Grand Preserver"], [50, "Legend of the Larder"]]
## Avatars (Phosphor food icons on a lid disc): [id, icon, colour, unlocked at player level (0 = by milestone)].
const AVATARS := [
	["lemon", "orange-slice", "#E8C14A", 1], ["pepper", "pepper", "#C6553A", 1], ["carrot", "carrot", "#E8A04A", 1],
	["avocado", "avocado", "#8A9A4B", 5], ["cheese", "cheese", "#EBD3A2", 10], ["bread", "bread", "#B98A5A", 15],
	["egg", "egg", "#F2E6C9", 20], ["fish", "fish", "#5E7F9A", 25], ["cookie", "cookie", "#9C6B43", 30],
	["coffee", "coffee", "#6D4C3D", 40], ["trophy", "trophy", "#D9A441", 0], ["crown", "crown", "#7B3F61", 0],
]


## First-solve coins: 10 + 4 per group above 2; tricky +4, hard +8. Replays and gold lids pay no coins.
static func win_coins(groups: int, kind: String) -> int:
	return 10 + 4 * maxi(groups - 2, 0) + {"tricky": 4, "hard": 8}.get(kind, 0)


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


## Adds rewards {coins, hint, complete, saver, avatar} to the save.
static func grant(save: Dictionary, rewards: Dictionary) -> void:
	save["coins"] = clampi(int(save.get("coins", 0)) + int(rewards.get("coins", 0)), 0, 9999999)
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
