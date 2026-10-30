extends SceneTree
## Exercise the complete controller for all subtypes together in an authored map.
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
	campaign.save_path = "res://.godot/enemy-pressure-private.cfg"
	campaign.profiles = {}
	campaign.select_profile("Enemy pressure")
	campaign.profile().completed = range(10)
	campaign.profile().pending = -1
	var game = load("res://scenes/levels/level_10.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	if game.has_node("LoadoutScreen"):
		game.get_node("LoadoutScreen").accept()
	game.set_pause(false)
	game.player.set_physics_process(false)
	game.player.max_health = 100000
	game.player.health = 100000
	game.mission.set_process(false)
	game.mission.doors.set_process(false)
	for actor in game.get_children():
		if actor is EnemyController:
			game.remove_child(actor)
			actor.free()
	game.mission.done.assign(range(game.mission.objective_count-1))
	game.mission.doors.sync(false)
	game.mission.build_spawn_cells()
	for beacon in game.get_node("HUD/Interface").get_children():
		if beacon.get_script() == preload("res://scripts/missions/objective_beacons.gd"):
			beacon.set_process(false)
	var points: Array[Vector3] = game.mission.valid_spawn_points()
	check(points.size() >= 18, "Authored map has enough separated spawn positions")
	var subjects: Array[Node] = []
	for kind in range(mini(18,points.size())):
		var actor = load("res://scenes/actors/enemy_%d.tscn" % kind).instantiate()
		actor.name = "PressureKind%d" % kind
		actor.position = points[kind]
		actor.alerted = true
		game.add_child(actor)
		actor.tactics.ability_cooldown = 1.0 + kind%3*.3
		if kind % 3 == 0:
			actor.health = maxi(1,roundi(actor.max_health*.6))
		subjects.append(actor)
	await physics_frame
	var started := Time.get_ticks_msec()
	for frame in range(300):
		await physics_frame
		for actor in subjects:
			if is_instance_valid(actor) and not actor.is_queued_for_deletion():
				check(actor.position.is_finite() and actor.velocity.is_finite(), "Mixed encounter retains finite physical state")
	var active := 0
	var sensed := 0
	for actor in subjects:
		if is_instance_valid(actor) and not actor.is_queued_for_deletion():
			active += 1
			if actor.tactics.clock > 0:
				sensed += 1
	check(sensed >= 14, "All surviving subtypes actively evaluate tactics")
	print("MIXED ENCOUNTER: active=",active," tactical=",sensed," physics_steps=300 elapsed_ms=",Time.get_ticks_msec()-started)
	game.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	campaign.music.stream_paused = false
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(.3).timeout
	print("ENEMY AI PRESSURE: %d failures" % failures)
	quit(1 if failures else 0)
