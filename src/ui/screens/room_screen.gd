## One room: its three shelves of ten levels in the room's wood and jars. Solved jars open a card with their labels
## and "Play again"; the next level plays; a locked slot wobbles its number.
class_name RoomScreen
extends Control

signal back_pressed
signal level_pressed(id: String)

var header: ScreenHeader
var room := 1
## Where this room was opened from ("home" or "levels"), for Back.
var origin := "home"
var shelves: Array[ShelfView] = []
var _ids: PackedStringArray = []
var _count: Label
var _play: PillButton
var _next := ""


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	header = ScreenHeader.new("")
	header.back_pressed.connect(func() -> void: back_pressed.emit())
	add_child(header)
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_font_override("font", Style.sans_bold())
	_count.add_theme_font_size_override("font_size", Style.FS_26)
	_count.add_theme_color_override("font_color", Color(Style.INK, 0.78))
	add_child(_count)
	_play = PillButton.new("Play", true, Style.TOUCH_PRIMARY)
	_play.icon = "play"
	_play.pressed.connect(func() -> void: level_pressed.emit(_next))
	add_child(_play)
	for i in 3:
		var s := ShelfView.new()
		s.tappable = true
		s.slot_pressed.connect(_on_slot.bind(i))
		shelves.append(s)
		add_child(s)


func show_room(r: int, from: String) -> void:
	room = r
	origin = from
	var cat := Levels.catalog
	_ids = cat.room_ids(room)
	header.title = cat.room_name(room)
	var save := Save.data
	var next := Progression.next_level(cat, save)
	_count.text = "%d of %d jars filled, %d gold lids" % [Progression.solved_count(cat, save, room), _ids.size(),
		Progression.gold_count(cat, save, room)]
	for i in 3:
		var s := shelves[i]
		s.room = room
		var from_i := i * Catalog.SHELF
		var part := _ids.slice(from_i, mini(from_i + Catalog.SHELF, _ids.size()))
		var slots := ShelfView.slots_for(part, save, next)
		# Levels unlocked out of order (an old save) show as "next" too, so they read as playable.
		for k in slots.size():
			if slots[k]["state"] == "locked" and Progression.is_unlocked(cat, save, part[k]):
				slots[k]["state"] = "next"
		s.slots = slots
		s.visible = not part.is_empty()
		s.queue_redraw()
	shelves[0].breathe()
	# The room's next level, if it has one, gets the same Play button as Home.
	_next = next if next != "" and cat.entry(next)["room"] == room else ""
	_play.visible = _next != ""
	if _play.visible:
		_play.text = "Play level %d" % (cat.order_index(_next) + 1)
		_play.queue_redraw()
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	var y := header.place(size)
	var bottom: float = size.y - SafeArea.current(size)["bottom"] - 24.0
	if _play.visible:
		_play.size = Vector2(size.x - Style.GUTTER * 2.0, Style.TOUCH_PRIMARY)
		_play.position = Vector2(Style.GUTTER, bottom - Style.TOUCH_PRIMARY)
		bottom = _play.position.y - 16.0
	_count.position = Vector2(0, y)
	_count.size = Vector2(size.x, 36)
	y += 48.0
	var h := minf((bottom - y) / 3.0, 400.0)
	for i in 3:
		shelves[i].position = Vector2(Style.GUTTER, y + i * h)
		shelves[i].size = Vector2(size.x - Style.GUTTER * 2.0, h - 12.0)


func _on_slot(index: int, shelf: int) -> void:
	var i := shelf * Catalog.SHELF + index
	if i >= _ids.size():
		return
	var id := _ids[i]
	if Progression.is_unlocked(Levels.catalog, Save.data, id):
		level_pressed.emit(id)
	else:
		Haptics.slip()
		var s := shelves[shelf]
		var x := s.position.x
		var tw := s.create_tween()
		for dx in [6.0, -5.0, 3.0, 0.0]:
			tw.tween_property(s, "position:x", x + dx, 0.04)
