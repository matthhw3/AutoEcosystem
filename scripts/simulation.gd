extends RefCounted
## Pure simulation state. Rendering and wall-clock time never drive this directly.

const SAVE_VERSION = 1
const BOUNDS = 65.0
const MAX_POPULATION = 36
var animals: Array = []
var elapsed: float = 0.0
var environment_event: String = "normal"
var forage: float = 100.0
var rng = RandomNumberGenerator.new()
var next_id: int = 1

func reset(world_seed: int = 42) -> void:
	rng.seed = world_seed
	animals.clear()
	elapsed = 0.0
	forage = 100.0
	environment_event = "normal"
	next_id = 1
	_spawn("wolf", Vector3(-12, 0, -8))
	for i in range(6):
		_spawn("deer", Vector3(8 + i * 4, 0, rng.randf_range(-14, 14)))

func _spawn(species: String, position: Vector3) -> void:
	position.x = clampf(position.x, -BOUNDS, BOUNDS)
	position.z = clampf(position.z, -BOUNDS, BOUNDS)
	var animal: Dictionary = {
		"id": next_id, "name": ("Wolf " if species == "wolf" else "Deer ") + str(next_id),
		"species": species, "position": position, "heading": rng.randf_range(-PI, PI),
		"hunger": 64.0 if species == "wolf" else rng.randf_range(20, 45),
		"energy": 90.0, "stamina": 100.0, "age": 700.0, "alive": true,
		"behavior": "Observing", "memories": ["Entered the forest"], "target": -1,
		"fear": 0.0, "danger_position": position, "birth_cooldown": 180.0,
		"wander_time": 0.0, "meals": 0
	}
	next_id += 1
	animals.append(animal)

func set_event(event: String) -> void:
	if event not in ["normal", "drought", "wildfire", "flood"]:
		return
	environment_event = event
	for animal in animals:
		if animal.alive:
			_remember(animal, "Environment changed: " + event)

func tick(dt: float) -> void:
	if not is_finite(dt) or dt <= 0.0:
		return
	# Small internal substeps preserve steering and capture checks at high UI speeds.
	var remaining: float = minf(dt, 60.0)
	while remaining > 0.000001:
		var step: float = minf(remaining, 0.1)
		_tick_step(step)
		remaining -= step

func _tick_step(dt: float) -> void:
	elapsed += dt
	forage = clampf(forage + dt * (0.15 if environment_event == "normal" else -0.22), 0, 100)
	var newborns: Array = []
	for animal in animals:
		if not animal.alive:
			continue
		animal.age += dt / 1200.0
		animal.birth_cooldown = maxf(0, animal.birth_cooldown - dt)
		animal.hunger = minf(100, animal.hunger + dt * (0.075 if animal.species == "wolf" else 0.055))
		animal.energy = maxf(0, animal.energy - dt * 0.012)
		animal.fear = maxf(0, animal.fear - dt * 0.05)
		if animal.hunger >= 100 or animal.age > (5000 if animal.species == "wolf" else 6500):
			_die(animal, "Starvation" if animal.hunger >= 100 else "Old age")
			continue
		if environment_event == "wildfire" and animal.position.length() < 15:
			animal.energy = maxf(0, animal.energy - dt * 0.7)
			if animal.energy <= 0:
				_die(animal, "Wildfire exposure")
				continue
		if animal.species == "deer":
			_deer_decision(animal, dt)
		else:
			_wolf_decision(animal, dt)
		if animal.alive and animal.hunger < 35 and animal.energy > 65 and animal.birth_cooldown <= 0:
			var mate = _nearest(animal, animal.species, 12.0)
			if mate != null and mate.birth_cooldown <= 0 and mate.hunger < 40 and animals.size() + newborns.size() < MAX_POPULATION:
				newborns.append({"species": animal.species, "position": animal.position + Vector3(1, 0, 1)})
				animal.birth_cooldown = 300.0
				mate.birth_cooldown = 300.0
				animal.energy -= 15
				_remember(animal, "A new offspring was born")
	for birth in newborns:
		_spawn(birth.species, birth.position)
		animals.back().age = 0.0
		animals.back().birth_cooldown = 600.0
		animals.back().memories = ["Born in this forest"]

