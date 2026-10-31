## The sheets around the economy and the profile: Shop, not-enough-coins, the Complete picker, the daily gift, the
## streak, the avatar picker, renaming, a solved level's card and the room reveal. Built on Main's open_sheet.
class_name MetaSheets
extends RefCounted


## Coin packs and free coins. A utility sheet: Back closes it and the player stays where they were.
static func shop(main: Node) -> void:
	var s := Sheet.new("Shop")
	s.add_label("Coins buy Hints and Complete. Everything can also be won by playing.", Style.FS_26)
	var free_left := Wallet.ads_left("shop_coins")
	if Ads.available():
		var b := _row(s, "Free coins", "+%d" % Economy.AD_COINS, "Watch an ad (%d left today)" % free_left, func() -> void:
			s.close()
			main.rewarded("shop_coins", func() -> void:
				Wallet.grant({"coins": Economy.AD_COINS})
				main.toast("+%d coins" % Economy.AD_COINS)))
		b.enabled = Ads.rewarded_ready("shop_coins")
	if Store.available():
		for p: Dictionary in Store.products():
			var id: String = p["id"]
			_row(s, "%s coins" % CoinPill._fmt(int(p["coins"])), Store.price_text(id), "", func() -> void:
				s.close()
				main.purchase(id))
		if Store.provider == "mock":
			s.add_label("Test build: purchases are simulated and free.", Style.FS_22)
	elif not Ads.available():
		s.add_label("The shop opens in a later version. Play levels and claim daily gifts for coins.", Style.FS_26)
	main.open_sheet(s)


static func _row(s: Sheet, title: String, price: String, note: String, action: Callable) -> PillButton:
	var b := PillButton.new("%s    %s" % [title, price], false, 92.0)
	b.icon = ""
	b.font_size = Style.FS_30
	b.pressed.connect(action)
	s.body.add_child(b)
	if note != "":
		var l := Label.new()
		l.text = note
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", Style.FS_22)
		l.add_theme_color_override("font_color", Color(Style.INK, 0.7))
		s.body.add_child(l)
	return b


## A booster the player can't pay for: a free hint for an ad (Hint only), or the Shop. Never shown on a lose sheet.
static func need_coins(main: Node, item: String) -> void:
	var price := int(Economy.PRICES[item])
	var s := Sheet.new("Get a hint" if item == "hint" else "Complete a jar")
	s.add_label("It costs %d coins. You have %d." % [price, Wallet.coins()], Style.FS_30)
	if item == "hint" and Ads.rewarded_ready("free_hint"):
		s.add_button("Watch an ad for a free hint", true, func() -> void:
			s.close()
			main.rewarded("free_hint", main.play.grant_free_hint), Style.TOUCH_PRIMARY)
	s.add_button("Get coins", item != "hint" or not Ads.rewarded_ready("free_hint"), func() -> void:
		s.close()
		shop(main))
	s.add_button("Not now", false, s.close)
	main.open_sheet(s)


## Which jar to complete: the unsolved labels exactly as the rail shows them (no new information), then a confirm.
## Closing it any way spends nothing.
static func complete_picker(main: Node) -> void:
	var play: PlayScreen = main.play
	var s := Sheet.new("Complete which jar?")
	var chosen := [-1]
	var held := Wallet.count("complete")
	var confirm := PillButton.new("Pick a label", true, Style.TOUCH_PRIMARY)
	confirm.enabled = false
	var done := [false]
	var rows: Array[PillButton] = []
	for g in play.session.level.group_count():
		if play.session.board.is_solved(g):
			continue
		var group: Dictionary = play.session.level.groups[g]
		var text := LabelText.at_step(group["label"], group["key"], play.session.know.step[g]).replace("_", "▢")
		var b := PillButton.new(text if text != "" else "A label not found yet", false, 84.0)
		b.font_size = Style.FS_26
		b.icon = ""
		b.pressed.connect(func() -> void:
			chosen[0] = g
			for r in rows:
				r.primary = r == b
				r.queue_redraw()
			confirm.text = "Fill this jar: %s" % ("1 free" if held > 0 else "%d coins" % Economy.PRICES["complete"])
			confirm.enabled = true
			confirm.queue_redraw())
		rows.append(b)
		s.body.add_child(b)
	confirm.pressed.connect(func() -> void:
		if chosen[0] < 0:
			return
		done[0] = true
		s.close()
		play.do_complete(chosen[0]))
	s.body.add_child(confirm)
	s.closed.connect(func() -> void:
		if not done[0]:
			play.cancel_complete())
	main.open_sheet(s)


