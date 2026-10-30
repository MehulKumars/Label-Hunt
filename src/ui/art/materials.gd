## The pantry's materials as SVG, built per size in canvas units: glass jars (a back layer behind the cards and a
## front layer over them), paper cards, enamel lids, wooden planks and kraft labels. One light from the top left.
## No outlines in ink: edges come from the material itself (glass rim, paper edge, wood lip).
class_name Materials
extends RefCounted

const GLASS := "#3B6E6E"
const GLASS_DEEP := "#2E5A5A"
const PAPER_FACE := "#FFFEFA"
const PAPER_FOOT := "#F6EEDF"
const PAPER_EDGE := "#E4D3B6"
const SHADOW := "#3D2C2E"
const KRAFT := ["#EEDDBA", "#E2C99A"]
const WOOD_TOP := "#C08A5E"
const WOOD_FACE := ["#9A6644", "#764A30"]


## Jar proportions shared by both layers and by the board (rim height for the lid, neck inset).
static func jar_rim(h: float) -> float:
	return maxf(18.0, h * BoardLayout.NECK_RATIO)


static func jar_neck(w: float) -> float:
	return w * 0.09


static func jar_back(size: Vector2) -> String:
	var w := size.x
	var h := size.y
	var rim := jar_rim(h)
	var ni := jar_neck(w)
	var body := _jar_body(w, h, rim)
	var base := clampf(h * 0.06, 10.0, 22.0)
	var r2 := minf(w * 0.16, 34.0)
	return _svg(size, """
<defs>
<linearGradient id="t" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="%s" stop-opacity="0.07"/><stop offset="1" stop-color="%s" stop-opacity="0.16"/>
</linearGradient>
<radialGradient id="l" cx="0.42" cy="0.3" r="0.65">
<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.22"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
</radialGradient>
</defs>
<rect x="%s" y="%s" width="%s" height="%s" rx="4" fill="%s" fill-opacity="0.08"/>
<path d="%s" fill="url(#t)"/>
<path d="%s" fill="url(#l)"/>
<path d="M %s %s Q %s %s %s %s" fill="none" stroke="%s" stroke-opacity="0.22" stroke-width="2"/>
""" % [GLASS, GLASS, _f(ni), _f(rim * 0.15), _f(w - ni * 2), _f(rim * 1.2), GLASS, body, body,
		_f(r2 * 0.7), _f(h - base * 1.3), _f(w / 2.0), _f(h - base * 2.3), _f(w - r2 * 0.7), _f(h - base * 1.3), GLASS_DEEP])


static func jar_front(size: Vector2) -> String:
	var w := size.x
	var h := size.y
	var rim := jar_rim(h)
	var ni := jar_neck(w)
	var r1 := minf(w * 0.2, 40.0)
	var body := _jar_body(w, h, rim)
	var base := clampf(h * 0.06, 10.0, 22.0)
	var bh := h - rim
	var stroke := clampf(w * 0.014, 2.0, 3.0)
	return _svg(size, """
<defs>
<clipPath id="b"><path d="%s"/></clipPath>
<linearGradient id="w" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="%s" stop-opacity="0.34"/><stop offset="0.09" stop-color="%s" stop-opacity="0.08"/>
<stop offset="0.5" stop-color="%s" stop-opacity="0"/><stop offset="0.91" stop-color="%s" stop-opacity="0.08"/>
<stop offset="1" stop-color="%s" stop-opacity="0.30"/>
</linearGradient>
<linearGradient id="f" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="%s" stop-opacity="0"/><stop offset="1" stop-color="%s" stop-opacity="0.34"/>
</linearGradient>
<linearGradient id="s" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.8"/><stop offset="0.55" stop-color="#FFFFFF" stop-opacity="0.28"/>
<stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
</linearGradient>
</defs>
<g clip-path="url(#b)">
<rect x="0" y="%s" width="%s" height="%s" fill="url(#w)"/>
<rect x="0" y="%s" width="%s" height="%s" fill="url(#f)"/>
<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="url(#s)"/>
<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="#FFFFFF" fill-opacity="0.45"/>
<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="#FFFFFF" fill-opacity="0.22"/>
</g>
<path d="%s" fill="none" stroke="%s" stroke-opacity="0.5" stroke-width="%s"/>
<rect x="%s" y="%s" width="%s" height="%s" rx="4" fill="%s" fill-opacity="0.10" stroke="%s" stroke-opacity="0.45" stroke-width="%s"/>
<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="#FFFFFF" stroke-opacity="0.5" stroke-width="2"/>
<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-opacity="0.25" stroke-width="2"/>
<path d="M %s %s Q %s %s %s %s" fill="none" stroke="#FFFFFF" stroke-opacity="0.65" stroke-width="3" stroke-linecap="round"/>
""" % [body, GLASS_DEEP, GLASS, GLASS, GLASS, GLASS_DEEP, GLASS, GLASS_DEEP,
		_f(rim), _f(w), _f(bh), _f(h - base), _f(w), _f(base),
		_f(w * 0.075), _f(rim + r1 * 0.75), _f(maxf(6.0, w * 0.045)), _f(bh * 0.62), _f(maxf(3.0, w * 0.022)),
		_f(w * 0.14), _f(rim + r1 * 0.8), _f(maxf(3.0, w * 0.018)), _f(bh * 0.16), _f(maxf(1.5, w * 0.009)),
		_f(w * 0.885), _f(rim + r1), _f(maxf(3.0, w * 0.016)), _f(bh * 0.48), _f(maxf(1.5, w * 0.008)),
		body, GLASS_DEEP, _f(stroke),
		_f(ni), _f(rim * 0.15), _f(w - ni * 2), _f(rim * 1.05), GLASS, GLASS_DEEP, _f(stroke),
		_f(ni + 4), _f(rim * 0.48), _f(w - ni - 4), _f(rim * 0.48),
		_f(ni + 4), _f(rim * 0.8), _f(w - ni - 4), _f(rim * 0.8), GLASS_DEEP,
		_f(r1 * 0.5), _f(rim + r1 * 0.95), _f(r1 * 0.5), _f(rim + r1 * 0.35), _f(r1 * 1.15), _f(rim + r1 * 0.18)])


