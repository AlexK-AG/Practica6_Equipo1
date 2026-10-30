extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	var campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/scout-video-private.cfg"
	campaign.profiles = {}
	assert(campaign.select_profile("Scout video"))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_pause(false)
	game.player.set_physics_process(false)
	game.player.position = Vector3(25,.01,9.3)
	game.player.max_health = 100000
	game.player.health = 100000
	game.player.shield = 0
	game.mission.set_process(false)
	game.mission.doors.set_process(false)
	for node in game.get_node("HUD/Interface").get_children():
		if node.get_script() == preload("res://scripts/missions/objective_beacons.gd"):
			node.set_process(false)
	for actor in game.get_children():
		if actor is EnemyController:
			game.remove_child(actor)
			actor.free()
	var scouts: Array[Node] = []
	for point in [Vector3(23,.01,3),Vector3(27,.01,3)]:
		var actor = load("res://scenes/actors/enemy_0.tscn").instantiate()
		actor.position = point
		actor.alerted = true
		game.add_child(actor)
		actor.set_physics_process(false)
		scouts.append(actor)
	await physics_frame
	var travel := [0.0,0.0]
	var seen := [0,0]
	var reversals := [0,0]
	var last_x := [0.0,0.0]
	for tick in range(540):
		for index in range(2):
			var actor = scouts[index]
			var before: Vector3 = actor.position
			actor._physics_process(1.0/60)
			travel[index] += actor.position.distance_to(before)
			if actor.steering.clear_shot(actor,game.player.position): seen[index] += 1
			var dx: float = actor.position.x-before.x
			if absf(dx)>.005:
				if dx*last_x[index]<0: reversals[index]+=1
				last_x[index]=dx
		await physics_frame
	var passed := true
	for index in range(2):
		if scouts[index].tactics.shots < 3 or seen[index] < 120:
			passed = false
			push_error("Each explorer must acquire a sustained lane and actually fire rather than oscillate behind the crate")
		print("SCOUT VIDEO ",index," pos=",scouts[index].position," shots=",scouts[index].tactics.shots," travel=",travel[index]," clear_frames=",seen[index]," x_reversals=",reversals[index])
	passed = passed and game.player.health < 100000
	print("SCOUT DAMAGE ",100000-game.player.health)
	game.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	campaign.music.stream_paused = false
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(.3).timeout
	print("SCOUT COVER MOTION: ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
