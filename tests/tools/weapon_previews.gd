extends SceneTree
## Captures the shared first-person/pickup models, without running a campaign.
const Visuals = preload("res://scripts/visuals/combat_visuals.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/previews/weapons")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 240)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("a6d8e5")
	environment.environment.ambient_light_energy = 0.7
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("728b9f")
	sky_material.sky_horizon_color = Color("d0dce3")
	sky_material.ground_bottom_color = Color("34475a")
	sky_material.ground_horizon_color = Color("adbccb")
	sky.sky_material = sky_material
	environment.environment.sky = sky
	for constant: String in ClassDB.class_get_integer_constant_list("Environment"):
		if "REFLECT" in constant and constant.ends_with("_SKY"):
			environment.environment.reflected_light_source = ClassDB.class_get_integer_constant("Environment", constant)
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -35, 0)
	light.light_energy = 1.4
	viewport.add_child(light)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1, 1.5, -2)
	rim.light_color = Color("8cb2e4")
	rim.light_energy = 1.0
	viewport.add_child(rim)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	for id in ["pistol", "rifle", "shotgun", "precision", "plasma", "knife"]:
		var weapon: Node3D = Visuals.weapon(id)
		viewport.add_child(weapon)
		var bounds := AABB()
		var first := true
		for mesh: MeshInstance3D in weapon.find_children("*", "MeshInstance3D", true, false):
			var local: AABB = mesh.transform * mesh.get_aabb()
			bounds = local if first else bounds.merge(local)
			first = false
		camera.position = bounds.get_center() + Vector3(1.8, 1.05, 2.2)
		camera.look_at(bounds.get_center())
		var projected := AABB()
		for corner in range(8):
			var point := camera.transform.affine_inverse() * bounds.get_endpoint(corner)
			projected = AABB(point, Vector3.ZERO) if corner == 0 else projected.expand(point)
		camera.size = maxf(0.25, maxf(projected.size.y, projected.size.x / 2.0) * 1.2)
		await process_frame
		await RenderingServer.frame_post_draw
		var error := viewport.get_texture().get_image().save_png("res://assets/previews/weapons/%s.png" % id)
		assert(error == OK)
		weapon.queue_free()
		await process_frame
	print("PASS: six redesigned weapon previews captured from shared combat models")
	quit()

