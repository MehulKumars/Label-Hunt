## Home. The hero is a big glass jar labelled "Jarful" that fills with a layer for every category sorted in this
## room (full when the room is done). Below it the cabinet holds the current shelf (tap it for the whole room).
## Around them: the profile chip (avatar, level, XP ring) and coins at the top; the play streak and today's gift
## beside the jar; Levels, the big Play button and the Shop in the thumb zone.
class_name HomeScreen
extends Control

signal play_pressed
signal settings_pressed
signal levels_pressed
signal shop_pressed
## The coin pill: the Shop when it is open, else a note on how coins are earned.
signal coins_pressed
signal profile_pressed
signal gift_pressed
signal streak_pressed
signal room_pressed

var next_id := ""
## The open wall between the top row and the hero jar, where the room's decoration hangs (empty when too tight).
var props_band := Rect2()
var room := 1
var _gear: RoundButton
var _profile: _ProfileChip
var _coins: CoinPill
var _diamonds: CoinPill
var _streak: RoundButton
var _gift: RoundButton
var _hero: _HeroJar
var _cabinet: _Cabinet
var _shelf: ShelfView
var _count: Label
var _levels: RoundButton
var _shop: RoundButton
var _play: PillButton


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_profile = _ProfileChip.new()
	_profile.pressed.connect(func() -> void: profile_pressed.emit())
	add_child(_profile)
	_coins = CoinPill.new()
	# Coins are earned, never sold: no plus. With the Shop open a tap opens it; else it says how coins are earned.
	_coins.plus = false
	_coins.pressed.connect(func() -> void: coins_pressed.emit())
	add_child(_coins)
	_diamonds = CoinPill.new()
	_diamonds.diamond = true
	_diamonds.pressed.connect(func() -> void: shop_pressed.emit())
	add_child(_diamonds)
	_gear = RoundButton.new("gear")
	_gear.pressed.connect(func() -> void: settings_pressed.emit())
	add_child(_gear)
	_hero = _HeroJar.new()
	add_child(_hero)
	_streak = RoundButton.new("streak", "Streak")
	_streak.pressed.connect(func() -> void: streak_pressed.emit())
	add_child(_streak)
	_gift = RoundButton.new("gift", "Gift")
	_gift.pressed.connect(func() -> void: gift_pressed.emit())
	add_child(_gift)
	_cabinet = _Cabinet.new()
	_cabinet.pressed.connect(func() -> void: room_pressed.emit())
	add_child(_cabinet)
	_shelf = ShelfView.new()
	add_child(_shelf)
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_font_override("font", Style.sans_bold())
	_count.add_theme_font_size_override("font_size", Style.FS_26)
	_count.add_theme_color_override("font_color", Color(Style.INK, 0.78))
	add_child(_count)
	_levels = RoundButton.new("levels", "Levels")
	_levels.pressed.connect(func() -> void: levels_pressed.emit())
	add_child(_levels)
	_shop = RoundButton.new("shop", "Shop")
	_shop.pressed.connect(func() -> void: shop_pressed.emit())
	add_child(_shop)
	_play = PillButton.new("Play", true, Style.TOUCH_PRIMARY + 8.0)
	_play.icon = "play"
	_play.font_size = Style.FS_36
	_play.pressed.connect(func() -> void: play_pressed.emit())
	add_child(_play)


func _ready() -> void:
	Wallet.changed.connect(func() -> void:
		if visible:
			_coins.set_value(Wallet.coins())
			_diamonds.set_value(Wallet.diamonds())
			_profile.refresh())


