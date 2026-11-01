## The coin balance: a paper pill with the brass coin, the number and a small plus (tap opens the Shop). Gains count
## up and give the coin a bump, so a reward is seen landing; spends just settle.
class_name CoinPill
extends Control

signal pressed

const H := 64.0
const MIN_W := 150.0
const PLUS_W := 30.0

var shown := 0.0
## While coins are flying in, the pill keeps the old number (so the count-up happens when they land).
var hold := false
var _bump := 0.0
var _down := false
var _tw: Tween


func _init() -> void:
	custom_minimum_size = Vector2(150, H)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Shows `value`, counting up from the last shown value when it grew.
func set_value(value: int, animate: bool = true) -> void:
	if hold:
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if not animate or value <= int(shown) or not is_inside_tree():
		shown = value
		_fit()
		queue_redraw()
		return
	_tw = create_tween().set_parallel()
	_tw.tween_method(_set_shown, shown, float(value), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_method(func(v: float) -> void:
		_bump = v
		queue_redraw(), 1.0, 0.0, 0.35)


func _set_shown(v: float) -> void:
	shown = v
	_fit()
	queue_redraw()


## Wide enough for the number at full size, so it is never cut off. Screens place the pill by its right edge.
func wanted_width() -> float:
	var text_w := Style.sans_heavy().get_string_size(text_for(roundi(shown)), HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_30).x
	return maxf(MIN_W, ceilf(H - 4.0 + text_w + PLUS_W + 14.0))


## Keeps the right edge where it is while the number changes width.
func _fit() -> void:
	var w := wanted_width()
	if w != size.x:
		position.x += size.x - w
		size.x = w


## Where coins should fly to (global position of the coin's centre).
func coin_center() -> Vector2:
	return global_position + Vector2(H / 2.0, (H - 6.0) / 2.0)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if event.is_canceled():
		_down = false
	elif event.pressed:
		_down = true
		Sfx.play("tap", 1.0, 0.05, -4.0)
		pivot_offset = size / 2.0
		create_tween().tween_property(self, "scale", Vector2.ONE * 0.95, Style.T_PRESS)
	elif _down:
		_down = false
		create_tween().tween_property(self, "scale", Vector2.ONE, Style.T_RELEASE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if Rect2(Vector2.ZERO, size).has_point(event.position):
			pressed.emit()


func _draw() -> void:
	var face := Rect2(Vector2.ZERO, Vector2(size.x, H))
	draw_texture_rect(Art.tex("pill_paper", face.size, Materials.pill.bind(Style.PAPER, true)), face, false)
	var cs := 40.0 * (1.0 + 0.18 * _bump)
	var cc := Vector2(H / 2.0 - 2.0, (H - 8.0) / 2.0)
	draw_texture_rect(Art.tex("coin", Vector2(40, 40), Materials.coin), Rect2(cc - Vector2(cs, cs) / 2.0, Vector2(cs, cs)), false)
	var f := Style.sans_heavy()
	var txt := text_for(roundi(shown))
	var fs := Style.FS_30
	var base := (H - 8.0) / 2.0 + f.get_ascent(fs) / 2.0 - 2.0
	draw_string(f, Vector2(H - 4.0, base), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.INK)
	var pc := Vector2(size.x - PLUS_W / 2.0 - 8.0, (H - 8.0) / 2.0)
	draw_circle(pc, 13.0, Color(Style.TEAL, 0.9), true, -1.0, true)
	draw_line(pc - Vector2(6, 0), pc + Vector2(6, 0), Style.PAPER, 3.0, true)
	draw_line(pc - Vector2(0, 6), pc + Vector2(0, 6), Style.PAPER, 3.0, true)


## The balance as the pill shows it: the full number up to 99,999, then 125K, then 1.2M.
static func text_for(n: int) -> String:
	if n < 100000:
		return _fmt(n)
	if n < 1000000:
		return "%dK" % (n / 1000)
	return "%.1fM" % (floorf(n / 100000.0) / 10.0)


## 1240 -> "1,240"
static func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
