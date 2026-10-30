extends Node
## Each sector owns its objective sequence; combat alone no longer completes it.
const Kit = preload("res://scripts/common/kit.gd")
const INTERACTABLE = preload("res://scripts/missions/mission_object.gd")
const Early = preload("res://scripts/missions/early_missions.gd")
const Late = preload("res://scripts/missions/late_missions.gd")
var early: Node3D
var doors: Node3D
const MISSION_VERSION := 4
const WAVE_SIZES := [3, 3]
const BRIEFS := [
	"Recupera la tarjeta y alcanza la salida", "Recupera dos suministros y activa la defensa",
	"Activa tres terminales y evacua antes de la sobrecarga", "Desactiva los controles de la fundición",
	"Destruye los tres nidos y elimina la amenaza central", "Desactiva las defensas y derrota al comandante",
	"Activa tres enlaces y protege la transmisión", "Carga combustible y asegura el embarque",
	"Recupera tres núcleos y asegura el arsenal", "Desactiva la energía y derrota al Guardián Áureo"
]
var game: Node3D
var objects: Array = []
var done: Array = []
var wave: int = 0
var wave_wait: float = -1
var wave_remaining: int = 0
var spawn_wait: float = 0
var nest_wait: float = 12
var timer: float = -1
var hint: Label
var announcement: String = ""
var boss_phase: int = 0
var objective_count: int = 0
var used_supplies: Array = []
var notification: Label
var notification_left: float = 0
var pickup_audio: AudioStreamPlayer
var defense_time: float = -1
var reinforcements_left: int = 0
var found_weapons: Array[String] = []
var found_grenades: Array[String] = []
var spawn_cells: Array[Vector3] = []
var previous_spawn := Vector3.INF
var tutorial_guide: Control
var tutorial_start := Vector3.ZERO
var tutorial_reloading: bool = false
var tutorial_reload_ammo: int = 0
var tutorial_reload_weapon: String = ""
var tutorial_reloaded: bool = false
var tutorial_switched: bool = false
var tutorial_grenade: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	game = get_parent()
	var ui: Control = game.get_node("HUD/Interface")
	hint = ui.get_node("MissionPanel/MissionSource")
	notification = ui.get_node("MissionNotification")
	pickup_audio = AudioStreamPlayer.new()
	pickup_audio.bus = &"Effects"
	pickup_audio.volume_db = -8
	pickup_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pickup_audio)
	if game.tutorial_mode:
		setup_tutorial()
		return
	var labels: Array
	# Older stage layouts are incompatible; retain the campaign, discard only
	# this sector's checkpoint before reading any player/enemy snapshots.
	if not game.tutorial_mode:
		var old: Dictionary = Campaign.profile().get("checkpoint", {})
		var version: int = MISSION_VERSION
		if int(old.get("level", -1)) == game.level_number and int(old.get("mission_version", 0)) != version:
			Campaign.profile().erase("checkpoint")
	migrate_sector_checkpoint()
	migrate_balance_checkpoint()
	match game.level_number:
		1: labels = ["TARJETA", "SALIDA"]
		2: labels = ["SUMINISTROS A", "SUMINISTROS B", "INICIAR DEFENSA", "TRANSPORTE"]
		3: labels = ["TERMINAL A", "TERMINAL B", "TERMINAL C", "EVACUACIÓN"]
		4: labels = ["CONTROL A", "CONTROL B", "CONTROL C", "SALIDA"]
		5: labels = ["NIDO A", "NIDO B", "NIDO C", "EXTRACCIÓN"]
		6: labels = ["DEFENSA A", "DEFENSA B", "ACCESO AL NÚCLEO"]
		7: labels = ["ENLACE A", "ENLACE B", "ENLACE C", "TRANSMISIÓN"]
		8: labels = ["COMBUSTIBLE A", "COMBUSTIBLE B", "INICIAR CARGA", "EMBARQUE"]
		9: labels = ["NÚCLEO A", "NÚCLEO B", "NÚCLEO C", "SALIDA DEL ARSENAL"]
		_: labels = ["ENERGÍA A", "ENERGÍA B", "ENERGÍA C", "SALIDA FINAL"]
	if game.level_number <= 3:
		labels = Early.PLANS[game.level_number].labels
	else:
		labels = Late.PLANS[game.level_number].labels
	var corners := [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]
	objective_count = labels.size()
	for index in range(labels.size()):
		var item := StaticBody3D.new()
		item.set_script(INTERACTABLE)
		item.mission = self
		item.object_id = index
		item.title = labels[index]
		item.destructible = game.level_number == 5 and index in [2,3,4]
		var placement := game.get_node_or_null("MissionPoints/Objective%d" % index)
		if game.level_number <= 3:
			item.position = reachable(Early.PLANS[game.level_number].points[index])
		else:
			item.position = reachable(Late.PLANS[game.level_number].points[index])
		game.get_node("Arena").get_parent().add_child(item)
		objects.append(item)
		var decoration := Node3D.new()
		game.add_child(decoration)
		decoration.position = item.position
		Kit.model(decoration, "Prop_Light_Wide", Vector3(2.0, 0.25, 0.3), Vector3(0, 3.8, 0))
		Kit.model(decoration, "Prop_Cable_1", Vector3(0.2, 2.5, 0.25), Vector3(1.5, 1.7, 0))
		Kit.model(decoration, "Prop_PipeHolder", Vector3(0.3, 0.4, 0.3), Vector3(1.5, 0.4, 0))
		Kit.model(decoration, "Prop_Vent_Small" if index % 2 == 0 else "Prop_Fan_Small", Vector3(0.6, 0.6, 0.25), Vector3(-1.2, 1.8, 0))
	# Local checkpoint belongs to the current profile and sector.
	var saved: Dictionary = Campaign.profile().get("checkpoint", {})
	if int(saved.get("level", -1)) == game.level_number:
		game.elapsed = maxf(0,float(saved.get("elapsed",0)))
		found_weapons.assign(saved.get("found_weapons", []))
		found_grenades.assign(saved.get("found_grenades", []))
		game.run_weapons.assign(found_weapons)
		done = saved.get("done", []).duplicate()
		wave = int(saved.get("wave", 0))
		wave_remaining = int(saved.get("remaining", 0))
		wave_wait = float(saved.get("wave_wait", -1))
		timer = float(saved.get("timer", -1))
		boss_phase = int(saved.get("boss_phase", 0))
		defense_time = float(saved.get("defense_time", -1))
		reinforcements_left = int(saved.get("reinforcements", 0))
		used_supplies = saved.get("supplies", []).duplicate()
		if saved.has("player"):
			game.player.restore_state(saved.player)
			restore_enemies(saved.get("enemies", []))
			game.kills = int(saved.get("kills", 0))
			game.enemy_count = int(saved.get("enemy_count", 0))
		for id in done:
			if int(id) < objects.size():
				objects[int(id)].deactivate()
	var placements := game.get_node_or_null("MissionPoints")
	if placements != null:
		for point in placements.get_children():
			if point.name.begins_with("Supply"):
				add_supply(point.position, "MUNICIÓN")
	else:
		add_supply(reachable(Vector3(-game.navigation_extent + 6, 0, -6)), "MUNICIÓN")
		add_supply(reachable(Vector3(game.navigation_extent - 6, 0, -game.navigation_extent + 6)), "MUNICIÓN")
	for item in objects:
		if used_supplies.has(item.object_id):
			item.deactivate()
	var weapon: String = {1: "rifle", 3: "shotgun", 6: "precision", 9: "plasma"}.get(game.level_number, "")
	if not weapon.is_empty() and not Campaign.available_weapons(game.level_number).has(weapon):
		add_weapon_pickup(weapon)
	if game.level_number == 10:
		var guardian = game.get_node_or_null("FinalBoss")
		if guardian != null:
			guardian.invulnerable = done.size() < boss_phase + 1
	if game.level_number == 6:
		var captain = game.get_node_or_null("FortressCaptain")
		if captain != null:
			captain.invulnerable = done.size() < 2
	build_spawn_cells()
	early = Node3D.new()
	early.set_script(Early if game.level_number <= 3 else Late)
	early.mission = self
	game.add_child(early)
	doors = Node3D.new()
	doors.name = "SectorDoors"
	doors.set_script(preload("res://scripts/missions/sector_doors.gd"))
	doors.mission = self
	game.add_child(doors)
	make_hazards()
	# Append discoveries after authored supplies so legacy supply IDs stay stable.
	var grenade: String = {2: "fragmentation", 5: "slow"}.get(game.level_number, "")
	if not grenade.is_empty() and not Campaign.available_grenades().has(grenade):
		add_grenade_pickup(grenade)
	var beacons := Control.new()
	beacons.set_script(preload("res://scripts/missions/objective_beacons.gd"))
	beacons.mission = self
	ui.add_child(beacons)
	build_spawn_cells()
	refresh()

