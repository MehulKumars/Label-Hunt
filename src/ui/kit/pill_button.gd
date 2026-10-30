## Text button: primary (paprika enamel) or secondary (paper). Presses answer at once (squash, tap sound); the
## action fires on release inside. Optional leading icon.
class_name PillButton
extends Control

signal pressed

var text := ""
var primary := true
var icon := ""
var font_size := Style.FS_30
var enabled := true:
	set(v):
		enabled = v
		modulate.a = 1.0 if v else 0.45
var _down := false


func _init(label: String = "", is_primary: bool = true, height: float = Style.TOUCH) -> void:
	text = label
	primary = is_primary
	custom_minimum_size = Vector2(240, height)
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	pivot_offset = size / 2.0
	if event.is_canceled():
		_release(false)
	elif event.pressed:
		_down = true
		create_tween().tween_property(self, "scale", Vector2.ONE * 0.96, Style.T_PRESS).set_ease(Tween.EASE_OUT)
		if enabled:
			Sfx.play("tap", 1.0, 0.05, -4.0)
	elif _down:
		_release(Rect2(Vector2.ZERO, size).has_point(event.position))


func _release(inside: bool) -> void:
	_down = false
	create_tween().tween_property(self, "scale", Vector2.ONE, Style.T_RELEASE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if enabled and inside:
		pressed.emit()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var face_h := size.y - 8.0
	var key := "pill_%s" % ("paper" if not primary else Style.PAPRIKA.to_html(false))
	draw_texture_rect(Art.tex(key, size, Materials.pill.bind(Style.PAPRIKA, not primary)), r, false)
	var ink := Style.PAPER if primary else Style.INK
	var f := Style.sans_heavy() if primary else Style.sans_bold()
	var icon_w := 0.0
	var isz := roundf(font_size * 1.05)
	if icon != "":
		icon_w = isz + 12.0
	var fs := font_size
	while fs > Style.FS_22 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 48.0 - icon_w:
		fs -= 2
	var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var x := (size.x - ts.x - icon_w) / 2.0
	if icon != "":
		draw_texture_rect(Art.icon(icon, isz, ink), Rect2(x, (face_h - isz) / 2.0, isz, isz), false)
	draw_string(f, Vector2(x + icon_w, (face_h - f.get_height(fs)) / 2.0 + f.get_ascent(fs)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
