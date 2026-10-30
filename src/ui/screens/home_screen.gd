## Home: the wordmark, the current shelf of the room, and one big Play button in the thumb zone.
## Functional layout for step 0; the art pass (plan-m2 §2-§3) restyles it.
class_name HomeScreen
extends Control

signal play_pressed
signal tutorial_pressed
signal settings_pressed

var next_id := ""
var _wordmark: Label
var _progress: Label
var _shelf: _Shelf
var _play: PillButton
var _help: PillButton
var _gear: RoundButton


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gear = RoundButton.new("gear")
	_gear.pressed.connect(func() -> void: settings_pressed.emit())
	add_child(_gear)
	_wordmark = Label.new()
	_wordmark.text = "Jarful"
	_wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wordmark.add_theme_font_size_override("font_size", 96)
	_wordmark.add_theme_color_override("font_color", Style.INK)
	add_child(_wordmark)
	_shelf = _Shelf.new()
	add_child(_shelf)
	_progress = Label.new()
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress.add_theme_font_size_override("font_size", 30)
	_progress.add_theme_color_override("font_color", Style.INK)
	add_child(_progress)
	_help = PillButton.new("How to play", false, 88.0)
	_help.font_size = 28
	_help.pressed.connect(func() -> void: tutorial_pressed.emit())
	add_child(_help)
	_play = PillButton.new("Play", true, 112.0)
	_play.font_size = 40
	_play.pressed.connect(func() -> void: play_pressed.emit())
	add_child(_play)


func refresh() -> void:
	var cat := Levels.catalog
	var save := Save.data
	next_id = Progression.next_level(cat, save)
	var room := Progression.current_room(cat, save)
	var ids := cat.room_ids(room)
	var solved := Progression.solved_count(cat, save, room)
	_progress.text = "The Larder, %d of %d" % [solved, ids.size()]
	_play.text = "Play level %d" % (cat.play_order().find(next_id) + 1) if next_id != "" else "Room complete"
	_play.queue_redraw()
	var shelf := 0 if next_id == "" else cat.shelf_of(next_id)
	var slots: Array = []
	for i in range(shelf * Catalog.SHELF, mini((shelf + 1) * Catalog.SHELF, ids.size())):
		var s: Dictionary = save["solved"].get(ids[i], {})
		slots.append({"solved": not s.is_empty(), "gold": bool(s.get("gold", false)), "next": ids[i] == next_id})
	_shelf.slots = slots
	_shelf.queue_redraw()
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	var ins := SafeArea.current(size)
	var top: float = ins["top"] + 10.0
	var w := size.x
	var content_w := minf(w - 64.0, 640.0)
	var left := (w - content_w) / 2.0
	_gear.position = Vector2(left, top)
	_gear.size = _gear.custom_minimum_size
	_wordmark.position = Vector2(0, top + 90)
	_wordmark.size = Vector2(w, 120)
	var bottom: float = size.y - ins["bottom"]
	_play.size = Vector2(content_w, 112)
	_play.position = Vector2(left, bottom - 112 - 56)
	_help.size = Vector2(320, 88)
	_help.position = Vector2((w - 320) / 2.0, _play.position.y - 88 - 28)
	_progress.position = Vector2(0, _help.position.y - 70)
	_progress.size = Vector2(w, 44)
	var shelf_top := _wordmark.position.y + 150
	_shelf.position = Vector2(left, shelf_top)
	_shelf.size = Vector2(content_w, maxf(200.0, _progress.position.y - 24 - shelf_top))


## The current shelf: 10 slots as 5 x 2, solved slots filled, the next one glowing.
class _Shelf extends Control:
	var slots: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var cols := 5
		var rows := 2
		var cell := Vector2(size.x / cols, minf(size.y / rows, 200.0))
		var y0 := (size.y - cell.y * rows) / 2.0
		for r in rows:
			var plank_y := y0 + cell.y * (r + 1) - 10
			draw_rect(Rect2(0, plank_y, size.x, 12), Style.WOOD)
		for i in slots.size():
			var s: Dictionary = slots[i]
			var c := Vector2((i % cols + 0.5) * cell.x, y0 + (i / cols) * cell.y)
			var jar := Rect2(c.x - cell.x * 0.32, c.y + cell.y * 0.22, cell.x * 0.64, cell.y * 0.66)
			if s["solved"]:
				draw_rect(jar, Style.GLASS_EDGE)
				draw_rect(Rect2(jar.position.x - 4, jar.position.y - 12, jar.size.x + 8, 14),
					Style.APRICOT if s["gold"] else Style.PAPRIKA)
			else:
				draw_rect(jar, Color(Style.INK, 0.25 if s["next"] else 0.1), false, 3.0)
