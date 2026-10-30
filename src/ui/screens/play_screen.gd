## One level in play: HUD (pause, title, slip meter), label rail, the board, and the thumb bar (Undo, Peek, +Jar,
## Tidy up). Turns Session results into animation, captions and sound.
class_name PlayScreen
extends Control

signal finished(won: bool, stats: Dictionary)
signal pause_requested
signal skip_requested

const TOP_BAR := 96.0
const BAR_H := 122.0

var level_id := ""
## Features taught by this level (Catalog.features_at) and the ones it introduces.
var features: Dictionary = {}
var introduces: PackedStringArray = []
var session: Session
var board: BoardView
var rail: LabelRail
var meter: SlipMeter
var title_label: Label
var pause_btn: RoundButton
var undo_btn: RoundButton
var peek_btn: RoundButton
var jar_btn: RoundButton
var tidy_btn: RoundButton
var skip_btn: PillButton
var caption: Caption
var hand: HandPointer
var peeks_left := 1
var jars_left := 1
var hide_rail := false
var _started_ms := 0
var _done := false
var _tidying := false
var _idle := 0.0
var _hint_shown := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_btn = RoundButton.new("pause")
	pause_btn.pressed.connect(func() -> void: pause_requested.emit())
	add_child(pause_btn)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", Style.typed())
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Style.INK)
	add_child(title_label)
	meter = SlipMeter.new()
	add_child(meter)
	rail = LabelRail.new()
	add_child(rail)
	board = BoardView.new()
	board.drop_requested.connect(_on_drop)
	board.buried_tapped.connect(func(_c: int) -> void: _caption_once("buried", "Only the top card moves"))
	board.peek_picked.connect(_on_peek_picked)
	board.lift_started.connect(func(_j: int) -> void: _stop_hint())
	add_child(board)
	undo_btn = _bar_button("undo", "Undo", _on_undo)
	peek_btn = _bar_button("peek", "Peek", _on_peek)
	jar_btn = _bar_button("jar_plus", "+Jar", _on_add_jar)
	tidy_btn = _bar_button("tidy", "Tidy up", _on_tidy)
	caption = Caption.new()
	add_child(caption)
	skip_btn = PillButton.new("Skip", false, 72.0)
	skip_btn.font_size = 26
	skip_btn.visible = false
	skip_btn.pressed.connect(func() -> void: skip_requested.emit())
	add_child(skip_btn)
	hand = HandPointer.new()
	add_child(hand)


func _bar_button(icon: String, text: String, action: Callable) -> RoundButton:
	var b := RoundButton.new(icon, text)
	b.pressed.connect(action)
	add_child(b)
	return b


func start(id: String, s: Session, bonus_peeks: int = 0) -> void:
	level_id = id
	features = Levels.catalog.features_at(id)
	introduces = Levels.catalog.entry(id).get("introduces", PackedStringArray())
	session = s
	peeks_left = 1 + bonus_peeks
	jars_left = 1
	_done = false
	_tidying = false
	_idle = 0.0
	_hint_shown = false
	hand.stop()
	caption.modulate.a = 0.0
	for b in [undo_btn, peek_btn, jar_btn, tidy_btn]:
		b.set_pulse(false)
	# The thumb-bar buttons appear as the levels that teach them are reached.
	undo_btn.visible = features.has("undo")
	jar_btn.visible = features.has("jar")
	peek_btn.visible = features.has("peek")
	tidy_btn.visible = false
	hide_rail = not features.has("slip")
	rail.visible = not hide_rail
	title_label.text = Levels.title(id)
	board.reduce_motion = bool(Save.setting("reduce_motion"))
	board.setup(s)
	rail.setup(s)
	_layout()
	_started_ms = Time.get_ticks_msec()
	_refresh()
	_intro_captions()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and session != null:
		_layout()


