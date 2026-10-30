## The label rail: one kraft tag per group standing on a wooden ledge, showing how much of its label the player has
## earned. A blank tag, then the context words with the key word as blank letter tiles ("Things with ▢▢▢▢"), then
## the key's first letter, then the full label in hand lettering once the lid is on. Hints are Atkinson: during
## play they're the puzzle's key information.
class_name LabelRail
extends Control

const TAG_H := 64.0
const GAP := 10.0
const LEDGE := 12.0
const HOLE_W := 26.0
const TILE_GAP := 3.0
## Blank letter tiles: at least 3:1 against the kraft so the hidden word's length always reads.
const TILE := Color("#A88A5C")

var session: Session
var _pulse := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(s: Session) -> void:
	session = s
	_pulse.clear()
	queue_redraw()


static func columns(groups: int) -> int:
	return 3 if groups > 4 else 2


static func height_for(groups: int) -> float:
	var rows := ceili(groups / float(columns(groups)))
	return rows * (TAG_H + LEDGE) + (rows - 1) * GAP


func pulse(g: int) -> void:
	_pulse[g] = 1.0
	create_tween().tween_method(func(v: float) -> void:
		_pulse[g] = v
		queue_redraw(), 1.0, 0.0, 0.6)


func _draw() -> void:
	if session == null:
		return
	var groups := session.level.group_count()
	var cols := columns(groups)
	var rows := ceili(groups / float(cols))
	var w := (size.x - (cols - 1) * GAP) / cols
	for row in rows:
		var y := row * (TAG_H + LEDGE + GAP) + TAG_H - 3.0
		var ledge := Rect2(-8.0, y, size.x + 16.0, LEDGE + 16.0)
		draw_texture_rect(Art.tex("ledge", ledge.size, Materials.plank), ledge, false)
	for g in groups:
		var r := Rect2((g % cols) * (w + GAP), (g / cols) * (TAG_H + LEDGE + GAP), w, TAG_H)
		_draw_tag(g, r)


func _draw_tag(g: int, r: Rect2) -> void:
	var step := session.know.step[g]
	var lidded := _is_lidded(g)
	var color := Style.tag_color(g)
	var p: float = _pulse.get(g, 0.0)
	if p > 0.0:
		draw_style_box(Style.glow(Color(Style.APRICOT, 0.7 * p), 10, int(14 * p)), r)
	draw_texture_rect(Art.tex("tag", r.size, Materials.label.bind(true)), r, false)
	if lidded:
		draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, r.size.y - 9)), Color(color, 0.12))
	var face := Rect2(r.position, Vector2(r.size.x, r.size.y - 3.0))
	var x := r.position.x + HOLE_W
	if step > 0:
		var c := Vector2(x + 12, face.get_center().y)
		draw_circle(c, 12.0, color, true, -1.0, true)
		Style.draw_glyph(self, g, c, 5.8, Style.PAPER)
		x += 30.0
	var avail := face.end.x - x - 8.0
	var group: Dictionary = session.level.groups[g]
	if lidded or step >= Knowledge.FULL_STEP:
		_draw_solved(group["label"], Rect2(x, face.position.y, avail, face.size.y))
	elif step > 0:
		_draw_hint(group["label"], group["key"], step, Rect2(x, face.position.y, avail, face.size.y))


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


## Context words in Atkinson, the key word as letter tiles (its first letter shown from step 2). One line at 26 or
## 24 when it fits, else two lines at 22 (the floor).
func _draw_hint(label: String, key: String, step: int, area: Rect2) -> void:
	var font := Style.sans_bold()
	var tokens := _tokens(label, key, step)
	for fs in [Style.FS_26, 24]:
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


func _is_lidded(g: int) -> bool:
	for j in session.board.jar_count():
		if session.board.lidded[j] == 1 and LevelData.group_of(session.board.jars[j][0]) == g:
			return true
	return false
