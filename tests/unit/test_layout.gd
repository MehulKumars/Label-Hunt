extends GutTest

# Board areas left after the HUD on 16:9, 20:9 (with a notch) and a 3:4 tablet canvas.
# HUD budget: top bar 88 + rail (max 2 rows) 116 + gaps 16 = 220 on top; bottom bar 140.
const AREAS := {
	"16:9": Rect2(0, 220, 720, 1280 - 220 - 140),
	"20:9": Rect2(0, 48 + 220, 720, 1600 - 48 - 220 - 140 - 24),
	"tablet": Rect2(0, 220, 960, 1280 - 220 - 140),
}


func test_every_jar_count_fits_with_readable_cards() -> void:
	for name in AREAS:
		var area: Rect2 = AREAS[name]
		for n in range(2, 10):
			var l := BoardLayout.compute(area, n)
			assert_true(l["ok"], "%s with %d jars fits" % [name, n])
			assert_gte(l["font"], 34, "%s/%d card font" % [name, n])
			var jars: Array[Rect2] = l["jars"]
			assert_eq(jars.size(), n)
			for i in jars.size():
				assert_true(area.grow(0.5).encloses(jars[i]), "%s/%d jar %d inside the area" % [name, n, i])
				for k in range(i + 1, jars.size()):
					assert_false(jars[i].intersects(jars[k]), "%s/%d jars %d and %d don't overlap" % [name, n, i, k])


func test_board_sits_in_the_lower_part() -> void:
	for n in [3, 5, 8]:
		var area: Rect2 = AREAS["20:9"]
		var l := BoardLayout.compute(area, n)
		var jars: Array[Rect2] = l["jars"]
		var shelves: Array[Rect2] = l["shelves"]
		var board_mid := (jars[0].position.y + shelves[shelves.size() - 1].end.y) / 2.0
		assert_gt(board_mid, area.get_center().y, "%d jars: board centre is below the area centre" % n)
		assert_lte(shelves[shelves.size() - 1].end.y, area.end.y + 0.5)


func test_cards_stack_inside_their_jar() -> void:
	var l := BoardLayout.compute(AREAS["16:9"], 7)
	var jar: Rect2 = l["jars"][0]
	var cs: Vector2 = l["card_size"]
	for slot in 4:
		var p := BoardLayout.card_pos(l, jar, slot)
		assert_true(jar.encloses(Rect2(p, cs)), "slot %d inside the jar" % slot)


func test_safe_area_converts_to_canvas_units() -> void:
	var ins := SafeArea.insets(Vector2i(1080, 2400), Rect2i(0, 90, 1080, 2400 - 90 - 60), Vector2(720, 1600))
	assert_almost_eq(ins["top"], 60.0, 0.01)
	assert_almost_eq(ins["bottom"], 40.0, 0.01)
