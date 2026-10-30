extends RefCounted
## Two-sided rendering only for audited open kit surfaces; closed solids keep culling.
static var audits: Dictionary = {}

static func preserve_teardown_order(instance: MeshInstance3D) -> void:
	if instance.has_meta("two_sided_material_guard"):
		return
	instance.set_meta("two_sided_material_guard", true)
	# Godot 4.7 may release override RIDs before destroying their render instance.
	# Keep the materials alive for one frame after a scene leaves the tree.
	instance.tree_exiting.connect(func() -> void:
		var held: Array[Material] = []
		if instance.material_override != null:
			held.append(instance.material_override)
		for surface in range(instance.mesh.get_surface_count() if instance.mesh != null else 0):
			var mat := instance.get_surface_override_material(surface)
			if mat != null:
				held.append(mat)
		instance.get_tree().process_frame.connect(func() -> void: held.clear(), CONNECT_ONE_SHOT)
	)

static func audit(mesh: Mesh) -> Dictionary:
	var key := mesh.get_instance_id()
	if audits.has(key):
		return audits[key]
	var edges: Dictionary = {}
	var per_surface: Array[Array] = []
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var local_edges: Array = []
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for triangle in range(0, count - 2, 3):
			var points: Array[Vector3i] = []
			for corner in range(3):
				var index := indices[triangle + corner] if not indices.is_empty() else triangle + corner
				# Weld positions across UV/normal seams and material surfaces.
				points.append(Vector3i((vertices[index] * 1000.0).round()))
			for side in range(3):
				var a := points[side]
				var b := points[(side + 1) % 3]
				if a == b:
					continue
				var sa := "%d,%d,%d" % [a.x, a.y, a.z]
				var sb := "%d,%d,%d" % [b.x, b.y, b.z]
				var edge := sa + "/" + sb if sa < sb else sb + "/" + sa
				edges[edge] = int(edges.get(edge, 0)) + 1
				local_edges.append(edge)
		per_surface.append(local_edges)
	var open_surfaces: Array[int] = []
	var boundary_count := 0
	for surface in range(per_surface.size()):
		var open := false
		for edge in per_surface[surface]:
			if edges[edge] == 1:
				boundary_count += 1
				open = true
		if open:
			open_surfaces.append(surface)
	var result := {"boundaries": boundary_count, "surfaces": open_surfaces}
	audits[key] = result
	return result

static func eligible(mesh: Mesh) -> bool:
	var path := mesh.resource_path
	# These watertight props were checked against their original OBJ positions.
	# Import quantization can otherwise make tiny seams look like open edges.
	if path in ["res://assets/models/props/Prop_Chest.obj", "res://assets/models/props/Prop_Crate3.obj"]:
		return false
	return path.begins_with("res://assets/models/props/Prop_") or path in ["res://assets/models/structures/Column_Astra.obj", "res://assets/models/structures/WallAstra_Straight.obj", "res://assets/models/structures/Platform_Metal.obj"]

static func fix_mesh(instance: MeshInstance3D) -> int:
	if instance.mesh == null or not instance.mesh is ArrayMesh or not eligible(instance.mesh):
		return 0
	var inspection := audit(instance.mesh)
	if inspection.surfaces.is_empty():
		return 0
	if instance.material_override is BaseMaterial3D:
		var original := instance.material_override as BaseMaterial3D
		if original.cull_mode == BaseMaterial3D.CULL_DISABLED:
			return 0
		var copy := original.duplicate() as BaseMaterial3D
		copy.cull_mode = BaseMaterial3D.CULL_DISABLED
		instance.material_override = copy
		preserve_teardown_order(instance)
		return 1
	var changed := 0
	for surface in inspection.surfaces:
		var original := instance.get_active_material(surface) as BaseMaterial3D
		if original == null or original.cull_mode == BaseMaterial3D.CULL_DISABLED:
			continue
		var copy := original.duplicate() as BaseMaterial3D
		copy.cull_mode = BaseMaterial3D.CULL_DISABLED
		instance.set_surface_override_material(surface, copy)
		changed += 1
	if changed > 0:
		preserve_teardown_order(instance)
	return changed

static func apply(parent: Node) -> int:
	var changed := fix_mesh(parent) if parent is MeshInstance3D else 0
	for child in parent.get_children():
		changed += apply(child)
	return changed
