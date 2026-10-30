## Fits jars into the board area: always 3 columns, rows anchored to the bottom (thumb zone), each row on a shelf.
## Pure maths so tests can prove every shipped level fits at 720x1280 with card text >= 34 px.
class_name BoardLayout
extends RefCounted

const COLS := 3
const GAP_X := 18.0
const SHELF := 18.0
const ROW_SPACE := 24.0
const MAX_BOARD_W := 720.0
const MAX_JAR_W := 224.0
const ASPECT := 1.7
const NECK_RATIO := 0.075
## Glass visible beside the cards, as a share of the jar width (clamped).
const INSET_SHARE := 0.075
## Each side of the board stays clear of the Android edge-swipe Back zone (about 24 dp).
const SIDE := 28.0
const PAD_TOP := 8.0
const PAD_BOTTOM := 10.0
const CARD_GAP := 5.0
const MAX_CARD_H := 78.0
const MIN_CARD_H := 46.0
const FONT_MIN := 34
const FONT_MAX := 42
const HOVER_GAP := 14.0
const BOTTOM_SHARE := 0.35


## Returns {jars: Array[Rect2], shelves: Array[Rect2], card_size: Vector2, card_gap, neck, inset, font, hover, ok}.
static func compute(area: Rect2, jar_count: int) -> Dictionary:
	var rows := ceili(jar_count / float(COLS))
	var board_w := minf(area.size.x - SIDE * 2.0, MAX_BOARD_W)
	var jar_w := minf((board_w - GAP_X * (COLS - 1)) / COLS, MAX_JAR_W)
	var fixed := rows * SHELF + (rows - 1) * ROW_SPACE
	var inner := PAD_TOP + PAD_BOTTOM + 3 * CARD_GAP
	# Solve for the card height c: rows * (neck + inner + 4c) + (c + HOVER_GAP) must fit, and jars keep their aspect.
	# The neck depends on jar height, so settle it in a few rounds.
	var neck := 18.0
	var card_h := 0.0
	for _round in 3:
		var by_height := (area.size.y - fixed - HOVER_GAP - rows * (neck + inner)) / (4.0 * rows + 1.0)
		var by_aspect := (jar_w * ASPECT - neck - inner) / 4.0
		card_h = minf(minf(by_height, by_aspect), MAX_CARD_H)
		neck = maxf(18.0, (neck + inner + 4.0 * card_h) * NECK_RATIO)
	var by_height_final := (area.size.y - fixed - HOVER_GAP - rows * (neck + inner)) / (4.0 * rows + 1.0)
	card_h = minf(card_h, by_height_final)
	var jar_h := neck + inner + card_h * 4
	var font := clampi(floori(card_h * 0.62), FONT_MIN, FONT_MAX)
	var total_h := rows * jar_h + fixed
	# Sit low (thumb zone) but not jammed against the bottom: 35% of any spare height goes below the board.
	var spare := maxf(0.0, area.size.y - total_h - (card_h + HOVER_GAP))
	# One-row boards (the first tutorials) sit nearer the middle; taller boards stay low in the thumb zone.
	var y0 := area.end.y - total_h - spare * (BOTTOM_SHARE if rows > 1 else 0.48)
	var grid_w := jar_w * COLS + GAP_X * (COLS - 1)
	var inset := clampf(jar_w * INSET_SHARE, 10.0, 18.0)
	var cx := area.get_center().x
	var jars: Array[Rect2] = []
	var shelves: Array[Rect2] = []
	for r in rows:
		var y := y0 + r * (jar_h + SHELF + ROW_SPACE)
		var in_row := mini(COLS, jar_count - r * COLS)
		var row_w := jar_w * in_row + GAP_X * (in_row - 1)
		var x := cx - row_w / 2.0
		for i in in_row:
			jars.append(Rect2(x + i * (jar_w + GAP_X), y, jar_w, jar_h))
		shelves.append(Rect2(cx - grid_w / 2.0 - 12.0, y + jar_h, grid_w + 24.0, SHELF))
	return {
		"jars": jars, "shelves": shelves, "card_size": Vector2(jar_w - inset * 2, card_h), "inset": inset,
		"card_gap": CARD_GAP, "neck": neck, "font": font, "hover": card_h + HOVER_GAP,
		"ok": card_h >= MIN_CARD_H and y0 - (card_h + HOVER_GAP) >= area.position.y - 0.5,
	}


## Top-left of the card in `slot` (0 = bottom) of a jar rect.
static func card_pos(layout: Dictionary, jar: Rect2, slot: int) -> Vector2:
	var cs: Vector2 = layout["card_size"]
	var y := jar.end.y - PAD_BOTTOM - (slot + 1) * cs.y - slot * CARD_GAP
	return Vector2(jar.position.x + float(layout["inset"]), y)


## Where a lifted card hovers: just above the jar's mouth.
static func hover_pos(layout: Dictionary, jar: Rect2) -> Vector2:
	var cs: Vector2 = layout["card_size"]
	return Vector2(jar.position.x + float(layout["inset"]), jar.position.y - cs.y - HOVER_GAP + 6.0)
