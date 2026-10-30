extends SceneTree
var failures := 0
var campaign: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func freeze(game: Node) -> void:
	game.set_pause(false)
	game.player.set_physics_process(false)
	game.mission.set_process(false)
	for enemy in game.get_children():
		if enemy is EnemyController:
			enemy.set_physics_process(false)

func close_game(game: Node) -> void:
	paused = false
	game.queue_free()
	await process_frame

func make_game(level: int) -> Node:
	campaign.profile().erase("checkpoint")
	campaign.profile().pending = -1
	var game = load(campaign.LEVELS[level - 1].path).instantiate()
	root.add_child(game)
	current_scene = game
	return game

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	campaign = root.get_node("Campaign")
	campaign.profiles = {}
	campaign.select_profile("Station regression")
	campaign.profile().weapon_unlocks = ["rifle"]
	campaign.profile().starting_rifle = true
	check(campaign.available_weapons(9) == ["pistol", "rifle"], "Reaching a level no longer grants a gun")
	campaign.profile().completed = range(10)
	var common_energy := -1.0
	var common_color := Color.BLACK
	for level in range(1, 11):
		var game = make_game(level)
		freeze(game)
		await physics_frame
		check(game.get_node("Arena/Ceilings").get_child_count() > 0, "Physical ceiling exists in sector %d" % level)
		var origin: Vector3 = game.player.position + Vector3.UP * 1.6
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + Vector3.UP * 15, 1, [game.player.get_rid()]))
		check(not hit.is_empty(), "Ceiling has collision above spawn in sector %d" % level)
		check(not game.find_child("Controls", true, false).visible, "Bottom controls removed")
		if level == 1:
			check(game.player.reserve == 24 and game.player.inventory.rifle.reserve == 48, "Reduced starting reserves")
			for n in range(20):
				game.player.resupply()
			check(game.player.reserve == 48 and game.player.inventory.rifle.reserve == 96, "Reduced reserve caps remain enforced")
		var panel: Control = game.get_node("HUD/Interface/MissionPanel")
		check(panel.anchor_right == 1.0 and panel.offset_left == -350, "Mission is anchored at top right")
		for item in game.mission.objects:
			check(preload("res://tests/helpers/navigation_checks.gd").route(game,item.position, game.player.position).size() > 1, "Reachable objective/supply/weapon in sector %d: %s" % [level, item.title])
		if level in [1, 2, 8, 9]:
			var env: Environment = game.get_node("World").environment
			if level == 1:
				common_energy = env.ambient_light_energy
				common_color = env.ambient_light_color
			check(env.ambient_light_energy < 0.65, "Subdued lighting retained")
			if level != 1:
				check(env.ambient_light_color != common_color, "Distinct requested sector palette")
		if level in [3, 6]:
			var env: Environment = game.get_node("World").environment
			check(is_equal_approx(env.ambient_light_energy, 0.65 if level == 3 else 0.8), "Reactor/fortress original light energy retained")
		if level == 2:
			seed(8)
			var positions: Array[Vector3] = []
			for n in range(12):
				check(game.mission.spawn_enemy(n % 6), "Random reinforcements can spawn")
				var position: Vector3 = game.mission.previous_spawn
				check(position.distance_to(game.player.position) >= 12, "Spawn avoids player")
				positions.append(position)
			for child in game.get_children():
				if child is EnemyController:
					child.set_physics_process(false)
			check(positions[0] != positions[1] and positions[0] != positions[2], "Spawn does not always choose the farthest portal")
		await close_game(game)
	check(FileAccess.get_file_as_string("res://scenes/levels/level_8.tscn") != FileAccess.get_file_as_string("res://scenes/levels/level_2.tscn"), "Hangar has its own geometry")
	# New profiles must collect a physical weapon, keep it in checkpoints and clear
	# the sector before it appears in the next mission's equipment selector.
	campaign.reset_campaign()
	for level in [3, 6, 9]:
		campaign.profile().completed = range(level - 1)
		var game = make_game(level)
		freeze(game)
		check(not game.has_node("LoadoutScreen"), "No premature equipment popup in discovery mission")
		var weapon_id: String = {3: "shotgun", 6: "precision", 9: "plasma"}[level]
		check(not game.player.set_loadout(["pistol", weapon_id]), "Uncollected weapon cannot be equipped")
		var pickup: Node
		for item in game.mission.objects:
			if item.weapon_id == weapon_id:
				pickup = item
		check(pickup != null, "Physical weapon pickup exists")
		var ray_start: Vector3 = pickup.position + Vector3(0, 1.6, 2.5)
		await physics_frame
		var aim: Vector3 = pickup.position + Vector3(0, 1.35, 0)
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ray_start, aim, 1, [game.player.get_rid()]))
		check(not hit.is_empty() and hit.collider == pickup, "Aiming at visible gun hits its interaction collider")
		pickup.interact()
		check(game.player.weapon_id == weapon_id and game.mission.found_weapons.has(weapon_id), "Found weapon is immediately usable")
		check(not campaign.available_weapons(level).has(weapon_id), "Permanent equipment waits for sector completion")
		game.player.ammo -= 1
		game.mission.checkpoint()
		var rounds: int = game.player.ammo
		await close_game(game)
		campaign.profiles.clear()
		campaign.load_data()
		campaign.select_profile("Station regression")
		game = load(campaign.LEVELS[level - 1].path).instantiate()
		root.add_child(game)
		current_scene = game
		freeze(game)
		check(game.player.ammo == rounds and game.player.weapon_id == weapon_id and game.run_weapons.has(weapon_id), "Checkpoint restores found gun without new ammunition")
		preload("res://tests/helpers/mission_driver.gd").complete(game)
		await game.result_presented
		check(campaign.available_weapons(level + 1).has(weapon_id), "Cleared mission permanently unlocks collected weapon")
		game.get_node("UpgradeScreen").choose(campaign.offers_for_stage(campaign.pending())[0])
		await close_game(game)
		game = make_game(level + 1)
		check(game.has_node("LoadoutScreen") and paused, "Equipment selector appears after discovery mission")
		var screen = game.get_node("LoadoutScreen")
		screen.second.select(screen.choices.find(weapon_id))
		screen.accept()
		check(game.player.loadout.has(weapon_id), "New gun can be selected in following mission")
		await close_game(game)
	await tutorial_checks()
	print("STATION REVISION TESTS: ", "PASS" if failures == 0 else "FAIL", " / failures=", failures)
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(0.3).timeout
	quit(failures)

func tutorial_checks() -> void:
	campaign.profile().pending = -1
	campaign.profile().checkpoint = {"level": 2, "sentinel": true}
	var completed: Array = campaign.profile().completed.duplicate()
	var score: int = campaign.total_score()
	var game = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	freeze(game)
	check(not game.mission.tutorial_interact(3), "Tutorial exit waits for practice")
	preload("res://tests/helpers/tutorial_driver.gd").complete(game)
	check(game.mission.tutorial_reloaded and game.mission.tutorial_grenade and game.mission.tutorial_switched, "Tutorial observes its independent practice steps")
	await game.result_presented
	check(campaign.profile().completed == completed and campaign.total_score() == score and campaign.profile().checkpoint.get("sentinel", false), "Optional tutorial leaves campaign rewards and checkpoint untouched")
	await close_game(game)
