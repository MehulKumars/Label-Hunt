## Levels: every room as a card in a vertical, touch-scrolled list, opened at the current room. A card shows the
## room's wall and jars, its name, how many jars are filled and the gold lids; locked rooms say when they open.
class_name LevelsScreen
extends Control

signal back_pressed
signal room_pressed(room: int)

const CARD_H := 236.0
const GAP := 20.0

var header: ScreenHeader
var scroll: ScrollContainer
var list: VBoxContainer
var _current := 1


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	header = ScreenHeader.new("Levels")
	header.back_pressed.connect(func() -> void: back_pressed.emit())
	add_child(header)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", int(GAP))
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)


func refresh() -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	var cat := Levels.catalog
	var save := Save.data
	_current = Progression.current_room(cat, save)
	for room in cat.room_numbers():
		var ids := cat.room_ids(room)
		var card := RoomCard.new()
		card.room = room
		card.name_text = cat.room_name(room)
		card.solved = Progression.solved_count(cat, save, room)
		card.total = ids.size()
		card.gold = Progression.gold_count(cat, save, room)
		card.first_level = cat.order_index(ids[0]) + 1 if not ids.is_empty() else 0
		card.locked = ids.is_empty() or not Progression.is_unlocked(cat, save, ids[0])
		card.current = room == _current
		card.custom_minimum_size = Vector2(0, CARD_H)
		card.pressed.connect(func() -> void: room_pressed.emit(room))
		list.add_child(card)
	var end := Label.new()
	end.text = "More rooms are being stocked."
	end.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end.add_theme_font_override("font", Style.hand())
	end.add_theme_font_size_override("font_size", Style.FS_36)
	end.add_theme_color_override("font_color", Color(Style.INK, 0.6))
	end.custom_minimum_size = Vector2(0, 120)
	list.add_child(end)
	_layout()
	# Open on the current room, once the list has laid out.
	await get_tree().process_frame
	var i := cat.room_numbers().find(_current)
	scroll.scroll_vertical = maxi(0, roundi(i * (CARD_H + GAP) - CARD_H * 0.5))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	var y := header.place(size)
	var bottom: float = size.y - SafeArea.current(size)["bottom"]
	scroll.position = Vector2(Style.GUTTER, y + 8.0)
	scroll.size = Vector2(size.x - Style.GUTTER * 2.0, bottom - y - 8.0)


## One room: a window onto its wall with three of its jars, the name in hand lettering, progress and gold lids.
class RoomCard extends Control:
	signal pressed

	var room := 1
	var name_text := ""
	var solved := 0
	var total := 30
	var gold := 0
	var first_level := 1
	var locked := false
	var current := false
	var _down := false
	var _press_at := Vector2.ZERO
	var _scrolling := false

	func _init() -> void:
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
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				Sfx.play("tap", 1.0, 0.05, -4.0)
				pressed.emit()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var th := Themes.of(room)
		if current:
			draw_style_box(Style.glow(Color(Style.APRICOT, 0.55), Style.R_XL, 10), r)
		var sb := Style.box(Themes.color(room, "wall", 0), Style.R_XL)
		sb.shadow_color = Color(Style.INK, 0.16)
		sb.shadow_size = 12
		sb.shadow_offset = Vector2(0, 6)
		draw_style_box(sb, r)
		draw_texture_rect(Art.tex("card_wall|%d" % room, r.size, RoomArt.wall.bind(room, Style.R_XL)), r, false)
		# Three jars standing on a short plank at the left.
		var plank := Rect2(18, r.size.y - 50, r.size.x * 0.42, 26)
		draw_texture_rect(Art.tex("card_plank|%d" % room, plank.size, RoomArt.plank.bind(room)), plank, false)
		var jw := plank.size.x / 3.6
		var layers_sets := [[Style.APRICOT, Style.PAPRIKA], [Color("#8A9A4B"), Color("#EBD3A2")], [Color("#5B4A7A"), Color("#E8A04A")]]
		for i in 3:
			var jar := Rect2(plank.position.x + 10 + i * (jw + 6), plank.position.y - jw * 1.4 + 4, jw, jw * 1.4)
			var lyr: Array = layers_sets[i] if solved > i * 10 else []
			var key := "card_jar|%d|%d" % [room, lyr.size()]
			draw_texture_rect(Art.tex(key, jar.size, RoomArt.mini_jar.bind(room, lyr, lyr.is_empty())), jar, false)
		var x := r.size.x * 0.5
		var w := r.size.x - x - 22
		var f := Style.sans_bold()
		draw_string(f, Vector2(x, 46), "Room %d" % room, HORIZONTAL_ALIGNMENT_LEFT, w, Style.FS_22, Color(Style.INK, 0.65))
		var hand := Style.hand()
		var fs := Style.FS_44
		while fs > Style.FS_30 and hand.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
			fs -= 2
		draw_string(hand, Vector2(x, 46 + fs * 1.05), name_text, HORIZONTAL_ALIGNMENT_LEFT, w, fs, Style.INK)
		if locked:
			draw_style_box(Style.box(Color(Style.PAPER, 0.55), Style.R_XL), r)
			var isz := 34.0
			draw_texture_rect(Art.icon("lock-simple", isz, Style.INK_SOFT), Rect2(x, r.size.y - 74, isz, isz), false)
			draw_string(f, Vector2(x + isz + 10, r.size.y - 48), "Opens at level %d" % first_level, HORIZONTAL_ALIGNMENT_LEFT,
				w - isz - 10, Style.FS_26, Style.INK)
			return
		var bar := Rect2(x, r.size.y - 66, w, 14)
		draw_style_box(Style.box(Color(Style.INK, 0.1), 7), bar)
		if solved > 0:
			draw_style_box(Style.box(Style.TEAL, 7), Rect2(bar.position, Vector2(bar.size.x * solved / float(maxi(total, 1)), bar.size.y)))
		var fh := Style.sans_heavy()
		draw_string(fh, Vector2(x, r.size.y - 22), "%d / %d" % [solved, total], HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_26, Style.INK)
		if gold > 0:
			var gx := x + w - 70
			draw_circle(Vector2(gx, r.size.y - 31), 11.0, Style.GOLD, true, -1.0, true)
			draw_string(fh, Vector2(gx + 18, r.size.y - 22), str(gold), HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_26, Style.INK)
