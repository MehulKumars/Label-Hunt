## Root of the app: owns screens, popups and the Back button.
extends Control


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#FFF8EC")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
