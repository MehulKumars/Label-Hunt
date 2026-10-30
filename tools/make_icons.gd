## Renders the launcher icons from hand-written SVGs into PNGs for the Android export.
## Run: godot --headless --path . -s res://tools/make_icons.gd
extends SceneTree

const PAPER := Color("#FFF8EC")


func _init() -> void:
	var fg := _svg("res://assets/icon/icon_fg.svg", 1.0)
	fg.save_png("res://assets/icon/icon_fg_432.png")
	_svg("res://assets/icon/icon_mono.svg", 1.0).save_png("res://assets/icon/icon_mono_432.png")
	var bg := Image.create_empty(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(PAPER)
	bg.save_png("res://assets/icon/icon_bg_432.png")
	# Legacy 192 icon: foreground over paper, cropped to the central part so the jar fills it.
	var flat := bg.duplicate() as Image
	flat.blend_rect(fg, Rect2i(0, 0, 432, 432), Vector2i.ZERO)
	var legacy := flat.get_region(Rect2i(62, 62, 308, 308))
	legacy.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	legacy.save_png("res://assets/icon/icon_192.png")
	# Play Store hi-res icon.
	var hi := flat.get_region(Rect2i(62, 62, 308, 308))
	hi.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	hi.save_png("res://assets/icon/icon_512.png")
	print("make_icons: done")
	quit()


static func _svg(path: String, scale: float) -> Image:
	var img := Image.new()
	var err := img.load_svg_from_string(FileAccess.get_file_as_string(path), scale)
	assert(err == OK, "can't render %s" % path)
	return img
