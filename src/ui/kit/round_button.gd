## Round icon button with an optional caption and badge. Icons are drawn in code. Presses answer immediately
## (squash + tap sound + haptic); the action fires on release inside.
class_name RoundButton
extends Control

signal pressed

const D := 96.0

var icon := ""
var caption := ""
var badge := ""
var enabled := true:
	set(v):
		enabled = v
		modulate.a = 1.0 if v else 0.4
var _down := false
var _pulse := 0.0
var _pulse_on := false
var _t := 0.0


func _init(icon_name: String = "", text: String = "") -> void:
	icon = icon_name
	caption = text
	custom_minimum_size = Vector2(D, D + (26.0 if text != "" else 0.0))
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_pulse(on: bool) -> void:
	_pulse_on = on
	set_process(on)
	if not on:
		_pulse = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_pulse = 0.5 + 0.5 * sin(_t * 5.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if event.pressed:
		_down = true
		pivot_offset = Vector2(size.x / 2.0, D / 2.0)
		create_tween().tween_property(self, "scale", Vector2.ONE * 0.92, 0.05)
		if enabled:
			Sfx.play("tap", 1.0, 0.05, -4.0)
			Haptics.tick(6, 0.25)
	elif _down:
		_down = false
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_BACK)
		if enabled and Rect2(Vector2.ZERO, size).has_point(event.position):
			pressed.emit()


func _draw() -> void:
	var c := Vector2(size.x / 2.0, D / 2.0)
	var rad := D / 2.0 - 4.0
	if _pulse_on:
		draw_circle(c, rad + 4.0 + 6.0 * _pulse, Color(Style.APRICOT, 0.35 + 0.3 * _pulse))
	draw_circle(c + Vector2(0, 4), rad, Style.SHADOW)
	draw_circle(c, rad, Style.CARD)
	draw_arc(c, rad, 0, TAU, 48, Style.INK, 3.0, true)
	_draw_icon(c)
	if badge != "":
		var bc := c + Vector2(rad * 0.72, -rad * 0.72)
		draw_circle(bc, 17.0, Style.PAPRIKA)
		var f := Style.sans_bold()
		var ts := f.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		draw_string(f, bc + Vector2(-ts.x / 2.0, f.get_ascent(22) / 2.0 - 3), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Style.PAPER)
	if caption != "":
		var f := Style.sans_bold()
		var ts := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		draw_string(f, Vector2((size.x - ts.x) / 2.0, D + 20), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Style.INK)


func _draw_icon(c: Vector2) -> void:
	var ink := Style.INK
	match icon:
		"pause":
			draw_style_box(Style.box(ink, 3), Rect2(c + Vector2(-11, -14), Vector2(8, 28)))
			draw_style_box(Style.box(ink, 3), Rect2(c + Vector2(3, -14), Vector2(8, 28)))
		"undo":
			draw_arc(c + Vector2(2, 3), 14.0, deg_to_rad(-200), deg_to_rad(60), 24, ink, 5.0, true)
			var tip := c + Vector2(2, 3) + Vector2.from_angle(deg_to_rad(-200)) * 14.0
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-9, -2), tip + Vector2(7, -6), tip + Vector2(1, 10)]), ink)
		"peek":
			var eye := PackedVector2Array()
			for i in 24:
				var a := i * TAU / 24.0
				eye.append(c + Vector2(cos(a) * 22.0, sin(a) * 12.0 * (1.0 if sin(a) > 0 else 1.0)))
			draw_polyline(eye + PackedVector2Array([eye[0]]), ink, 4.0, true)
			draw_circle(c, 7.0, ink)
		"jar_plus":
			draw_style_box(_outline(ink, 4, 8), Rect2(c + Vector2(-14, -10), Vector2(24, 28)))
			draw_line(c + Vector2(-9, -15), c + Vector2(5, -15), ink, 4.0, true)
			draw_line(c + Vector2(17, -14), c + Vector2(17, -2), Style.PAPRIKA, 4.0, true)
			draw_line(c + Vector2(11, -8), c + Vector2(23, -8), Style.PAPRIKA, 4.0, true)
		"tidy":
			Style.draw_glyph(self, Style.Glyph.STAR, c + Vector2(-5, 3), 13.0, ink)
			Style.draw_glyph(self, Style.Glyph.STAR, c + Vector2(13, -12), 7.0, Style.APRICOT)
		"gear":
			draw_circle(c, 15.0, ink)
			for i in 8:
				draw_line(c, c + Vector2.from_angle(i * TAU / 8.0) * 21.0, ink, 7.0)
			draw_circle(c, 6.0, Style.CARD)


static func _outline(color: Color, width: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(width)
	sb.border_color = color
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb
