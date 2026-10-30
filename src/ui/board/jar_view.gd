## A glass jar, drawn in two layers so cards sit inside it: the back (glass tint) behind the cards and the front
## (outline, shine, cork, lid, label) above them. BoardView owns both and positions them on the same rect.
class_name JarView
extends Control

enum Layer { BACK, FRONT }

var layer := Layer.BACK
var neck := 20.0
var corked := false
var labelled_text := ""
## 0 = no lid, 1 = lid fully screwed on.
var lid_t := 0.0
var lid_label := ""
## Fraction of the label's characters typed so far.
var label_typed := 1.0
var label_color := Style.PAPRIKA
var shine_t := -1.0
var dim := false


func _init(l: Layer = Layer.BACK) -> void:
	layer = l
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 0 if l == Layer.BACK else 2


func _draw() -> void:
	var w := size.x
	var h := size.y
	var neck_inset := w * 0.1
	var body := Rect2(0, neck, w, h - neck)
	var mouth := Rect2(neck_inset, 0, w - neck_inset * 2, neck + 10)
	if layer == Layer.BACK:
		draw_style_box(Style.box(Style.GLASS_FILL, 30), body)
		draw_style_box(Style.box(Style.GLASS_FILL, 8), mouth)
		return
	var edge := Style.GLASS_EDGE
	draw_style_box(_outline(edge, 4, 30), body)
	draw_line(Vector2(mouth.position.x, 2), Vector2(mouth.position.x, neck + 4), edge, 4.0, true)
	draw_line(Vector2(mouth.end.x, 2), Vector2(mouth.end.x, neck + 4), edge, 4.0, true)
	draw_line(Vector2(mouth.position.x - 4, 2), Vector2(mouth.end.x + 4, 2), edge, 5.0, true)
	# Shine stripe down the left side of the glass.
	draw_line(Vector2(12, neck + 26), Vector2(12, h - 34), Style.GLASS_SHINE, 6.0, true)
	draw_line(Vector2(22, neck + 26), Vector2(22, neck + 70), Color(1, 1, 1, 0.3), 3.0, true)
	if corked:
		var cork := Rect2(mouth.position.x + 4, -14, mouth.size.x - 8, neck + 8)
		draw_style_box(Style.box(Color("#C49A6C"), 8, 3, Color("#7A5636")), cork)
		for i in 3:
			draw_circle(cork.position + Vector2(cork.size.x * (0.25 + i * 0.25), cork.size.y * 0.45), 3.0, Color("#7A5636"))
	if lid_t > 0.0:
		_draw_lid(mouth)
	var text := lid_label if lid_t > 0.0 else labelled_text
	if text != "" and (lid_t >= 1.0 or labelled_text != ""):
		_draw_label(text, w, h)


func _draw_lid(mouth: Rect2) -> void:
	var drop := (1.0 - minf(lid_t, 1.0)) * -46.0
	var lid := Rect2(mouth.position.x - 8, -16 + drop, mouth.size.x + 16, 26)
	var squash := 1.0 + 0.12 * sin(clampf(lid_t, 0.0, 1.0) * PI) * float(lid_t > 0.7)
	lid.size.y /= squash
	draw_style_box(Style.box(label_color, 9, 3, Style.INK), lid)
	# Ridges scroll sideways while it screws on.
	var phase := fmod(lid_t * 3.0, 1.0) * 14.0
	var x := lid.position.x + 8 + phase
	while x < lid.end.x - 6:
		draw_line(Vector2(x, lid.position.y + 5), Vector2(x, lid.end.y - 5), Color(1, 1, 1, 0.35), 2.0, true)
		x += 14.0


func _draw_label(text: String, w: float, h: float) -> void:
	var font := Style.typed()
	var fs := Style.LABEL_FONT
	var shown := text.substr(0, ceili(text.length() * clampf(label_typed, 0.0, 1.0)))
	var max_w := w - 26.0
	var lines := _wrap(text, font, fs, max_w)
	while lines.size() > 2 and fs > 15:
		fs -= 1
		lines = _wrap(text, font, fs, max_w)
	var line_h := fs + 4.0
	var box_h := line_h * lines.size() + 14.0
	var box := Rect2(8, h * 0.5 - box_h / 2.0, w - 16, box_h)
	draw_set_transform(box.get_center(), deg_to_rad(-2.0), Vector2.ONE)
	var local := Rect2(-box.size / 2.0, box.size)
	draw_style_box(Style.box(Style.SHADOW, 6), Rect2(local.position + Vector2(0, 4), local.size))
	draw_style_box(Style.box(Style.PAPER, 6, 2, Style.INK), local)
	var used := 0
	for i in lines.size():
		var line: String = lines[i]
		var visible := clampi(shown.length() - used, 0, line.length())
		used += line.length() + 1
		var ts := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var y := local.position.y + 7.0 + line_h * i + font.get_ascent(fs)
		draw_string(font, Vector2(-ts.x / 2.0, y), line.substr(0, visible), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.INK)
	if shine_t >= 0.0 and shine_t <= 1.0:
		var sx := lerpf(local.position.x - 30, local.end.x + 30, shine_t)
		draw_line(Vector2(sx, local.position.y + 2), Vector2(sx - 18, local.end.y - 2), Color(1, 1, 1, 0.75), 10.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _wrap(text: String, font: Font, fs: int, max_w: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var trial := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
			out.append(line)
			line = word
		else:
			line = trial
	if line != "":
		out.append(line)
	return out


static func _outline(color: Color, width: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(width)
	sb.border_color = color
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb
