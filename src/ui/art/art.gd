## Material art cache. Materials are SVG text built per size (Materials), rasterised by ThorVG at the device's real
## pixel scale so glass, paper and wood stay crisp on every phone, then drawn into canvas-unit rects.
## Keyed by material, size and variant; one raster serves every jar or card of the same size.
class_name Art
extends RefCounted

static var _cache := {}
## Rasterisation scale override (tools set it; the game reads the window).
static var forced_scale := 0.0


## Device pixels per canvas unit, so a 100 u texture is rasterised at its true on-screen size.
static func px_scale() -> float:
	if forced_scale > 0.0:
		return forced_scale
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return 2.0
	var visible := tree.root.get_visible_rect().size
	if visible.y <= 0.0:
		return 2.0
	return clampf(float(DisplayServer.window_get_size().y) / visible.y, 0.5, 4.0)


## A texture for a material at a size in canvas units. `svg` builds the SVG for that size (viewBox in units).
static func tex(key: String, size: Vector2, svg: Callable) -> Texture2D:
	var s := px_scale()
	var id := "%s|%d|%d|%.2f" % [key, roundi(size.x), roundi(size.y), s]
	if _cache.has(id):
		return _cache[id]
	var img := Image.new()
	var err := img.load_svg_from_string(svg.call(size), s)
	if err != OK:
		push_error("art: can't rasterise %s" % key)
		return null
	var t := ImageTexture.create_from_image(img)
	_cache[id] = t
	return t


static func clear() -> void:
	_cache.clear()


## A Phosphor icon (MIT, assets/icons) tinted to `color`, rasterised at its on-screen size in canvas units.
static func icon(name: String, size_u: float, color: Color) -> Texture2D:
	var s := px_scale()
	var id := "icon|%s|%d|%s|%.2f" % [name, roundi(size_u), color.to_html(), s]
	if _cache.has(id):
		return _cache[id]
	var svg := FileAccess.get_file_as_string("res://assets/icons/%s.svg" % name)
	if svg == "":
		push_error("art: no icon %s" % name)
		return null
	svg = svg.replace("currentColor", "#" + color.to_html(false))
	if color.a < 1.0:
		svg = svg.replace("<svg ", '<svg fill-opacity="%s" ' % snappedf(color.a, 0.01))
	var img := Image.new()
	if img.load_svg_from_string(svg, size_u * s / 256.0) != OK:
		return null
	var t := ImageTexture.create_from_image(img)
	_cache[id] = t
	return t
