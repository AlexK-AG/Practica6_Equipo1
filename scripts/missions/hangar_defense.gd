extends RefCounted
const Kit = preload("res://scripts/common/kit.gd")
const DURATION := 120.0
const MAX_HEALTH := 500
var late: Node3D
var mission: Node
var cargo: StaticBody3D
var health := MAX_HEALTH
var elapsed := 0.0
var next_spawn := 6.0
var started := false
var completed := false
var groups := 0
var health_label: Label3D

func setup(controller: Node3D) -> void:
	late = controller
	mission = late.mission
	var saved: Dictionary = mission.get_node("/root/Campaign").profile().get("checkpoint",{})
	if int(saved.get("level",-1)) == 8:
		var data: Dictionary = saved.get("hangar_defense",{})
		health = clampi(int(data.get("health",MAX_HEALTH)),0,MAX_HEALTH)
		started = bool(data.get("started",mission.done.has(5)))
		completed = bool(data.get("completed",started and mission.defense_time==0))
		elapsed = float(data.get("elapsed",maxf(0,60-mission.defense_time) if started and not completed else DURATION if completed else 0.0))
		next_spawn = float(data.get("next_spawn",6.0))
		groups = int(data.get("groups",0))
		if data.is_empty():
			while next_spawn <= elapsed:
				next_spawn += 6 if next_spawn < 60 else 7
		if started:
			mission.defense_time = 0 if completed else maxf(0,DURATION-elapsed)
	cargo = StaticBody3D.new()
	cargo.name = "DefenseCargo"
	cargo.set_script(preload("res://scripts/missions/defense_cargo.gd"))
	cargo.defense = self
	var marker: Node3D = mission.game.get_node_or_null("MissionPoints/DefenseCargo")
	cargo.position = marker.position if marker != null else Vector3(3,.1,-11)
	mission.game.get_node("Arena").add_child(cargo)
	Kit.model(cargo,"Prop_Crate4",Vector3(2.2,1.3,1.6),Vector3(0,.65,0),Color("82c9bd"))
	Kit.collider(cargo,Vector3(2.2,1.3,1.6),Vector3(0,.65,0))
	health_label = Label3D.new()
	health_label.position.y = 2.05
	health_label.font_size = 30
	health_label.pixel_size = .004
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cargo.add_child(health_label)
	refresh_label()
	for index in range(4):
		var point: Node3D = mission.game.get_node_or_null("MissionPoints/DefenseSupply%d" % index)
		mission.add_supply(point.position if point != null else Vector3(-7 if index%2==0 else 7,.1,-8 if index<2 else -16),"MUNICIÓN DE DEFENSA %d" % (index+1))
		var supply = mission.objects.back()
		if mission.used_supplies.has(supply.object_id):
			supply.deactivate()
	mission.game.build_navigation()

func active() -> bool:
	return started and not completed and health>0 and not mission.game.finished

func begin() -> void:
	started = true
	completed = false
	health = MAX_HEALTH
	elapsed = 0
	next_spawn = 6
	groups = 0
	mission.defense_time = DURATION
	mission.reinforcements_left = 0
	mission.game.log_event("cargo_defense_started",{"health":health,"duration_seconds":DURATION})
	refresh_label()

func tick(delta: float) -> void:
	if not active():
		return
	elapsed = minf(DURATION,elapsed+delta)
	# A batch uses one zone, never separate random rooms for its members.
	while next_spawn <= elapsed and next_spawn < DURATION:
		var count := 2 if next_spawn <= 60 else 3
		spawn_group(count)
		next_spawn += 6 if next_spawn < 60 else 7
	mission.defense_time = maxf(0,DURATION-elapsed)
	if mission.defense_time == 0:
		completed = true
		mission.game.log_event("cargo_defense_completed",{"health":health,"groups":groups})
		mission.notify("CARGA ASEGURADA · DEFENSA COMPLETADA\nDirígete al embarque","pickup_key")
		mission.checkpoint()
	refresh_label()

func spawn_group(count: int) -> void:
	var candidates: Array[Vector3] = mission.valid_spawn_points()
	if candidates.is_empty():
		return
	# Prefer the hangar itself and its open approaches, rather than remote rooms.
	var nearby: Array[Vector3] = []
	for candidate in candidates:
		if candidate.distance_to(cargo.position) <= 27:
			nearby.append(candidate)
	var anchor: Vector3 = (nearby if not nearby.is_empty() else candidates).pick_random()
	var spawned := 0
	for index in range(count):
		var kind: int = [9,12,16][(groups+index)%3]
		var enemy = load("res://scenes/actors/enemy_%d.tscn" % kind).instantiate()
		var locations: Array[Vector3] = mission.death_spawn_points(enemy,mission.game.to_global(anchor))
		if locations.is_empty():
			enemy.free()
			continue
		enemy.position = mission.game.to_local(locations[0])
		enemy.max_health = 45+(kind%6)*4
		enemy.attack_damage = 4+(kind%6)
		mission.game.add_child(enemy)
		enemy.alerted = true
		enemy.set_meta("cargo_attacker",true)
		mission.game.enemy_count += 1
		spawned += 1
		mission.game.log_event("enemy_spawned",{"enemy_id":str(enemy.get_instance_id()),"kind":kind,"source":"cargo_defense","group":groups+1})
	groups += 1
	mission.game.log_event("defense_group_spawned",{"group":groups,"enemies":spawned,"scheduled_seconds":next_spawn,"zone":[anchor.x,anchor.z]})

