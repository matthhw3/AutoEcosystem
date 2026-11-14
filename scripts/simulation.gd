extends RefCounted
## Pure simulation state. Rendering and wall-clock time never drive this directly.
const Habitat = preload("res://scripts/habitat.gd")

const SAVE_VERSION = 2
const BOUNDS = 65.0
const MAX_POPULATION = 36
const MAX_RECORDS = 128
const MATURITY_DAYS = {"deer": 365.0, "wolf": 730.0}
# A three-wolf pack needs fewer large carcasses than three independent daily meals.
# Rates are compressed observation pacing, not scientific metabolic estimates.
const WOLF_HUNGER_RATE = 0.025
var animals: Array = []
var resources: Array = []
var elapsed: float = 0.0
var environment_event: String = "normal"
var forage: float = 100.0
var rng = RandomNumberGenerator.new()
var next_id: int = 1

func reset(world_seed: int = 42) -> void:
	rng.seed = world_seed
	animals.clear()
	resources = _default_resources()
	elapsed = 0.0
	forage = 100.0
	environment_event = "normal"
	next_id = 1
	_spawn("wolf", Vector3(-12, 0, -8))
	for i in range(6):
		_spawn("deer", Vector3(8 + i * 4, 0, rng.randf_range(-14, 14)))
	_spawn("wolf", Vector3(-18, 0, -9))
	_spawn("wolf", Vector3(-20, 0, -12))

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
		"wander_time": 0.0, "meals": 0, "thirst": 15.0,
		"traits": {"boldness": rng.randf_range(0.1, 0.9), "endurance": rng.randf_range(0.1, 0.9)},
		"food_memory": [], "water_memory": []
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
	_update_resources(dt)
	var newborns: Array = []
	for animal in animals:
		if not animal.alive:
			continue
		animal.age += dt / 1200.0
		animal.birth_cooldown = maxf(0, animal.birth_cooldown - dt)
		animal.hunger = minf(100, animal.hunger + dt * (WOLF_HUNGER_RATE if animal.species == "wolf" else 0.055))
		animal.thirst = minf(100, animal.thirst + dt * (0.11 if environment_event == "drought" else 0.035))
		_perceive_resources(animal)
		animal.energy = maxf(0, animal.energy - dt * 0.012)
		animal.fear = maxf(0, animal.fear - dt * 0.05)
		if animal.hunger >= 100 or animal.thirst >= 100 or animal.age > (5000 if animal.species == "wolf" else 6500):
			_die(animal, "Starvation" if animal.hunger >= 100 else ("Dehydration" if animal.thirst >= 100 else "Old age"))
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
		if animal.alive and animal.age >= MATURITY_DAYS[animal.species] and animal.hunger < 35 and animal.energy > 65 and animal.birth_cooldown <= 0:
			var mate = _nearest_mate(animal, 12.0)
			if mate != null and living_count() + newborns.size() < MAX_POPULATION:
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
	_prune_archive()

func _deer_decision(animal: Dictionary, dt: float) -> void:
	var predator = _nearest(animal, "wolf", 29.0 - animal.traits.boldness * 8.0 + animal.fear * 0.08)
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
	elif (animal.thirst > 55 or (animal.behavior == "Drinking" and animal.thirst > 15)) and _seek_resource(animal, "water", dt):
		pass
	elif animal.hunger > 18 and _seek_resource(animal, "meadow", dt):
		pass
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
	if (animal.thirst > 55 or (animal.behavior == "Drinking" and animal.thirst > 15)) and _seek_resource(animal, "water", dt):
		return
	var prey = _pack_target(animal)
	if prey == null:
		prey = _nearest(animal, "deer", 40.0)
	if animal.hunger > 38 and prey != null:
		_set_behavior(animal, "Hunting")
		animal.target = prey.id
		_move(animal, prey.position - animal.position, 7.5, dt, true)
		if animal.position.distance_to(prey.position) < 1.6:
			_die(prey, "Caught by " + animal.name)
			_share_food(animal, prey)
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
		if candidate < distance and Habitat.visible(animal.position, other.position):
			distance = candidate
			closest = other
	return closest

