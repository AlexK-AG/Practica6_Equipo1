extends SceneTree
## Reproducible previews from the real kit meshes and authored maps.
const Kit = preload("res://scripts/common/kit.gd")
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")

class Studio extends Node3D:
	var level_number: int = 1
	var finished: bool = true

func _initialize() -> void:
	preload("res://tests/helpers/test_paths.gd").prepare()
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/previews/enemies")
	DirAccess.make_dir_recursive_absolute("res://assets/previews/menu")
	var campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/test-results/logs/preview-build-profile.cfg"
	campaign.profiles = {"preview": campaign.fresh_profile("Preview")}
	campaign.active_id = "preview"
	campaign.profile().completed = range(10)
	campaign.music_volume = 0
	var viewport := SubViewport.new()
	viewport.size = Vector2i(384, 384)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var studio := Studio.new()
	viewport.add_child(studio)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("0b1423")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b4c9de")
	environment.environment.ambient_light_energy = 0.65
	studio.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-32, -28, 0)
	light.light_energy = 1.3
	studio.add_child(light)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2, 2, -2)
	rim.light_color = Color("70d8ef")
	rim.light_energy = 1.5
	studio.add_child(rim)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	studio.add_child(camera)
	for index in range(Catalog.ENTRIES.size()):
		var actor: Node3D = load("res://scenes/actors/enemy_%d.tscn" % index).instantiate()
		actor.position = Vector3.ZERO
		actor.set_physics_process(false)
		actor.get_node("Title").hide()
		studio.add_child(actor)
		var bounds := AABB()
		for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			bounds = bounds.merge(mesh.transform * mesh.get_aabb())
		var height: float = maxf(1.7, bounds.size.y)
		camera.position = bounds.get_center() + Vector3(height * 0.9, height * 0.3, height * 1.55)
		camera.look_at(bounds.get_center())
		var projected := AABB()
		for corner in range(8):
			var point := camera.transform.affine_inverse() * bounds.get_endpoint(corner)
			projected = AABB(point, Vector3.ZERO) if corner == 0 else projected.expand(point)
		camera.size = maxf(projected.size.y, projected.size.x) * 1.12
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://assets/previews/enemies/enemy_%02d.png" % index)
		actor.queue_free()
		await process_frame
	viewport.queue_free()
	await process_frame
	for shot in [
		{"level": 2, "file": "menu_station", "from": Vector3(-7, 2.4, -10), "to": Vector3(3, 1.8, -20)},
		{"level": 5, "file": "menu_fortress", "from": Vector3(-6, 2.4, 9), "to": Vector3(5, 1.8, -5)},
		{"level": 7, "file": "menu_hangar", "from": Vector3(0, 2.4, 4), "to": Vector3(0, 1.8, -18)}
	]:
		campaign.profile().erase("checkpoint")
		var game = load(campaign.LEVELS[shot.level].path).instantiate()
		root.add_child(game)
		current_scene = game
		if game.has_node("LoadoutScreen"):
			game.get_node("LoadoutScreen").accept()
		game.set_pause(false)
		game.player.set_physics_process(false)
		game.mission.set_process(false)
		game.get_node("HUD").hide()
		game.player.weapon.hide()
		for item in game.mission.objects:
			item.hide()
		for actor in game.get_children():
			if actor is EnemyController:
				actor.set_physics_process(false)
				actor.title.hide()
		game.player.camera.global_position = shot.from
		game.player.camera.look_at(shot.to)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://assets/previews/menu/%s.png" % shot.file)
		game.queue_free()
		await process_frame
		paused = false
	campaign.music.stop()
	campaign.music.stream = null
	print("MENU PREVIEWS PASS: ", Catalog.ENTRIES.size(), " enemies, 3 station views")
	quit()