## A paper word card. The face is the top (h - 5) units; the edge and a soft contact shadow sit below it.
static func card(size: Vector2) -> String:
	var w := size.x
	var h := size.y
	var r := minf(14.0, h * 0.24)
	return _svg(size, """
<defs><linearGradient id="p" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/>
</linearGradient></defs>
<rect x="2" y="4" width="%s" height="%s" rx="%s" fill="%s" fill-opacity="0.16"/>
<rect x="0" y="2" width="%s" height="%s" rx="%s" fill="%s"/>
<rect x="0" y="0" width="%s" height="%s" rx="%s" fill="url(#p)"/>
<rect x="%s" y="1.5" width="%s" height="2" rx="1" fill="#FFFFFF" fill-opacity="0.9"/>
""" % [PAPER_FACE, PAPER_FOOT, _f(w - 4), _f(h - 4), _f(r), SHADOW, _f(w), _f(h - 3), _f(r), PAPER_EDGE,
		_f(w), _f(h - 5), _f(r), _f(r * 0.7), _f(w - r * 1.4)])


## A screw-top lid in enamel of any colour (the group's colour, or gold), with knurled ridges.
static func lid(size: Vector2, base: Color = Color("#A9432C")) -> String:
	var w := size.x
	var h := size.y
	var c: Array = ["#" + base.lightened(0.22).to_html(false), "#" + base.to_html(false), "#" + base.darkened(0.28).to_html(false)]
	var ridges := ""
	var x := 9.0
	while x < w - 8.0:
		ridges += '<rect x="%s" y="%s" width="2.5" height="%s" fill="#FFFFFF" fill-opacity="0.2"/>' % [_f(x), _f(h * 0.3), _f(h * 0.5)]
		ridges += '<rect x="%s" y="%s" width="2" height="%s" fill="#000000" fill-opacity="0.12"/>' % [_f(x + 2.5), _f(h * 0.3), _f(h * 0.5)]
		x += 9.0
	return _svg(size, """
<defs><linearGradient id="e" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="%s"/><stop offset="0.45" stop-color="%s"/><stop offset="1" stop-color="%s"/>
</linearGradient></defs>
<rect x="1" y="3" width="%s" height="%s" rx="7" fill="%s" fill-opacity="0.2"/>
<rect x="0" y="0" width="%s" height="%s" rx="7" fill="url(#e)"/>
%s
<rect x="4" y="2" width="%s" height="%s" rx="3" fill="#FFFFFF" fill-opacity="0.32"/>
<rect x="0" y="%s" width="%s" height="3" rx="1.5" fill="#000000" fill-opacity="0.18"/>
""" % [c[0], c[1], c[2], _f(w - 2), _f(h - 3), SHADOW, _f(w), _f(h - 3), ridges, _f(w - 8), _f(h * 0.2),
		_f(h - 7), _f(w)])


