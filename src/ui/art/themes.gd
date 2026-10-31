## One look per room of 30 levels: the wall, its pattern, the wood, and the jar style (silhouette, glass tint, lid).
## Walls stay light-to-mid in every room so ink text keeps 4.5:1 and cards stay paper on glass. Early rooms are
## simple and polished; later ones get richer (props, ornament, gold), the finale is marble and gold.
class_name Themes
extends RefCounted

## pattern: plaster, tiles, slats, floral, scallop, brick, stone, panes, damask, hex, stripes, dots, checks, marble
## jar: mason, jam, squat, caddy, honey, bell, apothecary, amphora (silhouettes inside the same card area)
## lid: enamel, gingham, cork, tin, wax, gold    props: none, herbs, bunting, shelf, lanterns, garland, chandelier
const ROOMS := {
	1: {"wall": ["#FFF9EE", "#EEDDC2"], "pattern": "plaster", "ink": "#C9A97E", "wood": ["#C08A5E", "#9A6644", "#764A30"],
		"jar": "mason", "glass": "#3B6E6E", "lid": "enamel", "lid_color": "#A9432C", "props": "none", "accent": "#F28F3B"},
	2: {"wall": ["#F3F6E8", "#D9E0C4"], "pattern": "tiles", "ink": "#9DAA86", "wood": ["#C79A6B", "#A3764E", "#7E5634"],
		"jar": "jam", "glass": "#3F6F66", "lid": "gingham", "lid_color": "#B84A3A", "props": "herbs", "accent": "#8A9A4B"},
	3: {"wall": ["#F8F0DF", "#E5D3AE"], "pattern": "slats", "ink": "#B9965F", "wood": ["#B98352", "#94603A", "#6E4426"],
		"jar": "squat", "glass": "#4A6F55", "lid": "gingham", "lid_color": "#5E7F4A", "props": "bunting", "accent": "#C6553A"},
	4: {"wall": ["#F0F4F6", "#D0DCE4"], "pattern": "floral", "ink": "#93A9BA", "wood": ["#C49A78", "#9F7556", "#7A543B"],
		"jar": "caddy", "glass": "#3E6274", "lid": "tin", "lid_color": "#5B6E86", "props": "shelf", "accent": "#7B3F61"},
	5: {"wall": ["#FCEFE3", "#EDCDB2"], "pattern": "scallop", "ink": "#D29A72", "wood": ["#B4774C", "#8E5634", "#693B20"],
		"jar": "squat", "glass": "#5A6B5E", "lid": "cork", "lid_color": "#B98A5A", "props": "garland", "accent": "#E8A04A"},
	6: {"wall": ["#FFF6E5", "#F0D8B2"], "pattern": "brick", "ink": "#D7B48A", "wood": ["#C69462", "#A06C42", "#7B4C2A"],
		"jar": "jam", "glass": "#4D6E6A", "lid": "gingham", "lid_color": "#C27A2E", "props": "shelf", "accent": "#B98A5A"},
	7: {"wall": ["#EFF4F7", "#D2DEE7"], "pattern": "stone", "ink": "#A3B5C3", "wood": ["#AE8B6E", "#88674E", "#634634"],
		"jar": "bell", "glass": "#4E7488", "lid": "tin", "lid_color": "#7D8FA0", "props": "garland", "accent": "#5E7F9A"},
	8: {"wall": ["#EFF6EC", "#CEE1C9"], "pattern": "panes", "ink": "#8FB286", "wood": ["#B98D64", "#93694A", "#6D4A31"],
		"jar": "bell", "glass": "#3F7259", "lid": "cork", "lid_color": "#A47E57", "props": "herbs", "accent": "#6D8B3A"},
	9: {"wall": ["#EEF5F2", "#C9DCD3"], "pattern": "damask", "ink": "#8FB1A2", "wood": ["#A97C5C", "#835A40", "#5F3E2A"],
		"jar": "apothecary", "glass": "#2F6B63", "lid": "cork", "lid_color": "#9C7651", "props": "shelf", "accent": "#7FA88E"},
	10: {"wall": ["#FFF5DC", "#F2D69B"], "pattern": "hex", "ink": "#DDB666", "wood": ["#C08A50", "#9A6534", "#73461F"],
		"jar": "honey", "glass": "#7A6A3C", "lid": "wax", "lid_color": "#D9A441", "props": "garland", "accent": "#E8A04A"},
	11: {"wall": ["#F6F0E8", "#E1D2C0"], "pattern": "stone", "ink": "#BBA58C", "wood": ["#A0704C", "#7A5034", "#573620"],
		"jar": "squat", "glass": "#55684F", "lid": "wax", "lid_color": "#8E3B36", "props": "lanterns", "accent": "#C6553A"},
	12: {"wall": ["#EEF6F8", "#CDE3EA"], "pattern": "stripes", "ink": "#93BBC8", "wood": ["#C2A07E", "#9B7A5B", "#765841"],
		"jar": "mason", "glass": "#2F6E86", "lid": "tin", "lid_color": "#4A6E8C", "props": "bunting", "accent": "#4A5A8C"},
	13: {"wall": ["#F8F1F6", "#E4D3E1"], "pattern": "dots", "ink": "#C2A3BD", "wood": ["#A97A66", "#83574A", "#5F3C33"],
		"jar": "amphora", "glass": "#5B4A7A", "lid": "enamel", "lid_color": "#5B4A7A", "props": "lanterns", "accent": "#7B3F61"},
	14: {"wall": ["#F9F0E9", "#E7D2C2"], "pattern": "checks", "ink": "#C7A58D", "wood": ["#8F6248", "#6E4634", "#4E2F22"],
		"jar": "bell", "glass": "#5E4B44", "lid": "enamel", "lid_color": "#6B3F2E", "props": "garland", "accent": "#B98A5A"},
	15: {"wall": ["#F4F2EA", "#DDD6C2"], "pattern": "panes", "ink": "#B5AC92", "wood": ["#9D7B57", "#785B3E", "#56402A"],
		"jar": "caddy", "glass": "#4C6264", "lid": "tin", "lid_color": "#8A7A5A", "props": "shelf", "accent": "#D9A441"},
	16: {"wall": ["#F8F3E6", "#E9DAB6"], "pattern": "damask", "ink": "#D2B977", "wood": ["#A3744C", "#7D5231", "#5A361C"],
		"jar": "apothecary", "glass": "#3D5F6E", "lid": "gold", "lid_color": "#D9A441", "props": "chandelier", "accent": "#7B3F61"},
	17: {"wall": ["#FBF8F3", "#E6DFD3"], "pattern": "marble", "ink": "#BDB3A3", "wood": ["#B48A62", "#8C6445", "#64452E"],
		"jar": "amphora", "glass": "#3B6E6E", "lid": "gold", "lid_color": "#D9A441", "props": "chandelier", "accent": "#D9A441"},
	18: {"wall": ["#F1F5F7", "#D4DFE6"], "pattern": "waves", "ink": "#9FB5C4", "wood": ["#B39578", "#8D705A", "#694F3E"],
		"jar": "mason", "glass": "#35617A", "lid": "tin", "lid_color": "#5E7F9A", "props": "lanterns", "accent": "#5E7F9A"},
}


static func of(room: int) -> Dictionary:
	if ROOMS.has(room):
		return ROOMS[room]
	return ROOMS[((room - 1) % ROOMS.size()) + 1]


static func color(room: int, key: String, i: int = 0) -> Color:
	var v: Variant = of(room)[key]
	return Color(str(v[i] if v is Array else v))
