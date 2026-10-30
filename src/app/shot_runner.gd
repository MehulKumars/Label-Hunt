## Screenshot mode for checking layouts at many sizes. Needs a real window (headless renders nothing).
## godot.cmd --path . -- --shots=shots/m1 --size=1080x2400 [--only=t01,win] [--safe=60,40]
class_name ShotRunner
extends Node

const SCENARIOS := ["t01", "t03_slip", "t07", "m01", "m01_play", "m06_frost", "m07_label", "m08_cork", "worst", "win", "lose", "pause", "test"]

var out_dir := ""
var window := Vector2i(720, 1280)
var only: PackedStringArray = []
var main: Node


static func from_args() -> ShotRunner:
	var r: ShotRunner = null
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--shots="):
			r = ShotRunner.new()
			r.out_dir = a.substr(8)
	if r == null:
		return null
	for a in args:
		if a.begins_with("--size="):
			var p := a.substr(7).split("x")
			r.window = Vector2i(int(p[0]), int(p[1]))
		elif a.begins_with("--only="):
			r.only = a.substr(7).split(",")
		elif a.begins_with("--safe="):
			var p := a.substr(7).split(",")
			SafeArea.forced = {"top": float(p[0]), "bottom": float(p[1]), "left": 0.0, "right": 0.0}
	return r


func _ready() -> void:
	main = get_parent()
	Sfx.set_enabled(false)
	Save.data["seen_captions"] = {"budget": true}
	DisplayServer.window_set_size(window)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _wait(0.5)
	for name in SCENARIOS:
		if only.is_empty() or only.has(name):
			await _run(name)
	get_tree().quit()


func _run(name: String) -> void:
	var play: PlayScreen = main.play
	match name:
		"t01":
			main.start_level(0)
		"t03_slip":
			main.start_level(2)
			await _legal(play, 2)
			await _slips(play, 1)
		"t07":
			main.start_level(6)
			await _legal(play, 3)
		"m01":
			main.start_level(10)
		"m01_play":
			main.start_level(10)
			await _legal(play, 6)
			await _slips(play, 1)
		"m06_frost":
			main.start_level(15)
			await _legal(play, 2)
		"m07_label":
			main.start_level(16)
		"m08_cork":
			main.start_level(17)
		"worst":
			main.start_level(10)
			for i in 2:
				play.session.add_jar()
				play.board.add_jar()
			await _slips(play, 1)
		"win":
			main.start_level(0)
			await _legal(play, 99)
			await _wait(2.5)
		"lose":
			main.start_level(10)
			await _slips(play, 4)
			await _wait(1.5)
		"pause":
			main.start_level(3)
			await _wait(0.3)
			main._open_pause()
		"test":
			main.start_level(3)
			await _wait(0.3)
			main._open_test_menu()
	await _wait(1.4)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s_%dx%d.png" % [out_dir, name, img.get_width(), img.get_height()]
	img.save_png(path)
	print("shot: ", path, "  viewport=", get_viewport().get_visible_rect().size, " main=", main.size, " play=", play.size, " board=", play.board.size)
	for line in play.board.misplaced():
		print("  MISPLACED ", line)


## Plays the solver's next n moves through the real play screen.
func _legal(play: PlayScreen, n: int) -> void:
	for i in n:
		if play.session.is_over():
			return
		var res := Solver.solve(play.session.board, 20000)
		if not res["solved"] or (res["path"] as Array).is_empty():
			return
		var mv: Vector2i = res["path"][0]
		play._on_drop(mv.x, mv.y)
		await _wait(0.3)


## Makes n wrong drops the player couldn't have ruled out (first opening a target if every jar is full or empty).
func _slips(play: PlayScreen, n: int) -> void:
	for i in n:
		if play.session.is_over():
			return
		var b := play.session.board
		var has_target := false
		for t in b.jar_count():
			if b.size(t) > 0 and not b.is_full(t) and not b.is_closed(t):
				has_target = true
		if not has_target:
			await _legal(play, 1)
		var done := false
		for a in b.jar_count():
			if done or not b.can_take(a):
				continue
			for t in b.jar_count():
				if t == a or b.is_closed(t) or b.is_full(t) or b.size(t) == 0:
					continue
				var c := b.top(a)
				if b.drop_check(c, t) == BoardState.Drop.WRONG and not play.session.is_proven_wrong(c, t):
					play._on_drop(a, t)
					done = true
					break
		await _wait(0.45)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
