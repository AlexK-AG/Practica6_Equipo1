extends SceneTree
const Driver = preload("res://tests/helpers/mission_driver.gd")
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")
var failures := 0
var campaign: Node
var observed: Array[int] = []

func _initialize() -> void:
	preload("res://tests/helpers/test_paths.gd").prepare()
	call_deferred("run")

func check(value: bool,message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func freeze(game: Node) -> void:
	game.set_pause(false)
	if game.has_node("LoadoutScreen"):
		game.get_node("LoadoutScreen").accept()
	game.player.set_physics_process(false)
	game.mission.set_process(false)
	game.mission.doors.set_process(false)
	for enemy in game.get_children():
		if enemy is EnemyController:
			enemy.set_physics_process(false)

func make_game(level: int) -> Node:
	campaign.profile().pending = -1
	var game = load(campaign.LEVELS[level - 1].path).instantiate()
	root.add_child(game)
	current_scene = game
	freeze(game)
	return game

func close_game(game: Node) -> void:
	paused = false
	game.queue_free()
	await process_frame

func run() -> void:
	campaign = root.get_node("Campaign")
	campaign.options.difficulty = 1
	campaign.save_path = "res://.godot/test-results/logs/sector-systems-profile.cfg"
	campaign.profiles = {}
	campaign.select_profile("Sector systems")
	campaign.profile().completed = range(10)
	for level in range(1,11):
		campaign.profile().erase("checkpoint")
		var game = make_game(level)
		var mission = game.mission
		var doors = mission.doors
		await physics_frame
		check(not doors.gates.is_empty(),"Physical progression doors exist in sector%d" % level)
		var closed_gate: Dictionary = doors.gates[0]
		var collision: CollisionShape3D = closed_gate.body.find_children("*","CollisionShape3D",false,false)[0]
		var shape: Vector3 = collision.shape.size
		var normal := Vector3.RIGHT if shape.x < shape.z else Vector3.BACK
		var center: Vector3 = closed_gate.body.position + Vector3.UP * 2
		var exclusions: Array[RID] = [game.player.get_rid()]
		for enemy in game.get_children():
			if enemy is EnemyController:exclusions.append(enemy.get_rid())
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center + normal * 2,center - normal * 2,1,exclusions))
		check(not hit.is_empty() and hit.collider == closed_gate.body,"Closed door has a physical collision surface")
		var categories := {"walls":false,"floor":false,"roof":false}
		for mesh in game.get_node("Arena").find_children("*","MeshInstance3D",true,false):
			var parent_name: String = str(mesh.get_parent().name)
			var category: String = "walls" if parent_name.begins_with("Wall") else ("floor" if parent_name.begins_with("Floor") else ("roof" if str(game.get_node("Arena").get_path_to(mesh)).begins_with("Ceilings/") else ""))
			if not category.is_empty():
				var material: StandardMaterial3D = mesh.material_override
				check(material != null and material.albedo_texture != null and material.normal_texture != null and material.uv1_world_triplanar,"Textured PBR world surface: %s sector%d" % [category,level])
				categories[category] = true
		check(categories.values().all(func(value):return value),"All three surface categories textured")
		for enemy in game.get_children():
			if enemy is EnemyController:
				check(Catalog.MIN_LEVEL[enemy.kind] <= level,"Subtype introduced at an appropriate sector")
				if not observed.has(enemy.kind): observed.append(enemy.kind)
		for id in range(mission.objective_count):
			freeze(game)
			Driver.clear_enemies(game)
			if level == 7 and id == 5:
				mission._process(46)
				Driver.clear_enemies(game)
			if level in [5,8] and id == mission.objective_count - 1:
				mission._process(121 if level == 8 else 91)
				Driver.clear_enemies(game)
			if level == 2 and id == mission.objective_count - 1:
				for tick in range(180):
					mission._process(3)
					Driver.clear_enemies(game)
					if mission.wave >= mission.WAVE_SIZES.size() and mission.wave_remaining == 0:break
			doors.sync(false)
			var point: Vector3 = mission.objects[id].position
			var path: PackedVector2Array = game.route(game.player.position,point)
			check(path.size() > 0,"Active stage reachable through current doors: sector%d stage%d from%s to%s" % [level,id,game.player.position,point])
			game.player.position = point
			if level == 10 and id == 2:
				doors._process(0)
				check(doors.arena_sealed,"Entry seals the boss chamber")
				check(doors.gates.all(func(gate):return gate.closed),"Every boss access is physically closed")
				check(game.route(game.player.position,Vector3(0,.1,17)).is_empty(),"No escape path during boss combat")
				mission.checkpoint()
				await close_game(game)
				game = make_game(10)
				mission = game.mission
				doors = mission.doors
				check(doors.arena_sealed and doors.gates.all(func(gate):return gate.closed),"Checkpoint restores the sealed arena")
				Driver.clear_enemies(game)
			if mission.objects[id].destructible:
				mission.objects[id].take_damage(10000)
				check(mission.done.has(id),"Destructible objective advances normally")
			else:
				check(mission.interact_object(id),"Current mission stage accepts interaction")
			if level == 10 and id in [2,3,4]:
				var boss = game.get_node("FinalBoss")
				mission.early.update_effects()
				boss.take_damage(100000)
				mission.early.update_effects()
				doors.sync(false)
				if id == 4:
					check(doors.gates.all(func(gate):return not gate.closed),"Boss death opens every access")
		check(game.finished,"Sector completes with physical locks")
		await game.result_presented
		await close_game(game)
	check(observed.size() == Catalog.ENTRIES.size(),"All eighteen subtypes appear during the campaign")
	await abilities()
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(.2).timeout
	print("SECTOR SYSTEMS: ","PASS" if failures == 0 else "FAIL"," / failures=",failures)
	quit(failures)

