## Screenshot mode for checking layouts at many sizes. Needs a real window (headless renders nothing).
## godot.cmd --path . -- --shots=shots/m1 --size=1080x2400 [--only=t01,win] [--safe=60,40] [--true-size]
## The window takes the phone's shape scaled to fit the monitor (PhoneWindow); --true-size keeps real pixels.
## Audio is muted unless --with-audio (for Movie Maker captures: godot --write-movie x.avi --fixed-fps 60 -- ...).
class_name ShotRunner
extends Node

const SCENARIOS := ["home", "home_mid", "levels", "room", "profile", "shop", "streak", "streak_new", "gift", "tutorial", "t01", "t03_slip", "t07", "spicy", "assist",
	"m01", "m01_play", "m06_frost", "m07_label", "m08_cork", "worst", "need_coins", "hint", "complete_pick", "complete_fly",
	"win", "win2", "replay", "finale", "rate", "lose", "lose_gems", "need_gems", "shop_off", "play_off", "room_reveal", "pause", "restart", "test", "drag", "pick", "themes", "feature"]

var out_dir := ""
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
		if a.begins_with("--only="):
			r.only = a.substr(7).split(",")
		elif a.begins_with("--safe="):
			var p := a.substr(7).split(",")
			SafeArea.forced = {"top": float(p[0]), "bottom": float(p[1]), "left": 0.0, "right": 0.0}
	return r


