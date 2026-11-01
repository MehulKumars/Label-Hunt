## Root of the app: theme, the room's wall, the screens (Home, Levels, a room, Profile, Play), popups, the tutorial
## flow, resume and the Android Back button. Progress goes through Progression and Wallet; Back through BackPolicy.
extends Control

const T_IN := 0.25
const T_OUT := 0.18

var home: HomeScreen
var levels: LevelsScreen
var room_view: RoomScreen
var profile: ProfileScreen
var play: PlayScreen
## "home", "levels", "room", "profile", "play" (a room or test level) or "tutorial"
var screen := "home"
var sheets: Array[Sheet] = []
var fps_label: Label
var backdrop: RoomBackdrop
var _fails := 0
var _assisted := false
var _tutorial_replay := false
var _toast: Caption


func _ready() -> void:
	PhoneWindow.fit(get_window(), PhoneWindow.phone_from_args())
	theme = _make_theme()
	ThemeDB.fallback_font = Style.sans()
	ThemeDB.fallback_font_size = Style.BODY_FONT
	backdrop = RoomBackdrop.new()
	add_child(backdrop)
	Sfx.set_volumes(float(Save.setting("sound")), float(Save.setting("music")))
	Haptics.enabled = bool(Save.setting("haptics"))
	home = HomeScreen.new()
	home.play_pressed.connect(func() -> void: start_level(home.next_id))
	home.settings_pressed.connect(_open_settings)
	home.levels_pressed.connect(open_levels)
	home.shop_pressed.connect(func() -> void: _sheet_once(MetaSheets.shop))
	home.profile_pressed.connect(open_profile)
	home.gift_pressed.connect(func() -> void: _sheet_once(MetaSheets.gift))
	home.streak_pressed.connect(func() -> void: _sheet_once(MetaSheets.streak))
	home.room_pressed.connect(func() -> void: open_room(home.room, "home"))
	add_child(home)
	levels = LevelsScreen.new()
	levels.back_pressed.connect(go_home)
	levels.room_pressed.connect(func(r: int) -> void: open_room(r, "levels"))
	levels.visible = false
	add_child(levels)
	room_view = RoomScreen.new()
	room_view.back_pressed.connect(on_back)
	room_view.level_pressed.connect(_on_room_level)
	room_view.visible = false
	add_child(room_view)
	profile = ProfileScreen.new()
	profile.back_pressed.connect(go_home)
	profile.avatar_pressed.connect(func() -> void: _sheet_once(MetaSheets.avatar_picker))
	profile.name_pressed.connect(func() -> void: _sheet_once(MetaSheets.rename))
	profile.visible = false
	add_child(profile)
	play = PlayScreen.new()
	play.finished.connect(_on_finished)
	play.pause_requested.connect(_open_pause)
	play.skip_requested.connect(_open_skip)
	play.shop_requested.connect(func() -> void: _sheet_once(MetaSheets.shop))
	play.need_coins.connect(func(item: String) -> void: _sheet_once(MetaSheets.need_coins.bind(item)))
	play.progress_changed.connect(_save_board)
	play.visible = false
	add_child(play)
	_toast = Caption.new()
	_toast.z_index = 60
	add_child(_toast)
	fps_label = Label.new()
	fps_label.position = Vector2(8, 4)
	fps_label.z_index = 100
	fps_label.add_theme_font_size_override("font_size", 20)
	fps_label.visible = bool(Save.setting("fps")) and Build.playtest()
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


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			on_back()
		NOTIFICATION_RESIZED:
			if _toast != null:
				_toast.position = Vector2(0, size.y * 0.42)
				_toast.size = Vector2(size.x, 64)


## A short line in the middle of the screen (rewards claimed, a purchase).
func toast(text: String) -> void:
	if text == "":
		return
	_toast.position = Vector2(0, size.y * 0.42)
	_toast.size = Vector2(size.x, 64)
	_toast.say(text, 2.0)


# --- screens -------------------------------------------------------------------------------------------------------

