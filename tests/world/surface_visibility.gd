extends SceneTree
const Visibility = preload("res://scripts/visuals/surface_visibility.gd")

func _initialize() -> void:
	preload("res://tests/helpers/test_paths.gd").prepare()
	call_deferred("run")

func run() -> void:
	var files: Array[String] = []
	for group in ["enemies", "props", "structures"]:
		var folder := DirAccess.open("res://assets/models/" + group)
		for file in folder.get_files():
			if file.ends_with(".obj"):
				files.append("res://assets/models/" + group + "/" + file)
	var tested := 0
	for file in files:
		var mesh := load(file) as Mesh
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		root.add_child(instance)
		var originals: Array[Material] = []
		for surface in range(mesh.get_surface_count()):
			originals.append(mesh.surface_get_material(surface))
		var expected: bool = Visibility.eligible(mesh) and not Visibility.audit(mesh).surfaces.is_empty()
		var changes := Visibility.fix_mesh(instance)
		assert((changes > 0) == expected, file + ": open surfaces selected accurately")
		for surface in range(mesh.get_surface_count()):
			assert(mesh.surface_get_material(surface) == originals[surface], "Shared mesh material not replaced")
		assert(Visibility.fix_mesh(instance) == 0, "Second application is idempotent")
		print("AUDIT %s: %d boundaries, %d corrected surfaces" % [file, Visibility.audit(mesh).boundaries, changes])
		instance.queue_free()
		await process_frame
		tested += 1
	assert(tested == 20, "All relocated models were audited")
	var closed := MeshInstance3D.new()
	closed.mesh = BoxMesh.new()
	closed.material_override = StandardMaterial3D.new()
	assert(Visibility.fix_mesh(closed) == 0)
	assert(closed.material_override.cull_mode == BaseMaterial3D.CULL_BACK)
	closed.free()
	var open_mesh := MeshInstance3D.new()
	open_mesh.mesh = load("res://assets/models/props/Prop_Vent_Small.obj")
	var shared := StandardMaterial3D.new()
	shared.albedo_color = Color("c39a6c")
	open_mesh.material_override = shared
	assert(Visibility.fix_mesh(open_mesh) == 1)
	assert(shared.cull_mode == BaseMaterial3D.CULL_BACK)
	assert(open_mesh.material_override.cull_mode == BaseMaterial3D.CULL_DISABLED)
	assert(open_mesh.material_override.albedo_color == shared.albedo_color)
	open_mesh.free()
	if "--capture" in OS.get_cmdline_user_args():
		await capture()
	print("PASS: %d meshes audited; two-sided open props, closed solids and material isolation" % tested)
	quit()

func capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 320)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("102033")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 1.0
	viewport.add_child(environment)
	var camera := Camera3D.new()
	camera.position = Vector3(0, -3, 1)
	viewport.add_child(camera)
	camera.look_at(Vector3.ZERO)
	var comparison := Image.create(960, 640, false, Image.FORMAT_RGBA8)
	var row := 0
	for file in ["Platform_Metal", "Prop_Crate4"]:
		camera.position = Vector3(0, -3, 1)
		camera.look_at(Vector3.ZERO)
		var instance := MeshInstance3D.new()
		instance.mesh = load(preload("res://scripts/common/kit.gd").model_path(file))
		var bounds := instance.mesh.get_aabb()
		var extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		instance.scale = Vector3.ONE * 2.0 / extent
		instance.position = -(bounds.position + bounds.size * 0.5) * instance.scale
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("5dd2cb")
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		instance.material_override = material
		viewport.add_child(instance)
		var before := 0
		for fixed in [false, true]:
			if fixed:
				Visibility.fix_mesh(instance)
			await process_frame
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			var pixels := 0
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					if image.get_pixel(x, y).g > 0.5:
						pixels += 1
			if not fixed:
				before = pixels
			else:
				print("RENDER %s before=%d after=%d" % [file, before, pixels])
				if file == "Platform_Metal":
					assert(pixels > before + 100, file + ": rear faces become visible")
			comparison.blit_rect(image, Rect2i(0, 0, 480, 320), Vector2i(480 if fixed else 0, row * 320))
		instance.queue_free()
		await process_frame
		row += 1
	comparison.save_png("res://.godot/test-results/capturas/surface-backface-before-after.png")
