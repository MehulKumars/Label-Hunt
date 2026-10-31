## The Win card's rewards, the moment they land: two chunky chips under "Jar filled": brass coins counting up
## (their coins then fly to the coin pill) and XP with the rank bar filling. An "x2 with an ad" chip is optional.
## A rank-up fills the bar, then names the new rank. Replays pay nothing and show a quiet "Practice run" instead.
class_name RewardRow
extends Control

signal double_pressed
## The coin chip's centre (global), for the coin flight.
signal coins_landed(from: Vector2)

const CHIP_H := 76.0

var coins := 0
var xp := 0
## Rank info before and after the win (Economy.level_for_xp).
var before := {}
var after := {}
var ups: Array = []
var chip: PillButton
var _coin_t := 0.0
var _bar_t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(0, CHIP_H + 56.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip = PillButton.new("x2 with an ad", false, 64.0)
	chip.font_size = Style.FS_26
	chip.custom_minimum_size = Vector2(196, 64)
	chip.visible = false
	chip.pressed.connect(func() -> void: double_pressed.emit())
	add_child(chip)


func offer_double(on: bool) -> void:
	chip.visible = on and coins > 0


## Counts the coins up and fills the bar (the card's reveal sequence calls this after the jar lands).
func play(delay: float) -> void:
	if coins == 0 and xp == 0:
		return
	var tw := create_tween()
	tw.tween_interval(delay)
	if coins > 0:
		tw.tween_callback(func() -> void:
			Sfx.play("coin", 1.0, 0.03)
			Haptics.coin())
		tw.tween_method(func(v: float) -> void:
			_coin_t = v
			queue_redraw(), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void: coins_landed.emit(global_position + _coin_chip().get_center()))
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
	coins_landed.emit(global_position + _coin_chip().get_center())


func _coin_chip() -> Rect2:
	return Rect2(0, 0, (size.x - 14.0) * 0.46, CHIP_H)


func _xp_chip() -> Rect2:
	var c := _coin_chip()
	return Rect2(c.end.x + 14.0, 0, size.x - c.size.x - 14.0, CHIP_H)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		chip.size = chip.custom_minimum_size
		chip.position = Vector2(size.x - chip.size.x, CHIP_H + 4.0)


func _draw() -> void:
	var f := Style.sans_heavy()
	var fb := Style.sans_bold()
	if coins == 0 and xp == 0:
		var t := "Practice run: replays don't pay"
		var ts := fb.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_26)
		draw_string(fb, Vector2((size.x - ts.x) / 2.0, 44), t, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_26, Color(Style.INK, 0.72))
		return
	# Coin chip: brass coin and the count.
	var cc := _coin_chip()
	_chip_bg(cc, Color("#F7E7BE"))
	draw_texture_rect(Art.tex("coin", Vector2(52, 52), Materials.coin), Rect2(cc.position + Vector2(14, (CHIP_H - 52) / 2.0), Vector2(52, 52)), false)
	draw_string(f, Vector2(cc.position.x + 76, CHIP_H / 2.0 + 14), "+%d" % roundi(coins * _coin_t), HORIZONTAL_ALIGNMENT_LEFT,
		cc.size.x - 84, Style.FS_44, Style.INK)
	# XP chip: the XP and the rank bar.
	var xc := _xp_chip()
	_chip_bg(xc, Color("#DCEAE7"))
	var leveled := not ups.is_empty() and _bar_t >= 1.0
	var lv: int = after["level"] if leveled else before["level"]
	draw_string(f, Vector2(xc.position.x + 16, 34), "Rank up!" if leveled else "+%d XP" % xp, HORIZONTAL_ALIGNMENT_LEFT,
		xc.size.x - 24, Style.FS_30, Style.INK)
	var rank := "Rank %d" % lv
	var rs := fb.get_string_size(rank, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_22)
	draw_string(fb, Vector2(xc.end.x - rs.x - 14, 32), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_22, Color(Style.INK, 0.72))
	var bar := Rect2(xc.position.x + 16, 48, xc.size.x - 32, 14)
	draw_style_box(Style.box(Color(Style.INK, 0.12), 7), bar)
	var from := float(before["into"]) / float(before["need"])
	var to := 1.0 if not ups.is_empty() else float(after["into"]) / float(after["need"])
	if leveled:
		from = 0.0
		to = float(after["into"]) / float(after["need"])
	var t := lerpf(from, to, 1.0 if leveled else _bar_t)
	if t > 0.0:
		draw_style_box(Style.box(Style.APRICOT if leveled else Style.TEAL, 7), Rect2(bar.position, Vector2(maxf(bar.size.x * t, 14.0), bar.size.y)))


func _chip_bg(r: Rect2, fill: Color) -> void:
	var sb := Style.box(fill, Style.R_L)
	sb.shadow_color = Color(Style.INK, 0.14)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	draw_style_box(sb, r)


## Call after setting coins and xp: a replay (nothing earned) takes one short line, not the chips' height.
func fit() -> void:
	custom_minimum_size = Vector2(0, 56.0 if coins == 0 and xp == 0 else CHIP_H + 56.0)
