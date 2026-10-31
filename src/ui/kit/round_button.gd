## Round icon button on a paper disc, with an optional caption and badge. Icons are Phosphor (MIT) plus our own
## jar-plus. Presses answer at once (squash, tap sound); the action fires on release inside.
class_name RoundButton
extends Control

signal pressed

const D := 88.0
const ICONS := {
	"pause": "pause", "undo": "arrow-counter-clockwise", "hint": "lightbulb", "jar_plus": "jar-plus",
	"complete": "jar-seal", "tidy": "magic-wand", "gear": "gear-six", "help": "question", "home": "house",
	"close": "x", "play": "play", "shop": "storefront", "levels": "map-trifold", "profile": "user", "gift": "gift",
	"streak": "fire", "back": "arrow-left",
}

var icon := ""
var caption := ""
var badge := ""
## The badge is a price in coins (drawn with a coin), not a count.
var badge_coin := false
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
	# How many are left: a small kraft count tag on the disc's shoulder (not a red notification dot).
	if badge != "":
		var f := Style.sans_heavy()
		var ts := f.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_22)
		var coin_w := 22.0 if badge_coin else 0.0
		var tag := Vector2(maxf(ts.x + 16.0 + coin_w, 32.0), 30.0)
		var at := c + Vector2(D * 0.3, -D * 0.36) - tag / 2.0
		draw_style_box(Style.box(Color(Style.INK, 0.18), Style.R_S), Rect2(at + Vector2(0, 2), tag))
		draw_style_box(Style.box(Color("#E7D1A8"), Style.R_S), Rect2(at, tag))
		if badge_coin:
			draw_texture_rect(Art.tex("coin", Vector2(20, 20), Materials.coin), Rect2(at + Vector2(6, 5), Vector2(20, 20)), false)
		draw_string(f, at + Vector2(coin_w + (tag.x - coin_w - ts.x) / 2.0, (tag.y - f.get_height(Style.FS_22)) / 2.0 + f.get_ascent(Style.FS_22)), badge,
			HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_22, Style.INK)
	if caption != "":
		var f := Style.sans_bold()
		var ts := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_22)
		draw_string(f, Vector2((size.x - ts.x) / 2.0, D + 6.0 + f.get_ascent(Style.FS_22)), caption,
			HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_22, Style.INK)
