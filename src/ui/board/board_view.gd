## The jars and cards on their shelves: handles tap-tap / drag input and animates what Session reports.
## Never decides rules itself: it asks for a drop and plays back the result.
class_name BoardView
extends Control

signal drop_requested(from: int, to: int)
signal lift_started(jar: int)
signal lift_cancelled
signal buried_tapped(card: int)
signal peek_picked(card: int)
signal lid_finished(jar: int)

const DRAG_START := 12.0
## A dragged card rides this far above the fingertip (in card heights, centre to touch point) so the finger never
## hides the word.
const FINGER_LIFT := 1.15
## How quickly a dragged card catches up with the finger (per second, exponential).
const FOLLOW_RATE := 32.0
const PICK_RISE := 10.0

var session: Session
var layout: Dictionary = {}
var cards: Dictionary = {} # card id -> CardView
var backs: Array[JarView] = []
var fronts: Array[JarView] = []
var lifted_jar := -1
var peek_mode := false
var reduce_motion := false
var _dragging := false
var _pressing := false
## True while the press that picked the card up is still down (release = tap, so the card goes to its hover spot).
var _fresh_pick := false
var _press_pos := Vector2.ZERO
var _finger := Vector2.ZERO
var _hot := -1
## A buried card under the press: if the press turns out to be a tap, it gets the "only the top moves" nudge.
var _buried_hit := -1
## Lid cascade: how many lids in a row (each within 4 s of the last), and when the last one went on.
var _combo := 0
var _last_lid := -10.0
var _flights := {} # CardView -> Tween
var _wobble := {} # jar -> Tween
var _misc: Array[Tween] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		relayout()


func setup(s: Session) -> void:
	session = s
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for tw in _misc:
		if tw.is_valid():
			tw.kill()
	_misc.clear()
	for tw in _wobble.values():
		(tw as Tween).kill()
	cards.clear()
	backs.clear()
	fronts.clear()
	_flights.clear()
	_wobble.clear()
	lifted_jar = -1
	peek_mode = false
	_end_drag()
	for j in s.board.jar_count():
		_add_jar_nodes()
	for c in s.level.card_count():
		var cv := CardView.new()
		cv.card = c
		cv.word = s.level.word(c)
		cv.z_index = 1
		add_child(cv)
		cards[c] = cv
	relayout()


