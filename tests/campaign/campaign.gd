extends SceneTree

var failures := 0
var campaign: Node

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	campaign = root.get_node("Campaign")
	assert("--campaign-test" in OS.get_cmdline_user_args())
	if "--reload-only" in OS.get_cmdline_user_args():
		check(campaign.select_profile("Persistence"), "Load named profile in another process")
		check(campaign.unlocked(1) and not campaign.unlocked(2), "Unlocks survive process restart")
		check(campaign.pending() == 0, "Unchosen reward survives process restart")
		check(campaign.total_score() == 1234, "Score survives process restart")
		finish()
		return
	campaign.profiles = {}
	campaign.active_id = ""
	check(not campaign.select_profile("   "), "Reject empty name")
	check(campaign.select_profile("Ana"), "Create player")
	check(campaign.unlocked(0) and not campaign.unlocked(1), "Only first mission unlocked")
	check(not campaign.complete_level(5, 500), "Cannot reward a locked mission")
	var start = load("res://scenes/start.tscn").instantiate()
	root.add_child(start)
	current_scene = start
	start.show_levels()
	check(start.get_node("Margin/Stack/LevelsPage/Scroll/Grid/Level1/Content/Launch").disabled, "Locked button")
	start.open_level(5)
	check(current_scene == start, "Script also rejects locked level")
	start.open_level(0)
	await scene_changed
	for index in range(10):
		var game = current_scene
		await physics_frame
		await create_timer(0.08, true).timeout
		if game.has_node("LoadoutScreen"):
			game.get_node("LoadoutScreen").accept()
		game.set_pause(false)
		check(game.level_number == index + 1, "Correct campaign order")
		check(game.get_node("HUD/Interface") != null, "Saved reusable HUD")
		check(campaign.music.playing, "Background audio playing")
		var enemies: Array = []
		for child in game.get_children():
			if child.get_script() == load("res://scripts/enemies/enemy.gd"):
				enemies.append(child)
				check(preload("res://tests/helpers/navigation_checks.gd").route(game,child.position, game.player.position).size() > 1, "Reachable enemy in level %d: %s" % [index + 1, child.name])
				check(child.process_mode == Node.PROCESS_MODE_PAUSABLE, "Enemy pausable")
				child.set_physics_process(false)
		check(enemies.size() == game.enemy_count and enemies.size() >= 6, "Enemy count")
		game.player.set_physics_process(false)
		for enemy in enemies:
			enemy.take_damage(10000)
		preload("res://tests/helpers/mission_driver.gd").complete(game)
		await game.result_presented
		check(game.finished and paused, "Victory pauses")
		check(campaign.profile().completed.has(index), "Victory saved before choosing upgrade")
		check(campaign.unlocked(mini(9, index + 1)), "Next mission unlocked")
		check(not campaign.save_error.length(), "No persistence error")
		if index < 9:
			check(campaign.pending() == index, "Pending reward")
			var id: String = campaign.offers_for_stage(index)[0]
			game.get_node("UpgradeScreen").choose(id)
			check(campaign.pending() == -1, "Reward claimed")
			check(not campaign.choose_upgrade(id), "Cannot claim twice")
			game.advance()
			await scene_changed
		else:
			check(campaign.pending() == -1 and not game.next_button.visible, "Final completion")
			game.go_home()
			await scene_changed
	check(campaign.rank_of("health") == 3 and campaign.rank_of("damage") == 3, "Ranks accumulate across campaign")
	var previous: int = campaign.total_score()
	check(campaign.complete_level(0, 1), "Replay completed level")
	check(campaign.total_score() == previous and campaign.pending() == -1, "Replay cannot farm points or rewards")
	campaign.select_profile("Bruno")
	check(campaign.total_score() == 0 and not campaign.unlocked(1), "Profiles isolated")
	campaign.select_profile("ANA")
	check(campaign.total_score() == previous, "Case-insensitive profile lookup")
	campaign.reset_campaign()
	check(campaign.total_score() == 0 and campaign.rank_of("health") == 0 and not campaign.unlocked(1), "Reset only active campaign")
	check(campaign.profile().record == previous and campaign.profiles.has("bruno"), "Record and other player survive reset")
	# Exercise defensive upgrades and weapon balance in a real player instance.
	campaign.profile().weapon_unlocks = ["rifle"]
	campaign.profile().choices = {"0": "shield", "1": "rifle", "2": "armor", "3": "reload", "4": "regen", "5": "melee"}
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.08, true).timeout
	game.set_pause(false)
	var player = game.player
	player.equip("rifle")
	check(player.weapon_damage == 20 and player.ammo_capacity == 24 and is_equal_approx(player.fire_interval, 0.15), "Balanced rifle")
	player.take_damage(20)
	check(player.health == 100 and player.shield < 25 and player.shield > 0, "Shield absorbs reduced damage")
	var remaining: float = player.shield
	player.regenerate(3.0)
	check(is_equal_approx(player.shield, remaining), "Shield regeneration delay")
	player.regenerate(2.0)
	check(player.shield > remaining, "Shield regeneration resumes")
	game.set_pause(true)
	remaining = player.shield
	player.regenerate(20)
	check(is_equal_approx(player.shield, remaining), "Pause freezes shield")
	paused = false
	root.remove_child(game)
	game.free()
	campaign.select_profile("Persistence")
	campaign.reset_campaign()
	campaign.complete_level(0, 1234)
	check(campaign.pending() == 0, "Fixture saved for next-process check")
	finish()

func finish() -> void:
	print("CAMPAIGN TESTS: ", "PASS" if failures == 0 else "FAIL", " / failures=", failures)
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
	root.get_node("Campaign").music.stream_paused = false
	root.get_node("Campaign").music.stop()
	root.get_node("Campaign").music.stream = null
	await create_timer(0.3).timeout
	quit(failures)