func _layout() -> void:
	var w := size.x
	var h := size.y
	var ins := SafeArea.current(size)
	var top: float = ins["top"] + 10.0
	var content_w := minf(w - 32.0, 720.0)
	var left := (w - content_w) / 2.0
	pause_btn.position = Vector2(left, top)
	pause_btn.size = pause_btn.custom_minimum_size
	var meter_w := maxf(110.0, session.budget * 38.0 + 8.0) if session.budget > 0 else 140.0
	meter.position = Vector2(left + content_w - meter_w, top)
	meter.size = Vector2(meter_w, RoundButton.D)
	skip_btn.size = Vector2(130, 72)
	skip_btn.position = Vector2(left + content_w - 130, top + (RoundButton.D - 72) / 2.0)
	title_label.position = Vector2(left + 110, top)
	title_label.size = Vector2(content_w - 110 - maxf(110.0, meter_w) - 10, RoundButton.D)
	var rail_h := 0.0 if hide_rail else LabelRail.height_for(session.level.group_count())
	rail.position = Vector2(left, top + TOP_BAR + 6)
	rail.size = Vector2(content_w, rail_h)
	var board_top := rail.position.y + rail_h + 14.0
	var bar_y: float = h - ins["bottom"] - BAR_H - 10.0
	var buttons := [undo_btn, peek_btn, jar_btn, tidy_btn]
	var shown := buttons.filter(func(b: RoundButton) -> bool: return b.visible)
	var spacing := minf(150.0, content_w / maxf(shown.size(), 1))
	var x0 := w / 2.0 - spacing * (shown.size() - 1) / 2.0
	for i in shown.size():
		var b: RoundButton = shown[i]
		b.size = Vector2(130, BAR_H)
		b.custom_minimum_size = Vector2(130, BAR_H)
		b.position = Vector2(x0 + i * spacing - 65, bar_y)
	board.position = Vector2(0, board_top)
	board.size = Vector2(w, bar_y - 8.0 - board_top)
	caption.position = Vector2(0, board_top - 4)
	caption.size = Vector2(w, 64)


func _process(delta: float) -> void:
	if session == null or _done or session.level.tutorial not in ["move", "empty"]:
		return
	_idle += delta
	if not _hint_shown and _idle > (0.6 if session.moves == 0 else 3.0):
		_show_hint()


## Tutorial hand: shows the solver's next move.
func _show_hint() -> void:
	var res := Solver.solve(session.board, 5000)
	if not res["solved"] or (res["path"] as Array).is_empty():
		return
	var mv: Vector2i = res["path"][0]
	_hint_shown = true
	board.set_glow_card(session.board.top(mv.x))
	# Fingertip at the card's lower-right, so the word itself stays readable.
	var cs: Vector2 = board.layout["card_size"]
	var top_slot := session.board.size(mv.x) - 1
	var a := board.position + board.slot_pos(mv.x, top_slot) + Vector2(cs.x * 0.82, cs.y * 0.8)
	var b := board.position + (board.layout["jars"][mv.y] as Rect2).get_center() + Vector2(cs.x * 0.3, 0)
	hand.show_path(a, b)


func _stop_hint() -> void:
	_idle = 0.0
	if _hint_shown:
		_hint_shown = false
		hand.stop()
		board.set_glow_card(-1)


## The one short line a level opens with: what this level introduces, if anything.
func _intro_captions() -> void:
	match session.level.tutorial:
		"empty":
			caption.say("Empty jars take any card", 3.0)
		"rail":
			caption.say("Not sure? Try a drop", 3.0)
	for f in introduces:
		match f:
			"undo":
				_teach(undo_btn, "Undo is free")
			"jar":
				_teach(jar_btn, "Stuck? Add a jar")
			"peek":
				_teach(peek_btn, "Peek shows a card's group")
			"four":
				caption.say("Four groups now", 3.0)
			"herrings":
				caption.say("Some words fit two", 3.0)
	if session.has_budget() and not Save.data["seen_captions"].has("budget"):
		_caption_once("budget", "%d slips allowed" % session.budget)


func _teach(button: RoundButton, text: String) -> void:
	button.set_pulse(true)
	caption.say(text, 3.0)
	get_tree().create_timer(3.5).timeout.connect(button.set_pulse.bind(false))


func _caption_once(key: String, text: String) -> void:
	var seen: Dictionary = Save.data["seen_captions"]
	if seen.has(key):
		return
	seen[key] = true
	Save.write()
	caption.say(text)


# --- actions -------------------------------------------------------------------------------------------------------

func _on_drop(from: int, to: int) -> void:
	_stop_hint()
	var card := session.board.top(from)
	var r := session.try_move(from, to)
	match r["result"]:
		Session.Result.MOVED:
			board.show_move(r["events"])
			if session.board.size(to) == 1 and session.board.label_group[to] < 0:
				_caption_once("empty", "Empty jars take any card")
		Session.Result.SLIP:
			board.show_slip(from, to, card)
			if session.level.also.has(card):
				_caption_once("herring", "Fits both? Not here")
			else:
				_caption_once("slip", "Not the same group")
		Session.Result.REFUSE_PROVEN:
			board.show_refuse(from, card)
			_caption_once("refuse", "Already ruled out: free")
		Session.Result.REFUSE_FULL, Session.Result.REFUSE_CLOSED:
			board.wobble(to, 0.6)
			board.cancel_lift()
		_:
			board.cancel_lift()
	_after(r["events"])


