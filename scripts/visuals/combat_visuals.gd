extends RefCounted
## Shared by first person, pickups and studio previews. Gameplay data stays separate.
const Kit = preload("res://scripts/common/kit.gd")
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")
const SKIN = preload("res://assets/shaders/alien_skin.gdshader")
const SOURCE := "res://Modular SciFi MegaKit[Standard]/Textures/"
const ACCENTS := {"pistol":Color("6cd9d1"),"rifle":Color("7aaee8"),"shotgun":Color("e9af67"),"precision":Color("9cbb89"),"plasma":Color("c99ae8"),"knife":Color("97cdd2")}
static var materials: Dictionary = {}

static func metal(color: Color, polymer: bool = false) -> StandardMaterial3D:
	var key := color.to_html() + str(polymer)
	if materials.has(key):return materials[key]
	var mat := StandardMaterial3D.new()
	mat.resource_name = "Weapon_Polymer" if polymer else "Weapon_BrushedMetal"
	mat.albedo_color = color
	mat.albedo_texture = load(SOURCE + "T_Trim_02_BaseColor.png")
	mat.normal_enabled = true
	mat.normal_texture = load(SOURCE + "T_Trim_02_Normal.png")
	mat.normal_scale = .3 if polymer else .45
	mat.metallic = .12 if polymer else .78
	mat.roughness = .8 if polymer else .37
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * 7
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	materials[key] = mat
	return mat

static func enemy(actor: Node3D,kind: int) -> void:
	for mesh in actor.get_children():
		if not mesh is MeshInstance3D or mesh.mesh == null:continue
		if "Alien_" in mesh.mesh.resource_path:
			var mat := ShaderMaterial.new()
			mat.resource_name = "Alien_Skin_" + str(kind)
			mat.shader = SKIN
			mat.set_shader_parameter("skin_color",Catalog.ENTRIES[kind].color)
			mat.set_shader_parameter("mesh_origin",mesh.mesh.get_aabb().position)
			mat.set_shader_parameter("mesh_size",mesh.mesh.get_aabb().size)
			mesh.material_override = mat
		elif mesh.material_override is StandardMaterial3D and not mesh.material_override.emission_enabled:
			mesh.material_override = metal(mesh.material_override.albedo_color)
			preload("res://scripts/visuals/surface_visibility.gd").fix_mesh(mesh)

static func box(parent: Node3D,size: Vector3,position: Vector3,material: Material) -> MeshInstance3D:
	var mesh := Kit.box(parent,size,position,Color.WHITE)
	mesh.material_override = material
	return mesh

static func cylinder(parent: Node3D,radius: float,length: float,position: Vector3,material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = length
	shape.radial_segments = 16
	node.mesh = shape
	node.rotation.x = PI / 2
	node.position = position
	node.material_override = material
	parent.add_child(node)
	return node

static func weapon(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Model_" + id
	var steel := metal(Color("a1abb5"))
	var body := metal(Color("384654"))
	var rubber := metal(Color("26313a"),true)
	var accent: Color = ACCENTS[id]
	var trim := metal(accent.darkened(.15))
	var light := Kit.material(accent,true)
	if id == "knife":
		box(root,Vector3(.055,.07,.23),Vector3(.3,-.27,-.43),rubber)
		box(root,Vector3(.16,.035,.055),Vector3(.3,-.27,-.56),steel)
		var blade := PrismMesh.new()
		blade.size = Vector3(.085,.025,.48)
		var mesh := MeshInstance3D.new()
		mesh.mesh = blade
		mesh.material_override = steel
		mesh.position = Vector3(.3,-.27,-.81)
		root.add_child(mesh)
		box(root,Vector3(.012,.008,.38),Vector3(.278,-.251,-.78),light)
		for i in range(4):box(root,Vector3(.065,.075,.012),Vector3(.3,-.27,-.36-i*.04),trim)
		return root
	var length: float = {"pistol":.48,"rifle":.7,"shotgun":.76,"precision":.78,"plasma":.68}[id]
	box(root,Vector3(.19,.17,length),Vector3(.3,-.24,-.61),body)
	var grip := box(root,Vector3(.115,.28,.15),Vector3(.3,-.43,-.4),rubber)
	grip.rotation.x = -.18
	box(root,Vector3(.15,.035,.18),Vector3(.3,-.35,-.59),steel)
	box(root,Vector3(.022,.12,.025),Vector3(.235,-.3,-.57),steel)
	box(root,Vector3(.022,.12,.025),Vector3(.365,-.3,-.57),steel)
	box(root,Vector3(.125,.055,length*.68),Vector3(.3,-.135,-.63),trim)
	for side in [-1,1]:
		box(root,Vector3(.008,.018,.22),Vector3(.3+side*.1,-.22,-.61),light)
		for index in range(3):
			box(root,Vector3(.012,.06,.018),Vector3(.3+side*.103,-.25,-.69-index*.052),steel)
	var barrel_length := .22 if id == "pistol" else (.5 if id == "precision" else .35)
	var muzzle_z: float = -.61-length/2-barrel_length/2
	cylinder(root,.045,barrel_length,Vector3(.3,-.23,muzzle_z),steel)
	cylinder(root,.055,.07,Vector3(.3,-.23,muzzle_z-barrel_length/2),rubber)
	box(root,Vector3(.035,.05,.035),Vector3(.3,-.105,-.83),steel)
	if id != "pistol":
		box(root,Vector3(.14,.19,.17),Vector3(.3,-.415,-.68),rubber)
		box(root,Vector3(.13,.13,.26),Vector3(.3,-.24,-.17),body)
		box(root,Vector3(.15,.27,.08),Vector3(.3,-.27,-.025),rubber)
		for i in range(5):box(root,Vector3(.16,.018,.025),Vector3(.3,-.115,-.43-i*.07),steel)
	if id == "shotgun":
		cylinder(root,.04,.54,Vector3(.3,-.315,-.98),steel)
		box(root,Vector3(.19,.14,.3),Vector3(.3,-.29,-.91),trim)
		for i in range(5):box(root,Vector3(.2,.012,.015),Vector3(.3,-.21,-.8-i*.045),rubber)
	elif id == "precision":
		cylinder(root,.065,.35,Vector3(.3,-.055,-.6),rubber)
		cylinder(root,.055,.02,Vector3(.3,-.055,-.785),light)
		box(root,Vector3(.12,.07,.16),Vector3(.3,-.105,-.61),steel)
	elif id == "plasma":
		for side in [-1,1]:
			box(root,Vector3(.065,.17,.4),Vector3(.3+side*.12,-.23,-.82),trim)
			for i in range(4):
				cylinder(root,.063,.02,Vector3(.3+side*.12,-.23,-.7-i*.085),light)
		box(root,Vector3(.065,.055,.28),Vector3(.3,-.115,-.83),light)
	return root
