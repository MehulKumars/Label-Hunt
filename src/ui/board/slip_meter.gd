## Slips left, drawn as small jars that crack. In stars mode it shows the stars you'd get now instead.
class_name SlipMeter
extends Control

var budget := 0
var slips := 0
var stars_mode := false
var _shake := 0.0


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
	var w := 30.0
	var gap := 8.0
	var x := size.x - budget * (w + gap) + gap
	for i in budget:
		var cracked := i >= budget - slips
		var r := Rect2(x + i * (w + gap), size.y / 2.0 - 20, w, 40)
		if cracked and i == budget - slips:
			r.position.x += sin(_shake * 30.0) * 4.0 * _shake
		_draw_mini_jar(r, cracked)


func _draw_mini_jar(r: Rect2, cracked: bool) -> void:
	var col := Style.INK_SOFT if cracked else Style.TEAL
	draw_style_box(Style.box(Color(col, 0.15), 8, 3, col), Rect2(r.position + Vector2(0, 8), r.size - Vector2(0, 8)))
	draw_rect(Rect2(r.position + Vector2(5, 0), Vector2(r.size.x - 10, 9)), Style.PAPRIKA if not cracked else Style.INK_SOFT)
	if cracked:
		var a := r.position + Vector2(r.size.x * 0.55, 12)
		draw_polyline(PackedVector2Array([a, a + Vector2(-6, 8), a + Vector2(2, 14), a + Vector2(-4, 24)]), Style.INK, 2.0, true)
