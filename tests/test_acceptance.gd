extends SceneTree
## Release regression checks for observer interactions and failed-save recovery.

const MainScene = preload("res://scenes/main.tscn")
const SAVE_PATH: String = "user://ecosystem.save"
var failures: int = 0
var preserved: Dictionary = {}

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var result := _find_button(child, text)
		if result != null: return result
	return null

func run_checks() -> void:
	# Preserve files if invoked against an existing user directory.
	for path in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp", "user://settings.cfg"]:
		if DirAccess.dir_exists_absolute(path):
			push_error("Acceptance test requires regular files at save locations")
			quit(1)
			return
		if FileAccess.file_exists(path):
			preserved[path] = FileAccess.get_file_as_bytes(path)
			DirAccess.remove_absolute(path)
	var scene = MainScene.instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var original: Dictionary = scene.sim.to_data()
	var resource_count: int = scene.sim.resources.size()
	check(scene.resource_view.markers.size() == resource_count, "Every resource has an observation marker")
	var removed_resource: Dictionary = scene.sim.resources.pop_back()
	scene._refresh_ui()
	check(not scene.resource_view.markers.has(removed_resource.id), "Removed resource marker is pruned")
	scene.sim.resources.append(removed_resource)
	scene._refresh_ui()
	check(scene.resource_view.markers.size() == resource_count, "Resource marker returns after state restoration")
	# Selection/follow must survive removal of a retained death record without stale nodes.
	var removed_animal: Dictionary = scene.sim.animals.pop_back()
	scene.selected = removed_animal.id
	scene.camera.follow_target = scene.proxies[removed_animal.id]
	scene._refresh_ui()
	check(scene.camera.follow_target == null, "Pruning a followed animal releases its camera reference")
	check(not scene.proxies.has(removed_animal.id), "Pruning removes animal visual proxy")
	check(scene.proxies.has(scene.selected), "Pruning moves selection to a valid animal")
	check(scene.sim.from_data(original), "Original habitat state restores")
	scene._refresh_ui()
	var before_observation: float = scene.sim.elapsed
	var map_click := InputEventMouseButton.new()
	map_click.button_index = MOUSE_BUTTON_LEFT
	map_click.pressed = true
	map_click.position = scene.habitat_map.project_point(Vector3(-20,0,30))
	scene.habitat_map._gui_input(map_click)
	check(scene.camera.position.distance_to(Vector3(-20,5,40)) < 5.0, "Habitat map converts an actual click into camera travel")
	check(scene.sim.elapsed == before_observation, "Pruning and observation do not advance biology")
	# Opening/canceling reset cannot discard the current ecosystem.
	scene.sim.tick(2.0)
	var before_reset: float = scene.sim.elapsed
	var new_button := _find_button(scene, "New ecosystem")
	check(new_button != null, "New ecosystem confirmation control exists")
	if new_button != null:
		new_button.pressed.emit()
		check(scene.confirm_reset.visible, "New ecosystem opens confirmation")
		check(scene.sim.elapsed == before_reset, "Opening reset dialog retains current ecosystem")
		scene.confirm_reset.hide()
		check(scene.sim.elapsed == before_reset, "Canceling reset retains current ecosystem")
	check(scene._save(), "Current ecosystem checkpoint saves before reset")
	scene._new_ecosystem()
	check(scene.sim.elapsed == 0.0 and not scene.running, "Confirmed reset creates a paused world")
	var backup = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH + ".bak"))
	check(backup is Dictionary and is_equal_approx(backup.elapsed, before_reset), "Reset retains the previous ecosystem checkpoint as backup")
	scene._load(SAVE_PATH + ".bak")
	check(is_equal_approx(scene.sim.elapsed, before_reset) and not scene.running, "Reset can be undone by backup recovery without offline progression")
	# An unopenable temporary path reproduces disk-write failure without changing permissions.
	if FileAccess.file_exists(SAVE_PATH + ".tmp"): DirAccess.remove_absolute(SAVE_PATH + ".tmp")
	check(DirAccess.make_dir_absolute(SAVE_PATH + ".tmp") == OK, "Create isolated save-failure fixture")
	var before_failure: Dictionary = scene.sim.to_data()
	var disk_checkpoint: PackedByteArray = FileAccess.get_file_as_bytes(SAVE_PATH)
	check(not scene._save(), "Unwritable save reports failure")
	check(scene.status.text.begins_with("Save failed"), "Save failure has visible user feedback")
	scene.event_selector.item_selected.emit(1)
	check(scene.status.text.begins_with("Save failed"), "Event changes preserve save-failure feedback")
	scene.sim.from_data(before_failure)
	scene._new_ecosystem()
	check(scene.sim.to_data() == before_failure, "Save failure prevents destructive reset")
	check(FileAccess.get_file_as_bytes(SAVE_PATH) == disk_checkpoint, "Save failure preserves disk checkpoint")
	scene.running = true
	scene._toggle()
	check(not scene.running and scene.sim.to_data() == before_failure, "Failed pause save still pauses without changing state")
	DirAccess.remove_absolute(SAVE_PATH + ".tmp")
	scene.queue_free()
	await process_frame
	for path in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp", "user://settings.cfg"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		if preserved.has(path):
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(preserved[path])
			file.close()
	print("Acceptance tests: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
