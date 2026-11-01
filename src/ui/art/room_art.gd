## Room-themed material art (Themes): walls with their pattern, wood in the room's tones, and jars in the room's
## glass and lids. SVG strings like Materials; every texture key must name the room (Art caches by key).
class_name RoomArt
extends RefCounted

const TILE := 96.0


## A wall panel: the room's light-to-shade gradient (light from the top left) with its pattern, clipped to `radius`.
static func wall(size: Vector2, room: int, radius: float = 0.0) -> String:
	var th := Themes.of(room)
	var w := size.x
	var h := size.y
	var marks := ""
	var y := 0.0
	while y < h:
		var x := 0.0
		while x < w:
			marks += '<g transform="translate(%s %s)">%s</g>' % [_f(x), _f(y), pattern(str(th["pattern"]), TILE, str(th["ink"]))]
			x += TILE
		y += TILE
	return Materials._svg(size, """
<defs><linearGradient id="w" x1="0.1" y1="0" x2="0.6" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>
<clipPath id="c"><rect x="0" y="0" width="%s" height="%s" rx="%s"/></clipPath></defs>
<g clip-path="url(#c)"><rect x="0" y="0" width="%s" height="%s" fill="url(#w)"/>%s</g>
""" % [th["wall"][0], th["wall"][1], _f(w), _f(h), _f(radius), _f(w), _f(h), marks])


## One TILE x TILE square of the room's pattern, transparent between the marks (tiled behind the whole screen).
static func pattern_tile(size: Vector2, room: int) -> String:
	var th := Themes.of(room)
	return Materials._svg(size, pattern(str(th["pattern"]), size.x, str(th["ink"])))


