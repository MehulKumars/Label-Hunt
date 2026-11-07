## Slips left, drawn as small jars that crack, and beside them the stars this attempt would earn right now. A slip
## past a star limit dims that star (quietly: a slip is not a success, so no juice). Levels without a budget show the
## stars alone.
class_name SlipMeter
extends Control

const STAR := 26.0
const STAR_GAP := 3.0

var budget := 0
var slips := 0
## Economy.star_limits for this level: 3 stars up to x slips, 2 up to y.
var limits := Vector2i(99, 99)
var _shake := 0.0
## One apricot pulse on the last jar left, so running out never comes as a surprise.
var _warn := 0.0
## 1 while a star that was just lost fades out.
var _fade := 0.0
var _faded_star := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func stars() -> int:
	return Economy.stars_for(slips, limits)


func set_state(b: int, s: int, lim: Vector2i) -> void:
	var cracked := s > slips
	var had := stars()
	budget = b
	slips = s
	limits = lim
	if cracked:
		create_tween().tween_method(func(v: float) -> void:
			_shake = v
			queue_redraw(), 1.0, 0.0, 0.4)
		if b > 0 and s == b - 1:
			var tw := create_tween()
			tw.tween_method(_set_warn, 0.0, 1.0, 0.3).set_delay(0.35)
			tw.tween_method(_set_warn, 1.0, 0.0, 0.6)
		if stars() < had and not bool(Save.setting("reduce_motion")):
			_faded_star = stars()
			create_tween().tween_method(func(v: float) -> void:
				_fade = v
				queue_redraw(), 1.0, 0.0, 0.35)
	queue_redraw()


func _draw() -> void:
	var gap := 6.0
	var stars_w := STAR * 3.0 + STAR_GAP * 2.0
	var w := 0.0
	var h := 0.0
	var jars_w := 0.0
	if budget > 0:
		# The jars shrink to fit long budgets and short rows (36 x 50 at most), leaving room for the stars.
		var room := size.x - stars_w - 18.0
		w = minf(36.0, minf((room + gap) / budget - gap, size.y * 0.72))
		h = w * 50.0 / 36.0
		jars_w = budget * (w + gap) - gap
	var total := jars_w + (18.0 if budget > 0 else 0.0) + stars_w
	var x := (size.x - total) / 2.0
	for i in budget:
		var cracked := i >= budget - slips
		var r := Rect2(x + i * (w + gap), (size.y - h) / 2.0, w, h)
		if cracked and i == budget - slips:
			r.position.x += sin(_shake * 30.0) * 4.0 * _shake
		if not cracked and _warn > 0.0:
			draw_style_box(Style.glow(Color(Style.APRICOT, 0.8 * _warn), 10, int(16 * _warn)), r)
		_draw_mini_jar(r, cracked)
	var sx := x + jars_w + (18.0 if budget > 0 else 0.0)
	var n := stars()
	var off := Art.tex("star_off_%d" % int(STAR), Vector2(STAR, STAR), Materials.star.bind(false))
	var on := Art.tex("star_on_%d" % int(STAR), Vector2(STAR, STAR), Materials.star.bind(true))
	for i in 3:
		var r := Rect2(sx + i * (STAR + STAR_GAP), (size.y - STAR) / 2.0, STAR, STAR)
		draw_texture_rect(off, r, false)
		if i < n:
			draw_texture_rect(on, r, false)
		elif i == _faded_star and _fade > 0.0:
			var k := 0.7 + 0.3 * _fade
			draw_texture_rect(on, Rect2(r.get_center() - r.size * k / 2.0, r.size * k), false, Color(1, 1, 1, _fade))


## A small glass jar per slip left; a used one empties, greys and shows a clean crack across its body.
func _draw_mini_jar(r: Rect2, cracked: bool) -> void:
	var k := r.size.x / 36.0
	var body := Rect2(r.position + Vector2(0, 9 * k), r.size - Vector2(0, 9 * k))
	var glass := Color(Style.TEAL, 0.2 if not cracked else 0.08)
	draw_style_box(Style.box(glass, 9, 2, Color(Style.TEAL if not cracked else Style.INK, 0.6 if not cracked else 0.35)), body)
	if not cracked:
		draw_style_box(Style.box(Color(Style.TEAL, 0.35), 6), Rect2(body.position + Vector2(4, body.size.y * 0.45), Vector2(body.size.x - 8, body.size.y * 0.5)))
		draw_line(body.position + Vector2(6, 7), body.position + Vector2(6, body.size.y * 0.5), Color(1, 1, 1, 0.7), 2.5, true)
	draw_style_box(Style.box(Style.PAPRIKA if not cracked else Color(Style.INK, 0.3), 3), Rect2(r.position + Vector2(4, 0), Vector2(r.size.x - 8, 10)))
	if cracked:
		var a := body.position + Vector2(body.size.x * 0.2, body.size.y * 0.3)
		draw_polyline(PackedVector2Array([a, a + Vector2(9, 7), a + Vector2(6, 13), a + Vector2(17, 21)]), Style.INK, 2.2, true)


func _set_warn(v: float) -> void:
	_warn = v
	queue_redraw()
