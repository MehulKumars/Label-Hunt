## The Win card's reward line: coins counting up beside the brass coin (with an optional "x2" chip for an ad), and
## the XP bar filling toward the next player level. A level-up fills the bar, then names the new level and its gift.
class_name RewardRow
extends Control

signal double_pressed

var coins := 0
var xp := 0
## Level info before and after the win (Economy.level_for_xp).
var before := {}
var after := {}
var ups: Array = []
var chip: PillButton
var _coin_t := 0.0
var _bar_t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 118)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip = PillButton.new("x2 with an ad", false, 64.0)
	chip.font_size = Style.FS_22
	chip.custom_minimum_size = Vector2(190, 64)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	chip.visible = false
	chip.pressed.connect(func() -> void: double_pressed.emit())
	add_child(chip)


func offer_double(on: bool) -> void:
	chip.visible = on and coins > 0


## Counts the coins up and fills the bar (the card's reveal sequence calls this after the jar lands).
func play(delay: float) -> void:
	var tw := create_tween()
	tw.tween_interval(delay)
	if coins > 0:
		tw.tween_callback(func() -> void:
			Sfx.play("coin", 1.0, 0.03)
			Haptics.coin())
		tw.tween_method(func(v: float) -> void:
			_coin_t = v
			queue_redraw(), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void:
		_bar_t = v
		queue_redraw(), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not ups.is_empty():
		tw.tween_callback(func() -> void:
			Sfx.play("levelup", 1.0, 0.0)
			Haptics.win())


## After an ad doubled the coins: the count jumps again from the old total.
func doubled() -> void:
	coins *= 2
	chip.visible = false
	_coin_t = 0.5
	create_tween().tween_method(func(v: float) -> void:
		_coin_t = v
		queue_redraw(), 0.5, 1.0, 0.4)
	Sfx.play("coin", 1.1, 0.03)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		chip.size = chip.custom_minimum_size
		chip.position = Vector2(size.x - chip.size.x, 0)


func _draw() -> void:
	var f := Style.sans_heavy()
	var fb := Style.sans_bold()
	if coins > 0:
		draw_texture_rect(Art.tex("coin", Vector2(44, 44), Materials.coin), Rect2(0, 6, 44, 44), false)
		draw_string(f, Vector2(56, 42), "+%d coins" % roundi(coins * _coin_t), HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_36, Style.INK)
	else:
		draw_string(fb, Vector2(0, 40), "Replays don't pay coins", HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_26, Color(Style.INK, 0.6))
	if before.is_empty():
		return
	var y := 74.0
	var leveled := not ups.is_empty() and _bar_t >= 1.0
	var lv: int = after["level"] if leveled else before["level"]
	var tag := "Level %d" % lv
	draw_string(f, Vector2(0, y + 26), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_26, Style.INK)
	var bx := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_26).x + 16.0
	var bar := Rect2(bx, y + 10, size.x - bx - 110.0, 16)
	draw_style_box(Style.box(Color(Style.INK, 0.1), 8), bar)
	var from := float(before["into"]) / float(before["need"])
	var to := 1.0 if not ups.is_empty() else float(after["into"]) / float(after["need"])
	if leveled:
		from = 0.0
		to = float(after["into"]) / float(after["need"])
	var t := lerpf(from, to, 1.0 if leveled else _bar_t)
	if t > 0.0:
		draw_style_box(Style.box(Style.APRICOT if leveled else Style.TEAL, 8), Rect2(bar.position, Vector2(maxf(bar.size.x * t, 16.0), bar.size.y)))
	var right := "Level up!" if leveled else "+%d XP" % xp
	draw_string(fb, Vector2(size.x - 100.0, y + 26), right, HORIZONTAL_ALIGNMENT_LEFT, 100.0, Style.FS_22, Style.INK)
