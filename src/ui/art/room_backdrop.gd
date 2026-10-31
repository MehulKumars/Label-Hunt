## The wall behind every screen, in the current room's look (Themes): its colours lit from the top left like the
## materials, and its pattern as a small tile repeated across the screen (cheap at any phone size). Changing room
## crossfades.
class_name RoomBackdrop
extends Control

var room := 0
var _gradients := {}
var _fade := 1.0
var _from := 0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func set_room(r: int) -> void:
	if r == room:
		return
	_from = room
	room = r
	if _from == 0:
		queue_redraw()
		return
	_fade = 0.0
	create_tween().tween_method(func(v: float) -> void:
		_fade = v
		queue_redraw(), 0.0, 1.0, 0.35)


func _draw() -> void:
	if room == 0:
		return
	var r := Rect2(Vector2.ZERO, size)
	if _fade < 1.0 and _from > 0:
		_paint(_from, r, 1.0)
	_paint(room, r, _fade)


func _paint(rm: int, r: Rect2, alpha: float) -> void:
	draw_texture_rect(_gradient(rm), r, false, Color(1, 1, 1, alpha))
	var tile := Vector2(RoomArt.TILE, RoomArt.TILE)
	var tex := Art.tex("wall_tile|%d" % rm, tile, RoomArt.pattern_tile.bind(rm))
	if tex == null:
		return
	# The tile is rasterised at device scale; draw it at its canvas size so the pattern keeps its proportions.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (tile.x / tex.get_width()))
	draw_texture_rect(tex, Rect2(Vector2.ZERO, r.size * (tex.get_width() / tile.x)), true, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _gradient(rm: int) -> GradientTexture2D:
	if _gradients.has(rm):
		return _gradients[rm]
	var g := Gradient.new()
	var light := Themes.color(rm, "wall", 0)
	var shade := Themes.color(rm, "wall", 1)
	g.set_color(0, light.lightened(0.25))
	g.add_point(0.55, light)
	g.set_color(g.get_point_count() - 1, shade)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.18, 0.08)
	tex.fill_to = Vector2(1.15, 1.05)
	tex.width = 128
	tex.height = 256
	_gradients[rm] = tex
	return tex
