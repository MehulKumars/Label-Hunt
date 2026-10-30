## One price tag per group showing how much of its label the player has earned (blank, hint, initial, full).
class_name LabelRail
extends Control

const TAG_H := 52.0
const GAP := 10.0

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
	return rows * TAG_H + (rows - 1) * GAP


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
	var w := (size.x - (cols - 1) * GAP) / cols
	for g in groups:
		var r := Rect2((g % cols) * (w + GAP), (g / cols) * (TAG_H + GAP), w, TAG_H)
		_draw_tag(g, r)


func _draw_tag(g: int, r: Rect2) -> void:
	var step := session.know.step[g]
	var lidded := _is_lidded(g)
	var color := Style.tag_color(g)
	var fill := Style.PAPER.lerp(color, 0.22) if lidded else Style.PAPER
	var p: float = _pulse.get(g, 0.0)
	if p > 0.0:
		draw_style_box(Style.box(Color(Style.APRICOT, 0.6 * p), 14), r.grow(5.0 * p))
	draw_style_box(Style.box(fill, 12, 2, Style.INK), r)
	draw_circle(r.position + Vector2(12, r.size.y / 2.0), 5.0, Style.PAPER_DEEP)
	draw_arc(r.position + Vector2(12, r.size.y / 2.0), 5.0, 0, TAU, 16, Style.INK, 1.5, true)
	var x := r.position.x + 24.0
	if step > 0:
		var c := Vector2(x + 12, r.get_center().y)
		draw_circle(c, 12.0, color)
		Style.draw_glyph(self, g, c, 6.0, Style.PAPER)
		x += 30.0
	var avail := r.end.x - x - 8.0
	var text := LabelText.at_step(session.level.groups[g]["label"], session.level.groups[g]["key"], step)
	if text == "":
		var y := r.get_center().y
		var dx := x + 4.0
		while dx < r.end.x - 14.0:
			draw_line(Vector2(dx, y + 8), Vector2(dx + 8, y + 8), Style.INK_SOFT, 2.0)
			dx += 14.0
		return
	var font := Style.typed()
	var fs := Style.LABEL_FONT
	var lines := JarView._wrap(text, font, fs, avail)
	while (lines.size() > 2 or _widest(lines, font, fs) > avail) and fs > 14:
		fs -= 1
		lines = JarView._wrap(text, font, fs, avail)
	var line_h := fs + 2.0
	var top := r.get_center().y - line_h * lines.size() / 2.0
	for i in lines.size():
		draw_string(font, Vector2(x, top + i * line_h + font.get_ascent(fs)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, avail, fs, Style.INK)


func _is_lidded(g: int) -> bool:
	for j in session.board.jar_count():
		if session.board.lidded[j] == 1 and LevelData.group_of(session.board.jars[j][0]) == g:
			return true
	return false


static func _widest(lines: PackedStringArray, font: Font, fs: int) -> float:
	var w := 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	return w