## A wooden shelf plank: the lit top surface, the front face, and a soft shadow on the wall below.
static func plank(size: Vector2) -> String:
	var w := size.x
	var h := size.y
	var top := h * 0.3
	var face := h * 0.45
	return _svg(size, """
<defs>
<linearGradient id="f" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>
<linearGradient id="s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s" stop-opacity="0.22"/><stop offset="1" stop-color="%s" stop-opacity="0"/></linearGradient>
</defs>
<rect x="0" y="%s" width="%s" height="%s" fill="url(#s)"/>
<rect x="0" y="0" width="%s" height="%s" rx="3" fill="%s"/>
<rect x="0" y="%s" width="%s" height="%s" rx="3" fill="url(#f)"/>
<rect x="0" y="%s" width="%s" height="1.5" fill="#FFFFFF" fill-opacity="0.35"/>
""" % [WOOD_FACE[0], WOOD_FACE[1], SHADOW, SHADOW, _f(top + face), _f(w), _f(h - top - face), _f(w), _f(top + 2), WOOD_TOP,
		_f(top), _f(w), _f(face), _f(top), _f(w)])


## A kraft paper label (jar labels, the rail's tags). hole: a punched hole with a ring on the left.
static func label(size: Vector2, hole: bool = false) -> String:
	var w := size.x
	var h := size.y
	var punch := ""
	if hole:
		punch = '<circle cx="%s" cy="%s" r="5" fill="%s" fill-opacity="0.35"/><circle cx="%s" cy="%s" r="5" fill="none" stroke="#FFFFFF" stroke-opacity="0.7" stroke-width="2"/>' % [
			_f(14), _f(h / 2.0), SHADOW, _f(14), _f(h / 2.0)]
	return _svg(size, """
<defs><linearGradient id="k" x1="0" y1="0" x2="0.3" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient></defs>
<rect x="1.5" y="3" width="%s" height="%s" rx="6" fill="%s" fill-opacity="0.16"/>
<rect x="0" y="0" width="%s" height="%s" rx="6" fill="url(#k)"/>
<rect x="3" y="3" width="%s" height="%s" rx="4" fill="none" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="1.5"/>
%s
""" % [KRAFT[0], KRAFT[1], _f(w - 3), _f(h - 3), SHADOW, _f(w), _f(h - 3), _f(w - 6), _f(h - 9), punch])


## Rounded jar outline (shoulders at the top, a slightly tighter base), from the rim down.
static func _jar_body(w: float, h: float, rim: float) -> String:
	var r1 := minf(w * 0.2, 40.0)
	var r2 := minf(w * 0.16, 34.0)
	return "M %s %s L %s %s Q %s %s %s %s L %s %s Q %s %s %s %s L %s %s Q %s %s %s %s L %s %s Q %s %s %s %s Z" % [
		_f(r1), _f(rim), _f(w - r1), _f(rim), _f(w), _f(rim), _f(w), _f(rim + r1),
		_f(w), _f(h - r2), _f(w), _f(h), _f(w - r2), _f(h),
		_f(r2), _f(h), _f(0), _f(h), _f(0), _f(h - r2),
		_f(0), _f(rim + r1), _f(0), _f(rim), _f(r1), _f(rim)]


static func _svg(size: Vector2, body: String) -> String:
	return '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="0 0 %s %s">%s</svg>' % [
		_f(size.x), _f(size.y), _f(size.x), _f(size.y), body]


static func _f(v: float) -> String:
	return str(snappedf(v, 0.1))


## A raised button: enamel (any colour, for primary actions) or paper (secondary). The face is the top (h - 8)
## units; the material's edge and a soft shadow sit below it.
static func pill(size: Vector2, base: Color, paper: bool = false) -> String:
	var w := size.x
	var h := size.y
	var r := (h - 8.0) / 2.0
	var top := PAPER_FACE if paper else "#" + base.lightened(0.16).to_html(false)
	var bottom := PAPER_FOOT if paper else "#" + base.darkened(0.08).to_html(false)
	var edge := PAPER_EDGE if paper else "#" + base.darkened(0.35).to_html(false)
	var gloss := 0.55 if paper else 0.14
	return _svg(size, """
<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient></defs>
<rect x="2" y="7" width="%s" height="%s" rx="%s" fill="%s" fill-opacity="0.18"/>
<rect x="0" y="3" width="%s" height="%s" rx="%s" fill="%s"/>
<rect x="0" y="0" width="%s" height="%s" rx="%s" fill="url(#g)"/>
<rect x="%s" y="2.5" width="%s" height="%s" rx="%s" fill="#FFFFFF" fill-opacity="%s"/>
""" % [top, bottom, _f(w - 4), _f(h - 7), _f(r), SHADOW, _f(w), _f(h - 5), _f(r), edge, _f(w), _f(h - 8), _f(r),
		_f(r * 0.7), _f(w - r * 1.4), _f((h - 8) * 0.14), _f((h - 8) * 0.07), str(gloss)])