func migrate_sector_checkpoint() -> void:
	var saved: Dictionary = Campaign.profile().get("checkpoint", {})
	if int(saved.get("level", -1)) != game.level_number or not game.level_number in [3,4,5,6] or int(saved.get("sector_revision", 0)) >= 1:
		return
	var completed: Array = saved.get("done", [])
	if game.level_number == 3 and completed.has(5):
		saved["timer"] = maxf(0, float(saved.get("timer", 120))) + 60
		saved["stage_started"] = false
	elif game.level_number == 4 and completed.size() == 6:
		saved["stage_started"] = false
	elif game.level_number == 5 and float(saved.get("defense_time", -1)) > 0:
		saved["defense_time"] = float(saved.defense_time) + 60
		saved["reinforcements"] = int(saved.get("reinforcements", 0)) + 2
	elif game.level_number == 6 and completed.size() >= 4:
		saved["done"] = [0,1,2,3]
		saved["stage_started"] = false
	for enemy in saved.get("enemies", []):
		var encounter: int = int(enemy.get("encounter", -1))
		if game.level_number == 3 and encounter == 6: enemy["encounter"] = 7
		if game.level_number == 6 and encounter >= 4: enemy["encounter"] = encounter + 2
	saved["sector_revision"] = 1

func migrate_balance_checkpoint() -> void:
	var saved: Dictionary = Campaign.profile().get("checkpoint", {})
	if int(saved.get("level", -1)) != game.level_number or int(saved.get("sector_revision", 0)) >= 2:
		return
	if game.level_number == 4 and float(saved.get("timer", -1)) > 0:
		saved["timer"] = float(saved.timer) + 60
	if game.level_number == 6 and saved.get("done", []).size() in [3,4,5]:
		# start_stage fills only the missing guards, preserving existing allies.
		saved["stage_started"] = false
	if game.level_number == 2:
		saved["wave"] = mini(int(saved.get("wave", 0)), WAVE_SIZES.size())
		saved["remaining"] = mini(int(saved.get("remaining", 0)), 3)
	saved["sector_revision"] = 2

