## Base for every popup: dims the screen, slides a paper panel up, and closes on Back unless told otherwise.
## Built from plain Controls (never Window-based nodes, which show default chrome).
class_name Sheet
extends Control

signal closed

var panel: Control
var body: VBoxContainer
var title := ""
var _dim: ColorRect


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
		margin.add_theme_constant_override("margin_" + side, 36)
	panel.add_child(margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	margin.add_child(body)
	if heading != "":
		var t := Label.new()
		t.text = heading
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_font_override("font", Style.typed())
		t.add_theme_font_size_override("font_size", 46)
		body.add_child(t)


func _ready() -> void:
	modulate.a = 0.0
	_fit()
	# Wrapped labels only know their height once the containers have given them a width.
	await get_tree().process_frame
	_fit()
	resized.connect(_fit)
	var final_y := panel.position.y
	panel.position.y += 60.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, Style.T_SCREEN)
	tw.tween_property(panel, "position:y", final_y, Style.T_SCREEN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fit() -> void:
	var w := minf(size.x - 48.0, 620.0)
	panel.size.x = w
	var h := minf(body.get_combined_minimum_size().y + 72.0, size.y - 48.0)
	panel.size = Vector2(w, h)
	panel.position = Vector2((size.x - w) / 2.0, maxf(24.0, (size.y - h) / 2.0))


## Called by Main on Android Back. Return true if handled.
func on_back() -> bool:
	close()
	return true


func close() -> void:
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
		draw_style_box(Style.box(Style.SHADOW, 30), Rect2(Vector2(0, 8), size))
		draw_style_box(Style.box(Style.PAPER, 30, 3, Style.INK), Rect2(Vector2.ZERO, size))