## The marks of a wall pattern in a t x t tile, in the room's pattern ink at low opacity (never louder than 0.3,
## so cards and text stay the loudest thing on screen).
static func pattern(kind: String, t: float, ink: String) -> String:
	var s := ""
	var op := "0.13"
	match kind:
		"plaster":
			s = '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s" fill-opacity="0.10"/><ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s" fill-opacity="0.07"/>' % [
				_f(t * 0.3), _f(t * 0.35), _f(t * 0.22), _f(t * 0.1), ink, _f(t * 0.75), _f(t * 0.8), _f(t * 0.18), _f(t * 0.08), ink]
		"tiles":
			s = '<rect x="1" y="1" width="%s" height="%s" rx="4" fill="none" stroke="%s" stroke-opacity="%s" stroke-width="2"/>' % [_f(t / 2 - 2), _f(t / 2 - 2), ink, op]
			s += s.replace('x="1" y="1"', 'x="%s" y="1"' % _f(t / 2 + 1)) + s.replace('x="1" y="1"', 'x="1" y="%s"' % _f(t / 2 + 1)) \
				+ s.replace('x="1" y="1"', 'x="%s" y="%s"' % [_f(t / 2 + 1), _f(t / 2 + 1)])
		"slats":
			for i in 3:
				s += '<line x1="%s" y1="0" x2="%s" y2="%s" stroke="%s" stroke-opacity="%s" stroke-width="2"/>' % [_f(i * t / 3), _f(i * t / 3), _f(t), ink, op]
			s += '<ellipse cx="%s" cy="%s" rx="4" ry="2.5" fill="none" stroke="%s" stroke-opacity="0.2" stroke-width="1.5"/>' % [_f(t * 0.5), _f(t * 0.62), ink]
		"floral":
			for p: Vector2 in [Vector2(0.25, 0.25), Vector2(0.75, 0.75)]:
				var c := p * t
				for a in 4:
					var d := Vector2(7, 0).rotated(a * PI / 2.0)
					s += '<circle cx="%s" cy="%s" r="5" fill="%s" fill-opacity="0.12"/>' % [_f(c.x + d.x), _f(c.y + d.y), ink]
				s += '<circle cx="%s" cy="%s" r="3" fill="%s" fill-opacity="0.35"/>' % [_f(c.x), _f(c.y), ink]
		"scallop":
			for i in 2:
				for j in 2:
					var cx := (i + (0.5 if j == 1 else 0.0)) * t / 2.0 + t / 4.0
					s += '<path d="M %s %s A %s %s 0 0 0 %s %s" fill="none" stroke="%s" stroke-opacity="%s" stroke-width="2"/>' % [
						_f(cx - t / 4), _f((j + 1) * t / 2), _f(t / 4), _f(t / 4), _f(cx + t / 4), _f((j + 1) * t / 2), ink, op]
		"brick":
			var bh := t / 4.0
			for r in 4:
				var off := 0.0 if r % 2 == 0 else t / 4.0
				s += '<line x1="0" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-opacity="%s" stroke-width="2"/>' % [_f(r * bh), _f(t), _f(r * bh), ink, op]
				for k in 2:
					var x := off + k * t / 2.0
					s += '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-opacity="%s" stroke-width="2"/>' % [_f(x), _f(r * bh), _f(x), _f((r + 1) * bh), ink, op]
		"stone":
			s = '<rect x="3" y="3" width="%s" height="%s" rx="12" fill="none" stroke="%s" stroke-opacity="0.13" stroke-width="2"/><rect x="%s" y="%s" width="%s" height="%s" rx="10" fill="none" stroke="%s" stroke-opacity="0.13" stroke-width="2"/><rect x="3" y="%s" width="%s" height="%s" rx="10" fill="none" stroke="%s" stroke-opacity="0.13" stroke-width="2"/>' % [
				_f(t * 0.55), _f(t * 0.42), ink, _f(t * 0.62), _f(3), _f(t * 0.35), _f(t * 0.42), ink, _f(t * 0.5), _f(t * 0.9), _f(t * 0.45), ink]
		"panes":
			s = '<rect x="2" y="2" width="%s" height="%s" rx="3" fill="#FFFFFF" fill-opacity="0.18" stroke="%s" stroke-opacity="%s" stroke-width="3"/><line x1="%s" y1="2" x2="%s" y2="%s" stroke="%s" stroke-opacity="0.2" stroke-width="2"/>' % [
				_f(t - 4), _f(t - 4), ink, op, _f(t / 2), _f(t / 2), _f(t - 2), ink]
		"damask":
			s = '<path d="M %s 4 L %s %s L %s %s L 4 %s Z" fill="none" stroke="%s" stroke-opacity="0.13" stroke-width="2"/><circle cx="%s" cy="%s" r="5" fill="%s" fill-opacity="0.13"/><circle cx="0" cy="0" r="4" fill="%s" fill-opacity="0.2"/><circle cx="%s" cy="%s" r="4" fill="%s" fill-opacity="0.2"/>' % [
				_f(t / 2), _f(t - 4), _f(t / 2), _f(t / 2), _f(t - 4), _f(t / 2), ink, _f(t / 2), _f(t / 2), ink, ink, _f(t), _f(t), ink]
		"hex":
			var r := t / 4.0
			for c: Vector2 in [Vector2(t / 4, t / 4), Vector2(t * 0.75, t * 0.75)]:
				var pts := PackedStringArray()
				for k in 6:
					var v := c + Vector2(r, 0).rotated(k * PI / 3.0)
					pts.append("%s,%s" % [_f(v.x), _f(v.y)])
				s += '<polygon points="%s" fill="none" stroke="%s" stroke-opacity="%s" stroke-width="2"/>' % [" ".join(pts), ink, op]
		"stripes":
			s = '<rect x="0" y="0" width="%s" height="%s" fill="%s" fill-opacity="0.07"/>' % [_f(t / 4), _f(t), ink]
			s += '<rect x="%s" y="0" width="%s" height="%s" fill="%s" fill-opacity="0.12"/>' % [_f(t / 2), _f(t / 4), _f(t), ink]
		"dots":
			for c: Vector2 in [Vector2(0.25, 0.25), Vector2(0.75, 0.75)]:
				s += '<circle cx="%s" cy="%s" r="4" fill="%s" fill-opacity="0.15"/>' % [_f(c.x * t), _f(c.y * t), ink]
		"checks":
			s = '<rect x="0" y="0" width="%s" height="%s" fill="%s" fill-opacity="0.1"/><rect x="%s" y="%s" width="%s" height="%s" fill="%s" fill-opacity="0.1"/>' % [
				_f(t / 2), _f(t / 2), ink, _f(t / 2), _f(t / 2), _f(t / 2), _f(t / 2), ink]
		"marble":
			s = '<path d="M 0 %s C %s %s %s %s %s %s" fill="none" stroke="%s" stroke-opacity="0.18" stroke-width="1.5"/><path d="M %s 0 C %s %s %s %s %s %s" fill="none" stroke="%s" stroke-opacity="0.12" stroke-width="1"/>' % [
				_f(t * 0.3), _f(t * 0.3), _f(t * 0.1), _f(t * 0.6), _f(t * 0.6), _f(t), _f(t * 0.4), ink,
				_f(t * 0.2), _f(t * 0.4), _f(t * 0.4), _f(t * 0.1), _f(t * 0.7), _f(t * 0.5), _f(t), ink]
		"waves":
			for i in 2:
				var y := t * (0.25 + i * 0.5)
				s += '<path d="M 0 %s Q %s %s %s %s T %s %s" fill="none" stroke="%s" stroke-opacity="%s" stroke-width="2"/>' % [
					_f(y), _f(t / 4), _f(y - 7), _f(t / 2), _f(y), _f(t), _f(y), ink, op]
	return s


