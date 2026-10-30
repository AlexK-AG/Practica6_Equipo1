extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	var campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/menu-audio-private.cfg"
	var previous_volume: float = campaign.music_volume
	campaign.music_volume = .45
	var menu = load("res://scenes/start.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	var audio: AudioStreamPlayer = menu.menu_music_player
	check(audio.stream != null and audio.stream.stereo, "Stereo menu music loaded")
	check(is_equal_approx(audio.stream.get_length(), 32), "Original 32-second duration retained")
	check(audio.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Full menu loop enabled")
	check(audio.stream.mix_rate == 22050 and audio.stream.loop_end == 705600, "Whole track loops at source rate")
	check(audio.stream.format == AudioStreamWAV.FORMAT_16_BITS, "Menu uses uncompressed PCM playback")
	if "--capture-audio" in OS.get_cmdline_user_args():
		var capture := AudioEffectCapture.new()
		capture.buffer_length = 1.0
		AudioServer.add_bus_effect(0, capture)
		await create_timer(.15).timeout
		capture.clear_buffer()
		await create_timer(.4).timeout
		var samples := capture.get_buffer(capture.get_frames_available())
		var energy := 0.0
		for sample in samples:
			energy += (sample.x * sample.x + sample.y * sample.y) * .5
		var rms := sqrt(energy / max(1, samples.size()))
		check(samples.size() > 1000 and rms > .015, "Menu emits audible audio on Master")
		print("MENU OUTPUT RMS: ", rms)
		AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	await create_timer(.12).timeout
	check(audio.playing and audio.get_playback_position() > 0, "Menu playback advances")
	var cursor := audio.get_playback_position()
	for page in ["ProfilePage", "MainPage", "LevelsPage", "SettingsPage"]:
		menu.show_page(page)
		check(audio.playing, "Page transition preserves music: " + page)
	check(audio.get_playback_position() >= cursor, "Page transitions do not restart track")
	audio.seek(31.95)
	await create_timer(.22).timeout
	check(audio.playing and audio.get_playback_position() < .6, "Loop crosses end without stopping")
	campaign.music_volume = 0
	menu.apply_menu_audio()
	check(audio.stream_paused, "Configured menu mute respected")
	campaign.music_volume = .45
	menu.apply_menu_audio()
	check(not audio.stream_paused, "Unmute resumes menu")
	audio.stop()
	audio.stream = null
	menu.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	campaign.play_music(0)
	check(campaign.music.playing and campaign.music.stream.resource_path.contains("levels/01_laboratory"), "Level music remains independent after menu")
	campaign.music.stop()
	campaign.music.stream = null
	campaign.music_volume = previous_volume
	campaign.apply_audio()
	await create_timer(.1).timeout
	print("MENU AUDIO: %d failures" % failures)
	quit(0 if failures == 0 else 1)