## Today's gift and the week ahead. Claim (and an optional ad to double), or how to open it.
static func gift(main: Node) -> void:
	var s := Sheet.new("Daily gift")
	var view := GiftLadderView.new()
	var today: Dictionary = Wallet.gift_today()
	view.today = today["rung"]
	view.waiting = Wallet.gift_ready()
	s.body.add_child(view)
	var streak := Wallet.streak_shown()
	var savers := int(Save.data["streak"]["savers"])
	s.add_label("%d-day streak%s" % [streak, (", %d streak saver%s" % [savers, "" if savers == 1 else "s"]) if savers > 0 else ""],
		Style.FS_26, true)
	if view.waiting:
		var r: Dictionary = today["rewards"]
		var what := "%d coins" % int(r.get("coins", 0)) + (" and a Complete" if r.has("complete") else "")
		s.add_button("Claim %s" % what, true, func() -> void:
			s.close()
			var got := Wallet.claim_gift(false)
			main.toast(_reward_text(got))
			main.refresh_home(), Style.TOUCH_PRIMARY)
		if Ads.rewarded_ready("gift_double"):
			s.add_button("Watch an ad: double it", false, func() -> void:
				s.close()
				main.rewarded("gift_double", func() -> void:
					var got := Wallet.claim_gift(true)
					main.toast(_reward_text(got))
					main.refresh_home()))
	else:
		var claimed := int(Save.data["gift"]["claimed_day"]) == Wallet.today()
		s.add_label("Claimed today. Come back tomorrow." if claimed else "Win any level today to open it.", Style.FS_26)
	main.open_sheet(s)


## The streak explained in two lines (no guilt): what counts, and what savers do.
static func streak(main: Node) -> void:
	var s := Sheet.new("Play streak")
	var n := Wallet.streak_shown()
	var best := int(Save.data["streak"]["best"])
	s.add_label("%d day%s in a row. Best: %d." % [n, "" if n == 1 else "s", best], Style.FS_30, true)
	s.add_label("Win any level on a day to count it. Every 7 days earns a streak saver, which covers a missed day.", Style.FS_26)
	s.add_label("Longer streaks grow the daily gift.", Style.FS_26)
	main.open_sheet(s)


static func avatar_picker(main: Node) -> void:
	var s := Sheet.new("Pick an avatar")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	for a: Array in Economy.AVATARS:
		var id: String = a[0]
		var unlocked: bool = Save.data["avatars"].has(id)
		var cell := _AvatarCell.new(id, not unlocked, Save.data["profile"]["avatar"] == id)
		cell.custom_minimum_size = Vector2(120, 140)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.note = "" if unlocked else ("Level %d" % int(a[3]) if int(a[3]) > 0 else ("30-day streak" if id == "trophy" else "100-day streak"))
		cell.pressed.connect(func() -> void:
			if not unlocked:
				return
			Save.data["profile"]["avatar"] = id
			Save.write()
			Wallet.changed.emit()
			s.close()
			main.refresh_profile())
		grid.add_child(cell)
	s.body.add_child(grid)
	main.open_sheet(s)


static func rename(main: Node) -> void:
	var s := Sheet.new("Your name")
	var edit := LineEdit.new()
	edit.text = str(Save.data["profile"]["name"])
	edit.max_length = SaveSchema.MAX_NAME
	edit.placeholder_text = "Name"
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size = Vector2(0, 88)
	edit.add_theme_font_size_override("font_size", Style.FS_36)
	edit.add_theme_color_override("font_color", Style.INK)
	edit.add_theme_stylebox_override("normal", Style.box(Style.CARD, Style.R_L, 2, Color(Style.INK, 0.2)))
	edit.add_theme_stylebox_override("focus", Style.box(Style.CARD, Style.R_L, 3, Style.TEAL))
	s.body.add_child(edit)
	var save_name := func() -> void:
		Save.data["profile"]["name"] = SaveSchema.clean_name(edit.text)
		Save.write()
		s.close()
		main.refresh_profile()
	edit.text_submitted.connect(func(_t: String) -> void: save_name.call())
	s.add_button("Save", true, save_name)
	main.open_sheet(s)
	edit.grab_focus.call_deferred()


