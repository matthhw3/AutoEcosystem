extends Node3D
## Original procedural landscape. All meshes and materials are generated locally.

const EXTENT: float = 72.0
const Habitat = preload("res://scripts/habitat.gd")
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _ground_material: StandardMaterial3D
var _sky_material: ProceduralSkyMaterial
var _environment: Environment
var _fire_effect: Node3D
var _flood_effect: MeshInstance3D
var _visual_event: String = "normal"

static func height_at(x: float, z: float) -> float:
	return sin(x * 0.047) * cos(z * 0.041) * 1.5 + sin(z * 0.09 + x * 0.025) * 0.35

func _ready() -> void:
	_rng.seed = 23119
	_build_ground()
	_build_backdrop()
	_build_forest()
	_build_lighting()
	_build_event_effects()
	set_event(_visual_event)

func _material(color: Color, roughness: float = 0.92) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _build_ground() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var divisions: int = 72
	var spacing: float = EXTENT * 2.0 / divisions
	for x in range(divisions):
		for z in range(divisions):
			var a := Vector3(-EXTENT + x * spacing, 0, -EXTENT + z * spacing)
			var b := a + Vector3(spacing, 0, 0)
			var c := a + Vector3(0, 0, spacing)
			var d := a + Vector3(spacing, 0, spacing)
			# Godot uses clockwise front faces; keep terrain visible from above.
			for point: Vector3 in [a, b, c, b, d, c]:
				point.y = height_at(point.x, point.z)
				var clearing: float = 1.0 - smoothstep(8.0, 24.0, Vector2(point.x, point.z).length())
				var trail: float = 1.0 - smoothstep(1.0, 2.8, abs(point.x - sin(point.z * 0.04) * 12.0))
				var color := Color(0.07, 0.15, 0.055).lerp(Color(0.17, 0.25, 0.08), clearing)
				color = color.lerp(Color(0.20, 0.13, 0.065), trail * 0.7)
				surface.set_color(color)
				surface.add_vertex(point)
	surface.generate_normals()
	var ground := MeshInstance3D.new()
	ground.mesh = surface.commit()
	var mat := _material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	_ground_material = mat
	ground.material_override = mat
	add_child(ground)
	# A reflective blue pond beyond the clearing, with a pebble shore.
	var pond := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 8.5
	disk.bottom_radius = 8.5
	disk.height = 0.06
	disk.radial_segments = 48
	pond.mesh = disk
	pond.position = Vector3(28, height_at(28, 28) + 0.15, 28)
	pond.scale.z = 0.65
	pond.material_override = _material(Color(0.12, 0.32, 0.38), 0.18)
	add_child(pond)

func _instances(mesh: Mesh, transforms: Array[Transform3D], material: Material) -> MultiMeshInstance3D:
	var batch := MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index in range(transforms.size()):
		multi.set_instance_transform(index, transforms[index])
	batch.multimesh = multi
	batch.material_override = material
	add_child(batch)
	return batch

func _transform(point: Vector3, dimensions: Vector3, yaw: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(dimensions), point)

func _build_forest() -> void:
	var trunks: Array[Transform3D] = []
	var needles: Array[Transform3D] = []
	var leaves: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var grasses: Array[Transform3D] = []
	for record: Dictionary in Habitat.tree_records():
		var x: float = record.x
		var z: float = record.z
		var height: float = record.height
		var index: int = record.index
		var base := Vector3(x, height_at(x, z), z)
		trunks.append(_transform(base + Vector3.UP * height * 0.43, Vector3(0.3, height * 0.86, 0.3)))
		if index % 4 != 0:
			for tier in range(3):
				var radius: float = height * (0.26 - tier * 0.045)
				needles.append(_transform(base + Vector3.UP * height * (0.5 + tier * 0.18), Vector3(radius, height * 0.46, radius)))
		else:
			leaves.append(_transform(base + Vector3.UP * height * 0.85, Vector3(height * 0.37, height * 0.39, height * 0.34)))
	_rng.state = Habitat.decoration_rng_state()
	for index in range(140):
		var x: float = _rng.randf_range(-68, 68)
		var z: float = _rng.randf_range(-68, 68)
		if Vector2(x,z).length() < 7:
			continue
		var size: float = _rng.randf_range(0.25, 1.2)
		rocks.append(_transform(Vector3(x, height_at(x,z) + size * 0.2, z), Vector3(size, size * 0.65, size * 0.8), _rng.randf() * TAU))
	for index in range(1600):
		var x: float = _rng.randf_range(-68, 68)
		var z: float = _rng.randf_range(-68, 68)
		if abs(x - sin(z * 0.04) * 12) < 2 or Vector2(x - 28, z - 28).length() < 10:
			continue
		var size: float = _rng.randf_range(0.18, 0.55)
		grasses.append(_transform(Vector3(x, height_at(x,z) + size * 0.4, z), Vector3(size * 0.65, size, size * 0.65)))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.6
	trunk.bottom_radius = 1
	trunk.height = 1
	trunk.radial_segments = 6
	_instances(trunk, trunks, _material(Color(0.23, 0.16, 0.10)))
	var cone := CylinderMesh.new()
	cone.top_radius = 0
	cone.bottom_radius = 1
	cone.height = 1
	cone.radial_segments = 7
	_instances(cone, needles, _material(Color(0.035, 0.15, 0.075)))
	var sphere := SphereMesh.new()
	sphere.height = 2
	sphere.radius = 1
	sphere.radial_segments = 7
	sphere.rings = 4
	_instances(sphere, leaves, _material(Color(0.13, 0.27, 0.055)))
	_instances(sphere, rocks, _material(Color(0.34, 0.37, 0.35)))
	var grass_batch := _instances(cone, grasses, _material(Color(0.15, 0.25, 0.065)))
	grass_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _backdrop_height(x: float, z: float) -> float:
	var distance: float = maxf(absf(x),absf(z))
	var hills: float = (sin(x * 0.018) * cos(z * 0.014) + 1.0) * 17.0
	return height_at(x,z) + smoothstep(115.0,290.0,distance) * hills

