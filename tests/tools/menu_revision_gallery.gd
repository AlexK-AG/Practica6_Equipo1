extends SceneTree

func _initialize() -> void:
	preload("res://tests/helpers/test_paths.gd").prepare()
	call_deferred("run")

func capture(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var campaign = root.get_node("Campaign")
	# Presentation-only fixture. Never writes user profiles or shared test saves.
	campaign.save_path = "res://.godot/test-results/logs/menu-preview-profile.cfg"
	campaign.profiles = {"preview": campaign.fresh_profile("Piloto")}
	campaign.active_id = "preview"
	campaign.music_volume = 0.65
	campaign.profile()["discovered_enemies"] = [0, 2, 13]
	var audio_capture := AudioEffectCapture.new()
	audio_capture.buffer_length = 0.2
	AudioServer.add_bus_effect(0, audio_capture)
	if "--refresh-menu-image" in OS.get_cmdline_user_args():
		var game = load(campaign.LEVELS[2].path).instantiate()
		campaign.profile().completed = range(10)
		root.add_child(game)
		current_scene = game
		game.player.set_physics_process(false)
		game.mission.set_process(false)
		game.get_node("HUD").hide()
		game.player.weapon.hide()
		for item in game.mission.objects:
			item.hide()
		for child in game.get_children():
			if child is EnemyController:
				child.set_physics_process(false)
				child.title.hide()
		game.player.camera.global_position = Vector3(-7, 2.4, -10)
		game.player.camera.look_at(Vector3(3, 1.8, -20))
		await capture("res://assets/previews/menu/menu_station.png")
		game.queue_free()
		await process_frame
		campaign.music.stop()
		campaign.music.stream = null
		quit()
		return
	var menu = load("res://scenes/start.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	# Loading the fully authored scene can fill the capture with startup silence.
	audio_capture.clear_buffer()
	await capture("res://.godot/test-results/capturas/menu-revision-main.png")
	var slideshow = menu.find_child("MainSlideshow", true, false)
	assert(slideshow != null)
	var initial_texture = slideshow.texture
	slideshow.next_slide()
	await create_timer(1.1).timeout
	assert(slideshow.texture != initial_texture)
	var mixed_audio := audio_capture.get_buffer(audio_capture.get_frames_available())
	var audio_peak := 0.0
	for frame in mixed_audio:
		audio_peak = maxf(audio_peak, maxf(absf(frame.x), absf(frame.y)))
	assert(audio_peak > 0.005, "Menu music must produce audible samples on Master")
	await capture("res://.godot/test-results/capturas/menu-revision-slide-2.png")
	menu.show_page("EnemyPage")
	await capture("res://.godot/test-results/capturas/menu-revision-index.png")
	var cards = menu.find_child("EnemyCards", true, false)
	assert(cards.get_child_count() == preload("res://scripts/enemies/enemy_catalog.gd").ENTRIES.size())
	assert(cards.get_child(0).get_meta("discovered"))
	assert(not cards.get_child(1).get_meta("discovered"))
	for card in cards.get_children():
		assert(card.find_child("EnemyPreview", true, false).texture != null)
	campaign.profile().discovered_enemies = range(preload("res://scripts/enemies/enemy_catalog.gd").ENTRIES.size())
	menu.show_page("EnemyPage")
	await process_frame
	await process_frame
	cards.get_parent().scroll_vertical = int(cards.get_parent().get_v_scroll_bar().max_value)
	await capture("res://.godot/test-results/capturas/menu-revision-index-complete.png")
	campaign.profile().discovered_enemies = [0, 2, 13]
	menu.show_levels()
	await capture("res://.godot/test-results/capturas/menu-revision-levels.png")
	menu.show_page("SettingsPage")
	await capture("res://.godot/test-results/capturas/menu-revision-settings.png")
	menu.show_profiles()
	await capture("res://.godot/test-results/capturas/menu-revision-profiles.png")
	campaign.profile().pending = 0
	menu.get_node("UpgradeScreen").refresh()
	await capture("res://.godot/test-results/capturas/menu-revision-upgrades.png")
	menu.get_node("UpgradeScreen").hide()
	campaign.profile().pending = -1
	assert(menu.find_child("EnemyIndex", true, false) != null)
	assert(menu.menu_music_player.playing)
	assert(menu.menu_music_player.stream.loop_end > menu.menu_music_player.stream.mix_rate * 31)
	assert(not menu.menu_music_player.stream_paused)
	assert(menu.menu_music_player.volume_db > -6)
	assert(menu.menu_music_player.get_playback_position() > 0)
	assert(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")))
	menu.menu_music_player.seek(31.85)
	await create_timer(0.45).timeout
	assert(menu.menu_music_player.playing)
	assert(menu.menu_music_player.get_playback_position() < 1.0, "Music must loop after 32 seconds")
	campaign.music_volume = 0
	menu.apply_menu_audio()
	assert(menu.menu_music_player.stream_paused)
	campaign.music_volume = 0.65
	menu.apply_menu_audio()
	assert(not menu.menu_music_player.stream_paused)
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	menu.queue_free()
	await process_frame
	var game = load(campaign.LEVELS[0].path).instantiate()
	root.add_child(game)
	current_scene = game
	game.set_pause(true)
	await capture("res://.godot/test-results/capturas/menu-revision-pause.png")
	assert(game.menu.get_global_rect().end.y <= root.size.y, "Pause buttons must stay inside the window")
	paused = false
	print("MENU REVISION PASS · mixed music peak ", audio_peak, " · 32-second loop verified")
	campaign.music.stop()
	campaign.music.stream = null
	quit()
