extends SceneTree
## Real close-range shot, healing feedback and temporary slow, isolated saves.
func _initialize() -> void:
	preload("res://tests/helpers/test_paths.gd").prepare()
	call_deferred("run")

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	var campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/test-results/logs/enemy-feedback-profile.cfg"
	campaign.profiles = {}
	campaign.options.difficulty = 1
	campaign.select_profile("Enemy feedback")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_pause(false)
	game.player.set_physics_process(false)
	game.mission.set_process(false)
	for actor in game.get_children():
		if actor is EnemyController:
			actor.queue_free()
	await process_frame
	game.player.position = Vector3(0,.1,30)
	var medic = load("res://scenes/actors/enemy_4.tscn").instantiate()
	medic.position = Vector3(-4,.1,25)
	game.add_child(medic)
	medic.set_physics_process(false)
	medic.alerted = true
	var tank = load("res://scenes/actors/enemy_2.tscn").instantiate()
	tank.position = Vector3(-2,.1,25)
	game.add_child(tank)
	tank.set_physics_process(false)
	tank.health = 40
	var sniper = load("res://scenes/actors/enemy_1.tscn").instantiate()
	sniper.position = Vector3(0,.1,25)
	game.add_child(sniper)
	sniper.set_physics_process(false)
	await physics_frame
	await physics_frame
	game.player.shield = 0
	var health: int = game.player.health
	sniper.fire_at_player()
	assert(game.player.health < health,"A real sniper shot hits at five meters")
	assert(sniper.ranged_damage(5) < sniper.ranged_damage(25),"Damage grows with range")
	medic.tactics.ability_cooldown = 0
	medic._physics_process(.01)
	assert(tank.health == 40 and medic.tactics.channel == "heal", "Healing is announced before health is restored")
	medic.take_damage(1)
	medic._physics_process(1.0)
	assert(tank.health == 40 and medic.tactics.channel == "", "Damaging the healer interrupts its channel")
	medic.tactics.ability_cooldown = 0
	medic._physics_process(.01)
	medic._physics_process(1.0)
	assert(tank.health > 40 and tank.has_node("HealingTrail"),"Completed channel heals and leaves green feedback")
	assert(medic.tactics.ability_cooldown > 0, "Healing has a cooldown after completion")
	tank.apply_slow(5,.45)
	assert(tank.slow_left == 5 and tank.slow_factor == .45)
	tank._physics_process(5.01)
	assert(tank.slow_left == 0 and tank.slow_factor == 1,"Movement recovers after slow expires")
	game.damage_time = 0
	game.damage_overlay.color.a = 0
	game.player.camera.look_at(tank.global_position + Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/test-results/capturas/enemy-healing-feedback.png")
	game.queue_free()
	await process_frame
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(.3).timeout
	print("ENEMY FEEDBACK PASS: close sniper hit, range damage, healing trail, slow expiry")
	quit()
