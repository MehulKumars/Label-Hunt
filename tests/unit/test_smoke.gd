extends GutTest


func test_project_name() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Label Hunt")
