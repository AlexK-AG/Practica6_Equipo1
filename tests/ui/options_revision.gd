extends SceneTree

class ContextCampaign extends "res://scripts/persistence/campaign.gd":
	var context: String = "embedded"
	var reject_save := false
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
	func display_context() -> String:
		return context
	func save_data() -> bool:
		if reject_save:
			save_error = "Simulated write failure"
			return false
		return super.save_data()

func _initialize() -> void:
	preload("res://tests/helpers/test_paths.gd").prepare()
	call_deferred("run")

func capture(name: String) -> Image:
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		return null
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png("res://.godot/test-results/capturas/options-%s.png" % name)
	return picture

func luminance(picture: Image) -> float:
	var total := 0.0
	var count := 0
	for x in range(100, mini(picture.get_width() - 100, 1180), 40):
		for y in range(160, mini(picture.get_height() - 160, 500), 40):
			var color := picture.get_pixel(x, y)
			total += color.get_luminance()
			count += 1
	return total / maxf(1, count)

func run() -> void:
	var campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/test-results/logs/options-revision.cfg"
	campaign.options = campaign.DEFAULT_OPTIONS.duplicate(true)
	campaign.profiles = {"pilot": campaign.fresh_profile("Pilot")}
	campaign.active_id = "pilot"
	campaign.profile().completed = [0, 1]
	campaign.profile().record = 3456
	campaign.profile().discovered_enemies = [0, 2]
	campaign.profile().tutorial_completed = true
	campaign.music_volume = 0
	var untouched: Dictionary = campaign.profiles.duplicate(true)
	assert(campaign.save_data())
	campaign.apply_display()
	root.size = Vector2i(1280, 720)
	await process_frame
	var original_window: Vector2i = DisplayServer.window_get_size() if campaign.display_context() == "standalone" else Vector2i.ZERO
	assert(campaign.preview_display({"resolution": 1, "render_scale": .75}, .08))
	assert(campaign.screen_preview_active())
	assert(is_equal_approx(root.scaling_3d_scale, .75))
	assert(campaign.save_data())
	var stored: Dictionary = campaign.store.load_snapshot()
	assert(stored.settings.options.resolution == 0)
	assert(stored.settings.options.render_scale == 1.0)
	var deadline: int = Time.get_ticks_msec() + 1500
	while campaign.screen_preview_active() and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(not campaign.screen_preview_active())
	assert(campaign.options.resolution == 0)
	assert(campaign.options.render_scale == 1.0)
	if campaign.display_context() == "standalone":
		assert(DisplayServer.window_get_size() == original_window)
	assert(campaign.preview_display({"render_scale": .85}))
	assert(campaign.confirm_display_preview())
	campaign.load_data()
	assert(is_equal_approx(campaign.options.render_scale, .85))
	assert(campaign.profiles == untouched)
	var isolated := ContextCampaign.new()
	isolated.save_path = "res://.godot/test-results/logs/options-embedded-policy.cfg"
	root.add_child(isolated)
	assert(not isolated.preview_display({"resolution": 1}))
	assert(not isolated.preview_display({"fullscreen": true}))
	assert(isolated.options.resolution == 0 and not isolated.options.fullscreen)
	assert(isolated.preview_display({"render_scale": .67}))
	assert(isolated.confirm_display_preview())
	assert(isolated.options.render_scale == .67)
	isolated.reject_save = true
	assert(isolated.preview_display({"render_scale": .75}))
	assert(not isolated.confirm_display_preview())
	assert(isolated.options.render_scale == .67)
	isolated.queue_free()
	await process_frame
	campaign.apply_display()
	var menu = load("res://scenes/start.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu.show_page("SettingsPage")
	var ui: ScrollContainer
	for child in menu.find_children("*", "ScrollContainer", true, false):
		if child.get_script() != null and child.get_script().resource_path.ends_with("game_options.gd"):
			ui = child
	assert(ui != null)
	assert(not ui.has_node("Content/Quality") and not ui.has_node("Content/QualityHint"))
	assert(ui.difficulty.get_item_text(0) == "Dificultad: Fácil")
	ui.set_option("difficulty", 2)
	assert("HP 125" in ui.difficulty_hint.text)
	assert("desde cero" in ui.difficulty_hint.text)
	ui.apply_display_context("embedded")
	assert(ui.resolution.disabled and ui.fullscreen.disabled)
	assert(not ui.render_scale.disabled)
	assert("incrustada" in ui.display_hint.text)
	ui.apply_display_context("standalone")
	assert(not ui.resolution.disabled and not ui.fullscreen.disabled)
	await capture("settings-top")
	ui.request_screen_change("render_scale", .75)
	assert(ui.screen_dialog.visible)
	assert("10 segundos" in ui.screen_dialog.dialog_text)
	await capture("confirmation")
	ui.screen_dialog.canceled.emit()
	assert(not ui.screen_dialog.visible)
	assert(campaign.options.render_scale == .85)
	assert(campaign.preview_display({"render_scale": .75}, .08))
	ui.open_screen_confirmation()
	deadline = Time.get_ticks_msec() + 1500
	while campaign.screen_preview_active() and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(not ui.screen_dialog.visible)
	assert(campaign.options.render_scale == .85)
	ui.request_screen_change("render_scale", .67)
	menu.show_page("MainPage")
	assert(not campaign.screen_preview_active())
	assert(campaign.options.render_scale == .85)
	menu.show_page("SettingsPage")
	ui.waiting_action = "forward"
	ui.waiting_button = ui.binding_buttons.forward
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Z
	key.pressed = true
	ui._input(key)
	assert(campaign.bindings.forward == KEY_Z)
	campaign.sensitivity = .003
	campaign.music_volume = .1
	campaign.effects_volume = .2
	ui.reset_settings()
	assert(campaign.profiles == untouched)
	assert(campaign.bindings.is_empty())
	assert(campaign.sensitivity == campaign.DEFAULT_SENSITIVITY)
	assert(campaign.music_volume == campaign.DEFAULT_MUSIC_VOLUME)
	assert(campaign.effects_volume == campaign.DEFAULT_EFFECTS_VOLUME)
	assert(is_equal_approx(menu.get_node("%MusicSlider").value, campaign.DEFAULT_MUSIC_VOLUME))
	assert(is_equal_approx(menu.get_node("%SensitivitySlider").value, campaign.DEFAULT_SENSITIVITY))
	assert(campaign.screen_preview_active())
	await process_frame
	assert(campaign.confirm_display_preview())
	assert(not ui.screen_dialog.visible)
	assert(campaign.options == campaign.DEFAULT_OPTIONS)
	campaign.load_data()
	assert(campaign.options == campaign.DEFAULT_OPTIONS)
	assert(campaign.profiles == untouched)
	ui.scroll_vertical = int(ui.get_v_scroll_bar().max_value)
	await capture("settings-bottom")
	ui.request_screen_change("render_scale", .75)
	menu.menu_music_player.stream_paused = false
	menu.menu_music_player.stop()
	menu.menu_music_player.stream = null
	menu.queue_free()
	current_scene = null
	await process_frame
	assert(not campaign.screen_preview_active())
	assert(campaign.options.render_scale == 1.0)
	campaign.music_volume = 0
	var game = load(campaign.LEVELS[0].path).instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	for child in game.find_children("*", "Node", true, false):
		child.process_mode = Node.PROCESS_MODE_DISABLED
	var world: WorldEnvironment = game.get_node("World")
	var original: Environment = world.get_meta("authored_environment")
	var original_ambient := world.environment.ambient_light_energy
	var original_exposure := world.environment.tonemap_exposure
	var normal_picture := await capture("brightness-100")
	campaign.options.brightness = .75
	campaign.apply_game_options()
	var dark_picture := await capture("brightness-75")
	campaign.options.brightness = 1.3
	campaign.options.fov = 90.0
	campaign.apply_game_options()
	assert(is_equal_approx(world.environment.tonemap_exposure, original_exposure * 1.3))
	assert(world.environment.ambient_light_energy == original_ambient)
	assert(game.player.camera.fov == 90)
	campaign.apply_game_options()
	assert(is_equal_approx(world.environment.tonemap_exposure, original_exposure * 1.3))
	var bright_picture := await capture("brightness-130")
	if normal_picture != null:
		assert(luminance(bright_picture) > luminance(normal_picture) * 1.02, "Brightness must visibly affect the actual 3D image")
	campaign.options.brightness = 1.35
	campaign.apply_game_options()
	var maximum_picture := await capture("brightness-135")
	if dark_picture != null:
		assert(luminance(maximum_picture) > luminance(dark_picture) * 1.1, "Brightness extremes must change the real Compatibility output")
		print("BRIGHTNESS .75 -> 1.35 luminance: ", luminance(dark_picture), " -> ", luminance(maximum_picture))
	var test_light := OmniLight3D.new()
	test_light.shadow_enabled = true
	game.get_node("Arena").add_child(test_light)
	original.fog_enabled = true
	campaign.options.quality = 0
	campaign.apply_game_options()
	assert(not test_light.shadow_enabled and not world.environment.fog_enabled)
	assert(game.get_viewport().msaa_3d == Viewport.MSAA_DISABLED)
	campaign.options.quality = 2
	campaign.apply_game_options()
	assert(test_light.shadow_enabled and world.environment.fog_enabled)
	assert(game.get_viewport().msaa_3d == Viewport.MSAA_4X)
	campaign.music.stream_paused = false
	campaign.music.stop()
	campaign.music.stream = null
	game.queue_free()
	current_scene = null
	await process_frame
	await create_timer(.3).timeout
	print("OPTIONS REVISION PASS · timer/cancel/confirm/exit rollback, embedded policy, profile-safe defaults, controls, quality/brightness/FOV")
	quit()
