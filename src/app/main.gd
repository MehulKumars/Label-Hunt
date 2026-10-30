## Root of the app: theme, background, the screens (Home, Play), popups, the tutorial flow and the Android Back
## button. Progress goes through Progression; Back decisions through BackPolicy.
extends Control

const T_IN := 0.25
const T_OUT := 0.18

var home: HomeScreen
var play: PlayScreen
## "home", "play" (a room or test level) or "tutorial"
var screen := "home"
var sheets: Array[Sheet] = []
var fps_label: Label
var _fails := 0
var _assisted := false
var _flags: Array[String] = []
var _tutorial_replay := false


func _ready() -> void:
	PhoneWindow.fit(get_window(), PhoneWindow.phone_from_args())
	theme = _make_theme()
	ThemeDB.fallback_font = Style.sans()
	ThemeDB.fallback_font_size = Style.BODY_FONT
	_add_background()
	Sfx.set_volumes(float(Save.setting("sound")), float(Save.setting("music")))
	Haptics.enabled = bool(Save.setting("haptics"))
	home = HomeScreen.new()
	home.play_pressed.connect(func() -> void: start_level(home.next_id))
	home.tutorial_pressed.connect(start_tutorial.bind(0, true))
	home.settings_pressed.connect(_open_settings)
	add_child(home)
	play = PlayScreen.new()
	play.finished.connect(_on_finished)
	play.pause_requested.connect(_open_pause)
	play.skip_requested.connect(_open_skip)
	play.visible = false
	add_child(play)
	fps_label = Label.new()
	fps_label.position = Vector2(8, 4)
	fps_label.z_index = 100
	fps_label.add_theme_font_size_override("font_size", 20)
	fps_label.visible = bool(Save.setting("fps")) and playtest()
	add_child(fps_label)
	var shots := ShotRunner.from_args()
	if shots:
		add_child(shots)
		return
	if not bool(Save.data["tutorial"]["done"]):
		start_tutorial(int(Save.data["tutorial"]["board"]))
	else:
		go_home()


func _process(_delta: float) -> void:
	if fps_label.visible:
		fps_label.text = "%d fps" % Engine.get_frames_per_second()


## Test tools (test menu, level select, FPS) exist in debug runs and in APKs exported with the "playtest" tag only.
static func playtest() -> bool:
	return OS.is_debug_build() or OS.has_feature("playtest")


# --- screens -------------------------------------------------------------------------------------------------------

func go_home() -> void:
	close_all_sheets()
	play.board.cancel_lift()
	home.refresh()
	_show(home, "home")


