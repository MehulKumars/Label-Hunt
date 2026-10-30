## The save file's shape: defaults, migrations and a sanitiser that type- and range-checks every field, so a
## corrupt or hand-edited save can never crash the game or smuggle in odd values. JSON only, never str_to_var.
class_name SaveSchema
extends RefCounted

const VERSION := 2
const MAX_BYTES := 1 << 20
const RULE_KEYS := ["tag_on_slip", "pair_reveal", "pour", "one_empty"]


static func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"launches": 0,
		"settings": {"sound": 1.0, "music": 0.7, "haptics": true, "reduce_motion": false, "fps": false},
		"rules": {},
		"seen_captions": {},
		"tutorial": {"done": false, "board": 0},
		"solved": {},
		"board": {},
	}


## Brings an older save up to VERSION. v1 (M1) kept a level index and on/off sound.
static func migrate(d: Dictionary) -> Dictionary:
	var v := int(_num(d.get("version", 1), 1))
	if v < 2:
		var s: Variant = d.get("settings", {})
		if s is Dictionary and s.get("sound") is bool:
			s["sound"] = 1.0 if s["sound"] else 0.0
		d["tutorial"] = {"done": int(_num(d.get("level", 0), 0)) > 2, "board": 0}
		d.erase("level")
		d["version"] = 2
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
	var r: Dictionary = _dict(d.get("rules"))
	for k in RULE_KEYS:
		if r.get(k) is bool:
			out["rules"][k] = r[k]
	if r.get("mode") in ["budget", "stars"]:
		out["rules"]["mode"] = r["mode"]
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
	var b: Dictionary = _dict(d.get("board"))
	if b.get("id") is String and (valid_ids.is_empty() or valid_ids.has(b["id"])):
		out["board"] = b
	return out


static func _num(v: Variant, fallback: float) -> float:
	if (v is float or v is int) and is_finite(float(v)):
		return float(v)
	return fallback


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}
