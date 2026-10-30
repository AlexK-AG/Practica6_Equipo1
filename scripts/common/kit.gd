extends RefCounted

static func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.65
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.0
	return mat

static func model(parent: Node3D, file: String, size: Vector3, center: Vector3, tint: Color = Color.WHITE) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = load(model_path(file)) as Mesh
	var bounds := mesh.mesh.get_aabb()
	mesh.scale = size / bounds.size
	mesh.position = center - (bounds.position + bounds.size / 2.0) * mesh.scale
	if tint != Color.WHITE:
		mesh.material_override = material(tint)
	else:
		for index in range(mesh.mesh.get_surface_count()):
			var original := mesh.mesh.surface_get_material(index)
			if original == null:
				continue
			var texture := ""
			if "Trim_01" in original.resource_name:
				texture = "T_Trim_01_BaseColor.png"
			elif "Trim_02" in original.resource_name:
				texture = "T_Trim_02_BaseColor.png"
			elif "Trim_03" in original.resource_name:
				texture = "T_Trim_03_BaseColor.png"
			if not texture.is_empty():
				var mat := material(Color.WHITE)
				mat.albedo_texture = load("res://assets/" + texture)
				mesh.set_surface_override_material(index, mat)
	parent.add_child(mesh)
	preload("res://scripts/visuals/surface_visibility.gd").fix_mesh(mesh)
	return mesh

static func box(parent: Node3D, size: Vector3, center: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color, glow)
	mesh.position = center
	parent.add_child(mesh)
	return mesh

static func collider(parent: Node3D, size: Vector3, center: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = center
	parent.add_child(collision)

static func model_path(file: String) -> String:
	var group := "enemies" if file.begins_with("Alien_") else ("props" if file.begins_with("Prop_") else "structures")
	return "res://assets/models/%s/%s.obj" % [group, file]
