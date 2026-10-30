## Builds the project's few .tscn files so Godot writes them (and their uids), never a human.
## Run: godot --headless --path . -s res://tools/make_scenes.gd
extends SceneTree


func _init() -> void:
	var root := Control.new()
	root.name = "Main"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://src/app/main.gd"))
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, "res://main.tscn")
	print("make_scenes: main.tscn -> ", error_string(err))
	root.free()
	quit(0 if err == OK else 1)
