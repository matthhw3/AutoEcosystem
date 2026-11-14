extends SceneTree
## Export notices from the exact engine distributed with the portable build.

func _initialize() -> void:
	var destination: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			destination = argument.trim_prefix("--output=")
	if destination.is_empty() or not destination.is_absolute_path():
		push_error("Provide an absolute --output= directory after --")
		quit(1)
		return
	if not DirAccess.dir_exists_absolute(destination):
		push_error("Notice output directory does not exist")
		quit(1)
		return
	var notices: Dictionary = {
		"engine_version": Engine.get_version_info(),
		"license_texts": Engine.get_license_info(),
		"copyright_components": Engine.get_copyright_info(),
		"source": "https://docs.godotengine.org/en/stable/about/complying_with_licenses.html"
	}
	if not _write(destination.path_join("GODOT_LICENSE.txt"), "This game uses Godot Engine. The following license applies to Godot Engine, not to the game's original source or assets.\n\n" + Engine.get_license_text() + "\n"):
		quit(1)
		return
	if not _write(destination.path_join("GODOT_THIRD_PARTY.json"), JSON.stringify(notices, "  ", true) + "\n"):
		quit(1)
		return
	print("GODOT_NOTICES_OK ", Engine.get_version_info().string)
	quit(0)

func _write(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write engine notices: " + error_string(FileAccess.get_open_error()))
		return false
	file.store_string(content)
	file.close()
	return true
