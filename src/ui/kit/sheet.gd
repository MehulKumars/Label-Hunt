## Base for every popup: dims the screen, slides a paper panel up, and closes on Back unless told otherwise.
## Dismissible sheets also close from a × button and from a tap on the dimmed area outside the panel.
## Built from plain Controls (never Window-based nodes, which show default chrome).
class_name Sheet
extends Control

signal closed

## False for sheets that need a decision (results, a playing ad): no ×, and outside taps do nothing.
var dismissible := true
## For Back (BackPolicy): "utility" closes, "result" goes Home, "blocking" (an ad playing) ignores Back.
var kind := "utility"
## Pause shows no × (it has Resume); it still closes on Back and outside taps.
var show_close := true
## How much the sheet darkens the screen behind it (Win keeps it light so the solved board stays in view).
var dim_alpha := 0.2
var panel: Control
var body: VBoxContainer
var title := ""
var _dim: ColorRect
var _outside_press := false
var _closing := false


func _init(heading: String = "") -> void:
	title = heading
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	_dim = ColorRect.new()
	_dim.color = Style.DIM
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	panel = _Panel.new()
	add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	panel.add_child(margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	margin.add_child(body)
	if heading != "":
		var t := Label.new()
		t.text = heading
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_font_override("font", Style.sans_heavy())
		t.add_theme_font_size_override("font_size", Style.FS_44)
		t.add_theme_color_override("font_color", Style.INK)
		body.add_child(t)


func _ready() -> void:
	modulate.a = 0.0
	_dim.color = Color(Style.INK, dim_alpha)
	if dismissible and show_close:
		var x := _CloseButton.new()
		x.pressed.connect(func() -> void: on_back())
		panel.add_child(x)
	_fit()
	# Wrapped labels only know their height once the containers have given them a width.
	await get_tree().process_frame
	_fit()
	resized.connect(_fit)
	var final_y := panel.position.y
	panel.position.y += 140.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, Style.T_SHEET_IN * 0.6)
	tw.tween_property(panel, "position:y", final_y, Style.T_SHEET_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _fit() -> void:
	var w := minf(size.x - 32.0, 660.0)
	panel.size.x = w
	var h := minf(body.get_combined_minimum_size().y + 72.0, size.y - 48.0)
	panel.size = Vector2(w, h)
	# Anchored to the bottom, in the thumb zone, above the gesture bar.
	var bottom: float = SafeArea.current(size)["bottom"] + 20.0
	panel.position = Vector2((size.x - w) / 2.0, maxf(24.0, size.y - h - bottom))
	for child in panel.get_children():
		if child is _CloseButton:
			child.position = Vector2(w - child.size.x - 6.0, 6.0)


## Taps that reach the sheet itself landed outside the panel (the panel swallows its own). Press and release both
## have to be outside, so a drag that started on a button can't close the sheet by accident.
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if event.pressed:
		_outside_press = true
	elif _outside_press:
		_outside_press = false
		if dismissible and not _closing:
			on_back()


## Called by Main on Android Back, and by the × and outside taps on dismissible sheets. Return true if handled.
func on_back() -> bool:
	close()
	return true


func close() -> void:
	if _closing:
		return
	_closing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func() -> void:
		closed.emit()
		queue_free())


func add_label(text: String, size_px: int = Style.BODY_FONT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size_px)
	if bold:
		l.add_theme_font_override("font", Style.sans_bold())
	body.add_child(l)
	return l


func add_button(text: String, primary: bool, action: Callable, height: float = 96.0) -> PillButton:
	var b := PillButton.new(text, primary, height)
	b.pressed.connect(action)
	body.add_child(b)
	return b


func add_toggle(text: String, on: bool, action: Callable) -> PillButton:
	var b := PillButton.new("", false, 76.0)
	b.font_size = 26
	var refresh := func(v: bool) -> void:
		b.text = "%s: %s" % [text, "On" if v else "Off"]
		b.queue_redraw()
	refresh.call(on)
	var state := [on]
	b.pressed.connect(func() -> void:
		state[0] = not state[0]
		refresh.call(state[0])
		action.call(state[0]))
	body.add_child(b)
	return b


class _Panel extends Control:
	func _draw() -> void:
		var sb := Style.box(Style.PAPER, Style.R_XL)
		sb.shadow_color = Color(Style.INK, 0.22)
		sb.shadow_size = 26
		sb.shadow_offset = Vector2(0, 10)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		draw_rect(Rect2(Style.R_XL, 2, size.x - Style.R_XL * 2, 2), Color(1, 1, 1, 0.8))


## The × in the panel's top-right corner: a 56 px disc inside an 88 px touch target.
class _CloseButton extends Control:
	signal pressed

	var _down := false

	func _init() -> void:
		size = Vector2(88, 88)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if event.pressed:
			_down = true
			Sfx.play("tap", 1.0, 0.05, -4.0)
		elif _down:
			_down = false
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, 28.0, Style.PAPER_DEEP, true, -1.0, true)
		draw_texture_rect(Art.icon("x", 26.0, Style.INK), Rect2(c - Vector2(13, 13), Vector2(26, 26)), false)


## A settings row: the setting's name, and a switch that flips on a tap anywhere in the row.
func add_switch(text: String, on: bool, action: Callable) -> Control:
	var row := _Switch.new(text, on)
	row.toggled.connect(action)
	body.add_child(row)
	return row


## On/off shows as the knob's side as well as the track colour, so colour is never the only signal.
class _Switch extends Control:
	signal toggled(on: bool)

	var text := ""
	var on := false
	var _knob := 0.0
	var _down := false

	func _init(label: String, value: bool) -> void:
		text = label
		on = value
		_knob = 1.0 if value else 0.0
		custom_minimum_size = Vector2(0, Style.TOUCH)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if event.is_canceled():
			_down = false
		elif event.pressed:
			_down = true
		elif _down:
			_down = false
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				on = not on
				Sfx.play("tap", 1.0, 0.05, -4.0)
				create_tween().tween_method(func(v: float) -> void:
					_knob = v
					queue_redraw(), _knob, 1.0 if on else 0.0, Style.T_RELEASE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				toggled.emit(on)

	func _draw() -> void:
		var f := Style.sans_bold()
		var fs := Style.FS_30
		draw_string(f, Vector2(4, (size.y - f.get_height(fs)) / 2.0 + f.get_ascent(fs)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.INK)
		var track := Rect2(size.x - 100, (size.y - 48) / 2.0, 96, 48)
		draw_style_box(Style.box(Style.TEAL.lerp(Style.INK_FAINT, 1.0 - _knob) if _knob < 1.0 else Style.TEAL, 24), track)
		var kc := Vector2(lerpf(track.position.x + 24, track.end.x - 24, _knob), track.get_center().y)
		draw_circle(kc + Vector2(0, 2), 19.0, Color(Style.INK, 0.2), true, -1.0, true)
		draw_circle(kc, 19.0, Style.CARD, true, -1.0, true)
