extends SceneTree
var campaign: Node

func _initialize() -> void:
	preload("res://tests/helpers/test_paths.gd").prepare()
	call_deferred("run")

func capture(name: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png("res://.godot/test-results/capturas/station-" + name + ".png")
	return picture

func freeze(game: Node) -> void:
	if game.has_node("LoadoutScreen"):
		game.get_node("LoadoutScreen").accept()
	game.set_pause(false)
	game.player.set_physics_process(false)
	game.mission.set_process(false)
	for child in game.get_children():
		if child is EnemyController:
			child.set_physics_process(false)

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/test-results/logs/station-preview-profile.cfg"
	campaign.profiles = {}
	campaign.select_profile("Vista de estación")
	campaign.profile().completed = range(10)
	for index in range(10):
		campaign.profile().erase("checkpoint")
		var game = load(campaign.LEVELS[index].path).instantiate()
		root.add_child(game)
		current_scene = game
		freeze(game)
		await capture("sector-%d" % (index + 1))
		if index == 2:
			var pickup: Node3D
			for item in game.mission.objects:
				if not item.weapon_id.is_empty():
					pickup = item
			game.player.position = pickup.position + Vector3(0, 0, 2.7)
			game.player.camera.look_at(pickup.position + Vector3(0, 1.2, 0))
			await capture("shotgun-found")
		game.get_node("HUD").hide()
		game.player.weapon.hide()
		game.get_node("Arena/Ceilings").hide()
		game.player.camera.global_position = Vector3(42, 60, 56)
		game.player.camera.look_at(Vector3.ZERO)
		game.player.camera.fov = 55
		var preview := await capture("layout-%d" % (index + 1))
		preview.resize(480, 270, Image.INTERPOLATE_LANCZOS)
		preview.save_png("res://assets/previews/levels/level_%d.png" % (index + 1))
		game.queue_free()
		await process_frame
		paused = false
	campaign.profile().erase("checkpoint")
	campaign.profile().weapon_unlocks = ["rifle", "shotgun", "precision", "plasma"]
	var game = load(campaign.LEVELS[9].path).instantiate()
	root.add_child(game)
	current_scene = game
	await capture("equipment")
	game.queue_free()
	await process_frame
	paused = false
	game = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	freeze(game)
	await capture("tutorial")
	game.queue_free()
	await process_frame
	var menu = load("res://scenes/start.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu.show_levels()
	await capture("level-cards")
	menu.queue_free()
	await process_frame
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(0.3).timeout
	print("STATION GALLERY PASS")
	quit()
