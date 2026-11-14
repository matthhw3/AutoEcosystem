extends SceneTree
## Scene control/persistence regression test; preserve any user's existing save files.

const MainScene = preload("res://scenes/main.tscn")
const Simulation = preload("res://scripts/simulation.gd")
const SAVE_PATH = "user://ecosystem.save"
var failures: int = 0
var backups: Dictionary = {}

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_tests")

func state_json(world) -> String:
	return JSON.stringify(world.to_data(), "", true, true)

func same_state(a, b) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not same_state(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not same_state(a[i], b[i]): return false
		return true
	if (a is float or a is int) and (b is float or b is int):
		# Godot JSON parsing may round a double by one ULP even at full precision.
		return absf(float(a) - float(b)) < 0.000000000001
	return a == b

func run_tests() -> void:
	if FileAccess.file_exists("user://settings.cfg"):
		backups["user://settings.cfg"] = FileAccess.get_file_as_bytes("user://settings.cfg")
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = SAVE_PATH + suffix
		if FileAccess.file_exists(path):
			backups[path] = FileAccess.get_file_as_bytes(path)
			DirAccess.remove_absolute(path)
	var scene = MainScene.instantiate()
	root.add_child(scene)
	await process_frame
	check(not scene.running, "Scene starts paused")
	check(scene.proxies.size() == scene.sim.animals.size(), "Scene builds every animal proxy")
	var initial: String = state_json(scene.sim)
	for frame in range(5):
		await process_frame
	check(state_json(scene.sim) == initial, "Frames do not advance paused simulation")
	scene.set_process(false)
	scene._toggle()
	check(scene.running, "Start enables simulation")
	scene._process(0.2)
	check(is_equal_approx(scene.sim.elapsed, 0.2), "Running frames advance fixed ticks")
	scene._toggle()
	check(not scene.running, "Pause disables simulation")
	check(FileAccess.file_exists(SAVE_PATH), "Pause creates local save")
	check(scene.status.text == "Saved locally.", "Atomic save reports success")
	var expected_state: Dictionary = scene.sim.to_data()
	var persisted = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	var reloaded = Simulation.new()
	check(persisted is Dictionary and reloaded.from_data(persisted), "Written save passes validation")
	check(same_state(reloaded.to_data(), expected_state), "Written save retains full state within JSON float precision")
	scene.sim.tick(4.0)
	scene.running = true
	scene.accumulator = 0.07
	scene._load()
	check(not scene.running and scene.accumulator == 0.0, "Load pauses and clears fractional time")
	check(same_state(scene.sim.to_data(), expected_state), "Load restores full ecosystem state")
	var before_invalid: String = state_json(scene.sim)
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{\"version\":1,\"animals\":[]}")
	file.close()
	scene._load()
	check(state_json(scene.sim) == before_invalid, "Invalid save preserves live state")
	check(scene.status.text.begins_with("Invalid save"), "Invalid save produces visible feedback")
	var before_step: float = scene.sim.elapsed
	scene._step()
	check(not scene.running and is_equal_approx(scene.sim.elapsed, before_step + 0.1), "Step advances exactly one fixed tick and pauses")
	check(scene.status.text == "Saved locally.", "Step saves its checkpoint")
	scene._process(0.2)
	check(is_equal_approx(scene.sim.elapsed, before_step + 0.1), "Paused manual processing leaves time unchanged")
	# Observation tools must stay live while biological time remains paused.
	scene.roster.item_selected.emit(2)
	check(scene.selected == scene.sim.animals[2].id, "Roster selects an independent animal")
	var followed: Node3D = scene.proxies[scene.selected]
	scene.camera.focus_position(followed.position)
	check(scene.camera.position.distance_to(followed.position) < 20, "Focus brings camera near animal")
	scene.camera.follow_target = followed
	var old_camera: Vector3 = scene.camera.position
	followed.position += Vector3(6, 0, 0)
	scene.camera._process(0.2)
	check(scene.camera.position.distance_to(old_camera) > 0.1, "Follow camera tracks animal proxy while paused")
	check(is_equal_approx(scene.sim.elapsed, before_step + 0.1), "Camera follow never advances biology")
	var before_map: float = scene.sim.elapsed
	scene.habitat_map.location_chosen.emit(Vector3(20, 0, 20))
	check(scene.camera.follow_target == null, "Map exploration releases follow target")
	check(scene.camera.position.distance_to(Vector3(20, 5, 30)) < 5, "Map click focuses world position")
	check(scene.sim.elapsed == before_map, "Map interaction never advances ecosystem")
	check(scene.ambience.stream is AudioStreamWAV and scene.ambience.stream.data.size() > 0, "Local ambience contains synthesized audio")
	scene.camera.follow_target = null
	for event in ["wildfire", "flood", "drought", "normal"]:
		scene.sim.set_event(event)
		scene._refresh_ui()
		check(scene.forest._visual_event == event, "Environment view reflects simulation event")
		check(scene.forest._fire_effect.visible == (event == "wildfire"), "Wildfire view toggles cleanly")
		check(scene.forest._flood_effect.visible == (event == "flood"), "Flood view toggles cleanly")
		check(is_equal_approx(scene.sim.elapsed, before_step + 0.1), "Changing an event does not advance time")
	# Restore a valid checkpoint and verify explicit backup recovery.
	scene._save()
	scene._save()
	var backup_state = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH + ".bak"))
	scene.sim.tick(0.1)
	scene._load(SAVE_PATH + ".bak")
	var backup_world = Simulation.new()
	check(backup_world.from_data(backup_state), "Backup checkpoint is a valid ecosystem")
	check(same_state(scene.sim.to_data(), backup_world.to_data()) and not scene.running, "Backup recovery restores the checkpoint paused")
	var preferences_time: float = scene.sim.elapsed
	scene.sound_enabled = false
	scene._save_preferences()
	scene.sound_enabled = true
	scene._load_preferences()
	check(not scene.sound_enabled, "Observation preferences persist locally")
	check(scene.sim.elapsed == preferences_time, "Saving preferences never advances simulation")
	scene.speed = 10.0
	scene.running = true
	var speed_time: float = scene.sim.elapsed
	scene._process(0.2)
	check(is_equal_approx(scene.sim.elapsed - speed_time, 2.0), "10x speed schedules the correct number of fixed ticks")
	scene.running = false
	scene.roster.grab_focus()
	var follow_key := InputEventKey.new()
	follow_key.keycode = KEY_F
	follow_key.pressed = true
	Input.parse_input_event(follow_key.duplicate())
	await process_frame
	check(scene.camera.follow_target == scene.proxies[scene.selected], "Follow shortcut works while roster has focus")
	follow_key.pressed = false
	Input.parse_input_event(follow_key.duplicate())
	scene.start_button.grab_focus()
	var space_key := InputEventKey.new()
	space_key.keycode = KEY_SPACE
	space_key.pressed = true
	Input.parse_input_event(space_key.duplicate())
	await process_frame
	check(scene.running, "Space starts exactly once with a focused button")
	space_key.pressed = false
	Input.parse_input_event(space_key.duplicate())
	space_key.pressed = true
	Input.parse_input_event(space_key.duplicate())
	await process_frame
	check(not scene.running, "Space pauses exactly once with a focused button")
	space_key.pressed = false
	Input.parse_input_event(space_key.duplicate())
	scene.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = SAVE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		if backups.has(path):
			var restore = FileAccess.open(path, FileAccess.WRITE)
			restore.store_buffer(backups[path])
			restore.close()
	if FileAccess.file_exists("user://settings.cfg"): DirAccess.remove_absolute("user://settings.cfg")
	if backups.has("user://settings.cfg"):
		var restore = FileAccess.open("user://settings.cfg", FileAccess.WRITE)
		restore.store_buffer(backups["user://settings.cfg"])
		restore.close()
	print("Integration tests: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
