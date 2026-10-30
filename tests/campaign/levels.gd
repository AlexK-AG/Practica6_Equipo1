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
	campaign.options.difficulty = 1
	campaign.profiles = {}
	campaign.select_profile("Level checks")
	campaign.profile().completed = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	var last_hp := 0
	for index in range(10):
		var game = load(campaign.LEVELS[index].path).instantiate()
		root.add_child(game)
		game.set_pause(true)
		await create_timer(0.06, true).timeout
		var total_hp := 0
		for child in game.get_children():
			if child.get_script() == load("res://scripts/enemies/enemy.gd"):
				total_hp += child.max_health
				check(preload("res://tests/helpers/navigation_checks.gd").route(game,child.position, game.player.position).size() > 1, "Level %d: reachable %s" % [index + 1, child.name])
				check(child.get_node("Shot").stream != null, "Enemy audio assigned")
		check(total_hp > 0, "Mission has combat encounters")
		last_hp = total_hp
		check(load("res://assets/previews/levels/level_%d.png" % (index + 1)) != null, "Actual level preview")
		check(campaign.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Music loops")
		if index == 9:
			check(game.get_node("FinalBoss").boss and game.get_node("FinalBoss").max_health == 900, "Final guardian")
		root.remove_child(game)
		game.free()
		campaign.music.stop()
		await create_timer(0.06, true).timeout
		paused = false
	print("LEVEL TESTS: ", "PASS" if failures == 0 else "FAIL", " / failures=", failures)
	root.get_node("Campaign").music.stop()
	root.get_node("Campaign").music.stream = null
	await create_timer(0.15).timeout
	quit(failures)
