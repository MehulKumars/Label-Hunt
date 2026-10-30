## One word card. Draws itself (paper, word, group tag chip, frost) and is moved around by BoardView.
class_name CardView
extends Control

var card := -1
var word := ""
var tag_group := -1
var frosted := false
var lifted := false
var glow := false
var font_size := 38
var _chip_pop := 0.0
var _glow_t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if glow:
		_glow_t += delta
		queue_redraw()


func set_tag(g: int, pop: bool = false) -> void:
	if g == tag_group:
		return
	tag_group = g
	if pop and g >= 0:
		create_tween().tween_method(_set_pop, 1.0, 0.0, 0.35)
	queue_redraw()


func _set_pop(v: float) -> void:
	_chip_pop = v
	queue_redraw()


func set_lifted(on: bool) -> void:
	if on == lifted:
		return
	lifted = on
	z_index = 5 if on else 1
	var s := 1.06 if on else 1.0
	create_tween().tween_property(self, "scale", Vector2(s, s), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


func set_glow(on: bool) -> void:
	glow = on
	set_process(on)
	queue_redraw()


## A small sideways nudge (used when a buried card is tapped: only the top card moves).
func nudge() -> void:
	var base := position
	var tw := create_tween()
	tw.tween_property(self, "position:x", base.x + 6.0, 0.05)
	tw.tween_property(self, "position:x", base.x - 4.0, 0.06)
	tw.tween_property(self, "position:x", base.x, 0.05)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if lifted:
		draw_style_box(Style.box(Style.SHADOW, 12), Rect2(r.position + Vector2(0, 7), r.size))
	if frosted:
		draw_style_box(Style.box(Style.FROST, 12, 2, Style.GLASS_EDGE), r)
		for i in 4:
			var x := r.size.x * (0.15 + i * 0.22)
			draw_line(Vector2(x, r.size.y * 0.8), Vector2(x + r.size.y * 0.5, r.size.y * 0.2), Color(1, 1, 1, 0.8), 3.0, true)
		return
	draw_style_box(Style.box(Style.CARD, 12, 2, Style.INK), r)
	if glow:
		var a := 0.55 + 0.45 * sin(_glow_t * 6.0)
		draw_style_box(_outline(Color(Style.APRICOT, a), 5), r.grow(4))
	var left := 0.0
	if tag_group >= 0:
		var rad := 12.0 + 6.0 * _chip_pop
		var c := Vector2(20, r.size.y / 2.0)
		draw_circle(c, rad, Style.tag_color(tag_group))
		Style.draw_glyph(self, tag_group, c, rad * 0.5, Style.PAPER)
		left = 30.0
	var font := Style.sans_bold()
	var avail := r.size.x - 20.0 - left
	var fs := font_size
	while fs > 26 and font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
		fs -= 1
	var ts := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var baseline := (r.size.y - ts.y) / 2.0 + font.get_ascent(fs)
	draw_string(font, Vector2(left + 10.0 + (avail - ts.x) / 2.0, baseline), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.INK)


static func _outline(color: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(width)
	sb.border_color = color
	sb.set_corner_radius_all(16)
	sb.anti_aliasing = true
	return sb
