## A short teaching caption on a kraft slip, just under the rail: fades in, then away. Never a wall of text.
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
	var fs := Style.FS_26
	var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var slip := Vector2(ts.x + 48.0, 52.0)
	draw_set_transform(size / 2.0, deg_to_rad(-1.0), Vector2.ONE)
	draw_texture_rect(Art.tex("caption|%d" % roundi(slip.x), slip, Materials.label.bind(false)), Rect2(-slip / 2.0, slip), false)
	draw_string(f, Vector2(-ts.x / 2.0, -f.get_height(fs) / 2.0 + f.get_ascent(fs) - 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