func _build_backdrop() -> void:
	# Ground extends beyond the camera's entire visible range. The active habitat
	# retains its exact shared geometry; outer hills are observer-only scenery.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x_index in range(100):
		for z_index in range(100):
			var x: float = -600.0 + x_index * 12.0
			var z: float = -600.0 + z_index * 12.0
			if x >= -72.0 and x < 72.0 and z >= -72.0 and z < 72.0:
				continue
			var a := Vector3(x,0,z)
			var b := Vector3(x + 12.0,0,z)
			var c := Vector3(x,0,z + 12.0)
			var d := Vector3(x + 12.0,0,z + 12.0)
			for point: Vector3 in [a,b,c,b,d,c]:
				point.y = _backdrop_height(point.x,point.z)
				var variation: float = (sin(point.x * 0.021 + point.z * 0.035) + 1.0) * 0.5
				surface.set_color(Color(0.075,0.15,0.065).lerp(Color(0.12,0.21,0.09),variation))
				surface.add_vertex(point)
	surface.generate_normals()
	var ground := MeshInstance3D.new()
	ground.name = "SurroundingLandscape"
	ground.mesh = surface.commit()
	ground.material_override = _ground_material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	var distant_rng := RandomNumberGenerator.new()
	distant_rng.seed = 90417
	var pines: Array[Transform3D] = []
	for index in range(1700):
		var x: float = distant_rng.randf_range(-330,330)
		var z: float = distant_rng.randf_range(-330,330)
		if maxf(absf(x),absf(z)) < 76.0:
			continue
		var height: float = distant_rng.randf_range(7.0,16.0)
		var base := Vector3(x,_backdrop_height(x,z),z)
		pines.append(_transform(base + Vector3.UP * height * 0.5,Vector3(height * 0.24,height,height * 0.24)))
	var pine := CylinderMesh.new()
	pine.top_radius = 0
	pine.bottom_radius = 1
	pine.height = 1
	pine.radial_segments = 6
	var distant_forest := _instances(pine,pines,_material(Color(0.055,0.17,0.12)))
	distant_forest.name = "DistantForest"
	distant_forest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var peaks: Array[Transform3D] = []
	for index in range(24):
		var angle: float = TAU * index / 24.0
		var radius: float = distant_rng.randf_range(290,360)
		var x: float = cos(angle) * radius
		var z: float = sin(angle) * radius
		var height: float = distant_rng.randf_range(36,79)
		peaks.append(_transform(Vector3(x,_backdrop_height(x,z) + height * 0.42,z),Vector3(55,height,45),angle))
	var mountains := _instances(pine,peaks,_material(Color(0.14,0.23,0.25)))
	mountains.name = "DistantRidgeline"
	mountains.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.light_color = Color(1.0, 0.89, 0.70)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120
	add_child(sun)
	var sky := ProceduralSkyMaterial.new()
	_sky_material = sky
	sky.sky_top_color = Color(0.25, 0.47, 0.66)
	sky.sky_horizon_color = Color(0.74, 0.83, 0.80)
	sky.ground_horizon_color = sky.sky_horizon_color
	var sky_resource := Sky.new()
	sky_resource.sky_material = sky
	var environment := Environment.new()
	_environment = environment
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky_resource
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.67, 0.77, 0.85)
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.62, 0.73, 0.70)
	environment.fog_density = 0.0015
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

