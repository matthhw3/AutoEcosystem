extends Node3D
## Original faceted animal models. All poses are a pure function of saved state.

static var _mesh_cache: Dictionary = {}
static var _coat_material: StandardMaterial3D
var legs: Array[Node3D] = []
var knees: Array[Node3D] = []
var head: Node3D
var body: Node3D
var tail: Node3D
var antlers: MeshInstance3D
var title: Label3D
var _wolf: bool = false
var _leg_length: float = 0.8

func _part(shape: String, dimensions: Vector3, point: Vector3, color: Color, rotation_value: Vector3 = Vector3.ZERO) -> Dictionary:
	return {"shape": shape, "dimensions": dimensions, "point": point, "color": color, "rotation": rotation_value}

func _model(parent: Node3D, key: String, parts: Array) -> MeshInstance3D:
	if not _mesh_cache.has(key):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: Dictionary in parts:
			var primitive: PrimitiveMesh
			if part.shape == "box":
				primitive = BoxMesh.new()
			elif part.shape == "cone":
				var cone := CylinderMesh.new()
				cone.height = 1.0
				cone.top_radius = 0.0
				cone.bottom_radius = 0.5
				cone.radial_segments = 5
				primitive = cone
			else:
				var sphere := SphereMesh.new()
				sphere.height = 1.0
				sphere.radius = 0.5
				sphere.radial_segments = 9
				sphere.rings = 5
				primitive = sphere
			var arrays: Array = primitive.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var transform_value := Transform3D(Basis.from_euler(part.rotation).scaled(part.dimensions), part.point)
			var normal_basis := transform_value.basis.inverse().transposed()
			for index: int in indices:
				surface.set_color(part.color)
				surface.set_normal((normal_basis * normals[index]).normalized())
				surface.add_vertex(transform_value * vertices[index])
		_mesh_cache[key] = surface.commit()
	if _coat_material == null:
		_coat_material = StandardMaterial3D.new()
		_coat_material.vertex_color_use_as_albedo = true
		_coat_material.roughness = 0.96
	var instance := MeshInstance3D.new()
	instance.mesh = _mesh_cache[key]
	instance.material_override = _coat_material
	parent.add_child(instance)
	return instance

func build(animal: Dictionary) -> void:
	_wolf = animal.species == "wolf"
	_leg_length = 0.78 if _wolf else 1.14
	var prefix: String = "wolf" if _wolf else "deer"
	var coat := Color("59676c") if _wolf else Color("855333")
	var cream := Color("b0b5a4") if _wolf else Color("c2b79a")
	var dark := Color("303d42") if _wolf else Color("593c29")
	var torso_y: float = 1.0 if _wolf else 1.43
	body = Node3D.new()
	add_child(body)
	var torso_parts: Array = [
		_part("sphere", Vector3(0.77,0.76,1.92), Vector3(0,torso_y,0), coat),
		_part("sphere", Vector3(0.58,0.49,1.48), Vector3(0,torso_y - 0.16,0.02), cream),
		_part("sphere", Vector3(0.65,0.74,0.69), Vector3(0,torso_y + 0.04,-0.56), coat),
		_part("sphere", Vector3(0.64,0.68,0.68), Vector3(0,torso_y - 0.03,0.57), coat),
		_part("sphere", Vector3(0.49,0.20,1.6), Vector3(0,torso_y + 0.30,0.1), dark)
	]
	if _wolf:
		torso_parts.append(_part("sphere", Vector3(0.79,0.84,0.68), Vector3(0,1.14,-0.53), coat.lightened(0.08)))
	else:
		torso_parts.append(_part("sphere", Vector3(0.59,0.53,0.18), Vector3(0,1.46,0.84), cream))
	_model(body,prefix + "_torso",torso_parts)
	head = Node3D.new()
	head.position = Vector3(0,0.98 if _wolf else 1.30,-0.69)
	body.add_child(head)
	var head_y: float = 0.32 if _wolf else 0.72
	var head_parts: Array = [
		_part("sphere", Vector3(0.46,head_y + 0.32,0.45), Vector3(0,head_y * 0.42,-0.02), coat),
		_part("sphere", Vector3(0.48,0.48,0.67), Vector3(0,head_y,-0.16), coat),
		_part("sphere", Vector3(0.32,0.27,0.71 if _wolf else 0.52), Vector3(0,head_y - 0.13,-0.50), cream),
		_part("sphere", Vector3(0.24,0.16,0.16), Vector3(0,head_y - 0.12,-0.83 if _wolf else -0.74), Color("1b2527"))
	]
	for side: float in [-1.0,1.0]:
		head_parts.append(_part("sphere", Vector3(0.065,0.085,0.10), Vector3(side * 0.235,head_y + 0.035,-0.34), Color("101b1c")))
		head_parts.append(_part("sphere", Vector3(0.018,0.025,0.035), Vector3(side * 0.263,head_y + 0.05,-0.36), Color("b2c3b3")))
		if _wolf:
			head_parts.append(_part("cone", Vector3(0.26,0.37,0.25), Vector3(side * 0.19,head_y + 0.33,-0.06), dark,Vector3(0,0,-side * 0.18)))
			head_parts.append(_part("cone", Vector3(0.13,0.25,0.11), Vector3(side * 0.19,head_y + 0.33,-0.13), cream,Vector3(0,0,-side * 0.18)))
		else:
			head_parts.append(_part("sphere", Vector3(0.22,0.52,0.15), Vector3(side * 0.32,head_y + 0.30,0), coat,Vector3(0,0,-side * 0.66)))
			head_parts.append(_part("sphere", Vector3(0.12,0.35,0.08), Vector3(side * 0.32,head_y + 0.31,-0.06), cream,Vector3(0,0,-side * 0.66)))
	_model(head,prefix + "_head",head_parts)
	if not _wolf:
		var antler_parts: Array = []
		for side: float in [-1.0,1.0]:
			antler_parts.append(_part("box",Vector3(0.06,0.67,0.055),Vector3(side * 0.22,head_y + 0.60,0.03),Color("aa9a77"),Vector3(-0.26,0,-side * 0.40)))
			for tine in range(2):
				antler_parts.append(_part("cone",Vector3(0.07,0.30,0.07),Vector3(side * (0.28 + tine * 0.07),head_y + 0.58 + tine * 0.18,-0.09),Color("aa9a77"),Vector3(-0.5,0,-side * 0.2)))
		antlers = _model(head,"deer_antlers",antler_parts)
	# Hip and knee pivots keep each segment attached throughout the stride.
	for side: float in [-1.0,1.0]:
		for front: bool in [true,false]:
			var hip := Node3D.new()
			hip.position = Vector3(side * 0.25,_leg_length,-0.59 if front else 0.62)
			body.add_child(hip)
			legs.append(hip)
			var upper: float = _leg_length * 0.49
			var lower: float = _leg_length - upper
			_model(hip,prefix + "_upper",[
				_part("sphere",Vector3(0.19,upper + 0.1,0.24),Vector3(0,-upper * 0.45,0),coat),
				_part("sphere",Vector3(0.13,0.16,0.14),Vector3(0,-upper,0),dark)
			])
			var knee := Node3D.new()
			knee.position.y = -upper
			hip.add_child(knee)
			knees.append(knee)
			_model(knee,prefix + "_lower",[
				_part("sphere",Vector3(0.105,lower,0.12),Vector3(0,-lower * 0.45,0),coat.darkened(0.1)),
				_part("sphere" if _wolf else "box",Vector3(0.16,0.11,0.24 if _wolf else 0.17),Vector3(0,-lower + 0.055,-0.045),dark)
			])
	tail = Node3D.new()
	tail.position = Vector3(0,torso_y + 0.06,0.83)
	body.add_child(tail)
	_model(tail,prefix + "_tail",[
		_part("sphere",Vector3(0.24,0.25,0.88) if _wolf else Vector3(0.18,0.20,0.36),Vector3(0,-0.12 if _wolf else 0,0.30 if _wolf else 0.13),coat),
		_part("sphere",Vector3(0.16,0.17,0.30) if _wolf else Vector3(0.14,0.14,0.24),Vector3(0,-0.23 if _wolf else -0.045,0.65 if _wolf else 0.20),dark if _wolf else cream)
	])
	title = Label3D.new()
	title.text = animal.name
	title.position.y = 2.05 if _wolf else 2.85
	title.font_size = 38
	title.pixel_size = 0.008
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.outline_size = 10
	title.modulate = Color("dfe8e7")
	add_child(title)

