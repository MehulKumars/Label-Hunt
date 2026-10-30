## One word card. Draws itself (paper, word, group tag chip, frost) and is moved around by BoardView.
class_name CardView
extends Control

var card := -1
var word := ""
var tag_group := -1
var frosted := false
var lifted := false
var glow := false
## Under another card: drawn a touch darker and flatter, so the movable top card stands out.
var buried := false
var font_size := 38
var _chip_pop := 0.0
var _glow_t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_buried(on: bool) -> void:
	if on != buried:
		buried = on
		queue_redraw()


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


## Paper tile from Materials.card; the face is the top (height - 5) units, the paper's edge shows below it.
func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var face := Rect2(0, 0, size.x, size.y - 5.0)
	if lifted:
		draw_style_box(Style.glow(Color(Style.INK, 0.28), Style.R_M, 14), Rect2(face.position + Vector2(0, 10), face.size).grow(-6))
	elif not buried:
		draw_style_box(Style.glow(Color(Style.INK, 0.2), Style.R_M, 6), Rect2(face.position + Vector2(0, 4), face.size).grow(-3))
	if glow:
		var a := 0.45 + 0.35 * sin(_glow_t * 5.0)
		draw_style_box(Style.glow(Color(Style.APRICOT, a), Style.R_M, 16), face)
	draw_texture_rect(Art.tex("card", size, Materials.card), r, false)
	if frosted:
		draw_style_box(Style.box(Color(Style.FROST, 0.94), Style.R_M), face)
		for i in 4:
			var x := face.size.x * (0.14 + i * 0.22)
			draw_line(Vector2(x, face.size.y * 0.78), Vector2(x + face.size.y * 0.45, face.size.y * 0.22), Color(1, 1, 1, 0.85), 3.0, true)
		return
	var font := Style.sans_bold()
	var avail := face.size.x - 28.0
	var fs := font_size
	# The board picks one size for every card; only a word that still can't fit shrinks on its own.
	while fs > 26 and font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
		fs -= 2
	var ts := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var baseline := (face.size.y - font.get_height(fs)) / 2.0 + font.get_ascent(fs)
	draw_string(font, Vector2((face.size.x - ts.x) / 2.0, baseline), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.INK)
	if buried:
		draw_style_box(Style.box(Color(Style.INK, 0.05), Style.R_M), face)
	# The group tag is a round sticker on the card's top-left corner, so the word stays centred.
	if tag_group >= 0:
		var rad := 12.0 + 5.0 * _chip_pop
		var c := Vector2(9, 9)
		draw_circle(c + Vector2(0, 1.5), rad + 2.0, Color(Style.INK, 0.18), true, -1.0, true)
		draw_circle(c, rad + 2.0, Style.CARD, true, -1.0, true)
		draw_circle(c, rad, Style.tag_color(tag_group), true, -1.0, true)
		Style.draw_glyph(self, tag_group, c, rad * 0.48, Style.PAPER)
