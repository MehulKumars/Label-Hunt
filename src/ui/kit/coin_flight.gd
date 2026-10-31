## A handful of brass coins flying from where they were earned to the coin pill, in a short stagger along a gentle
## arc. `landed` fires when the last one arrives (the pill then counts up). Frees itself.
class_name CoinFlight
extends Control

signal landed

const COUNT := 6
const SIZE := 40.0
const DUR := 0.5
const STAGGER := 0.05

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _t: Array[float] = []


## Starts a flight in global coordinates on `parent` (a full-screen Control).
static func launch(parent: Control, from: Vector2, to: Vector2) -> CoinFlight:
	var c := CoinFlight.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.z_index = 70
	c._from = from - parent.global_position
	c._to = to - parent.global_position
	parent.add_child(c)
	c._go()
	return c


func _go() -> void:
	_t.resize(COUNT)
	_t.fill(-1.0)
	var tw := create_tween().set_parallel()
	for i in COUNT:
		tw.tween_method(func(v: float) -> void:
			_t[i] = v
			queue_redraw(), 0.0, 1.0, DUR).set_delay(i * STAGGER).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(func() -> void:
		Sfx.play("coin", 1.15, 0.03, -3.0)
		Haptics.coin()
		landed.emit()
		queue_free())


func _draw() -> void:
	var tex := Art.tex("coin", Vector2(SIZE, SIZE), Materials.coin)
	for i in COUNT:
		var t := _t[i]
		if t < 0.0 or t >= 1.0:
			continue
		# Each coin starts a little apart and takes its own arc, so they read as a handful, not one blob.
		var spread := Vector2(cos(i * 1.7) * 26.0, sin(i * 2.3) * 16.0)
		var a := _from + spread
		var ctrl := (a + _to) / 2.0 + Vector2(-60.0 + i * 20.0, -120.0)
		var p := a.lerp(ctrl, t).lerp(ctrl.lerp(_to, t), t)
		var s := SIZE * lerpf(1.0, 0.7, t)
		draw_texture_rect(tex, Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)), false)
