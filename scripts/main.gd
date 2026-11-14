extends Node3D

const Simulation = preload("res://scripts/simulation.gd")
const Forest = preload("res://scripts/forest.gd")
const Spectator = preload("res://scripts/spectator_camera.gd")
const AnimalVisual = preload("res://scripts/animal_visual.gd")
const ObservationMap = preload("res://scripts/observation_map.gd")
const ForestAudio = preload("res://scripts/forest_audio.gd")
const ResourceVisuals = preload("res://scripts/resource_visuals.gd")
const SAVE_PATH = "user://ecosystem.save"
const DT = 0.1
var sim = Simulation.new()
var running := false
var speed := 1.0
var accumulator := 0.0
var selected := 1
var proxies: Dictionary = {}
var camera: Camera3D
var summary: Label
var inspection: RichTextLabel
var status: Label
var roster: ItemList
var start_button: Button
var event_selector: OptionButton
var ring: MeshInstance3D
var ui_elapsed := 0.0
var forest: Node3D
var habitat_map: Control
var ambience: AudioStreamPlayer
var resource_view: Node3D
var confirm_reset: ConfirmationDialog
var labels_visible := true
var sound_enabled := true
var resources_visible := true

func _ready() -> void:
	get_tree().auto_accept_quit = false
	_load_preferences()
	sim.reset(42)
	forest = Forest.new()
	add_child(forest)
	camera = Spectator.new()
	add_child(camera)
	camera.current = true
	ambience = ForestAudio.new()
	add_child(ambience)
	ambience.stream_paused = not sound_enabled
	resource_view = ResourceVisuals.new()
	add_child(resource_view)
	resource_view.visible = resources_visible
	_build_ui()
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.0
	torus.outer_radius = 1.12
	torus.rings = 24
	ring.mesh = torus
	ring.material_override = _material(Color("e9c978"))
	add_child(ring)
	_sync_proxies()
	if FileAccess.file_exists(SAVE_PATH) and "--fresh" not in OS.get_cmdline_user_args():
		_load()
	_refresh_ui()
	if "--benchmark" in OS.get_cmdline_user_args():
		running = true
		speed = 10.0
		var started := Time.get_ticks_msec()
		for frame in range(360): await get_tree().process_frame
		var seconds: float = (Time.get_ticks_msec() - started) / 1000.0
		running = false
		print("GRAPHICAL_BENCHMARK frames=360 fps=", 360.0 / seconds, " simulation_seconds=", sim.elapsed)
		ambience.stop()
		await get_tree().process_frame
		get_tree().quit()
	if "--capture" in OS.get_cmdline_user_args():
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--event="):
				sim.set_event(argument.trim_prefix("--event="))
		_refresh_ui()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://test-results")
		get_viewport().get_texture().get_image().save_png("res://test-results/observatory.png")
		print("GRAPHICAL_CAPTURE_OK")
		ambience.stop()
		await get_tree().process_frame
		get_tree().quit()
	if "--smoke" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		_step()
		print("SCENE_SMOKE_OK agents=", proxies.size())
		ambience.stop()
		get_tree().quit()

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat

func _animal_proxy(a: Dictionary) -> Node3D:
	var root = AnimalVisual.new()
	root.build(a)
	add_child(root)
	return root

func _sync_proxies() -> void:
	var ids: Array = []
	for a in sim.animals: ids.append(a.id)
	for id in proxies.keys():
		if id not in ids:
			if camera.follow_target == proxies[id]: camera.follow_target = null
			proxies[id].queue_free()
			proxies.erase(id)
	if selected not in ids and not ids.is_empty(): selected = ids[0]
	for a in sim.animals:
		if not proxies.has(a.id):
			proxies[a.id] = _animal_proxy(a)
		var proxy = proxies[a.id]
		proxy.sync(a, Forest.height_at(a.position.x, a.position.z), sim.elapsed, a.id == selected)
		proxy.title.visible = labels_visible
		if a.id == selected:
			ring.position = proxy.position + Vector3.UP * 0.08

func _process(delta: float) -> void:
	if running:
		accumulator += minf(delta, 0.25) * speed
		while accumulator + 0.000000001 >= DT:
			sim.tick(DT)
			accumulator = maxf(0.0, accumulator - DT)
		_sync_proxies()
	ui_elapsed += delta
	if ui_elapsed > 0.25:
		ui_elapsed = 0
		_refresh_ui()

func _input(event: InputEvent) -> void:
	if is_instance_valid(confirm_reset) and confirm_reset.visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: _toggle()
		if event.keycode == KEY_PERIOD: _step()
		if event.keycode == KEY_F: camera.follow_target = proxies.get(selected)
		if event.keycode == KEY_R:
			camera.follow_target = null
			if proxies.has(selected): camera.focus_position(proxies[selected].position)
		if event.keycode == KEY_TAB:
			var ids: Array = proxies.keys()
			if not ids.is_empty(): selected = ids[(ids.find(selected) + 1) % ids.size()]
			_refresh_ui()
		if event.keycode in [KEY_SPACE, KEY_PERIOD, KEY_F, KEY_R, KEY_TAB]: get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var best := 45.0
		for a in sim.animals:
			var p: Vector3 = proxies[a.id].position + Vector3.UP
			if camera.is_position_behind(p): continue
			var distance: float = camera.unproject_position(p).distance_to(event.position)
			if distance < best:
				best = distance
				selected = a.id
		_refresh_ui()