func reachable(target: Vector3) -> Vector3:
	var best: Vector3 = game.player.position
	var cost := INF
	for x in range(-game.navigation_extent + 2, game.navigation_extent - 1):
		for z in range(-game.navigation_extent + 2, game.navigation_extent - 1):
			var point := Vector3(x, 0.1, z)
			var distance := point.distance_squared_to(target)
			if distance < cost and not game.grid.is_point_solid(Vector2i(x, z)) and game.route(point, game.player.position).size() > 1:
				best = point
				cost = distance
	return best

func add_supply(point: Vector3, title: String) -> void:
	var item := StaticBody3D.new()
	item.set_script(INTERACTABLE)
	item.mission = self
	item.object_id = -10 - used_supply_count()
	item.title = title
	item.position = reachable(point)
	game.add_child(item)
	objects.append(item)

func used_supply_count() -> int:
	var count := 0
	for item in objects:
		if item.object_id <= -10 and item.grenade_id.is_empty():
			count += 1
	return count

func interact_object(id: int) -> bool:
	if game.finished or get_tree().paused:
		return false
	if game.tutorial_mode:
		return tutorial_interact(id)
	if id <= -200:
		for item in objects:
			if item.object_id == id and item.active and not item.grenade_id.is_empty() and not found_grenades.has(item.grenade_id):
				found_grenades.append(item.grenade_id)
				game.log_event("grenade_found",{"object_id":id,"grenade":item.grenade_id})
				game.player.discover_grenade(item.grenade_id)
				game.update_hud()
				notify("GRANADA ENCONTRADA: %s\nCompleta la misión para conservarla · %s cambia el tipo" % [preload("res://scripts/combat/grenade_catalog.gd").DATA[item.grenade_id].title, key_name("grenade_cycle")], "weapon_unlock")
				checkpoint()
				return true
		return false
	if id <= -100:
		for item in objects:
			if item.object_id == id and item.active and not found_weapons.has(item.weapon_id):
				found_weapons.append(item.weapon_id)
				game.log_event("weapon_found",{"object_id":id,"weapon":item.weapon_id})
				game.player.discover_weapon(item.weapon_id)
				game.update_hud()
				notify("ARMA ENCONTRADA: %s\nCompleta la misión para conservarla" % game.player.Weapons.DATA[item.weapon_id].title, "weapon_unlock")
				checkpoint()
				return true
		return false
	if id < 0:
		var supply: Node
		for item in objects:
			if item.object_id == id and item.active:
				supply = item
		if supply == null or used_supplies.has(id):
			return false
		var receipt: String = game.player.resupply()
		used_supplies.append(id)
		game.log_event("supply_collected",{"object_id":id,"title":supply.title})
		game.update_hud()
		notify("MUNICIÓN RECOGIDA\n" + receipt, "pickup_ammo")
		checkpoint()
		return true
	if done.has(id):
		return false
	if early != null:
		return early.interact(id)
	if game.level_number == 10 and id < 3 and id > boss_phase:
		announcement = "Esta fuente se habilita en la siguiente fase del guardián"
		return false
	var final_id: int = objective_count - 1
	var is_final := id == final_id
	if is_final:
		if done.size() < final_id:
			announcement = "Completa primero los objetivos marcados"
			return false
		if game.level_number == 2 and (wave < WAVE_SIZES.size() or living_enemies() > 0 or wave_remaining > 0):
			announcement = "Resiste las dos oleadas"
			return false
		if game.level_number in [5, 6, 9, 10] and living_enemies() > 0:
			announcement = "Elimina las amenazas restantes"
			return false
		if game.level_number in [7, 8] and defense_time != 0:
			notify("Completa la defensa antes de extraerte", "")
			return false
		game.log_event("objective_completed",{"object_id":id,"final":true})
		game.end_game(true)
		return true
	done.append(id)
	if game.level_number == 6 and done.size() == 2:
		var captain = game.get_node_or_null("FortressCaptain")
		if captain != null:
			captain.invulnerable = false
			captain.update_title()
	if game.level_number in [2, 8] and id == 2:
		if not done.has(0) or not done.has(1):
			done.erase(id)
			announcement = "Recupera ambos suministros primero"
			return false
		if game.level_number == 2:
			wave_wait = 5
	game.log_event("objective_completed",{"object_id":id,"final":false})
	if game.level_number == 3 and done.size() == 3:
		timer = 90
	if game.level_number in [7, 8] and done.size() == final_id:
		defense_time = 45 if game.level_number == 7 else 60
		reinforcements_left = 6 if game.level_number == 7 else 8
		nest_wait = 5
	if game.level_number == 2 and id < 2:
		var receipt: String = game.player.resupply()
		game.update_hud()
		checkpoint()
		notify("SUMINISTROS RECUPERADOS\n" + receipt, "pickup_ammo")
		return true
	checkpoint()
	notify("TARJETA OBTENIDA · SALIDA HABILITADA" if game.level_number == 1 else "OBJETIVO COMPLETADO · CHECKPOINT", "pickup_key")
	return true

