## Prints one bot game move by move (debug aid). Run: godot --headless --path . -s res://tools/trace_bot.gd -- --level=r1-01 --profile=average --seed=1
extends SceneTree

const FILES := ["res://data/levels/tutorial.json", "res://data/levels/room1.json", "res://data/levels/test.json"]


func _init() -> void:
	var id := "r1-01"
	var prof := "average"
	var game_seed := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			id = a.substr(8)
		elif a.begins_with("--profile="):
			prof = a.substr(10)
		elif a.begins_with("--seed="):
			game_seed = int(a.substr(7))
	var cat := Catalog.from_files(PackedStringArray(FILES))
	if cat.has(id):
		var b := Bot.new()
		b.level = cat.level(id)
		b.profile = Bot.PROFILES[prof]
		b.rng = RandomNumberGenerator.new()
		b.rng.seed = game_seed
		b.trace = true
		print(b._run({}))
	else:
		print("no level ", id)
	quit()
