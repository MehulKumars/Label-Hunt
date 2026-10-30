## Plays every level in a level file with each bot profile and reports difficulty, plus a bake-time benchmark.
## Run: godot --headless --path . -s res://tools/sim.gd [-- --n=200 --file=res://data/levels/handmade.json --out=handmade]
extends SceneTree

const PROFILES := ["novice", "average", "expert", "prober"]


func _init() -> void:
	var n := 200
	var path := "res://data/levels/handmade.json"
	var out := "handmade"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = int(a.substr(4))
		elif a.begins_with("--file="):
			path = a.substr(7)
		elif a.begins_with("--out="):
			out = a.substr(6)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var csv: Array[String] = ["level,groups,budget,par,profile,win_rate,median_slips,p90_slips,mean_moves,dead_ends,median_after_known,median_secs"]
	var md: Array[String] = [
		"# Bot simulation: %s" % out, "",
		"%d games per profile per level. Win rate counts a loss when slips reach the level's budget (levels with no budget can't be lost, so read their slips instead). Moves after the aha = moves the bot still made once it believed every remaining card's true group (post-aha busywork; target 8 or fewer)." % n, "",
		"| level | grp | budget | par | novice win | average win | expert win | prober win | avg median slips | avg p90 slips | avg moves | avg after-known | avg secs |",
		"|---|---|---|---|---|---|---|---|---|---|---|---|---|",
	]
	var t_all := Time.get_ticks_msec()
	var games := 0
	for d: Dictionary in data["levels"]:
		var level := LevelData.from_dict(d)
		var par: int = Solver.solve(BoardState.from_level(level), 200000)["cost"]
		var row := {}
		for prof in PROFILES:
			var res: Array[Dictionary] = []
			for i in n:
				res.append(Bot.play(level, prof, hash(level.id + prof) + i))
				games += 1
			var st := _stats(res)
			row[prof] = st
			csv.append("%s,%d,%d,%d,%s,%.3f,%d,%d,%.1f,%.2f,%d,%d" % [level.id, level.group_count(), level.budget, par, prof,
				st["win"], st["slips_med"], st["slips_p90"], st["moves"], st["dead_ends"], st["after_med"], st["secs_med"]])
		var av: Dictionary = row["average"]
		md.append("| %s | %d | %d | %d | %s | %s | %s | %s | %d | %d | %.0f | %d | %d |" % [level.id, level.group_count(), level.budget, par,
			_pct(row["novice"]["win"]), _pct(av["win"]), _pct(row["expert"]["win"]), _pct(row["prober"]["win"]),
			av["slips_med"], av["slips_p90"], av["moves"], av["after_med"], av["secs_med"]])
		print("%-4s grp=%d budget=%d par=%2d  win n/a/e/p = %s %s %s %s  slips med=%d p90=%d  moves=%.0f after=%d" % [
			level.id, level.group_count(), level.budget, par, _pct(row["novice"]["win"]), _pct(av["win"]),
			_pct(row["expert"]["win"]), _pct(row["prober"]["win"]), av["slips_med"], av["slips_p90"], av["moves"], av["after_med"]])
	var ms := Time.get_ticks_msec() - t_all
	var per_game := float(ms) / maxi(games, 1)
	# Bake estimate: 515 levels x (3 candidates x 40 screening games + 300 average + 2 x 100 other profiles).
	var bake_games := 515 * (3 * 40 + 300 + 200)
	md.append("")
	md.append("**Benchmark:** %d games in %.1f s = %.2f ms/game. A full bake (515 levels, about %d games) would take about %.0f min on one process, or %.0f min split over 6 processes." % [
		games, ms / 1000.0, per_game, bake_games, bake_games * per_game / 60000.0, bake_games * per_game / 60000.0 / 6.0])
	print(md.back())
	DirAccess.make_dir_recursive_absolute("res://reports")
	_write("res://reports/sim_%s.csv" % out, "\n".join(csv))
	_write("res://reports/sim_%s.md" % out, "\n".join(md))
	quit()


func _stats(res: Array[Dictionary]) -> Dictionary:
	var slips: Array[int] = []
	var after: Array[int] = []
	var secs: Array[float] = []
	var wins := 0
	var moves := 0.0
	var dead := 0.0
	for r in res:
		wins += 1 if r["won"] else 0
		slips.append(r["slips"])
		after.append(r["after_known"])
		secs.append(r["secs"])
		moves += r["moves"]
		dead += r["dead_ends"]
	slips.sort()
	after.sort()
	secs.sort()
	var n := res.size()
	return {
		"win": float(wins) / n, "slips_med": slips[n / 2], "slips_p90": slips[mini(n - 1, int(n * 0.9))],
		"moves": moves / n, "dead_ends": dead / n, "after_med": after[n / 2], "secs_med": int(secs[n / 2]),
	}


static func _pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


static func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text + "\n")