func go_home() -> void:
	close_all_sheets()
	play.board.cancel_lift()
	refresh_home()
	_show(home, "home")


func refresh_home() -> void:
	home.refresh()
	backdrop.set_room(home.room)
	backdrop.props_rect = home.props_band


func open_levels() -> void:
	close_all_sheets()
	levels.refresh()
	backdrop.set_room(Progression.current_room(Levels.catalog, Save.data))
	_show(levels, "levels")


func open_room(r: int, origin: String) -> void:
	close_all_sheets()
	var ids := Levels.catalog.room_ids(r)
	if ids.is_empty() or not Progression.is_unlocked(Levels.catalog, Save.data, ids[0]):
		return
	room_view.show_room(r, origin)
	backdrop.set_room(r)
	_show(room_view, "room")


func open_profile() -> void:
	close_all_sheets()
	profile.refresh()
	_show(profile, "profile")


func refresh_profile() -> void:
	if profile.visible:
		profile.refresh()
	home.refresh()


func _on_room_level(id: String) -> void:
	if Save.data["solved"].has(id):
		_sheet_once(MetaSheets.level_card.bind(id))
	else:
		start_level(id)


## Crossfades to a screen. The outgoing one stops taking input at once, so a double tap can't navigate twice.
func _show(target: Control, name: String) -> void:
	if not target.visible:
		Sfx.play("whoosh", 1.0, 0.05)
	screen = name
	backdrop.props_visible = name == "home"
	# Menus are mostly still: let the engine sleep between redraws there (battery). Play keeps full frame pacing.
	OS.low_processor_usage_mode = name not in ["play", "tutorial"]
	for s: Control in [home, levels, room_view, profile, play]:
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
	var rules: Dictionary = Save.data["rules"] if Build.playtest() else {}
	var level: LevelData = Levels.make_level(id, bool(rules.get("one_empty", false)))
	var s: Session = null
	var saved: Dictionary = Save.data["board"]
	# Resume: the same level, unchanged since it was saved, replayed action by action.
	if mode == "play" and not retry and str(saved.get("id", "")) == id and str(saved.get("fingerprint", "")) == level.fingerprint():
		s = Session.replay(level, rules.duplicate(), saved.get("log", []))
		if s != null:
			_fails = int(saved.get("fails", 0))
			_assisted = bool(saved.get("assisted", false))
	var bonus := 0
	if s == null:
		s = Session.new(level, rules.duplicate())
		_assisted = false
		if _fails >= 2:
			# The assist after two fails: one more slip and a free Hint (gold is withheld).
			if s.budget > 0:
				s.grant_slips(1)
			bonus = 1
			_assisted = true
	var e := Levels.catalog.entry(id)
	var look := int(e["room"]) if e["track"] == "room" else 1
	backdrop.set_room(look)
	play.board.room = look
	play.start(id, s, bonus)
	play.set_tutorial(mode == "tutorial")
	_show(play, mode)
	if mode == "play":
		_save_board()


## The attempt in progress, so a killed app resumes it exactly (Session.replay). Tutorial boards aren't saved.
func _save_board() -> void:
	if screen != "play" or play.session == null or Levels.catalog.entry(play.level_id).get("track", "") == "tutorial":
		return
	if play.session.is_over():
		Save.data["board"] = {}
	else:
		Save.data["board"] = {"id": play.level_id, "fingerprint": play.session.level.fingerprint(),
			"log": play.session.log.duplicate(true), "fails": _fails, "assisted": _assisted}
	Save.touch()


func _on_finished(won: bool, stats: Dictionary) -> void:
	stats["flags"] = []
	Save.log_attempt(stats)
	if screen == "tutorial":
		_tutorial_won() if won else start_tutorial(Levels.catalog.tutorial.find(play.level_id), _tutorial_replay)
		return
	Save.data["board"] = {}
	Save.touch()
	if won:
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
	if not Save.data["intro_gifts"].has("starter"):
		Wallet.starter_gift()
		s.add_label("+%d coins to start" % Economy.STARTER_COINS, Style.FS_30, true)
	var next := Progression.next_level(Levels.catalog, Save.data)
	s.add_button("Play level %d" % (Levels.catalog.order_index(next) + 1) if next != "" else "Home", true,
		func() -> void: start_level(next) if next != "" else go_home(), 104.0)
	s.add_button("Home", false, go_home)
	open_sheet(s)


