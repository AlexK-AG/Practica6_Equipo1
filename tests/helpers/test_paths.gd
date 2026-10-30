extends RefCounted
## Keep generated QA artifacts separate from the user's archived revisions.
static func prepare() -> void:
	for folder in ["res://.godot/test-results/logs", "res://.godot/test-results/capturas"]:
		var result := DirAccess.make_dir_recursive_absolute(folder)
		assert(result == OK, "Cannot create the test output directory: " + folder)
