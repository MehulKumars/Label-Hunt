## Touch scrolling through buttons: a press that turns into a drag (more than SLOP units) stops being a press and
## scrolls the nearest ScrollContainer instead, so lists of buttons (Shop, Levels map) scroll under the thumb.
class_name Scroller
extends RefCounted

const SLOP := 12.0


static func find(c: Node) -> ScrollContainer:
	var n := c.get_parent()
	while n != null:
		if n is ScrollContainer:
			return n
		n = n.get_parent()
	return null


## Scrolls the list holding `c` by a finger movement.
static func drag(c: Node, relative: Vector2) -> void:
	var s := find(c)
	if s != null:
		s.scroll_vertical -= roundi(relative.y)
