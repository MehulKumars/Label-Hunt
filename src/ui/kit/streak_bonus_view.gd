## The road past the week of gifts: the next streak lengths that pay a bonus, the nearest one lit, each with what it
## gives. It moves on as the streak grows, so there is always a next one to see, and everything is shown in advance.
class_name StreakBonusView
extends Control

const SHOWN := 6
const Y := 46.0

var streak := 0


func _init(days: int = 0) -> void:
	streak = days
	custom_minimum_size = Vector2(0, 146)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var days := Economy.next_streak_bonuses(streak, SHOWN)
	var cell := size.x / SHOWN
	var fb := Style.sans_bold()
	draw_line(Vector2(cell / 2.0, Y), Vector2(size.x - cell / 2.0, Y), Color(Style.INK, 0.12), 6.0, true)
	for i in SHOWN:
		var reward := Economy.streak_bonus(days[i])
		var c := Vector2((i + 0.5) * cell, Y)
		var r := minf(cell * 0.4, 36.0)
		var next := i == 0
		if next:
			draw_circle(c, r + 8.0, Color(Style.APRICOT, 0.45), true, -1.0, true)
		draw_circle(c + Vector2(0, 2), r, Color(Style.INK, 0.15), true, -1.0, true)
		draw_circle(c, r, Style.APRICOT if next else Style.CARD, true, -1.0, true)
		var icon := "coins"
		if reward.has("avatar"):
			icon = str(reward["avatar"])
		elif reward.has("complete"):
			icon = "jar-seal"
		draw_texture_rect(Art.icon(icon, r, Style.INK if next else Color(Style.INK, 0.45)),
			Rect2(c - Vector2(r, r) / 2.0, Vector2(r, r)), false)
		var coins := CoinPill._fmt(int(reward.get("coins", 0)))
		var ts := fb.get_string_size(coins, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_26)
		draw_string(fb, Vector2(c.x - ts.x / 2.0, 110), coins, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_26, Style.INK)
		var label := "%d days" % days[i]
		var ds := fb.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_22)
		draw_string(fb, Vector2(c.x - ds.x / 2.0, 136), label, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_22, Color(Style.INK, 0.72))
