extends SceneTree
const Navigation = preload("res://scripts/navigation.gd")
const Habitat = preload("res://scripts/habitat.gd")
var failures := 0

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func brute_body_line(from: Vector3, to: Vector3) -> bool:
	var a := Vector2(from.x, from.z)
	var movement := Vector2(to.x - from.x, to.z - from.z)
	var length_squared: float = movement.length_squared()
	for obstacle: Dictionary in Habitat.obstacles():
		var center := Vector2(obstacle.position.x, obstacle.position.z)
		var fraction: float = clampf((center - a).dot(movement) / length_squared, 0, 1) if length_squared > 0.0000001 else 0.0
		var radius: float = float(obstacle.radius) + Habitat.BODY_RADIUS + Habitat.CLEARANCE - 0.00001
		if (a + movement * fraction).distance_squared_to(center) < radius * radius: return false
	return true

func _initialize() -> void:
	var started: int = Time.get_ticks_msec()
	var start := Vector3(30.36529, 0, -3.36345)
	var goal := Vector3(12, 0, -15)
	var path: Array[Vector3] = Navigation.route(start, goal)
	print("Seed7 water regression route: ", path)
	check(path.size() > 2, "Known resource stall gets a route around its trunk cluster")
	check(path == Navigation.route(start, goal), "Route choice is deterministic")
	for index in range(path.size() - 1): check(brute_body_line(path[index], path[index + 1]), "Route segments retain full animal-body clearance")
	var point: Vector3 = start
	var steps := 0
	while point.distance_to(goal) > 1.0 and steps < 2400:
		var target: Vector3 = Navigation.waypoint(point, goal)
		point = Habitat.steer(point, target - point, 2.4, 0.1)
		check(brute_body_line(point, point), "Route following never penetrates a trunk")
		steps += 1
	print("Seed7 water route-follow arrival: ", point, " steps=", steps)
	check(point.distance_to(goal) <= 1.0, "Physical local steering follows global route out of the known resource stall")
	var random := RandomNumberGenerator.new()
	random.seed = 712091
	for sample in range(60):
		var from: Vector3 = Habitat.steer(Vector3(random.randf_range(-64, 64), 0, random.randf_range(-64, 64)), Vector3.ZERO, 0, 0)
		var to: Vector3 = Habitat.steer(Vector3(random.randf_range(-64, 64), 0, random.randf_range(-64, 64)), Vector3.ZERO, 0, 0)
		var route: Array[Vector3] = Navigation.route(from, to)
		if route.is_empty(): print("No route sample=", sample, " from=", from, " to=", to, " attachments=", Navigation._attachment(from), ",", Navigation._attachment(to), " endpoint_clear=", Navigation.has_line(from, from), ",", Navigation.has_line(to, to))
		check(not route.is_empty(), "Open forest endpoints have a bounded route")
		check(route == Navigation.route(from, to), "Cached route agrees with first deterministic query")
		for index in range(route.size() - 1):
			check(brute_body_line(route[index], route[index + 1]), "Random route cannot cut through trunk/body geometry")
			check(absf(route[index].x) <= 65 and absf(route[index].z) <= 65, "Route stays inside world bounds")
	for sample in range(16):
		var destination := Vector3(12, 0, -15) if sample % 2 == 0 else Vector3(-28, 0, 18)
		var traveler: Vector3 = Habitat.steer(Vector3(random.randf_range(-64, 64), 0, random.randf_range(-64, 64)), Vector3.ZERO, 0, 0)
		var traveled_steps := 0
		while traveler.distance_to(destination) > 2.5 and traveled_steps < 2000:
			var next: Vector3 = Navigation.waypoint(traveler, destination)
			traveler = Habitat.steer(traveler, next - traveler, 2.4, 0.1)
			if traveled_steps % 10 == 0: check(brute_body_line(traveler, traveler), "Resource route-following retains physical clearance")
			traveled_steps += 1
		if traveler.distance_to(destination) > 2.5: print("RESOURCE_ROUTE_FAILURE sample=", sample, " point=", traveler, " goal=", destination)
		check(traveler.distance_to(destination) <= 2.5, "Random forest travelers can physically reach known drinking sites")
	var trunk: Vector3 = Habitat.obstacles()[0].position
	var projected: Array[Vector3] = Navigation.route(Vector3.ZERO, trunk)
	check(not projected.is_empty() and brute_body_line(projected.back(), projected.back()), "Overlapping goal projects to physically reachable free space")
	check(Navigation.route(Vector3.ZERO, Vector3(1000, 0, 0)).is_empty(), "Impossible out-of-world destination reports no route")
	check(Navigation.waypoint(Vector3.ZERO, Vector3(1000, 0, 0)) == Vector3.ZERO, "Impossible destination never teleports or invents motion")
	check(Navigation._paths.size() <= Navigation.CACHE_LIMIT, "Route cache stays bounded")
	print("Navigation tests: %d failure(s), %.2fs" % [failures, (Time.get_ticks_msec() - started) / 1000.0])
	quit(0 if failures == 0 else 1)
