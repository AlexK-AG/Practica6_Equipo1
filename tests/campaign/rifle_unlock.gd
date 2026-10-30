extends SceneTree
const Driver = preload("res://tests/helpers/mission_driver.gd")
var campaign: Node

func _initialize() -> void:
	call_deferred("run")

func spawn_game() -> Node:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.player.set_physics_process(false)
	game.mission.set_process(false)
	Driver.clear_enemies(game)
	return game

func close_game(game: Node) -> void:
	paused = false
	game.queue_free()
	current_scene = null
	await process_frame
	await process_frame

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/rifle-unlock-private.cfg"
	campaign.store.close()
	for suffix in ["",".bak"]:
		if FileAccess.file_exists(campaign.database_path()+suffix):
			assert(DirAccess.remove_absolute(campaign.database_path()+suffix)==OK)
	# Both active and inactive legacy profiles receive the original starting rifle.
	var old: Dictionary = campaign.fresh_profile("Legacy")
	old.completed = range(6)
	old.weapon_unlocks = ["shotgun", "precision"]
	old.checkpoint = {"level": 6, "sentinel": "preserve"}
	var config := ConfigFile.new()
	config.set_value("campaign", "version", 4)
	config.set_value("campaign", "profiles", {"legacy": old, "inactive": campaign.fresh_profile("Inactive")})
	config.set_value("settings", "music", .6)
	assert(config.save(campaign.save_path) == OK)
	campaign.load_data()
	assert(campaign.profiles.legacy.weapon_unlocks.has("rifle"))
	assert(campaign.profiles.inactive.weapon_unlocks.has("rifle"))
	assert(campaign.profiles.legacy.completed == range(6) and campaign.profiles.legacy.checkpoint.sentinel == "preserve")
	assert(campaign.profiles.legacy.weapon_unlocks.has("precision") and is_equal_approx(campaign.music_volume, .6))
	campaign.active_id = "legacy"
	assert(campaign.reset_campaign() and campaign.available_weapons(1).has("rifle"))
	assert(campaign.select_profile("New pilot"))
	assert(campaign.available_weapons(10) == ["pistol"])
	assert(campaign.selected_loadout(1) == ["pistol"])
	campaign.load_data()
	assert(campaign.available_weapons(1) == ["pistol"], "Reload must not migrate new profiles")
	var game = spawn_game()
	assert(game.player.loadout == ["pistol"] and not game.player.inventory.has("rifle"))
	assert(not game.has_node("LoadoutScreen"))
	var key := InputEventAction.new()
	key.action = "weapon_two"
	key.pressed = true
	game.player._unhandled_input(key)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	game.player._unhandled_input(wheel)
	assert(game.player.weapon_id == "pistol", "Empty second slot is safe")
	var pickup: Node3D
	for item in game.mission.objects:
		if item.weapon_id == "rifle": pickup = item
	assert(pickup != null and pickup.position == Vector3(-4, .1, -20))
	assert(Rect2(-8,-26,16,14).has_point(Vector2(pickup.position.x,pickup.position.z)), "Rifle is in the final room")
	game.mission.done.assign([0,1,2])
	game.mission.doors.sync()
	assert(preload("res://tests/helpers/navigation_checks.gd").route(game,game.mission.objects[3].position,pickup.position).size() > 1, "Pickup is reachable from final objective")
	await physics_frame
	var aim := pickup.position + Vector3(0,1.35,0)
	var ray := PhysicsRayQueryParameters3D.create(aim+Vector3(0,.25,2.5),aim,1,[game.player.get_rid()])
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
	assert(not hit.is_empty() and hit.collider == pickup, "Visible rifle has an unobstructed interaction collider")
	pickup.interact()
	assert(game.player.weapon_id == "rifle" and game.player.loadout == ["pistol","rifle"])
	assert(not campaign.available_weapons(1).has("rifle"))
	game.player.ammo -= 3
	game.mission.checkpoint()
	var rounds: int = game.player.ammo
	await close_game(game)
	campaign.load_data()
	game = spawn_game()
	assert(game.player.weapon_id == "rifle" and game.player.ammo == rounds and game.run_weapons.has("rifle"))
	# Complete the run through the normal objective driver, not a direct unlock.
	Driver.complete(game)
	await game.result_presented
	assert(campaign.available_weapons(2).has("rifle"))
	game.get_node("UpgradeScreen").choose(campaign.offers_for_stage(campaign.pending())[0])
	await close_game(game)
	campaign.load_data()
	assert(campaign.available_weapons(2).has("rifle"))
	# A skipped rifle remains available when replaying level 1.
	assert(campaign.select_profile("Skipped rifle"))
	assert(campaign.complete_level(0,100))
	assert(campaign.choose_upgrade(campaign.offers_for_stage(0)[0]))
	assert(not campaign.available_weapons(2).has("rifle"))
	game = spawn_game()
	var found := false
	for item in game.mission.objects:
		if item.weapon_id == "rifle": found = true
	assert(found)
	await close_game(game)
	var training = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(training)
	current_scene = training
	assert(training.player.inventory.has("rifle") and training.player.loadout == ["pistol","rifle"])
	var described := false
	for step in training.mission.tutorial_guide.steps:
		if step.id == "weapons": described = step.body.contains("última sala del nivel 1") and step.body.contains("perfiles anteriores")
	assert(described)
	await close_game(training)
	campaign.music.stream_paused = false
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(.3).timeout
	print("RIFLE UNLOCK: PASS - legacy migration, fresh users, pickup, checkpoint, completion, replay, tutorial")
	quit()
