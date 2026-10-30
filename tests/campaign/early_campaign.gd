extends SceneTree
var failures := 0
var campaign: Node
const Driver = preload("res://tests/helpers/mission_driver.gd")

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func freeze(game: Node) -> void:
	game.set_pause(false)
	game.player.set_physics_process(false)
	game.mission.set_process(false)
	for enemy in game.get_children():
		if enemy is EnemyController:
			enemy.set_physics_process(false)

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	campaign = root.get_node("Campaign")
	campaign.profiles = {}
	campaign.select_profile("Early missions")
	campaign.profile().completed = range(10)
	for level in range(1, 4):
		campaign.profile().erase("checkpoint")
		var game = load(campaign.LEVELS[level - 1].path).instantiate()
		root.add_child(game)
		current_scene = game
		freeze(game)
		await physics_frame
		var mission = game.mission
		check(mission.objective_count == {1: 5, 2: 8, 3: 8}[level], "New chained mission length")
		check(not mission.interact_object(1), "Cannot skip stage")
		check(not mission.interact_object(0), "Cannot bypass required defenders")
		Driver.clear_enemies(game)
		check(mission.interact_object(0), "Secured stage advances")
		if level == 2:
			check(mission.early.cargo and is_equal_approx(game.player.cargo_factor, .8), "Cargo penalizes movement")
		# Serialize to disk, reload and ensure no repeated guards or stat scaling.
		var count: int = mission.living_enemies()
		mission.checkpoint()
		game.queue_free()
		await process_frame
		campaign.profiles.clear()
		campaign.load_data()
		campaign.select_profile("Early missions")
		game = load(campaign.LEVELS[level - 1].path).instantiate()
		root.add_child(game)
		current_scene = game
		freeze(game)
		await physics_frame
		mission = game.mission
		check(mission.early.stage == 1 and mission.done.has(0), "Stage restored from disk")
		check(mission.living_enemies() == count, "Checkpoint does not duplicate defenders")
		if level == 2:
			check(mission.early.cargo and game.player.cargo_factor == .8, "Cargo restored")
		Driver.complete(game)
		check(game.finished, "Expanded sector completable")
		if level == 3:
			check(mission.early.gate.visible and mission.timer > 0, "Purge closes emergency shutter")
			check(game.route(Vector3(17, .1, 8), Vector3(25, .1, -17)).size() > 1, "West evacuation detour remains reachable")
		await game.result_presented
		paused = false
		game.queue_free()
		await process_frame
	# Enemy statistics, shield facing and support mitigation in a real world.
	campaign.profile().pending = -1
	campaign.profile().erase("checkpoint")
	var game = load(campaign.LEVELS[3].path).instantiate()
	root.add_child(game)
	freeze(game)
	var damages: Array[int] = []
	var speeds: Array[float] = []
	var intervals: Array[float] = []
	for difficulty in range(3):
		campaign.options.difficulty = difficulty
		var enemy = load("res://scenes/actors/enemy_14.tscn").instantiate()
		game.add_child(enemy)
		enemy.set_physics_process(false)
		damages.append(enemy.attack_damage)
		speeds.append(enemy.move_speed)
		intervals.append(enemy.attack_interval)
		enemy.queue_free()
		await process_frame
	check(damages[0] < damages[1] and damages[1] < damages[2], "Damage scales with difficulty")
	check(speeds[0] < speeds[1] and speeds[1] < speeds[2], "Movement scales with difficulty")
	check(intervals[0] > intervals[1] and intervals[1] > intervals[2], "Attack frequency scales with difficulty")
	Driver.clear_enemies(game)
	campaign.options.difficulty = 1
	var shield = load("res://scenes/actors/enemy_13.tscn").instantiate()
	shield.position = Vector3.ZERO
	game.add_child(shield)
	shield.set_physics_process(false)
	game.player.position = Vector3(0, 0, 4)
	var hp: int = shield.health
	shield.take_damage(30)
	check(shield.health == hp and shield.shield_health == 40, "Frontal shield absorbs damage")
	game.player.position.z = -4
	shield.take_damage(30)
	check(shield.health == hp - 30 and shield.shield_health == 40, "Flanking bypasses shield")
	var support = load("res://scenes/actors/enemy_15.tscn").instantiate()
	support.position = Vector3(2, 0, 0)
	game.add_child(support)
	support.set_physics_process(false)
	await physics_frame
	shield.take_damage(20)
	check(shield.health == hp - 43, "Bastion reduces ally damage")
	game.queue_free()
	await process_frame
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(0.2).timeout
	print("EARLY CAMPAIGN TESTS: ", "PASS" if failures == 0 else "FAIL", " / failures=", failures)
	quit(failures)
