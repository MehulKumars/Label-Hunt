## The label rail: one kraft luggage tag per group, hanging on twine from a wooden rod, showing how much of its
## label the player has earned. A blank tag, then the context words with the key word as blank letter tiles
## ("Things with ▢▢▢▢"), then the key's first letter, then the full label in hand lettering once the lid is on.
## Hints are Atkinson: during play they're the puzzle's key information.
class_name LabelRail
extends Control

const TAG_H := 58.0
const GAP := 10.0
const ROD := 12.0
const TWINE := 12.0
const HOLE_W := 30.0
const TILE_GAP := 3.0
## Blank letter tiles in ink at 40%: well over 3:1 on kraft, so the hidden word's length always reads.
const TILE := Color(0.239, 0.173, 0.18, 0.4)

signal tag_picked(group: int)

var session: Session
## The group chosen for Complete (-1 = none yet).
var selected := -1
var _pulse := {}
var _choosing := false
var _breath := 0.0
var _press_tag := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func setup(s: Session) -> void:
	session = s
	_pulse.clear()
	queue_redraw()


static func columns(groups: int) -> int:
	return 3 if groups > 4 else 2


static func height_for(groups: int) -> float:
	var rows := ceili(groups / float(columns(groups)))
	return rows * (ROD + TWINE + TAG_H) + (rows - 1) * GAP


func pulse(g: int) -> void:
	_pulse[g] = 1.0
	create_tween().tween_method(func(v: float) -> void:
		_pulse[g] = v
		queue_redraw(), 1.0, 0.0, 0.6)


## While Complete is choosing, the unsolved tags breathe and can be tapped (it adds no information: they're just the
## choices); the chosen one glows steadily.
func set_choosing(on: bool) -> void:
	_choosing = on
	selected = -1
	set_process(on)
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	queue_redraw()


## While choosing: a tap anywhere in a tag's cell (tag, twine and half the gap around it, a thumb-sized target)
## picks that group, if it isn't solved yet.
func _gui_input(event: InputEvent) -> void:
	if not _choosing or not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if event.pressed:
		_press_tag = _tag_at(event.position)
	elif _press_tag >= 0 and _tag_at(event.position) == _press_tag:
		selected = _press_tag
		Sfx.play("tap", 1.1, 0.03, -2.0)
		tag_picked.emit(selected)
		queue_redraw()


func _tag_at(pos: Vector2) -> int:
	for g in session.level.group_count():
		if session.board.is_solved(g):
			continue
		var r := tag_rect(g)
		if Rect2(r.position - Vector2(GAP / 2.0, ROD + TWINE), r.size + Vector2(GAP, ROD + TWINE + GAP / 2.0)).has_point(pos):
			return g
	return -1


func _process(delta: float) -> void:
	_breath += delta
	queue_redraw()


## A tag's rect in rail coordinates (before its small tilt).
func tag_rect(g: int) -> Rect2:
	var groups := session.level.group_count()
	var cols := columns(groups)
	var w := (size.x - (cols - 1) * GAP) / cols
	var row_h := ROD + TWINE + TAG_H + GAP
	var row := g / cols
	var in_row := mini(cols, groups - row * cols)
	# A part-filled last row is centred under the rod.
	var x0 := (size.x - (in_row * w + (in_row - 1) * GAP)) / 2.0
	return Rect2(x0 + (g % cols) * (w + GAP), row * row_h + ROD + TWINE, w, TAG_H)


func tag_center(g: int) -> Vector2:
	return tag_rect(g).get_center()


func _draw() -> void:
	if session == null:
		return
	var groups := session.level.group_count()
	var cols := columns(groups)
	var rows := ceili(groups / float(cols))
	var row_h := ROD + TWINE + TAG_H + GAP
	for row in rows:
		var rod := Rect2(-6.0, row * row_h, size.x + 12.0, ROD + 14.0)
		draw_texture_rect(Art.tex("rod", rod.size, Materials.plank), rod, false)
	for g in groups:
		_draw_tag(g, tag_rect(g), -1.2 if g % 2 == 0 else 1.0)