func damage(amount: int, context: Dictionary) -> void:
	if not active():
		return
	var applied := mini(health,maxi(0,amount))
	health -= applied
	mission.game.update_hud()
	mission.game.log_event("cargo_damaged",{"damage":applied,"health":health,"enemy_id":context.get("enemy_id","")})
	refresh_label()
	if health == 0:
		mission.game.log_event("cargo_destroyed")
		mission.notify("CARGA DESTRUIDA · MISIÓN FALLIDA","")
		mission.game.end_game(false)

func refresh_label() -> void:
	if is_instance_valid(health_label):
		health_label.text = "CARGA · %d / %d" % [health,MAX_HEALTH]
		health_label.modulate = Color("ed8e89") if health<=45 else Color("8ed7c6")

func capture_state() -> Dictionary:
	return {"health":health,"elapsed":elapsed,"next_spawn":next_spawn,"started":started,"completed":completed,"groups":groups}

func tick_enemy(enemy: CharacterBody3D, delta: float) -> bool:
	if not active() or enemy.boss or enemy.combat_role() in [2,4,5] or enemy.kind in [13,15]:
		return false
	if enemy.tactics.channel != "" or enemy.tactics.charge_state != "":
		return false
	# Nearby visible players can draw attackers away from the transport.
	if enemy.global_position.distance_to(mission.game.player.global_position)<6 and enemy.steering.clear_shot(enemy,mission.game.player.global_position):
		return false
	var target := cargo.global_position+Vector3.UP*.8
	var origin: Vector3 = enemy.global_position+Vector3.UP*enemy.steering.firing_height(enemy)
	var query := PhysicsRayQueryParameters3D.create(origin,target,1,[enemy.get_rid()])
	var hit: Dictionary = enemy.get_world_3d().direct_space_state.intersect_ray(query)
	var clear: bool = not hit.is_empty() and hit.collider==cargo
	var distance := origin.distance_to(target)
	var kamikaze: bool = enemy.combat_role()==3
	var stop_range := 2.8 if kamikaze else minf(12,enemy.attack_range*.7)
	var goal: Vector3 = approach(enemy,kamikaze,delta)
	if clear and distance<stop_range:
		goal = enemy.global_position
	var direction: Vector3 = enemy.steering.direction(enemy,goal,delta)
	var speed: float = enemy.move_speed*enemy.slow_factor*(1.25 if kamikaze else 1.0)
	enemy.velocity.x = direction.x*speed
	enemy.velocity.z = direction.z*speed
	enemy.velocity.y -= 22*delta
	enemy.move_and_slide()
	var facing := Vector3(target.x,enemy.global_position.y,target.z)
	if enemy.global_position.distance_to(facing)>.1:
		enemy.look_at(facing,Vector3.UP,true)
	enemy.attack_time -= delta
	enemy.tactics.enraged_left = maxf(0,enemy.tactics.enraged_left-delta)
	enemy.tactics.burst_pause = maxf(0,enemy.tactics.burst_pause-delta)
	if clear and distance < (3.2 if kamikaze else enemy.attack_range) and enemy.attack_time<=0 and enemy.tactics.burst_pause<=0:
		if enemy.warning_left < 0 and enemy.warning_duration>0:
			enemy.warning_left = enemy.warning_duration
			enemy.title.text = "¡ATACANDO LA CARGA!"
		elif enemy.warning_left<=0 or enemy.warning_duration<=0:
			enemy.warning_left = -1
			enemy.get_node("Shot").play()
			mission.game.beam(origin,hit.position,enemy.Catalog.ENTRIES[enemy.kind].color)
			cargo.take_damage(enemy.ranged_damage(distance)*(2 if kamikaze else 1),{"source":"enemy","enemy_id":str(enemy.get_instance_id())})
			enemy.attack_time = enemy._attack_delay()
			enemy.tactics.on_shot(enemy)
			if kamikaze:
				enemy.take_damage(enemy.max_health*10)
	if enemy.warning_left>=0:
		enemy.warning_left = maxf(0,enemy.warning_left-delta)
	return true

func approach(enemy: CharacterBody3D, kamikaze: bool, delta: float) -> Vector3:
	var wait: float = float(enemy.get_meta("cargo_route_wait",0.0))-delta
	if wait>0 and enemy.has_meta("cargo_route_goal"):
		enemy.set_meta("cargo_route_wait",wait)
		return enemy.get_meta("cargo_route_goal")
	var best: Vector3 = enemy.global_position
	var cost := INF
	for radius in ([2.5,3.0,4.0] if kamikaze else [5.0,9.0,13.0]):
		for step in range(12):
			var angle := TAU*step/12
			var point: Vector3 = cargo.global_position+Vector3(cos(angle)*radius,0,sin(angle)*radius)
			point.y = enemy.global_position.y
			if not enemy.search.standable(enemy,point) or mission.game.pursuit_route(enemy.global_position,point).is_empty():
				continue
			var origin: Vector3 = point+Vector3.UP*enemy.steering.firing_height(enemy)
			var hit: Dictionary = enemy.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,cargo.global_position+Vector3.UP*.8,1,[enemy.get_rid()]))
			if hit.is_empty() or hit.collider!=cargo:
				continue
			var score: float = point.distance_squared_to(enemy.global_position)
			if score<cost:
				cost = score
				best = point
	enemy.set_meta("cargo_route_goal",best)
	enemy.set_meta("cargo_route_wait",1.0)
	return best
