extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var started: int = Time.get_ticks_msec()
	var world = Simulation.new()
	world.reset(42)
	check(world.animals.size() == 9, "Initial population")
	var before: Dictionary = world.to_data()
	check(world.to_data() == before, "Reading state never advances time")
	world.tick(0.1)
	check(world.animals[0].behavior == "Hunting", "Hungry wolf perceives and hunts deer")
	check(world.animals[1].behavior == "Fleeing", "Deer perceives nearby wolf")
	check(world.animals[1].fear > 0, "Danger enters persistent memory")
	var saved = JSON.parse_string(JSON.stringify(world.to_data(), "", true, true))
	var restored = Simulation.new()
	check(restored.from_data(saved), "JSON save loads")
	world.tick(3.0)
	restored.tick(3.0)
	check(JSON.stringify(world.to_data()) == JSON.stringify(restored.to_data()), "Save restores deterministic continuation")
	var snapshot: Dictionary = world.to_data()
	var invalid: Dictionary = snapshot.duplicate(true)
	invalid.animals[0].hunger = "bad"
	check(not world.from_data(invalid), "Malformed needs rejected")
	check(world.to_data() == snapshot, "Rejected load leaves world intact")
	invalid = snapshot.duplicate(true)
	invalid.animals[1].id = invalid.animals[0].id
	check(not world.from_data(invalid), "Duplicate IDs rejected")
	world.reset(42)
	world.animals[1].position = world.animals[0].position + Vector3(0.1, 0, 0)
	world.tick(0.1)
	check(not world.animals[1].alive, "Predator captures nearby prey")
	check(world.animals[0].hunger < 64, "Successful hunt satisfies hunger")
	world.animals[2].hunger = 99.999
	world.tick(0.1)
	check(not world.animals[2].alive, "Starvation causes death")
	world.set_event("drought")
	var initial_forage: float = world.forage
	world.tick(10)
	check(world.forage < initial_forage, "Drought reduces forage")
	world.set_event("unknown")
	check(world.environment_event == "drought", "Unknown event rejected")
	world.reset(20)
	world.animals[0].alive = false
	for animal in world.animals:
		animal.hunger = 10.0
		animal.energy = 100.0
		animal.birth_cooldown = 0.0
		animal.position = Vector3(10, 0, 10)
	world.tick(0.1)
	check(world.animals.size() > 9, "Well-fed nearby adults reproduce")
	for i in range(60):
		world.tick(10)
	for animal in world.animals:
		check(is_finite(animal.position.x) and absf(animal.position.x) <= 65.0, "Long-run positions stay bounded")
		check(animal.memories.size() <= 8, "Memory bounded")
	_test_hazards_and_aging()
	_test_recovery_and_learning()
	_test_reproductive_maturity()
	_test_invalid_saves()
	_test_spatial_resources()
	_test_traits_and_pack()
	_test_schema_and_archive()
	_test_endurance()
	print("Simulation suite runtime: %.2fs" % ((Time.get_ticks_msec() - started) / 1000.0))
	print("Simulation tests: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)

func _test_hazards_and_aging() -> void:
	for event in ["wildfire", "flood"]:
		var world = Simulation.new()
		world.reset(42)
		world.animals[0].position = Vector3(1, 0, 1)
		world.animals[1].position = Vector3(1, 0, -1)
		world.set_event(event)
		var start_distance: float = world.animals[1].position.length()
		world.tick(0.1)
		check(world.animals[0].behavior.begins_with("Fleeing"), event + ": wolf avoids hazard")
		check(world.animals[1].behavior == "Fleeing", event + ": deer avoids hazard")
		check(world.animals[1].position.length() > start_distance, event + ": deer moves out of danger")
		world.animals[0].alive = false
		world.tick(8.0)
		check(world.animals[1].alive and world.animals[1].position.length() >= 22, event + ": deer reaches safety")
	var fire = Simulation.new()
	fire.reset(42)
	fire.set_event("wildfire")
	fire.animals[1].position = Vector3(1, 0, 0)
	fire.animals[1].energy = 0.001
	fire.tick(0.1)
	check(not fire.animals[1].alive and "Wildfire" in fire.animals[1].behavior, "Exhausted animal can die from fire exposure")
	var old = Simulation.new()
	old.reset(42)
	old.animals[0].age = 6000.0
	old.animals[1].age = 7000.0
	old.tick(0.1)
	check(not old.animals[0].alive and not old.animals[1].alive, "Both species eventually die of old age")
	check("Old age" in old.animals[0].memories.back(), "Death cause remains inspectable")

func _test_recovery_and_learning() -> void:
	var world = Simulation.new()
	world.reset(42)
	world.animals[0].stamina = 1.0
	world.animals[0].energy = 70.0
	world.tick(0.1)
	check(world.animals[0].behavior == "Resting", "Exhausted predator rests instead of chasing")
	world.tick(5.0)
	check(world.animals[0].stamina > 10 and world.animals[0].energy > 70, "Rest restores stamina and energy")
	world.reset(42)
	for animal in world.animals:
		animal.alive = animal.id == 2
	var deer: Dictionary = world.animals[1]
	deer.position = Vector3.ZERO
	deer.danger_position = Vector3(-10, 0, 0)
	deer.fear = 100.0
	deer.heading = -PI / 2
	deer.wander_time = 10.0
	deer.hunger = 0.0
	deer.memories = ["Encountered a predator to the west"]
	var learned = Simulation.new()
	var naive = Simulation.new()
	var saved = JSON.parse_string(JSON.stringify(world.to_data(), "", true, true))
	check(learned.from_data(saved) and naive.from_data(saved), "Learned danger loads from save")
	naive.animals[1].fear = 0.0
	learned.tick(0.1)
	naive.tick(0.1)
	check(learned.animals[1].position.x > naive.animals[1].position.x, "Saved danger memory steers subsequent travel away from threat")
	check(deer.memories[0] in learned.animals[1].memories, "Experience log survives save and later decisions")

func _test_invalid_saves() -> void:
	var world = Simulation.new()
	world.reset(42)
	var original: Dictionary = world.to_data()
	var candidates: Array = []
	for key in ["elapsed", "forage", "next_id", "animals", "rng_state", "environment_event"]:
		var missing: Dictionary = original.duplicate(true)
		missing.erase(key)
		candidates.append(missing)
	var bad: Dictionary = original.duplicate(true)
	bad.animals[0].position = [INF, 0, 0]
	candidates.append(bad)
	bad = original.duplicate(true)
	bad.animals[0].position = [0, 0]
	candidates.append(bad)
	bad = original.duplicate(true)
	bad.animals[0].position = [66, 0, 0]
	candidates.append(bad)
	bad = original.duplicate(true)
	bad.animals[0].energy = NAN
	candidates.append(bad)
	bad = original.duplicate(true)
	bad.animals[0].species = "unknown"
	candidates.append(bad)
	bad = original.duplicate(true)
	bad.animals[0].id = 1.5
	candidates.append(bad)
	bad = original.duplicate(true)
	bad.animals[0].target = 999
	candidates.append(bad)
	bad = JSON.parse_string(JSON.stringify(original))
	bad.animals[1].id = bad.animals[0].id
	candidates.append(bad)
	bad = original.duplicate(true)
	bad.animals[0].memories = [123]
	candidates.append(bad)
	bad = original.duplicate(true)
	bad.rng_state = "not an integer"
	candidates.append(bad)
	for i in range(candidates.size()):
		check(not world.from_data(candidates[i]), "Malformed save variant %d rejected" % i)
		check(world.to_data() == original, "Malformed save variant %d leaves state unchanged" % i)
	world.tick(-1)
	world.tick(INF)
	check(world.to_data() == original, "Invalid time input never advances simulation")

func _test_reproductive_maturity() -> void:
	for species in ["deer", "wolf"]:
		var maturity: float = 365.0 if species == "deer" else 730.0
		var world = Simulation.new()
		world.reset(42)
		for animal in world.animals:
			animal.alive = false
		var mature: Dictionary = world.animals[1]
		var juvenile: Dictionary = world.animals[2]
		for animal in [mature, juvenile]:
			animal.species = species
			animal.alive = true
			animal.hunger = 0.0
			animal.energy = 100.0
			animal.birth_cooldown = 0.0
			animal.position = Vector3(30, 0, 30)
		mature.age = 1000.0
		juvenile.age = maturity - 1.0
		var original_population: int = world.animals.size()
		world.tick(0.1)
		check(world.animals.size() == original_population, species + ": mature animal cannot reproduce with juvenile despite expired cooldown")
		juvenile.age = maturity
		world.tick(0.1)
		check(world.animals.size() == original_population + 1, species + ": two mature eligible adults can reproduce")
		check(world.animals.back().age == 0, species + ": offspring starts life as newborn")

func _test_endurance() -> void:
	var world = Simulation.new()
	world.reset(42)
	var validator = Simulation.new()
	var deaths_seen: Array = []
	for step in range(36000):
		world.tick(0.1)
		if step % 600 == 0:
			check(world.living_count() <= 36 and world.animals.size() <= 128, "Endurance population remains bounded")
			check(is_finite(world.elapsed) and world.forage >= 0 and world.forage <= 100, "Endurance world state remains finite")
			check(validator.from_data(world.to_data()), "Endurance state remains loadable")
			for animal in world.animals:
				if not animal.alive and animal.id not in deaths_seen:
					deaths_seen.append(animal.id)
					print("Ecology death by %.0fs: %s %s" % [world.elapsed, animal.name, animal.behavior])
				check(animal.position.is_finite() and absf(animal.position.x) <= 65 and absf(animal.position.z) <= 65, "Endurance agent position remains finite and bounded")
				check(animal.hunger >= 0 and animal.hunger <= 100 and animal.energy >= 0 and animal.energy <= 100 and animal.stamina >= 0 and animal.stamina <= 100, "Endurance needs remain bounded")
				check(animal.thirst >= 0 and animal.thirst <= 100, "Endurance thirst remains bounded")
				check(animal.memories.size() <= 8, "Endurance memory remains bounded")
		if step == 17999:
			check(_species_count(world, "deer") > 0 and _species_count(world, "wolf") > 0, "Both predator and prey remain observable after thirty minutes")
	check(absf(world.elapsed - 3600.0) < 0.000001, "One hour advances only requested simulation time")
	var living: int = 0
	for animal in world.animals:
		if animal.alive: living += 1
	print("One-hour ecology sample: %d living / %d total records, wolf alive=%s, forage=%.1f" % [living, world.animals.size(), str(world.animals[0].alive), world.forage])
	check(_species_count(world, "deer") > 0 and _species_count(world, "wolf") > 0, "Baseline ecosystem retains predator and prey after one hour")
	for seed_value in [7, 2026]:
		world.reset(seed_value)
		for minute in range(30): world.tick(60.0)
		print("Seed %d thirty-minute sample: %d deer, %d wolves" % [seed_value, _species_count(world, "deer"), _species_count(world, "wolf")])
		check(_species_count(world, "deer") > 0 and _species_count(world, "wolf") > 0, "Additional seeded ecosystems retain predator and prey for thirty minutes")

func _species_count(world, species: String) -> int:
	var total: int = 0
	for animal in world.animals:
		if animal.alive and animal.species == species: total += 1
	return total

func _isolated_world():
	var world = Simulation.new()
	world.reset(42)
	for animal in world.animals: animal.alive = false
	return world

func _test_spatial_resources() -> void:
	var world = _isolated_world()
	world.resources = [
		{"id": 1, "kind": "meadow", "position": Vector3.ZERO, "biomass": 100.0},
		{"id": 2, "kind": "water", "position": Vector3(10, 0, 0), "biomass": 100.0}
	]
	var deer: Dictionary = world.animals[1]
	deer.alive = true
	deer.position = Vector3.ZERO
	deer.hunger = 80.0
	world.tick(1.0)
	check(deer.hunger < 80 and world.resources[0].biomass < 100, "Grazing consumes a nearby meadow and reduces hunger")
	check(1 in deer.food_memory and 2 in deer.water_memory, "Visible resource discoveries enter individual memory")
	deer.position = Vector3(10, 0, 0)
	deer.thirst = 80.0
	world.tick(1.0)
	check(deer.behavior == "Drinking" and deer.thirst < 80 and world.resources[1].biomass < 100, "Drinking consumes water and relieves thirst")
	var restored = Simulation.new()
	check(restored.from_data(JSON.parse_string(JSON.stringify(world.to_data(), "", true, true))), "Resource ecosystem saves and loads")
	check(restored.animals[1].water_memory == deer.water_memory and restored.animals[1].food_memory == deer.food_memory, "Discovered food and water survive loading")
	var before_water: float = restored.resources[1].biomass
	restored.set_event("drought")
	restored.tick(1.0)
	check(restored.resources[1].biomass < before_water, "Drought depletes spatial water supply")
	deer.thirst = 99.999
	world.tick(0.1)
	check(not deer.alive and "Dehydration" in deer.behavior, "Dehydration is a biological mortality cause")
	var remembered = _isolated_world()
	remembered.resources = [{"id": 1, "kind": "water", "position": Vector3(40, 0, 0), "biomass": 100.0}]
	var traveler: Dictionary = remembered.animals[1]
	traveler.alive = true
	traveler.position = Vector3.ZERO
	traveler.water_memory = [1]
	traveler.thirst = 80.0
	remembered.tick(0.1)
	check(traveler.behavior == "Seeking water" and traveler.position.x > 0, "Animal returns toward remembered water beyond current perception")

func _test_traits_and_pack() -> void:
	for boldness in [0.0, 1.0]:
		var world = _isolated_world()
		world.animals[0].alive = true
		world.animals[0].position = Vector3(12, 0, 0)
		var deer: Dictionary = world.animals[1]
		deer.alive = true
		deer.position = Vector3(-12, 0, 0)
		deer.hunger = 0.0
		deer.traits.boldness = boldness
		world.tick(0.1)
		check((deer.behavior == "Fleeing") == (boldness == 0), "Boldness changes risk response to a distant predator")
	var distances: Array = []
	var stamina: Array = []
	for endurance in [0.0, 1.0]:
		var world = _isolated_world()
		world.animals[0].alive = true
		world.animals[0].position = Vector3(-5, 0, 0)
		world.animals[0].traits.endurance = endurance
		world.animals[1].alive = true
		world.animals[1].position = Vector3(15, 0, 0)
		world.tick(0.1)
		distances.append(world.animals[0].position.x + 5)
		stamina.append(world.animals[0].stamina)
	check(distances[1] > distances[0] and stamina[1] > stamina[0], "Endurance increases sprint speed while conserving stamina")
	var pack = _isolated_world()
	for index in [0, 1, 2, 7]: pack.animals[index].alive = true
	pack.animals[0].position = Vector3(10, 0, 0)
	pack.animals[7].position = Vector3(-10, 0, 0)
	pack.animals[1].position = Vector3(15, 0, 0)
	pack.animals[2].position = Vector3(-10, 0, 12)
	pack.tick(0.1)
	check(pack.animals[0].target == pack.animals[1].id and pack.animals[7].target == pack.animals[1].id, "Nearby wolves coordinate on one prey instead of each choosing nearest")
	pack = _isolated_world()
	for index in [0, 1, 7, 8]: pack.animals[index].alive = true
	pack.animals[0].position = Vector3.ZERO
	pack.animals[1].position = Vector3(0.1, 0, 0)
	pack.animals[7].position = Vector3(-5, 0, 0)
	pack.animals[8].position = Vector3(60, 0, 60)
	pack.tick(0.1)
	check(not pack.animals[1].alive and pack.animals[0].hunger < 10 and pack.animals[7].hunger < 10, "A captured deer feeds the hunter and nearby pack mate")
	check(pack.animals[8].hunger >= 64, "Distant wolf cannot consume a remote pack meal")
	check("Shared prey" in str(pack.animals[7].memories), "Pack meal sharing remains inspectable")

func _test_schema_and_archive() -> void:
	var world = Simulation.new()
	world.reset(42)
	var legacy: Dictionary = world.to_data()
	legacy.version = 1
	legacy.erase("resources")
	legacy.animals = legacy.animals.slice(0, 7)
	legacy.next_id = 8
	for animal in legacy.animals:
		for key in ["thirst", "traits", "food_memory", "water_memory"]: animal.erase(key)
	var restored = Simulation.new()
	check(restored.from_data(legacy) and restored.animals.size() == 7, "Historical seven-animal v1 save migrates without replacing population")
	check(restored.to_data().version == 2 and restored.resources.size() > 0 and restored.animals[0].thirst == 15, "Migration supplies spatial habitat and new biological fields")
	var snapshot: Dictionary = world.to_data()
	var invalids: Array = []
	for key in ["thirst", "traits", "food_memory", "water_memory"]:
		var bad: Dictionary = snapshot.duplicate(true)
		bad.animals[0].erase(key)
		invalids.append(bad)
	var bad: Dictionary = snapshot.duplicate(true)
	bad.resources[0].biomass = 101
	invalids.append(bad)
	bad = snapshot.duplicate(true)
	bad.resources[1].id = bad.resources[0].id
	invalids.append(bad)
	bad = snapshot.duplicate(true)
	bad.animals[0].traits.endurance = -0.1
	invalids.append(bad)
	bad = snapshot.duplicate(true)
	bad.animals[0].water_memory = [1]
	invalids.append(bad)
	bad = snapshot.duplicate(true)
	bad.resources[0].position = [NAN, 0, 0]
	invalids.append(bad)
	bad = snapshot.duplicate(true)
	while bad.animals.size() < 37:
		var additional: Dictionary = bad.animals[1].duplicate(true)
		additional.id = bad.animals.size() + 1
		bad.animals.append(additional)
	bad.next_id = 38
	invalids.append(bad)
	for data in invalids:
		check(not world.from_data(data) and world.to_data() == snapshot, "Invalid schema2 resource/trait/memory fields reject atomically")
	var archive = _isolated_world()
	for index in [1, 2]:
		archive.animals[index].alive = true
		archive.animals[index].hunger = 0.0
		archive.animals[index].age = 1000.0
		archive.animals[index].birth_cooldown = 0.0
		archive.animals[index].position = Vector3(10, 0, 10)
	while archive.animals.size() < 128:
		archive._spawn("deer", Vector3.ZERO)
		archive.animals.back().alive = false
	archive.tick(0.1)
	check(archive.living_count() == 3, "Historical deaths do not consume living reproduction capacity")
	check(archive.animals.size() == 128 and archive.animals[0].id != 1, "Archive bounds records by removing oldest dead animals")
	var validator = Simulation.new()
	check(validator.from_data(archive.to_data()), "Pruned archive remains valid and has no dangling target references")
