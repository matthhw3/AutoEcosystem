extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
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
	print("Simulation tests: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)

