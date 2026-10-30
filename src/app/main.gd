## Root of the app: theme, background, the play screen, popups and the Android Back button.
extends Control

var play: PlayScreen
var sheets: Array[Sheet] = []
var fps_label: Label
var _fails := 0
var _flags: Array[String] = []


func _ready() -> void:
	theme = _make_theme()
	ThemeDB.fallback_font = Style.sans()
	ThemeDB.fallback_font_size = Style.BODY_FONT
	_add_background()
	Sfx.set_enabled(bool(Save.setting("sound")))
	Haptics.enabled = bool(Save.setting("haptics"))
	play = PlayScreen.new()
	play.finished.connect(_on_finished)
	play.pause_requested.connect(_open_pause)
	add_child(play)
	fps_label = Label.new()
	fps_label.position = Vector2(8, 4)
	fps_label.z_index = 100
	fps_label.add_theme_font_size_override("font_size", 20)
	fps_label.visible = bool(Save.setting("fps"))
	add_child(fps_label)
	var shots := ShotRunner.from_args()
	if shots:
		add_child(shots)
		return
	start_level(int(Save.data["level"]))


func _process(_delta: float) -> void:
	if fps_label.visible:
		fps_label.text = "%d fps" % Engine.get_frames_per_second()


func start_level(i: int, retry: bool = false) -> void:
	close_all_sheets()
	if not retry:
		_fails = 0
	i = clampi(i, 0, Levels.count() - 1)
	var rules: Dictionary = Save.data["rules"]
	var level: LevelData = Levels.make_level(i, bool(rules.get("one_empty", false)))
	var s := Session.new(level, rules.duplicate())
	var bonus := 0
	if _fails >= 2:
		s.budget += 1 if s.budget > 0 else 0
		bonus = 1
	play.start(i, s, bonus)
	Save.data["level"] = i
	Save.write()


func _on_finished(won: bool, stats: Dictionary) -> void:
	stats["flags"] = []
	_flags = []
	Save.log_attempt(stats)
	if won:
		_open_win(stats)
	else:
		_fails += 1
		_open_lose()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			on_back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			Save.write()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		on_back()


## Back: close the top popup, else put down a lifted card, else pause.
func on_back() -> void:
	if not sheets.is_empty():
		sheets.back().on_back()
	elif not play.on_back():
		_open_pause()


func open_sheet(s: Sheet) -> Sheet:
	sheets.append(s)
	s.closed.connect(func() -> void: sheets.erase(s))
	add_child(s)
	return s


func close_all_sheets() -> void:
	for s in sheets.duplicate():
		s.queue_free()
	sheets.clear()


# --- popups --------------------------------------------------------------------------------------------------------

func _open_win(stats: Dictionary) -> void:
	var s := _BackSheet.new("Solved!")
	s.back_action = _next_level
	s.add_label("%d slips · %d moves · %ss" % [stats["slips"], stats["moves"], stats["secs"]], 26)
	s.add_button("Next", true, _next_level, 110.0)
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
	open_sheet(s)


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


func _next_level() -> void:
	var next := play.level_index + 1
	if next >= Levels.count():
		next = 0
	start_level(next)


func _open_lose() -> void:
	var s := _BackSheet.new("Out of slips")
	s.back_action = func() -> void: start_level(play.level_index, true)
	s.add_label("Every slip showed you part of a label.", 26)
	s.add_button("Retry", true, func() -> void: start_level(play.level_index, true), 110.0)
	s.add_button("Continue +2 slips (ad)", false, func() -> void:
		s.close()
		_mock_ad(func() -> void:
			play.session.continue_play(2)
			play.resume_after_continue()))
	open_sheet(s)


func _mock_ad(grant: Callable) -> void:
	var s := Sheet.new("Ad")
	s.add_label("Test build: a rewarded video plays here later.", 26)
	open_sheet(s)
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_instance_valid(s):
			s.close()
		grant.call())


func _open_pause() -> void:
	if not sheets.is_empty():
		return
	play.board.cancel_lift()
	var s := Sheet.new("Paused")
	s.add_button("Resume", true, s.close)
	s.add_button("Restart level", false, func() -> void: start_level(play.level_index, true))
	s.add_toggle("Sound", bool(Save.setting("sound")), func(v: bool) -> void:
		Save.set_setting("sound", v)
		Sfx.set_enabled(v))
	s.add_toggle("Haptics", bool(Save.setting("haptics")), func(v: bool) -> void:
		Save.set_setting("haptics", v)
		Haptics.enabled = v)
	s.add_toggle("Reduce motion", bool(Save.setting("reduce_motion")), func(v: bool) -> void:
		Save.set_setting("reduce_motion", v)
		play.board.reduce_motion = v)
	s.add_button("Test menu", false, func() -> void:
		s.close()
		_open_test_menu())
	open_sheet(s)


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
	s.add_button("Apply rules: restart level", true, func() -> void: start_level(play.level_index, true), 80.0)
	var levels := _grid(s, 6)
	for i in Levels.count():
		var name := str(i + 1) if i < 10 else "B%d" % (i - 9)
		var b := PillButton.new(name, i == play.level_index, 60.0)
		b.custom_minimum_size = Vector2(80, 60)
		b.font_size = 22
		b.pressed.connect(start_level.bind(i))
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
	_compact(s.add_button("Background", false, func() -> void: AppBack.to_background()), tools)
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

func _add_background() -> void:
	var g := Gradient.new()
	g.set_color(0, Style.PAPER)
	g.set_color(1, Style.PAPER_DEEP)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
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


## A sheet whose Back runs a custom action (Win: Next, Lose: Retry).
class _BackSheet extends Sheet:
	var back_action: Callable

	func on_back() -> bool:
		if back_action.is_valid():
			back_action.call()
		return true