func _nearest_mate(animal: Dictionary, radius: float):
	var closest = null
	var distance: float = radius
	for other in animals:
		if other.id == animal.id or not other.alive or other.species != animal.species:
			continue
		if other.age < MATURITY_DAYS[other.species] or other.birth_cooldown > 0 or other.hunger >= 40 or other.energy <= 65:
			continue
		var candidate: float = animal.position.distance_to(other.position)
		if candidate < distance:
			distance = candidate
			closest = other
	return closest

func _default_resources() -> Array:
	return [
		{"id": 1, "kind": "meadow", "position": Vector3(16, 0, 8), "biomass": 100.0},
		{"id": 2, "kind": "meadow", "position": Vector3(-30, 0, 28), "biomass": 100.0},
		{"id": 3, "kind": "meadow", "position": Vector3(38, 0, -30), "biomass": 100.0},
		{"id": 4, "kind": "water", "position": Vector3(12, 0, -15), "biomass": 100.0},
		{"id": 5, "kind": "water", "position": Vector3(-28, 0, 18), "biomass": 100.0}
	]

func _update_resources(dt: float) -> void:
	var meadow_total: float = 0.0
	var meadow_count: int = 0
	for patch in resources:
		var rate: float = 0.07 if patch.kind == "meadow" else 0.1
		if environment_event == "drought": rate = -0.12
		if environment_event == "wildfire" and patch.position.length() < 30: rate = -0.6
		if environment_event == "flood": rate = -0.2 if patch.kind == "meadow" else 0.4
		patch.biomass = clampf(patch.biomass + rate * dt, 0, 100)
		if patch.kind == "meadow":
			meadow_total += patch.biomass
			meadow_count += 1
	forage = meadow_total / maxf(1, meadow_count)

func _perceive_resources(animal: Dictionary) -> void:
	for patch in resources:
		var key: String = "water_memory" if patch.kind == "water" else "food_memory"
		if patch.id in animal[key]: continue
		if animal.position.distance_to(patch.position) > 28 or not Habitat.visible(animal.position, patch.position):
			continue
		animal[key].append(patch.id)
		_remember(animal, "Discovered " + patch.kind + " #" + str(patch.id))

func _seek_resource(animal: Dictionary, kind: String, dt: float) -> bool:
	var key: String = "water_memory" if kind == "water" else "food_memory"
	var destination = null
	var best: float = INF
	for patch in resources:
		if patch.kind != kind or patch.biomass <= 1 or patch.id not in animal[key]: continue
		var distance: float = animal.position.distance_to(patch.position)
		if distance < best:
			best = distance
			destination = patch
	if destination == null: return false
	if best > 3.0:
		_set_behavior(animal, "Seeking water" if kind == "water" else "Seeking forage")
		_move(animal, destination.position - animal.position, 2.4, dt, false)
	else:
		_set_behavior(animal, "Drinking" if kind == "water" else "Grazing")
		if kind == "water":
			animal.thirst = maxf(0, animal.thirst - dt * 5)
		else:
			animal.hunger = maxf(0, animal.hunger - dt * 0.9)
			animal.energy = minf(100, animal.energy + dt * 0.1)
		destination.biomass = maxf(0, destination.biomass - dt * (0.15 if kind == "water" else 0.3))
		animal.stamina = minf(100, animal.stamina + dt * 1.8)
	return true

func _pack_target(animal: Dictionary):
	for member in animals:
		if not member.alive or member.species != "wolf" or member.id == animal.id or member.behavior != "Hunting": continue
		if member.position.distance_to(animal.position) > 35: continue
		for prey in animals:
			if prey.id == member.target and prey.alive and prey.species == "deer" and prey.position.distance_to(animal.position) < 55:
				return prey
	return null

func _share_food(hunter: Dictionary, prey: Dictionary) -> void:
	var pack: Array = []
	for member in animals:
		if member.alive and member.species == "wolf" and member.position.distance_to(hunter.position) < 15:
			pack.append(member)
	for member in pack:
		# A deer carcass provides one substantial meal for each nearby pack member.
		member.hunger = maxf(0, member.hunger - 70.0)
		member.energy = minf(100, member.energy + 10)
		member.meals += 1
		if member.id != hunter.id:
			_remember(member, "Shared prey from " + hunter.name + ": " + prey.name)

func living_count() -> int:
	var living: int = 0
	for animal in animals:
		if animal.alive: living += 1
	return living

