## Slips left, drawn as small jars that crack. In stars mode it shows the stars you'd get now instead.
class_name SlipMeter
extends Control

var budget := 0
var slips := 0
var stars_mode := false
var _shake := 0.0
## One apricot pulse on the last jar left, so running out never comes as a surprise.
var _warn := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(b: int, s: int, stars: bool) -> void:
	var cracked := s > slips
	budget = b
	slips = s
	stars_mode = stars
	if cracked:
		create_tween().tween_method(func(v: float) -> void:
			_shake = v
			queue_redraw(), 1.0, 0.0, 0.4)
		if b > 0 and s == b - 1 and not stars:
			var tw := create_tween()
			tw.tween_method(_set_warn, 0.0, 1.0, 0.3).set_delay(0.35)
			tw.tween_method(_set_warn, 1.0, 0.0, 0.6)
	queue_redraw()


func _draw() -> void:
	if stars_mode:
		var stars := 3 if slips <= 1 else (2 if slips <= 3 else 1)
		for i in 3:
			var c := Vector2(size.x - 22 - (2 - i) * 40, size.y / 2.0)
			Style.draw_glyph(self, Style.Glyph.STAR, c, 15.0, Style.APRICOT if i < stars else Style.INK_SOFT)
		return
	if budget <= 0:
		return
	var w := 36.0
	var gap := 8.0
	var x := size.x - budget * (w + gap) + gap
	for i in budget:
		var cracked := i >= budget - slips
		var r := Rect2(x + i * (w + gap), size.y / 2.0 - 25, w, 50)
		if cracked and i == budget - slips:
			r.position.x += sin(_shake * 30.0) * 4.0 * _shake
		if not cracked and _warn > 0.0:
			draw_style_box(Style.glow(Color(Style.APRICOT, 0.8 * _warn), 10, int(16 * _warn)), r)
		_draw_mini_jar(r, cracked)


## A small glass jar per slip left; a used one empties, greys and shows a clean crack across its body.
func _draw_mini_jar(r: Rect2, cracked: bool) -> void:
	var body := Rect2(r.position + Vector2(0, 9), r.size - Vector2(0, 9))
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
