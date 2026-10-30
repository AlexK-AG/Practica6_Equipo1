extends RefCounted
## Original kit PBR textures, mapped in world space so room size cannot stretch them.
const SOURCE := "res://Modular SciFi MegaKit[Standard]/Textures/"

static func surface(trim: String, tint: Color, density: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "Station_" + trim
	material.albedo_texture = load(SOURCE + "T_" + trim + "_BaseColor.png")
	material.albedo_color = tint
	material.normal_enabled = true
	material.normal_texture = load(SOURCE + "T_" + trim + "_Normal.png")
	material.normal_scale = .55
	var orm: Texture2D = load(SOURCE + "T_" + trim + "_ORM.png")
	material.roughness_texture = orm
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	material.metallic_texture = orm
	material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	material.metallic = .6
	material.roughness = .8
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * density
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material

static func apply(arena: Node3D) -> void:
	var walls := surface("Trim_02",Color(.85,.88,.92),.18)
	var floors := surface("Trim_01",Color(.73,.76,.8),.24)
	var ceiling := surface("Trim_03",Color(.52,.56,.63),.2)
	for mesh in arena.find_children("*","MeshInstance3D",true,false):
		var parent_name: String = str(mesh.get_parent().name)
		var relative: String = str(arena.get_path_to(mesh))
		if parent_name.begins_with("Wall"):
			mesh.material_override = walls
		elif parent_name.begins_with("Floor"):
			mesh.material_override = floors
		elif relative.begins_with("Ceilings/"):
			mesh.material_override = ceiling