func abilities() -> void:
	campaign.profile().erase("checkpoint")
	var game = make_game(8)
	Driver.clear_enemies(game)
	await process_frame
	var revenant = load("res://scenes/actors/enemy_16.tscn").instantiate()
	revenant.name = "RevivalFixture"
	revenant.position = Vector3(-27,.1,26)
	game.add_child(revenant)
	revenant.set_physics_process(false)
	game.enemy_count += 1
	var kills: int = game.kills
	revenant.take_damage(100000)
	check(revenant.revival_left == 4 and revenant.is_threat() and game.kills == kills,"First fall retains threat and does not award a kill")
	check(is_equal_approx(revenant.title.global_basis.get_scale().y,1),"Revival instructions retain their readable size")
	var phase = load("res://scenes/actors/enemy_17.tscn").instantiate()
	phase.name = "PhaseFixture"
	phase.position = Vector3(-25,.1,26)
	game.add_child(phase)
	phase.set_physics_process(false)
	phase.phase_left = 1.2
	phase.restore_special_visuals()
	var hp: int = phase.health
	phase.take_damage(100000)
	check(phase.health == hp and phase.collision_layer == 0,"Desfasado is intangible")
	game.mission.checkpoint()
	await close_game(game)
	game = make_game(8)
	revenant = game.get_node("RevivalFixture")
	phase = game.get_node("PhaseFixture")
	check(revenant.revival_left == 4 and revenant.health == 0 and phase.phase_left == 1.2,"Checkpoint restores ongoing revival and phase timers")
	revenant.special_tick(4.1)
	check(revenant.has_revived and revenant.health == ceili(revenant.max_health * .6),"Single revival restores sixty percent health")
	revenant.take_damage(100000)
	check(game.kills == kills + 1,"Final death awards exactly one kill")
	phase.special_tick(1.3)
	check(phase.phase_left < 0 and phase.collision_layer == 1 and game.route(phase.position,game.player.position).size() > 0,"Reappearance respects closed sectors")
	phase.queue_free()
	await process_frame
	var medic = load("res://scenes/actors/enemy_4.tscn").instantiate()
	medic.position = Vector3(0,.1,5)
	game.add_child(medic)
	medic.set_physics_process(false)
	medic.alerted = true
	var tank = load("res://scenes/actors/enemy_2.tscn").instantiate()
	tank.position = Vector3(2,.1,5)
	tank.max_health = 100
	game.add_child(tank)
	tank.set_physics_process(false)
	check(tank.max_health == 160,"Tank gains durable health without reapplying it on reload")
	tank.health = 50
	await physics_frame
	medic.tactics.ability_cooldown = 0
	medic._physics_process(.01)
	check(tank.health == 50 and medic.tactics.channel == "heal", "Medic announces its healing channel")
	medic._physics_process(1.0)
	check(tank.health >= 90 and medic.tactics.ability_cooldown > 0,"Medic completes a bounded healing channel")
	check(tank.has_node("HealingTrail"),"Healing leaves a visible green trail on its recipient")
	var sniper = load("res://scenes/actors/enemy_7.tscn").instantiate()
	sniper.position = Vector3(-4,.1,5)
	game.add_child(sniper)
	sniper.set_physics_process(false)
	check(sniper.attack_range >= 38 and sniper.attack_damage > 8,"Sniper gains range and damage")
	check(sniper.ranged_damage(1) > 0 and sniper.ranged_damage(1) < sniper.ranged_damage(18) and sniper.ranged_damage(18) < sniper.ranged_damage(38),"Sniper can hurt nearby and damage grows with distance")
	for summoner_kind in [5,11]:
		var summoner = load("res://scenes/actors/enemy_%d.tscn" % summoner_kind).instantiate()
		summoner.position = Vector3(-7,.1,5)
		game.add_child(summoner)
		summoner.set_physics_process(false)
		var count_before: int = game.enemy_count
		var previous_enemies: Array = game.get_children()
		var death_position: Vector3 = summoner.global_position
		summoner.finish_death()
		var released: Array = []
		for reinforcement in game.get_children():
			if reinforcement is EnemyController and not previous_enemies.has(reinforcement):
				released.append(reinforcement)
				reinforcement.set_physics_process(false)
				check(reinforcement.global_position.distance_to(death_position)<=5.05,"Death reinforcements spawn at the corpse, not across the map")
				check(reinforcement.kind in summoner.summon_pool(),"Death reinforcements retain the invoker subtype pool")
				check(game.navigation_segment_clear(death_position,reinforcement.global_position),"Corpse spawn cannot cross a wall or closed gate")
		check(released.size()==2,"Exactly two nearby death reinforcements are created")
		if released.size()==2:
			var separation: float = released[0].steering.body_radius(released[0])+released[1].steering.body_radius(released[1])
			check(released[0].position.distance_to(released[1].position)>=separation,"Death reinforcements do not overlap each other")
		check(game.enemy_count == count_before + 2,"Dying invoker releases two reinforcements")
		summoner.finish_death()
		check(game.enemy_count == count_before + 2,"Death reinforcements cannot be duplicated")
	var core = load("res://scenes/actors/enemy_16.tscn").instantiate()
	core.position = Vector3(4,.1,5)
	game.add_child(core)
	core.set_physics_process(false)
	var before: int = game.kills
	core.take_damage(100000)
	core.take_damage(45)
	check(not core.is_threat() and game.kills == before + 1,"Destroying the exposed core prevents resurrection")
	await close_game(game)
