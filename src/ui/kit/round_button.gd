## Round icon button on a paper disc, with an optional caption and badge. Icons are Phosphor (MIT) plus our own
## jar-plus. Presses answer at once (squash, tap sound); the action fires on release inside.
class_name RoundButton
extends Control

signal pressed

const D := 88.0
const ICONS := {
	"pause": "pause", "undo": "arrow-counter-clockwise", "peek": "eye", "jar_plus": "jar-plus",
	"tidy": "magic-wand", "gear": "gear-six", "help": "question", "home": "house", "close": "x", "play": "play",
}

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
	custom_minimum_size = Vector2(D, D + (30.0 if text != "" else 0.0))
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
	pivot_offset = Vector2(size.x / 2.0, D / 2.0)
	if event.is_canceled():
		_release(false)
	elif event.pressed:
		_down = true
		create_tween().tween_property(self, "scale", Vector2.ONE * 0.92, Style.T_PRESS).set_ease(Tween.EASE_OUT)
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
	var disc := Rect2((size.x - D) / 2.0, 0, D, D + 6.0)
	var c := Vector2(size.x / 2.0, D / 2.0)
	if _pulse_on:
		draw_circle(c, D / 2.0 + 2.0 + 6.0 * _pulse, Color(Style.APRICOT, 0.3 + 0.3 * _pulse), true, -1.0, true)
	draw_texture_rect(Art.tex("disc", disc.size, Materials.disc), disc, false)
	var isz := D * 0.44
	if ICONS.has(icon):
		draw_texture_rect(Art.icon(ICONS[icon], isz, Style.INK), Rect2(c - Vector2(isz, isz) / 2.0, Vector2(isz, isz)), false)
	if badge != "":
		var bc := c + Vector2(D * 0.34, -D * 0.34)
		draw_circle(bc + Vector2(0, 2), 16.0, Color(Style.INK, 0.2), true, -1.0, true)
		draw_circle(bc, 16.0, Style.PAPRIKA, true, -1.0, true)
		var f := Style.sans_heavy()
		var ts := f.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_22)
		draw_string(f, bc + Vector2(-ts.x / 2.0, -f.get_height(Style.FS_22) / 2.0 + f.get_ascent(Style.FS_22)), badge,
			HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_22, Style.PAPER)
	if caption != "":
		var f := Style.sans_bold()
		var ts := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_22)
		draw_string(f, Vector2((size.x - ts.x) / 2.0, D + 6.0 + f.get_ascent(Style.FS_22)), caption,
			HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_22, Style.INK)
