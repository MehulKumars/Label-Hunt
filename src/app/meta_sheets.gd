## The sheets around the economy and the profile: Shop, not-enough-coins, the daily gift, the streak, the avatar
## picker, renaming, a solved level's card and the room reveal. Built on Main's open_sheet.
class_name MetaSheets
extends RefCounted


## Coin packs and free coins. A utility sheet: Back closes it and the player stays where they were.
static func shop(main: Node) -> void:
	var s := Sheet.new("Shop")
	s.add_label("Coins buy Hints and Complete. Everything can also be won by playing.", Style.FS_26)
	if Ads.available():
		var left := Wallet.ads_left("shop_coins")
		var free := _ShopRow.new(0, "+%d coins" % Economy.AD_COINS, "%d left today" % left, "Watch ad", true)
		free.enabled = Ads.rewarded_ready("shop_coins")
		free.pressed.connect(func() -> void:
			s.close()
			main.rewarded("shop_coins", func() -> void:
				Wallet.grant({"coins": Economy.AD_COINS})
				main.toast("+%d coins" % Economy.AD_COINS)))
		s.body.add_child(free)
	if Store.available():
		var tier := 1
		for p: Dictionary in Store.products():
			var id: String = p["id"]
			var coins := int(p["coins"])
			var row := _ShopRow.new(tier, "%s coins" % CoinPill._fmt(coins),
				"%d Hints or %d Completes" % [coins / int(Economy.PRICES["hint"]), coins / int(Economy.PRICES["complete"])],
				Store.price_text(id), false)
			row.pressed.connect(func() -> void:
				s.close()
				main.purchase(id))
			s.body.add_child(row)
			tier += 1
		if Store.provider == "mock":
			s.add_label("Test build: purchases are simulated and free.", Style.FS_26)
	elif not Ads.available():
		s.add_label("The shop opens in a later version. Play levels and claim daily gifts for coins.", Style.FS_26)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 12)
	s.body.add_child(pad)
	main.open_sheet(s)


## One shop row: a coin stack that grows with the pack (or an ad film for free coins), the amount and what it buys,
## and a price chip (paprika to buy, teal for an ad). Tappable anywhere; a drag scrolls the list instead.
class _ShopRow extends Control:
	signal pressed

	var tier := 0
	var title := ""
	var sub := ""
	var price := ""
	var ad := false
	var enabled := true:
		set(v):
			enabled = v
			modulate.a = 1.0 if v else 0.45
	var _down := false
	var _scrolling := false
	var _press_at := Vector2.ZERO

	func _init(t: int, ttl: String, s: String, p: String, is_ad: bool) -> void:
		tier = t
		title = ttl
		sub = s
		price = p
		ad = is_ad
		custom_minimum_size = Vector2(0, 112)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion and (_down or _scrolling):
			accept_event()
			if not _scrolling and event.position.distance_to(_press_at) > Scroller.SLOP:
				_scrolling = true
				_down = false
			if _scrolling:
				Scroller.drag(self, event.relative)
			return
		if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if event.is_canceled():
			_down = false
			_scrolling = false
		elif event.pressed:
			_down = true
			_scrolling = false
			_press_at = event.position
		elif _scrolling:
			_scrolling = false
		elif _down:
			_down = false
			if enabled and Rect2(Vector2.ZERO, size).has_point(event.position):
				Sfx.play("tap", 1.0, 0.05, -4.0)
				pressed.emit()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := Style.box(Style.CARD, Style.R_L)
		sb.shadow_color = Color(Style.INK, 0.12)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 3)
		draw_style_box(sb, r)
		# Left: a stack of coins that grows with the pack, or an ad's film for free coins.
		var art := Rect2(14, 10, 92, size.y - 20)
		if ad:
			draw_circle(art.get_center(), 34.0, Color(Style.TEAL, 0.14), true, -1.0, true)
			draw_texture_rect(Art.icon("film-slate", 40, Style.TEAL), Rect2(art.get_center() - Vector2(20, 20), Vector2(40, 40)), false)
		else:
			var coin := Art.tex("coin", Vector2(48, 48), Materials.coin)
			var n := tier + 1
			for i in n:
				var x := art.position.x + 20.0 + (i % 2) * 18.0 - (i / 4) * 8.0
				var y := art.end.y - 50.0 - i * 9.0
				draw_texture_rect(coin, Rect2(x, y, 48, 48), false)
		var f := Style.sans_heavy()
		var fb := Style.sans_bold()
		var chip_w := 150.0
		var text_w := size.x - 120.0 - chip_w - 24.0
		draw_string(f, Vector2(120, size.y / 2.0 - 4), title, HORIZONTAL_ALIGNMENT_LEFT, text_w, Style.FS_36, Style.INK)
		draw_string(fb, Vector2(120, size.y / 2.0 + 30), sub, HORIZONTAL_ALIGNMENT_LEFT, text_w, Style.FS_22, Color(Style.INK, 0.72))
		# Right: the price chip.
		var chip := Rect2(size.x - chip_w - 16, (size.y - 60) / 2.0, chip_w, 60)
		draw_style_box(Style.box(Style.TEAL if ad else Style.PAPRIKA, 30), chip)
		var ps := f.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_30)
		draw_string(f, Vector2(chip.get_center().x - ps.x / 2.0, chip.get_center().y + 11), price, HORIZONTAL_ALIGNMENT_LEFT, -1,
			Style.FS_30, Style.PAPER)