func checkpoint() -> void:
	if game.tutorial_mode:
		return
	var enemies: Array = []
	for enemy in game.get_children():
		if enemy is EnemyController and enemy.is_threat():
			enemies.append({"scene": enemy.scene_file_path, "name": str(enemy.name), "kind": enemy.kind, "position": enemy.position, "scale": enemy.scale, "health": enemy.health, "max_health": enemy.max_health, "damage": enemy.attack_damage, "speed": enemy.move_speed, "interval": enemy.attack_interval, "range": enemy.attack_range, "warning": enemy.warning_duration, "boss": enemy.boss, "encounter": enemy.encounter_stage, "alerted": enemy.alerted, "shield": enemy.shield_health})
			enemies.back()["enraged"] = enemy.boss_enraged
			enemies.back()["tactics"] = enemy.tactics.capture_state()
			enemies.back()["search"] = enemy.search.capture_state()
			enemies.back().merge({"slow_left": enemy.slow_left, "slow_factor": enemy.slow_factor})
			enemies.back().merge({"revived":enemy.has_revived,"revival_left":enemy.revival_left,"revival_core":enemy.revival_core,"standing_scale":enemy.standing_scale,"phase_left":enemy.phase_left,"phase_wait":enemy.phase_wait})
	Campaign.profile()["checkpoint"] = {"level": game.level_number, "elapsed": game.elapsed, "done": done.duplicate(), "found_weapons": found_weapons.duplicate(), "found_grenades": found_grenades.duplicate(), "wave": wave, "remaining": wave_remaining, "wave_wait": wave_wait, "timer": timer, "defense_time": defense_time, "reinforcements": reinforcements_left, "boss_phase": boss_phase, "supplies": used_supplies.duplicate(), "player": game.player.capture_state(), "enemies": enemies, "kills": game.kills, "enemy_count": game.enemy_count}
	if early != null:
		Campaign.profile().checkpoint.merge({"mission_version": MISSION_VERSION, "sector_revision": 2, "cargo": early.cargo, "stage_started": early.stage_started,"arena_sealed":doors.arena_sealed if doors != null else false})
	if early != null and early.get("defense") != null:
		Campaign.profile().checkpoint["hangar_defense"] = early.defense.capture_state()
	if early != null and early.get("delivery") != null:
		Campaign.profile().checkpoint["arsenal_delivery"] = early.delivery.capture_state()
	game.log_event("checkpoint_created",{"objectives":done.duplicate(),"supplies":used_supplies.duplicate(),"wave":wave})
	if not Campaign.save_data():
		announcement = Campaign.save_error

