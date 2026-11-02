## One level in play: HUD (pause, title with the slip meter under it, coins), label rail, the board, and the thumb
## bar (Undo, Hint, +Jar, Complete, Tidy up). Turns Session results into animation, captions and sound.
## Hints are worked out on a worker thread (Advisor) and charged only when one is shown on an unchanged board.
class_name PlayScreen
extends Control

signal finished(won: bool, stats: Dictionary)
signal pause_requested
signal skip_requested
signal shop_requested
## The player can't pay for a booster ("hint" or "complete"): main offers an ad (Hint only) or the Shop.
signal need_coins(item: String)


## The attempt changed (for the resume save).
signal progress_changed

const TOP_BAR := 96.0
const BAR_H := 122.0
const HINT_BUDGET_MS := 150

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
var coins: CoinPill
var undo_btn: RoundButton
var hint_btn: RoundButton
var jar_btn: RoundButton
var complete_btn: RoundButton
var tidy_btn: RoundButton
var skip_btn: PillButton
var caption: Caption
var hand: HandPointer
## Free Hints for this attempt only (the assist after two fails); used before the inventory and coins.
var free_hints := 0
var jars_left := 1
var hide_rail := false
## Complete is waiting for a label to be tapped.
var choosing := false
var _dim: ColorRect
var _choice: _ChoiceBar
var _started_ms := 0
var _done := false
var _tidying := false
var _idle := 0.0
var _hint_shown := false
## Hint worker: task id (-1 = none), cancel flag shared with the solver, and a token so stale results are dropped.
var _hint_task := -1
var _hint_cancel: Array = [false]
var _hint_token := 0
var _hint_result := {}
## A solver path the player is following: the rest of it, and the board key expected before its next step.
var _hint_path: Array = []
var _hint_expect := ""


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_btn = RoundButton.new("pause")
	pause_btn.pressed.connect(func() -> void: pause_requested.emit())
	add_child(pause_btn)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", Style.sans_heavy())
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Style.INK)
	add_child(title_label)
	meter = SlipMeter.new()
	add_child(meter)
	coins = CoinPill.new()
	coins.pressed.connect(func() -> void: shop_requested.emit())
	add_child(coins)
	rail = LabelRail.new()
	add_child(rail)
	board = BoardView.new()
	board.drop_requested.connect(_on_drop)
	board.buried_tapped.connect(func(_c: int) -> void: _caption_once("buried", "Only the top card moves"))
	board.lift_started.connect(func(_j: int) -> void: _stop_hint())
	add_child(board)
	undo_btn = _bar_button("undo", "Undo", _on_undo)
	hint_btn = _bar_button("hint", "Hint", _on_hint)
	jar_btn = _bar_button("jar_plus", "+Jar", _on_add_jar)
	complete_btn = _bar_button("complete", "Complete", _on_complete)
	tidy_btn = _bar_button("tidy", "Tidy up", _on_tidy)
	caption = Caption.new()
	add_child(caption)
	skip_btn = PillButton.new("Skip", false, 72.0)
	skip_btn.font_size = 26
	skip_btn.custom_minimum_size = Vector2(130, 72)
	skip_btn.visible = false
	skip_btn.pressed.connect(func() -> void: skip_requested.emit())
	add_child(skip_btn)
	_dim = ColorRect.new()
	_dim.color = Color(Style.PAPER, 0.62)
	_dim.visible = false
	_dim.z_index = 10  # above the board's cards and jar fronts (z 1-6)
	_dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and not e.pressed:
			cancel_complete())
	add_child(_dim)
	_choice = _ChoiceBar.new()
	_choice.visible = false
	_choice.z_index = 11
	_choice.cancelled.connect(cancel_complete)
	_choice.confirmed.connect(func() -> void: do_complete(rail.selected))
	add_child(_choice)
	rail.tag_picked.connect(_on_tag_picked)
	hand = HandPointer.new()
	add_child(hand)


func _ready() -> void:
	Wallet.changed.connect(func() -> void:
		coins.set_value(Wallet.coins())
		if session != null:
			_refresh())


func _bar_button(icon: String, text: String, action: Callable) -> RoundButton:
	var b := RoundButton.new(icon, text)
	b.pressed.connect(action)
	add_child(b)
	return b


