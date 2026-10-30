## Type lab: renders the candidate hand-lettered faces as real jar labels (kraft, 26-34 u) and as the wordmark,
## next to Atkinson, and saves one PNG. Needs a window (headless renders nothing).
## Run: godot --path . -s res://tools/type_lab.gd -- --fonts=<dir with ttf files> [--out=shots/art/type_lab.png]
extends SceneTree

const LABELS := ["Things with keys", "Big cats", "Kitchen tools", "Words before ball"]


func _init() -> void:
	var dir := ""
	var out := "res://shots/art/type_lab.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fonts="):
			dir = a.substr(8)
		elif a.begins_with("--out="):
			out = "res://" + a.substr(6)
	DisplayServer.window_set_size(Vector2i(1080, 1600))
	var fonts: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".ttf"):
			var ff := FontFile.new()
			ff.load_dynamic_font(dir.path_join(f))
			fonts.append([f.get_slice("_", 1).get_basename(), ff])
	var lab := _Lab.new()
	lab.fonts = fonts
	lab.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(lab)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	root.get_texture().get_image().save_png(out)
	print("wrote ", ProjectSettings.globalize_path(out))
	quit()


class _Lab extends Control:
	var fonts: Array = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Style.PAPER)
		var y := 20.0
		var s := size.x / 720.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
		for pair: Array in fonts:
			var name: String = pair[0]
			var font: Font = pair[1]
			draw_string(Style.sans(), Vector2(20, y + 22), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Style.INK_SOFT)
			draw_string(font, Vector2(20, y + 92), "Jarful", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Style.INK)
			var x := 250.0
			for i in 2:
				var text: String = LABELS[i * 2 if name.length() % 2 == 0 else i]
				var tex := Art.tex("label", Vector2(220, 58), Materials.label.bind(false))
				draw_texture_rect(tex, Rect2(x, y + 30, 220, 58), false)
				var fs := 30 if i == 0 else 26
				var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
				draw_string(font, Vector2(x + (220 - ts.x) / 2.0, y + 30 + 29 + font.get_ascent(fs) / 2.6), text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.INK)
				x += 232.0
			y += 128.0
		draw_string(Style.sans_bold(), Vector2(20, y + 50), "Atkinson card: Keyboard  Pistachio", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Style.INK)