func restore_enemies(states: Array) -> void:
	for enemy in game.get_children():
		if enemy is EnemyController:
			game.remove_child(enemy)
			enemy.free()
	for state in states:
		var enemy = load(state.scene).instantiate()
		enemy.name = state.name
		enemy.position = state.position
		enemy.scale = state.scale
		enemy.kind = int(state.kind)
		enemy.max_health = int(state.max_health)
		enemy.attack_damage = int(state.damage)
		enemy.move_speed = float(state.speed)
		enemy.attack_interval = float(state.interval)
		enemy.attack_range = float(state.range)
		enemy.warning_duration = float(state.warning)
		enemy.boss = bool(state.boss)
		enemy.difficulty_applied = true
		enemy.encounter_stage = int(state.get("encounter", -1))
		enemy.alerted = bool(state.get("alerted", false))
		enemy.shield_health = int(state.get("shield", 70))
		enemy.boss_enraged = bool(state.get("enraged", false))
		enemy.slow_left = maxf(0, float(state.get("slow_left", 0)))
		enemy.slow_factor = clampf(float(state.get("slow_factor", 1)), .15, 1)
		enemy.has_revived = bool(state.get("revived",false))
		enemy.revival_left = float(state.get("revival_left",-1))
		enemy.revival_core = int(state.get("revival_core",45))
		enemy.phase_left = float(state.get("phase_left",-1))
		enemy.phase_wait = float(state.get("phase_wait",7))
		game.add_child(enemy)
		enemy.health = int(state.health)
		enemy.attack_damage = int(state.damage)
		enemy.standing_scale = state.get("standing_scale",enemy.scale)
		enemy.restore_special_visuals()
		enemy.tactics.restore_state(state.get("tactics", {}))
		enemy.search.restore_state(state.get("search", {}))
		enemy.tactics.restore_visuals(enemy)

func living_enemies() -> int:
	var count := 0
	for child in game.get_children():
		if child is EnemyController and child.is_threat():
			count += 1
	return count

func spawn_enemy(kind: int, origin: Vector3 = Vector3.INF) -> bool:
	kind = preload("res://scripts/enemies/enemy_catalog.gd").permitted(kind,game.level_number)
	var enemy = load("res://scenes/actors/enemy_%d.tscn" % kind).instantiate()
	var points := valid_spawn_points() if not origin.is_finite() else death_spawn_points(enemy,origin)
	if points.is_empty():
		enemy.free()
		return false
	enemy.position = points.pick_random() if not origin.is_finite() else game.to_local(points[0])
	previous_spawn = enemy.position
	enemy.max_health = 45 + wave * 12 + (kind % 6) * 4
	enemy.attack_damage = 4 + wave + (kind % 6)
	if game.level_number == 2 and wave == WAVE_SIZES.size() and wave_remaining == 1:
		enemy.max_health = 300
		enemy.attack_damage = 14
		enemy.move_speed = 1.5
	game.add_child(enemy)
	enemy.alerted = true
	game.enemy_count += 1
	game.log_event("enemy_spawned",{"enemy_id":str(enemy.get_instance_id()),"kind":kind,"wave":wave,"source":"death_summon" if origin.is_finite() else "reinforcement"})
	return true

func death_spawn_points(enemy: EnemyController, origin: Vector3) -> Array[Vector3]:
	# Stay at the corpse, spreading only enough to fit two living bodies safely.
	var candidates: Array[Vector3] = [origin]
	for radius in [.9,1.6,2.4,3.5,5.0]:
		for step in range(16):
			var angle := TAU*step/16.0
			candidates.append(origin+Vector3(cos(angle),0,sin(angle))*radius)
	var radius := .43
	for child in enemy.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			var scaled: Vector3 = child.shape.size*(game.global_transform*enemy.transform*child.transform).basis.get_scale().abs()
			radius = maxf(scaled.x,scaled.z)*.5
	var excluded: Array[RID] = []
	for actor in game.get_children():
		if actor is EnemyController and actor.health <= 0:
			excluded.append(actor.get_rid())
	for point in candidates:
		var local: Vector3 = game.to_local(point)
		var cell := Vector2i(roundi(local.x),roundi(local.z))
		if not game.grid.is_in_boundsv(cell) or game.grid.is_point_solid(cell):
			continue
		if not game.navigation_segment_clear(origin,point):
			continue
		var occupied := false
		for actor in game.get_children():
			if actor is CharacterBody3D and (not actor is EnemyController or actor.health > 0):
				if actor.global_position.distance_to(point) < radius+enemy.steering.body_radius(actor)+.2:
					occupied = true
		if occupied:
			continue
		for child in enemy.get_children():
			if not child is CollisionShape3D or child.disabled or child.shape == null:
				continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = child.shape
			query.transform = game.global_transform*enemy.transform*child.transform
			query.transform.origin += point-game.to_global(enemy.position)+Vector3.UP*.08
			query.collision_mask = 1
			query.exclude = excluded
			if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
				occupied = true
		if not occupied:
			return [point]
	return []