func start(id: String, s: Session, bonus_hints: int = 0) -> void:
	_cancel_hint_task()
	level_id = id
	features = Levels.catalog.features_at(id)
	introduces = Levels.catalog.entry(id).get("introduces", PackedStringArray())
	session = s
	free_hints = bonus_hints
	jars_left = 1 - s.jars_added
	_done = false
	_tidying = false
	_idle = 0.0
	_hint_shown = false
	_hint_path = []
	_hint_expect = ""
	hand.stop()
	caption.modulate.a = 0.0
	board.input_locked = false
	for b in [undo_btn, hint_btn, jar_btn, complete_btn, tidy_btn]:
		b.set_pulse(false)
	# The thumb-bar buttons appear as the levels that teach them are reached.
	undo_btn.visible = features.has("undo")
	jar_btn.visible = features.has("jar")
	hint_btn.visible = features.has("hint")
	complete_btn.visible = features.has("complete")
	tidy_btn.visible = false
	coins.visible = features.has("hint") or Wallet.coins() > 0
	coins.hold = false
	coins.set_value(Wallet.coins(), false)
	hide_rail = not features.has("slip")
	rail.visible = not hide_rail
	title_label.text = Levels.title(id)
	board.reduce_motion = bool(Save.setting("reduce_motion"))
	board.setup(s)
	rail.setup(s)
	_layout()
	board.deal_in()
	_started_ms = Time.get_ticks_msec()
	_refresh()
	_intro_captions()


func _exit_tree() -> void:
	_cancel_hint_task()


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
	var coin_w := coins.wanted_width()
	coins.size = Vector2(coin_w, CoinPill.H)
	coins.position = Vector2(left + content_w - coin_w, top + (RoundButton.D - CoinPill.H) / 2.0)
	skip_btn.size = Vector2(130, 72)
	skip_btn.position = Vector2(left + content_w - 130, top + (RoundButton.D - 72) / 2.0)
	# Title on the upper half of the top row, the slip meter on the lower half, between pause and coins.
	var mid_x := left + 100.0
	var mid_w := content_w - 100.0 - coin_w - 12.0
	var with_meter := meter.visible
	title_label.position = Vector2(mid_x, top + (0.0 if with_meter else 0.0))
	title_label.size = Vector2(mid_w, RoundButton.D * (0.5 if with_meter else 1.0))
	meter.position = Vector2(mid_x, top + RoundButton.D * 0.48)
	meter.size = Vector2(mid_w, RoundButton.D * 0.52)
	var rail_h := 0.0 if hide_rail else LabelRail.height_for(session.level.group_count())
	rail.position = Vector2(left, top + TOP_BAR + 6)
	rail.size = Vector2(content_w, rail_h)
	var board_top := rail.position.y + rail_h + 14.0
	var bar_y: float = h - ins["bottom"] - BAR_H - 10.0
	var buttons := [undo_btn, hint_btn, jar_btn, complete_btn, tidy_btn]
	var shown := buttons.filter(func(b: RoundButton) -> bool: return b.visible)
	var spacing := minf(150.0, content_w / maxf(shown.size(), 1))
	var bw := minf(130.0, spacing)
	var x0 := w / 2.0 - spacing * (shown.size() - 1) / 2.0
	for i in shown.size():
		var b: RoundButton = shown[i]
		b.size = Vector2(bw, BAR_H)
		b.custom_minimum_size = Vector2(bw, BAR_H)
		b.position = Vector2(x0 + i * spacing - bw / 2.0, bar_y)
	board.position = Vector2(0, board_top)
	board.size = Vector2(w, bar_y - 8.0 - board_top)
	caption.position = Vector2(0, board_top - 4)
	_dim.position = board.position
	_dim.size = board.size + Vector2(0, BAR_H + 30.0)
	_choice.size = Vector2(content_w, 170.0)
	_choice.position = Vector2(left, h - ins["bottom"] - 180.0)
	caption.size = Vector2(w, 64)


func _process(delta: float) -> void:
	if session == null or _done or session.level.tutorial not in ["move", "empty"]:
		return
	_idle += delta
	if not _hint_shown and _idle > (0.6 if session.moves == 0 else 3.0):
		_show_tutorial_hand()


## Tutorial hand: shows the solver's next move (tutorial boards are tiny, so this runs inline).
func _show_tutorial_hand() -> void:
	var res := Solver.solve(session.board, 5000)
	if not res["solved"] or (res["path"] as Array).is_empty():
		return
	_point(res["path"][0])