func _after(events: Array) -> void:
	var lid_delay := 0.0
	for e: Dictionary in events:
		match e["type"]:
			"step":
				rail.pulse(e["group"])
				Sfx.play("tag", 1.0, 0.05, -3.0)
				if session.know.paired_once[e["group"]] == 1 and session.know.step[e["group"]] == 1:
					_caption_once("pair", "A pair! Label hint above")
			"lid":
				lid_delay = Style.T_DROP + Style.T_LID + 0.6
				get_tree().create_timer(Style.T_DROP + Style.T_LID).timeout.connect(rail.queue_redraw)
			"lost":
				_done = true
				get_tree().create_timer(0.8).timeout.connect(_finish.bind(false))
			"won":
				_done = true
				get_tree().create_timer(lid_delay + 0.6).timeout.connect(_win_flourish)
	_refresh()


func _refresh() -> void:
	undo_btn.enabled = session.can_undo()
	peek_btn.badge = str(peeks_left)
	peek_btn.enabled = peeks_left > 0 and not session.is_over()
	jar_btn.badge = str(jars_left)
	jar_btn.enabled = jars_left > 0 and not session.is_over() and session.board.jar_count() < 9
	var tidy := session.all_known() and not _tidying and features.has("undo")
	if tidy != tidy_btn.visible:
		tidy_btn.visible = tidy
		tidy_btn.set_pulse(tidy)
		_layout()
	meter.visible = session.budget > 0 or session.rules["mode"] == "stars"
	meter.set_state(session.budget, session.slips, session.rules["mode"] == "stars")
	rail.queue_redraw()
	for b in [undo_btn, peek_btn, jar_btn, tidy_btn]:
		b.queue_redraw()
	var stuck := session.is_stuck()
	undo_btn.set_pulse(stuck and session.can_undo())
	jar_btn.set_pulse(stuck and jars_left > 0)
	if stuck:
		caption.say("No safe moves: Undo or +Jar")


func _on_undo() -> void:
	board.cancel_lift()
	if not session.undo().is_empty():
		board.show_undo()
	_refresh()


func _on_peek() -> void:
	if board.peek_mode:
		board.peek_mode = false
		peek_btn.set_pulse(false)
		return
	board.cancel_lift()
	board.peek_mode = true
	peek_btn.set_pulse(true)
	caption.say("Tap a card to peek")


func _on_peek_picked(card: int) -> void:
	var ev := session.peek(card)
	if ev.is_empty():
		caption.say("Pick a card without a tag")
		return
	peeks_left -= 1
	board.peek_mode = false
	peek_btn.set_pulse(false)
	board.refresh_cards(true)
	_after(ev)


func _on_add_jar() -> void:
	board.cancel_lift()
	session.add_jar()
	jars_left -= 1
	board.add_jar()
	_refresh()


func _on_tidy() -> void:
	var res := Solver.solve(session.board, 50000)
	if not res["solved"]:
		return
	_tidying = true
	board.cancel_lift()
	tidy_btn.visible = false
	_layout()
	_play_path(res["path"], 0)


func _play_path(path: Array, i: int) -> void:
	if i >= path.size() or session.is_over():
		return
	var mv: Vector2i = path[i]
	var r := session.try_move(mv.x, mv.y)
	board.show_move(r["events"])
	_after(r["events"])
	get_tree().create_timer(0.16).timeout.connect(_play_path.bind(path, i + 1))


func _win_flourish() -> void:
	board.play_win()
	Sfx.play("win", 1.0, 0.0)
	Haptics.win()
	get_tree().create_timer(0.9).timeout.connect(_finish.bind(true))


func _finish(won: bool) -> void:
	finished.emit(won, stats(won))


func stats(won: bool) -> Dictionary:
	return {
		"level": session.level.id, "won": won, "slips": session.slips,
		"budget": session.budget, "moves": session.moves, "undos": session.undos, "peeks": session.peeks,
		"jars_added": session.jars_added, "continues": session.continues, "tidy": _tidying,
		"secs": snappedf((Time.get_ticks_msec() - _started_ms) / 1000.0, 0.1),
		"slip_pairs": session.slip_log, "rules": session.rules.duplicate(),
		"at": Time.get_datetime_string_from_system(),
	}


## After a Continue (+2 slips), play resumes on the same board.
func resume_after_continue() -> void:
	_done = false
	_refresh()


## Back: put down a lifted card or leave peek mode. Returns true if it did something.
func on_back() -> bool:
	if board.peek_mode:
		_on_peek()
		return true
	if board.lifted_jar >= 0:
		board.cancel_lift()
		return true
	return false


## Tutorial boards swap the slip meter for a visible Skip.
func set_tutorial(on: bool) -> void:
	skip_btn.visible = on
	if on:
		meter.visible = false