func _prune_archive() -> void:
	while animals.size() > MAX_RECORDS:
		var removed: int = -1
		for i in range(animals.size()):
			if not animals[i].alive:
				removed = int(animals[i].id)
				animals.remove_at(i)
				break
		if removed == -1: break
		for animal in animals:
			if animal.target == removed: animal.target = -1

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
	speed *= 0.9 + animal.traits.endurance * 0.2
	animal.heading = atan2(direction.x, direction.z)
	animal.position = Habitat.steer(animal.position, direction, speed, dt)
	animal.position.x = clampf(animal.position.x, -BOUNDS, BOUNDS)
	animal.position.z = clampf(animal.position.z, -BOUNDS, BOUNDS)
	animal.energy = maxf(0, animal.energy - dt * (0.11 if sprint else 0.025))
	animal.stamina = clampf(animal.stamina + dt * (-2.1 + animal.traits.endurance if sprint else 1.2), 0, 100)

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
		"rng_seed": str(rng.seed), "rng_state": str(rng.state), "animals": records,
		"resources": _resource_data(resources)}

func _resource_data(patches: Array) -> Array:
	var result: Array = []
	for patch in patches:
		var item: Dictionary = patch.duplicate(true)
		var p: Vector3 = patch.position
		item.position = [p.x, p.y, p.z]
		result.append(item)
	return result

func from_data(data: Dictionary) -> bool:
	# Validate every field before mutating the running ecosystem.
	if data.get("version") == 1 and data.get("animals") is Array:
		data = data.duplicate(true)
		data.version = SAVE_VERSION
		data.resources = _resource_data(_default_resources())
		for record in data.animals:
			if not record is Dictionary: return false
			record.thirst = 15.0
			record.traits = {"boldness": 0.5, "endurance": 0.5}
			record.food_memory = []
			record.water_memory = []
	if data.get("version") != SAVE_VERSION or not data.get("animals") is Array:
		return false
	if data.animals.size() < 1 or data.animals.size() > MAX_RECORDS:
		return false
	if not data.get("resources") is Array or data.resources.size() < 1 or data.resources.size() > 64:
		return false
	var restored_resources: Array = []
	var resource_ids: Array = []
	var resource_kinds: Dictionary = {}
	for raw in data.resources:
		if not raw is Dictionary: return false
		var patch: Dictionary = raw.duplicate(true)
		if not _number(patch.get("id")) or patch.id < 1 or patch.id != int(patch.id) or int(patch.id) in resource_ids: return false
		if patch.get("kind") not in ["meadow", "water"]: return false
		if not _number(patch.get("biomass")) or patch.biomass < 0 or patch.biomass > 100: return false
		var p = patch.get("position")
		if not p is Array or p.size() != 3: return false
		for coordinate in p:
			if not _number(coordinate) or absf(coordinate) > BOUNDS: return false
		if p[1] != 0: return false
		patch.position = Vector3(p[0], p[1], p[2])
		patch.id = int(patch.id)
		resource_ids.append(patch.id)
		resource_kinds[patch.id] = patch.kind
		restored_resources.append(patch)
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
		for key in ["hunger", "energy", "stamina", "fear", "thirst"]:
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
		if not animal.get("traits") is Dictionary: return false
		for key in ["boldness", "endurance"]:
			if not _number(animal.traits.get(key)) or animal.traits[key] < 0 or animal.traits[key] > 1: return false
		for key in ["food_memory", "water_memory"]:
			if not animal.get(key) is Array or animal[key].size() > resource_ids.size(): return false
			var known: Array = []
			for resource_id in animal[key]:
				if not _number(resource_id) or resource_id != int(resource_id): return false
				var normalized: int = int(resource_id)
				if normalized not in resource_ids or normalized in known: return false
				if resource_kinds[normalized] != ("water" if key == "water_memory" else "meadow"): return false
				known.append(normalized)
			animal[key] = known
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
	var living: int = 0
	for animal in restored:
		if animal.alive: living += 1
	if living > MAX_POPULATION: return false
	animals = restored
	resources = restored_resources
	elapsed = float(data.elapsed)
	forage = float(data.forage)
	next_id = int(data.next_id)
	environment_event = data.environment_event
	rng.seed = data.rng_seed.to_int()
	rng.state = data.rng_state.to_int()
	return true

func _number(value) -> bool:
	return (value is float or value is int) and is_finite(float(value))
