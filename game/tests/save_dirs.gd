extends RefCounted

# Test helper, preloaded by tests that write saves. Not a test itself:
# GUT only collects files starting with "test_".

# Where tests put their saves, so they never touch user://saves.
const TEST_ROOT: String = "user://test_saves"


# Deletes a folder and everything in it. A missing folder is fine.
static func remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	for dir: String in DirAccess.get_directories_at(path):
		remove_tree(path.path_join(dir))
	DirAccess.remove_absolute(path)
