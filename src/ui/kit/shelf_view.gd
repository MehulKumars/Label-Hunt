## A run of shelf slots, one per level: solved levels as layered jars (a gold lid for a clean solve), the next level
## glowing gently, later ones as faint outlines. Home shows the current shelf (5 x 2); Win shows the row the new
## jar drops into.
class_name ShelfView
extends Control

## [{state: "solved"|"next"|"locked", layers: Array[Color], gold: bool, stars: int, number: int}]
var slots: Array = []
var cols := 5
## The slot whose jar is dropping in (Win), and how far it has fallen (0..1).
var drop_index := -1
var drop_t := 1.0:
	set(v):
		drop_t = v
		queue_redraw()
var glow := 0.0:
	set(v):
		glow = v
		queue_redraw()
## The room whose wood and jars to draw (Themes).
var room := 1
## In the room view, slots are tappable.
var tappable := false:
	set(v):
		tappable = v
		mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE

signal slot_pressed(index: int)

var _down := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func slot_at(pos: Vector2) -> int:
	if slots.is_empty():
		return -1
	var rows := ceili(slots.size() / float(cols))
	var cell := Vector2(size.x / cols, size.y / rows)
	var i := int(pos.y / cell.y) * cols + int(pos.x / cell.x)
	return i if i >= 0 and i < slots.size() and Rect2(Vector2.ZERO, size).has_point(pos) else -1


## Where slot i's jar stands (for flights and highlights), in local coordinates.
func slot_rect(i: int) -> Rect2:
	var rows := ceili(slots.size() / float(cols))
	var cell := Vector2(size.x / cols, size.y / rows)
	var jar := Vector2(minf(cell.x * 0.74, 104.0), 0.0)
	jar.y = minf(jar.x * 1.4, cell.y - 34.0)
	var base := Vector2((i % cols + 0.5) * cell.x, cell.y * (i / cols + 1) - 14.0)
	return Rect2(base - Vector2(jar.x / 2.0, jar.y), jar)


func _gui_input(event: InputEvent) -> void:
	if not tappable or not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if event.is_canceled():
		_down = -1
	elif event.pressed:
		_down = slot_at(event.position)
	elif _down >= 0:
		var i := slot_at(event.position)
		if i == _down:
			Sfx.play("tap", 1.0, 0.05, -4.0)
			slot_pressed.emit(i)
		_down = -1


## Three slow breaths on the next slot, then rest (no endless redraws on an idle screen).
func breathe() -> void:
	glow = 0.35
	var tw := create_tween()
	for i in 3:
		tw.tween_property(self, "glow", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(self, "glow", 0.35, 0.9).set_trans(Tween.TRANS_SINE)


func _draw() -> void:
	if slots.is_empty():
		return
	var rows := ceili(slots.size() / float(cols))
	var cell := Vector2(size.x / cols, size.y / rows)
	var jar := Vector2(minf(cell.x * 0.74, 104.0), 0.0)
	jar.y = minf(jar.x * 1.4, cell.y - 34.0)
	for r in rows:
		var plank := Rect2(-6.0, cell.y * (r + 1) - 16.0, size.x + 12.0, 34.0)
		draw_texture_rect(Art.tex("shelf_plank|%d" % room, plank.size, RoomArt.plank.bind(room)), plank, false)
	for i in slots.size():
		var s: Dictionary = slots[i]
		var rect := slot_rect(i)
		match str(s["state"]):
			"solved":
				if i == drop_index:
					rect.position.y -= (1.0 - _bounce(clampf(drop_t, 0.0, 1.0))) * cell.y * 0.9
				var layers: Array = s["layers"]
				var key := "mini|%d|%s|%s" % [room, ",".join(layers.map(func(c: Color) -> String: return c.to_html(false))), s["gold"]]
				draw_texture_rect(Art.tex(key, jar, RoomArt.mini_jar.bind(room, layers, false, bool(s["gold"]))), rect, false)
				if i != drop_index or drop_t >= 1.0:
					_stars(rect, int(s.get("stars", 0)), cell)
			_:
				draw_texture_rect(Art.tex("mini_outline|%d" % room, jar, RoomArt.mini_jar.bind(room, [], true)), rect, false)
				_number(rect, s, str(s["state"]) == "next")


## Falls, lands, one small bounce.
static func _bounce(t: float) -> float:
	if t < 0.7:
		return ease(t / 0.7, 2.4)
	return 1.0 - sin((t - 0.7) / 0.3 * PI) * 0.06


## Slot data for a run of room levels from the save: layers are each solved category's preserve colour.
static func slots_for(ids: PackedStringArray, save: Dictionary, next_id: String) -> Array:
	var out: Array = []
	for id in ids:
		var s: Dictionary = save["solved"].get(id, {})
		if s.is_empty():
			out.append({"state": "next" if id == next_id else "locked", "layers": [], "gold": false,
				"number": Levels.catalog.order_index(id) + 1, "kind": str(Levels.catalog.entry(id).get("kind", ""))})
			continue
		var labels: Array = []
		for g: Dictionary in Levels.catalog.entry(id)["data"].get("groups", []):
			labels.append(str(g.get("label", "")))
		var layers := Materials.preserve_layers(labels)
		out.append({"state": "solved", "layers": layers, "gold": bool(s.get("gold", false)),
			"stars": int(s.get("stars", 1)), "number": Levels.catalog.order_index(id) + 1})
	return out


## Empty slots carry a small kraft tag with their level number; the next level's tag is apricot and breathes.
func _number(rect: Rect2, s: Dictionary, next: bool) -> void:
	var n := str(s.get("number", ""))
	var f := Style.sans_heavy() if next else Style.sans_bold()
	var fs := Style.FS_26 if next else Style.FS_22
	var ts := f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var c := rect.get_center() + Vector2(0, rect.size.y * 0.1)
	var grow := 1.0 + (0.08 * glow if next else 0.0)
	var tag := Vector2(maxf(ts.x + 18.0, 38.0), fs + 12.0) * grow
	var fill: Color = Style.APRICOT if next else Color("#E7D1A8")
	draw_style_box(Style.box(Color(Style.INK, 0.16), Style.R_S), Rect2(c - tag / 2.0 + Vector2(0, 2), tag))
	draw_style_box(Style.box(fill, Style.R_S), Rect2(c - tag / 2.0, tag))
	draw_string(f, Vector2(c.x - ts.x / 2.0, c.y - f.get_height(fs) / 2.0 + f.get_ascent(fs)), n,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.INK if next else Color(Style.INK, 0.7))
	# Tricky and hard levels carry their peppers above the tag, inside the jar outline.
	var spice := minf(rect.size.x * 0.24, 26.0)
	SpiceMark.draw_at(self, Vector2(c.x, c.y - tag.y / 2.0 - spice * 0.75), str(s.get("kind", "")), spice,
		Style.PAPRIKA if next else Color(Style.PAPRIKA, 0.7))


## The stars a solved level earned, stamped small on the plank's front edge under its jar.
func _stars(rect: Rect2, n: int, cell: Vector2) -> void:
	if n <= 0:
		return
	var sz := clampf(cell.x * 0.14, 12.0, 18.0)
	var on := Art.tex("star_on_%d" % int(sz), Vector2(sz, sz), Materials.star.bind(true))
	var off := Art.tex("star_off_%d" % int(sz), Vector2(sz, sz), Materials.star.bind(false))
	var w := sz * 3.0 + 4.0
	var x := rect.get_center().x - w / 2.0
	var y := rect.end.y + 2.0
	for i in 3:
		draw_texture_rect(on if i < n else off, Rect2(x + i * (sz + 2.0), y, sz, sz), false)