## The room's decoration along the top of the wall (later rooms are richer): hanging herbs, bunting, a high shelf of
## pots, a leafy garland, lanterns, a chandelier. Quiet (it sits behind the HUD), never over the cards.
static func props(size: Vector2, room: int) -> String:
	var th := Themes.of(room)
	var w := size.x
	var h := size.y
	var acc := str(th["accent"])
	var lid := str(th["lid_color"])
	var wood: Array = th["wood"]
	var s := ""
	match str(th["props"]):
		"herbs":
			s += '<path d="M 0 %s Q %s %s %s %s" fill="none" stroke="#8C6440" stroke-opacity="0.55" stroke-width="2"/>' % [_f(h * 0.22), _f(w / 2), _f(h * 0.34), _f(w), _f(h * 0.22)]
			for i in 5:
				var x := w * (0.1 + i * 0.2)
				var y := h * 0.22 + sin(PI * x / w) * h * 0.1
				s += '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="#8C6440" stroke-opacity="0.5" stroke-width="1.5"/>' % [_f(x), _f(y), _f(x), _f(y + 14)]
				for k in 5:
					var a := -0.9 + k * 0.45
					s += '<ellipse cx="%s" cy="%s" rx="5" ry="13" transform="rotate(%s %s %s)" fill="#6D8B3A" fill-opacity="0.5"/>' % [
						_f(x + sin(a) * 8), _f(y + 30), _f(rad_to_deg(a)), _f(x + sin(a) * 8), _f(y + 30)]
		"bunting":
			s += '<path d="M 0 %s Q %s %s %s %s" fill="none" stroke="#3D2C2E" stroke-opacity="0.3" stroke-width="1.5"/>' % [_f(h * 0.25), _f(w / 2), _f(h * 0.5), _f(w), _f(h * 0.25)]
			var n := 11
			for i in n:
				var t := (i + 0.5) / n
				var x := w * t
				var y := h * 0.25 + 4.0 * t * (1.0 - t) * h * 0.25 * 2.0 - 2.0
				var c: String = [acc, lid, "#FFF8EC"][i % 3]
				s += '<path d="M %s %s L %s %s L %s %s Z" fill="%s" fill-opacity="0.6"/>' % [_f(x - 14), _f(y), _f(x + 14), _f(y), _f(x), _f(y + 30), c]
		"shelf":
			s += '<rect x="0" y="%s" width="%s" height="10" fill="%s" fill-opacity="0.55"/>' % [_f(h * 0.62), _f(w), wood[1]]
			var x := 28.0
			var k := 0
			while x < w - 30:
				var ph := 22.0 + (k % 3) * 8.0
				var pc: String = [acc, lid, str(th["glass"])][k % 3]
				s += '<rect x="%s" y="%s" width="%s" height="%s" rx="5" fill="%s" fill-opacity="0.45"/>' % [_f(x), _f(h * 0.62 - ph), _f(20 + (k % 2) * 8), _f(ph), pc]
				x += 58.0 + (k % 4) * 9.0
				k += 1
		"garland":
			var pts := 14
			s += '<path d="M 0 %s Q %s %s %s %s" fill="none" stroke="#5E7F4A" stroke-opacity="0.45" stroke-width="2.5"/>' % [_f(h * 0.18), _f(w / 2), _f(h * 0.62), _f(w), _f(h * 0.18)]
			for i in pts:
				var t := (i + 0.5) / pts
				var x := w * t
				var y := h * 0.18 + 4.0 * t * (1.0 - t) * h * 0.22 * 2.0
				s += '<ellipse cx="%s" cy="%s" rx="10" ry="5" transform="rotate(%s %s %s)" fill="#6D8B3A" fill-opacity="0.5"/>' % [_f(x), _f(y), _f(25 if i % 2 == 0 else -25), _f(x), _f(y)]
				if i % 3 == 1:
					s += '<circle cx="%s" cy="%s" r="4" fill="%s" fill-opacity="0.6"/>' % [_f(x + 6), _f(y + 7), acc]
		"lanterns":
			for i in 3:
				var x := w * (0.2 + i * 0.3)
				var top := h * (0.08 + (i % 2) * 0.1)
				s += '<line x1="%s" y1="0" x2="%s" y2="%s" stroke="#3D2C2E" stroke-opacity="0.3" stroke-width="1.5"/>' % [_f(x), _f(x), _f(top)]
				s += '<circle cx="%s" cy="%s" r="30" fill="%s" fill-opacity="0.16"/>' % [_f(x), _f(top + 26), acc]
				s += '<rect x="%s" y="%s" width="26" height="36" rx="11" fill="%s" fill-opacity="0.55"/>' % [_f(x - 13), _f(top + 8), acc]
				s += '<rect x="%s" y="%s" width="18" height="5" rx="2" fill="#3D2C2E" fill-opacity="0.35"/>' % [_f(x - 9), _f(top + 5)]
		"chandelier":
			var cx := w / 2
			s += '<line x1="%s" y1="0" x2="%s" y2="%s" stroke="#B07E2C" stroke-opacity="0.55" stroke-width="2"/>' % [_f(cx), _f(cx), _f(h * 0.3)]
			s += '<path d="M %s %s Q %s %s %s %s" fill="none" stroke="#D9A441" stroke-opacity="0.6" stroke-width="3"/>' % [_f(cx - 70), _f(h * 0.45), _f(cx), _f(h * 0.75), _f(cx + 70), _f(h * 0.45)]
			for dx in [-70, -35, 0, 35, 70]:
				var y := h * 0.45 + (0.3 if absi(dx) < 40 else 0.0) * h * 0.25
				s += '<rect x="%s" y="%s" width="6" height="16" rx="2" fill="#FFF8EC" fill-opacity="0.8"/><circle cx="%s" cy="%s" r="9" fill="#F6DC8C" fill-opacity="0.45"/>' % [
					_f(cx + dx - 3), _f(y - 16), _f(cx + dx), _f(y - 20)]
	return Materials._svg(size, s)


