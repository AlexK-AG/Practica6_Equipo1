extends SceneTree
const Driver = preload("res://tests/helpers/mission_driver.gd")
const Nav = preload("res://tests/helpers/navigation_checks.gd")
var failures := 0
var campaign: Node
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func freeze(game: Node) -> void:
	if game.has_node("LoadoutScreen"): game.get_node("LoadoutScreen").accept()
	game.set_pause(false)
	game.player.set_physics_process(false)
	game.mission.set_process(false)
	for enemy in game.get_children():
		if enemy is EnemyController: enemy.set_physics_process(false)
func make_game(level: int) -> Node:
	campaign.profile().pending = -1
	var game = load(campaign.LEVELS[level - 1].path).instantiate()
	root.add_child(game)
	current_scene = game
	freeze(game)
	return game
func close(game: Node) -> void:
	paused = false
	game.queue_free()
	await process_frame
func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	campaign = root.get_node("Campaign")
	campaign.profiles = {}
	campaign.select_profile("Sector finales")
	campaign.profile().completed = range(10)
	for level in [3,4,5,6]:
		campaign.profile().erase("checkpoint")
		var game = make_game(level)
		await physics_frame
		var mission = game.mission
		check(mission.objective_count == {3:8,4:9,5:7,6:8}[level], "Expanded stage count in sector %d" % level)
		var purge_budget := 0
		for id in range(mission.objective_count):
			freeze(game)
			mission.doors.sync(false)
			check(Nav.route(game, game.player.position, mission.objects[id].position).size() > 1, "Stage reachable: sector %d stage %d" % [level,id])
			if level==3 and id==6:
				check(mission.early.guards_alive()==2, "Two cargo guards")
				check(mission.timer==180 and not mission.early.cargo, "180 seconds start before cargo retrieval")
				check(not mission.interact_object(7), "Cannot skip cargo and evacuate")
				check(mission.objects[6].position.distance_to(Vector3(0,.1,26))<3, "Cargo in initial room")
			if level==4 and id==7:
				check(mission.timer==120 and mission.early.guards_alive()==4, "Emergency furnace has 120 seconds and four guards")
				check(not mission.interact_object(8), "Exit blocked until furnace disabled")
				mission._process(9)
				check(mission.timer==111, "Emergency countdown advances")
			if level==6 and id in [3,4,5]:
				check(mission.early.guards_alive()==3, "Each command key has three guards")
				check(not mission.interact_object(id), "Key guards must be defeated")
			Driver.clear_enemies(game)
			if level==5 and id==6:
				check(mission.defense_time==90 and mission.reinforcements_left in [5,6], "90-second purge with five or six scheduled enemies")
				purge_budget=mission.reinforcements_left
				check(not mission.interact_object(id), "Extraction blocked during purge")
				var before: int=game.enemy_count
				for tick in range(90):
					mission._process(1)
					Driver.clear_enemies(game)
				check(mission.defense_time==0 and mission.reinforcements_left==0, "Purge finishes and emits all reinforcements")
				check(game.enemy_count-before==purge_budget, "Exact five or six purge enemies")
			if level==4 and id==8:
				check(mission.timer<0, "Furnace disables countdown")
				mission._process(70)
				check(not game.finished, "No timeout after furnace disabled")
			game.player.position=mission.objects[id].position+Vector3(0,0,2)
			check(mission.interact_object(id), "Stage accepts interaction: sector %d stage %d" % [level,id])
			if level==3 and id==6:
				check(mission.early.cargo and is_equal_approx(game.player.cargo_factor,.8), "Cargo must be carried back")
			if (level==3 and id==6) or (level==4 and id==6) or (level==6 and id==4):
				var timer: float=mission.timer
				var count: int=mission.living_enemies()
				mission.checkpoint()
				if level==4:
					campaign.profile().checkpoint["sector_revision"]=1
					campaign.profile().checkpoint["timer"]=timer-60
				if level==6:
					campaign.profile().checkpoint["sector_revision"]=1
					var snapshots: Array=campaign.profile().checkpoint.enemies
					for index in range(snapshots.size()):
						if int(snapshots[index].get("encounter",-1))==5:
							snapshots.remove_at(index)
							break
				await close(game)
				game=make_game(level)
				await physics_frame
				mission=game.mission
				check(mission.early.stage==id+1 and mission.timer==timer and mission.living_enemies()==count, "Checkpoint restores new stages without duplicate guards")
				if level==3: check(mission.early.cargo, "Checkpoint restores evacuation cargo")
		check(game.finished, "Sector completes: %d" % level)
		await game.result_presented
		await close(game)
	# Legacy sector checkpoints retain inventory/progress while inserting new tasks.
	for level in [3,4,5,6]:
		campaign.profile().erase("checkpoint")
		var game=make_game(level)
		game.mission.checkpoint()
		var saved: Dictionary=campaign.profile().checkpoint.duplicate(true)
		await close(game)
		saved.erase("sector_revision")
		saved["done"]=[0,1,2,3,4,5] if level in [3,4,5] else [0,1,2,3,4]
		saved["enemies"]=[]
		saved["stage_started"]=true
		if level==3: saved["timer"]=120
		if level==5:
			saved["defense_time"]=30
			saved["reinforcements"]=4
		campaign.profile()["checkpoint"]=saved
		game=make_game(level)
		check(game.mission.early.stage==(4 if level==6 else 6), "Legacy checkpoint inserts pending tasks")
		if level==3: check(game.mission.timer==180 and game.mission.early.guards_alive()==2, "Legacy reactor gains 60 seconds and two cargo guards")
		if level==4: check(game.mission.early.guards_alive()==3, "Legacy foundry starts final defender task")
		if level==5: check(game.mission.defense_time==90 and game.mission.reinforcements_left==6, "Legacy purge extended without resetting progress")
		if level==6: check(game.mission.done==[0,1,2,3] and game.mission.early.guards_alive()==3, "Legacy fortress retains first key and adds remaining keys")
		var timer: float=game.mission.timer
		var count: int=game.mission.living_enemies()
		game.mission.checkpoint()
		await close(game)
		game=make_game(level)
		check(game.mission.timer==timer and game.mission.living_enemies()==count, "Migration applies once without duplicate guards")
		await close(game)
	# Explicit timer failure, independently from victory and with no real saves.
	for level in [3,4]:
		campaign.profile().erase("checkpoint")
		var game=make_game(level)
		game.mission.timer=.5
		game.mission._process(1)
		check(game.finished, "Expired countdown ends sector %d" % level)
		await create_timer(.8).timeout
		await close(game)
	campaign.music.stop()
	campaign.music.stream=null
	await create_timer(.3).timeout
	print("SECTOR FINALES: ", "PASS" if failures==0 else "FAIL", " / failures=",failures)
	quit(failures)