func refresh() -> void:
	var cat := Levels.catalog
	var save := Save.data
	next_id = Progression.next_level(cat, save)
	room = Progression.current_room(cat, save)
	var ids := cat.room_ids(room)
	var solved := Progression.solved_count(cat, save, room)
	_cabinet.title = cat.room_name(room)
	_cabinet.room = room
	_shelf.room = room
	_hero.room = room
	_count.text = "%d of %d jars filled" % [solved, ids.size()]
	var resume := str(save["board"].get("id", "")) == next_id and next_id != ""
	if next_id == "":
		_play.text = "All rooms done"
	else:
		_play.text = ("Continue level %d" if resume else "Play level %d") % (cat.order_index(next_id) + 1)
	_play.enabled = next_id != ""
	_play.queue_redraw()
	var labels: Array = []
	for id in ids:
		if save["solved"].has(id):
			for g: Dictionary in cat.entry(id)["data"].get("groups", []):
				labels.append(str(g.get("label", "")))
	_hero.layers = Materials.preserve_layers(labels)
	_hero.frac = solved / float(maxi(ids.size(), 1))
	_hero.queue_redraw()
	var shelf := 0 if next_id == "" or cat.entry(next_id)["room"] != room else cat.shelf_of(next_id)
	var from := shelf * Catalog.SHELF
	_shelf.slots = ShelfView.slots_for(ids.slice(from, mini(from + Catalog.SHELF, ids.size())), save, next_id)
	_shelf.queue_redraw()
	_shelf.breathe()
	_coins.set_value(Wallet.coins(), false)
	_diamonds.set_value(Wallet.diamonds(), false)
	# The Shop and diamonds appear only when something can be bought or watched (Build.shop_open).
	var shop := Build.shop_open()
	_diamonds.visible = shop
	_shop.visible = shop
	_profile.refresh()
	var streak := Wallet.streak_shown()
	_streak.badge = str(streak) if streak > 0 else ""
	_streak.caption = "%d day%s" % [streak, "" if streak == 1 else "s"] if streak > 0 else "Streak"
	var ready := Wallet.gift_ready()
	_gift.caption = "Open" if ready else "Gift"
	_gift.set_pulse(ready)
	for b in [_streak, _gift]:
		b.queue_redraw()
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	var ins := SafeArea.current(size)
	var top: float = ins["top"] + Style.SP_3
	var bottom: float = size.y - ins["bottom"]
	var w := size.x
	var left := Style.GUTTER
	_profile.position = Vector2(left - 6.0, top)
	_profile.size = Vector2(230, RoundButton.D)
	_gear.position = Vector2(w - left - RoundButton.D, top)
	_gear.size = _gear.custom_minimum_size
	var coin_w := _coins.wanted_width()
	var pill_y := top + (RoundButton.D - CoinPill.H) / 2.0
	_coins.size = Vector2(coin_w, CoinPill.H)
	_coins.position = Vector2(_gear.position.x - 12.0 - coin_w, pill_y)
	var chip_end := _coins.position.x - 12.0
	if _diamonds.visible:
		var gem_w := _diamonds.wanted_width()
		_diamonds.size = Vector2(gem_w, CoinPill.H)
		_diamonds.position = Vector2(_coins.position.x - 10.0 - gem_w, pill_y)
		chip_end = _diamonds.position.x - 10.0
	# The profile chip gives way to big balances rather than overlap them.
	_profile.size.x = clampf(chip_end - _profile.position.x, 150.0, 230.0)
	# Thumb row: Levels, Play, Shop (without the Shop, Play takes its place).
	var disc_w := RoundButton.D + 12.0
	var play_h := Style.TOUCH_PRIMARY + 8.0
	var row_y := bottom - play_h - 36.0
	var discs := 2.0 if _shop.visible else 1.0
	_play.size = Vector2(w - left * 2.0 - disc_w * discs - 8.0 * discs, play_h)
	_play.position = Vector2(left + disc_w + 8.0, row_y)
	for b: RoundButton in [_levels, _shop]:
		b.size = Vector2(disc_w, b.custom_minimum_size.y)
	_levels.position = Vector2(left - 6.0, row_y + (play_h - 8.0 - RoundButton.D) / 2.0)
	_shop.position = Vector2(w - left - disc_w + 6.0, _levels.position.y)
	_count.size = Vector2(w, 40)
	_count.position = Vector2(0, row_y - 40 - 22.0)
	# The cabinet takes what the screen can spare: full height on tall phones, less on 16:9.
	var cab_h := clampf((_count.position.y - top) * 0.46, 330.0, 440.0)
	_cabinet.size = Vector2(w - (left - 8.0) * 2.0, cab_h)
	_cabinet.position = Vector2(left - 8.0, _count.position.y - 40.0 - cab_h)
	_shelf.position = _cabinet.position + Vector2(30, 26)
	_shelf.size = _cabinet.size - Vector2(60, 76)
	# The hero jar stands on the cabinet's top, filling the room above it; streak and gift sit at its shoulders.
	var hero_top := top + RoundButton.D + 18.0
	var stand := _cabinet.position.y + 12.0
	var hero_h := clampf(stand - hero_top, 220.0, 480.0)
	var hero_w := minf(hero_h * 0.78, w * 0.56)
	_hero.size = Vector2(hero_w, hero_h)
	_hero.position = Vector2((w - hero_w) / 2.0, stand - hero_h)
	var side_y := _hero.position.y + hero_h * 0.34
	_streak.size = Vector2(disc_w + 20.0, _streak.custom_minimum_size.y)
	_gift.size = _streak.size
	_streak.position = Vector2(maxf(left - 14.0, (_hero.position.x - _streak.size.x) / 2.0), side_y)
	_gift.position = Vector2(w - _streak.position.x - _gift.size.x, side_y)
	move_child(_hero, -1)
	var band_top := top + RoundButton.D + 4.0
	var band_h := minf(150.0, _hero.position.y - band_top + 10.0)
	props_band = Rect2(0, band_top, w, band_h) if band_h >= 70.0 else Rect2()


