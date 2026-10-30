## Light haptics (autoload "Haptics"). Needs the VIBRATE permission in the Android export.
extends Node

var enabled := true


func tick(ms: int, amplitude: float = 0.4) -> void:
	if enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, amplitude)


func lift() -> void:
	tick(8, 0.3)


func drop() -> void:
	tick(10, 0.4)


func slip() -> void:
	tick(12, 0.25)


func lid() -> void:
	tick(50, 0.7)


func win() -> void:
	tick(30, 0.6)
	get_tree().create_timer(0.12).timeout.connect(tick.bind(50, 0.8))