func _toggle() -> void:
	running = not running
	accumulator = 0.0
	if not running: _save()
	_refresh_ui()

func _step() -> void:
	running = false
	accumulator = 0.0
	sim.tick(DT)
	_sync_proxies()
	_save()
	_refresh_ui()

func _button(row: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	row.add_child(button)
	return button

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(margin)
	var outer := VBoxContainer.new()
	var theme := Theme.new()
	theme.default_font_size = 16
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.065, 0.075, 0.96)
	panel_style.set_content_margin_all(12)
	panel_style.set_corner_radius_all(6)
	theme.set_stylebox("panel", "PanelContainer", panel_style)
	theme.set_stylebox("panel", "ItemList", panel_style)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("203b40")
	button_style.set_content_margin_all(8)
	button_style.set_corner_radius_all(4)
	theme.set_stylebox("normal", "Button", button_style)
	var hover := button_style.duplicate()
	hover.bg_color = Color("39636a")
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", hover)
	outer.theme = theme
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(outer)
	var heading := Label.new()
	heading.text = "NORTH AMERICAN ECOSYSTEM   /   FOREST OBSERVATORY"
	heading.add_theme_font_size_override("font_size", 25)
	outer.add_child(heading)
	summary = Label.new()
	outer.add_child(summary)
	var row := HBoxContainer.new()
	outer.add_child(row)
	start_button = _button(row, "Start", _toggle)
	_button(row, "Step 0.1s", _step)
	var speed_select := OptionButton.new()
	for s in [1, 2, 5, 10]: speed_select.add_item(str(s) + "x")
	speed_select.item_selected.connect(func(i: int): speed = [1.0, 2.0, 5.0, 10.0][i])
	row.add_child(speed_select)
	_button(row, "Save", _save)
	_button(row, "Load", _load)
	var event_select := OptionButton.new()
	event_selector = event_select
	for e in ["normal", "drought", "wildfire", "flood"]: event_select.add_item(e.capitalize())
	event_select.item_selected.connect(func(i: int):
		sim.set_event(["normal", "drought", "wildfire", "flood"][i])
		if not running and not _save(): return
		status.text = "Event queued. Start or Step advances its effects."
		_refresh_ui()
	)
	row.add_child(event_select)
	confirm_reset = ConfirmationDialog.new()
	confirm_reset.title = "Create a new ecosystem?"
	confirm_reset.dialog_text = "The current ecosystem will be replaced. Its last checkpoint is retained as a backup."
	confirm_reset.confirmed.connect(_new_ecosystem)
	canvas.add_child(confirm_reset)
	_button(row, "New ecosystem", func():
		if running: _toggle()
		confirm_reset.popup_centered()
	)
	var options := HBoxContainer.new()
	outer.add_child(options)
	var sound := CheckButton.new()
	sound.text = "Forest sound"
	sound.button_pressed = sound_enabled
	sound.toggled.connect(func(enabled: bool):
		sound_enabled = enabled
		ambience.stream_paused = not enabled
		_save_preferences()
	)
	options.add_child(sound)
	var labels := CheckButton.new()
	labels.text = "Animal labels"
	labels.button_pressed = labels_visible
	labels.toggled.connect(func(enabled: bool):
		labels_visible = enabled
		_sync_proxies()
		_save_preferences()
	)
	options.add_child(labels)
	var resources_toggle := CheckButton.new()
	resources_toggle.text = "Resource markers"
	resources_toggle.button_pressed = resources_visible
	resources_toggle.toggled.connect(func(enabled: bool):
		resources_visible = enabled
		resource_view.visible = enabled
		_save_preferences()
	)
	options.add_child(resources_toggle)
	_button(options, "Recover backup", func(): _load(SAVE_PATH + ".bak"))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(spacer)
	var lower := HBoxContainer.new()
	lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(lower)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(370, 330)
	lower.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	inspection = RichTextLabel.new()
	inspection.custom_minimum_size = Vector2(370, 280)
	inspection.bbcode_enabled = true
	box.add_child(inspection)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	_button(actions, "Follow", func(): camera.follow_target = proxies.get(selected))
	_button(actions, "Focus", func():
		camera.follow_target = null
		if proxies.has(selected): camera.focus_position(proxies[selected].position)
	)
	_button(actions, "Free camera", func(): camera.follow_target = null)
	roster = ItemList.new()
	roster.custom_minimum_size = Vector2(220, 330)
	roster.item_selected.connect(func(i: int):
		selected = roster.get_item_metadata(i)
		_refresh_ui()
	)
	lower.add_child(roster)
	var horizontal_space := Control.new()
	horizontal_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	horizontal_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lower.add_child(horizontal_space)
	habitat_map = ObservationMap.new()
	habitat_map.simulation = sim
	habitat_map.size_flags_vertical = Control.SIZE_SHRINK_END
	habitat_map.location_chosen.connect(func(point: Vector3):
		camera.follow_target = null
		point.y = Forest.height_at(point.x, point.z)
		camera.focus_position(point)
	)
	lower.add_child(habitat_map)
	status = Label.new()
	status.text = "Ready. Simulation starts paused."
	outer.add_child(status)
	var help := Label.new()
	help.text = "RMB + WASD fly  •  Q/E vertical  •  Shift fast  •  F follow  •  R focus  •  Tab next animal  •  Space pause  •  . step"
	outer.add_child(help)

