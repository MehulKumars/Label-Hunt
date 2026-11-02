## How spicy a level is: one pepper for a tricky level, two for a hard one, none otherwise. Told before the level
## starts (on its shelf slot and beside the title), so failing a marked level reads as fair and winning one as earned.
## The count carries the meaning, not the colour.
class_name SpiceMark
extends Control

const GAP := 0.15  # of the icon size, between peppers

## Level kind ("tricky", "hard", ...): sets how many peppers show.
var kind := "":
	set(v):
		kind = v
		visible = peppers(v) > 0
		custom_minimum_size = Vector2(width(v, icon_size), icon_size)
		queue_redraw()
var icon_size := 30.0


static func peppers(level_kind: String) -> int:
	return {"tricky": 1, "hard": 2}.get(level_kind, 0)


static func width(level_kind: String, s: float) -> float:
	var n := peppers(level_kind)
	return 0.0 if n == 0 else n * s + (n - 1) * s * GAP


## Draws the peppers centred on `center` into any canvas item (shelf slots draw them this way).
static func draw_at(ci: CanvasItem, center: Vector2, level_kind: String, s: float, color: Color = Style.PAPRIKA) -> void:
	var n := peppers(level_kind)
	if n == 0:
		return
	var tex := Art.icon("pepper", s, color)
	var x := center.x - width(level_kind, s) / 2.0
	for i in n:
		ci.draw_texture_rect(tex, Rect2(Vector2(x + i * s * (1.0 + GAP), center.y - s / 2.0), Vector2(s, s)), false)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _draw() -> void:
	draw_at(self, size / 2.0, kind, icon_size)