## A shelf plank in the room's wood.
static func plank(size: Vector2, room: int) -> String:
	return _wood(Materials.plank(size), room)


## Home's cabinet in the room's wood.
static func cabinet(size: Vector2, room: int) -> String:
	return _wood(Materials.cabinet(size), room)


## A small jar on a shelf in the room's glass and shape, with the room's lid colour (gold lids stay gold).
static func mini_jar(size: Vector2, room: int, layers: Array, outline_only: bool, gold: bool = false) -> String:
	var lid := Style.GOLD if gold else Themes.color(room, "lid_color")
	return _glass(Materials.mini_jar(size, layers, lid, outline_only, shape(room)), room)


## Jar silhouettes: shoulder (r1) and base (r2) radii as a share of the width, and how far the walls bow out between
## them (barrel, in units). Kept inside the jar rect so the card area is the same in every room.
const SHAPES := {
	"mason": {"r1": 0.2, "r2": 0.16}, "jam": {"r1": 0.26, "r2": 0.22, "barrel": 2.0},
	"squat": {"r1": 0.13, "r2": 0.1}, "caddy": {"r1": 0.08, "r2": 0.07}, "honey": {"r1": 0.24, "r2": 0.3, "barrel": 4.0},
	"bell": {"r1": 0.26, "r2": 0.1}, "apothecary": {"r1": 0.14, "r2": 0.08}, "amphora": {"r1": 0.24, "r2": 0.26, "barrel": 4.0},
}


