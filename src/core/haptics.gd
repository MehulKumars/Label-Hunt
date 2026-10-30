## Light haptics (autoload "Haptics"). Needs the VIBRATE permission in the Android export.
## Godot has only vibrate_handheld, and cheap phones' motors buzz on very short pulses, so every pulse is at least
## 15 ms and only the moments that matter vibrate: lift, drop, slip, lid and win (never hovers or UI taps).
extends Node

const MIN_MS := 15

var enabled := true


func tick(ms: int, amplitude: float = 0.4) -> void:
	if enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(maxi(ms, MIN_MS), amplitude)


func lift() -> void:
	tick(15, 0.3)


func drop() -> void:
	tick(18, 0.4)


func slip() -> void:
	tick(20, 0.3)


func lid() -> void:
	tick(35, 0.7)


func win() -> void:
	tick(20, 0.5)
	get_tree().create_timer(0.1).timeout.connect(tick.bind(40, 0.8))
	get_tree().create_timer(0.24).timeout.connect(tick.bind(20, 0.5))
