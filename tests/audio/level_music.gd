extends SceneTree
## No profiles are created or saved; isolates audio preferences in memory.
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
	# Bypass the shared campaign test fixture as well as real player saves.
	campaign.save_path = "res://.godot/level-music-private.cfg"
	var original_volume: float = campaign.music_volume
	var streams: Array[String] = []
	campaign.music_volume = 0.65
	for level in range(10):
		campaign.play_music(level)
		var stream: AudioStreamWAV = campaign.music.stream
		check(stream != null, "Missing music for level %d" % (level + 1))
		if stream == null:
			continue
		check(not streams.has(stream.resource_path), "Levels must have distinct music")
		streams.append(stream.resource_path)
		check(stream.stereo and stream.mix_rate == 22050, "Stereo music format")
		check(is_equal_approx(stream.get_length(), 32.0), "Full 32-second score")
		check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_begin == 0 and stream.loop_end == 705600, "Whole-track seamless loop")
		check(campaign.music.playing and not campaign.music.stream_paused, "Audible music started")
		var pcm: PackedByteArray = stream.data
		check(pcm.size() > 1000, "Nonempty music")
		check(absf(campaign.music.volume_db - (linear_to_db(0.65) - 10)) < 0.001, "Configured mix volume retained")
		campaign.music_volume = 0
		campaign.apply_audio()
		check(campaign.music.stream_paused, "Mute preference pauses music")
		campaign.music_volume = 0.65
		campaign.apply_audio()
		check(not campaign.music.stream_paused, "Unmute resumes music")
		await process_frame
	campaign.play_music(-1)
	check(campaign.music.stream.resource_path == "res://assets/audio/menu_tension.wav", "Menu soundtrack independent from levels")
	campaign.music_volume = original_volume
	campaign.apply_audio()
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(.3).timeout
	print("LEVEL MUSIC: %d failures, %d unique scores" % [failures, streams.size()])
	quit(0 if failures == 0 else 1)
