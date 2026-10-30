## The one place to tune Jarful's look and feel: palette, type, spacing, radii and motion. Screens hold no raw
## numbers of their own. Materials (glass, paper, enamel, wood, kraft) live in Materials.
class_name Style
extends RefCounted

# Mehul's contrast-checked palette. Apricot is decoration only (never text); text on Teal is Paper.
const PAPER := Color("#FFF8EC")
const INK := Color("#3D2C2E")
const PAPRIKA := Color("#A9432C")
const TEAL := Color("#3B6E6E")
const APRICOT := Color("#F28F3B")

const PAPER_DEEP := Color("#F3E6D0")
const WALL_LIGHT := Color("#FFF9EE")
const WALL_SHADE := Color("#EEDDC2")
const CARD := Color("#FFFDF8")
const INK_SOFT := Color(0.239, 0.173, 0.18, 0.62)
const INK_FAINT := Color(0.239, 0.173, 0.18, 0.14)
const WOOD := Color("#8C5A3C")
const WOOD_DARK := Color("#6B4430")
const GOLD := Color("#D9A441")
const GLASS_FILL := Color(0.231, 0.431, 0.431, 0.10)
const GLASS_EDGE := Color(0.231, 0.431, 0.431, 0.55)
const GLASS_SHINE := Color(1, 1, 1, 0.45)
const FROST := Color("#E3EEEC")
const SHADOW := Color(0.239, 0.173, 0.18, 0.18)
const DIM := Color(0.239, 0.173, 0.18, 0.45)

## Group tags: colour plus a glyph shape, so colour is never the only signal.
const TAG_COLORS: Array[Color] = [
	Color("#3B6E6E"), Color("#A9432C"), Color("#C8711F"), Color("#6F4A86"), Color("#5E6B1F"), Color("#36598A"),
]
## DROP replaced a triangle, which read as a warning sign next to slips.
enum Glyph { CIRCLE, DROP, SQUARE, DIAMOND, STAR, HEXAGON }

# Type scale on the 720-wide canvas (22 u = 33 px on a 1080-wide phone, above the 28 px floor).
const FS_22 := 22
const FS_26 := 26
const FS_30 := 30
const FS_36 := 36
const FS_44 := 44
const FS_56 := 56
const FS_72 := 72
const FS_96 := 96
const BODY_FONT := FS_30
const LABEL_FONT := FS_26
const HUD_FONT := FS_36
const CARD_FONT_MAX := 42
const CARD_FONT_MIN := 34

# Space (4-unit grid), radii and touch targets. 88 u is about 48 dp on a typical phone.
const GUTTER := 32.0
const SP_1 := 4.0
const SP_2 := 8.0
const SP_3 := 12.0
const SP_4 := 16.0
const SP_6 := 24.0
const SP_8 := 32.0
const R_S := 8
const R_M := 14
const R_L := 22
const R_XL := 28
const R_PILL := 48
const RADIUS := R_M
const TOUCH := 88
const TOUCH_PRIMARY := 104

# Motion in seconds (plan-m2 §11). Reduce motion keeps state changes and drops decoration.
const T_PRESS := 0.08
const T_RELEASE := 0.12
const T_LIFT := 0.08
const T_DROP := 0.15
const T_BOUNCE := 0.22
const T_LID_HOLD := 0.08
const T_LID := 0.3
const T_TYPE_CHAR := 0.025
const T_SHINE := 0.4
const T_SCREEN := 0.25
const T_SHEET_IN := 0.25
const T_SHEET_OUT := 0.18
const WOBBLE_DEG := 3.0

static var _sans: FontVariation
static var _sans_bold: FontVariation
static var _sans_heavy: FontVariation
static var _hand: Font


## Atkinson Hyperlegible Next: everything read during play.
static func sans() -> Font:
	if _sans == null:
		_sans = _weight(500)
	return _sans


static func sans_bold() -> Font:
	if _sans_bold == null:
		_sans_bold = _weight(700)
	return _sans_bold


## Headings and HUD titles.
static func sans_heavy() -> Font:
	if _sans_heavy == null:
		_sans_heavy = _weight(800)
	return _sans_heavy


## Gochi Hand: the marker on a kraft label. Solved labels, the wordmark and celebration lines only, never < 26 u.
static func hand() -> Font:
	if _hand == null:
		_hand = load("res://assets/fonts/GochiHand-Regular.ttf")
	return _hand


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
			ci.draw_circle(c, r, color, true, -1.0, true)
		Glyph.DROP:
			var drop := PackedVector2Array([c + Vector2(0, -r * 1.25)])
			for i in 13:
				var a := deg_to_rad(-30.0 + i * 20.0)
				drop.append(c + Vector2(0, r * 0.22) + Vector2(cos(a), sin(a)) * r * 0.82)
			_poly(ci, drop, color)
		Glyph.SQUARE:
			_poly(ci, PackedVector2Array([c + Vector2(-r, -r) * 0.85, c + Vector2(r, -r) * 0.85, c + Vector2(r, r) * 0.85, c + Vector2(-r, r) * 0.85]), color)
		Glyph.DIAMOND:
			_poly(ci, PackedVector2Array([c + Vector2(0, -r * 1.15), c + Vector2(r, 0), c + Vector2(0, r * 1.15), c + Vector2(-r, 0)]), color)
		Glyph.STAR:
			var pts := PackedVector2Array()
			for i in 10:
				var rr := r * (1.15 if i % 2 == 0 else 0.5)
				pts.append(c + Vector2.from_angle(-PI / 2 + i * PI / 5) * rr)
			_poly(ci, pts, color)
		Glyph.HEXAGON:
			var hex := PackedVector2Array()
			for i in 6:
				hex.append(c + Vector2.from_angle(i * PI / 3) * r)
			_poly(ci, hex, color)


## Filled polygon with an antialiased rim (draw_colored_polygon alone has hard, jaggy edges).
static func _poly(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	ci.draw_colored_polygon(pts, color)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, color, 1.0, true)


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


## A soft glow behind a rect (StyleBoxFlat's blurred shadow), e.g. the jar a dragged card hovers over.
static func glow(color: Color, radius: float, spread: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.0)
	sb.set_corner_radius_all(int(radius))
	sb.shadow_color = color
	sb.shadow_size = spread
	sb.anti_aliasing = true
	return sb
