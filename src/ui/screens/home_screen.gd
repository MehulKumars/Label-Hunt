## Home. The hero is a big glass jar labelled "Jarful" that fills with a layer for every category sorted in this
## room (full when the room is done). Below it the cabinet holds the current shelf, one layered jar per solved level,
## then one big Play button in the thumb zone. Settings top left, How to play top right.
class_name HomeScreen
extends Control

signal play_pressed
signal tutorial_pressed
signal settings_pressed

const ROOM_NAMES := {1: "The Larder"}

var next_id := ""
var _gear: RoundButton
var _help: RoundButton
var _hero: _HeroJar
var _cabinet: _Cabinet
var _shelf: ShelfView
var _count: Label
var _play: PillButton


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gear = RoundButton.new("gear")
	_gear.pressed.connect(func() -> void: settings_pressed.emit())
	add_child(_gear)
	_help = RoundButton.new("help")
	_help.pressed.connect(func() -> void: tutorial_pressed.emit())
	add_child(_help)
	_hero = _HeroJar.new()
	add_child(_hero)
	_cabinet = _Cabinet.new()
	add_child(_cabinet)
	_shelf = ShelfView.new()
	add_child(_shelf)
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_font_override("font", Style.sans_bold())
	_count.add_theme_font_size_override("font_size", Style.FS_26)
	_count.add_theme_color_override("font_color", Style.INK_SOFT)
	add_child(_count)
	_play = PillButton.new("Play", true, Style.TOUCH_PRIMARY + 8.0)
	_play.icon = "play"
	_play.font_size = Style.FS_36
	_play.pressed.connect(func() -> void: play_pressed.emit())
	add_child(_play)


func refresh() -> void:
	var cat := Levels.catalog
	var save := Save.data
	next_id = Progression.next_level(cat, save)
	var room := Progression.current_room(cat, save)
	var ids := cat.room_ids(room)
	var solved := Progression.solved_count(cat, save, room)
	_cabinet.title = ROOM_NAMES.get(room, "Room %d" % room)
	_count.text = "%d of %d jars filled" % [solved, ids.size()]
	_play.text = "Play level %d" % (cat.play_order().find(next_id) + 1) if next_id != "" else "Room complete"
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
	var shelf := 0 if next_id == "" else cat.shelf_of(next_id)
	var from := shelf * Catalog.SHELF
	_shelf.slots = ShelfView.slots_for(ids.slice(from, mini(from + Catalog.SHELF, ids.size())), save, next_id)
	_shelf.queue_redraw()
	_shelf.breathe()
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
	_gear.position = Vector2(left, top)
	_gear.size = _gear.custom_minimum_size
	_help.position = Vector2(w - left - RoundButton.D, top)
	_help.size = _help.custom_minimum_size
	_play.size = Vector2(w - left * 2.0, Style.TOUCH_PRIMARY + 8.0)
	_play.position = Vector2(left, bottom - _play.size.y - 40.0)
	_count.size = Vector2(w, 40)
	_count.position = Vector2(0, _play.position.y - 40 - 28.0)
	var cab_h := 440.0
	_cabinet.size = Vector2(w - (left - 8.0) * 2.0, cab_h)
	_cabinet.position = Vector2(left - 8.0, _count.position.y - 20.0 - cab_h)
	_shelf.position = _cabinet.position + Vector2(30, 56)
	_shelf.size = _cabinet.size - Vector2(60, 82)
	# The hero jar takes the room between the top bar and the cabinet's name tag.
	var hero_top := top + RoundButton.D * 0.4
	var hero_h := clampf(_cabinet.position.y - 56.0 - hero_top, 240.0, 470.0)
	var hero_w := minf(hero_h * 0.78, w - 2.0 * (left + RoundButton.D + 12.0))
	_hero.size = Vector2(hero_w, hero_h)
	_hero.position = Vector2((w - hero_w) / 2.0, hero_top + (_cabinet.position.y - 56.0 - hero_top - hero_h) / 2.0)


## The big jar: glass, its contents, a paprika lid (gold when the room is complete) and the "Jarful" label.
class _HeroJar extends Control:
	var layers: Array = []
	var frac := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var neck := Materials.jar_rim(size.y)
		draw_texture_rect(Art.tex("hero_back", size, Materials.jar_back), r, false)
		var key := "hero_fill|%d|%.3f|%d" % [layers.size(), frac, hash(layers)]
		draw_texture_rect(Art.tex(key, size, Materials.jar_contents.bind(layers, frac)), r, false)
		draw_texture_rect(Art.tex("hero_front", size, Materials.jar_front), r, false)
		var ni := Materials.jar_neck(size.x)
		var lid := Vector2(size.x - ni * 2.0 + 18.0, neck * 1.3)
		var lid_color := Style.GOLD if frac >= 1.0 else Style.PAPRIKA
		draw_texture_rect(Art.tex("hero_lid_" + lid_color.to_html(false), lid, Materials.lid.bind(lid_color)),
			Rect2(Vector2(ni - 9.0, -lid.y * 0.5), lid), false)
		var f := Style.hand()
		var fs := clampi(roundi(size.x * 0.27), 56, 96)
		var ts := f.get_string_size("Jarful", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var tag := Vector2(minf(size.x * 0.86, ts.x + 48.0), fs * 1.05)
		draw_set_transform(Vector2(size.x / 2.0, neck + (size.y - neck) * 0.42), deg_to_rad(-3.0), Vector2.ONE)
		draw_texture_rect(Art.tex("hero_label", tag, Materials.label.bind(false)), Rect2(-tag / 2.0, tag), false)
		draw_string(f, Vector2(-ts.x / 2.0, f.get_ascent(fs) * 0.36), "Jarful", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.INK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The wooden cabinet, with the room's name on a kraft label pinned to its crown.
class _Cabinet extends Control:
	var title := "":
		set(v):
			title = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_texture_rect(Art.tex("cabinet", size, Materials.cabinet), Rect2(Vector2.ZERO, size), false)
		var f := Style.hand()
		var fs := Style.FS_44
		var ts := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var tag := Vector2(ts.x + 56.0, 66.0)
		draw_set_transform(Vector2(size.x / 2.0, 6.0), deg_to_rad(-2.0), Vector2.ONE)
		draw_texture_rect(Art.tex("room_tag", tag, Materials.label.bind(false)), Rect2(-tag / 2.0, tag), false)
		draw_circle(Vector2(0, -tag.y / 2.0 + 9.0), 4.5, Style.WOOD_DARK, true, -1.0, true)
		draw_string(f, Vector2(-ts.x / 2.0, f.get_ascent(fs) * 0.36), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.INK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