func _open_skip() -> void:
	if not sheets.is_empty():
		return
	play.board.cancel_lift()
	var s := Sheet.new("Skip the tutorial?")
	s.add_label("You can replay it any time from Settings.", 28)
	s.add_button("Keep learning", true, s.close)
	s.add_button("Skip", false, func() -> void:
		if not _tutorial_replay:
			Save.data["tutorial"] = {"done": true, "board": 0}
			Save.touch()
			Wallet.starter_gift()
		go_home())
	open_sheet(s)


# --- back ----------------------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		on_back()


func on_back() -> void:
	var top: String = "" if sheets.is_empty() else sheets.back().kind
	var lifted := play.visible and (play.board.lifted_jar >= 0 or play.choosing)
	match BackPolicy.decide({"screen": screen, "sheet": top, "lifted": lifted, "origin": room_view.origin}):
		&"close_sheet":
			sheets.back().on_back()
		&"home":
			go_home()
		&"levels":
			open_levels()
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


## Opens a sheet built by `build(main)` unless one is already open (a double tap opens one).
func _sheet_once(build: Callable) -> void:
	if sheets.is_empty():
		build.call(self)


func close_all_sheets() -> void:
	Sfx.muffle(false)
	for s in sheets.duplicate():
		s.queue_free()
	sheets.clear()
	if play.choosing:
		play.cancel_complete()


# --- popups --------------------------------------------------------------------------------------------------------

func _result_sheet(heading: String) -> Sheet:
	var s := Sheet.new(heading)
	s.dismissible = false
	s.kind = "result"
	return s


func _open_win(stats: Dictionary) -> void:
	var id := play.level_id
	var cat := Levels.catalog
	var entry := cat.entry(id)
	var room_level: bool = entry["track"] == "room"
	# Any help (a Hint, Complete, Continue or the two-fails assist) keeps the gold lid for a clean sort.
	var helped := _assisted or play.session.continues > 0 or play.session.hints > 0 or play.session.completes > 0
	var res := Progression.record_win(cat, Save.data, id, int(stats["slips"]), helped)
	var before := Wallet.level_info()
	# The HUD pill keeps its number until the earned coins fly into it.
	play.coins.hold = room_level
	var rewards := Wallet.record_win(entry, res) if room_level else {}
	var s := _result_sheet("")
	s.dim_alpha = 0.1
	if room_level:
		var labels: Array = []
		for g: Dictionary in entry["data"].get("groups", []):
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
		var row := RewardRow.new()
		row.coins = int(rewards["coins"])
		row.xp = int(rewards["xp"])
		row.before = before
		row.after = Wallet.level_info()
		row.ups = rewards["ups"]
		row.fit()
		row.offer_double(Ads.rewarded_ready("win_double"))
		row.double_pressed.connect(func() -> void:
			rewarded("win_double", func() -> void:
				play.coins.hold = true
				Wallet.grant({"coins": row.coins})
				row.doubled()))
		s.body.add_child(row)
		row.coins_landed.connect(func(from: Vector2) -> void:
			var release := func() -> void:
				play.coins.hold = false
				play.coins.set_value(Wallet.coins())
			if bool(Save.setting("reduce_motion")):
				release.call()
			else:
				CoinFlight.launch(self, from, play.coins.coin_center()).landed.connect(release))
		row.play(0.95)
		if row.coins == 0:
			play.coins.hold = false
	# One line at most, the biggest news first: the card stays calm, and a gift waiting shows on the Home button.
	var lines: Array[String] = []
	if room_level:
		if res["room_done"]:
			lines.append("Room complete: +%d coins." % Economy.ROOM_COINS)
		if not (rewards["milestone"] as Dictionary).is_empty():
			lines.append("%d-day streak: %s" % [rewards["streak"]["count"], MetaSheets._reward_text(rewards["milestone"])])
		for up: Dictionary in rewards["ups"]:
			lines.append("Rank %d: %s" % [up["level"], MetaSheets._reward_text(up["rewards"])])
		if res["new_gold"]:
			lines.append("Clean sort: your first gold lid." if res["first_gold"] else "Clean sort: gold lid.")
		elif res["shelf_full"] >= 0:
			lines.append("Shelf %d is full." % (res["shelf_full"] + 1))
	if not lines.is_empty():
		s.add_label(lines[0], Style.FS_26, true)
	var next: String = res["next"] if room_level else ""
	if entry["track"] == "test":
		var tests := cat.test
		next = tests[(tests.find(id) + 1) % tests.size()]
	if next != "":
		var next_room := int(cat.entry(next)["room"])
		var new_room: bool = room_level and next_room != int(entry["room"]) and cat.entry(next)["track"] == "room"
		s.add_button("Next level", true, func() -> void:
			if new_room:
				close_all_sheets()
				MetaSheets.room_reveal(self, next_room, next)
			else:
				start_level(next), Style.TOUCH_PRIMARY).icon = "play"
	var gift_waiting: bool = room_level and rewards["gift_ready"]
	var home_btn := s.add_button("Home: gift ready" if gift_waiting else "Home", next == "", go_home, Style.TOUCH)
	if gift_waiting:
		home_btn.icon = "gift"
	if Build.playtest():
		_add_rate_button(s)
	# Taps are ignored for a moment so the jar's drop onto the shelf is seen, not skipped by a fast double tap.
	s.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	get_tree().create_timer(0.4).timeout.connect(func() -> void:
		if is_instance_valid(s):
			s.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED)
	open_sheet(s)


