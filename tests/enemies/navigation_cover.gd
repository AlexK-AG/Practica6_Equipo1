extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func freeze(game: Node) -> void:
	game.set_pause(false)
	if game.has_node("LoadoutScreen"):
		game.get_node("LoadoutScreen").accept()
	game.player.set_physics_process(false)
	game.mission.set_process(false)
	game.mission.doors.set_process(false)
	for actor in game.get_children():
		if actor is EnemyController:
			actor.set_physics_process(false)

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	var campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/navigation-cover-private.cfg"
	campaign.profiles = {}
	campaign.select_profile("Navigation cover")
	campaign.profile().completed = range(10)
	campaign.profile().pending = -1
	for level in [1,10]:
		campaign.profile().erase("checkpoint")
		var game = load(campaign.LEVELS[level - 1].path).instantiate()
		root.add_child(game)
		current_scene = game
		freeze(game)
		await physics_frame
		await physics_frame
		if level == 1:
			var hidden := Vector3(-7,.01,7.35)
			var pursuer := Vector3(-7,.01,2)
			check(game.route(pursuer,hidden).is_empty(), "Fixture reproduces conservative crate padding")
			var recovered: PackedVector2Array = game.pursuit_route(pursuer,hidden)
			check(recovered.size() > 1, "Pursuit recovers a path to the player against Cover199")
			if not recovered.is_empty():
				var endpoint: Vector2 = recovered[recovered.size()-1]
				check(game.navigation_segment_clear(hidden,Vector3(endpoint.x,hidden.y,endpoint.y)), "Recovered endpoint stays on the physically connected side of the crate")
			check(game.pursuit_route(hidden,pursuer).size() > 1, "Enemy near cover can recover its own start node")
			var cover: Node3D = game.get_node("Arena/Cover199")
			check(not game.navigation_segment_clear(cover.global_position-Vector3(2.5,0,2.5),cover.global_position+Vector3(2.5,0,2.5)), "Diagonal shortcuts through crate corners are rejected physically")
			check(game.pursuit_route(pursuer,Vector3(1000,0,1000)).is_empty(), "Outside map never clamps to a reachable edge")
			# A solid grid barrier remains impassable even with endpoint recovery.
			var original: AStarGrid2D = game.grid
			game.grid = AStarGrid2D.new()
			game.grid.region = Rect2i(-3,-3,7,7)
			game.grid.update()
			for z in range(-3,4):
				game.grid.set_point_solid(Vector2i(0,z))
			check(game.pursuit_route(Vector3(-2,.1,0),Vector3(2,.1,0)).is_empty(), "Disconnected components still return an empty route")
			game.grid = original
		else:
			game.mission.done.assign([0,1])
			game.mission.doors.arena_sealed = true
			game.mission.doors.sync(false)
			await physics_frame
			await physics_frame
			check(game.pursuit_route(Vector3(0,.1,-8),Vector3(0,.1,17)).is_empty(), "Sealed boss arena cannot be bypassed by endpoint recovery")
		for gate in game.mission.doors.gates:
			if not gate.closed:
				continue
			var body: StaticBody3D = gate.body
			var shape: CollisionShape3D = body.find_children("*","CollisionShape3D",false,false)[0]
			var normal := Vector3.RIGHT if shape.shape.size.x < shape.shape.size.z else Vector3.BACK
			var center: Vector3 = body.global_position
			check(not game.navigation_segment_clear(center-normal*.7,center+normal*.7), "Physical closed gate rejects endpoint shortcuts")
			var near: Vector3 = center-normal*.7
			for endpoint in game._navigation_endpoints(near):
				var point := Vector3(endpoint.x,near.y,endpoint.y)
				check((point-center).dot(normal) < 0, "A solid door-margin endpoint cannot jump to the other side")
		game.queue_free()
		await process_frame
		paused = false
	print("NAVIGATION COVER: %d failures" % failures)
	campaign.music.stream_paused = false
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(.3).timeout
	quit(1 if failures else 0)
