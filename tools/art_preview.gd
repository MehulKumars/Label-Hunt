## Composites the pantry materials into one PNG for review, headless: a jar with cards between its back and front
## layers, lids (enamel, gold), a plank and labels on the wall colour.
## Run: godot --headless --path . -s res://tools/art_preview.gd [-- --scale=2.5 --out=shots/art/materials.png]
extends SceneTree


func _init() -> void:
	var s := 2.5
	var out := "res://shots/art/materials.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scale="):
			s = float(a.substr(8))
		elif a.begins_with("--out="):
			out = "res://" + a.substr(6)
	var canvas := Image.create_empty(roundi(720 * s), roundi(820 * s), false, Image.FORMAT_RGBA8)
	canvas.fill(Style.PAPER)
	var jar := Vector2(200, 330)
	var card := Vector2(170, 64)
	for i in 2:
		var x := 60.0 + i * 260.0
		_put(canvas, Materials.jar_back(jar), Vector2(x, 60), s)
		for k in 4 - i:
			_put(canvas, Materials.card(card), Vector2(x + 15, 60 + jar.y - 18 - (k + 1) * 68), s)
		_put(canvas, Materials.jar_front(jar), Vector2(x, 60), s)
		_put(canvas, Materials.lid(Vector2(jar.x * 0.82 + 12, 30), Style.GOLD if i == 1 else Style.PAPRIKA), Vector2(x + jar.x * 0.09 - 6, 44), s)
	_put(canvas, Materials.plank(Vector2(640, 40)), Vector2(40, 60 + jar.y - 4), s)
	_put(canvas, Materials.label(Vector2(300, 56), true), Vector2(60, 480), s)
	_put(canvas, Materials.label(Vector2(220, 80)), Vector2(400, 470), s)
	_put(canvas, Materials.card(Vector2(300, 72)), Vector2(60, 600), s)
	_put(canvas, Materials.lid(Vector2(300, 40)), Vector2(400, 610), s)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	canvas.save_png(out)
	print("wrote ", ProjectSettings.globalize_path(out))
	quit()


func _put(canvas: Image, svg: String, at: Vector2, s: float) -> void:
	var img := Image.new()
	if img.load_svg_from_string(svg, s) != OK:
		push_error("bad svg: " + svg.left(200))
		return
	img.convert(Image.FORMAT_RGBA8)
	canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(roundi(at.x * s), roundi(at.y * s)))
