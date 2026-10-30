extends RefCounted
## Deterministic campaign traversal: exercises objective transitions, wave spawns
## and boss shields without depending on human aiming or wall-clock combat.
static func clear_enemies(game: Node) -> void:
	# A second pass also defeats the pair released by dying invokers.
	for pass_index in range(2):
		for enemy in game.get_children():
			if enemy is EnemyController:
				enemy.set_physics_process(false)
				if not enemy.boss:
					enemy.phase_left = -1
					enemy.take_damage(100000)
					enemy.take_damage(100000)

static func complete(game: Node) -> Array[int]:
	var wave_sizes: Array[int] = []
	if game.has_node("LoadoutScreen"):
		game.get_node("LoadoutScreen").accept()
	var mission = game.mission
	mission.set_process(false)
	game.set_pause(false)
	for item in mission.objects:
		if (not item.weapon_id.is_empty() or not item.grenade_id.is_empty()) and item.active:
			item.interact()
	for id in range(mission.objective_count - 1):
		clear_enemies(game)
		if game.level_number == 7 and id == 5:
			mission._process(46.0)
			clear_enemies(game)
		mission.interact_object(id)
		mission.objects[id].deactivate()
		if game.level_number == 10 and id in [2,3,4]:
			var boss = game.get_node("FinalBoss")
			mission.early.update_effects()
			boss.take_damage(100000)
			mission.early.update_effects()
	clear_enemies(game)
	if game.level_number == 2:
		for tick in range(180):
			var previous_wave: int = mission.wave
			mission._process(3.0)
			if mission.wave > previous_wave:
				wave_sizes.append(mission.wave_remaining)
			clear_enemies(game)
			if mission.wave >= mission.WAVE_SIZES.size() and mission.wave_remaining == 0:
				break
	if game.level_number in [5, 7, 8]:
		mission._process(121.0 if game.level_number==8 else (91.0 if game.level_number==5 else 61.0))
		clear_enemies(game)
	mission.interact_object(mission.objective_count - 1)
	return wave_sizes
