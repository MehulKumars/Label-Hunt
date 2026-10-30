## A glass jar in two layers so cards sit inside it: the back (glass tint) behind the cards and the front (walls,
## highlights, rim, cork, lid, label) above them. BoardView owns both and positions them on the same rect.
## Art comes from Materials; this file only places it and animates the lid and label.
class_name JarView
extends Control

enum Layer { BACK, FRONT }

const LABEL_SHARE := 0.88

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
## A dragged card is over this jar (shown on every jar alike, so it never hints at which drop is right).
var hot := false


func _init(l: Layer = Layer.BACK) -> void:
	layer = l
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 0 if l == Layer.BACK else 2


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if layer == Layer.BACK:
		if hot:
			var body := Rect2(0, neck, size.x, size.y - neck)
			draw_style_box(Style.glow(Color(Style.APRICOT, 0.55), 30, 22), body.grow(-6))
		draw_texture_rect(Art.tex("jar_back", size, Materials.jar_back), r, false)
		return
	draw_texture_rect(Art.tex("jar_front", size, Materials.jar_front), r, false)
	var ni := Materials.jar_neck(size.x)
	var mouth := Rect2(ni, 0, size.x - ni * 2, neck)
	if corked:
		_draw_cork(mouth)
	if lid_t > 0.0:
		_draw_lid(mouth)
	var text := lid_label if lid_t > 0.0 else labelled_text
	if text != "" and (lid_t >= 1.0 or labelled_text != ""):
		_draw_label(text)
	if dim:
		draw_rect(r, Color(Style.PAPER, 0.45))


func _draw_cork(mouth: Rect2) -> void:
	var cork := Rect2(mouth.position.x + 4, -14, mouth.size.x - 8, neck + 10)
	draw_style_box(Style.box(Color("#C49A6C"), 8), cork)
	draw_style_box(Style.box(Color("#D7B286"), 6), Rect2(cork.position + Vector2(4, 3), Vector2(cork.size.x - 8, 6)))
	for i in 3:
		draw_circle(cork.position + Vector2(cork.size.x * (0.25 + i * 0.25), cork.size.y * 0.55), 2.5, Color("#8C6440"), true, -1.0, true)


## The lid drops in from above, then seats with a small squash.
func _draw_lid(mouth: Rect2) -> void:
	var t := clampf(lid_t, 0.0, 1.0)
	var drop := (1.0 - ease(t, 0.4)) * -52.0
	var lid_size := Vector2(mouth.size.x + 16, maxf(26.0, neck * 1.25))
	var squash := 1.0 + 0.1 * sin(clampf((t - 0.7) / 0.3, 0.0, 1.0) * PI)
	var rect := Rect2(mouth.position.x - 8, -lid_size.y * 0.55 + drop, lid_size.x, lid_size.y / squash)
	rect.position.x -= (rect.size.x * (squash - 1.0)) / 2.0
	rect.size.x *= squash
	var tex := Art.tex("lid_%s" % label_color.to_html(false), lid_size, Materials.lid.bind(label_color))
	draw_texture_rect(tex, rect, false)


func _draw_label(text: String) -> void:
	var font := Style.hand()
	var w := size.x * LABEL_SHARE
	var max_w := w - 20.0
	var fs := Style.FS_30
	var lines := _wrap(text, font, fs, max_w)
	if lines.size() > 1 or font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		fs = Style.FS_26
		lines = _wrap(text, font, fs, max_w)
	var line_h := fs * 1.08
	var box := Vector2(w, line_h * lines.size() + 20.0)
	var centre := Vector2(size.x / 2.0, neck + (size.y - neck) * 0.46)
	draw_set_transform(centre, deg_to_rad(-2.0), Vector2.ONE)
	var local := Rect2(-box / 2.0, box)
	draw_texture_rect(Art.tex("label", box, Materials.label.bind(false)), local, false)
	var shown := ceili(text.length() * clampf(label_typed, 0.0, 1.0))
	var used := 0
	for i in lines.size():
		var line: String = lines[i]
		var visible := clampi(shown - used, 0, line.length())
		used += line.length() + 1
		var ts := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var y := local.position.y + 9.0 + line_h * i + font.get_ascent(fs) * 0.92
		draw_string(font, Vector2(-ts.x / 2.0, y), line.substr(0, visible), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.INK)
	if shine_t >= 0.0 and shine_t <= 1.0:
		var sx := lerpf(local.position.x - 30, local.end.x + 30, shine_t)
		draw_line(Vector2(sx, local.position.y + 3), Vector2(sx - 16, local.end.y - 5), Color(1, 1, 1, 0.6), 12.0, true)
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
