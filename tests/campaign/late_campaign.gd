extends SceneTree
const Driver = preload("res://tests/helpers/mission_driver.gd")
var failures := 0
var campaign: Node
var encountered: Array[int] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func freeze(game: Node) -> void:
	game.set_pause(false)
	if game.has_node("LoadoutScreen"):
		game.get_node("LoadoutScreen").accept()
	game.player.set_physics_process(false)
	game.mission.set_process(false)
	for enemy in game.get_children():
		if enemy is EnemyController:
			enemy.set_physics_process(false)
			if not encountered.has(enemy.kind):
				encountered.append(enemy.kind)

func make_game(level: int) -> Node:
	campaign.profile().pending = -1
	var game = load(campaign.LEVELS[level - 1].path).instantiate()
	root.add_child(game)
	current_scene = game
	freeze(game)
	return game

func release(game: Node) -> void:
	paused = false
	game.queue_free()
	await process_frame

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	campaign = root.get_node("Campaign")
	campaign.profiles = {}
	campaign.select_profile("Late campaign")
	campaign.profile().completed = range(10)
	for level in range(1,11):
		campaign.profile().erase("checkpoint")
		var game = make_game(level)
		await physics_frame
		check(game.mission.early != null, "Every sector has a stage controller")
		check(game.mission.objective_count >= 5, "Expanded objective count")
		for item in game.mission.objects:
			check(preload("res://tests/helpers/navigation_checks.gd").route(game,game.player.position,item.position).size() > 1, "Objective reachable in sector%d: %s" % [level,item.title])
		if level in [4,5,7,10]:
			check(game.room_layout and game.map_scale == 1, "Legacy arena replaced with authored room layout")
			check(game.get_node("Arena/Ceilings").get_child_count() >= 10, "New room ceilings")
			check(is_equal_approx(game.get_node("World").environment.ambient_light_energy,.8), "Original ambient energy preserved")
		if level >= 4:
			check(not game.mission.interact_object(1), "Stage cannot be skipped")
			check(not game.mission.interact_object(0), "Mandatory defenders block interaction")
			Driver.clear_enemies(game)
			check(game.mission.interact_object(0), "Secured first stage advances")
			freeze(game)
			game.mission.checkpoint()
			var count: int = game.mission.living_enemies()
			var counters: Dictionary = {}
			for enemy in game.get_children():
				if enemy is EnemyController and enemy.health > 0:
					counters[str(enemy.name)] = [enemy.attack_damage,enemy.move_speed,enemy.attack_interval]
			await release(game)
			campaign.profiles.clear()
			campaign.load_data()
			campaign.select_profile("Late campaign")
			game = make_game(level)
			check(game.mission.early.stage == 1 and game.mission.living_enemies() == count, "Late checkpoint restores stages without duplicate encounters")
			for enemy in game.get_children():
				if enemy is EnemyController and counters.has(str(enemy.name)):
					var stats: Array = counters[str(enemy.name)]
					check(enemy.attack_damage == stats[0] and is_equal_approx(enemy.move_speed,stats[1]) and is_equal_approx(enemy.attack_interval,stats[2]), "Checkpoint does not multiply difficulty or level twice")
			if level == 10:
				for id in [1,2,3]:
					Driver.clear_enemies(game)
					check(game.mission.interact_object(id), "Final mission advances through preparation and energy phases")
					if id in [2,3]:
						game.get_node("FinalBoss").take_damage(100000)
						game.mission.early.update_effects()
				var boss = game.get_node("FinalBoss")
				check(game.mission.boss_phase == 2 and boss.invulnerable and boss.boss_enraged, "Final phase has an enraged shielded boss")
				var interval: float = boss.attack_interval
				game.mission.checkpoint()
				await release(game)
				game = make_game(level)
				boss = game.get_node("FinalBoss")
				check(boss.boss_enraged and is_equal_approx(boss.attack_interval,interval), "Enrage is restored without repeated acceleration")
			Driver.complete(game)
			check(game.finished, "Late mission completes")
			await game.result_presented
		await release(game)
	check(encountered.size() == 18, "All eighteen subtype scenes occur in real campaign instances")
	# Discoveries persist independently from campaign checkpoints and profiles.
	campaign.select_profile("Index A")
	check(campaign.profile().discovered_enemies.is_empty(), "New pilot starts without discoveries")
	check(campaign.discover_enemy(13), "First observation is recorded")
	check(not campaign.discover_enemy(13), "Discovery is idempotent")
	campaign.profiles.clear()
	campaign.load_data()
	campaign.select_profile("Index A")
	check(campaign.profile().discovered_enemies == [13], "Discovery survives disk reload")
	campaign.select_profile("Index B")
	check(campaign.profile().discovered_enemies.is_empty(), "Discovery belongs to each pilot")
	campaign.select_profile("Late campaign")
	campaign.profile().erase("checkpoint")
	var game = make_game(4)
	Driver.clear_enemies(game)
	# Holding subtype constant, a later sector increases pressure; difficulty
	# has independent monotonic effects and is bounded below sprint speed.
	var results: Array = []
	for pair in [[1,1],[10,1],[10,2]]:
		game.level_number = pair[0]
		campaign.options.difficulty = pair[1]
		var enemy = load("res://scenes/actors/enemy_14.tscn").instantiate()
		game.add_child(enemy)
		enemy.set_physics_process(false)
		results.append([enemy.attack_damage,enemy.move_speed,enemy.attack_interval])
		enemy.queue_free()
		await process_frame
	check(results[0][0] < results[1][0] and results[1][0] < results[2][0], "Damage scales by sector and difficulty")
	check(results[0][1] < results[1][1] and results[1][1] <= results[2][1] and results[2][1] <= 4.6, "Movement scales with a readable speed cap")
	check(results[0][2] > results[1][2] and results[1][2] > results[2][2], "Attack frequency scales by sector and difficulty")
	campaign.options.difficulty = 1
	await release(game)
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(.2).timeout
	print("LATE CAMPAIGN TESTS: ","PASS" if failures == 0 else "FAIL"," / failures=",failures)
	quit(failures)