func _process(delta: float) -> void:
	if game.finished:
		return
	notification_left = maxf(0, notification_left - delta)
	notification.visible = notification_left > 0
	if defense_time > 0 and game.level_number != 8:
		defense_time = maxf(0, defense_time - delta)
		nest_wait -= delta
		if nest_wait <= 0 and reinforcements_left > 0 and living_enemies() < 8:
			var kind: int = [0,1,3,4,5,6][reinforcements_left % 6] if game.level_number <= 3 else Late.PLANS[game.level_number].kinds[reinforcements_left % 3]
			if spawn_enemy(kind):
				reinforcements_left -= 1
			nest_wait = 6
		if defense_time == 0:
			notify("DEFENSA COMPLETADA · DIRÍGETE A LA SALIDA", "pickup_key")
	if Input.is_action_just_pressed("interact"):
		if _uses_touch_controls():
			var touch_target := _touch_interaction_target()
			if is_instance_valid(touch_target):
				touch_target.interact()
		else:
			var ray := PhysicsRayQueryParameters3D.create(game.player.camera.global_position, game.player.camera.global_position - game.player.camera.global_basis.z * 3.5, 1, [game.player.get_rid()])
			var hit := game.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and hit.collider.has_method("interact"):
				hit.collider.interact()
	if game.tutorial_mode:
		process_tutorial()
		return
	if early != null and early.has_method("tick"):
		early.tick(delta)
	if timer > 0:
		timer -= delta
		if timer <= 0:
			game.end_game(false)
	if game.level_number == 2 and done.has(6):
		if wave_remaining > 0:
			spawn_wait -= delta
			if spawn_wait <= 0 and living_enemies() < 8:
				if spawn_enemy([0, 1, 2, 3][(wave_remaining + wave) % 4]):
					wave_remaining -= 1
				spawn_wait = 2
		elif living_enemies() == 0 and wave < WAVE_SIZES.size() and wave_wait < 0:
			wave_wait = 10
			var receipt: String = game.player.resupply()
			notify("REABASTECIMIENTO ENTRE OLEADAS\n" + receipt, "pickup_ammo")
			checkpoint()
		if wave_wait >= 0:
			wave_wait -= delta
			if wave_wait < 0 and wave < WAVE_SIZES.size():
				wave += 1
				game.log_event("wave_started",{"wave":wave})
				wave_remaining = WAVE_SIZES[wave - 1]
				spawn_wait = 2
				checkpoint()
	if game.level_number == 5 and early == null:
		nest_wait -= delta
		if nest_wait <= 0:
			nest_wait = 15
			if done.size() < 3 and living_enemies() < 8:
				spawn_enemy(0)
	if game.level_number == 10 and early == null:
		var boss = game.get_node_or_null("FinalBoss")
		if is_instance_valid(boss) and boss.health > 0:
			boss.invulnerable = done.size() < boss_phase + 1
			if boss.health <= boss.max_health * 0.66 and boss_phase == 0:
				boss_phase = 1
				boss.invulnerable = done.size() < 2
			if boss.health <= boss.max_health * 0.33 and boss_phase == 1:
				boss_phase = 2
				boss.attack_interval = 1.0
				boss.invulnerable = done.size() < 3
			boss.update_title()
	refresh()

