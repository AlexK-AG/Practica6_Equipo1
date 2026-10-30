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
	campaign.select_profile("Final shot")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_pause(false)
	var target: Node3D = game.get_node("Enemy0")
	for child in game.get_children():
		if child.get_script() == load("res://scripts/enemies/enemy.gd"):
			child.set_physics_process(false)
			if child != target:
				child.take_damage(10000)
	target.position = Vector3(0, 0.1, 25)
	target.health = 25
	game.player.camera.look_at(target.position + Vector3(0, 0.7, 0))
	await physics_frame
	await physics_frame
	var before_ammo: int = game.player.ammo
	game.player.shoot()
	check(not game.finished and game.kills == game.enemy_count, "Final shot clears threats but objectives remain")
	preload("res://tests/helpers/mission_driver.gd").complete(game)
	check(not paused and not game.get_node("UpgradeScreen").visible and not game.menu.visible, "No immediate pause or upgrade overlay")
	check(game.player.get_node("Shot").playing and game.player.flash.visible, "Final sound and flash start")
	check(game.hit_time > 0, "Final hit marker starts")
	check(campaign.profile().completed.has(0), "Progress saved before presentation delay")
	var health: int = game.player.health
	game.player.shoot()
	game.player.take_damage(100)
	check(game.player.ammo == before_ammo - 1 and game.player.health == health, "Combat stops while feedback finishes")
	await create_timer(0.1).timeout
	check(not paused and not game.get_node("UpgradeScreen").visible, "Feedback remains visible before result")
	await game.result_presented
	check(paused and game.get_node("UpgradeScreen").visible, "Upgrade appears after feedback")
	check(not game.player.get_node("Shot").playing, "Final sound finishes before pause")
	check(not game.player.flash.visible and is_zero_approx(game.player.recoil), "Flash and recoil finish")
	print("FINAL SHOT TESTS: ", "PASS" if failures == 0 else "FAIL", " / failures=", failures)
	paused = false
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(0.3, true).timeout
	quit(failures)

