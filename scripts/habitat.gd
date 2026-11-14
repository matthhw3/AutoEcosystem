extends RefCounted
## Shared deterministic trunk geometry for rendering, movement, and perception.
## Cached records are read-only to callers. Heights are supplied by forest.gd.

const BOUND: float = 65.0
const BODY_RADIUS: float = 0.5
const CLEARANCE: float = 0.005
const CELL_SIZE: float = 8.0
static var _trees: Array = []
static var _obstacles: Array = []
static var _grid: Dictionary = {}
static var _decoration_state: int = 0

static func _generate() -> void:
	if not _trees.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 23119
	for index in range(440):
		var x: float = rng.randf_range(-69, 69)
		var z: float = rng.randf_range(-69, 69)
		if Vector2(x, z).length() < 18.0 or absf(x - sin(z * 0.04) * 12.0) < 3.5:
			continue
		if Vector2(x - 28, z - 28).length() < 12:
			continue
		var height: float = rng.randf_range(6, 12)
		_trees.append({"x": x, "z": z, "height": height, "index": index})
		_obstacles.append({"position": Vector3(x, 0, z), "radius": 0.3})
		var cell := Vector2i(floori(x / CELL_SIZE), floori(z / CELL_SIZE))
		if not _grid.has(cell):
			_grid[cell] = []
		_grid[cell].append(_obstacles.size() - 1)
	_decoration_state = rng.state

static func tree_records() -> Array:
	_generate()
	return _trees

static func obstacles() -> Array:
	_generate()
	return _obstacles

static func decoration_rng_state() -> int:
	_generate()
	return _decoration_state

static func _horizontal(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)

static func _candidates(from: Vector2, to: Vector2, margin: float) -> Array:
	_generate()
	var minimum := Vector2i(floori((minf(from.x, to.x) - margin) / CELL_SIZE), floori((minf(from.y, to.y) - margin) / CELL_SIZE))
	var maximum := Vector2i(floori((maxf(from.x, to.x) + margin) / CELL_SIZE), floori((maxf(from.y, to.y) + margin) / CELL_SIZE))
	var indices: Array = []
	for x in range(minimum.x, maximum.x + 1):
		for z in range(minimum.y, maximum.y + 1):
			var cell := Vector2i(x, z)
			if _grid.has(cell):
				indices.append_array(_grid[cell])
	# Stable original generation order preserves collision and tie decisions.
	indices.sort()
	var result: Array = []
	for index: int in indices:
		result.append(_obstacles[index])
	return result

static func _resolve_overlap(point: Vector2) -> Vector2:
	for pass_index in range(6):
		var changed: bool = false
		for obstacle: Dictionary in _candidates(point, point, 0.3 + BODY_RADIUS + CLEARANCE):
			var center := _horizontal(obstacle.position)
			var radius: float = float(obstacle.radius) + BODY_RADIUS + CLEARANCE
			var offset := point - center
			if offset.length_squared() < radius * radius - 0.000001:
				var normal := offset.normalized() if offset.length_squared() > 0.000001 else Vector2.RIGHT
				var resolved := center + normal * radius
				if absf(resolved.x) > BOUND or absf(resolved.y) > BOUND:
					resolved = center - center.normalized() * radius
				point = resolved
				changed = true
		if not changed:
			break
	return point.clamp(Vector2(-BOUND, -BOUND), Vector2(BOUND, BOUND))

static func visible(from: Vector3, to: Vector3) -> bool:
	var start := _horizontal(from)
	var movement := _horizontal(to) - start
	var length_squared: float = movement.length_squared()
	for obstacle: Dictionary in _candidates(start, start + movement, 0.3):
		var center := _horizontal(obstacle.position)
		var fraction: float = clampf((center - start).dot(movement) / length_squared, 0.0, 1.0) if length_squared > 0.000001 else 0.0
		if (start + movement * fraction).distance_squared_to(center) < pow(float(obstacle.radius), 2):
			return false
	return true

static func steer(position: Vector3, direction: Vector3, speed: float, dt: float) -> Vector3:
	if not position.is_finite() or not direction.is_finite() or not is_finite(speed) or not is_finite(dt):
		return position
	var point := _horizontal(position).clamp(Vector2(-BOUND, -BOUND), Vector2(BOUND, BOUND))
	# Recover safely if a loaded/teleported agent overlaps a trunk.
	point = _resolve_overlap(point)
	var desired := _horizontal(direction).normalized()
	var distance: float = maxf(0.0, speed) * maxf(0.0, dt)
	if distance == 0.0 or desired == Vector2.ZERO:
		return Vector3(point.x, position.y, point.y)
	# Look ahead for a trunk and pick a stable side, preventing head-on stalls.
	var nearest: float = 3.0
	var avoidance := Vector2.ZERO
	for obstacle: Dictionary in _candidates(point, point + desired * 3.0, 0.3 + BODY_RADIUS + 0.15):
		var toward := _horizontal(obstacle.position) - point
		var forward: float = toward.dot(desired)
		var lateral: float = absf(toward.cross(desired))
		var radius: float = float(obstacle.radius) + BODY_RADIUS + 0.15
		if forward > 0.0 and forward < nearest and lateral < radius:
			nearest = forward
			var side: float = 1.0 if desired.cross(toward) <= 0.0 else -1.0
			var tangent := Vector2(-toward.y, toward.x).normalized() * side
			avoidance = (desired * 0.35 + tangent * 0.9).normalized()
	if avoidance != Vector2.ZERO:
		desired = avoidance
	var remaining := desired * distance
	# Swept circles prohibit tunneling even for large tick distances.
	for iteration in range(6):
		remaining = (point + remaining).clamp(Vector2(-BOUND, -BOUND), Vector2(BOUND, BOUND)) - point
		var hit_time: float = 1.0
		var hit_center := Vector2.ZERO
		var collided: bool = false
		var a: float = remaining.length_squared()
		if a < 0.00000001:
			break
		for obstacle: Dictionary in _candidates(point, point + remaining, 0.3 + BODY_RADIUS + CLEARANCE):
			var center := _horizontal(obstacle.position)
			var radius: float = float(obstacle.radius) + BODY_RADIUS + CLEARANCE
			var offset := point - center
			var b: float = offset.dot(remaining)
			var c: float = offset.length_squared() - radius * radius
			var discriminant: float = b * b - a * c
			if b >= 0.0 or discriminant < 0.0:
				continue
			var candidate: float = (-b - sqrt(discriminant)) / a
			if candidate >= -0.00001 and candidate < hit_time:
				hit_time = maxf(candidate, 0.0)
				hit_center = center
				collided = true
		if not collided:
			point += remaining
			break
		point += remaining * maxf(0.0, hit_time - 0.0001)
		var normal := (point - hit_center).normalized()
		remaining *= 1.0 - hit_time
		remaining -= normal * minf(0.0, remaining.dot(normal))
	point = _resolve_overlap(point)
	return Vector3(point.x, position.y, point.y)
