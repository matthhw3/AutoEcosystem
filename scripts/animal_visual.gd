extends Node3D
## Replaceable procedural visual proxy. No biological state lives in this node.

var legs: Array[MeshInstance3D] = []
var head: Node3D
var body: Node3D
var title: Label3D
var previous_position := Vector3.ZERO
var initialized := false

func _ellipsoid(parent: Node3D, dimensions: Vector3, point: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	mesh.mesh = sphere
	mesh.scale = dimensions
	mesh.position = point
	mesh.material_override = _material(color)
	parent.add_child(mesh)
	return mesh

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _box(parent: Node3D, dimensions: Vector3, point: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.position = point
	mesh.material_override = _material(color)
	parent.add_child(mesh)
	return mesh

func build(animal: Dictionary) -> void:
	var wolf: bool = animal.species == "wolf"
	var coat := Color("68757c") if wolf else Color("9c6844")
	body = Node3D.new()
	add_child(body)
	_ellipsoid(body, Vector3(0.8, 0.88, 1.9), Vector3(0, 1, 0), coat)
	_ellipsoid(body, Vector3(0.55, 0.45, 1.45), Vector3(0, 0.85, -0.1), coat.lightened(0.25))
	_ellipsoid(body, Vector3(0.5, 0.8 if not wolf else 0.6, 0.55), Vector3(0, 1.25, -0.65), coat)
	head = Node3D.new()
	head.position = Vector3(0, 1.45, -0.85)
	body.add_child(head)
	_ellipsoid(head, Vector3(0.52, 0.62, 0.75), Vector3.ZERO, coat.lightened(0.12))
	_ellipsoid(head, Vector3(0.38, 0.3, 0.7), Vector3(0, -0.13, -0.4), coat)
	_box(head, Vector3(0.25, 0.14, 0.13), Vector3(0, -0.08, -0.66), Color("202729"))
	for x in [-0.23, 0.23]:
		for z in [-0.53, 0.53]:
			var leg := _box(body, Vector3(0.13, 0.7, 0.13), Vector3(x, 0.35, z), coat.darkened(0.25))
			legs.append(leg)
		_box(head, Vector3(0.16, 0.34, 0.14), Vector3(x, 0.37, 0), coat)
		_box(head, Vector3(0.055, 0.075, 0.09), Vector3(x * 1.02, 0.06, -0.32), Color("151d1c"))
	var tail := _box(body, Vector3(0.17, 0.17, 0.68 if wolf else 0.3), Vector3(0, 1.05, 1), coat)
	tail.rotation.x = -0.4 if wolf else 0.5
	title = Label3D.new()
	title.text = animal.name
	title.position.y = 2.3
	title.font_size = 38
	title.pixel_size = 0.008
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.outline_size = 10
	title.modulate = Color("dfe8e7")
	add_child(title)

func sync(animal: Dictionary, ground_height: float, elapsed: float, selected: bool) -> void:
	var point: Vector3 = animal.position
	point.y = ground_height
	position = point
	rotation.y = animal.heading + PI
	rotation.z = 0.0 if animal.alive else PI / 2
	var moving: bool = animal.behavior in ["Hunting", "Fleeing", "Fleeing hazard", "Wandering", "Seeking water", "Seeking forage", "Pack hunting"] and animal.alive
	var sprint: bool = animal.behavior in ["Hunting", "Fleeing", "Fleeing hazard", "Pack hunting"]
	var phase: float = elapsed * (15.0 if sprint else 6.0) + animal.id
	for i in range(legs.size()):
		legs[i].rotation.x = sin(phase + (PI if i in [1, 2] else 0.0)) * (0.6 if sprint else 0.3) if moving else 0.0
	body.position.y = absf(sin(phase)) * 0.06 if moving else 0.0
	head.rotation.x = 0.65 if animal.behavior in ["Grazing", "Drinking"] else 0.0
	var maturity := 730.0 if animal.species == "wolf" else 365.0
	scale = Vector3.ONE * lerpf(0.48, 1, clampf(animal.age / maturity, 0, 1))
	if animal.behavior == "Resting": body.position.y = -0.3
	title.modulate = Color("ffe7a3") if selected else Color("dfe8e7")
	title.text = animal.name + ("  †" if not animal.alive else "")