static func shape(room: int) -> Dictionary:
	return SHAPES.get(str(Themes.of(room)["jar"]), SHAPES["mason"])


## The glass behind the cards, in the room's tint and shape.
static func jar_back(size: Vector2, room: int) -> String:
	return _glass(Materials.jar_back(size, shape(room)), room)


## The glass over the cards, in the room's tint and shape, with the style's own detail: honey pots have rings, caddies
## and squat jars a raised band under the shoulder, apothecary jars a tall printed panel line.
static func jar_front(size: Vector2, room: int) -> String:
	var svg := _glass(Materials.jar_front(size, shape(room)), room)
	var w := size.x
	var h := size.y
	var rim := Materials.jar_rim(h)
	var deep := Themes.color(room, "glass").darkened(0.2).to_html(false)
	var extra := ""
	match str(Themes.of(room)["jar"]):
		"honey", "amphora":
			for k in 3:
				var y := rim + (h - rim) * (0.22 + k * 0.03)
				extra += '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="#%s" stroke-opacity="0.22" stroke-width="2"/>' % [_f(w * 0.08), _f(y), _f(w * 0.92), _f(y), deep]
		"caddy", "squat":
			var y2 := rim + (h - rim) * 0.12
			extra = '<rect x="2" y="%s" width="%s" height="6" rx="3" fill="#FFFFFF" fill-opacity="0.18" stroke="#%s" stroke-opacity="0.25" stroke-width="1.5"/>' % [_f(y2), _f(w - 4), deep]
		"apothecary":
			extra = '<rect x="%s" y="%s" width="%s" height="%s" rx="6" fill="none" stroke="#FFFFFF" stroke-opacity="0.25" stroke-width="1.5"/>' % [
				_f(w * 0.1), _f(rim + (h - rim) * 0.08), _f(w * 0.8), _f((h - rim) * 0.84)]
	return svg.replace("</svg>", extra + "</svg>")