func _deer_decision(animal: Dictionary, dt: float) -> void:
	var predator = _nearest(animal, "wolf", 24.0 + animal.fear * 0.08)
	var hazard: bool = environment_event in ["wildfire", "flood"] and animal.position.length() < 22
	if predator != null or hazard:
		var threat: Vector3 = predator.position if predator != null else Vector3.ZERO
		animal.target = predator.id if predator != null else -1
		if animal.behavior != "Fleeing":
			_remember(animal, "Detected a wolf; fleeing" if predator != null else "Fled an environmental hazard")
		animal.danger_position = threat
		animal.fear = 100.0
		_set_behavior(animal, "Fleeing")
		_move(animal, animal.position - threat, 7.0 if animal.stamina > 5 else 2.4, dt, true)
	elif animal.energy < 30 or (animal.behavior == "Resting" and animal.energy < 80):
		_rest(animal, dt)
	elif animal.hunger > 18 and forage > 2:
		_set_behavior(animal, "Grazing")
		animal.hunger = maxf(0, animal.hunger - dt * 0.7 * forage / 100.0)
		forage = maxf(0, forage - dt * 0.02)
		animal.stamina = minf(100, animal.stamina + dt * 1.8)
		animal.energy = minf(100, animal.energy + dt * 0.1)
	else:
		_wander(animal, dt)

func _wolf_decision(animal: Dictionary, dt: float) -> void:
	if environment_event in ["wildfire", "flood"] and animal.position.length() < 22:
		_set_behavior(animal, "Fleeing hazard")
		_move(animal, animal.position, 6.5, dt, true)
		return
	if animal.energy < 25 or animal.stamina < 5 or (animal.behavior == "Resting" and (animal.energy < 75 or animal.stamina < 85)):
		_rest(animal, dt)
		return
	var prey = _nearest(animal, "deer", 40.0)
	if animal.hunger > 38 and prey != null:
		_set_behavior(animal, "Hunting")
		animal.target = prey.id
		_move(animal, prey.position - animal.position, 7.5, dt, true)
		if animal.position.distance_to(prey.position) < 1.6:
			_die(prey, "Caught by " + animal.name)
			animal.hunger = maxf(0, animal.hunger - 70)
			animal.energy = minf(100, animal.energy + 15)
			animal.meals += 1
			_remember(animal, "Successful hunt: " + prey.name)
			_set_behavior(animal, "Feeding")
	else:
		_wander(animal, dt)

func _nearest(animal: Dictionary, species: String, radius: float):
	var closest = null
	var distance: float = radius
	for other in animals:
		if other.id == animal.id or not other.alive or other.species != species:
			continue
		var candidate: float = animal.position.distance_to(other.position)
		if candidate < distance:
			distance = candidate
			closest = other
	return closest

func _rest(animal: Dictionary, dt: float) -> void:
	_set_behavior(animal, "Resting")
	animal.energy = minf(100, animal.energy + dt * 0.8)
	animal.stamina = minf(100, animal.stamina + dt * 2.8)

func _wander(animal: Dictionary, dt: float) -> void:
	_set_behavior(animal, "Wandering")
	animal.wander_time -= dt
	if animal.wander_time <= 0:
		animal.heading += rng.randf_range(-1.4, 1.4)
		animal.wander_time = rng.randf_range(2, 6)
	var direction = Vector3(sin(animal.heading), 0, cos(animal.heading))
	# Learned danger influences later travel even when no predator is visible.
	if animal.species == "deer" and animal.fear > 5 and animal.position.distance_to(animal.danger_position) < 30:
		direction += (animal.position - animal.danger_position).normalized() * animal.fear / 50.0
	if animal.position.length() > 52:
		direction -= animal.position.normalized() * 2
	_move(animal, direction, 1.5, dt, false)

func _move(animal: Dictionary, direction: Vector3, speed: float, dt: float, sprint: bool) -> void:
	if direction.length_squared() < 0.0001:
		direction = Vector3.RIGHT
	direction = direction.normalized()
	animal.heading = atan2(direction.x, direction.z)
	animal.position += direction * speed * dt
	animal.position.x = clampf(animal.position.x, -BOUNDS, BOUNDS)
	animal.position.z = clampf(animal.position.z, -BOUNDS, BOUNDS)
	animal.energy = maxf(0, animal.energy - dt * (0.11 if sprint else 0.025))
	animal.stamina = clampf(animal.stamina + dt * (-1.7 if sprint else 1.2), 0, 100)

