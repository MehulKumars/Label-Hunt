## The week of daily gifts: seven gift discs, days already claimed ticked, today's glowing, later ones faint, each
## with its coins underneath (day 7 also carries a Complete). The whole week is shown in advance: no surprises.
class_name GiftLadderView
extends Control

## Today's rung (0-based) and whether today's gift is still waiting.
var today := 0
var waiting := false


func _init() -> void:
	custom_minimum_size = Vector2(0, 146)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var n := Economy.GIFT_LADDER.size()
	var cell := size.x / n
	var fb := Style.sans_bold()
	for i in n:
		var c := Vector2((i + 0.5) * cell, 46)
		var r := minf(cell * 0.4, 36.0) * (1.15 if i == n - 1 else 1.0)
		var past := i < today or (i == today and not waiting)
		var now := i == today and waiting
		if now:
			draw_circle(c, r + 8.0, Color(Style.APRICOT, 0.45), true, -1.0, true)
		draw_circle(c + Vector2(0, 2), r, Color(Style.INK, 0.15), true, -1.0, true)
		draw_circle(c, r, Style.APRICOT if now else (Style.CARD if not past else Color(Style.TEAL, 0.85)), true, -1.0, true)
		var icon := "check" if past else ("jar-seal" if i == n - 1 else "gift")
		var isz := r * 1.0
		var ink := Style.PAPER if past else Style.INK
		draw_texture_rect(Art.icon(icon, isz, ink if not (not past and not now and i > today) else Color(Style.INK, 0.45)),
			Rect2(c - Vector2(isz, isz) / 2.0, Vector2(isz, isz)), false)
		var g: Dictionary = Economy.GIFT_LADDER[i]
		var txt := str(g.get("coins", 0))
		var ts := fb.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_26)
		draw_string(fb, Vector2(c.x - ts.x / 2.0, 110), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_26, Style.INK)
		var day := "Day %d" % (i + 1)
		var ds := fb.get_string_size(day, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_22)
		draw_string(fb, Vector2(c.x - ds.x / 2.0, 136), day, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.FS_22, Color(Style.INK, 0.72))
