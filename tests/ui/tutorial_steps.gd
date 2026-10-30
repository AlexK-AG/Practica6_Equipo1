extends SceneTree
const Driver = preload("res://tests/helpers/tutorial_driver.gd")
var campaign: Node

func _initialize() -> void:
	preload("res://tests/helpers/test_paths.gd").prepare()
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/test-results/capturas/training-" + name + ".png")

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	root.size = Vector2i(1280,720)
	campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/test-results/logs/tutorial-steps-private.cfg"
	campaign.profiles = {"test":campaign.fresh_profile("Training Test")}
	campaign.active_id = "test"
	campaign.profile().completed = range(6)
	campaign.profile().checkpoint = {"level":6,"sentinel":true}
	var before: Dictionary = campaign.profile().duplicate(true)
	var menu = load("res://scenes/start.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	assert(menu.get_node("%Tutorial").text.contains("pendiente"))
	await capture("menu-pending")
	menu.queue_free()
	await process_frame
	var game = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var mission = game.mission
	var guide = mission.tutorial_guide
	assert(not mission.tutorial_interact(3),"Cannot exit before the lessons")
	var untouched_health: int = mission.objects[1].health
	mission.objects[1].take_damage(100)
	assert(mission.objects[1].health == untouched_health,"Future targets cannot be damaged")
	game.set_pause(true)
	await process_frame
	assert(not guide.visible,"Guide does not cover pause menu")
	game.set_pause(false)
	var seen: Array[String] = []
	for iteration in range(35):
		if game.finished:
			break
		var id: String = guide.current_id()
		assert(not seen.has(id),"Each lesson occurs once")
		seen.append(id)
		await process_frame
		await process_frame
		var active: int = guide.active_object_id()
		var signs: Control = game.get_node("HUD/Interface/TutorialBeacons")
		var visible_signs := 0
		for sign in signs.get_children():
			if sign.visible:
				visible_signs += 1
		assert(visible_signs == (0 if active == -999 else 1),"Exactly this step's card is visible")
		for item in mission.objects:
			assert(item.visible == (item.active and item.object_id == active),"Only this step's object is visible")
			assert(item.collision_layer == (1 if item.visible else 0),"Future objects do not obstruct practice")
			if item.visible and id in ["terminal","card","supply","weapon_pickup","grenade_pickup","exit"]:
				assert(not game.route(game.player.position,item.position).is_empty(),"Active E exercise is reachable")
				game.player.position = mission.reachable(item.position + Vector3(0,0,2.4))
				game.player.camera.look_at(item.position + Vector3(0,.8,0))
				await physics_frame
				await physics_frame
				var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(game.player.camera.global_position,item.position + Vector3(0,.8,0),1,[game.player.get_rid()]))
				assert(not hit.is_empty() and hit.collider == item,"Visible E item has a usable interaction surface")
		if id in ["cover_small","cover_tall","cover_search"]:
			assert(guide.complete and not guide.next.disabled,"Cover explanations advance independently with Next")
			assert(active == -999,"Cover lesson does not overlap a previous practice target")
			assert(not guide.body.text.contains("ray") and not guide.body.text.contains("colisión"),"Cover lessons use player-facing language")
			assert(guide.preview.visible == (id != "cover_search"),"Cover height examples show their corresponding enemy preview")
		if id in ["vitals","arsenal","missions","terminal","shoot","enemy0","enemy5","cover_small","cover_tall","cover_search"]:
			await capture(id)
		if not guide.complete:
			var phase: int = guide.step
			guide.advance()
			assert(guide.step == phase,"Next stays blocked until the action is complete")
			Driver.practice(game)
		if not game.finished:
			assert(guide.complete,"Real practice satisfies this step")
			guide.advance()
	assert(seen.size() == guide.steps.size() and game.finished)
	assert(seen.find("cover_small") == seen.find("shoot")+1,"Cover lesson follows shooting practice")
	assert(seen.find("cover_tall") == seen.find("cover_small")+1 and seen.find("cover_search") == seen.find("cover_tall")+1,"Small cover, tall enemies and search are separate sequential lessons")
	await game.result_presented
	assert(campaign.profile().tutorial_completed)
	for field in before:
		assert(campaign.profile()[field] == before[field],"Training must preserve campaign fields: " + field)
	assert(mission.tutorial_reloaded and mission.tutorial_switched and mission.tutorial_grenade)
	await capture("finished")
	game.queue_free()
	await process_frame
	campaign.load_data()
	assert(campaign.profile().tutorial_completed,"Completion survives disk reload")
	menu = load("res://scenes/start.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	assert(menu.get_node("%Tutorial").text.contains("completado"))
	await capture("menu-completed")
	menu.menu_music_player.stop()
	menu.menu_music_player.stream = null
	menu.queue_free()
	await process_frame
	assert(campaign.reset_campaign() and campaign.profile().tutorial_completed,"Campaign reset preserves having completed training")
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(.3).timeout
	print("TUTORIAL STEPS PASS: HUD, independent practice, three cover lessons, six roles, Next gating, completion and campaign preservation")
	quit()
