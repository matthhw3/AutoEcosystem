extends SceneTree

const Habitat = preload("res://scripts/habitat.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func clear_of_trunks(point: Vector3) -> bool:
	for obstacle: Dictionary in Habitat.obstacles():
		var offset := Vector2(point.x - obstacle.position.x, point.z - obstacle.position.z)
		if offset.length() < float(obstacle.radius) + Habitat.BODY_RADIUS - 0.001:
			return false
	return true

func brute_visible(from: Vector3, to: Vector3) -> bool:
	var start := Vector2(from.x, from.z)
	var movement := Vector2(to.x, to.z) - start
	var length_squared: float = movement.length_squared()
	for obstacle: Dictionary in Habitat.obstacles():
		var center := Vector2(obstacle.position.x, obstacle.position.z)
		var fraction: float = clampf((center - start).dot(movement) / length_squared, 0, 1) if length_squared > 0.000001 else 0.0
		if (start + movement * fraction).distance_squared_to(center) < pow(float(obstacle.radius), 2):
			return false
	return true

func _initialize() -> void:
	check(Habitat.tree_records().size() > 250, "Forest contains trees")
	check(Habitat.tree_records().size() == Habitat.obstacles().size(), "Every rendered trunk has an obstacle")
	# Independent replay proves the shared records preserve original procedural placement.
	var rng := RandomNumberGenerator.new()
	rng.seed = 23119
	var expected: Array = []
	for index in range(440):
		var x: float = rng.randf_range(-69, 69)
		var z: float = rng.randf_range(-69, 69)
		if Vector2(x,z).length() < 18 or absf(x - sin(z * 0.04) * 12) < 3.5 or Vector2(x - 28,z - 28).length() < 12:
			continue
		expected.append({"x": x, "z": z, "height": rng.randf_range(6,12), "index": index})
	check(expected == Habitat.tree_records(), "Tree positions match original seed exactly")
	check(rng.state == Habitat.decoration_rng_state(), "Decoration RNG continuity preserved")
	var center := Vector3.ZERO
	for obstacle: Dictionary in Habitat.obstacles():
		if absf(obstacle.position.x) < 50 and absf(obstacle.position.z) < 50:
			center = obstacle.position
			break
	check(not Habitat.visible(center - Vector3(2,0,0), center + Vector3(2,0,0)), "Trunk occludes crossing sight line")
	check(Habitat.visible(Vector3.ZERO, Vector3(5,0,5)), "Clearing sight line is unobstructed")
	check(not Habitat.visible(center, center), "Inside-trunk sight origin is occluded")
	var start := center - Vector3(5,0,0)
	var crossed: Vector3 = Habitat.steer(start, Vector3.RIGHT, 20.0, 1.0)
	check(clear_of_trunks(crossed), "Swept movement cannot tunnel through trunks")
	check(crossed.x < center.x, "Direct long crossing stops on near side of trunk")
	var point := center - Vector3(2,0,0)
	var replay := point
	for step in range(200):
		point = Habitat.steer(point, Vector3.RIGHT, 3.0, 0.05)
		replay = Habitat.steer(replay, Vector3.RIGHT, 3.0, 0.05)
		check(point == replay, "Avoidance deterministic")
		check(clear_of_trunks(point), "Avoidance maintains body clearance")
		check(absf(point.x) <= 65 and absf(point.z) <= 65, "Avoidance bounded")
	check(point.distance_to(center) > 2, "Head-on avoidance makes progress around tree")
	var recovered: Vector3 = Habitat.steer(center, Vector3.ZERO, 0, 0)
	check(clear_of_trunks(recovered), "Overlapping spawn recovers safely")
	var random := RandomNumberGenerator.new()
	random.seed = 8291
	for step in range(300):
		point = Vector3(random.randf_range(-65,65), 0, random.randf_range(-65,65))
		var direction := Vector3(random.randf_range(-1,1),0,random.randf_range(-1,1))
		point = Habitat.steer(point, direction, 25, 1)
		check(clear_of_trunks(point), "Random long movement nonpenetrating")
		check(absf(point.x) <= 65 and absf(point.z) <= 65, "Random movement bounded")
	for step in range(500):
		var sight_start := Vector3(random.randf_range(-69,69), 0, random.randf_range(-69,69))
		var sight_end := Vector3(random.randf_range(-69,69), 0, random.randf_range(-69,69))
		check(Habitat.visible(sight_start,sight_end) == brute_visible(sight_start,sight_end), "Grid sight matches full geometry scan")
	# Segment queries on cell borders retain blockers and original index order.
	for coordinate in range(-8, 9):
		var query_start := Vector2(coordinate * 8.0, -64)
		var query_end := Vector2(coordinate * 8.0, 64)
		var candidates: Array = Habitat._candidates(query_start,query_end,0.805)
		var previous: int = -1
		for obstacle: Dictionary in candidates:
			var index: int = Habitat.obstacles().find(obstacle)
			check(index > previous, "Grid candidates preserve original order without duplicates")
			previous = index
		for obstacle: Dictionary in Habitat.obstacles():
			if absf(obstacle.position.x - query_start.x) <= 0.805 and absf(obstacle.position.z) <= 64.805:
				check(candidates.has(obstacle), "Grid includes all swept-boundary blockers")
	var started: int = Time.get_ticks_usec()
	point = Vector3(20,0,20)
	for step in range(10000):
		var angle: float = float(step) * 0.013
		var direction := Vector3(cos(angle),0,sin(angle))
		point = Habitat.steer(point,direction,5.0,0.1)
		Habitat.visible(point,point + direction * 22.0)
	print("Habitat 10,000 steer + sight queries: %.3fs" % ((Time.get_ticks_usec() - started) / 1000000.0))
	print("Habitat tests: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