## The row of the shelf this level's jar belongs to, with the jar dropping into its slot.
func _win_shelf(id: String) -> ShelfView:
	var cat := Levels.catalog
	var room := int(cat.entry(id)["room"])
	var ids := cat.room_ids(room)
	var i := ids.find(id)
	var from := (i / 5) * 5
	var strip := ShelfView.new()
	strip.room = room
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


## Test builds: a quiet star in the card's corner opens the level's rating (it goes in the playtest log).
func _add_rate_button(s: Sheet) -> void:
	var b := PillButton.new("", false, 64.0)
	b.icon = "star"
	b.custom_minimum_size = Vector2(72, 64)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.offset_left = -84.0
	b.offset_right = -12.0
	b.offset_top = 12.0
	b.offset_bottom = 76.0
	b.pressed.connect(_rate_level)
	s.panel.add_child(b)


func _rate_level() -> void:
	var s := Sheet.new("Rate this level")
	s.add_label("Test builds only. Your picks help tune the difficulty.", Style.FS_26)
	var flags: Array = [] if Save.log_entries.is_empty() else Save.log_entries.back().get("flags", [])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for flag: String in ["Too hard", "Boring", "Unfair", "Loved it"]:
		var b := PillButton.new(flag, flags.has(flag), Style.TOUCH)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			_flag(flag)
			b.primary = not b.primary
			b.queue_redraw())
		grid.add_child(b)
	s.body.add_child(grid)
	s.add_button("Done", false, s.close, Style.TOUCH)
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


## Out of slips: Try again, or Continue (+2 slips) for an optional ad or coins the player already has.
## Never a link to the Shop here (the ethics line: no upsell on the fail screen).
func _open_lose() -> void:
	var s := _result_sheet("Out of slips")
	s.add_label("Every slip showed you part of a label.", 28)
	s.add_button("Try again", true, start_level.bind(play.level_id, true), 104.0)
	if AdPolicy.can_offer_continue(play.session.continues):
		var go_on := func() -> void:
			play.session.continue_play(2)
			play.resume_after_continue()
		if Ads.rewarded_ready("continue"):
			s.add_button("Watch an ad: 2 more slips", false, func() -> void:
				s.close()
				rewarded("continue", go_on))
		var price := int(Economy.PRICES["continue"])
		if Wallet.coins() >= price:
			s.add_button("2 more slips: %d coins" % price, false, func() -> void:
				if Wallet.pay(price):
					s.close()
					go_on.call())
	s.add_button("Home", false, go_home)
	open_sheet(s)