## +Jar: every jar and card glides to its new place and the new jar fades in, rather than the board jumping.
func add_jar() -> void:
	var old := {}
	for v: Control in backs + fronts:
		old[v] = v.position
	for c in cards:
		old[cards[c]] = (cards[c] as CardView).position
	_add_jar_nodes()
	relayout()
	if reduce_motion:
		return
	for node: Control in old:
		var to := node.position
		node.position = old[node]
		_track(node.create_tween()).tween_property(node, "position", to, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for v: Control in [backs.back(), fronts.back()]:
		v.modulate.a = 0.0
		_track(v.create_tween()).tween_property(v, "modulate:a", 1.0, 0.25).set_delay(0.12)


## The board's entrance: cards drop into their jars, staggered jar by jar, bottom up. Skipped with reduce motion.
func deal_in() -> void:
	if reduce_motion:
		return
	var i := 0
	for j in session.board.jar_count():
		var jar := session.board.jars[j]
		for k in jar.size():
			var cv: CardView = cards[jar[k]]
			var home := cv.position
			cv.position = home - Vector2(0, 90)
			cv.modulate.a = 0.0
			var tw := cv.create_tween().set_parallel()
			_flights[cv] = tw
			tw.tween_property(cv, "position", home, 0.22).set_delay(i * 0.022).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(cv, "modulate:a", 1.0, 0.12).set_delay(i * 0.022)
			tw.finished.connect(func() -> void: _flights.erase(cv))
			i += 1


func _add_jar_nodes() -> void:
	var b := JarView.new(JarView.Layer.BACK)
	var f := JarView.new(JarView.Layer.FRONT)
	add_child(b)
	add_child(f)
	backs.append(b)
	fronts.append(f)


func relayout() -> void:
	if session == null or size.x <= 0.0:
		return
	layout = BoardLayout.compute(Rect2(Vector2.ZERO, size), session.board.jar_count())
	var rects: Array[Rect2] = layout["jars"]
	for j in rects.size():
		for v: JarView in [backs[j], fronts[j]]:
			v.position = rects[j].position
			v.size = rects[j].size
			v.neck = layout["neck"]
			v.pivot_offset = Vector2(rects[j].size.x / 2.0, rects[j].size.y)
	var font := _board_font((layout["card_size"] as Vector2).x, layout["font"])
	for c in cards:
		var cv: CardView = cards[c]
		cv.size = layout["card_size"]
		cv.pivot_offset = cv.size / 2.0
		cv.font_size = font
	refresh_jars()
	refresh_cards(false)
	sync(false)
	queue_redraw()


## One card size per board (42, 38, 34, then 30): the largest at which every word fits beside a tag chip, so
## neighbouring cards never look mismatched and no glyph sizes are rasterised mid-game.
func _board_font(card_w: float, cap: int) -> int:
	var f := Style.sans_bold()
	var avail := card_w - 20.0 - 30.0
	for fs in [42, 38, 34, 30]:
		if fs > cap and fs > 30:
			continue
		var fits := true
		for c in cards:
			if f.get_string_size((cards[c] as CardView).word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
				fits = false
				break
		if fits:
			return fs
	return 30


## Jar decorations from board state (corks, printed labels, lids already on).
func refresh_jars() -> void:
	for j in session.board.jar_count():
		var f := fronts[j]
		f.corked = session.board.corked[j] == 1
		var lg := session.board.label_group[j]
		f.labelled_text = session.level.groups[lg]["label"] if lg >= 0 else ""
		if session.board.lidded[j] == 1 and f.lid_t <= 0.0:
			var g := LevelData.group_of(session.board.jars[j][0])
			f.lid_t = 1.0
			f.lid_label = session.level.groups[g]["label"]
			f.label_color = Style.tag_color(g)
			f.label_typed = 1.0
		f.queue_redraw()


## Card faces from knowledge (tags, frost). `pop` animates chips that just appeared.
func refresh_cards(pop: bool = true) -> void:
	for c in cards:
		var cv: CardView = cards[c]
		var was_frosted := cv.frosted
		cv.frosted = session.know.seen[c] == 0
		if was_frosted and not cv.frosted and pop:
			Sfx.play("frost")
		cv.set_tag(session.know.class_tag(c), pop)
		cv.queue_redraw()


func slot_pos(j: int, slot: int) -> Vector2:
	return BoardLayout.card_pos(layout, layout["jars"][j], slot)


func hover_pos(j: int) -> Vector2:
	return BoardLayout.hover_pos(layout, layout["jars"][j])


## Moves every card to where the board says it is.
func sync(animate: bool = true) -> void:
	for j in session.board.jar_count():
		var jar := session.board.jars[j]
		for k in jar.size():
			var cv: CardView = cards[jar[k]]
			cv.set_buried(k < jar.size() - 1)
			var lifted := j == lifted_jar and k == jar.size() - 1
			if lifted and _dragging:
				continue
			var target := hover_pos(j) if lifted else slot_pos(j, k)
			if cv.position.distance_to(target) < 0.5 and not _flights.has(cv):
				continue
			if animate:
				_fly(cv, target, Style.T_DROP, 40.0, not lifted)
			else:
				_stop(cv)
				cv.position = target
				cv.rotation = 0.0
				cv.set_lifted(lifted)


func jar_at(pos: Vector2) -> int:
	if layout.is_empty():
		return -1
	var rects: Array[Rect2] = layout["jars"]
	var hover: float = layout["hover"]
	for j in rects.size():
		var r := rects[j].grow_individual(BoardLayout.GAP_X / 2.0, hover, BoardLayout.GAP_X / 2.0, BoardLayout.SHELF + 8.0)
		if r.has_point(pos):
			return j
	return -1


func card_at(pos: Vector2) -> int:
	var best := -1
	var best_z := -1
	for c in cards:
		var cv: CardView = cards[c]
		if Rect2(cv.position, cv.size).has_point(pos) and cv.z_index > best_z:
			best = c
			best_z = cv.z_index
	return best


func top_card(j: int) -> CardView:
	var t := session.board.top(j)
	return cards[t] if t >= 0 else null


# --- input ---------------------------------------------------------------------------------------------------------

## Input model:
## - Press a jar: its top card pops up in place (same frame).
## - Release without moving (a tap): the card glides to its hover spot above the jar; tap another jar to drop.
## - Move past DRAG_START: the card rides just above the fingertip; release over any jar to drop there.
##   The drop jar is the one under the card (generous column hit areas), highlighted while you hover.
## - Tap the lifted card's own jar again, or empty space, to put it back.
func _gui_input(event: InputEvent) -> void:
	if session == null or session.is_over():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_canceled():
			# The system took the touch (Android edge-swipe Back): put the card down, never drop it.
			if lifted_jar >= 0:
				cancel_lift()
			_pressing = false
			accept_event()
		elif event.pressed:
			_on_press(event.position)
		else:
			_on_release(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _pressing and lifted_jar >= 0 \
			and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_finger = event.position
		if not _dragging and _finger.distance_to(_press_pos) > DRAG_START:
			_start_drag()
		if _dragging:
			_set_hot(_drop_target())
		accept_event()


func _on_press(pos: Vector2) -> void:
	_press_pos = pos
	_finger = pos
	_dragging = false
	_pressing = false
	_fresh_pick = false
	if peek_mode:
		var c := card_at(pos)
		if c >= 0:
			peek_picked.emit(c)
		return
	var j := jar_at(pos)
	if lifted_jar >= 0:
		if j == lifted_jar or _on_card(top_card(lifted_jar), pos):
			# Press on the lifted card's jar: a tap puts it back, a drag carries it.
			_pressing = true
		elif j < 0:
			cancel_lift()
		else:
			drop_requested.emit(lifted_jar, j)
		return
	if j < 0 or not session.board.can_take(j):
		if j >= 0:
			wobble(j, 0.5)
		return
	var hit := card_at(pos)
	_buried_hit = hit if hit >= 0 and hit != session.board.top(j) else -1
	_pick(j)


func _on_release(_pos: Vector2) -> void:
	var was_pressing := _pressing
	_pressing = false
	if lifted_jar < 0 or not was_pressing:
		_end_drag()
		return
	if _dragging:
		var to := _drop_target()
		_end_drag()
		if to >= 0 and to != lifted_jar:
			drop_requested.emit(lifted_jar, to)
		else:
			cancel_lift()
	elif _fresh_pick:
		_fly(top_card(lifted_jar), hover_pos(lifted_jar), Style.T_LIFT + 0.04, 0.0, false)
		if _buried_hit >= 0:
			(cards[_buried_hit] as CardView).nudge()
			buried_tapped.emit(_buried_hit)
	else:
		cancel_lift()
	_fresh_pick = false


## Picks up the top card of jar j: it pops up in place and waits to see whether this is a tap or a drag.
func _pick(j: int) -> void:
	lifted_jar = j
	_pressing = true
	_fresh_pick = true
	var cv := top_card(j)
	cv.set_lifted(true)
	_fly(cv, slot_pos(j, session.board.size(j) - 1) + Vector2(0, -PICK_RISE), 0.06, 0.0, false)
	Sfx.play("lift")
	Haptics.lift()
	lift_started.emit(j)


## Programmatic lift straight to the hover spot (tutorial replays and screenshots).
func lift(j: int) -> void:
	lifted_jar = j
	var cv := top_card(j)
	cv.set_lifted(true)
	_fly(cv, hover_pos(j), Style.T_LIFT, 0.0, false)
	Sfx.play("lift")
	Haptics.lift()
	lift_started.emit(j)


func cancel_lift() -> void:
	_pressing = false
	_end_drag()
	if lifted_jar < 0:
		return
	var j := lifted_jar
	lifted_jar = -1
	var cv := top_card(j)
	_fly(cv, slot_pos(j, session.board.size(j) - 1), 0.16, 0.0, true)
	lift_cancelled.emit()


func _start_drag() -> void:
	_dragging = true
	_fresh_pick = false
	_stop(top_card(lifted_jar))
	set_process(true)


func _end_drag() -> void:
	_dragging = false
	_set_hot(-1)
	set_process(false)


## Where the dragged card wants to be: centred on the finger, lifted clear of the fingertip.
func _drag_anchor() -> Vector2:
	var cs: Vector2 = layout["card_size"]
	return _finger - Vector2(cs.x / 2.0, cs.y / 2.0 + cs.y * FINGER_LIFT)


func _process(delta: float) -> void:
	if not _dragging or lifted_jar < 0:
		return
	var cv := top_card(lifted_jar)
	var before := cv.position
	var k := 1.0 - exp(-FOLLOW_RATE * delta)
	cv.position = before.lerp(_drag_anchor(), k)
	if not reduce_motion and delta > 0.0:
		# Lean into the direction of travel, like a card held by its top edge.
		var lean := clampf((cv.position.x - before.x) / delta * 0.00022, -0.14, 0.14)
		cv.rotation = lerpf(cv.rotation, lean, 1.0 - exp(-14.0 * delta))


## The jar under the dragged card's centre, else under the finger, else the nearest jar within reach.
func _drop_target() -> int:
	if lifted_jar < 0 or layout.is_empty():
		return -1
	var cv := top_card(lifted_jar)
	var centre := _drag_anchor() + cv.size / 2.0
	var j := jar_at(centre)
	if j < 0:
		j = jar_at(_finger)
	if j >= 0:
		return j
	var rects: Array[Rect2] = layout["jars"]
	var best := -1
	var best_d := rects[0].size.x * 0.8
	for i in rects.size():
		var d := rects[i].get_center().distance_to(centre)
		if d < best_d:
			best = i
			best_d = d
	return best


## Highlights the jar a drag would drop into. It means "this jar has room" (visible to anyone), never "this is
## the right group".
func _set_hot(j: int) -> void:
	if j == lifted_jar or (j >= 0 and (session.board.is_full(j) or session.board.is_closed(j))):
		j = -1
	if j == _hot:
		return
	if _hot >= 0 and _hot < fronts.size():
		fronts[_hot].hot = false
		fronts[_hot].queue_redraw()
	_hot = j
	if j >= 0:
		fronts[j].hot = true
		fronts[j].queue_redraw()


func _on_card(cv: CardView, pos: Vector2) -> bool:
	return cv != null and Rect2(cv.position, cv.size).grow(8.0).has_point(pos)


# --- results from Session ---------------------------------------------------------------------------------------

func show_move(events: Array) -> void:
	lifted_jar = -1
	var stagger := 0.0
	var lids: Array[Dictionary] = []
	for e: Dictionary in events:
		match e["type"]:
			"move":
				var cv: CardView = cards[e["card"]]
				var to: int = e["to"]
				var slot := session.board.jars[to].find(e["card"])
				cv.set_lifted(true)
				# From the hover spot the card arcs over; from a drag it is already above the jar, so it just drops in.
				var target := slot_pos(to, slot)
				var arc := 70.0 if cv.position.y > target.y - 40.0 or absf(cv.position.x - target.x) > 60.0 else 12.0
				var flight := Style.T_DROP + 0.04
				var tw := _fly(cv, target, flight, arc, true, stagger)
				tw.finished.connect(_squash.bind(cv))
				if stagger < 0.01:
					# The clink starts early by the audio latency so it lands with the card; it rises in pitch as the
					# jar fills, like water in a bottle.
					var fill := session.board.size(to)
					Sfx.play_at(flight, "drop", 1.0 + 0.05 * (fill - 1), 0.02)
					tw.finished.connect(Haptics.drop)
				stagger += 0.06
			"lid":
				lids.append(e)
			"uncork":
				for j in e["jars"]:
					fronts[j].corked = false
					fronts[j].queue_redraw()
					wobble(j, 0.6)
			"jar_added":
				pass
	refresh_cards(true)
	for e in lids:
		get_tree().create_timer(Style.T_DROP + stagger).timeout.connect(play_lid.bind(e["jar"], e["group"]))


## A card settles: a quick squash (1.06 x 0.94) that springs back, so a landing reads as weight.
func _squash(cv: CardView) -> void:
	if reduce_motion or not is_instance_valid(cv):
		return
	cv.scale = Vector2(1.06, 0.94)
	cv.create_tween().tween_property(cv, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_slip(from: int, to: int, card: int) -> void:
	lifted_jar = -1
	var cv: CardView = cards[card]
	_stop(cv)
	var start := cv.position
	var peak := hover_pos(to) + Vector2(0, 18)
	var tw := cv.create_tween()
	_flights[cv] = tw
	tw.tween_property(cv, "position", start.lerp(peak, 0.85), 0.09).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		Sfx.play("slip")
		Haptics.slip()
		wobble(to, 1.0)
		refresh_cards(true))
	tw.tween_property(cv, "position", start, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(cv, "position", slot_pos(from, session.board.size(from) - 1), 0.1)
	tw.finished.connect(func() -> void:
		_flights.erase(cv)
		cv.set_lifted(false))


## A drop the board already proves wrong: a quick "no" shake, then the card settles home. Costs nothing.
func show_refuse(from: int, card: int) -> void:
	lifted_jar = -1
	var cv: CardView = cards[card]
	_stop(cv)
	var x := cv.position.x
	var tw := cv.create_tween()
	_flights[cv] = tw
	for dx in [10.0, -8.0, 6.0, 0.0]:
		tw.tween_property(cv, "position:x", x + dx, 0.045)
	tw.tween_property(cv, "position", slot_pos(from, session.board.size(from) - 1), 0.1)
	tw.finished.connect(func() -> void:
		_flights.erase(cv)
		cv.set_lifted(false))
	Sfx.play("refuse")


func show_undo() -> void:
	lifted_jar = -1
	for c in cards:
		(cards[c] as CardView).set_lifted(false)
	sync(true)


func play_lid(j: int, g: int) -> void:
	var f := fronts[j]
	f.lid_label = session.level.groups[g]["label"]
	f.label_color = Style.tag_color(g)
	f.label_typed = 0.0
	# Lids in quick succession climb a semitone each (capped), so a cascade sounds like it's building.
	var now := Time.get_ticks_msec() / 1000.0
	_combo = mini(_combo + 1, 5) if now - _last_lid < 4.0 else 0
	_last_lid = now
	var pitch := pow(2.0, _combo / 12.0)
	var tw := _track(create_tween())
	tw.tween_interval(Style.T_LID_HOLD)
	tw.tween_callback(Sfx.play.bind("ratchet", pitch, 0.02, 0.0))
	tw.tween_method(_set_lid.bind(f), 0.0, 1.0, Style.T_LID)
	tw.tween_callback(func() -> void:
		Sfx.play("seat", pitch, 0.02)
		Haptics.lid())
	var chars := f.lid_label.length()
	tw.tween_method(_type_label.bind(f), 0, chars, maxf(0.15, chars * Style.T_TYPE_CHAR))
	tw.tween_method(_set_shine.bind(f), 0.0, 1.0, 0.0 if reduce_motion else 0.4)
	tw.tween_callback(func() -> void:
		f.shine_t = -1.0
		f.queue_redraw()
		lid_finished.emit(j))
	if not reduce_motion:
		hop(j, 0.0)


func _set_lid(v: float, f: JarView) -> void:
	f.lid_t = v
	f.queue_redraw()


func _type_label(n: int, f: JarView) -> void:
	var total := f.lid_label.length()
	var before := roundi(f.label_typed * total)
	f.label_typed = float(n) / maxf(total, 1)
	if n != before and n % 2 == 0 and f.lid_label[clampi(n - 1, 0, total - 1)] != " ":
		Sfx.play("type", 1.0, 0.08, -6.0)
	f.queue_redraw()


func _set_shine(v: float, f: JarView) -> void:
	f.shine_t = v
	f.queue_redraw()


## Little celebratory hop of one jar and its cards.
func hop(j: int, delay: float) -> void:
	if reduce_motion:
		return
	var tw := _track(create_tween())
	tw.tween_interval(delay)
	tw.tween_method(_apply_hop.bind(j), 0.0, 1.0, 0.32)


func _apply_hop(t: float, j: int) -> void:
	var dy := -sin(t * PI) * 16.0
	var base: Rect2 = layout["jars"][j]
	backs[j].position.y = base.position.y + dy
	fronts[j].position.y = base.position.y + dy
	var jar := session.board.jars[j]
	for k in jar.size():
		var cv: CardView = cards[jar[k]]
		if not _flights.has(cv):
			cv.position = slot_pos(j, k) + Vector2(0, dy)


func play_win() -> void:
	for j in session.board.jar_count():
		hop(j, 0.25 + j * 0.06)


func wobble(j: int, strength: float) -> void:
	if reduce_motion:
		return
	if _wobble.has(j):
		(_wobble[j] as Tween).kill()
	var d := Style.WOBBLE_DEG * strength
	var tw := create_tween()
	_wobble[j] = tw
	for a in [d, -d * 0.7, d * 0.35, 0.0]:
		tw.tween_method(_apply_angle.bind(j), _angle(j), a, 0.08)
	tw.finished.connect(func() -> void: _wobble.erase(j))


func _angle(j: int) -> float:
	return rad_to_deg(backs[j].rotation)


func _apply_angle(deg: float, j: int) -> void:
	var rad := deg_to_rad(deg)
	backs[j].rotation = rad
	fronts[j].rotation = rad
	var r: Rect2 = layout["jars"][j]
	var pivot := Vector2(r.get_center().x, r.end.y)
	var jar := session.board.jars[j]
	for k in jar.size():
		var cv: CardView = cards[jar[k]]
		if _flights.has(cv) or cv.lifted:
			continue
		# Cards turn about their own centre (pivot_offset), so rotate the centre around the jar's base.
		var centre := slot_pos(j, k) + cv.size / 2.0
		cv.position = pivot + (centre - pivot).rotated(rad) - cv.size / 2.0
		cv.rotation = rad


func set_glow_card(card: int) -> void:
	for c in cards:
		(cards[c] as CardView).set_glow(c == card)


# --- tweens ------------------------------------------------------------------------------------------------------

func _fly(cv: CardView, target: Vector2, dur: float, arc: float, settle: bool, delay: float = 0.0) -> Tween:
	_stop(cv)
	var from := cv.position
	var lean := cv.rotation
	var tw := cv.create_tween()
	_flights[cv] = tw
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(t: float) -> void:
		cv.position = _bezier(from, target, arc, t)
		cv.rotation = lean * (1.0 - t), 0.0, 1.0, dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void:
		_flights.erase(cv)
		if settle:
			cv.set_lifted(false))
	return tw


func _stop(cv: CardView) -> void:
	if _flights.has(cv):
		(_flights[cv] as Tween).kill()
		_flights.erase(cv)
	cv.modulate.a = 1.0


func _track(tw: Tween) -> Tween:
	_misc = _misc.filter(func(t: Tween) -> bool: return t.is_valid())
	_misc.append(tw)
	return tw


## Debug self-check: cards that aren't where the board says they should be (screenshot runs print this).
func misplaced() -> Array[String]:
	var out: Array[String] = []
	for j in session.board.jar_count():
		var jar := session.board.jars[j]
		for k in jar.size():
			var cv: CardView = cards[jar[k]]
			var lifted := j == lifted_jar and k == jar.size() - 1
			var target := hover_pos(j) if lifted else slot_pos(j, k)
			if cv.position.distance_to(target) > 1.0 or cv.lifted != lifted:
				out.append("%s jar%d slot%d at %s want %s lifted=%s flying=%s" % [
					cv.word, j, k, cv.position, target, cv.lifted, _flights.has(cv)])
	return out


static func _bezier(a: Vector2, b: Vector2, arc: float, t: float) -> Vector2:
	var ctrl := (a + b) / 2.0 + Vector2(0, -arc)
	return a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)


func _draw() -> void:
	if layout.is_empty():
		return
	# Wooden planks: the jars stand on the lit top surface; the plank's shadow falls on the wall below.
	for s: Rect2 in layout["shelves"]:
		var plank := Rect2(s.position.x, s.position.y - 6.0, s.size.x, s.size.y + 26.0)
		draw_texture_rect(Art.tex("plank", plank.size, Materials.plank), plank, false)