func refresh() -> void:
	_update_touch_interaction_prompt()
	if early != null:
		hint.text = early.describe()
		return
	var extra := ""
	if game.level_number == 2 and done.has(2):
		extra = " · OLEADA %d/%d · enemigos %d" % [wave, WAVE_SIZES.size(), living_enemies() + wave_remaining]
		if wave_wait >= 0:
			extra += " · refuerzos en %ds" % ceili(wave_wait)
	if defense_time > 0:
		extra += " · DEFENSA %ds" % ceili(defense_time)
	if timer > 0:
		extra += " · EVACUACIÓN %ds" % ceili(timer)
	hint.text = "MISIÓN\n" + BRIEFS[game.level_number - 1] + extra
	var nearest: Node3D
	var distance := INF
	for item in objects:
		if not item.active or item.object_id < 0:
			continue
		if item.object_id == objective_count - 1 and done.size() < objective_count - 1:
			continue
		if game.level_number == 2 and item.object_id == 2 and done.size() < 2:
			continue
		if game.level_number == 10 and item.object_id > boss_phase and item.object_id < 3:
			continue
		var d: float = game.player.position.distance_to(item.position)
		if d < distance:
			nearest = item
			distance = d
	if nearest != null:
		hint.text += "\n%s · %dm · %s" % [nearest.title, roundi(distance), "DISPARA" if nearest.destructible else "Acércate, apunta y pulsa E"]
	for item in objects:
		if item.object_id < 0 and item.active and item.position.distance_to(game.player.position) < 4:
			hint.text += "\n" + item.title

func _uses_touch_controls() -> bool:
	return OS.get_name() in ["Android", "iOS"] or bool(Campaign.options.get("touch_debug", false))

func _touch_interaction_target() -> Node:
	if not _uses_touch_controls() or get_tree().paused or game.finished:
		return null
	var camera: Camera3D = game.player.camera
	var forward := -camera.global_basis.z
	var nearest: Node
	var nearest_distance := 3.5
	for item in objects:
		if not is_instance_valid(item) or not item.active or item.destructible:
			continue
		if item.object_id >= 0:
			if done.has(item.object_id):
				continue
			if early != null and item.object_id != int(early.get("stage")):
				continue
			var final_id := objective_count - 1
			if item.object_id == final_id and done.size() < final_id:
				continue
			if game.level_number == 2 and item.object_id == 2 and done.size() < 2:
				continue
			if game.level_number == 10 and item.object_id > boss_phase and item.object_id < 3:
				continue
		var target_point: Vector3 = item.global_position + Vector3.UP * 0.7
		var offset := target_point - camera.global_position
		var distance := offset.length()
		if distance > nearest_distance or distance <= 0.05 or forward.dot(offset / distance) < 0.55:
			continue
		var ray := PhysicsRayQueryParameters3D.create(camera.global_position, target_point, 1, [game.player.get_rid()])
		var hit := game.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.get("collider") != item:
			continue
		nearest = item
		nearest_distance = distance
	return nearest

func _update_touch_interaction_prompt() -> void:
	var touch_controls := game.get_node_or_null("HUD/Interface/TouchControls")
	if not is_instance_valid(touch_controls) or not touch_controls.has_method("set_interaction_prompt"):
		return
	touch_controls.set_interaction_prompt(is_instance_valid(_touch_interaction_target()))

func make_hazards() -> void:
	var points: Array = [Vector3(-7, .05, 0), Vector3(7, .05, 0)]
	if game.level_number <= 3:
		points = {1: [Vector3(20, .05, 8)], 2: [Vector3(-24, .05, -10), Vector3(24, .05, -10)], 3: [Vector3(-17, .05, 1), Vector3(17, .05, 1)]}[game.level_number]
	else:
		points = {4:[Vector3(-24,.05,-7),Vector3(24,.05,-7)],5:[Vector3(0,.05,-5)],6:[Vector3(-23,.05,0),Vector3(23,.05,0)],7:[Vector3(0,.05,4)],8:[Vector3(-24,.05,1),Vector3(24,.05,-12)],9:[Vector3(-21,.05,-14)],10:[Vector3(-20,.05,-10),Vector3(20,.05,-10)]}[game.level_number]
	for point in points:
		var hazard := Area3D.new()
		hazard.set_script(preload("res://scripts/missions/hazard.gd"))
		hazard.position = reachable(point)
		hazard.mission = self
		game.add_child(hazard)

func notify(message: String, sound: String = "pickup_key") -> void:
	announcement = message.replace("\n", " · ")
	notification.text = message
	notification_left = 3.5
	notification.show()
	if not sound.is_empty():
		pickup_audio.stream = load("res://assets/audio/%s.wav" % sound)
		pickup_audio.play()

func add_weapon_pickup(id: String) -> void:
	var item := StaticBody3D.new()
	item.set_script(INTERACTABLE)
	item.mission = self
	item.weapon_id = id
	item.object_id = -100 - game.level_number
	item.title = game.player.Weapons.DATA[id].title
	var marker := game.get_node_or_null("MissionPoints/WeaponPickup")
	item.position = marker.position if marker != null else reachable(Vector3(-12, 0, 0))
	game.add_child(item)
	objects.append(item)
	if found_weapons.has(id):
		item.deactivate()