func sync(animal: Dictionary, ground_height: float, elapsed: float, selected: bool) -> void:
	position = Vector3(animal.position.x,ground_height,animal.position.z)
	rotation = Vector3(0,animal.heading + PI,0)
	var moving: bool = animal.behavior in ["Hunting","Fleeing","Fleeing hazard","Wandering","Seeking water","Seeking forage","Pack hunting","Following parent"] and animal.alive
	var sprint: bool = animal.behavior in ["Hunting","Fleeing","Fleeing hazard","Pack hunting"]
	var resting: bool = animal.behavior == "Resting" and animal.alive
	var feeding: bool = animal.behavior in ["Grazing","Drinking","Feeding"] and animal.alive
	var phase: float = elapsed * (13.0 if sprint else 5.5) + animal.id
	body.position = Vector3(0,absf(sin(phase)) * (0.055 if sprint else 0.025) if moving else 0.0,0)
	body.rotation = Vector3.ZERO
	head.rotation = Vector3(-2.1 if not _wolf else -1.4,0,0) if feeding else Vector3.ZERO
	tail.rotation.x = (-0.75 if not _wolf else -0.15) if sprint else (0.30 if _wolf else 0.15)
	for index in range(legs.size()):
		var stride: float = sin(phase + (PI if index in [1,2] else 0.0))
		legs[index].rotation.x = stride * (0.65 if sprint else 0.35) if moving else 0.0
		knees[index].rotation.x = maxf(0,-stride) * (0.95 if sprint else 0.5) if moving else 0.0
		if resting or not animal.alive:
			legs[index].rotation.x = -1.15 if index % 2 == 0 else 1.10
			knees[index].rotation.x = 2.5 if index % 2 == 0 else -2.5
	if resting:
		body.position.y = -_leg_length * 0.65
		head.rotation.x = -0.12
	if not animal.alive:
		body.rotation.z = PI * 0.5
		body.position.y = 0.40
		head.rotation.x = -0.2
	var maturity: float = 730.0 if _wolf else 365.0
	scale = Vector3.ONE * lerpf(0.48,1,clampf(animal.age / maturity,0,1))
	if antlers != null: antlers.visible = animal.age >= maturity and animal.id % 3 == 0
	title.modulate = Color("ffe7a3") if selected else Color("dfe8e7")
	title.text = animal.name + ("  †" if not animal.alive else "")
