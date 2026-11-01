## A player avatar: a Phosphor food icon on an enamel lid disc in the avatar's colour (Economy.AVATARS).
## Optional ring around it (the player's XP progress) and a lock for avatars not yet earned.
class_name AvatarView
extends Control

var avatar_id := "lemon":
	set(v):
		avatar_id = v
		queue_redraw()
## 0..1 progress ring around the disc; < 0 hides it.
var ring := -1.0:
	set(v):
		ring = v
		queue_redraw()
var locked := false:
	set(v):
		locked = v
		queue_redraw()
var selected := false:
	set(v):
		selected = v
		queue_redraw()


func _init(id: String = "lemon") -> void:
	avatar_id = id
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_avatar(self, Rect2(Vector2.ZERO, size), avatar_id, ring, locked, selected)


static func draw_avatar(ci: CanvasItem, r: Rect2, id: String, ring_t: float = -1.0, is_locked: bool = false,
		is_selected: bool = false) -> void:
	var a := Economy.avatar(id)
	var base := Color(str(a[2]))
	var c := r.get_center()
	var rad := minf(r.size.x, r.size.y) / 2.0 - (6.0 if ring_t >= 0.0 or is_selected else 1.0)
	if is_selected:
		ci.draw_circle(c, rad + 5.0, Style.APRICOT, true, -1.0, true)
	if ring_t >= 0.0:
		ci.draw_arc(c, rad + 3.5, 0.0, TAU, 48, Color(Style.INK, 0.12), 4.0, true)
		if ring_t > 0.0:
			ci.draw_arc(c, rad + 3.5, -PI / 2.0, -PI / 2.0 + TAU * clampf(ring_t, 0.0, 1.0), 48, Style.TEAL, 4.0, true)
	ci.draw_circle(c + Vector2(0, 2.5), rad, Color(Style.INK, 0.2), true, -1.0, true)
	ci.draw_circle(c, rad, base.darkened(0.25), true, -1.0, true)
	ci.draw_circle(c, rad * 0.88, base if not is_locked else Style.INK_FAINT, true, -1.0, true)
	ci.draw_arc(c, rad * 0.7, deg_to_rad(200), deg_to_rad(250), 12, Color(1, 1, 1, 0.45), maxf(rad * 0.08, 1.5), true)
	var isz := rad * 1.05
	var ink := Style.PAPER if base.get_luminance() < 0.62 else Style.INK
	var icon: String = "lock-simple" if is_locked else str(a[1])
	ci.draw_texture_rect(Art.icon(icon, isz, ink if not is_locked else Style.INK_SOFT),
		Rect2(c - Vector2(isz, isz) / 2.0, Vector2(isz, isz)), false)
