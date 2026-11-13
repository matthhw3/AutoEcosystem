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
	check(world.animals.size() == 7, "Initial population")
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
	check(world.animals[0].hunger < 10, "Successful hunt satisfies hunger")
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
	check(world.animals.size() > 7, "Well-fed nearby adults reproduce")
	for i in range(60):
		world.tick(10)
	for animal in world.animals:
		check(is_finite(animal.position.x) and absf(animal.position.x) <= 65.0, "Long-run positions stay bounded")
		check(animal.memories.size() <= 8, "Memory bounded")
	_test_hazards_and_aging()
	_test_recovery_and_learning()
	_test_reproductive_maturity()
	_test_invalid_saves()
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
	check(learned.animals[1].memories == deer.memories, "Experience log survives save and later decisions")

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
	for step in range(36000):
		world.tick(0.1)
		if step % 600 == 0:
			check(world.animals.size() <= 36, "Endurance population remains bounded")
			check(is_finite(world.elapsed) and world.forage >= 0 and world.forage <= 100, "Endurance world state remains finite")
			check(validator.from_data(world.to_data()), "Endurance state remains loadable")
			for animal in world.animals:
				check(animal.position.is_finite() and absf(animal.position.x) <= 65 and absf(animal.position.z) <= 65, "Endurance agent position remains finite and bounded")
				check(animal.hunger >= 0 and animal.hunger <= 100 and animal.energy >= 0 and animal.energy <= 100 and animal.stamina >= 0 and animal.stamina <= 100, "Endurance needs remain bounded")
				check(animal.memories.size() <= 8, "Endurance memory remains bounded")
	check(absf(world.elapsed - 3600.0) < 0.000001, "One hour advances only requested simulation time")
	var living: int = 0
	for animal in world.animals:
		if animal.alive: living += 1
	print("One-hour ecology sample: %d living / %d total records, wolf alive=%s, forage=%.1f" % [living, world.animals.size(), str(world.animals[0].alive), world.forage])
