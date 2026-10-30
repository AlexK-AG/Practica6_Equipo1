extends SceneTree
## Standalone audio check. Never creates or writes a player profile.
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
	campaign.save_path = "res://.godot/weapon-audio-private.cfg"
	var player := AudioStreamPlayer.new()
	root.add_child(player)
	player.bus = &"Effects"
	player.volume_db = -10
	player.max_polyphony = 4
	var paths: Array[String] = []
	for name in ["pistol", "rifle", "shotgun", "precision", "plasma", "knife_swing", "knife_hit"]:
		var path := "res://assets/audio/weapons/%s.wav" % name
		var stream := load(path) as AudioStreamWAV
		check(stream != null, "Missing weapon sound: " + name)
		if stream == null:
			continue
		check(not paths.has(stream.resource_path), "Unique weapon audio")
		paths.append(stream.resource_path)
		check(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Weapon shots must finish")
		check(stream.mix_rate == 44100 and not stream.stereo, "Mono 44.1kHz weapon format")
		check(stream.get_length() >= .19 and stream.get_length() <= .90, "Controlled shot tail")
		player.stream = stream
		player.play()
		check(player.playing, "Weapon playback started: " + name)
		check(player.bus == &"Effects" and is_equal_approx(player.volume_db, -10), "Effects mix maintained")
		await create_timer(stream.get_length() + .08).timeout
		check(not player.playing, "Weapon playback finishes: " + name)
	var bus := AudioServer.get_bus_index("Effects")
	var previous_volume: float = campaign.effects_volume
	campaign.effects_volume = 0
	campaign.apply_audio()
	check(AudioServer.is_bus_mute(bus), "Effects mute applies to new sounds")
	campaign.effects_volume = previous_volume
	campaign.apply_audio()
	player.stream = null
	player.queue_free()
	await process_frame
	await process_frame
	print("WEAPON AUDIO: %d failures, %d original effects" % [failures, paths.size()])
	quit(0 if failures == 0 else 1)
