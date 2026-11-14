extends SceneTree
## Independent release regressions. Preserve any pre-existing local checkpoints.

const MainScene = preload("res://scenes/main.tscn")
const Simulation = preload("res://scripts/simulation.gd")
const Forest = preload("res://scripts/forest.gd")
const SAVE_PATH := "user://ecosystem.save"
var failures := 0
var preserved: Dictionary = {}

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func run_checks() -> void:
	for path in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp", SAVE_PATH + ".corrupt", "user://settings.cfg"]:
		if DirAccess.dir_exists_absolute(path):
			push_error("Release audit requires regular files at checkpoint locations")
			quit(1)
			return
		if FileAccess.file_exists(path):
			preserved[path] = FileAccess.get_file_as_bytes(path)
			DirAccess.remove_absolute(path)
	var first = MainScene.instantiate()
	root.add_child(first)
	await process_frame
	first.set_process(false)
	first.sim.tick(1.0)
	check(first._save(), "First known-good checkpoint saves")
	first.sim.tick(1.0)
	check(first._save(), "Second checkpoint creates a recoverable backup")
	var known_backup = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH + ".bak"))
	check(known_backup is Dictionary and is_equal_approx(known_backup.elapsed, 1.0), "Backup retains the previous session")
	var corrupt := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	corrupt.store_string("{\"version\":2,\"animals\":[]}")
	corrupt.close()
	first.queue_free()
	await process_frame
	var restarted = MainScene.instantiate()
	root.add_child(restarted)
	await process_frame
	restarted.set_process(false)
	check(not restarted.running, "Corrupt-primary startup remains paused")
	check(is_equal_approx(restarted.sim.elapsed, 1.0), "Corrupt-primary startup recovers the previous valid session without offline advancement")
	# Saving is the exact persistence operation performed on normal window close.
	check(restarted._save(), "Normal close persistence can write after a corrupt primary")
	var backup_after = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH + ".bak"))
	var backup_world = Simulation.new()
	check(backup_after is Dictionary and backup_world.from_data(backup_after), "Normal close after a corrupt startup must not replace the last valid backup with corrupt bytes")
	check(FileAccess.file_exists(SAVE_PATH + ".corrupt"), "Damaged primary is preserved separately for recovery diagnostics")
	restarted.queue_free()
	await process_frame
	# The roster must be browsable even when an animal elsewhere remains selected.
	var roster_scene = MainScene.instantiate()
	root.add_child(roster_scene)
	await process_frame
	roster_scene.set_process(false)
	for index in range(40):
		roster_scene.sim._spawn("deer", Vector3(index % 10, 0, index / 10))
		roster_scene.sim._die(roster_scene.sim.animals.back(), "Release audit archive")
	roster_scene._refresh_ui()
	await process_frame
	var scrollbar: VScrollBar = roster_scene.roster.get_v_scroll_bar()
	check(scrollbar.max_value > scrollbar.page, "Large roster has a scrollable animal archive")
	scrollbar.value = scrollbar.max_value - scrollbar.page
	var scrolled: float = scrollbar.value
	roster_scene._refresh_ui()
	await process_frame
	check(scrolled > 0 and scrollbar.value > 0, "Periodic inspection refresh preserves a user's roster scroll position")
	var profile: Dictionary = roster_scene.sim.animals[0]
	profile.memories.clear()
	for index in range(8): profile.memories.append("Experience %d: a long retained forest observation that wraps within the profile panel." % index)
	roster_scene.selected = profile.id
	roster_scene._refresh_ui()
	await process_frame
	var profile_scroll: VScrollBar = roster_scene.inspection.get_v_scroll_bar()
	profile_scroll.value = profile_scroll.max_value - profile_scroll.page
	var profile_scrolled: float = profile_scroll.value
	profile.hunger += 1
	roster_scene._refresh_ui()
	await process_frame
	check(profile_scrolled > 0 and profile_scroll.value > 0, "Needs refresh preserves the profile's scrolled recent-experience view")
	# Upward follow orbit currently permits a negative vertical offset. Exercise the
	# saved-pose restoration path without capturing the user's physical mouse.
	var followed: Node3D = roster_scene.proxies[roster_scene.selected]
	roster_scene.camera.restore_pose(followed.position + Vector3(0, -6, 2), Vector3.ZERO)
	roster_scene.camera.restore_follow(followed)
	roster_scene.camera._process(1.0)
	var view: Vector3 = roster_scene.camera.position
	check(view.y >= Forest.height_at(view.x, view.z) + 0.1, "Restoring a low follow orbit keeps the observer above ground")
	roster_scene.queue_free()
	await process_frame
	for path in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp", SAVE_PATH + ".corrupt", "user://settings.cfg"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		if preserved.has(path):
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(preserved[path])
			file.close()
	print("Release audit tests: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