func _refresh_ui() -> void:
	if not is_instance_valid(summary): return
	forest.set_event(sim.environment_event)
	if sim.has_method("hazard_radius"): forest.set_event_progress(sim.hazard_radius(), sim.event_intensity)
	_sync_proxies()
	if sim.get("resources") != null: resource_view.sync(sim.resources)
	habitat_map.selected_id = selected
	habitat_map.camera_position = camera.position
	habitat_map.queue_redraw()
	var live := 0
	for a in sim.animals:
		if a.alive: live += 1
	summary.text = "%s   |   %.1f simulation seconds   |   %d living animals   |   %s   |   forage %.0f%%" % ["RUNNING" if running else "PAUSED", sim.elapsed, live, sim.environment_event.to_upper(), sim.forage]
	if sim.environment_event != "normal" and sim.has_method("hazard_radius"):
		summary.text += "   |   affected radius %.0fm · intensity %.1fx" % [sim.hazard_radius(), sim.event_intensity]
	start_button.text = "Pause & save" if running else "Start"
	event_selector.select(["normal", "drought", "wildfire", "flood"].find(sim.environment_event))
	roster.clear()
	for a in sim.animals:
		var i := roster.add_item("%s · %s" % [a.name, a.behavior])
		roster.set_item_metadata(i, a.id)
		if a.id == selected:
			roster.select(i)
			var traits: Dictionary = a.get("traits", {"boldness": 0.5, "endurance": 0.5})
			inspection.text = "[b]%s[/b]  /  %s\n%s   |   Target %s\n\nHunger %.0f%%   Thirst %.0f%%\nEnergy %.0f%%   Stamina %.0f%%\nAge %.1f days   |   Meals %d\nBoldness %.0f%%   Endurance %.0f%%\n\n[b]Recent experiences[/b]\n%s" % [a.name, a.species.capitalize(), a.behavior.capitalize(), str(a.target) if a.target != -1 else "none", a.hunger, a.get("thirst", 0), a.energy, a.stamina, a.age, a.meals, traits.boldness * 100, traits.endurance * 100, "\n".join(a.memories)]

func _new_ecosystem() -> void:
	running = false
	accumulator = 0.0
	if not _save(): return
	camera.follow_target = null
	for proxy in proxies.values(): proxy.queue_free()
	proxies.clear()
	sim.reset(42)
	selected = 1
	_sync_proxies()
	_save()
	_refresh_ui()

func _load_preferences() -> void:
	var preferences := ConfigFile.new()
	if preferences.load("user://settings.cfg") != OK: return
	for key in ["sound_enabled", "labels_visible", "resources_visible"]:
		if not preferences.has_section_key("observation", key): continue
		var value = preferences.get_value("observation", key)
		if value is bool: set(key, value)

func _save_preferences() -> void:
	var preferences := ConfigFile.new()
	for key in ["sound_enabled", "labels_visible", "resources_visible"]:
		preferences.set_value("observation", key, get(key))
	if preferences.save("user://settings.cfg") != OK:
		status.text = "Could not save observation preferences."

func _save() -> bool:
	var temp := SAVE_PATH + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		status.text = "Save failed: cannot open local file."
		return false
	file.store_string(JSON.stringify(sim.to_data(), "", true, true))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		status.text = "Save failed while writing. Previous save retained."
		return false
	if FileAccess.file_exists(SAVE_PATH):
		if DirAccess.copy_absolute(SAVE_PATH, SAVE_PATH + ".bak") != OK:
			status.text = "Cannot back up save. Previous save retained."
			return false
	var error := DirAccess.rename_absolute(temp, SAVE_PATH)
	status.text = "Saved locally." if error == OK else "Save failed; previous backup retained."
	return error == OK

func _load(path: String = SAVE_PATH) -> void:
	if not FileAccess.file_exists(path):
		status.text = "No local save yet."
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not sim.from_data(data):
		status.text = "Invalid save; current ecosystem preserved."
		return
	running = false
	accumulator = 0.0
	camera.follow_target = null
	for proxy in proxies.values(): proxy.queue_free()
	proxies.clear()
	selected = sim.animals[0].id
	_sync_proxies()
	status.text = "Loaded locally. Paused; no offline progression."
	_refresh_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		running = false
		if _save():
			ambience.stop()
			get_tree().quit()
