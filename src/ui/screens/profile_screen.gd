## The player: avatar (tap to change), name (tap to rename), level and title with the XP bar, a few honest stats,
## and friends (sample data in test builds until Google Play Games is connected).
class_name ProfileScreen
extends Control

signal back_pressed
signal avatar_pressed
signal name_pressed

var header: ScreenHeader
var scroll: ScrollContainer
var list: VBoxContainer
var _top: _Top


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	header = ScreenHeader.new("Profile")
	header.back_pressed.connect(func() -> void: back_pressed.emit())
	add_child(header)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 18)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)


func refresh() -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	var cat := Levels.catalog
	var save := Save.data
	_top = _Top.new()
	_top.avatar_pressed.connect(func() -> void: avatar_pressed.emit())
	_top.name_pressed.connect(func() -> void: name_pressed.emit())
	_top.custom_minimum_size = Vector2(0, 336)
	list.add_child(_top)
	var solved := 0
	var categories := {}
	for id in save["solved"]:
		if cat.has(id) and cat.entry(id)["track"] == "room":
			solved += 1
			for g: Dictionary in cat.entry(id)["data"].get("groups", []):
				categories[str(g.get("label", ""))] = true
	var rooms_done := 0
	for r in cat.room_numbers():
		if Progression.solved_count(cat, save, r) == cat.room_ids(r).size():
			rooms_done += 1
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for row: Array in [
		["Levels solved", solved], ["Gold lids", Progression.gold_count(cat, save, -1)],
		["Labels collected", categories.size()], ["Rooms finished", rooms_done],
		["Day streak", Wallet.streak_shown()], ["Best streak", int(save["streak"]["best"])],
	]:
		var card := _Stat.new(str(row[0]), int(row[1]))
		card.custom_minimum_size = Vector2(0, 116)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
	list.add_child(grid)
	if Social.available():
		var head := Label.new()
		head.text = "Friends (test data)"
		head.add_theme_font_override("font", Style.sans_heavy())
		head.add_theme_font_size_override("font_size", Style.FS_30)
		list.add_child(head)
		var mine := {"name": str(save["profile"]["name"]) if str(save["profile"]["name"]) != "" else "You",
			"level": cat.order_index(Progression.next_level(cat, save)) + 1, "avatar": str(save["profile"]["avatar"]), "me": true}
		var people: Array = Social.friends().duplicate()
		people.append(mine)
		people.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["level"]) > int(b["level"]))
		for p: Dictionary in people:
			var row := _Friend.new(p)
			row.custom_minimum_size = Vector2(0, 84)
			list.add_child(row)
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	var y := header.place(size)
	var bottom: float = size.y - SafeArea.current(size)["bottom"]
	scroll.position = Vector2(Style.GUTTER, y)
	scroll.size = Vector2(size.x - Style.GUTTER * 2.0, bottom - y)


## Avatar, name with a pencil, level and title, and the XP bar to the next level.
class _Top extends Control:
	signal avatar_pressed
	signal name_pressed

	var _down := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _area(pos: Vector2) -> String:
		if Rect2(size.x / 2.0 - 90, 0, 180, 180).has_point(pos):
			return "avatar"
		if Rect2(0, 186, size.x, 56).has_point(pos):
			return "name"
		return ""

	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if event.pressed:
			_down = _area(event.position)
		elif _down != "" and _area(event.position) == _down:
			Sfx.play("tap", 1.0, 0.05, -4.0)
			if _down == "avatar":
				avatar_pressed.emit()
			else:
				name_pressed.emit()
			_down = ""

	func _draw() -> void:
		var info := Wallet.level_info()
		AvatarView.draw_avatar(self, Rect2(size.x / 2.0 - 84, 4, 168, 168), str(Save.data["profile"]["avatar"]))
		var pen := 28.0
		draw_circle(Vector2(size.x / 2.0 + 58, 150), 22.0, Style.PAPER, true, -1.0, true)
		draw_texture_rect(Art.icon("pencil-simple", pen, Style.INK), Rect2(size.x / 2.0 + 58 - pen / 2, 150 - pen / 2, pen, pen), false)
		var name := str(Save.data["profile"]["name"])
		var f := Style.hand()
		var shown := name if name != "" else "Tap to add your name"
		var fs := Style.FS_44 if name != "" else Style.FS_30
		var ts := f.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f, Vector2((size.x - ts.x) / 2.0, 226), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Style.INK if name != "" else Color(Style.INK, 0.55))
		var fb := Style.sans_bold()
		var line := "Level %d, %s" % [info["level"], info["title"]]
		var ls := fb.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_26)
		draw_string(fb, Vector2((size.x - ls.x) / 2.0, 262), line, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_26, Color(Style.INK, 0.8))
		var bar := Rect2(size.x * 0.14, 276, size.x * 0.72, 14)
		draw_style_box(Style.box(Color(Style.INK, 0.1), 7), bar)
		var t := float(info["into"]) / float(info["need"])
		if t > 0.0:
			draw_style_box(Style.box(Style.TEAL, 7), Rect2(bar.position, Vector2(maxf(bar.size.x * t, 14.0), bar.size.y)))
		var xp := "%d / %d XP" % [info["into"], info["need"]]
		var xs := fb.get_string_size(xp, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_22)
		draw_string(fb, Vector2((size.x - xs.x) / 2.0, 298 + 18), xp, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_22, Color(Style.INK, 0.6))


## A stat on a paper card: the number big, the name under it.
class _Stat extends Control:
	var label := ""
	var value := 0

	func _init(l: String, v: int) -> void:
		label = l
		value = v
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := Style.box(Style.CARD, Style.R_L)
		sb.shadow_color = Color(Style.INK, 0.12)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 4)
		draw_style_box(sb, r)
		var f := Style.sans_heavy()
		var n := str(value)
		var ns := f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_44)
		draw_string(f, Vector2((size.x - ns.x) / 2.0, 58), n, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_44, Style.INK)
		var fb := Style.sans_bold()
		var ls := fb.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_22)
		draw_string(fb, Vector2((size.x - ls.x) / 2.0, 92), label, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_22, Color(Style.INK, 0.7))


## A friend (or you): avatar, name, the level they've reached.
class _Friend extends Control:
	var p := {}

	func _init(person: Dictionary) -> void:
		p = person
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(Style.box(Color(Style.APRICOT, 0.18) if p.get("me", false) else Color(Style.CARD, 0.9), Style.R_L), r)
		AvatarView.draw_avatar(self, Rect2(10, 8, size.y - 16, size.y - 16), str(p["avatar"]))
		var f := Style.sans_bold()
		draw_string(f, Vector2(size.y + 6, size.y / 2.0 + 10), str(p["name"]), HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.5, Style.FS_30, Style.INK)
		var fh := Style.sans_heavy()
		var lv := "Level %d" % int(p["level"])
		var ls := fh.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_26)
		draw_string(fh, Vector2(size.x - ls.x - 20, size.y / 2.0 + 9), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_26, Style.INK)
