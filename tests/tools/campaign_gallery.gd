extends SceneTree

func _initialize() -> void:
	preload("res://tests/helpers/test_paths.gd").prepare()
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/test-results/capturas")
	var campaign = root.get_node("Campaign")
	assert("--campaign-test" in OS.get_cmdline_user_args())
	campaign.profiles = {}
	campaign.select_profile("Vista previa")
	campaign.profile().completed = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	for index in range(campaign.LEVELS.size()):
		var game = load(campaign.LEVELS[index].path).instantiate()
		root.add_child(game)
		current_scene = game
		if game.has_node("LoadoutScreen"):
			game.get_node("LoadoutScreen").accept()
		game.set_pause(true)
		game.menu.hide()
		game.get_node("HUD").hide()
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		picture.save_png("res://.godot/test-results/capturas/preview-campaign-%d.png" % (index + 1))
		game.player.weapon.hide()
		game.get_node("Arena/Ceilings").hide()
		game.player.camera.global_position = Vector3(42, 60, 56)
		game.player.camera.look_at(Vector3.ZERO)
		game.player.camera.fov = 55
		await RenderingServer.frame_post_draw
		picture = root.get_texture().get_image()
		picture.resize(480, 270, Image.INTERPOLATE_LANCZOS)
		picture.save_png("res://assets/previews/levels/level_%d.png" % (index + 1))
		paused = false
		root.remove_child(game)
		game.free()
	print("CAMPAIGN GALLERY PASS")
	quit()