## A solved level from the room view: its labels, its gold state, and Play again.
static func level_card(main: Node, id: String) -> void:
	var cat := Levels.catalog
	var e := cat.entry(id)
	var s := Sheet.new(cat.title(id))
	var solved: Dictionary = Save.data["solved"].get(id, {})
	for g: Dictionary in e["data"].get("groups", []):
		var l := s.add_label(str(g.get("label", "")), Style.FS_36)
		l.add_theme_font_override("font", Style.hand())
	if bool(solved.get("gold", false)):
		s.add_label("Gold lid: a clean sort.", Style.FS_26, true)
	elif int(e.get("gold", -1)) >= 0:
		s.add_label("Gold lid for %d slip%s or fewer, with no help." % [int(e["gold"]), "" if int(e["gold"]) == 1 else "s"], Style.FS_26)
	s.add_button("Play again", true, func() -> void: main.start_level(id), Style.TOUCH_PRIMARY)
	main.open_sheet(s)


## A new room opens: its wall and name, then in.
static func room_reveal(main: Node, room: int, next_id: String) -> void:
	var s := Sheet.new("")
	s.kind = "result"
	s.dismissible = false
	var art := _RoomArtPreview.new(room)
	art.custom_minimum_size = Vector2(0, 260)
	s.body.add_child(art)
	var t := s.add_label(Levels.catalog.room_name(room), Style.FS_56)
	t.add_theme_font_override("font", Style.hand())
	s.add_label("A new room: new walls, new jars, new ideas.", Style.FS_26)
	s.add_button("Go in", true, func() -> void: main.start_level(next_id), Style.TOUCH_PRIMARY)
	s.add_button("Home", false, main.go_home)
	main.open_sheet(s)
	Sfx.play_at(0.2, "levelup", 0.9, 0.0)


static func _reward_text(r: Dictionary) -> String:
	var parts: Array[String] = []
	if int(r.get("coins", 0)) > 0:
		parts.append("+%d coins" % int(r["coins"]))
	if int(r.get("complete", 0)) > 0:
		parts.append("+%d Complete" % int(r["complete"]))
	if int(r.get("hint", 0)) > 0:
		parts.append("+%d Hints" % int(r["hint"]))
	return ", ".join(parts)


class _AvatarCell extends Control:
	signal pressed

	var id := ""
	var locked := false
	var selected := false
	var note := ""
	var _down := false

	func _init(avatar: String, is_locked: bool, is_selected: bool) -> void:
		id = avatar
		locked = is_locked
		selected = is_selected
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if event.pressed:
			_down = true
		elif _down:
			_down = false
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				Sfx.play("tap", 1.0, 0.05, -4.0)
				pressed.emit()

	func _draw() -> void:
		var d := minf(size.x, 104.0)
		AvatarView.draw_avatar(self, Rect2((size.x - d) / 2.0, 0, d, d), id, -1.0, locked, selected)
		if note != "":
			var f := Style.sans_bold()
			var ts := f.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
			draw_string(f, Vector2((size.x - ts.x) / 2.0, d + 24), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Style.INK, 0.65))


class _RoomArtPreview extends Control:
	var room := 1

	func _init(r: int) -> void:
		room = r
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_texture_rect(Art.tex("reveal_wall|%d" % room, r.size, RoomArt.wall.bind(room, Style.R_XL)), r, false)
		var plank := Rect2(30, size.y - 54, size.x - 60, 30)
		draw_texture_rect(Art.tex("reveal_plank|%d" % room, plank.size, RoomArt.plank.bind(room)), plank, false)
		var jw := 86.0
		var colors := [[Style.APRICOT, Style.PAPRIKA], [Color("#8A9A4B"), Color("#EBD3A2")], [Color("#5B4A7A"), Color("#E8A04A")],
			[Color("#5E7F9A"), Color("#B5C77A")]]
		for i in 4:
			var jr := Rect2(size.x / 2.0 - 2 * (jw + 14) + 7 + i * (jw + 14), plank.position.y - jw * 1.4 + 4, jw, jw * 1.4)
			draw_texture_rect(Art.tex("reveal_jar|%d|%d" % [room, i], jr.size, RoomArt.mini_jar.bind(room, colors[i], false)), jr, false)