## A booster the player can't pay for: a free hint for an ad (Hint only), or the Shop. Never shown on a lose sheet.
static func need_coins(main: Node, item: String) -> void:
	var price := int(Economy.PRICES[item])
	var s := Sheet.new("Get a hint" if item == "hint" else "Complete a jar")
	s.add_label("It costs %d coins. You have %d." % [price, Wallet.coins()], Style.FS_30)
	if item == "hint" and Ads.rewarded_ready("free_hint"):
		s.add_button("Watch an ad for a free hint", false, func() -> void:
			s.close()
			main.rewarded("free_hint", main.play.grant_free_hint))
	s.add_button("Get coins", false, func() -> void:
		s.close()
		shop(main))
	s.add_button("Not now", false, s.close)
	main.open_sheet(s)


## Today's gift and the week ahead. Claim (and an optional ad to double), or how to open it.
static func gift(main: Node) -> void:
	var s := Sheet.new("Daily gift")
	var view := GiftLadderView.new()
	var today: Dictionary = Wallet.gift_today()
	var claimed := int(Save.data["gift"]["claimed_day"]) == Wallet.today()
	view.today = today["rung"]
	view.waiting = Wallet.gift_ready()
	view.claimed = claimed
	s.body.add_child(view)
	_add_bonus_road(s, Wallet.streak_shown())
	if view.waiting:
		var r: Dictionary = today["rewards"]
		var what := "%d coins" % int(r.get("coins", 0)) + (" and a Complete" if r.has("complete") else "")
		s.add_button("Claim %s" % what, true, func() -> void:
			s.close()
			var got := Wallet.claim_gift(false)
			Sfx.play("gift", 1.0, 0.0)
			Sfx.play_at(0.25, "coin", 1.0, 0.03)
			Haptics.coin()
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
		s.add_label("Claimed today. Come back tomorrow." if claimed else "Win any level today to open it.", Style.FS_26)
	main.open_sheet(s)


## The streak at a glance (no guilt): the count, the best and the savers, then the bonuses ahead.
static func streak(main: Node) -> void:
	var s := Sheet.new("Play streak")
	var n := Wallet.streak_shown()
	s.body.add_child(_StreakHero.new(n, int(Save.data["streak"]["best"]), int(Save.data["streak"]["savers"])))
	_add_bonus_road(s, n)
	s.add_label("Every 7 days earns a saver, which covers a missed day.", Style.FS_26)
	main.open_sheet(s)


static func _add_bonus_road(s: Sheet, streak_days: int) -> void:
	var left: int = Economy.next_streak_bonuses(streak_days, 1)[0] - streak_days
	s.add_label("Next streak bonus in %d day%s" % [left, "" if left == 1 else "s"], Style.FS_26, true)
	s.body.add_child(StreakBonusView.new(streak_days))


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
		cell.note = "" if unlocked else ("Rank %d" % int(a[3]) if int(a[3]) > 0 else ("30-day streak" if id == "trophy" else "100-day streak"))
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
	if r.has("avatar"):
		parts.append("a new avatar")
	return ", ".join(parts)


## A flame disc with the streak beside it in big numerals; the best streak and the savers sit at the right.
class _StreakHero extends Control:
	var count := 0
	var best := 0
	var savers := 0

	func _init(c: int, b: int, s: int) -> void:
		count = c
		best = b
		savers = s
		custom_minimum_size = Vector2(0, 124)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(56, 60)
		draw_circle(c, 54.0, Color(Style.APRICOT, 0.25) if count == 0 else Style.APRICOT, true, -1.0, true)
		draw_texture_rect(Art.icon("fire", 60, Style.INK), Rect2(c - Vector2(30, 30), Vector2(60, 60)), false)
		var fh := Style.sans_heavy()
		var fb := Style.sans_bold()
		draw_string(fh, Vector2(128, 70), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_72, Style.INK)
		var note := "Win a level to start" if count == 0 else ("day in a row" if count == 1 else "days in a row")
		draw_string(fb, Vector2(128, 108), note, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_26, Color(Style.INK, 0.72))
		_stat("Best", best, 38.0)
		_stat("Savers", savers, 82.0)

	func _stat(label: String, value: int, y: float) -> void:
		var fh := Style.sans_heavy()
		var fb := Style.sans_bold()
		var v := str(value)
		var vs := fh.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_36)
		draw_string(fh, Vector2(size.x - vs.x, y), v, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_36, Style.INK)
		var ls := fb.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_26)
		draw_string(fb, Vector2(size.x - 52.0 - ls.x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_26, Color(Style.INK, 0.72))


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
