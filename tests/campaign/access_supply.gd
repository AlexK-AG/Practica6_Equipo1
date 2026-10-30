extends SceneTree
var campaign: Node

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/access-supply-tests.cfg"
	campaign.profiles = {}
	assert(campaign.select_profile("Access supplies"))
	campaign.profile().completed = range(10)
	for level in [3, 5]:
		campaign.profile().erase("checkpoint")
		campaign.profile().pending = -1
		var game: Node = load(campaign.LEVELS[level - 1].path).instantiate()
		root.add_child(game)
		current_scene = game
		game.set_pause(false)
		game.player.set_physics_process(false)
		game.mission.set_process(false)
		for enemy in game.get_children():
			if enemy is EnemyController:
				enemy.set_physics_process(false)
		await physics_frame
		var cache: Node3D
		for item in game.mission.objects:
			if item.title == "SUMINISTROS DE ACCESO":
				cache = item
		assert(cache != null and cache.active, "Initial supply exists")
		var distance: float = cache.position.distance_to(game.player.position)
		assert(distance >= 3 and distance <= 7, "Supply sits near, rather than on, spawn")
		assert(not game.route(game.player.position, cache.position).is_empty(), "Supply is reachable without unlocking sectors")
		assert(game.mission.interact_object(cache.object_id), "Initial supply can be collected")
		assert(game.mission.used_supplies.has(cache.object_id))
		if level == 3:
			var early: Node = game.mission.early
			assert(early.gate.position == Vector3(17, 0, -2))
			early.set_shutter(true)
			await physics_frame
			for x in [15.5, 17.0, 18.5]:
				var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 1.5, -3), Vector3(x, 1.5, -1)))
				assert(not hit.is_empty() and hit.collider == early.gate, "Shutter seals the entire actual corridor width")
			assert(game.grid.is_point_solid(Vector2i(17, -2)), "Navigation matches closed shutter")
			early.set_shutter(false)
			await physics_frame
			assert(not game.grid.is_point_solid(Vector2i(17, -2)), "Open shutter restores the corridor")
			var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(17, 1.5, -3), Vector3(17, 1.5, -1)))
			assert(hit.is_empty(), "Open shutter removes physical blocker")
			game.mission.done.assign([0, 1, 2, 3, 4, 5])
			game.mission.doors.sync(false)
			early.set_shutter(true)
			assert(not game.route(Vector3(0,.1,-18), game.player.position).is_empty(), "West gallery still allows evacuation")
		print("PASS: initial supply and access geometry level %d" % level)
		paused = false
		for audio in root.find_children("*", "AudioStreamPlayer", true, false):
			audio.stop()
		await process_frame
		game.queue_free()
		await process_frame
	await create_timer(.08).timeout
	quit()