func _ready() -> void:
	main = get_parent()
	if not OS.get_cmdline_user_args().has("--with-audio"):
		Sfx.set_volumes(0.0, 0.0)
	Save.data["seen_captions"] = {"budget": true}
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
			main.start_level("tut1")
		"t03_slip":
			main.start_level("tut3")
			await _legal(play, 2)
			await _slips(play, 1)
		"t07":
			main.start_level("r1-04")
			await _legal(play, 3)
		"assist":
			# The fourth try at a hard level: the help ladder's head start on its hardest label, announced.
			Save.data["seen_captions"]["hard"] = true
			main._fails = 3
			main.start_level("l1-20", true)
		"spicy":
			# A hard room level, first met: two peppers by the title and their one-time caption.
			main.start_level("l1-10")
		"m01":
			main.start_level("m01")
		"m01_play":
			main.start_level("m01")
			await _legal(play, 6)
			await _slips(play, 1)
		"m06_frost":
			main.start_level("m06")
			await _legal(play, 2)
		"m07_label":
			main.start_level("m07")
		"m08_cork":
			main.start_level("m08")
		"worst":
			main.start_level("m01")
			for i in 2:
				play.session.add_jar()
				play.board.add_jar()
			await _slips(play, 1)
		"levels":
			# A player well into the game: Room 1 done, Room 2 under way.
			var cat := Levels.catalog
			for id in cat.room_ids(1):
				var st := 3 if int(id.substr(id.length() - 1)) % 3 == 0 else 2
				Save.data["solved"][id] = {"slips": 0, "stars": st, "gold": st == 3}
			for id in cat.room_ids(2).slice(0, 12):
				Save.data["solved"][id] = {"slips": 1, "stars": 1 + int(id.substr(id.length() - 1)) % 3, "gold": false}
			main.open_levels()
			await _wait(0.4)
		"room":
			main.open_room(2, "levels")
			await _wait(0.4)
		"profile":
			Save.data["profile"]["name"] = "Mehul"
			Save.data["xp"] = 340
			main.open_profile()
			await _wait(0.4)
		"shop":
			Save.data["diamonds"] = 120
			main.go_home()
			await _wait(0.3)
			MetaSheets.shop(main)
		"shop_off", "play_off":
			# The Play testing build: no providers, so no Shop, no diamonds, coins only.
			var keep := [Store.provider, Ads.provider]
			Store.provider = "none"
			Ads.provider = "none"
			Save.data["coins"] = 20
			Save.data["inventory"] = {"hint": 0, "complete": 0}
			if name == "shop_off":
				main.go_home()
				await _wait(0.4)
				await RenderingServer.frame_post_draw
				_save(name, play)
				MetaSheets.coins_tapped(main)
				await _wait(0.4)
				await RenderingServer.frame_post_draw
				_save("coins_off", play)
			else:
				main.start_level("l2-01")
				await _wait(0.5)
				play._on_hint()
				await _wait(0.4)
				await RenderingServer.frame_post_draw
				_save(name, play)
			main.close_all_sheets()
			Store.provider = keep[0]
			Ads.provider = keep[1]
			return
		"need_gems":
			Save.data["coins"] = 20
			Save.data["diamonds"] = 40
			Save.data["inventory"] = {"hint": 0, "complete": 0}
			main.start_level("m01")
			await _wait(0.5)
			play._on_hint()
		"lose_gems":
			Save.data["coins"] = 40
			Save.data["diamonds"] = 60
			main.start_level("m01")
			await _slips(play, 4)
			await _wait(1.5)
		"win2":
			# Room 5 (3 stars up to 1 slip, 2 up to 3): two slips, then a clean finish.
			main.close_all_sheets()
			Save.data["seen_captions"]["stars"] = true
			main.start_level("l5-01")
			await _slips(play, 2)
			await _legal(play, 99)
			await _wait(2.5)
		"replay":
			# A level solved at 1 star, replayed cleanly: the new best pays the stars it adds.
			main.close_all_sheets()
			Save.data["seen_captions"]["stars"] = true
			Save.data["solved"]["r1-05"] = {"slips": 3, "stars": 1, "gold": false}
			main.start_level("r1-05")
			await _legal(play, 99)
			await _wait(2.5)
		"streak":
			Save.data["coins"] = 48221
			Save.data["streak"] = {"count": 12, "best": 18, "last_day": Wallet.today(), "savers": 1}
			main.go_home()
			await _wait(0.3)
			MetaSheets.streak(main)
		"streak_new":
			Save.data["coins"] = 8184
			Save.data["streak"] = {"count": 0, "best": 0, "last_day": -1, "savers": 0}
			Save.data["gift"]["claimed_day"] = -1
			main.go_home()
			await _wait(0.3)
			MetaSheets.gift(main)
		"rate":
			main._rate_level()
		"gift":
			var today := Wallet.today()
			Save.data["streak"] = {"count": 3, "best": 5, "last_day": today, "savers": 1}
			Save.data["gift"]["claimed_day"] = today - 1
			main.go_home()
			await _wait(0.3)
			MetaSheets.gift(main)
		"need_coins":
			Save.data["coins"] = 20
			Save.data["inventory"] = {"hint": 0, "complete": 0}
			main.start_level("m01")
			await _wait(0.5)
			play._on_hint()
		"hint":
			Save.data["coins"] = 500
			main.start_level("m01")
			await _wait(0.5)
			play._on_hint()
			await _wait(0.6)
		"complete_pick":
			Save.data["coins"] = 500
			main.start_level("m01")
			await _legal(play, 4)
			await _slips(play, 1)
			play._on_complete()
			await _wait(0.3)
			play.rail.selected = 1
			play._on_tag_picked(1)
		"complete_fly":
			Save.data["coins"] = 500
			main.start_level("m01")
			await _wait(0.5)
			play._on_complete()
			play.do_complete(0)
			await _wait(0.32)
			await RenderingServer.frame_post_draw
			_save(name, play)
			await _wait(1.4)
			_save("complete_done", play)
			return
		"room_reveal":
			main.go_home()
			await _wait(0.2)
			MetaSheets.room_reveal(main, int(Levels.catalog.room_numbers().back()), Levels.catalog.play_order()[0])
		"themes":
			# Every room's look on its own hardest level, a few moves in: the fullest boards and rails it has.
			Save.data["coins"] = 340
			for r in Levels.catalog.room_numbers():
				main.close_all_sheets()
				var ids := Levels.catalog.room_ids(r)
				main.start_level(ids[ids.size() - 1])
				await _legal(play, 5)
				await _wait(0.6)
				await RenderingServer.frame_post_draw
				_save("theme_%02d" % r, play)
				for line in play.board.misplaced():
					print("  MISPLACED ", line)
			return
		"feature":
			# The Play feature graphic (run at --size=1024x500 --true-size --rgb): the wall, jars on a plank, the name.
			main.close_all_sheets()
			var art := _FeatureArt.new()
			art.z_index = 100
			add_child(art)
			art.position = Vector2.ZERO
			art.size = get_viewport().get_visible_rect().size
			await _wait(0.4)
			await RenderingServer.frame_post_draw
			_save(name, play)
			art.queue_free()
			return
		"home":
			main.go_home()
			await _wait(0.4)
		"home_mid":
			# A player a few levels in: four jars on the shelf, two with gold lids.
			var ids := Levels.catalog.play_order()
			for i in mini(4, ids.size() - 1):
				Save.data["solved"][ids[i]] = {"slips": 0, "stars": 3 if i % 2 == 1 else 2, "gold": i % 2 == 1}
			main.go_home()
			await _wait(0.4)
		"tutorial":
			main.start_tutorial(0)
			await _wait(1.2)
		"win":
			main.close_all_sheets()
			Save.data["xp"] = 50
			Save.data["coins"] = 8184
			main.start_level("l1-01")
			await _legal(play, 99)
			await _wait(2.5)
			if OS.get_cmdline_user_args().has("--rgb"):
				await _wait(2.5)  # store shots: let the coins land
		"finale":
			# Two jars from the end of Room 1, a hard level next: the finish line and the Next button's label.
			main.close_all_sheets()
			for i in range(1, 28):
				Save.data["solved"]["l1-%02d" % i] = {"slips": 0 if i == 1 else 1, "stars": 3 if i == 1 else 2, "gold": i == 1}
			main.start_level("l1-28")
			await _legal(play, 99)
			await _wait(2.5)
		"lose":
			Save.data["coins"] = 300
			main.start_level("m01")
			await _slips(play, 4)
			await _wait(1.5)
		"pause":
			main.start_level("l2-01")
			await _wait(0.3)
			main._open_pause()
		"restart":
			# Restart from Pause after some moves: it asks first.
			main.start_level("l2-01")
			await _legal(play, 3)
			main._confirm_restart()
		"test":
			main.start_level("l2-01")
			await _wait(0.3)
			main._open_test_menu()
		"drag", "pick":
			# Real input events: press on jar 0's body (below its top card), then drag towards jar 2.
			main.start_level("m01")
			await _wait(0.4)
			var rects: Array[Rect2] = play.board.layout["jars"]
			var from := rects[0].position + Vector2(rects[0].size.x / 2.0, rects[0].size.y * 0.85)
			var to := rects[5].get_center() + Vector2(0, rects[5].size.y * 0.3)
			_touch(play.board, from, true)
			if name == "drag":
				for i in 12:
					await _wait(0.03)
					_touch(play.board, from.lerp(to, (i + 1) / 12.0), true, true)
				await _wait(0.25)
			_marker(play.board, to if name == "drag" else from)
			await _wait(0.1)
			await RenderingServer.frame_post_draw
			_save(name, play)
			if name == "drag":
				_touch(play.board, to, false)
				await _wait(0.8)
				_save("drag_dropped", play)
			for c in get_children():
				c.queue_free()
			return
	await _wait(1.4)
	await RenderingServer.frame_post_draw
	_save(name, play)
	for line in (play.board.misplaced() if play.session != null else []):
		print("  MISPLACED ", line)