## Glows the card to move and runs the hand from it to the slot it lands in. The fingertip touches the card's right
## edge, so the hand hangs over the jar wall and the gap beside it rather than the words of the cards below.
func _point(mv: Vector2i) -> void:
	_hint_shown = true
	board.set_glow_card(session.board.top(mv.x))
	var cs: Vector2 = board.layout["card_size"]
	var top_slot := session.board.size(mv.x) - 1
	var a := board.position + board.slot_pos(mv.x, top_slot) + Vector2(cs.x * 0.96, cs.y * 0.62)
	var b := board.position + board.slot_pos(mv.y, session.board.size(mv.y)) + Vector2(cs.x * 0.96, cs.y * 0.62)
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
		"move":
			caption.say("Tap a jar, then another", 6.0)
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
			"hint":
				var g := Wallet.intro_gift("hint")
				_teach(hint_btn, "Hints show a good move" + (": %d free" % g["hint"] if g.has("hint") else ""))
			"complete":
				var g := Wallet.intro_gift("complete")
				_teach(complete_btn, "Complete fills one jar for you" + (": 1 free" if g.has("complete") else ""))
			"four":
				caption.say("Four groups now", 3.0)
			"five":
				caption.say("Five groups now", 3.0)
			"six":
				caption.say("Six groups now", 3.0)
			"herrings", "double":
				caption.say("Some words fit two", 3.0)
			"lateral":
				caption.say("Some labels join words", 3.0)
			"abstract":
				caption.say("Some labels are ideas", 3.0)
			"wordplay":
				caption.say("Some labels play with words", 3.5)
			"frost":
				caption.say("Frosted cards clear on top", 3.5)
			"labelled":
				caption.say("A labelled jar takes one group", 3.5)
			"corked":
				caption.say("Corks pop when a lid goes on", 3.5)
	if session.has_budget() and not Save.data["seen_captions"].has("budget"):
		_caption_once("budget", "%d slips allowed" % session.budget)


func _teach(button: RoundButton, text: String) -> void:
	button.set_pulse(true)
	caption.say(text, 3.5)
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
	# A slip's letters are written in pencil (the sound turns the mistake positive); a pair's hint chimes.
	var from_slip := events.any(func(e: Dictionary) -> bool: return e["type"] == "slip")
	for e: Dictionary in events:
		match e["type"]:
			"step":
				rail.pulse(e["group"])
				if from_slip:
					Sfx.play_at(0.18, "write", 1.0, 0.05)
				else:
					Sfx.play("chime", 1.0, 0.03)
				if session.know.paired_once[e["group"]] == 1 and session.know.step[e["group"]] == 1:
					_caption_once("pair", "A pair! Label hint above")
			"lid":
				lid_delay = Style.T_DROP + Style.T_LID + 0.6
				get_tree().create_timer(Style.T_DROP + Style.T_LID).timeout.connect(rail.queue_redraw)
			"seal":
				lid_delay = maxf(lid_delay, 1.1)
			"lost":
				_done = true
				get_tree().create_timer(0.8).timeout.connect(_finish.bind(false))
			"won":
				_done = true
				get_tree().create_timer(lid_delay + 0.6).timeout.connect(_win_flourish)
	_refresh()
	progress_changed.emit()


func _refresh() -> void:
	undo_btn.enabled = session.can_undo()
	_price_badge(hint_btn, "hint", free_hints)
	hint_btn.enabled = not session.is_over() and _hint_task < 0
	jar_btn.badge = str(jars_left)
	jar_btn.badge_coin = false
	jar_btn.enabled = jars_left > 0 and not session.is_over() and session.board.jar_count() < 9
	_price_badge(complete_btn, "complete", 0)
	complete_btn.enabled = not session.is_over() and _unsolved().size() > 0
	var tidy := session.all_known() and not _tidying and features.has("undo")
	if tidy != tidy_btn.visible:
		tidy_btn.visible = tidy
		tidy_btn.set_pulse(tidy)
		_layout()
	var meter_was := meter.visible
	meter.visible = session.budget > 0 or session.rules["mode"] == "stars"
	if meter.visible != meter_was:
		_layout()
	meter.set_state(session.budget, session.slips, session.rules["mode"] == "stars")
	rail.queue_redraw()
	for b in [undo_btn, hint_btn, jar_btn, complete_btn, tidy_btn]:
		b.queue_redraw()
	var stuck := session.is_stuck()
	undo_btn.set_pulse(stuck and session.can_undo())
	jar_btn.set_pulse(stuck and jars_left > 0)
	if stuck:
		caption.say("No safe moves: Undo or +Jar")


## A booster's badge: how many you hold (free + inventory), else its price with a coin.
func _price_badge(b: RoundButton, item: String, free: int) -> void:
	var held := free + Wallet.count(item)
	b.badge_coin = held == 0
	b.badge = str(held) if held > 0 else str(Economy.PRICES[item])


func _on_undo() -> void:
	board.cancel_lift()
	if not session.undo().is_empty():
		board.show_undo()
	_refresh()
	progress_changed.emit()


