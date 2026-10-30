extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	var campaign = root.get_node("Campaign")
	campaign.profiles = {}
	campaign.select_profile("Expansion")
	campaign.profile().weapon_unlocks = ["rifle", "shotgun", "precision", "plasma"]
	campaign.profile().completed = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	for level in range(10):
		campaign.profile().erase("checkpoint")
		var game = load(campaign.LEVELS[level].path).instantiate()
		root.add_child(game)
		current_scene = game
		await physics_frame
		if game.has_node("LoadoutScreen"):
			game.get_node("LoadoutScreen").accept()
		game.set_pause(false)
		game.mission.set_process(false)
		game.player.set_physics_process(false)
		for enemy in game.get_children():
			if enemy is EnemyController:
				enemy.set_physics_process(false)
		check(game.navigation_extent >= 23, "Expanded map")
		check(not game.mission.interact_object(game.mission.objective_count - 1), "Exit rejects unfinished objectives")
		for object in game.mission.objects:
			check(preload("res://tests/helpers/navigation_checks.gd").route(game,object.position, game.player.position).size() > 1, "Objective and supply reachable: " + object.title)
		if level == 0:
			await weapons(game)
			preload("res://tests/helpers/mission_driver.gd").clear_enemies(game)
			game.mission.interact_object(0)
			var expected: Dictionary = game.player.capture_state()
			game.mission.checkpoint()
			game.queue_free()
			await process_frame
			campaign.profiles.clear()
			campaign.load_data()
			campaign.select_profile("Expansion")
			game = load(campaign.LEVELS[0].path).instantiate()
			root.add_child(game)
			current_scene = game
			game.set_pause(false)
			game.mission.set_process(false)
			game.player.set_physics_process(false)
			check(game.mission.done.has(0) and not game.mission.objects[0].active, "Checkpoint restores objective state")
			check(game.player.ammo == int(expected.inventory[expected.weapon].ammo) and game.player.reserve == int(expected.inventory[expected.weapon].reserve), "Checkpoint preserves finite ammunition")
			check(game.player.position.is_equal_approx(expected.position), "Checkpoint restores position")
		if level == 9:
			var boss = game.get_node("FinalBoss")
			var hp: int = boss.health
			boss.take_damage(1000)
			check(boss.health == hp, "Boss initially shielded")
			check(not game.mission.interact_object(4), "Cannot pre-disable phase three")
		var wave_sizes: Array[int] = preload("res://tests/helpers/mission_driver.gd").complete(game)
		check(game.finished, "Distinct mission can complete: %d" % (level + 1))
		if level == 1:
			check(game.mission.wave == 2 and wave_sizes == [3, 3], "Two actual waves contain three enemies each")
		await game.result_presented
		check(campaign.profile().get("checkpoint", {}).is_empty(), "Victory clears checkpoint")
		paused = false
		game.queue_free()
		await process_frame
	print("EXPANSION TESTS: ", "PASS" if failures == 0 else "FAIL", " / failures=", failures)
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(0.3, true).timeout
	quit(failures)

func weapons(game: Node) -> void:
	var player = game.player
	player.ammo = 3
	player.reserve = 2
	player.switch_time = 0
	player.start_reload()
	player._physics_process(2)
	check(player.ammo == 5 and player.reserve == 0, "Reload consumes only available reserves")
	player.start_reload()
	check(player.reload_time <= 0, "No reload without reserve")
	player.equip("rifle")
	player.switch_time = 0
	player.ammo = 10
	player.reserve = 20
	player.start_reload()
	player.equip("pistol")
	player.equip("rifle")
	check(player.ammo == 10 and player.reserve == 20 and player.reload_time == 0, "Switch cancels reload and preserves both counters")
	player.set_loadout(["pistol", "shotgun"])
	player.equip("shotgun")
	check(player.weapon_id == "shotgun" and player.loadout.size() == 2, "Loadout equips unlocked shotgun")
	player.switch_time = 0
	player.ammo = 0
	player.reserve = 0
	player.cooldown = 0
	player.shoot()
	check(player.ammo == 0 and player.reload_time == 0, "Empty weapon cannot fabricate rounds")
	player.melee_attack()
	check(player.melee_wait > 0 and player.melee_enabled, "Knife always available without ammunition")
	var grenades: int = player.grenades
	player.throw_grenade()
	player.throw_grenade()
	check(player.grenades == grenades - 1, "Grenade cooldown prevents duplicate throws")
	game.set_pause(true)
	var wait: float = player.melee_wait
	player.melee_attack()
	check(player.melee_wait == wait, "Pause blocks knife")
	game.set_pause(false)
