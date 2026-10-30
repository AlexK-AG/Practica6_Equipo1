extends SceneTree
const Search = preload("res://scripts/enemies/enemy_search.gd")
const Steering = preload("res://scripts/enemies/enemy_steering.gd")
var campaign: Node
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func freeze(game: Node) -> void:
	game.set_pause(false)
	game.player.set_physics_process(false)
	if not campaign.profile().has("checkpoint"):
		game.player.health = 100000
		game.player.max_health = 100000
		game.player.shield = 0
	game.mission.set_process(false)
	game.mission.doors.set_process(false)
	for node in game.get_node("HUD/Interface").get_children():
		if node.get_script() == preload("res://scripts/missions/objective_beacons.gd"):
			node.set_process(false)
	for actor in game.get_children():
		if actor is EnemyController:
			actor.set_physics_process(false)
func clear(game: Node) -> void:
	for actor in game.get_children():
		if actor is EnemyController:
			game.remove_child(actor)
			actor.free()
func actor(game: Node, kind: int, location: Vector3) -> EnemyController:
	var enemy: EnemyController = load("res://scenes/actors/enemy_%d.tscn" % kind).instantiate()
	enemy.name = "SearchKind%d" % kind
	enemy.position = location
	enemy.alerted = true
	game.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.tactics.has_memory = true
	enemy.tactics.last_seen = Vector3(25,.01,9.3)
	enemy.tactics.memory_left = 0
	return enemy
func make_game() -> Node:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	freeze(game)
	return game
func close_game(game: Node) -> void:
	game.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	paused = false
func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/enemy-search-private.cfg"
	campaign.profiles = {}
	assert(campaign.select_profile("Search regression"))
	var game = make_game()
	for kind in range(0 if "--checks-only" in OS.get_cmdline_user_args() else 18):
		clear(game)
		game.player.position = Vector3(24.5,.01,4.5)
		var enemy := actor(game,kind,Vector3(25,.01,9))
		await physics_frame
		await physics_frame
		check(not enemy.steering.clear_shot(enemy,game.player.position), "Fixture initially blocks vision kind%d" % kind)
		var regained := false
		var previous: Vector3 = enemy.position
		var biggest_step := 0.0
		for frame in range(600):
			enemy._physics_process(1.0/60)
			biggest_step = maxf(biggest_step,enemy.position.distance_to(previous))
			previous = enemy.position
			if enemy.steering.clear_shot(enemy,game.player.position):
				regained = true
				break
			await physics_frame
		print("SEARCH KIND ",kind," regained=",regained," pos=",enemy.position," phase=",enemy.search.phase," cursor=",enemy.search.cursor)
		check(regained, "Idle subtype must investigate nearby cover and regain sight kind%d" % kind)
		if kind != 17:
			check(biggest_step < .4,"Search must walk without teleporting kind%d" % kind)
		if kind == 0 and regained:
			var shots: int = enemy.tactics.shots
			for frame in range(120):
				enemy._physics_process(1.0/60)
				await physics_frame
			check(enemy.tactics.shots > shots, "Recovered explorer really fires instead of abandoning its new lane")
	clear(game)
	var subject := actor(game,0,Vector3(25,.01,9))
	await physics_frame
	# Two different hidden positions must produce the same initial search plan.
	game.player.position = Vector3(24.5,.01,4.5)
	var first = Search.new()
	var goal_a: Vector3 = first.investigate(subject,subject.tactics.last_seen,.01)
	game.player.position = Vector3(25.3,.01,4.5)
	await physics_frame
	subject.steering = Steering.new()
	subject.steering.setup(subject)
	var second = Search.new()
	var goal_b: Vector3 = second.investigate(subject,subject.tactics.last_seen,.01)
	check(goal_a == goal_b and first.points == second.points, "Search plan uses remembered position and geometry, not hidden player coordinates")
	# Active roles keep their job rather than being pulled into the shared search.
	var support := actor(game,4,Vector3(23,.01,9))
	await physics_frame
	for kind in [2,13]:
		subject.kind = kind
		check(not subject.search.eligible(subject), "Tank/shield keep escorting a visible support")
	for kind in [8,15]:
		subject.kind = kind
		check(not subject.search.eligible(subject), "Guardian/projector stay with their allied group")
	subject.kind = 4
	support.health = 1
	check(not subject.search.eligible(subject), "Healer prioritizes a wounded ally")
	subject.kind = 5
	subject.tactics.channel = "summon"
	check(not subject.search.eligible(subject), "Search never interrupts a channel")
	subject.tactics.channel = ""
	subject.kind = 9
	subject.tactics.charge_state = "charge"
	check(not subject.search.eligible(subject), "Search never redirects a committed charge")
	subject.tactics.charge_state = ""
	subject.kind = 12
	subject.tactics.memory_left = 3
	check(not subject.search.eligible(subject), "Suppression completes before search")
	subject.tactics.memory_left = 0
	subject.boss = true
	check(not subject.search.eligible(subject), "Boss remains controlled by its arena rules")
	clear(game)
	# Reaching a closed-off memory cannot reveal or bypass the final-room door.
	game.player.position = Vector3(0,.01,-20)
	subject = actor(game,0,Vector3(0,.01,-9))
	subject.tactics.last_seen = game.player.position
	await physics_frame
	for frame in range(180):
		subject._physics_process(1.0/60)
		check(subject.position.z > -12,"Investigation must not cross a locked extraction door")
		await physics_frame
	check(not subject.alerted,"An inaccessible exhausted search returns to guarding rather than staying in pursuit forever")
	# Restore actual checkpoint data during an active local search.
	clear(game)
	game.player.position = Vector3(25.3,.01,4.5)
	subject = actor(game,0,Vector3(23,.01,9))
	subject.tactics.last_seen = Vector3(23,.01,9.3)
	await physics_frame
	await physics_frame
	subject._physics_process(.02)
	check(subject.search.initialized and subject.search.phase == 1,"Checkpoint fixture is in active local search")
	# The larger budget remains active beyond the previous six-point/12s limit.
	var extended = Search.new()
	extended.initialized = true
	extended.anchor = subject.tactics.last_seen
	extended.phase = 1
	extended.elapsed = 13
	extended.cursor = 6
	extended.route_wait = 100
	extended.previous = subject.position+Vector3.RIGHT
	for index in range(10):
		extended.points.append(subject.position+Vector3.RIGHT*3)
	extended.investigate(subject,subject.tactics.last_seen,.01)
	check(extended.phase == 1,"Search continues beyond six probes and twelve seconds")
	extended.elapsed = 21
	extended.investigate(subject,subject.tactics.last_seen,0)
	check(extended.phase == 2,"Extended search still has a finite timeout")
	var saved: Dictionary = subject.search.capture_state()
	game.player.health = 63
	game.player.ammo = 3
	game.player.reserve = 8
	game.mission.checkpoint()
	await close_game(game)
	game = make_game()
	subject = game.get_node("SearchKind0")
	check(subject.search.phase == saved.phase and subject.search.anchor == saved.anchor and subject.search.points == saved.points, "Checkpoint preserves bounded search progress")
	check(game.player.health == 63 and game.player.ammo == 3 and game.player.reserve == 8,"Search restoration preserves player resources")
	for state in campaign.profile().checkpoint.enemies:
		state.erase("search")
	await close_game(game)
	game = make_game()
	subject = game.get_node("SearchKind0")
	check(not subject.search.initialized,"Older checkpoints receive default search state")
	await close_game(game)
	campaign.music.stream_paused = false
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(.3).timeout
	print("ENEMY SEARCH: %d failures" % failures)
	quit(1 if failures else 0)
