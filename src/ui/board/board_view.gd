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

const DRAG_START := 16.0

var session: Session
var layout: Dictionary = {}
var cards: Dictionary = {} # card id -> CardView
var backs: Array[JarView] = []
var fronts: Array[JarView] = []
var lifted_jar := -1
var peek_mode := false
var reduce_motion := false
var _dragging := false
var _press_pos := Vector2.ZERO
var _drag_offset := Vector2.ZERO
var _flights := {} # CardView -> Tween
var _wobble := {} # jar -> Tween
var _misc: Array[Tween] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


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


func add_jar() -> void:
	_add_jar_nodes()
	relayout()


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
	for c in cards:
		var cv: CardView = cards[c]
		cv.size = layout["card_size"]
		cv.font_size = layout["font"]
	refresh_jars()
	refresh_cards(false)
	sync(false)
	queue_redraw()


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
			var lifted := j == lifted_jar and k == jar.size() - 1
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

func _gui_input(event: InputEvent) -> void:
	if session == null or session.is_over():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_press(event.position)
		else:
			_on_release(event.position)
		accept_event()
	elif event is InputEventMouseMotion and lifted_jar >= 0 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if not _dragging and event.position.distance_to(_press_pos) > DRAG_START:
			_dragging = true
		if _dragging:
			var cv := top_card(lifted_jar)
			_stop(cv)
			cv.position = event.position - _drag_offset
		accept_event()


func _on_press(pos: Vector2) -> void:
	_press_pos = pos
	_dragging = false
	if peek_mode:
		var c := card_at(pos)
		if c >= 0:
			peek_picked.emit(c)
		return
	var j := jar_at(pos)
	if lifted_jar >= 0:
		if j < 0 or j == lifted_jar:
			cancel_lift()
		else:
			drop_requested.emit(lifted_jar, j)
		return
	if j < 0 or not session.board.can_take(j):
		if j >= 0:
			wobble(j, 0.5)
		return
	var hit := card_at(pos)
	lift(j)
	if hit >= 0 and hit != session.board.top(j):
		(cards[hit] as CardView).nudge()
		buried_tapped.emit(hit)
	_drag_offset = pos - hover_pos(j)


func _on_release(pos: Vector2) -> void:
	if lifted_jar < 0 or not _dragging:
		_dragging = false
		return
	_dragging = false
	var j := jar_at(pos)
	if j >= 0 and j != lifted_jar:
		drop_requested.emit(lifted_jar, j)
	elif j == lifted_jar:
		_fly(top_card(j), hover_pos(j), 0.1, 0.0, false)
	else:
		cancel_lift()


func lift(j: int) -> void:
	lifted_jar = j
	var cv := top_card(j)
	cv.set_lifted(true)
	_fly(cv, hover_pos(j), Style.T_LIFT, 0.0, false)
	Sfx.play("lift")
	Haptics.lift()
	lift_started.emit(j)


func cancel_lift() -> void:
	if lifted_jar < 0:
		return
	var j := lifted_jar
	lifted_jar = -1
	var cv := top_card(j)
	_fly(cv, slot_pos(j, session.board.size(j) - 1), 0.1, 0.0, true)
	lift_cancelled.emit()


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
				var tw := _fly(cv, slot_pos(to, slot), Style.T_DROP + 0.04, 70.0, true, stagger)
				stagger += 0.06
				if stagger <= 0.07:
					tw.finished.connect(_landed.bind(to))
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


func _landed(to: int) -> void:
	Sfx.play("drop", 1.0, 0.04)
	Haptics.drop()


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
	Sfx.play("lid")
	var tw := _track(create_tween())
	tw.tween_method(_set_lid.bind(f), 0.0, 1.0, Style.T_LID)
	tw.tween_callback(Haptics.lid)
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
		cv.position = pivot + (slot_pos(j, k) - pivot).rotated(rad)
		cv.rotation = rad


func set_glow_card(card: int) -> void:
	for c in cards:
		(cards[c] as CardView).set_glow(c == card)


# --- tweens ------------------------------------------------------------------------------------------------------

func _fly(cv: CardView, target: Vector2, dur: float, arc: float, settle: bool, delay: float = 0.0) -> Tween:
	_stop(cv)
	cv.rotation = 0.0
	var from := cv.position
	var tw := cv.create_tween()
	_flights[cv] = tw
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(t: float) -> void: cv.position = _bezier(from, target, arc, t), 0.0, 1.0, dur) \
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
	for s: Rect2 in layout["shelves"]:
		draw_style_box(Style.box(Style.WOOD, 6), s)
		draw_rect(Rect2(s.position.x + 6, s.end.y - 4, s.size.x - 12, 4), Style.WOOD_DARK)