func add_grenade_pickup(id: String) -> void:
	var item := StaticBody3D.new()
	item.set_script(INTERACTABLE)
	item.mission = self
	item.grenade_id = id
	item.object_id = -200 - game.level_number
	item.title = "GRANADA " + preload("res://scripts/combat/grenade_catalog.gd").DATA[id].title
	var marker := game.get_node_or_null("MissionPoints/GrenadePickup")
	if marker != null:
		# Keep authored discoveries inside rooms that are still mission-locked.
		item.position = marker.position
	else:
		marker = game.get_node_or_null("MissionPoints/Supply1")
		if marker == null:
			marker = game.get_node_or_null("MissionPoints/Objective1")
		item.position = reachable(marker.position + Vector3(2, 0, 0) if marker != null else Vector3(-12, 0, 0))
	game.add_child(item)
	objects.append(item)
	if found_grenades.has(id):
		item.deactivate()

func build_spawn_cells() -> void:
	spawn_cells.clear()
	for x in range(-game.navigation_extent + 2, game.navigation_extent - 1, 3):
		for z in range(-game.navigation_extent + 2, game.navigation_extent - 1, 3):
			if not game.grid.is_point_solid(Vector2i(x, z)):
				spawn_cells.append(Vector3(x, 0.1, z))

func valid_spawn_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	var candidates := spawn_cells.duplicate()
	candidates.shuffle()
	for point in candidates:
		if point.distance_to(game.player.position) < 12 or point.distance_to(previous_spawn) < 5:
			continue
		if game.route(point, game.player.position).size() < 2:
			continue
		var occupied := false
		for child in game.get_children():
			if child is EnemyController and child.health > 0 and child.position.distance_to(point) < 2.5:
				occupied = true
		for item in objects:
			if item.position.distance_to(point) < 2:
				occupied = true
		if not occupied:
			points.append(point)
		if points.size() >= 24:
			break
	return points

func setup_tutorial() -> void:
	objective_count = 4
	tutorial_start = game.player.position
	for i in range(4):
		var item := StaticBody3D.new()
		item.set_script(INTERACTABLE)
		item.mission = self
		item.object_id = i
		item.title = ["BALIZA DE MOVIMIENTO", "BLANCO DE TIRO", "BLANCO DE CUCHILLO", "SALIR DEL TUTORIAL"][i]
		item.destructible = i in [1, 2]
		item.health = 60
		item.position = game.get_node("MissionPoints/Objective%d" % i).position
		game.add_child(item)
		objects.append(item)
	add_supply(game.get_node("MissionPoints/Supply0").position, "MUNICIÓN DE PRÁCTICA")
	# Additional E exercises reuse the existing corridor and preserve old target IDs.
	for spec in [{"id":4,"title":"TERMINAL DE PRÁCTICA","point":Vector3(1.5,.1,4)},{"id":5,"title":"TARJETA","point":Vector3(-1.5,.1,-3)}]:
		var item := StaticBody3D.new()
		item.set_script(INTERACTABLE)
		item.mission = self
		item.object_id = spec.id
		item.title = spec.title
		item.position = reachable(spec.point)
		game.add_child(item)
		objects.append(item)
	for spec in [{"id":-103,"weapon":"shotgun","grenade":"","point":"Objective2","title":"ESCOPETA DE PRÁCTICA"},{"id":-205,"weapon":"","grenade":"fragmentation","point":"Objective3","title":"GRANADA DE PRÁCTICA"}]:
		var item := StaticBody3D.new()
		item.set_script(INTERACTABLE)
		item.mission = self
		item.object_id = spec.id
		item.weapon_id = spec.weapon
		item.grenade_id = spec.grenade
		item.title = spec.title
		item.position = game.get_node("MissionPoints/" + spec.point).position
		game.add_child(item)
		objects.append(item)
	tutorial_guide = preload("res://scenes/ui/tutorial_guide.tscn").instantiate()
	tutorial_guide.mission = self
	game.get_node("HUD/Interface").add_child(tutorial_guide)
	var beacons := Control.new()
	beacons.name = "TutorialBeacons"
	beacons.set_script(preload("res://scripts/missions/objective_beacons.gd"))
	beacons.mission = self
	game.get_node("HUD/Interface").add_child(beacons)

func key_name(action: String) -> String:
	return OS.get_keycode_string(int(Campaign.bindings.get(action, Campaign.DEFAULT_KEYS[action])))

func process_tutorial() -> void:
	if is_instance_valid(tutorial_guide):
		tutorial_guide.tick()

func tutorial_interact(id: int) -> bool:
	return is_instance_valid(tutorial_guide) and tutorial_guide.interact(id)