func _save(name: String, play: PlayScreen) -> void:
	var img := get_viewport().get_texture().get_image()
	# Store screenshots and the feature graphic must have no transparency (Google Play).
	if OS.get_cmdline_user_args().has("--rgb"):
		img.convert(Image.FORMAT_RGB8)
	var path := "%s/%s_%dx%d.png" % [out_dir, name, img.get_width(), img.get_height()]
	img.save_png(path)
	print("shot: ", path, "  viewport=", get_viewport().get_visible_rect().size, " main=", main.size, " play=", play.size, " board=", play.board.size)


## Sends a real mouse event (the same path touch takes on Android) at a point in `ctl`'s local coordinates.
func _touch(ctl: Control, local: Vector2, down: bool, motion: bool = false) -> void:
	var screen := get_viewport().get_screen_transform() * ctl.get_global_transform_with_canvas() * local
	var ev: InputEventMouse
	if motion:
		var m := InputEventMouseMotion.new()
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		ev = m
	else:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = down
		b.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		ev = b
	ev.position = screen
	ev.global_position = screen
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


## A translucent fingertip so screenshots show where the touch is.
func _marker(ctl: Control, local: Vector2) -> void:
	var dot := _Dot.new()
	dot.position = ctl.get_global_transform_with_canvas() * local
	dot.z_index = 200
	add_child(dot)


