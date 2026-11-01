## The difficulty curve across every shipped room, from each level's baked bot numbers: per room the groups, the
## average bot's slips and first-try win rate against the room's floor, novice wins, prober wins, and the levels that
## miss their floor. Writes reports/curve.md and reports/curve.csv.
## Run: godot --headless --path . -s res://tools/curve_report.gd
extends SceneTree

const LEVELS := preload("res://src/core/levels.gd")
const MAX_BUDGET := 8


func _init() -> void:
	var cat := Catalog.from_files(LEVELS.files())
	var md: Array[String] = ["# Difficulty curve", "",
		"Average bot = the target player; its first-try win rate must meet each level's floor (set per room and kind in data/rooms/curve.json). Prober = random guessing.", "",
		"| room | levels | groups | avg slips (normal / tricky / hard) | avg win (min) | floor misses | novice win (mean) | prober win (max) |",
		"|---|---|---|---|---|---|---|---|"]
	var csv: Array[String] = ["level,id,room,kind,groups,budget,gold,target,avg_slips,floor,avg_win,novice_win,prober_win,after_med,aha_frac"]
	var misses: Array[String] = []
	var shape: Array[String] = []
	var n := 0
	for r in cat.room_numbers():
		var ids := cat.room_ids(r)
		var slips := {"normal": [], "tricky": [], "hard": [], "rest": []}
		var groups := {}
		var min_win := 1.0
		var nov := 0.0
		var pro := 0.0
		var miss := 0
		for id in ids:
			n += 1
			var e := cat.entry(id)
			var d: Dictionary = e["data"]
			var m: Dictionary = d.get("meta", {})
			var g := (d["groups"] as Array).size()
			groups[g] = true
			(slips[str(e["kind"])] as Array).append(float(m.get("avg_slips", 0.0)))
			var win := float(m.get("avg_win", 1.0))
			min_win = minf(min_win, win)
			nov += float(m.get("novice_win", 1.0))
			pro = maxf(pro, float(m.get("prober_win", 0.0)))
			var fl := float(m.get("floor", 0.0))
			if int(d.get("budget", 0)) > 0 and win + 0.03 < fl:
				miss += 1
				misses.append("- %s (L%d, %s): average win %d%% under its floor %d%%" % [id, n, e["kind"], roundi(win * 100), roundi(fl * 100)])
			csv.append("%d,%s,%d,%s,%d,%d,%d,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%.2f" % [n, id, r, e["kind"], g, int(d.get("budget", 0)),
				int(d.get("gold", -1)), float(m.get("target", 0.0)), float(m.get("avg_slips", 0.0)), fl, win,
				float(m.get("novice_win", 1.0)), float(m.get("prober_win", 0.0)), int(m.get("after_med", 0)), float(m.get("aha_frac", 0.0))])
		var normal := _mean(slips["normal"])
		for id in ids:
			var d: Dictionary = cat.entry(id)["data"]
			var s := float(d.get("meta", {}).get("avg_slips", 0.0))
			if str(cat.entry(id)["kind"]) == "hard" and s < normal:
				shape.append("- %s: a hard level at %.1f slips, under its room's normal %.1f" % [id, s, normal])
			if int(d.get("budget", 0)) > MAX_BUDGET:
				shape.append("- %s: a slip limit of %d reads as no limit" % [id, int(d["budget"])])
		var gk := groups.keys()
		gk.sort()
		md.append("| %d %s | %d-%d | %s | %.1f / %.1f / %.1f | %d%% | %d | %d%% | %d%% |" % [r, cat.room_name(r), n - ids.size() + 1, n,
			"-".join(gk.map(func(x: int) -> String: return str(x))), _mean(slips["normal"]), _mean(slips["tricky"]), _mean(slips["hard"]),
			roundi(min_win * 100), miss, roundi(nov / maxf(ids.size(), 1) * 100), roundi(pro * 100)])
	md.append_array(["", "## Levels under their floor (3-point tolerance)", ""])
	md.append_array(misses if not misses.is_empty() else ["None."])
	md.append_array(["", "## Levels out of shape", ""])
	md.append_array(shape if not shape.is_empty() else ["None."])
	DirAccess.make_dir_recursive_absolute("res://reports")
	var f := FileAccess.open("res://reports/curve.md", FileAccess.WRITE)
	f.store_string("\n".join(md) + "\n")
	var c := FileAccess.open("res://reports/curve.csv", FileAccess.WRITE)
	c.store_string("\n".join(csv) + "\n")
	print("%d levels, %d under their floor, %d out of shape" % [n, misses.size(), shape.size()])
	quit()


static func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for x in a:
		s += float(x)
	return s / a.size()