func _draw_tag(g: int, r: Rect2, tilt: float) -> void:
	var step := session.know.step[g]
	var lidded := _is_lidded(g)
	var color := Style.tag_color(g)
	var eyelet := r.position + Vector2(HOLE_W * 0.55, (r.size.y - 3.0) / 2.0)
	# Twine from the rod down to the eyelet.
	draw_line(Vector2(eyelet.x - 4.0, r.position.y - TWINE - 2.0), eyelet, Color(Style.INK, 0.45), 1.6, true)
	draw_set_transform(eyelet, deg_to_rad(tilt), Vector2.ONE)
	var local := Rect2(r.position - eyelet, r.size)
	var p: float = _pulse.get(g, 0.0)
	if _choosing and not lidded:
		p = maxf(p, 1.0 if g == selected else (0.25 + 0.2 * sin(_breath * 4.0) if selected >= 0 else 0.45 + 0.35 * sin(_breath * 4.0)))
	if p > 0.0:
		draw_style_box(Style.glow(Color(Style.APRICOT, 0.7 * p), 10, int(14 * p)), local)
	draw_texture_rect(Art.tex("hang_tag", r.size, Materials.tag), local, false)
	if lidded:
		draw_rect(Rect2(local.position + Vector2(HOLE_W, 3), Vector2(local.size.x - HOLE_W - 4, local.size.y - 9)), Color(color, 0.12))
	var face := Rect2(local.position, Vector2(local.size.x, local.size.y - 3.0))
	var x := face.position.x + HOLE_W
	if step > 0:
		var c := Vector2(x + 13, face.get_center().y)
		draw_circle(c, 13.0, Style.CARD, true, -1.0, true)
		draw_circle(c, 11.0, color, true, -1.0, true)
		Style.draw_glyph(self, g, c, 5.6, Style.PAPER)
		x += 32.0
	var avail := face.end.x - x - 8.0
	if session.board.sealed[g] == 1:
		# Sealed by Complete: a small lidded jar on the tag says where its cards went.
		var isz := 24.0
		draw_texture_rect(Art.icon("jar-seal", isz, Color(Style.INK, 0.75)),
			Rect2(Vector2(face.end.x - isz - 6.0, face.get_center().y - isz / 2.0), Vector2(isz, isz)), false)
		avail -= isz + 6.0
	var group: Dictionary = session.level.groups[g]
	if lidded or step >= Knowledge.FULL_STEP:
		_draw_solved(group["label"], Rect2(x, face.position.y, avail, face.size.y))
	elif step > 0:
		_draw_hint(group["label"], group["key"], step, Rect2(x, face.position.y, avail, face.size.y))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_solved(text: String, area: Rect2) -> void:
	var font := Style.hand()
	var fs := Style.FS_30
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > area.size.x:
		fs = Style.FS_26
	var lines := JarView._wrap(text, font, fs, area.size.x)
	var line_h := fs * 0.95
	var top := area.get_center().y - line_h * lines.size() / 2.0
	for i in lines.size():
		draw_string(font, Vector2(area.position.x, top + i * line_h + font.get_ascent(fs) * 0.9), lines[i],
			HORIZONTAL_ALIGNMENT_LEFT, area.size.x, fs, Style.INK)


## Context words in Atkinson, the key word as letter tiles (its first letter shown from step 2). One line at 26, 24
## or 22 when it fits, else two lines at 22 (the floor).
func _draw_hint(label: String, key: String, step: int, area: Rect2) -> void:
	var font := Style.sans_bold()
	var tokens := _tokens(label, key, step)
	for fs in [Style.FS_26, 24, Style.FS_22]:
		var lines := _layout_tokens(tokens, font, fs, area.size.x)
		if lines.size() == 1:
			_paint(lines, font, fs, area)
			return
	_paint(_layout_tokens(tokens, font, Style.FS_22, area.size.x), font, Style.FS_22, area)


## [{text, tiles: bool, first: String}] in reading order.
func _tokens(label: String, key: String, step: int) -> Array:
	var out: Array = []
	var at := label.findn(key)
	if at < 0:
		for w in label.split(" ", false):
			out.append({"text": w, "tiles": false})
		return out
	for w in label.substr(0, at).split(" ", false):
		out.append({"text": w, "tiles": false})
	var key_words := label.substr(at, key.length()).split(" ", false)
	for i in key_words.size():
		out.append({"text": key_words[i], "tiles": true, "first": key_words[i][0] if step >= 2 and i == 0 else ""})
	for w in label.substr(at + key.length()).split(" ", false):
		out.append({"text": w, "tiles": false})
	return out


func _token_w(t: Dictionary, font: Font, fs: int) -> float:
	if t["tiles"]:
		var n: int = (t["text"] as String).length()
		return n * fs * 0.52 + (n - 1) * TILE_GAP
	return font.get_string_size(t["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


func _layout_tokens(tokens: Array, font: Font, fs: int, max_w: float) -> Array:
	var lines: Array = [[]]
	var line_w := 0.0
	var space := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	for t: Dictionary in tokens:
		var tw := _token_w(t, font, fs)
		if not (lines.back() as Array).is_empty() and line_w + space + tw > max_w:
			lines.append([])
			line_w = 0.0
		line_w += (space if line_w > 0.0 else 0.0) + tw
		(lines.back() as Array).append(t)
	return lines


func _paint(lines: Array, font: Font, fs: int, area: Rect2) -> void:
	var line_h := fs * (1.15 if lines.size() == 1 else 1.04)
	var top := area.get_center().y - line_h * lines.size() / 2.0
	var space := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	for i in lines.size():
		var x := area.position.x
		var base := top + i * line_h + font.get_ascent(fs) * 0.95
		for t: Dictionary in lines[i]:
			if t["tiles"]:
				var tile := Vector2(fs * 0.52, fs * 0.78)
				for k in (t["text"] as String).length():
					var tr := Rect2(x + k * (tile.x + TILE_GAP), base - tile.y + 2.0, tile.x, tile.y)
					draw_style_box(Style.box(TILE, 4), tr)
					if k == 0 and t["first"] != "":
						var ch: String = t["first"]
						var cw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
						draw_string(font, Vector2(tr.get_center().x - cw / 2.0, base), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.INK)
			else:
				draw_string(font, Vector2(x, base), t["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.INK)
			x += _token_w(t, font, fs) + space


## Lidded in a jar, or sealed by Complete.
func _is_lidded(g: int) -> bool:
	return session.board.is_solved(g)
