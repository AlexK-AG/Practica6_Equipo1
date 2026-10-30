extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	var campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/grenade-private-tests.cfg"
	campaign.profiles = {}
	campaign.select_profile("Grenade test")
	campaign.profile().completed = range(10)
	campaign.profile().pending = -1
	check(campaign.available_grenades() == ["basic"], "Skipping levels must not unlock grenades")
	for level in [2, 5]:
		var id: String = "fragmentation" if level == 2 else "slow"
		var game = load("res://scenes/levels/level_%d.tscn" % level).instantiate()
		root.add_child(game)
		current_scene = game
		game.set_pause(false)
		game.mission.set_process(false)
		for enemy in game.get_children():
			if enemy is EnemyController:
				enemy.set_physics_process(false)
		await physics_frame
		var pickup: Node
		for item in game.mission.objects:
			if item.grenade_id == id:
				pickup = item
		check(pickup != null and pickup.active, "Missed grenade pickup available on replay")
		if pickup != null:
			var expected := Vector3(5,.1,-27) if level == 2 else Vector3(28,.1,-26)
			check(pickup.position == expected and pickup.position == game.get_node("MissionPoints/GrenadePickup").position, "Grenade retains authored final-room position")
			check(game.route(game.player.position, pickup.position).is_empty(), "Final-room grenade is inaccessible before mission prerequisites")
			check(preload("res://tests/helpers/navigation_checks.gd").route(game,game.player.position,pickup.position).size() > 1, "Grenade room has a connected route behind its mission lock")
			# Simulate completed prerequisites to verify the actual exit-room route.
			for enemy in game.get_children():
				if enemy is EnemyController:
					enemy.health = 0
					enemy.revival_left = -1
			game.mission.done.assign(range(game.mission.objective_count - 1))
			game.mission.wave = 5
			game.mission.wave_remaining = 0
			game.mission.defense_time = 0
			game.mission.doors.sync(false)
			check(game.route(game.player.position,pickup.position).size() > 1, "Final-room grenade becomes reachable after mission prerequisites")
			await physics_frame
			var aim: Vector3 = pickup.position + Vector3(0,.8,0)
			var query := PhysicsRayQueryParameters3D.create(aim+Vector3(0,.4,2.5),aim,1,[game.player.get_rid()])
			var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and hit.collider == pickup, "Final-room grenade interaction is unobstructed")
			check(not game.grid.is_point_solid(Vector2i(roundi(pickup.position.x), roundi(pickup.position.z))), "Grenade pickup on walkable cell")
			for enemy in game.get_children():
				if enemy is EnemyController:
					enemy.health = enemy.max_health
			pickup.interact()
			check(not pickup.active and game.mission.found_grenades.has(id), "Physical pickup recorded")
			check(game.player.grenade_type == id and game.player.grenades == 2, "Immediate usable separate stock")
			check(not campaign.available_grenades().has(id), "Pickup alone is not permanent")
			check(not game.mission.interact_object(pickup.object_id), "Duplicate pickup cannot refill")
		game.player.throw_grenade()
		check(game.player.grenades == 1, "Throw consumes selected stock")
		check(game.player.grenade_audio.playing, "Throw audio plays")
		game.mission.checkpoint()
		var state: Dictionary = campaign.profile().checkpoint.player.duplicate(true)
		game.player.grenades = 0
		game.player.restore_state(state)
		check(game.player.grenades == 1 and game.player.grenade_type == id, "Checkpoint restores exact stock and selection")
		var old: Dictionary = state.duplicate(true)
		old.erase("grenade_inventory")
		old.erase("grenade_type")
		old.grenades = 2
		game.player.restore_state(old)
		check(game.player.grenade_type == "basic" and game.player.grenades == 2, "Legacy basic-grenade checkpoints survive")
		game.player.restore_state(state)
		var before: String = game.player.grenade_type
		game.player.cycle_grenade()
		check(game.player.grenade_type != before, "Grenade type selection cycles")
		check(InputMap.has_action("grenade_cycle") and campaign.DEFAULT_KEYS.grenade_cycle == KEY_Q, "Configurable cycle action defaults Q")
		# Controlled target validates direct explosion damage and the slow API.
		var target = load("res://scenes/actors/enemy_0.tscn").instantiate()
		target.kind = 0
		target.max_health = 10000
		target.position = game.mission.reachable(Vector3(0, 0, 0))
		game.add_child(target)
		target.set_physics_process(false)
		target.health = 10000
		await physics_frame
		var bomb := RigidBody3D.new()
		bomb.set_script(load("res://scripts/combat/grenade.gd"))
		bomb.grenade_type = id
		bomb.position = target.position + Vector3(0, 1, 1)
		game.add_child(bomb)
		bomb.freeze = true
		await physics_frame
		bomb.detonate()
		check(target.health < 10000, "Explosion damages target in range")
		if id == "slow":
			check(target.slow_left > 0 and is_equal_approx(target.slow_factor, .45), "Stasis slows for five seconds")
		check(game.find_child("GrenadeExplosion", false, false) != null, "Explosion sound survives projectile deletion")
		game.mission.checkpoint()
		var saved_enemies: Array = campaign.profile().checkpoint.enemies
		if id == "slow":
			check(saved_enemies.any(func(enemy): return float(enemy.get("slow_left", 0)) > 0), "Slow state saved in checkpoint")
		check(campaign.complete_level(level - 1, 100, [], game.mission.found_grenades), "Replay completion grants collected grenade")
		check(campaign.available_grenades().has(id), "Grenade permanent after successful extraction")
		check(campaign.save_data(), "Save grenade unlock")
		campaign.load_data()
		check(campaign.available_grenades().has(id), "Unlock survives disk reload")
		game.queue_free()
		current_scene = null
		await process_frame
		await process_frame
	check(campaign.available_grenades() == ["basic", "fragmentation", "slow"], "All three types found progressively")
	var replay = load("res://scenes/levels/level_2.tscn").instantiate()
	root.add_child(replay)
	current_scene = replay
	replay.set_pause(false)
	check(replay.player.grenade_inventory == {"basic": 3, "fragmentation": 2, "slow": 2}, "Permanent unlocks initialize separate balanced stocks")
	check(not replay.mission.objects.any(func(item): return not item.grenade_id.is_empty()), "Permanent discovery does not offer duplicate refill pickup")
	for audio in replay.find_children("*", "AudioStreamPlayer", true, false):
		audio.stop()
		audio.stream = null
	replay.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	campaign.profile().grenade_unlocks = []
	check(campaign.complete_level(0, 100, [], ["slow"]), "Unrelated replay remains valid")
	check(campaign.available_grenades() == ["basic"], "Wrong-sector discovery cannot grant special grenade")
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(.3).timeout
	print("GRENADES: %d failures" % failures)
	quit(0 if failures == 0 else 1)
