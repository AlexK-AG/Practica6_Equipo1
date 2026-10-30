extends SceneTree

func _initialize() -> void:
	preload("res://tests/helpers/test_paths.gd").prepare()
	call_deferred("run")

func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	var campaign = root.get_node("Campaign")
	campaign.profiles = {}
	campaign.select_profile("Captura de expansión")
	campaign.profile().completed = [0, 1, 2, 3, 4, 5, 6]
	var menu = load("res://scenes/start.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu.show_page("SettingsPage")
	await capture("res://.godot/test-results/capturas/expansion-options.png")
	menu.queue_free()
	await process_frame
	for level in [0, 1, 6]:
		var game = load(campaign.LEVELS[level].path).instantiate()
		root.add_child(game)
		current_scene = game
		game.set_pause(true)
		game.menu.hide()
		await capture("res://.godot/test-results/capturas/expansion-level-%d.png" % (level + 1))
		if level == 1:
			game.player.equip("shotgun")
			game.update_hud()
			await capture("res://.godot/test-results/capturas/expansion-shotgun.png")
		game.queue_free()
		await process_frame
		paused = false
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(0.3).timeout
	print("EXPANSION GALLERY PASS")
	quit()
