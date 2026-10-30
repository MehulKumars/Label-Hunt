## Tutorial hand: taps one spot, glides to a second and taps again, looping until hidden.
class_name HandPointer
extends Control

var _tween: Tween
var _ripple := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(90, 110)
	z_index = 20
	visible = false


func show_path(a: Vector2, b: Vector2) -> void:
	visible = true
	if _tween:
		_tween.kill()
	position = a
	_tween = create_tween().set_loops()
	_tween.tween_property(self, "modulate:a", 1.0, 0.2).from(0.0)
	_tween.tween_method(_set_ripple, 0.0, 1.0, 0.35)
	_tween.tween_interval(0.15)
	_tween.tween_property(self, "position", b, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_set_ripple, 0.0, 1.0, 0.35)
	_tween.tween_interval(0.35)
	_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_tween.tween_callback(func() -> void: position = a)


func stop() -> void:
	if _tween:
		_tween.kill()
	visible = false


func _set_ripple(v: float) -> void:
	_ripple = v
	queue_redraw()


func _draw() -> void:
	# The fingertip sits at (0, 0).
	if _ripple > 0.0 and _ripple < 1.0:
		draw_arc(Vector2.ZERO, 14.0 + 26.0 * _ripple, 0, TAU, 32, Color(Style.APRICOT, 1.0 - _ripple), 5.0, true)
	var skin := Color("#F6D2B5")
	var finger := Rect2(Vector2(-11, -2), Vector2(22, 50))
	draw_style_box(Style.box(skin, 11, 3, Style.INK), finger)
	var palm := Rect2(Vector2(-22, 34), Vector2(54, 56))
	draw_style_box(Style.box(skin, 20, 3, Style.INK), palm)
	draw_style_box(Style.box(skin, 9, 0), Rect2(Vector2(-8, 30), Vector2(16, 16)))
	draw_line(Vector2(-22, 62), Vector2(-30, 50), Style.INK, 3.0, true)
