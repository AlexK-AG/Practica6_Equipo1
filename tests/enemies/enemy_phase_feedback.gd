extends SceneTree
## Verify the real phase controller keeps the announced destination visible.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	var campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/enemy-phase-private.cfg"
	campaign.profiles = {}
	campaign.select_profile("Phase feedback")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_pause(false)
	game.player.set_physics_process(false)
	game.player.position = Vector3(0,.1,32)
	game.mission.set_process(false)
	game.mission.doors.set_process(false)
	for actor in game.get_children():
		if actor is EnemyController:
			game.remove_child(actor)
			actor.free()
	var phase = load("res://scenes/actors/enemy_17.tscn").instantiate()
	phase.name = "PhaseFeedback"
	phase.position = Vector3(0,.1,24)
	phase.alerted = true
	game.add_child(phase)
	phase.set_physics_process(false)
	phase.phase_wait = 1.0
	await physics_frame
	phase._physics_process(.02)
	assert(phase.tactics.pending_blink and is_instance_valid(phase.tactics.blink_marker))
	var destination: Vector3 = phase.tactics.blink_goal
	assert(destination.distance_to(phase.position) > 1, "Fixture must have an actual safe lateral destination")
	assert(phase.tactics.blink_marker.visible)
	phase._physics_process(1.1)
	assert(phase.phase_left > 0 and phase.collision_layer == 0)
	assert(phase.tactics.blink_marker.visible, "Telegraph remains visible while the enemy is invisible")
	assert(phase.tactics.blink_marker.global_position.distance_to(destination) < .15)
	game.mission.checkpoint()
	var state: Dictionary = campaign.profile().checkpoint.enemies[0]
	game.mission.restore_enemies([state])
	phase = game.get_node("PhaseFeedback")
	phase.set_physics_process(false)
	assert(phase.phase_left > 0 and phase.tactics.pending_blink and phase.tactics.blink_marker.visible, "Checkpoint restores phase and its visible destination")
	phase.special_tick(2.0)
	assert(phase.position.distance_to(destination) < .15 and phase.collision_layer == 1, "Enemy reappears at the previously announced safe point")
	assert(not phase.tactics.pending_blink)
	game.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	campaign.music.stream_paused = false
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(.3).timeout
	print("ENEMY PHASE FEEDBACK: PASS")
	quit()
