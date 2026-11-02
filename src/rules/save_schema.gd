## The save file's shape: defaults, migrations and a sanitiser that type- and range-checks every field, so a
## corrupt or hand-edited save can never crash the game or smuggle in odd values. JSON only, never str_to_var.
class_name SaveSchema
extends RefCounted

const VERSION := 3
const MAX_BYTES := 1 << 20
const RULE_KEYS := ["tag_on_slip", "pair_reveal", "pour", "one_empty"]
const MAX_COINS := 9999999
const MAX_NAME := 16
const MAX_LOG := 3000
const MAX_TOKENS := 200


static func defaults() -> Dictionary:
	var avatars := {}
	for id in Economy.starter_avatars():
		avatars[id] = true
	return {
		"version": VERSION,
		"launches": 0,
		"settings": {"sound": 1.0, "music": 0.7, "haptics": true, "reduce_motion": false, "fps": false},
		"rules": {},
		"seen_captions": {},
		"tutorial": {"done": false, "board": 0},
		"solved": {},
		"board": {},
		"coins": 0,
		"inventory": {"hint": 0, "complete": 0},
		"xp": 0,
		"xp_backdate": false,
		"profile": {"name": "", "avatar": Economy.starter_avatars()[0]},
		"avatars": avatars,
		"streak": Streak.fresh(),
		"gift": {"claimed_day": -1},
		"clock": {"max_day": 0},
		"ads": AdPolicy.fresh(),
		"purchases": {"tokens": []},
		"intro_gifts": {},
		"stats": {"hints": 0, "completes": 0, "coins_earned": 0, "coins_spent": 0, "ads": 0},
	}


## Brings an older save up to VERSION. v1 (M1) kept a level index and on/off sound. v2 (M2) had no economy: a
## returning player gets the starter coins, and XP for the levels already solved (applied once by Wallet).
static func migrate(d: Dictionary) -> Dictionary:
	var v := int(_num(d.get("version", 1), 1))
	if v < 2:
		var s: Variant = d.get("settings", {})
		if s is Dictionary and s.get("sound") is bool:
			s["sound"] = 1.0 if s["sound"] else 0.0
		d["tutorial"] = {"done": int(_num(d.get("level", 0), 0)) > 2, "board": 0}
		d.erase("level")
		d["version"] = 2
	if int(_num(d.get("version", 2), 2)) < 3:
		var t: Variant = d.get("tutorial", {})
		if t is Dictionary and t.get("done") is bool and t["done"]:
			d["coins"] = Economy.STARTER_COINS
		d["xp_backdate"] = true
		d["board"] = {}  # v2 boards had no action log
		d["version"] = 3
	return d


