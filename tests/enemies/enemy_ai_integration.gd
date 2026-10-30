extends SceneTree
var failures := 0
var campaign: Node

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
	for node in game.find_children("*", "Node", true, false):
		if node.get_script() == preload("res://scripts/missions/objective_beacons.gd"):
			node.set_process(false)
	for actor in game.get_children():
		if actor is EnemyController:
			actor.set_physics_process(false)

func make_game() -> Node:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	freeze(game)
	return game

func remove_enemies(game: Node) -> void:
	for actor in game.get_children():
		if actor is EnemyController:
			game.remove_child(actor)
			actor.free()

func actor(game: Node, kind: int, point: Vector3, label: String) -> EnemyController:
	var enemy: EnemyController = load("res://scenes/actors/enemy_%d.tscn" % kind).instantiate()
	enemy.name = label
	enemy.position = point
	game.add_child(enemy)
	enemy.alerted = true
	enemy.set_physics_process(false)
	return enemy

func settle() -> void:
	await physics_frame
	await physics_frame

func close_game(game: Node) -> void:
	game.queue_free()
	await process_frame
	paused = false

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/enemy-ai-integration-private.cfg"
	campaign.profiles = {}
	campaign.select_profile("Enemy AI integration")
	campaign.profile().completed = range(10)
	campaign.profile().pending = -1
	campaign.profile().erase("checkpoint")
	var game = make_game()
	remove_enemies(game)
	game.player.position = Vector3(-7,.01,7.35)
	var scout := actor(game,0,Vector3(-7,.01,2),"CoverScout")
	await settle()
	check(not scout.steering.clear_shot(scout,game.player.position), "Cover fixture initially hides the player")
	var previous := scout.position
	var greatest_step := 0.0
	var saw_player := false
	for tick in range(300):
		scout._physics_process(1.0/60)
		greatest_step = maxf(greatest_step,scout.position.distance_to(previous))
		previous = scout.position
		if scout.steering.clear_shot(scout,game.player.position):
			saw_player = true
			break
		await physics_frame
	print("Cover pursuit position=",scout.position," LOS=",saw_player," max step=",greatest_step)
	check(saw_player and scout.position.distance_to(Vector3(-7,.01,2)) > 1, "Real scout controller rounds Cover199 and restores sight")
	check(greatest_step < .35, "Cover recovery walks physically without teleporting")
	remove_enemies(game)
	game.player.position = Vector3(0,.01,30)
	var tank := actor(game,2,Vector3(0,.01,24),"LaneTank")
	var runner := actor(game,3,Vector3(0,.01,20),"LaneRunner")
	await settle()
	var max_lateral := 0.0
	var min_separation := INF
	for tick in range(600):
		runner._physics_process(1.0/60)
		max_lateral = maxf(max_lateral,absf(runner.position.x))
		min_separation = minf(min_separation,runner.position.distance_to(tank.position))
		if runner.position.z > 26:
			break
		await physics_frame
	print("Overtake position=",runner.position," lateral=",max_lateral," min separation=",min_separation)
	check(runner.position.z > 25 and max_lateral > .9, "Real kamikaze overtakes a stationary tank laterally")
	check(min_separation > .85, "Overtaking respects tank collision")
	remove_enemies(game)
	var blocker := actor(game,2,Vector3(0,.01,23),"ShotBlocker")
	var sniper := actor(game,1,Vector3(0,.01,16),"LaneSniper")
	await settle()
	check(not sniper.steering.clear_shot(sniper,game.player.position), "Ally initially blocks real sniper muzzle")
	var vitality: float = game.player.health + game.player.shield
	sniper.fire_at_player()
	check(is_equal_approx(vitality,game.player.health+game.player.shield), "Blocked sniper causes no player damage")
	var regained := false
	for tick in range(300):
		sniper._physics_process(1.0/60)
		if sniper.steering.clear_shot(sniper,game.player.position):
			regained = true
			break
		await physics_frame
	print("Sniper position=",sniper.position," regained=",regained)
	check(regained and absf(sniper.position.x) > .4, "Real sniper controller finds a lateral firing angle past its ally")
	if regained:
		sniper.fire_at_player()
		check(game.player.health+game.player.shield < vitality, "Repositioned sniper can damage the player through its clear lane")
	# Checkpoint through the public mission path, then repeat with legacy state.
	remove_enemies(game)
	var saved_enemy := actor(game,0,Vector3(0,.01,20),"SavedScout")
	saved_enemy.health = 37
	saved_enemy.tactics.clock = 42.0
	game.player.health = 63
	game.player.ammo = 3
	game.player.reserve = 8
	game.mission.checkpoint()
	await close_game(game)
	game = make_game()
	check(game.has_node("SavedScout") and is_equal_approx(game.get_node("SavedScout").tactics.clock,42.0), "Checkpoint restores new tactical state")
	check(game.player.health == 63 and game.player.ammo == 3 and game.player.reserve == 8 and game.get_node("SavedScout").health == 37, "Checkpoint preserves player ammunition and both health values")
	for state in campaign.profile().checkpoint.enemies:
		state.erase("tactics")
	await close_game(game)
	game = make_game()
	check(game.get_node("SavedScout").tactics.clock == 0.0, "Legacy checkpoint receives safe default tactics")
	check(game.player.health == 63 and game.player.ammo == 3 and game.player.reserve == 8 and game.get_node("SavedScout").health == 37, "Legacy checkpoint preserves health and ammunition")
	# Alerted enemies still cannot pursue across the locked extraction doorway.
	remove_enemies(game)
	game.player.position = Vector3(0,.01,-20)
	var locked_scout := actor(game,0,Vector3(0,.01,-7),"LockedScout")
	await settle()
	var original_z := locked_scout.position.z
	for tick in range(120):
		locked_scout._physics_process(1.0/60)
		await physics_frame
	check(locked_scout.position.z > -12 and locked_scout.position.z >= original_z-5, "Real pursuit cannot cross the locked extraction room")
	await close_game(game)
	campaign.music.stream_paused = false
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(.3).timeout
	print("ENEMY AI INTEGRATION: %d failures" % failures)
	quit(1 if failures else 0)
