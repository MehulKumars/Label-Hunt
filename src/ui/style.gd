## The one place to tune Jarful's look and feel: palette, fonts, sizes and timings.
class_name Style
extends RefCounted

# Mehul's contrast-checked palette. Apricot is decoration only (never text).
const PAPER := Color("#FFF8EC")
const INK := Color("#3D2C2E")
const PAPRIKA := Color("#A9432C")
const TEAL := Color("#3B6E6E")
const APRICOT := Color("#F28F3B")

const PAPER_DEEP := Color("#F3E6D0")
const CARD := Color("#FFFDF8")
const INK_SOFT := Color(0.239, 0.173, 0.18, 0.55)
const WOOD := Color("#8C5A3C")
const WOOD_DARK := Color("#6B4430")
const GLASS_FILL := Color(0.231, 0.431, 0.431, 0.10)
const GLASS_EDGE := Color(0.231, 0.431, 0.431, 0.55)
const GLASS_SHINE := Color(1, 1, 1, 0.45)
const FROST := Color("#E3EEEC")
const SHADOW := Color(0.239, 0.173, 0.18, 0.18)
const DIM := Color(0.239, 0.173, 0.18, 0.5)

## Group tags: colour plus a glyph shape, so colour is never the only signal.
const TAG_COLORS: Array[Color] = [
	Color("#3B6E6E"), Color("#A9432C"), Color("#C8711F"), Color("#6F4A86"), Color("#5E6B1F"), Color("#36598A"),
]
enum Glyph { CIRCLE, TRIANGLE, SQUARE, DIAMOND, STAR, HEXAGON }

# Sizes on the 720-wide canvas. 96 px is about 48 dp on a typical phone.
const TOUCH := 96
const CARD_FONT_MAX := 42
const CARD_FONT_MIN := 34
const LABEL_FONT := 22
const HUD_FONT := 32
const BODY_FONT := 28
const RADIUS := 14

# Feel timings in seconds (studio plan numbers). Reduce motion scales the decorative ones.
const T_LIFT := 0.08
const T_DROP := 0.15
const T_BOUNCE := 0.22
const T_LID := 0.3
const T_TYPE_CHAR := 0.03
const T_SCREEN := 0.18
const WOBBLE_DEG := 3.0

static var _sans: FontVariation
static var _sans_bold: FontVariation
static var _type: Font


static func sans() -> Font:
	if _sans == null:
		_sans = _weight(500)
	return _sans


static func sans_bold() -> Font:
	if _sans_bold == null:
		_sans_bold = _weight(700)
	return _sans_bold


## Typewriter face for labels and headings.
static func typed() -> Font:
	if _type == null:
		_type = load("res://assets/fonts/CourierPrime-Bold.ttf")
	return _type


static func tag_color(group: int) -> Color:
	return TAG_COLORS[group % TAG_COLORS.size()]


static func _weight(w: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/AtkinsonHyperlegibleNext-Variable.ttf")
	fv.variation_opentype = {"weight": w}
	return fv


## Draws a group glyph centred on `c` (used on tags and cards).
static func draw_glyph(ci: CanvasItem, glyph: int, c: Vector2, r: float, color: Color) -> void:
	match glyph % 6:
		Glyph.CIRCLE:
			ci.draw_circle(c, r, color)
		Glyph.TRIANGLE:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.1), c + Vector2(r, r * 0.8), c + Vector2(-r, r * 0.8)]), color)
		Glyph.SQUARE:
			ci.draw_rect(Rect2(c - Vector2(r, r) * 0.85, Vector2(r, r) * 1.7), color)
		Glyph.DIAMOND:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.15), c + Vector2(r, 0), c + Vector2(0, r * 1.15), c + Vector2(-r, 0)]), color)
		Glyph.STAR:
			var pts := PackedVector2Array()
			for i in 10:
				var rr := r * (1.15 if i % 2 == 0 else 0.5)
				pts.append(c + Vector2.from_angle(-PI / 2 + i * PI / 5) * rr)
			ci.draw_colored_polygon(pts, color)
		Glyph.HEXAGON:
			var hex := PackedVector2Array()
			for i in 6:
				hex.append(c + Vector2.from_angle(i * PI / 3) * r)
			ci.draw_colored_polygon(hex, color)


## Rounded-rect helper via StyleBoxFlat (antialiased).
static func box(fill: Color, radius: float = RADIUS, border: float = 0.0, border_color: Color = INK) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius))
	if border > 0.0:
		sb.set_border_width_all(int(border))
		sb.border_color = border_color
	sb.anti_aliasing = true
	return sb
