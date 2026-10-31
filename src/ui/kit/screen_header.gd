## The top of a full screen (Levels, a room, Profile): a back disc on the left and the screen's name, under the
## safe area. Back on Android does the same as the disc.
class_name ScreenHeader
extends Control

signal back_pressed

const H := 104.0

var title := "":
	set(v):
		title = v
		queue_redraw()
var back: RoundButton


func _init(heading: String = "") -> void:
	title = heading
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	back = RoundButton.new("back")
	back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back)


## Places itself at the top of `parent_size`, under the safe area. Returns the y where content can start.
func place(parent_size: Vector2) -> float:
	var top: float = SafeArea.current(parent_size)["top"] + Style.SP_3
	position = Vector2(0, top)
	size = Vector2(parent_size.x, H)
	back.position = Vector2(Style.GUTTER - 6.0, 0)
	back.size = back.custom_minimum_size
	queue_redraw()
	return top + H


func _draw() -> void:
	var f := Style.sans_heavy()
	var fs := Style.FS_44
	var avail := size.x - (Style.GUTTER + RoundButton.D) * 2.0
	while fs > Style.FS_30 and f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
		fs -= 2
	var ts := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(f, Vector2((size.x - ts.x) / 2.0, RoundButton.D / 2.0 + f.get_ascent(fs) / 2.0 - 4.0), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.INK)
