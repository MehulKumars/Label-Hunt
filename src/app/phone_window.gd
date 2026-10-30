## Desktop runs only: shapes the window like a portrait phone and fits it on the monitor, so test runs and
## screenshots look like the phone instead of spilling off the screen. With canvas_items + expand the layout
## depends only on the aspect ratio, so a scaled-down window shows exactly what a phone of that shape shows.
## Args: --phone=1080x2400 (or --size= in shot mode) picks the shape; --true-size keeps real pixels.
class_name PhoneWindow

const DEFAULT := Vector2i(1080, 2400) # a typical 20:9 Android phone
const SCREEN_FILL := 0.88 # of the usable height, leaving room for the title bar


static func phone_from_args(default: Vector2i = DEFAULT) -> Vector2i:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--phone=") or a.begins_with("--size="):
			var p := a.get_slice("=", 1).split("x")
			if p.size() == 2 and int(p[0]) > 0 and int(p[1]) > 0:
				return Vector2i(int(p[0]), int(p[1]))
	return default


static func fit(win: Window, phone: Vector2i) -> void:
	if DisplayServer.get_name() == "headless" or not OS.has_feature("pc"):
		return
	var size := phone
	if not OS.get_cmdline_user_args().has("--true-size"):
		var usable := DisplayServer.screen_get_usable_rect(win.current_screen).size
		var s := minf(1.0, minf(usable.y * SCREEN_FILL / phone.y, usable.x * SCREEN_FILL / phone.x))
		size = Vector2i(roundi(phone.x * s), roundi(phone.y * s))
	win.size = size
	win.move_to_center()
