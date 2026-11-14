extends Node3D
const Forest = preload("res://scripts/forest.gd")
var markers: Dictionary = {}

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
			mat.albedo_color = Color("3a8a9f") if resource.kind == "water" else Color("527d39")
			mat.roughness = 0.25 if resource.kind == "water" else 0.9
			mesh.material_override = mat
			marker.add_child(mesh)
			var label := Label3D.new()
			label.position.y = 0.7
			label.font_size = 24
			label.pixel_size = 0.012
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			marker.add_child(label)
			add_child(marker)
			markers[resource.id] = marker
		var node: Node3D = markers[resource.id]
		node.position = resource.position
		node.position.y = Forest.height_at(node.position.x, node.position.z) + 0.12
		node.get_child(1).text = "%s · %.0f%%" % ["Water" if resource.kind == "water" else "Meadow", resource.biomass]
		node.get_child(0).scale = Vector3.ONE * (0.35 + resource.biomass / 150.0)
