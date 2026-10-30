## Leaving the app from Home on Android Back: send the task to the background like native apps do.
class_name AppBack
extends RefCounted


static func to_background() -> void:
	if OS.get_name() == "Android" and Engine.has_singleton("AndroidRuntime"):
		var runtime: Object = Engine.get_singleton("AndroidRuntime")
		var activity: Object = runtime.call("getActivity")
		if activity != null:
			activity.call("moveTaskToBack", true)
			return
	if OS.has_feature("mobile"):
		Engine.get_main_loop().quit()
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
