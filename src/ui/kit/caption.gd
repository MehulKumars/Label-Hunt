## A short teaching caption that fades in near the board, then away. Never a wall of text.
class_name Caption
extends Control

var text := ""
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0


func say(t: String, seconds: float = 2.6) -> void:
	text = t
	queue_redraw()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	_tween.tween_interval(seconds)
	_tween.tween_property(self, "modulate:a", 0.0, 0.3)


func _draw() -> void:
	if text == "":
		return
	var f := Style.sans_bold()
	var fs := 28
	var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var r := Rect2((size.x - ts.x) / 2.0 - 26, (size.y - 56) / 2.0, ts.x + 52, 56)
	draw_style_box(Style.box(Style.INK, 28), r)
	draw_string(f, Vector2(r.position.x + 26, r.get_center().y - ts.y / 2.0 + f.get_ascent(fs)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.PAPER)