func _set_behavior(animal: Dictionary, value: String) -> void:
	animal.behavior = value
	if value not in ["Hunting", "Fleeing"]:
		animal.target = -1

func _remember(animal: Dictionary, message: String) -> void:
	animal.memories.append("%ds: %s" % [int(elapsed), message])
	while animal.memories.size() > 8:
		animal.memories.pop_front()

func _die(animal: Dictionary, cause: String) -> void:
	animal.alive = false
	animal.behavior = "Dead — " + cause
	animal.target = -1
	_remember(animal, cause)

func to_data() -> Dictionary:
	var records: Array = []
	for animal in animals:
		var record: Dictionary = animal.duplicate(true)
		for key in ["position", "danger_position"]:
			var p: Vector3 = animal[key]
			record[key] = [p.x, p.y, p.z]
		records.append(record)
	return {"version": SAVE_VERSION, "elapsed": elapsed, "forage": forage,
		"environment_event": environment_event, "next_id": next_id,
		"rng_seed": str(rng.seed), "rng_state": str(rng.state), "animals": records}

func from_data(data: Dictionary) -> bool:
	# Validate every field before mutating the running ecosystem.
	if data.get("version") != SAVE_VERSION or not data.get("animals") is Array:
		return false
	if data.animals.size() < 1 or data.animals.size() > MAX_POPULATION:
		return false
	if data.get("environment_event") not in ["normal", "drought", "wildfire", "flood"]:
		return false
	for key in ["elapsed", "forage", "next_id"]:
		if not _number(data.get(key)) or data[key] < 0:
			return false
	if data.forage > 100 or data.next_id < 1 or data.next_id != int(data.next_id):
		return false
	for key in ["rng_seed", "rng_state"]:
		if not data.get(key) is String or not data[key].is_valid_int():
			return false
	var restored: Array = []
	var ids: Array = []
	for raw in data.animals:
		if not raw is Dictionary:
			return false
		var animal: Dictionary = raw.duplicate(true)
		if animal.get("species") not in ["wolf", "deer"] or not animal.get("alive") is bool:
			return false
		for key in ["name", "behavior"]:
			if not animal.get(key) is String or animal[key].length() > 200:
				return false
		for key in ["hunger", "energy", "stamina", "fear"]:
			if not _number(animal.get(key)) or animal[key] < 0 or animal[key] > 100:
				return false
		for key in ["id", "target", "age", "heading", "birth_cooldown", "wander_time", "meals"]:
			if not _number(animal.get(key)):
				return false
		if animal.id < 1 or animal.id >= data.next_id or animal.id != int(animal.id) or int(animal.id) in ids or animal.age < 0 or animal.birth_cooldown < 0 or animal.meals < 0:
			return false
		if animal.target != int(animal.target) or animal.target < -1 or animal.meals != int(animal.meals):
			return false
		ids.append(int(animal.id))
		animal.id = int(animal.id)
		animal.target = int(animal.target)
		animal.meals = int(animal.meals)
		if not animal.get("memories") is Array or animal.memories.size() > 8:
			return false
		for memory in animal.memories:
			if not memory is String or memory.length() > 300:
				return false
		for key in ["position", "danger_position"]:
			var p = animal.get(key)
			if not p is Array or p.size() != 3:
				return false
			for coordinate in p:
				if not _number(coordinate) or absf(coordinate) > 10000:
					return false
			animal[key] = Vector3(p[0], p[1], p[2])
		if absf(animal.position.x) > BOUNDS or absf(animal.position.z) > BOUNDS or animal.position.y != 0:
			return false
		restored.append(animal)
	for animal in restored:
		if animal.target != -1 and animal.target not in ids:
			return false
	animals = restored
	elapsed = float(data.elapsed)
	forage = float(data.forage)
	next_id = int(data.next_id)
	environment_event = data.environment_event
	rng.seed = data.rng_seed.to_int()
	rng.state = data.rng_state.to_int()
	return true

func _number(value) -> bool:
	return (value is float or value is int) and is_finite(float(value))

