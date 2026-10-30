## Prints one bot game move by move (debug aid). Run: godot --headless --path . -s res://tools/trace_bot.gd -- --level=t02 --profile=average --seed=1
extends SceneTree


func _init() -> void:
	var id := "t02"
	var prof := "average"
	var game_seed := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			id = a.substr(8)
		elif a.begins_with("--profile="):
			prof = a.substr(10)
		elif a.begins_with("--seed="):
			game_seed = int(a.substr(7))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/handmade.json"))
	for d: Dictionary in data["levels"]:
		if d["id"] == id:
			var level := LevelData.from_dict(d)
			var b := Bot.new()
			b.level = level
			b.profile = Bot.PROFILES[prof]
			b.rng = RandomNumberGenerator.new()
			b.rng.seed = game_seed
			b.trace = true
			print(b._run({}))
	quit()
