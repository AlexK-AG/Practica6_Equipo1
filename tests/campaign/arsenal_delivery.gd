extends SceneTree
const Paths = preload("res://tests/helpers/test_paths.gd")
const DB := "res://.godot/test-results/arsenal-delivery.sqlite"
var failures := 0
var campaign: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func freeze(game: Node) -> void:
	if game.has_node("LoadoutScreen"):
		game.get_node("LoadoutScreen").accept()
	game.set_pause(false)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.mission.set_process(false)
	game.mission.doors.set_process(false)
	for actor in game.get_children():
		if actor is EnemyController:
			actor.set_physics_process(false)

func clear(game: Node) -> void:
	for actor in game.get_children():
		if actor is EnemyController:
			game.remove_child(actor)
			actor.free()

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	Paths.prepare()
	campaign = root.get_node("Campaign")
	campaign.store.close()
	for suffix in ["",".bak"]:
		if FileAccess.file_exists(DB+suffix):
			assert(DirAccess.remove_absolute(DB+suffix)==OK)
	campaign.save_path = DB
	campaign.load_data()
	check(campaign.select_profile("Arsenal test"),"Private profile")
	campaign.profile().completed = range(8)
	var game = load("res://scenes/levels/level_9.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	freeze(game)
	var mission: Node = game.mission
	var delivery: RefCounted = mission.early.delivery
	check(mission.objective_count==8,"Original sequence plus collection and delivery")
	check(delivery.supplies.size()==3,"Three extraction supplies")
	for item in delivery.supplies:
		check(not item.active and item.collision_layer==0,"Extraction supplies are locked until original mission is secured")
	clear(game)
	delivery.tick(7.1)
	check(mission.living_enemies()==0,"No transport reinforcements during original mission")
	for id in range(5):
		clear(game)
		check(mission.interact_object(id),"Original objective %d preserved" % id)
	check(mission.early.stage==5 and not game.finished,"Former final exit is now a secured-exit stage")
	clear(game)
	check(mission.spawn_enemy(0),"Guard blocks securing original exit")
	check(not mission.interact_object(5),"Original exit still requires eliminating existing enemies")
	clear(game)
	check(mission.interact_object(5),"Securing old exit starts return trip")
	check(mission.early.stage==6 and not game.finished,"Must return to initial room")
	check(not mission.interact_object(7),"Cannot skip collecting cargo")
	for item in delivery.supplies:
		check(item.active,"Extraction ammunition available during return trip")
		check(game.route(mission.objects[6].position,item.position).size()>1,"Each side cache remains reachable from cargo")
	check(game.route(game.player.position,mission.objects[6].position).size()>1,"Cargo in initial room remains reachable")
	delivery.tick(6.9)
	check(mission.living_enemies()==0,"No reinforcement before seven seconds")
	delivery.tick(.2)
	var pressure: int = mission.living_enemies()
	check(pressure>=1 and pressure<=2,"One or two reinforcements per seven-second burst")
	check(mission.interact_object(6),"Living reinforcements do not block collecting cargo")
	check(mission.early.stage==7 and mission.early.cargo and game.player.cargo_factor==.8,"Cargo slows movement and advances to final room")
	var used: int = delivery.supplies[0].object_id
	check(mission.interact_object(used),"Extraction cache can be collected")
	delivery.tick(2.0)
	mission.checkpoint()
	var checkpoint: Dictionary = campaign.profile().checkpoint.duplicate(true)
	check(checkpoint.arsenal_delivery.wait<7 and checkpoint.arsenal_delivery.wait>0,"Remaining reinforcement delay saved")
	check(checkpoint.arsenal_delivery.batches==1,"Burst count saved")
	check(checkpoint.supplies.has(used),"Used extraction cache saved")
	game.queue_free()
	await process_frame
	# Legacy stage IDs 0..5 retain their meaning; they have no delivery state key.
	for old_stage in range(6):
		var legacy: Dictionary = checkpoint.duplicate(true)
		legacy.erase("arsenal_delivery")
		legacy.done = range(old_stage)
		legacy.cargo = false
		legacy.stage_started = true
		legacy.supplies = [-10]
		legacy.enemies = []
		campaign.profile().checkpoint = legacy
		game = load("res://scenes/levels/level_9.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		freeze(game)
		check(game.mission.early.stage==old_stage,"Legacy checkpoint stage %d preserved" % old_stage)
		check(not game.mission.early.cargo and game.player.cargo_factor==1.0,"Legacy stage never gains cargo prematurely")
		check(game.mission.done==range(old_stage),"Legacy completed objectives preserved")
		check(game.mission.used_supplies.has(-10),"Old supply identifiers preserved")
		check(is_equal_approx(game.mission.early.delivery.wait,7.0),"Legacy save receives initial seven-second delay")
		game.queue_free()
		await process_frame
	campaign.profile().checkpoint = checkpoint
	game = load("res://scenes/levels/level_9.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	freeze(game)
	mission = game.mission
	delivery = mission.early.delivery
	check(mission.early.stage==7 and mission.early.cargo and game.player.cargo_factor==.8,"Checkpoint restores carrying state")
	check(is_equal_approx(delivery.wait,float(checkpoint.arsenal_delivery.wait)),"Checkpoint restores remaining delay without restarting it")
	check(not delivery.supplies[0].active,"Used cache does not respawn on checkpoint")
	check(mission.living_enemies()>0,"Checkpoint retains transport enemies")
	check(game.route(game.player.position,mission.objects[7].position).size()>1,"Final delivery room reachable")
	check(mission.interact_object(7),"Final delivery succeeds despite living reinforcements")
	check(game.finished and game.player.cargo_factor==1.0,"Delivery ends level and clears carrying penalty")
	var before: int = game.enemy_count
	delivery.tick(20)
	check(game.enemy_count==before,"No reinforcement after ending mission")
	check(campaign.profile().completed.has(8),"Victory records level nine progress")
	await create_timer(.8).timeout
	game.queue_free()
	await process_frame
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(.5).timeout
	print("ARSENAL DELIVERY: %d failures" % failures)
	quit(1 if failures else 0)