class _Dot extends Node2D:
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 34.0, Color(0.2, 0.2, 0.9, 0.35))
		draw_arc(Vector2.ZERO, 34.0, 0, TAU, 32, Color(0.2, 0.2, 0.9, 0.8), 3.0)


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


## The Google Play feature graphic, drawn from the game's own art: a room wall, five filled jars on a plank (the middle
## one with a gold lid) and the name hand-lettered on a kraft label, with one line under it. Sized from the viewport,
## so it works at any landscape size.
class _FeatureArt extends Control:
	const ROOM := 2
	const SETS := [["Birds", "Trees", "Fruit"], ["Things that click", "Fasteners", "Citrus fruit", "Big cats"],
		["Hairstyles", "Nuts", "Things with necks", "Fractions"], ["Cleaning kit", "Birthday party", "Planets"],
		["Superhero words", "Pasta", "Knots"]]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size
		draw_texture_rect(Art.tex("feat_wall|%dx%d" % [int(w.x), int(w.y)], w, RoomArt.wall.bind(ROOM)), Rect2(Vector2.ZERO, w), false)
		var jar := Vector2(w.y * 0.25, w.y * 0.35)
		var plank := Rect2(-8.0, w.y * 0.84, w.x + 16.0, w.y * 0.06)
		var step := jar.x * 1.3
		for i in SETS.size():
			var c := Vector2(w.x / 2.0 + (i - 2) * step, plank.position.y + jar.y * 0.04)
			var layers := Materials.preserve_layers(SETS[i])
			var key := "feat_jar%d|%d" % [i, int(jar.x)]
			draw_texture_rect(Art.tex(key, jar, RoomArt.mini_jar.bind(ROOM, layers, false, i == 2)),
				Rect2(c - Vector2(jar.x / 2.0, jar.y), jar), false)
		draw_texture_rect(Art.tex("feat_plank|%d" % int(w.x), plank.size, RoomArt.plank.bind(ROOM)), plank, false)
		var title := str(ProjectSettings.get_setting("application/config/name"))
		var f := Style.hand()
		var fs := roundi(w.y * 0.2)
		var ts := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var tag := Vector2(ts.x + fs * 0.9, fs * 1.2)
		draw_set_transform(Vector2(w.x / 2.0, w.y * 0.22), deg_to_rad(-3.0), Vector2.ONE)
		draw_texture_rect(Art.tex("feat_label|%dx%d" % [int(tag.x), int(tag.y)], tag, Materials.label.bind(true)), Rect2(-tag / 2.0, tag), false)
		draw_string(f, Vector2(-ts.x / 2.0, f.get_ascent(fs) * 0.36), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.INK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var line := "Sort the words. Find the labels."
		var fb := Style.sans_bold()
		var ls := roundi(w.y * 0.055)
		var lw := fb.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, ls)
		draw_string(fb, Vector2((w.x - lw.x) / 2.0, w.y * 0.41), line, HORIZONTAL_ALIGNMENT_LEFT, -1, ls, Style.INK)