func _on_add_jar() -> void:
	board.cancel_lift()
	session.add_jar()
	jars_left -= 1
	board.add_jar()
	_refresh()
	progress_changed.emit()


# --- Hint ----------------------------------------------------------------------------------------------------------

func _on_hint() -> void:
	if session.is_over() or _hint_task >= 0:
		return
	board.cancel_lift()
	if free_hints == 0 and not Wallet.can_afford("hint"):
		need_coins.emit("hint")
		return
	var key := Advisor.board_key(session.board)
	# Following a solver path: its next step is still right, no search needed.
	if _hint_expect == key and not _hint_path.is_empty():
		_show_hint_move(_hint_path[0], _hint_path.slice(1), "solver")
		return
	_hint_token += 1
	_hint_cancel = [false]
	_hint_result = {}
	var token := _hint_token
	var copy := session.board.copy()
	var cancel := _hint_cancel
	hint_btn.set_pulse(true)
	_hint_task = WorkerThreadPool.add_task(func() -> void:
		var res := Advisor.next_move(copy, HINT_BUDGET_MS, cancel)
		res["key"] = Advisor.board_key(copy)
		_hint_done.call_deferred(token, res))
	_refresh()


func _hint_done(token: int, res: Dictionary) -> void:
	if _hint_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_hint_task)
		_hint_task = -1
	hint_btn.set_pulse(false)
	if token != _hint_token or session == null or session.is_over() or res["key"] != Advisor.board_key(session.board):
		_refresh()
		return
	if res["kind"] == "none":
		# No move leads anywhere from here: point at Undo, and charge nothing.
		caption.say("Undo a few moves first")
		undo_btn.set_pulse(true)
		_refresh()
		return
	var path: Array = res["path"]
	_show_hint_move(res["move"], path.slice(1) if res["kind"] == "solver" else [], res["kind"])


## Charges the hint (free hints, then inventory, then coins), tags the card and points at the move.
func _show_hint_move(mv: Vector2i, rest: Array, kind: String) -> void:
	if free_hints > 0:
		free_hints -= 1
	elif not Wallet.spend("hint"):
		need_coins.emit("hint")
		return
	var card := session.board.top(mv.x)
	var ev := session.hint(card)
	board.refresh_cards(true)
	Sfx.play("chime", 1.2, 0.02)
	_point(mv)
	# Remember the rest of a solver path, keyed by the board after this move, so the next hint is instant.
	_hint_path = rest
	_hint_expect = ""
	if kind == "solver" and not rest.is_empty():
		var after := session.board.copy()
		after.move(mv.x, mv.y)
		after.check_lid(mv.y)
		_hint_expect = Advisor.board_key(after)
	_after(ev)


## Watched an ad for a free hint (main calls this after a rewarded ad).
func grant_free_hint() -> void:
	free_hints += 1
	_refresh()
	_on_hint()


func _cancel_hint_task() -> void:
	_hint_token += 1
	if _hint_task >= 0:
		_hint_cancel[0] = true
		WorkerThreadPool.wait_for_task_completion(_hint_task)
		_hint_task = -1


# --- Complete ------------------------------------------------------------------------------------------------------

## Groups not yet lidded or sealed (what the Complete picker offers).
func _unsolved() -> Array[int]:
	var out: Array[int] = []
	for g in session.level.group_count():
		if not session.board.is_solved(g):
			out.append(g)
	return out


## Complete: the board dims, the unsolved tags on the rail glow and can be tapped, and a bar at the bottom confirms
## the choice and its price. Cancel, Back or a tap on the dimmed board spends nothing.
func _on_complete() -> void:
	if session.is_over() or _unsolved().is_empty() or choosing:
		return
	board.cancel_lift()
	_stop_hint()
	if not Wallet.can_afford("complete"):
		need_coins.emit("complete")
		return
	choosing = true
	board.input_locked = true
	rail.set_choosing(true)
	_dim.show()
	_choice.open(Wallet.count("complete") > 0)
	caption.modulate.a = 0.0
	_layout()


func _on_tag_picked(_g: int) -> void:
	_choice.ready_to_finish()


## Closed without choosing: nothing was spent.
func cancel_complete() -> void:
	choosing = false
	board.input_locked = false
	rail.set_choosing(false)
	_dim.hide()
	_choice.hide()


## Seals group g: charges Complete (inventory first, then coins), then the cards fly up into the label.
func do_complete(g: int) -> void:
	cancel_complete()
	if g < 0 or session.is_over() or session.board.is_solved(g) or not Wallet.spend("complete"):
		_refresh()
		return
	_hint_path = []
	_hint_expect = ""
	var ev := session.complete(g)
	var target := rail.position + rail.tag_center(g) - board.position
	board.show_seal(ev, target)
	get_tree().create_timer(0.75).timeout.connect(func() -> void:
		rail.pulse(g)
		rail.queue_redraw())
	_after(ev)