## Avatar with an XP ring, "Level 7" and the title beside it. Tap for the profile.
class _ProfileChip extends Control:
	signal pressed

	var _down := false
	var _info := {}
	var _avatar := "lemon"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func refresh() -> void:
		_info = Wallet.level_info()
		_avatar = str(Save.data["profile"]["avatar"])
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if event.is_canceled():
			_down = false
		elif event.pressed:
			_down = true
			Sfx.play("tap", 1.0, 0.05, -4.0)
		elif _down:
			_down = false
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()

	func _draw() -> void:
		if _info.is_empty():
			return
		var d := size.y
		AvatarView.draw_avatar(self, Rect2(0, 0, d, d), _avatar, float(_info["into"]) / float(_info["need"]))
		var f := Style.sans_heavy()
		var fb := Style.sans_bold()
		draw_string(f, Vector2(d + 10.0, d * 0.46), "Rank %d" % _info["level"], HORIZONTAL_ALIGNMENT_LEFT, size.x - d - 10.0,
			Style.FS_30, Style.INK)
		draw_string(fb, Vector2(d + 10.0, d * 0.46 + 30.0), str(_info["title"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - d - 10.0,
			Style.FS_22, Color(Style.INK, 0.72))


## The big jar: glass, its contents, a paprika lid (gold when the room is complete) and the "Jarful" label.
class _HeroJar extends Control:
	var layers: Array = []
	var room := 1
	var frac := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var neck := Materials.jar_rim(size.y)
		var foot := Rect2(Vector2(size.x * 0.08, size.y - 10.0), Vector2(size.x * 0.84, 14.0))
		draw_style_box(Style.glow(Color(Style.INK, 0.3), 8, 10), foot)
		draw_texture_rect(Art.tex("hero_back|%d" % room, size, RoomArt.jar_back.bind(room)), r, false)
		var key := "hero_fill|%d|%.3f|%d" % [layers.size(), frac, hash(layers)]
		draw_texture_rect(Art.tex(key, size, Materials.jar_contents.bind(layers, frac)), r, false)
		draw_texture_rect(Art.tex("hero_front|%d" % room, size, RoomArt.jar_front.bind(room)), r, false)
		var ni := Materials.jar_neck(size.x)
		var lid := Vector2(size.x - ni * 2.0 + 18.0, neck * 1.3)
		var lid_color := Style.GOLD if frac >= 1.0 else Style.PAPRIKA
		draw_texture_rect(Art.tex("hero_lid_%s|%d" % [lid_color.to_html(false), room], lid, RoomArt.lid.bind(room, lid_color)),
			Rect2(Vector2(ni - 9.0, -lid.y * 0.5), lid), false)
		var f := Style.hand()
		# The game's name on the big jar's label, shrunk until it fits the label.
		var title := str(ProjectSettings.get_setting("application/config/name"))
		var fs := clampi(roundi(size.x * 0.27), 56, 96)
		var ts := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		while ts.x + 48.0 > size.x * 0.86 and fs > 40:
			fs -= 2
			ts = f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var tag := Vector2(minf(size.x * 0.86, ts.x + 48.0), maxf(fs * 1.05, 64.0))
		draw_set_transform(Vector2(size.x / 2.0, neck + (size.y - neck) * 0.42), deg_to_rad(-3.0), Vector2.ONE)
		draw_texture_rect(Art.tex("hero_label|%dx%d" % [int(tag.x), int(tag.y)], tag, Materials.label.bind(false)), Rect2(-tag / 2.0, tag), false)
		draw_string(f, Vector2(-ts.x / 2.0, f.get_ascent(fs) * 0.36), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.INK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The wooden cabinet, with the room's name on a kraft nameplate pinned to its base. Tap it to see the whole room.
class _Cabinet extends Control:
	signal pressed

	var title := "":
		set(v):
			title = v
			queue_redraw()
	var _down := false
	var room := 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if event.is_canceled():
			_down = false
		elif event.pressed:
			_down = true
		elif _down:
			_down = false
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				Sfx.play("tap", 1.0, 0.05, -4.0)
				pressed.emit()

	func _draw() -> void:
		draw_texture_rect(Art.tex("cabinet|%d" % room, size, RoomArt.cabinet.bind(room)), Rect2(Vector2.ZERO, size), false)
		var f := Style.hand()
		var fs := Style.FS_44
		var ts := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var tag := Vector2(ts.x + 64.0, 62.0)
		draw_set_transform(Vector2(size.x / 2.0, size.y - 14.0), deg_to_rad(-1.5), Vector2.ONE)
		draw_texture_rect(Art.tex("room_tag", tag, Materials.label.bind(false)), Rect2(-tag / 2.0, tag), false)
		for side in [-1.0, 1.0]:
			draw_circle(Vector2(side * (tag.x / 2.0 - 14.0), -1.5), 4.0, Style.WOOD_DARK, true, -1.0, true)
		draw_string(f, Vector2(-ts.x / 2.0, f.get_ascent(fs) * 0.36), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.INK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