## A clean save built field by field from untrusted parsed JSON. valid_ids drops progress for levels that no
## longer exist (pass an empty Dictionary to keep every id).
static func sanitize(raw: Variant, valid_ids: Dictionary) -> Dictionary:
	var out := defaults()
	if raw is not Dictionary:
		return out
	var d: Dictionary = migrate((raw as Dictionary).duplicate(true))
	out["launches"] = clampi(int(_num(d.get("launches"), 0)), 0, 1 << 30)
	var s: Dictionary = _dict(d.get("settings"))
	var os: Dictionary = out["settings"]
	os["sound"] = clampf(_num(s.get("sound"), os["sound"]), 0.0, 1.0)
	os["music"] = clampf(_num(s.get("music"), os["music"]), 0.0, 1.0)
	for k in ["haptics", "reduce_motion", "fps"]:
		if s.get(k) is bool:
			os[k] = s[k]
	out["rules"] = rules(_dict(d.get("rules")))
	for k in _dict(d.get("seen_captions")):
		if k is String and k.length() <= 32:
			out["seen_captions"][k] = true
	var t: Dictionary = _dict(d.get("tutorial"))
	out["tutorial"] = {
		"done": t.get("done") is bool and t["done"],
		"board": clampi(int(_num(t.get("board"), 0)), 0, 9),
	}
	var solved: Dictionary = _dict(d.get("solved"))
	for id in solved:
		if id is not String or (not valid_ids.is_empty() and not valid_ids.has(id)):
			continue
		var e: Dictionary = _dict(solved[id])
		out["solved"][id] = {
			"slips": clampi(int(_num(e.get("slips"), 0)), 0, 99),
			"gold": e.get("gold") is bool and e["gold"],
		}
	out["board"] = _board(_dict(d.get("board")), valid_ids)
	out["coins"] = clampi(int(_num(d.get("coins"), 0)), 0, MAX_COINS)
	var inv: Dictionary = _dict(d.get("inventory"))
	for item in Economy.ITEMS:
		out["inventory"][item] = clampi(int(_num(inv.get(item), 0)), 0, 999)
	out["xp"] = clampi(int(_num(d.get("xp"), 0)), 0, 99999999)
	out["xp_backdate"] = d.get("xp_backdate") is bool and d["xp_backdate"]
	var av: Dictionary = _dict(d.get("avatars"))
	for a: Array in Economy.AVATARS:
		if av.get(a[0]) is bool and av[a[0]]:
			out["avatars"][a[0]] = true
	var p: Dictionary = _dict(d.get("profile"))
	out["profile"]["name"] = clean_name(p.get("name", ""))
	if p.get("avatar") is String and out["avatars"].has(p["avatar"]):
		out["profile"]["avatar"] = p["avatar"]
	var st: Dictionary = _dict(d.get("streak"))
	out["streak"] = {
		"count": clampi(int(_num(st.get("count"), 0)), 0, 100000),
		"best": clampi(int(_num(st.get("best"), 0)), 0, 100000),
		"last_day": clampi(int(_num(st.get("last_day"), -1)), -1, 1000000),
		"savers": clampi(int(_num(st.get("savers"), 0)), 0, Economy.MAX_SAVERS),
	}
	out["gift"]["claimed_day"] = clampi(int(_num(_dict(d.get("gift")).get("claimed_day"), -1)), -1, 1000000)
	out["clock"]["max_day"] = clampi(int(_num(_dict(d.get("clock")).get("max_day"), 0)), 0, 1000000)
	var ads: Dictionary = _dict(d.get("ads"))
	out["ads"]["day"] = clampi(int(_num(ads.get("day"), -1)), -1, 1000000)
	out["ads"]["total"] = clampi(int(_num(ads.get("total"), 0)), 0, 1000)
	out["ads"]["last_s"] = clampi(int(_num(ads.get("last_s"), 0)), 0, 1 << 40)
	for k in _dict(ads.get("by_placement")):
		if k is String and k.length() <= 24:
			out["ads"]["by_placement"][k] = clampi(int(_num(ads["by_placement"][k], 0)), 0, 1000)
	var tokens: Variant = _dict(d.get("purchases")).get("tokens", [])
	if tokens is Array:
		for tok in (tokens as Array).slice(0, MAX_TOKENS):
			if tok is String and tok.length() <= 200:
				out["purchases"]["tokens"].append(tok)
	for k in _dict(d.get("intro_gifts")):
		if k is String and Economy.INTRO_GIFTS.has(k):
			out["intro_gifts"][k] = true
	var stats: Dictionary = _dict(d.get("stats"))
	for k in out["stats"]:
		out["stats"][k] = clampi(int(_num(stats.get(k), 0)), 0, 1 << 30)
	return out


## Printable characters only, trimmed, at most MAX_NAME.
static func clean_name(v: Variant) -> String:
	if v is not String:
		return ""
	var out := ""
	for ch in (v as String).strip_edges():
		if ch.unicode_at(0) >= 32 and ch.unicode_at(0) != 127:
			out += ch
	return out.left(MAX_NAME).strip_edges()


## Rule toggles with known keys and values only: the test menu's overrides, and the rules a saved attempt was
## played under.
static func rules(r: Dictionary) -> Dictionary:
	var out := {}
	for k in RULE_KEYS:
		if r.get(k) is bool:
			out[k] = r[k]
	if r.get("mode") in ["budget", "stars"]:
		out["mode"] = r["mode"]
	return out


## The saved attempt: {id, fingerprint, rules, log, fails, assisted}. Its log is only replayed (and checked) by
## Session, and only under the rules it was played with.
static func _board(b: Dictionary, valid_ids: Dictionary) -> Dictionary:
	if b.get("id") is not String or (not valid_ids.is_empty() and not valid_ids.has(b["id"])):
		return {}
	var log: Variant = b.get("log", [])
	if log is not Array or (log as Array).size() > MAX_LOG or b.get("fingerprint") is not String:
		return {}
	var clean: Array = []
	for a: Variant in log:
		if a is not Array or (a as Array).is_empty() or (a as Array).size() > 3 or (a as Array)[0] is not String:
			return {}
		var row: Array = [(a as Array)[0]]
		for x in (a as Array).slice(1):
			if not (x is int or x is float) or not is_finite(float(x)):
				return {}
			row.append(int(x))
		clean.append(row)
	return {"id": b["id"], "fingerprint": (b["fingerprint"] as String).left(32), "rules": rules(_dict(b.get("rules"))), "log": clean,
		"fails": clampi(int(_num(b.get("fails"), 0)), 0, 99), "assisted": b.get("assisted") is bool and b["assisted"]}


static func _num(v: Variant, fallback: float) -> float:
	if (v is float or v is int) and is_finite(float(v)):
		return float(v)
	return fallback


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}
