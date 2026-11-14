extends RefCounted
## Deterministic routes over the same static trunks used by rendering and physics.
## Routes are advisory; Habitat.steer still owns physical movement and collision.
const Habitat = preload("res://scripts/habitat.gd")
const STEP := 2.0
const HALF := 64.0
const WIDTH := 65
const BUCKET_SIZE := 8.0
const ROUTE_MARGIN := 0.35
const CACHE_LIMIT := 256
static var _graph: AStar2D
static var _buckets: Dictionary = {}
static var _paths: Dictionary = {}

static func _ensure_obstacles() -> void:
	if not _buckets.is_empty(): return
	for obstacle: Dictionary in Habitat.obstacles():
		var key := Vector2i(floori(obstacle.position.x / BUCKET_SIZE), floori(obstacle.position.z / BUCKET_SIZE))
		if not _buckets.has(key): _buckets[key] = []
		_buckets[key].append(obstacle)

static func _clear_line(from: Vector3, to: Vector3, margin: float) -> bool:
	_ensure_obstacles()
	if not from.is_finite() or not to.is_finite(): return false
	if maxf(absf(from.x), absf(from.z)) > Habitat.BOUND or maxf(absf(to.x), absf(to.z)) > Habitat.BOUND: return false
	var clearance: float = 0.3 + Habitat.BODY_RADIUS + Habitat.CLEARANCE + margin
	var minimum := Vector2i(floori((minf(from.x, to.x) - clearance) / BUCKET_SIZE), floori((minf(from.z, to.z) - clearance) / BUCKET_SIZE))
	var maximum := Vector2i(floori((maxf(from.x, to.x) + clearance) / BUCKET_SIZE), floori((maxf(from.z, to.z) + clearance) / BUCKET_SIZE))
	var a := Vector2(from.x, from.z)
	var segment := Vector2(to.x - from.x, to.z - from.z)
	var length_squared: float = segment.length_squared()
	for x in range(minimum.x, maximum.x + 1):
		for z in range(minimum.y, maximum.y + 1):
			for obstacle: Dictionary in _buckets.get(Vector2i(x, z), []):
				var center := Vector2(obstacle.position.x, obstacle.position.z)
				var fraction: float = clampf((center - a).dot(segment) / length_squared, 0, 1) if length_squared > 0.00000001 else 0.0
				var radius: float = float(obstacle.radius) + Habitat.BODY_RADIUS + Habitat.CLEARANCE + margin
				# Vector3 stores single-precision coordinates; accept micron-scale
				# boundary rounding from Habitat's overlap projection, retaining its
				# explicit 5mm clearance above the physical body radius.
				if (a + segment * fraction).distance_squared_to(center) < radius * radius - 0.00001: return false
	return true

static func has_line(from: Vector3, to: Vector3) -> bool:
	return _clear_line(from, to, 0.0)

static func _point(id: int, y: float = 0.0) -> Vector3:
	return Vector3(-HALF + (id % WIDTH) * STEP, y, -HALF + floori(float(id) / WIDTH) * STEP)

static func _ensure_graph() -> void:
	if _graph != null: return
	_graph = AStar2D.new()
	for z in range(WIDTH):
		for x in range(WIDTH):
			var id: int = x + z * WIDTH
			var p := _point(id)
			if _clear_line(p, p, ROUTE_MARGIN): _graph.add_point(id, Vector2(p.x, p.z))
	for z in range(WIDTH):
		for x in range(WIDTH):
			var id: int = x + z * WIDTH
			if not _graph.has_point(id): continue
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
				var neighbor := Vector2i(x, z) + offset
				if neighbor.x < 0 or neighbor.x >= WIDTH or neighbor.y >= WIDTH: continue
				var other: int = neighbor.x + neighbor.y * WIDTH
				if _graph.has_point(other) and _clear_line(_point(id), _point(other), ROUTE_MARGIN):
					_graph.connect_points(id, other)

static func _attachment(point: Vector3) -> int:
	var center := Vector2i(roundi((point.x + HALF) / STEP), roundi((point.z + HALF) / STEP))
	var best := -1
	var best_distance := INF
	# A clear endpoint always attaches locally, or reports no usable route.
	for ring in range(5):
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if ring > 0 and maxi(absi(dx), absi(dz)) != ring: continue
				var x: int = center.x + dx
				var z: int = center.y + dz
				if x < 0 or z < 0 or x >= WIDTH or z >= WIDTH: continue
				var id: int = x + z * WIDTH
				if not _graph.has_point(id): continue
				var candidate := _point(id, point.y)
				var distance: float = point.distance_squared_to(candidate)
				if (distance < best_distance or (is_equal_approx(distance, best_distance) and id < best)) and has_line(point, candidate):
					best = id
					best_distance = distance
		if best >= 0 and best_distance <= pow(maxf(1, ring) * STEP, 2): break
	return best

static func route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not from.is_finite() or not to.is_finite(): return result
	if maxf(absf(from.x), absf(from.z)) > Habitat.BOUND or maxf(absf(to.x), absf(to.z)) > Habitat.BOUND: return result
	# The collision resolver can recover overlapping saved/spawn positions. Route
	# endpoints are projected onto free space; no animal is teleported by this module.
	var start: Vector3 = Habitat.steer(from, Vector3.ZERO, 0, 0)
	var goal: Vector3 = Habitat.steer(to, Vector3.ZERO, 0, 0)
	if has_line(start, goal):
		result.append(start)
		result.append(goal)
		return result
	_ensure_graph()
	var first: int = _attachment(start)
	var last: int = _attachment(goal)
	if first < 0 or last < 0: return result
	var key := Vector2i(first, last)
	if not _paths.has(key):
		if _paths.size() >= CACHE_LIMIT: _paths.erase(_paths.keys()[0])
		_paths[key] = _graph.get_id_path(first, last)
	var ids: PackedInt64Array = _paths[key]
	if ids.is_empty(): return result
	var unsmoothed: Array[Vector3] = [start]
	for id: int in ids: unsmoothed.append(_point(id, from.y))
	unsmoothed.append(Vector3(goal.x, from.y, goal.z))
	# Keep only corners with generous trunk clearance. This avoids giving the
	# local anticipatory steering tiny waypoints beside the very same trunk.
	var cursor := 0
	result.append(start)
	while cursor < unsmoothed.size() - 1:
		var next: int = cursor + 1
		for candidate in range(unsmoothed.size() - 1, cursor, -1):
			if _clear_line(unsmoothed[cursor], unsmoothed[candidate], ROUTE_MARGIN):
				next = candidate
				break
		result.append(unsmoothed[next])
		cursor = next
	return result

static func waypoint(from: Vector3, to: Vector3) -> Vector3:
	var path: Array[Vector3] = route(from, to)
	return path[1] if path.size() > 1 else from
