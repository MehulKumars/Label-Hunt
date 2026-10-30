## Deals hand-made levels that ask for a seeded deal, then checks every level and writes the file back.
## Checks: unique exact cover, solvable by the solver, no same-group cards touching (tutorial t01 is exempt).
## Run: godot --headless --path . -s res://tools/check_levels.gd [-- --file=res://data/levels/room1.json]
extends SceneTree

const DEFAULT_FILE := "res://data/levels/room1.json"


func _init() -> void:
	var path := DEFAULT_FILE
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--file="):
			path = arg.substr(7)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var failures := 0
	print("%-5s %3s %4s %5s %6s %7s %6s  %s" % ["id", "grp", "jars", "cover", "par", "nodes", "ms", "notes"])
	for d: Dictionary in data["levels"]:
		_deal_if_needed(d)
		var level := LevelData.from_dict(d)
		var notes: Array[String] = []
		var cover := ExactCover.count(level)
		if cover != 1:
			notes.append("COVER=%d" % cover)
		if not Dealer.no_adjacent_pairs(level.jars) and level.id != "tut1":
			notes.append("ADJACENT")
		var t0 := Time.get_ticks_msec()
		var res := Solver.solve(BoardState.from_level(level), 200000)
		var ms := Time.get_ticks_msec() - t0
		if not res["solved"]:
			notes.append("UNSOLVED")
		if not notes.is_empty():
			failures += 1
		print("%-5s %3d %4d %5d %6d %7d %6d  %s" % [
			level.id, level.group_count(), level.jars.size(), cover, res["cost"], res["expanded"], ms, " ".join(notes)])
	JsonOut.write(path, data)
	print("checked %d levels, %d with problems" % [data["levels"].size(), failures])
	quit(1 if failures > 0 else 0)


func _deal_if_needed(d: Dictionary) -> void:
	if d.has("jars") or not d.has("deal"):
		return
	var spec: Dictionary = d["deal"]
	var shell := LevelData.from_dict(d)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec["seed"])
	# Re-deal until the solver proves it (corks and labels can make a deal impossible).
	for attempt in 50:
		var jars := Dealer.deal(shell.group_count(), int(spec.get("empties", 2)), rng)
		shell.jars = jars
		var corked := PackedInt32Array()
		for j in d.get("corked", []):
			corked.append(int(j))
		shell.corked = corked
		var labelled := {}
		for j in d.get("labelled", {}):
			labelled[int(j)] = int(d["labelled"][j])
		shell.labelled = labelled
		if Solver.solve(BoardState.from_level(shell), 200000)["solved"]:
			break
	var words: Array = []
	for jar in shell.jars:
		words.append(Array(jar).map(func(c): return shell.word(c)))
	d["jars"] = words
	var frost_bottom := int(spec.get("frost_bottom", 0))
	if frost_bottom > 0:
		var frost: Array = []
		for jar in shell.jars:
			for k in mini(frost_bottom, jar.size() - 1):
				frost.append(shell.word(jar[k]))
		d["frost"] = frost
