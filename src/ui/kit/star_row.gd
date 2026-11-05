## A row of three stars, filled for the stars a level earned. Static (the room shelves, a level card) or stamped in
## one by one on the Win card (`play`): each won star drops in with a small overshoot, a chime that climbs, and a
## light tick; a third star rings the bell. Reduce motion shows them at once, still with the sounds.
class_name StarRow
extends Control

## Stars filled (0-3).
var stars := 0
## Size of one star, and the gap between stars. The middle star is drawn `lift` larger and a little raised (the
## Win card's arc); 0 keeps a flat row.
var star_size := 64.0
var gap := 10.0
var lift := 0.0
## Per filled star, 0..1 while it stamps in (1 = at rest).
var _t: Array[float] = [1.0, 1.0, 1.0]


func _init(n: int = 0, size_px: float = 64.0) -> void:
	stars = clampi(n, 0, 3)
	star_size = size_px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(star_size * 3.0 + gap * 2.0, star_size)


## Stamps the filled stars in, one by one, starting after `delay` seconds.
func play(delay: float = 0.0) -> void:
	var still := bool(Save.setting("reduce_motion"))
	for i in 3:
		_t[i] = 1.0 if (i >= stars or still) else 0.0
	queue_redraw()
	# The Win card builds its rows before it opens: start the clock once the row is on screen.
	if not is_inside_tree():
		await tree_entered
	for i in stars:
		var at := delay + 0.2 * i
		var last := i == 2
		Sfx.play_at(at, "bell" if last else "chime", 1.0 + 0.12 * i, 0.0, -2.0 if last else -6.0)
		get_tree().create_timer(at).timeout.connect(func() -> void:
			if is_instance_valid(self):
				Haptics.tick(25 if last else 15, 0.5 if last else 0.3))
		if still:
			continue
		var tw := create_tween()
		tw.tween_interval(at)
		tw.tween_method(func(v: float) -> void:
			_t[i] = v
			queue_redraw(), 0.0, 1.0, 0.24)


func _draw() -> void:
	var total := star_size * 3.0 + gap * 2.0 + star_size * lift
	var x := (size.x - total) / 2.0
	for i in 3:
		var big := star_size * (1.0 + (lift if i == 1 else 0.0))
		var y := (size.y - big) / 2.0 + (0.0 if i == 1 or lift == 0.0 else star_size * lift * 0.5)
		var cell := Rect2(Vector2(x, y), Vector2(big, big))
		x += big + gap
		var key := "star_%s_%d" % ["on" if i < stars else "off", int(big)]
		var off := Art.tex("star_off_%d" % int(big), cell.size, Materials.star.bind(false))
		draw_texture_rect(off, cell, false)
		if i >= stars or _t[i] <= 0.0:
			continue
		# Drop in from 1.6x with a little overshoot (back ease), fading in over the first third.
		var t := _t[i]
		var k := 1.0 + 0.6 * (1.0 - _ease_back(t))
		var r := Rect2(cell.get_center() - cell.size * k / 2.0, cell.size * k)
		draw_texture_rect(Art.tex(key, cell.size, Materials.star.bind(true)), r, false, Color(1, 1, 1, clampf(t * 3.0, 0.0, 1.0)))


static func _ease_back(t: float) -> float:
	var c := 1.70158
	var u := t - 1.0
	return 1.0 + (c + 1.0) * u * u * u + c * u * u
