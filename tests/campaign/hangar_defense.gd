extends SceneTree
var campaign: Node
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func clear(game: Node) -> void:
	for actor in game.get_children():
		if actor is EnemyController:
			game.remove_child(actor)
			actor.free()
func freeze(game: Node) -> void:
	for actor in game.get_children():
		if actor is EnemyController:
			actor.set_physics_process(false)
func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	campaign=root.get_node("Campaign")
	campaign.save_path="res://.godot/hangar-defense-private.sqlite"
	campaign.load_data()
	campaign.profiles.clear()
	campaign.select_profile("Hangar test")
	campaign.profile().completed=range(10)
	var game=load("res://scenes/levels/level_8.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	if game.has_node("LoadoutScreen"):
		game.get_node("LoadoutScreen").accept()
	game.set_pause(false)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.mission.set_process(false)
	game.mission.doors.set_process(false)
	clear(game)
	var late=game.mission.early
	late.stage=5
	game.mission.done=[0,1,2,3,4]
	check(game.mission.interact_object(5),"Start defense")
	var defense=late.defense
	freeze(game)
	check(game.mission.defense_time==120 and defense.health==150,"Two minutes and 150 cargo HP")
	var supplies=game.mission.objects.filter(func(item):return item.title.begins_with("MUNICIÓN DE DEFENSA"))
	check(supplies.size()==4,"Four defense supplies")
	for supply in supplies:
		check(not preload("res://tests/helpers/navigation_checks.gd").route(game,game.player.position,supply.position).is_empty(),"Defense supply reachable")
	check(not game.mission.interact_object(6),"Cannot leave while defense active")
	defense.tick(5.9)
	check(defense.groups==0,"No batch before six seconds")
	defense.tick(.1)
	freeze(game)
	check(defense.groups==1,"First batch at six seconds")
	defense.tick(54)
	freeze(game)
	check(defense.groups==10,"Ten batches in first minute")
	defense.tick(6.9)
	check(defense.groups==10,"Second phase waits seven seconds")
	defense.tick(.1)
	freeze(game)
	check(defense.groups==11,"Second phase first batch at 67s")
	defense.tick(53)
	freeze(game)
	check(defense.groups==18 and defense.completed and game.mission.defense_time==0,"Eight batches in second minute and exact stop")
	var events: Array=campaign.events.pending.filter(func(event):return event.event_type=="defense_group_spawned")
	# Completion saves its checkpoint, so query the committed event stream.
	campaign.flush_events()
	var rows: Array=campaign.store.rows("SELECT payload_json FROM game_events WHERE session_id=? AND event_type='defense_group_spawned' ORDER BY sequence",[game._history_id])
	var total:=0
	for index in range(rows.size()):
		var event: Dictionary=JSON.parse_string(rows[index].payload_json)
		total+=int(event.enemies)
		check(event.enemies==(2 if index<10 else 3),"Grouped spawn matches phase")
	check(total==44,"Exactly 44 scheduled reinforcements")
	defense.tick(200)
	check(defense.groups==18,"No scheduled spawns after time ends")
	clear(game)
	defense.begin()
	var enemy=load("res://scenes/actors/enemy_0.tscn").instantiate()
	enemy.position=defense.cargo.position+Vector3(0,0,4)
	game.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.warning_duration=0
	enemy.attack_time=0
	await physics_frame
	await physics_frame
	check(defense.tick_enemy(enemy,.1),"Enemy chooses cargo when player is distant")
	check(defense.health<150,"Enemy actually damages cargo through clear physical shot")
	clear(game)
	enemy=load("res://scenes/actors/enemy_12.tscn").instantiate()
	enemy.position=defense.cargo.position+Vector3(0,0,4)
	game.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.warning_duration=0
	enemy.attack_time=0
	await physics_frame
	await physics_frame
	var before_heavy:int=defense.health
	check(defense.tick_enemy(enemy,.1) and defense.health<before_heavy,"Heavy attacker can fire at cargo without player visibility memory")
	game.hud_view.refresh()
	check(game.get_node("HUD/Interface/MissionPanel/Content/CargoVitality").visible,"Cargo health bar visible in authored HUD")
	var hp:int=defense.health
	defense.cargo.take_damage(100,{"source":"player"})
	check(defense.health==hp,"Player fire does not destroy objective")
	game.mission.checkpoint()
	check(campaign.profile().checkpoint.hangar_defense.health==hp,"Checkpoint preserves cargo damage")
	supplies[0].interact()
	game.mission.checkpoint()
	game.queue_free()
	await process_frame
	campaign.load_data()
	game=load("res://scenes/levels/level_8.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	game.set_pause(false)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.mission.set_process(false)
	game.mission.doors.set_process(false)
	freeze(game)
	defense=game.mission.early.defense
	check(defense.health==hp and defense.started and not defense.completed,"Checkpoint restores damaged cargo and active defense")
	check(game.mission.defense_time==120 and defense.next_spawn==6,"Checkpoint restores time and next batch")
	var restored_supplies=game.mission.objects.filter(func(item):return item.title.begins_with("MUNICIÓN DE DEFENSA"))
	check(not restored_supplies[0].active,"Used defense supply does not return on reload")
	defense.cargo.take_damage(1000,{"source":"enemy"})
	check(game.finished and defense.health==0,"Cargo destruction fails mission")
	paused=false
	await create_timer(.8).timeout
	game.queue_free()
	await process_frame
	campaign.music.stop()
	campaign.music.stream=null
	await create_timer(.3).timeout
	print("HANGAR DEFENSE: %d failures" % failures)
	quit(1 if failures else 0)