## A round paper disc for icon buttons (the face is a circle of diameter size.x; edge and shadow below).
static func disc(size: Vector2) -> String:
	var d := size.x
	var c := d / 2.0
	return _svg(size, """
<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient></defs>
<circle cx="%s" cy="%s" r="%s" fill="%s" fill-opacity="0.18"/>
<circle cx="%s" cy="%s" r="%s" fill="%s"/>
<circle cx="%s" cy="%s" r="%s" fill="url(#g)"/>
""" % [PAPER_FACE, PAPER_FOOT, _f(c + 1), _f(c + 6), _f(c - 3), SHADOW, _f(c), _f(c + 3), _f(c - 2), PAPER_EDGE,
		_f(c), _f(c), _f(c - 2)])


## Preserve colours for the layers in a solved jar on the shelf. A category always gets the same one.
const PRESERVES := ["#7B3F61", "#E8A04A", "#8A9A4B", "#D9A441", "#C6553A", "#4A5A8C", "#7FA88E", "#B98A5A",
	"#EBD3A2", "#5E7F9A", "#B5C77A", "#6D8B3A"]


static func preserve(label: String) -> Color:
	return Color(PRESERVES[absi(label.hash()) % PRESERVES.size()])


## Preserve colours for a stack of categories, bottom up; a layer never repeats the colour of the one below it.
static func preserve_layers(labels: Array) -> Array:
	var out: Array = []
	var prev := -1
	for l in labels:
		var i := absi(str(l).hash()) % PRESERVES.size()
		if i == prev:
			i = (i + 5) % PRESERVES.size()
		out.append(Color(PRESERVES[i]))
		prev = i
	return out


## A small shelf jar: one coloured layer per solved category (bottom up), glass over it, and a lid
## (`lid` = enamel colour; gold for a clean solve). Empty `layers` draws the faint outline of a slot to come.
static func mini_jar(size: Vector2, layers: Array, lid_color: Color, outline_only: bool = false) -> String:
	var w := size.x
	var h := size.y
	var lid_h := h * 0.13
	var neck_h := h * 0.07
	var top := lid_h + neck_h
	var body := _jar_body(w, h, top)
	var neck := '<rect x="%s" y="%s" width="%s" height="%s" rx="2" fill="%s" fill-opacity="0.16" stroke="%s" stroke-opacity="0.45" stroke-width="1.5"/>' % [
		_f(w * 0.16), _f(lid_h - 1.0), _f(w * 0.68), _f(neck_h + 3.0), GLASS, GLASS_DEEP]
	if outline_only:
		return _svg(size, '<path d="%s" fill="%s" fill-opacity="0.05" stroke="%s" stroke-opacity="0.25" stroke-width="2.5" stroke-dasharray="6 5"/>' % [
			body, SHADOW, SHADOW])
	var fill := ""
	var n := layers.size()
	var fill_top := top + (h - top) * 0.26
	var band := (h - fill_top - 2.0) / maxf(n, 1)
	for i in n:
		var c: Color = layers[i]
		var y := h - 2.0 - band * (i + 1)
		fill += '<rect x="0" y="%s" width="%s" height="%s" fill="#%s"/>' % [_f(y), _f(w), _f(band + 0.6), c.to_html(false)]
		fill += '<rect x="0" y="%s" width="%s" height="1.5" fill="#FFFFFF" fill-opacity="0.22"/>' % [_f(y), _f(w)]
	var lid := '<rect x="%s" y="0" width="%s" height="%s" rx="3" fill="#%s"/><rect x="%s" y="1.5" width="%s" height="%s" rx="1.5" fill="#FFFFFF" fill-opacity="0.38"/><rect x="%s" y="%s" width="%s" height="2" fill="#000000" fill-opacity="0.18"/>' % [
		_f(w * 0.12), _f(w * 0.76), _f(lid_h), lid_color.to_html(false), _f(w * 0.16), _f(w * 0.68), _f(lid_h * 0.28),
		_f(w * 0.12), _f(lid_h - 2.0), _f(w * 0.76)]
	return _svg(size, """
<defs><clipPath id="b"><path d="%s"/></clipPath>
<linearGradient id="s" x1="0" y1="0" x2="1" y2="0">
<stop offset="0" stop-color="#000000" stop-opacity="0.2"/><stop offset="0.1" stop-color="#FFFFFF" stop-opacity="0.05"/>
<stop offset="0.85" stop-color="#000000" stop-opacity="0"/><stop offset="1" stop-color="#000000" stop-opacity="0.2"/>
</linearGradient></defs>
<ellipse cx="%s" cy="%s" rx="%s" ry="3" fill="%s" fill-opacity="0.22"/>
<path d="%s" fill="%s" fill-opacity="0.12"/>
<g clip-path="url(#b)">%s<rect x="0" y="0" width="%s" height="%s" fill="url(#s)"/>
<rect x="%s" y="%s" width="%s" height="%s" rx="3" fill="#FFFFFF" fill-opacity="0.5"/></g>
<path d="%s" fill="none" stroke="%s" stroke-opacity="0.5" stroke-width="2"/>
%s%s
""" % [body, _f(w / 2.0), _f(h - 1.0), _f(w * 0.45), SHADOW, body, GLASS, fill, _f(w), _f(h),
		_f(w * 0.12), _f(top + (h - top) * 0.12), _f(maxf(3.0, w * 0.07)), _f((h - top) * 0.6),
		body, GLASS_DEEP, neck, lid])


