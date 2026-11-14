extends Node3D
const Forest = preload("res://scripts/forest.gd")
var markers: Dictionary = {}
var markers_visible := true

func set_markers_visible(enabled: bool) -> void:
	markers_visible = enabled
	for marker in markers.values(): marker.get_child(1).visible = enabled

func sync(resources: Array) -> void:
	var ids: Array = []
	for resource in resources: ids.append(resource.id)
	for id in markers.keys():
		if id not in ids:
			markers[id].queue_free()
			markers.erase(id)
	for resource in resources:
		if not markers.has(resource.id):
			var marker := Node3D.new()
			var mesh := MeshInstance3D.new()
			var disk := CylinderMesh.new()
			disk.top_radius = 2.8 if resource.kind == "water" else 3.5
			disk.bottom_radius = disk.top_radius
			disk.height = 0.09
			disk.radial_segments = 24
			mesh.mesh = disk
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("17444c") if resource.kind == "water" else Color("527d39")
			mat.roughness = 0.65 if resource.kind == "water" else 0.9
			mat.metallic_specular = 0.15
			mesh.material_override = mat
			marker.add_child(mesh)
			var label := Label3D.new()
			label.position.y = 0.7
			label.font_size = 24
			label.pixel_size = 0.012
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			marker.add_child(label)
			if resource.kind == "meadow":
				var plants := MultiMeshInstance3D.new()
				var grass := CylinderMesh.new()
				grass.top_radius = 0
				grass.bottom_radius = 0.22
				grass.height = 0.55
				grass.radial_segments = 4
				var batch := MultiMesh.new()
				batch.transform_format = MultiMesh.TRANSFORM_3D
				batch.mesh = grass
				batch.instance_count = 18
				for index in range(18):
					var angle: float = index * 2.39996
					var radius: float = 0.5 + (index % 5) * 0.45
					batch.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(cos(angle) * radius, 0.25, sin(angle) * radius)))
				plants.multimesh = batch
				var leaves := StandardMaterial3D.new()
				leaves.albedo_color = Color("6f963f")
				plants.material_override = leaves
				marker.add_child(plants)
			add_child(marker)
			markers[resource.id] = marker
		var node: Node3D = markers[resource.id]
		node.position = resource.position
		node.position.y = Forest.height_at(node.position.x, node.position.z) + 0.12
		node.get_child(1).text = "%s · %.0f%%" % ["Water" if resource.kind == "water" else "Meadow", resource.biomass]
		node.get_child(1).visible = markers_visible
		node.get_child(0).scale = Vector3.ONE * (0.35 + resource.biomass / 150.0)
		if node.get_child_count() > 2:
			node.get_child(2).scale = Vector3(1, maxf(0.05, resource.biomass / 100.0), 1)
