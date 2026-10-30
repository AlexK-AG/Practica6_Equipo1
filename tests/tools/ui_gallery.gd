extends SceneTree

func _initialize() -> void:
	preload("res://tests/helpers/test_paths.gd").prepare()
	call_deferred("run")

func capture(name_of_file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/test-results/capturas/preview-ui-%s.png" % name_of_file)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/test-results/capturas")
	assert("--campaign-test" in OS.get_cmdline_user_args())
	print("AMBIENT COLOR ENUM: ", Environment.AMBIENT_SOURCE_COLOR)
	var campaign = root.get_node("Campaign")
	campaign.profiles = {}
	campaign.active_id = ""
	var start = load("res://scenes/start.tscn").instantiate()
	root.add_child(start)
	current_scene = start
	await capture("profile")
	campaign.select_profile("Piloto")
	start.show_page("MainPage")
	await capture("menu")
	start.show_levels()
	await capture("levels")
	start.show_page("SettingsPage")
	await capture("settings")
	campaign.complete_level(0, 1400)
	start.get_node("UpgradeScreen").refresh()
	await capture("upgrades")
	start.get_node("UpgradeScreen").hide()
	start.show_scores()
	await capture("scores")
	print("UI GALLERY PASS")
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(0.15).timeout
	quit()