## A lid in the room's style, carrying its group's colour (the colour is information: it matches the rail tag).
static func lid(size: Vector2, room: int, color: Color) -> String:
	var w := size.x
	var h := size.y
	match str(Themes.of(room)["lid"]):
		"gingham":
			# A cloth cover over the mouth: checks in the group's colour, a scalloped hem and a twine tie.
			var checks := ""
			var s := 9.0
			var x := 0.0
			while x < w:
				var y := 0.0
				while y < h * 0.8:
					if int(x / s + y / s) % 2 == 0:
						checks += '<rect x="%s" y="%s" width="%s" height="%s" fill="#%s" fill-opacity="0.75"/>' % [_f(x), _f(y), _f(s), _f(s), color.to_html(false)]
					y += s
				x += s
			var hem := "M 0 %s " % _f(h * 0.8)
			var k := 0.0
			while k < w:
				hem += "Q %s %s %s %s " % [_f(k + 6), _f(h * 0.8 + 7), _f(minf(k + 12, w)), _f(h * 0.8)]
				k += 12
			return Materials._svg(size, """
<defs><clipPath id="c"><path d="M 2 2 L %s 2 L %s %s %sL 2 %s Z"/></clipPath></defs>
<rect x="1" y="4" width="%s" height="%s" rx="5" fill="#3D2C2E" fill-opacity="0.18"/>
<g clip-path="url(#c)"><rect x="0" y="0" width="%s" height="%s" fill="#FFF8EC"/>%s</g>
<rect x="0" y="%s" width="%s" height="3" fill="#8C6440"/>
""" % [_f(w - 2), _f(w - 2), _f(h * 0.8), hem.replace("M 0 %s " % _f(h * 0.8), ""), _f(h * 0.8), _f(w - 2), _f(h - 2), _f(w), _f(h), checks,
				_f(h * 0.55), _f(w)])
		"cork":
			var dots := ""
			for i in 6:
				dots += '<circle cx="%s" cy="%s" r="1.8" fill="#8C6440" fill-opacity="0.6"/>' % [_f(w * (0.15 + i * 0.14)), _f(h * (0.35 + (i % 2) * 0.25))]
			return Materials._svg(size, """
<rect x="%s" y="2" width="%s" height="%s" rx="7" fill="#3D2C2E" fill-opacity="0.18"/>
<rect x="%s" y="0" width="%s" height="%s" rx="7" fill="#C49A6C"/>
<rect x="%s" y="2" width="%s" height="5" rx="2.5" fill="#D9B88E"/>%s
<rect x="%s" y="%s" width="%s" height="%s" rx="2" fill="#%s"/>
""" % [_f(w * 0.08 + 1), _f(w * 0.84), _f(h - 3), _f(w * 0.08), _f(w * 0.84), _f(h - 3), _f(w * 0.12), _f(w * 0.76), dots,
				_f(w * 0.08), _f(h * 0.62), _f(w * 0.84), _f(h * 0.18), color.to_html(false)])
		"tin":
			return Materials.lid(size, color.lerp(Color("#9AA5AE"), 0.45))
		"wax":
			var svg := Materials.lid(size, color.darkened(0.15))
			var seal := '<circle cx="%s" cy="%s" r="%s" fill="#%s"/><circle cx="%s" cy="%s" r="%s" fill="#FFFFFF" fill-opacity="0.25"/>' % [
				_f(w / 2), _f(h * 0.62), _f(h * 0.34), color.darkened(0.35).to_html(false), _f(w / 2 - h * 0.1), _f(h * 0.52), _f(h * 0.1)]
			return svg.replace("</svg>", seal + "</svg>")
		"gold":
			var svg := Materials.lid(size, Style.GOLD)
			var dot := '<rect x="%s" y="%s" width="%s" height="%s" rx="3" fill="#%s"/>' % [_f(w * 0.3), _f(h * 0.3), _f(w * 0.4), _f(h * 0.32), color.to_html(false)]
			return svg.replace("</svg>", dot + "</svg>")
	return Materials.lid(size, color)


static func _glass(svg: String, room: int) -> String:
	var g := Themes.color(room, "glass")
	return svg.replace(Materials.GLASS_DEEP, "#" + g.darkened(0.22).to_html(false)).replace(Materials.GLASS, "#" + g.to_html(false))


static func _wood(svg: String, room: int) -> String:
	var wd: Array = Themes.of(room)["wood"]
	return svg.replace(Materials.WOOD_TOP, wd[0]).replace(Materials.WOOD_FACE[0], wd[1]).replace(Materials.WOOD_FACE[1], wd[2])


static func _f(v: float) -> String:
	return str(snappedf(v, 0.1))
