## Text button in our own style: primary (paprika) or secondary (paper with ink edge). Fires on release inside.
class_name PillButton
extends Control

signal pressed

var text := ""
var primary := true
var font_size := 32
var enabled := true:
	set(v):
		enabled = v
		modulate.a = 1.0 if v else 0.45
var _down := false


func _init(label: String = "", is_primary: bool = true, height: float = 96.0) -> void:
	text = label
	primary = is_primary
	custom_minimum_size = Vector2(260, height)
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	pivot_offset = size / 2.0
	if event.pressed:
		_down = true
		create_tween().tween_property(self, "scale", Vector2.ONE * 0.95, 0.05)
		if enabled:
			Sfx.play("tap", 1.0, 0.05, -4.0)
			Haptics.tick(6, 0.25)
	elif _down:
		_down = false
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_BACK)
		if enabled and Rect2(Vector2.ZERO, size).has_point(event.position):
			pressed.emit()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var radius := size.y / 2.0
	draw_style_box(Style.box(Style.SHADOW, radius), Rect2(r.position + Vector2(0, 5), r.size))
	if primary:
		draw_style_box(Style.box(Style.PAPRIKA, radius, 3, Style.INK), r)
	else:
		draw_style_box(Style.box(Style.CARD, radius, 3, Style.INK), r)
	var f := Style.sans_bold()
	var fs := font_size
	while fs > 18 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 40:
		fs -= 1
	var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(f, Vector2((size.x - ts.x) / 2.0, (size.y - ts.y) / 2.0 + f.get_ascent(fs)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.PAPER if primary else Style.INK)