## The cabinet that frames Home's shelf: a wooden frame around a recessed back panel lit from the top left.
static func cabinet(size: Vector2) -> String:
	var w := size.x
	var h := size.y
	var t := 16.0
	return _svg(size, """
<defs>
<linearGradient id="f" x1="0" y1="0" x2="0.4" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>
<linearGradient id="p" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#DCC6A2"/><stop offset="0.12" stop-color="#E9D8BA"/><stop offset="1" stop-color="#E2CDAA"/></linearGradient>
</defs>
<rect x="3" y="8" width="%s" height="%s" rx="22" fill="%s" fill-opacity="0.2"/>
<rect x="0" y="0" width="%s" height="%s" rx="22" fill="url(#f)"/>
<rect x="2" y="2" width="%s" height="3" rx="1.5" fill="#FFFFFF" fill-opacity="0.25"/>
<rect x="%s" y="%s" width="%s" height="%s" rx="10" fill="url(#p)"/>
<rect x="%s" y="%s" width="%s" height="10" rx="5" fill="%s" fill-opacity="0.12"/>
""" % [WOOD_FACE[0], WOOD_FACE[1], _f(w - 6), _f(h - 8), SHADOW, _f(w), _f(h - 6), _f(w - 4),
		_f(t), _f(t), _f(w - t * 2), _f(h - t * 2 - 6), _f(t), _f(t), _f(w - t * 2), SHADOW])


## What's inside a big jar: one band per entry in `layers` from the bottom, filling `frac` of the body, with a
## gentle meniscus on top. Drawn between jar_back and jar_front.
static func jar_contents(size: Vector2, layers: Array, frac: float) -> String:
	var w := size.x
	var h := size.y
	var rim := jar_rim(h)
	var body := _jar_body(w, h, rim)
	var n := layers.size()
	if n == 0 or frac <= 0.0:
		return _svg(size, "")
	var fill_h := (h - rim - 6.0) * clampf(frac, 0.0, 1.0)
	var band := fill_h / n
	var bands := ""
	for i in n:
		var c: Color = layers[i]
		var y := h - band * (i + 1)
		bands += '<rect x="0" y="%s" width="%s" height="%s" fill="#%s"/>' % [_f(y), _f(w), _f(band + 0.8), c.to_html(false)]
		bands += '<rect x="0" y="%s" width="%s" height="2" fill="#FFFFFF" fill-opacity="0.16"/>' % [_f(y), _f(w)]
	var top := h - fill_h
	return _svg(size, """
<defs><clipPath id="b"><path d="%s"/></clipPath></defs>
<g clip-path="url(#b)">%s
<path d="M 0 %s Q %s %s %s %s" fill="none" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="3"/></g>
""" % [body, bands, _f(top + 2.0), _f(w / 2.0), _f(top + 9.0), _f(w), _f(top + 2.0)])
