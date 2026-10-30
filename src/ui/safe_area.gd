## Converts the display's safe area (screen pixels) into insets on the stretched canvas.
class_name SafeArea
extends RefCounted

## Test hook: forced insets in canvas units (e.g. to screenshot a notched phone on desktop).
static var forced: Dictionary = {}


static func insets(window_size: Vector2i, safe: Rect2i, canvas: Vector2) -> Dictionary:
	if window_size.x <= 0 or window_size.y <= 0:
		return {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	var sx := canvas.x / window_size.x
	var sy := canvas.y / window_size.y
	return {
		"top": maxf(0.0, safe.position.y * sy),
		"bottom": maxf(0.0, (window_size.y - safe.end.y) * sy),
		"left": maxf(0.0, safe.position.x * sx),
		"right": maxf(0.0, (window_size.x - safe.end.x) * sx),
	}


## Insets for the running app. Desktop windows have no notches, so only mobile reads the display.
static func current(canvas: Vector2) -> Dictionary:
	if not forced.is_empty():
		return forced
	if not OS.has_feature("mobile"):
		return {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	return insets(DisplayServer.window_get_size(), DisplayServer.get_display_safe_area(), canvas)