## Crossfades to a screen. The outgoing one stops taking input at once, so a double tap can't navigate twice.
func _show(target: Control, name: String) -> void:
	if not target.visible:
		Sfx.play("whoosh", 1.0, 0.05)
	screen = name
	# Home is mostly still: let the engine sleep between redraws there (battery). Play keeps full frame pacing.
	OS.low_processor_usage_mode = name == "home"
	for s: Control in [home, play]:
		if s == target or not s.visible:
			continue
		s.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
		var out := s.create_tween()
		out.tween_property(s, "modulate:a", 0.0, T_OUT)
		out.tween_callback(s.hide)
	target.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	if target.visible and target.modulate.a >= 1.0:
		return
	target.show()
	target.modulate.a = 0.0
	var tw := target.create_tween()
	tw.tween_property(target, "modulate:a", 1.0, T_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func start_tutorial(board: int, replay: bool = false) -> void:
	var ids := Levels.catalog.tutorial
	board = clampi(board, 0, ids.size() - 1)
	_tutorial_replay = replay
	if not replay:
		Save.data["tutorial"]["board"] = board
		Save.touch()
	_begin(ids[board], "tutorial", false)


func start_level(id: String, retry: bool = false) -> void:
	if id == "" or not Levels.catalog.has(id):
		go_home()
		return
	_begin(id, "play", retry)


func _begin(id: String, mode: String, retry: bool) -> void:
	close_all_sheets()
	if not retry:
		_fails = 0
	var rules: Dictionary = Save.data["rules"] if playtest() else {}
	var level: LevelData = Levels.make_level(id, bool(rules.get("one_empty", false)))
	var s := Session.new(level, rules.duplicate())
	var bonus := 0
	_assisted = false
	if _fails >= 2:
		s.budget += 1 if s.budget > 0 else 0
		bonus = 1
		_assisted = true
	play.start(id, s, bonus)
	play.set_tutorial(mode == "tutorial")
	_show(play, mode)


func _on_finished(won: bool, stats: Dictionary) -> void:
	stats["flags"] = []
	_flags = []
	Save.log_attempt(stats)
	if screen == "tutorial":
		_tutorial_won() if won else start_tutorial(Levels.catalog.tutorial.find(play.level_id), _tutorial_replay)
	elif won:
		_open_win(stats)
	else:
		_fails += 1
		_open_lose()


func _tutorial_won() -> void:
	var ids := Levels.catalog.tutorial
	var i := ids.find(play.level_id)
	if i + 1 < ids.size():
		start_tutorial(i + 1, _tutorial_replay)
		return
	if not _tutorial_replay:
		Save.data["tutorial"] = {"done": true, "board": 0}
		Save.touch()
	var s := _result_sheet("You're ready")
	s.add_label("Sort the cards. Wrong drops give clues.", 28)
	var next := Progression.next_level(Levels.catalog, Save.data)
	s.add_button("Play level %d" % (Levels.catalog.play_order().find(next) + 1) if next != "" else "Home", true,
		func() -> void: start_level(next) if next != "" else go_home(), 104.0)
	s.add_button("Home", false, go_home)
	open_sheet(s)


func _open_skip() -> void:
	if not sheets.is_empty():
		return
	play.board.cancel_lift()
	var s := Sheet.new("Skip the tutorial?")
	s.add_label("You can replay it any time from Home.", 28)
	s.add_button("Keep learning", true, s.close)
	s.add_button("Skip", false, func() -> void:
		if not _tutorial_replay:
			Save.data["tutorial"] = {"done": true, "board": 0}
			Save.touch()
		go_home())
	open_sheet(s)


# --- back ----------------------------------------------------------------------------------------------------------

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			on_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		on_back()


func on_back() -> void:
	var top: String = "" if sheets.is_empty() else sheets.back().kind
	var lifted := play.visible and (play.board.lifted_jar >= 0 or play.board.peek_mode)
	match BackPolicy.decide({"screen": screen, "sheet": top, "lifted": lifted}):
		&"close_sheet":
			sheets.back().on_back()
		&"home":
			go_home()
		&"drop_card":
			play.on_back()
		&"pause":
			_open_pause()
		&"skip_prompt":
			_open_skip()
		&"background":
			AppBack.to_background()


func open_sheet(s: Sheet) -> Sheet:
	sheets.append(s)
	s.closed.connect(func() -> void: sheets.erase(s))
	add_child(s)
	return s


func close_all_sheets() -> void:
	Sfx.muffle(false)
	for s in sheets.duplicate():
		s.queue_free()
	sheets.clear()


# --- popups --------------------------------------------------------------------------------------------------------

func _result_sheet(heading: String) -> Sheet:
	var s := Sheet.new(heading)
	s.dismissible = false
	s.kind = "result"
	return s


func _open_win(stats: Dictionary) -> void:
	var id := play.level_id
	var cat := Levels.catalog
	var res := Progression.record_win(cat, Save.data, id, int(stats["slips"]), _assisted or play.session.continues > 0)
	Save.touch()
	var room_level: bool = cat.entry(id)["track"] == "room"
	var s := _result_sheet("")
	s.dim_alpha = 0.1
	if room_level:
		var labels: Array = []
		for g: Dictionary in cat.entry(id)["data"].get("groups", []):
			labels.append(str(g.get("label", "")))
		var trophy := JarTrophy.new(Materials.preserve_layers(labels), bool(Save.data["solved"][id]["gold"]))
		s.body.add_child(trophy)
		trophy.play()
		if res["new_gold"]:
			Sfx.play_at(0.6, "bell")
	var title := s.add_label("Jar filled" if room_level else "Solved", Style.FS_72)
	title.add_theme_font_override("font", Style.hand())
	if room_level:
		s.body.add_child(_win_shelf(id))
	var line := ""
	if res["shelf_full"] >= 0:
		line = "Shelf %d is full." % (res["shelf_full"] + 1)
	elif res["new_gold"]:
		line = "Clean sort: your first gold lid." if res["first_gold"] else "Clean sort: gold lid."
	if line != "":
		s.add_label(line, Style.FS_30, true)
	var next: String = res["next"] if room_level else ""
	if cat.entry(id)["track"] == "test":
		var tests := cat.test
		next = tests[(tests.find(id) + 1) % tests.size()]
	if next != "":
		s.add_button("Next level", true, start_level.bind(next), Style.TOUCH_PRIMARY).icon = "play"
	s.add_button("Home", next == "", go_home, Style.TOUCH)
	if playtest():
		_add_flag_row(s)
	# Taps are ignored for a moment so the jar's drop onto the shelf is seen, not skipped by a fast double tap.
	s.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	get_tree().create_timer(0.4).timeout.connect(func() -> void:
		if is_instance_valid(s):
			s.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED)
	open_sheet(s)


## The row of the shelf this level's jar belongs to, with the jar dropping into its slot.
func _win_shelf(id: String) -> ShelfView:
	var cat := Levels.catalog
	var ids := cat.room_ids(cat.entry(id)["room"])
	var i := ids.find(id)
	var from := (i / 5) * 5
	var strip := ShelfView.new()
	strip.custom_minimum_size = Vector2(0, 150)
	strip.slots = ShelfView.slots_for(ids.slice(from, mini(from + 5, ids.size())), Save.data,
		Progression.next_level(cat, Save.data))
	strip.drop_index = i - from
	strip.drop_t = 0.0
	var tw := strip.create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(strip, "drop_t", 1.0, 0.7)
	Sfx.play_at(0.25 + 0.7 * 0.7, "shelf", 1.0, 0.04)
	return strip


func _add_flag_row(s: Sheet) -> void:
	s.add_label("Playtest: how was that board?", 22)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for flag in ["Too hard", "Boring", "Unfair", "Loved it"]:
		var b := PillButton.new(flag, false, 72.0)
		b.custom_minimum_size = Vector2(120, 72)
		b.font_size = 22
		b.pressed.connect(func() -> void:
			_flag(flag)
			b.primary = not b.primary
			b.queue_redraw())
		row.add_child(b)
	s.body.add_child(row)


func _flag(flag: String) -> void:
	if Save.log_entries.is_empty():
		return
	var flags: Array = Save.log_entries.back().get("flags", [])
	if flags.has(flag):
		flags.erase(flag)
	else:
		flags.append(flag)
	Save.log_entries.back()["flags"] = flags
	Save.flush_log()


func _open_lose() -> void:
	var s := _result_sheet("Out of slips")
	s.add_label("Every slip showed you part of a label.", 28)
	s.add_button("Try again", true, start_level.bind(play.level_id, true), 104.0)
	if AdPolicy.can_offer_continue(play.session.continues):
		s.add_button("Continue with 2 more slips", false, func() -> void:
			s.close()
			_rewarded("continue", func() -> void:
				play.session.continue_play(2)
				play.resume_after_continue()))
	s.add_button("Home", false, go_home)
	open_sheet(s)


## A rewarded ad through Ads. While it plays, a blocking sheet stands in (the mock provider's "video").
func _rewarded(placement: String, grant: Callable) -> void:
	var s := Sheet.new("Ad")
	s.dismissible = false
	s.kind = "blocking"
	s.add_label("Test build: a rewarded video plays here.", 26)
	open_sheet(s)
	var granted: bool = await Ads.show_rewarded(placement)
	if is_instance_valid(s):
		s.close()
	if granted:
		grant.call()


func _open_pause() -> void:
	if not sheets.is_empty():
		return
	play.board.cancel_lift()
	var s := Sheet.new("Paused")
	s.show_close = false
	Sfx.muffle(true)
	s.closed.connect(Sfx.muffle.bind(false))
	s.add_button("Resume", true, s.close)
	s.add_button("Restart level", false, start_level.bind(play.level_id, true))
	s.add_button("Rules", false, func() -> void:
		s.close()
		_open_rules())
	s.add_button("Home", false, go_home)
	_add_toggles(s)
	if playtest():
		s.add_button("Test menu", false, func() -> void:
			s.close()
			_open_test_menu())
	open_sheet(s)


## The rules on one screen, for a quick refresher mid-level (the interactive tutorial never starts mid-level).
func _open_rules() -> void:
	var s := Sheet.new("Rules")
	for line in [
		"Every jar hides one group of four. Sort the cards until each jar holds one group.",
		"Only the top card moves. Drop it on an empty jar, or on a card from its own group.",
		"A wrong drop is a slip: the card comes back, and part of that group's label is written on the rail.",
		"Four of a group screw the lid on and reveal the label.",
		"Undo is free. Peek shows one card's group. +Jar gives you room.",
	]:
		s.add_label(line, Style.FS_26)
	s.add_button("Back to the jars", true, s.close)
	open_sheet(s)


func _open_settings() -> void:
	if not sheets.is_empty():
		return
	var s := Sheet.new("Settings")
	_add_toggles(s)
	s.add_button("How to play", false, func() -> void: start_tutorial(0, true))
	s.add_button("Credits", false, func() -> void:
		s.close()
		_open_credits())
	if playtest():
		s.add_button("Test menu", false, func() -> void:
			s.close()
			_open_test_menu())
	s.add_label("Jarful %s" % ProjectSettings.get_setting("application/config/version"), 22)
	open_sheet(s)


## Everyone whose work ships in the game (the full list with links is CREDITS.md).
func _open_credits() -> void:
	var s := Sheet.new("Credits")
	for line in [
		"Made by Mehul, with Claude.",
		"Fonts: Atkinson Hyperlegible Next (Braille Institute) and Gochi Hand (Huerta Tipográfica), SIL Open Font License.",
		"Icons: Phosphor Icons, MIT License.",
		"Sounds: Kenney, rubberduck, sinny, AntumDeluge, StarNinjas, BMacZero and PWL, via OpenGameArt, CC0.",
		"Music: \"Catmint\" by Kistol, CC0.",
		"Engine: Godot, MIT License.",
	]:
		s.add_label(line, Style.FS_26)
	open_sheet(s)


func _add_toggles(s: Sheet) -> void:
	s.add_switch("Music", float(Save.setting("music")) > 0.0, func(v: bool) -> void:
		Save.set_setting("music", 0.7 if v else 0.0)
		Sfx.set_volumes(float(Save.setting("sound")), float(Save.setting("music"))))
	s.add_switch("Sound", float(Save.setting("sound")) > 0.0, func(v: bool) -> void:
		Save.set_setting("sound", 1.0 if v else 0.0)
		Sfx.set_volumes(float(Save.setting("sound")), float(Save.setting("music"))))
	s.add_switch("Haptics", bool(Save.setting("haptics")), func(v: bool) -> void:
		Save.set_setting("haptics", v)
		Haptics.enabled = v)
	s.add_switch("Reduce motion", bool(Save.setting("reduce_motion")), func(v: bool) -> void:
		Save.set_setting("reduce_motion", v)
		play.board.reduce_motion = v)


func _open_test_menu() -> void:
	var s := Sheet.new("Test menu")
	var rules: Dictionary = Save.data["rules"]
	var toggles := _grid(s, 2)
	var rule := func(key: String, text: String, default: bool) -> void:
		_compact(s.add_toggle(text, bool(rules.get(key, default)), func(v: bool) -> void:
			rules[key] = v
			Save.write()), toggles)
	rule.call("tag_on_slip", "Slip tags", true)
	rule.call("pair_reveal", "Pair hint", true)
	rule.call("pour", "Pour runs", false)
	rule.call("one_empty", "1 empty jar", false)
	_compact(s.add_toggle("Stars only", rules.get("mode", "budget") == "stars", func(v: bool) -> void:
		rules["mode"] = "stars" if v else "budget"
		Save.write()), toggles)
	_compact(s.add_toggle("FPS", fps_label.visible, func(v: bool) -> void:
		fps_label.visible = v
		Save.set_setting("fps", v)), toggles)
	var cat := Levels.catalog
	var levels := _grid(s, 6)
	var ids: PackedStringArray = cat.play_order()
	ids.append_array(cat.test)
	for id in ids:
		var e := cat.entry(id)
		var name := str(cat.play_order().find(id) + 1) if e["track"] == "room" else "T%d" % e["number"]
		var b := PillButton.new(name, id == play.level_id, 60.0)
		b.custom_minimum_size = Vector2(80, 60)
		b.font_size = 22
		b.pressed.connect(start_level.bind(id))
		levels.add_child(b)
	var tools := _grid(s, 2)
	_compact(s.add_button("Copy log (%d)" % Save.log_entries.size(), false, func() -> void:
		DisplayServer.clipboard_set(_playtest_text())
		play.caption.say("Log copied: paste it to Claude")), tools)
	_compact(s.add_button("Reset log", false, func() -> void:
		Save.data["seen_captions"] = {}
		Save.clear_log()
		Save.write()
		play.caption.say("Log and captions reset")), tools)
	_compact(s.add_button("Reset progress", false, func() -> void:
		Save.reset()
		start_tutorial(0)), tools)
	_compact(s.add_button("Close", false, s.close), tools)
	open_sheet(s)


func _grid(s: Sheet, columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	s.body.add_child(g)
	return g


## Moves a button the sheet just added into a grid, at a compact size.
func _compact(b: PillButton, grid: GridContainer) -> void:
	b.get_parent().remove_child(b)
	b.custom_minimum_size = Vector2(0, 68)
	b.font_size = 24
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(b)


func _playtest_text() -> String:
	var lines: Array[String] = ["Jarful playtest log %s (%s)" % [ProjectSettings.get_setting("application/config/version"), OS.get_model_name()]]
	for e: Dictionary in Save.log_entries:
		if e.is_empty():
			continue
		var pairs: Array = e.get("slip_pairs", [])
		lines.append("%s %s slips=%d/%d moves=%d undo=%d peek=%d jar=%d cont=%d %ss flags=%s mode=%s pairs=%s" % [
			e.get("level"), "WIN" if e.get("won") else "LOSE", e.get("slips", 0), e.get("budget", 0), e.get("moves", 0),
			e.get("undos", 0), e.get("peeks", 0), e.get("jars_added", 0), e.get("continues", 0), e.get("secs", 0),
			",".join(e.get("flags", [])), e.get("rules", {}).get("mode", "?"),
			";".join(pairs.map(func(p: Array) -> String: return "%s>%s" % [p[0], p[1]]))])
	return "\n".join(lines)


# --- look ----------------------------------------------------------------------------------------------------------

## The pantry wall: warm light from the top left (the same light the materials use), falling off to the corners.
func _add_background() -> void:
	var g := Gradient.new()
	g.set_color(0, Style.WALL_LIGHT)
	g.add_point(0.55, Style.PAPER)
	g.set_color(g.get_point_count() - 1, Style.WALL_SHADE)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.18, 0.08)
	tex.fill_to = Vector2(1.15, 1.05)
	tex.width = 128
	tex.height = 256
	var bg := TextureRect.new()
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = Style.sans()
	t.default_font_size = Style.BODY_FONT
	t.set_color("font_color", "Label", Style.INK)
	return t
