extends GutTest


func test_project_name() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Label Hunt")


## Art.icon reads each icon's raw SVG at runtime. Godot never exports the source of an imported file (an include
## filter doesn't change that), so every icon must use the "keep" importer or exported builds show no icons.
func test_icons_ship_as_raw_files() -> void:
	var dir := "res://assets/icons/"
	var svgs := Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool: return f.ends_with(".svg"))
	assert_gt(svgs.size(), 30, "icons found")
	for f: String in svgs:
		var imp := FileAccess.get_file_as_string(dir + f + ".import")
		assert_true(imp.contains('importer="keep"'), "%s must use the keep importer" % f)