## A rewarded ad through Ads. While it plays, a blocking sheet stands in (the mock provider's "video").
func rewarded(placement: String, grant: Callable) -> void:
	if not Ads.rewarded_ready(placement):
		toast("No ad right now. Try again soon.")
		return
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


## Buys a coin pack through Store (a test purchase in playtest builds).
func purchase(id: String) -> void:
	var s := Sheet.new("Purchase")
	s.dismissible = false
	s.kind = "blocking"
	s.add_label("Test build: no money changes hands.", 26)
	open_sheet(s)
	var ok: bool = await Store.purchase(id)
	if is_instance_valid(s):
		s.close()
	if ok:
		Sfx.play("coin", 1.0, 0.0)
		toast("+%s coins" % CoinPill._fmt(int(Economy.pack(id).get("coins", 0))))


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
	if Build.playtest():
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
		"Undo and +Jar are free. A Hint shows a good move. Complete fills a jar you pick.",
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
	if Build.playtest():
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
	# Level select: a room, then its levels.
	var cat := Levels.catalog
	var rooms := _grid(s, 6)
	var level_grid := _grid(s, 6)
	var show_room := func(r: int) -> void:
		for c in level_grid.get_children():
			c.queue_free()
		var ids: PackedStringArray = cat.room_ids(r) if r > 0 else cat.test
		for id in ids:
			var e := cat.entry(id)
			var b := PillButton.new(str(cat.order_index(id) + 1) if e["track"] == "room" else "T%d" % e["number"], id == play.level_id, 60.0)
			b.custom_minimum_size = Vector2(80, 60)
			b.font_size = 22
			b.pressed.connect(start_level.bind(id))
			level_grid.add_child(b)
	for r in cat.room_numbers() + [0]:
		var rb := PillButton.new("R%d" % r if r > 0 else "Test", false, 60.0)
		rb.custom_minimum_size = Vector2(80, 60)
		rb.font_size = 22
		rb.pressed.connect(show_room.bind(r))
		rooms.add_child(rb)
	show_room.call(Progression.current_room(cat, Save.data))
	var tools := _grid(s, 2)
	_compact(s.add_button("Copy log (%d)" % Save.log_entries.size(), false, func() -> void:
		DisplayServer.clipboard_set(_playtest_text())
		toast("Log copied: paste it to Claude")), tools)
	_compact(s.add_button("+500 coins", false, func() -> void:
		Wallet.grant({"coins": 500})
		toast("+500 coins (test)")), tools)
	_compact(s.add_button("Reset log", false, func() -> void:
		Save.data["seen_captions"] = {}
		Save.clear_log()
		Save.write()
		toast("Log and captions reset")), tools)
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
		lines.append("%s %s slips=%d/%d moves=%d undo=%d hint=%d complete=%d jar=%d cont=%d %ss flags=%s mode=%s pairs=%s" % [
			e.get("level"), "WIN" if e.get("won") else "LOSE", e.get("slips", 0), e.get("budget", 0), e.get("moves", 0),
			e.get("undos", 0), e.get("hints", 0), e.get("completes", 0), e.get("jars_added", 0), e.get("continues", 0),
			e.get("secs", 0), ",".join(e.get("flags", [])), e.get("rules", {}).get("mode", "?"),
			";".join(pairs.map(func(p: Array) -> String: return "%s>%s" % [p[0], p[1]]))])
	return "\n".join(lines)


# --- look ----------------------------------------------------------------------------------------------------------

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = Style.sans()
	t.default_font_size = Style.BODY_FONT
	t.set_color("font_color", "Label", Style.INK)
	return t
