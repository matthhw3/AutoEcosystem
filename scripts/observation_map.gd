extends Control
## Observer-only map. Input moves the camera; it never mutates the ecosystem.
signal location_chosen(point: Vector3)
var simulation
var selected_id := 1
var camera_position := Vector3.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(240, 260)
	tooltip_text = "Click the habitat map to move the observer camera. Gold: selected animal; red: wolf; cream: deer; blue: water; green: meadow."

func project_point(point: Vector3) -> Vector2:
	return Vector2(12, 38) + Vector2(point.x + 72, point.z + 72) / 144.0 * Vector2(size.x - 24, size.y - 70)

func _draw() -> void:
	draw_style_box(_panel(), Rect2(Vector2.ZERO, size))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(14, 25), "HABITAT MAP   /   N ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("c5d8d4"))
	var area := Rect2(Vector2(12, 38), Vector2(size.x - 24, size.y - 70))
	draw_rect(area, Color("233b2f"))
	for index in range(1, 4):
		var x: float = area.position.x + area.size.x * index / 4.0
		var y: float = area.position.y + area.size.y * index / 4.0
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color(0.7, 0.8, 0.7, 0.12))
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(0.7, 0.8, 0.7, 0.12))
	if simulation != null:
		if simulation.environment_event in ["flood", "wildfire"]:
			var radius: float = simulation.hazard_radius() if simulation.has_method("hazard_radius") else 22.0
			draw_circle(project_point(Vector3.ZERO), area.size.x * radius / 144.0, Color(0.9, 0.3, 0.1, 0.3) if simulation.environment_event == "wildfire" else Color(0.2, 0.6, 0.8, 0.4))
		for resource in simulation.get("resources") if simulation.get("resources") != null else []:
			draw_circle(project_point(resource.position), 4, Color("67b6cf") if resource.kind == "water" else Color("88ba66"))
		for animal in simulation.animals:
			var point := project_point(animal.position)
			var color := Color("df856b") if animal.species == "wolf" else Color("dbc5a2")
			if not animal.alive: color = Color("626d66")
			draw_circle(point, 3, color)
			if animal.id == selected_id: draw_arc(point, 6, 0, TAU, 20, Color("f8da88"), 2)
	var eye := project_point(camera_position)
	draw_line(eye - Vector2(4, 0), eye + Vector2(4, 0), Color.WHITE, 1.5)
	draw_line(eye - Vector2(0, 4), eye + Vector2(0, 4), Color.WHITE, 1.5)
	draw_string(font, Vector2(14, size.y - 12), "Click to explore • 144 × 144 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("a7bbb5"))

func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.065, 0.075, 0.96)
	style.set_corner_radius_all(6)
	return style

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var normalized: Vector2 = (event.position - Vector2(12, 38)) / Vector2(size.x - 24, size.y - 70)
		if normalized.x >= 0 and normalized.x <= 1 and normalized.y >= 0 and normalized.y <= 1:
			location_chosen.emit(Vector3(normalized.x * 144 - 72, 0, normalized.y * 144 - 72))
		accept_event()