# --- Tidy up -------------------------------------------------------------------------------------------------------

## Tidy up: the path is found on a worker (6-group boards can take a moment), then played move by move with the
## board locked against taps.
func _on_tidy() -> void:
	if _tidying or _hint_task >= 0:
		return
	board.cancel_lift()
	_tidying = true
	board.input_locked = true
	tidy_btn.visible = false
	_layout()
	_hint_token += 1
	_hint_cancel = [false]
	var token := _hint_token
	var copy := session.board.copy()
	var cancel := _hint_cancel
	_hint_task = WorkerThreadPool.add_task(func() -> void:
		var res := Solver.solve(copy, 40000, 2.0, Time.get_ticks_msec() + 1500, cancel)
		_tidy_ready.call_deferred(token, res))


func _tidy_ready(token: int, res: Dictionary) -> void:
	if _hint_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_hint_task)
		_hint_task = -1
	if token != _hint_token or session == null or session.is_over():
		return
	if not res["solved"]:
		_tidying = false
		board.input_locked = false
		_refresh()
		return
	_play_path(res["path"], 0)


func _play_path(path: Array, i: int) -> void:
	if i >= path.size() or session.is_over():
		board.input_locked = false
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
		"budget": session.budget, "moves": session.moves, "undos": session.undos, "hints": session.hints,
		"completes": session.completes, "jars_added": session.jars_added, "continues": session.continues,
		"tidy": _tidying, "secs": snappedf((Time.get_ticks_msec() - _started_ms) / 1000.0, 0.1),
		"slip_pairs": session.slip_log, "rules": session.rules.duplicate(),
		"at": Time.get_datetime_string_from_system(),
	}


## After a Continue (+2 slips), play resumes on the same board.
func resume_after_continue() -> void:
	_done = false
	_refresh()
	progress_changed.emit()


## Back: leave Complete's choice, or put down a lifted card. Returns true if it did something.
func on_back() -> bool:
	if choosing:
		cancel_complete()
		return true
	if board.lifted_jar >= 0:
		board.cancel_lift()
		return true
	return false


## Tutorial boards swap the slip meter and coins for a visible Skip.
func set_tutorial(on: bool) -> void:
	skip_btn.visible = on
	if on:
		meter.visible = false
		coins.visible = false
	_layout()


## The bar under the board while Complete waits for a label: what to do, Cancel, and the price on the confirm button.
class _ChoiceBar extends Control:
	signal cancelled
	signal confirmed

	var _text: Label
	var _confirm: PillButton
	var _free := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_text = Label.new()
		_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_text.add_theme_font_override("font", Style.sans_bold())
		_text.add_theme_font_size_override("font_size", Style.FS_30)
		_text.add_theme_color_override("font_color", Style.INK)
		add_child(_text)
		var cancel := PillButton.new("Cancel", false, 84.0)
		cancel.custom_minimum_size = Vector2(170, 84)
		cancel.pressed.connect(func() -> void: cancelled.emit())
		add_child(cancel)
		_confirm = PillButton.new("", true, 84.0)
		_confirm.pressed.connect(func() -> void: confirmed.emit())
		add_child(_confirm)
		resized.connect(_place)

	func open(free: bool) -> void:
		_free = free
		_text.text = "Tap a label above to finish its jar"
		_confirm.text = "Finish it"
		_confirm.enabled = false
		_confirm.queue_redraw()
		show()

	func ready_to_finish() -> void:
		_text.text = "Its four cards will fly into the label"
		_confirm.text = "Finish: 1 free" if _free else "Finish: %d coins" % Economy.PRICES["complete"]
		_confirm.enabled = true
		_confirm.queue_redraw()

	func _place() -> void:
		var pad := 18.0
		_text.position = Vector2(pad, 14)
		_text.size = Vector2(size.x - pad * 2.0, 40)
		var cancel: Control = get_child(1)
		cancel.position = Vector2(pad, size.y - 84 - 18)
		cancel.size = Vector2(170, 84)
		_confirm.position = Vector2(pad + 170 + 14, size.y - 84 - 18)
		_confirm.size = Vector2(size.x - pad * 2.0 - 170 - 14, 84)

	func _draw() -> void:
		var sb := Style.box(Style.PAPER, Style.R_XL)
		sb.shadow_color = Color(Style.INK, 0.2)
		sb.shadow_size = 20
		sb.shadow_offset = Vector2(0, 6)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