func _effect_mesh(parent: Node3D, mesh: Mesh, material: Material, point: Vector3, dimensions: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = point
	instance.scale = dimensions
	if parent == _fire_effect:
		instance.set_meta("ground_clearance",point.y - height_at(point.x,point.z))
	parent.add_child(instance)
	return instance

func _build_event_effects() -> void:
	# Static cues deliberately have no timer: observing an event never advances it.
	_fire_effect = Node3D.new()
	_fire_effect.name = "WildfireVisual"
	add_child(_fire_effect)
	var flame := CylinderMesh.new()
	flame.top_radius = 0.0
	flame.bottom_radius = 1.0
	flame.height = 1.0
	flame.radial_segments = 5
	var orange := _material(Color(0.95, 0.19, 0.015))
	orange.emission_enabled = true
	orange.emission = Color(0.8, 0.12, 0.005)
	orange.emission_energy_multiplier = 0.6
	var yellow := _material(Color(1.0, 0.6, 0.05))
	yellow.emission_enabled = true
	yellow.emission = Color(0.7, 0.3, 0.015)
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 1.0
	smoke_mesh.height = 2.0
	smoke_mesh.radial_segments = 7
	smoke_mesh.rings = 4
	var smoke := _material(Color(0.15, 0.17, 0.16))
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = 0.2
	log_mesh.bottom_radius = 0.24
	log_mesh.height = 3.0
	log_mesh.radial_segments = 6
	var charred := _material(Color(0.065, 0.045, 0.025))
	for index in range(14):
		var angle: float = index * 2.39996
		var radius: float = 4.0 + float(index % 4) * 3.0
		var x: float = cos(angle) * radius
		var z: float = sin(angle) * radius
		var base := Vector3(x, height_at(x, z), z)
		var size: float = 1.5 + float(index % 3) * 0.5
		_effect_mesh(_fire_effect, flame, orange, base + Vector3.UP * size * 0.5, Vector3(0.8, size, 0.8))
		_effect_mesh(_fire_effect, flame, yellow, base + Vector3(0.25, size * 0.3, 0.3), Vector3(0.4, size * 0.6, 0.4))
		var log := _effect_mesh(_fire_effect, log_mesh, charred, base + Vector3.UP * 0.2, Vector3.ONE)
		log.rotation = Vector3(PI * 0.5, angle, 0)
		for tier in range(3):
			var drift: float = float(tier) * 0.8
			_effect_mesh(_fire_effect, smoke_mesh, smoke, base + Vector3(drift, size + 1.0 + tier * 1.8, 0), Vector3.ONE * (0.65 + tier * 0.35))
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 22.0
	water_mesh.bottom_radius = 22.0
	water_mesh.height = 0.08
	water_mesh.radial_segments = 64
	var water := _material(Color(0.07, 0.27, 0.35, 0.72), 0.12)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flood_effect = _effect_mesh(self, water_mesh, water, Vector3(0, 0.95, 0), Vector3.ONE)
	_flood_effect.name = "FloodVisual"
	_flood_effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func set_event(event: String) -> void:
	if event not in ["normal", "drought", "wildfire", "flood"]:
		event = "normal"
	_visual_event = event
	if not is_instance_valid(_fire_effect):
		return
	_fire_effect.visible = event == "wildfire"
	_flood_effect.visible = event == "flood"
	_ground_material.albedo_color = Color.WHITE
	_sky_material.sky_top_color = Color(0.25, 0.47, 0.66)
	_sky_material.sky_horizon_color = Color(0.74, 0.83, 0.80)
	_environment.fog_light_color = Color(0.62, 0.73, 0.70)
	_environment.fog_density = 0.0015
	match event:
		"drought":
			_ground_material.albedo_color = Color(1.5, 0.9, 0.4)
			_sky_material.sky_horizon_color = Color(0.83, 0.72, 0.50)
			_environment.fog_light_color = Color(0.75, 0.65, 0.46)
		"wildfire":
			_ground_material.albedo_color = Color(0.7, 0.55, 0.4)
			_sky_material.sky_top_color = Color(0.24, 0.25, 0.25)
			_sky_material.sky_horizon_color = Color(0.63, 0.42, 0.26)
			_environment.fog_light_color = Color(0.37, 0.32, 0.26)
			_environment.fog_density = 0.006
		"flood":
			_ground_material.albedo_color = Color(0.75, 0.85, 0.9)
			_sky_material.sky_top_color = Color(0.23, 0.32, 0.40)
			_sky_material.sky_horizon_color = Color(0.55, 0.65, 0.70)
	_sky_material.ground_horizon_color = _sky_material.sky_horizon_color

func set_event_progress(radius: float, intensity: float) -> void:
	# Driven entirely by saved simulation state; views do not run an independent clock.
	if is_instance_valid(_fire_effect):
		_fire_effect.scale = Vector3(maxf(1, radius / 15.0), 1, maxf(1, radius / 15.0))
		for part: Node3D in _fire_effect.get_children():
			part.position.y = height_at(part.position.x * _fire_effect.scale.x,part.position.z * _fire_effect.scale.z) + float(part.get_meta("ground_clearance",0.0))
	if is_instance_valid(_flood_effect):
		_flood_effect.scale = Vector3(maxf(1, radius / 22.0), 1, maxf(1, radius / 22.0))
	if _visual_event == "wildfire": _environment.fog_density = 0.006 * clampf(intensity, 1, 2)
