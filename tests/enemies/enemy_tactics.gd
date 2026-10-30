extends SceneTree
const Tactics = preload("res://scripts/enemies/enemy_tactics.gd")
var failures := 0

class MissionFixture extends Node:
	var population: int = 3
	var spawned: Array[int] = []
	func living_enemies() -> int:
		return population
	func spawn_enemy(kind: int) -> bool:
		spawned.append(kind)
		population += 1
		return true

class Arena extends Node3D:
	var level_number: int = 6
	var finished: bool = false
	var player: CharacterBody3D
	var mission: MissionFixture
	var beams: int = 0
	func route(from: Vector3,to: Vector3) -> PackedVector2Array:
		if absf(to.x)>40 or absf(to.z)>40:
			return PackedVector2Array()
		return PackedVector2Array([Vector2(from.x,from.z),Vector2(to.x,to.z)])
	func pursuit_route(from: Vector3,to: Vector3) -> PackedVector2Array:
		return route(from,to)
	func navigation_segment_clear(from: Vector3,to: Vector3,_radius: float=0) -> bool:
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from+Vector3.UP,to+Vector3.UP,1))
		return hit.is_empty()
	func beam(_from: Vector3,_to: Vector3,_color: Color) -> void:
		beams += 1
	func enemy_killed() -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func add_enemy(arena: Arena, kind: int, point: Vector3):
	var enemy = load("res://scenes/actors/enemy_0.tscn").instantiate()
	enemy.kind = kind
	enemy.name = "Kind%d_%d" % [kind,arena.get_child_count()]
	enemy.position = point
	enemy.set_physics_process(false)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.alerted = true
	return enemy

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	root.get_node("Campaign").save_path = "res://.godot/tactics-private.cfg"
	var arena := Arena.new()
	root.add_child(arena)
	arena.player = CharacterBody3D.new()
	arena.player.collision_layer = 1
	arena.add_child(arena.player)
	arena.player.position = Vector3(0,.1,-18)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = .4
	shape.shape = capsule
	shape.position.y = .9
	arena.player.add_child(shape)
	arena.mission = MissionFixture.new()
	arena.add_child(arena.mission)
	var subject = add_enemy(arena,0,Vector3(0,.1,0))
	var ally = add_enemy(arena,0,Vector3(6,.1,0))
	await physics_frame
	for kind in range(18):
		subject.kind = kind
		var tactics = Tactics.new()
		tactics.tick(subject,.1)
		var goal: Vector3 = tactics.movement_goal(subject,arena.player.position,true)
		check(goal.is_finite(), "Finite movement intent kind %d" % kind)
		check(tactics.speed_multiplier(subject)>=0, "Nonnegative speed kind %d" % kind)
		var restored = Tactics.new()
		restored.restore_state(tactics.capture_state())
		check(restored.shots == tactics.shots and restored.last_seen == tactics.last_seen, "State round trip kind %d" % kind)
	# Invisible alert seed keeps investigating after short attack-memory expiry.
	subject.kind = 0
	var search = Tactics.new()
	search.visible_cache = false
	search.sense_wait = 20
	search.tick(subject,.1)
	var original: Vector3 = search.last_seen
	arena.player.position += Vector3(8,0,0)
	search.tick(subject,6)
	check(search.movement_goal(subject,arena.player.position,false)==original, "Hidden player does not update communicated search point")
	# Patient priority and explicit channel interruption.
	arena.player.position = Vector3(0,.1,-18)
	subject.kind = 4
	ally.health = int(ally.max_health*.3)
	var healing = Tactics.new()
	healing.ability_cooldown = 0
	healing.tick(subject,.1)
	check(healing.channel == "heal" and healing.ally_name == str(ally.name), "Healer channels most injured visible ally")
	check(not healing.allow_attack(subject) and healing.speed_multiplier(subject)==0, "Channel forbids firing and movement")
	var health: int = ally.health
	healing.on_damaged(subject)
	healing.tick(subject,1)
	check(ally.health == health and healing.channel == "", "Damage interrupts healing")
	healing.ability_cooldown = 0
	healing.tick(subject,.1)
	healing.tick(subject,1)
	check(ally.health > health and arena.beams > 0, "Visible healing completes")
	healing.ability_cooldown = 0
	ally.health = int(ally.max_health*.3)
	healing.tick(subject,.1)
	var wall := StaticBody3D.new()
	arena.add_child(wall)
	preload("res://scripts/common/kit.gd").collider(wall,Vector3(.4,3,3),Vector3(3,1,0))
	await physics_frame
	var interrupted_health: int = ally.health
	healing.tick(subject,1)
	check(healing.channel=="" and ally.health==interrupted_health, "Wall/LOS interrupts visible heal channel")
	wall.queue_free()
	await physics_frame
	var mobile = Tactics.new()
	subject.kind = 10
	mobile.previous_patient = str(ally.name)
	check(mobile.choose_patient(subject)==ally, "Mobile healer still prioritizes critical patient")
	# Both healing supports stay behind a healthy frontline too.
	ally.health = ally.max_health
	for kind in [4,10]:
		subject.kind = kind
		var rear = Tactics.new()
		check(rear.rear_ally(subject,arena.player.position)==ally,"Healthy frontline still anchors healer formation")
		var goal: Vector3 = rear.movement_goal(subject,arena.player.position,true)
		var away: Vector3 = (ally.position-arena.player.position).normalized()
		check((goal-ally.position).dot(away)>1.5,"Healer destination stays behind its ally relative to threat")
		check(goal.distance_to(ally.position)<6,"Rear formation remains within healing reach")
	# Capped summoning, pressure pool and cancellation.
	subject.kind = 5
	var summoner = Tactics.new()
	summoner.ability_cooldown = 0
	summoner.tick(subject,.1)
	check(summoner.channel == "summon", "Announced summon channel starts")
	summoner.on_damaged(subject)
	summoner.tick(subject,2)
	check(arena.mission.spawned.is_empty(), "Interrupt prevents summon")
	summoner.ability_cooldown = 0
	summoner.tick(subject,.1)
	summoner.tick(subject,2)
	check(arena.mission.spawned.size()==1, "Summon completes once")
	arena.mission.population = 24
	summoner.ability_cooldown = 0
	summoner.tick(subject,.1)
	check(summoner.channel == "", "Population cap blocks summon")
	arena.mission.population = 3
	# Colossus relay damage prevents completion; interrupted checkpoint resumes.
	subject.kind = 11
	var heavy = Tactics.new()
	heavy.ability_cooldown = 0
	heavy.tick(subject,.1)
	check(is_instance_valid(heavy.deployment), "Destructible heavy relay created")
	if is_instance_valid(heavy.deployment):
		heavy.deployment.health = 43
		var saved: Dictionary = heavy.capture_state()
		heavy.deployment.take_damage(1000)
		heavy.tick(subject,.1)
		check(heavy.channel == "", "Destroy relay cancels reinforcement")
		await process_frame
		var resumed = Tactics.new()
		resumed.restore_state(saved)
		resumed.restore_visuals(subject)
		check(is_instance_valid(resumed.deployment) and resumed.deployment.health==43, "Relay health/channel restored")
		resumed.cancel_channel(subject)
	# Fixed charge direction, burst pauses and timed resurrection buff.
	subject.kind = 9
	arena.player.position = Vector3(0,.1,-10)
	await physics_frame
	var runner = Tactics.new()
	runner.ability_cooldown = 0
	runner.visible_cache = true
	runner.sense_wait = 3
	runner.has_memory = true
	runner.last_seen = arena.player.position
	runner.tick(subject,.1)
	var direction: Vector3 = runner.committed_direction()
	arena.player.position.x += 5
	runner.tick(subject,.9)
	check(runner.is_committed_charge() and runner.committed_direction()==direction, "Charge does not home onto dodging player")
	subject.kind = 12
	var suppression = Tactics.new()
	suppression.last_seen = Vector3(0,.1,-18)
	suppression.has_memory = true
	suppression.memory_left = 3
	check(suppression.attack_point(subject,arena.player.position,false)==Vector3(0,.1,-18), "Suppression aims at last seen ground point")
	for shot in range(4):
		suppression.on_shot(subject)
	check(not suppression.allow_attack(subject), "Suppression burst has pause")
	subject.kind = 16
	var revenant = Tactics.new()
	revenant.on_revived(subject)
	check(revenant.speed_multiplier(subject)>1 and revenant.attack_interval_multiplier(subject)<1, "Revival grants temporary aggression")
	revenant.tick(subject,8)
	check(is_equal_approx(revenant.speed_multiplier(subject),1), "Revival bonus expires")
	# Blink destination exists before phase and survives checkpoint restoration.
	subject.kind = 17
	subject.phase_wait = .9
	var blink = Tactics.new()
	blink.tick(subject,.1)
	check(blink.pending_blink and is_instance_valid(blink.blink_marker), "Blink destination telegraphed before phase")
	var pending: Vector3 = blink.blink_goal
	check(pending.distance_to(subject.position)>1, "Blink announces a distinct safe lateral destination")
	var restored_blink = Tactics.new()
	restored_blink.restore_state(blink.capture_state())
	check(restored_blink.blink_goal==pending, "Blink checkpoint preserves announced destination")
	check(blink.blink_destination(subject)==pending, "Blink reuses announced destination")
	# Explicit intent checks for the remaining authored subtype distinctions.
	subject.position = Vector3(0,.1,0)
	ally.position = Vector3(6,.1,0)
	ally.health = ally.max_health
	var support = add_enemy(arena,4,Vector3(6,.1,3))
	support.health = support.max_health
	await physics_frame
	var known := Vector3(0,.1,-10)
	subject.kind = 0
	arena.player.position = known
	await physics_frame
	var scout = Tactics.new()
	check(scout.movement_goal(subject,known,true)==subject.position, "Explorer holds a newly acquired lane instead of immediately abandoning it")
	scout.on_shot(subject)
	scout.tick(subject,1.0)
	var scout_goal: Vector3 = scout.movement_goal(subject,known,true)
	check(absf(scout_goal.x-subject.position.x)>1 and scout_goal!=known, "Explorer changes nearby firing position after completing a shot")
	var restored_scout = Tactics.new()
	restored_scout.restore_state(scout.capture_state())
	check(restored_scout.scout_shots_at_hold==scout.scout_shots_at_hold and restored_scout.scout_hold_until==scout.scout_hold_until, "Explorer firing hold survives checkpoint restoration")
	for tank_kind in [2,13]:
		subject.kind = tank_kind
		var escort = Tactics.new()
		escort.has_memory = true
		escort.last_seen = known
		var interception: Vector3 = escort.movement_goal(subject,known,false)
		var toward: Vector3 = (known-support.position).normalized()
		check((interception-support.position).dot(toward)>1 and interception.distance_to(support.position)<4, "Tank/shield escort interposes ahead of support kind %d" % tank_kind)
	subject.kind = 1
	var sniper = Tactics.new()
	var distant := Vector3(0,.1,-26)
	check(sniper.movement_goal(subject,distant,true)==subject.position, "Stationary sniper waits at firing range")
	sniper.goal_left = 2
	sniper.on_shot(subject)
	check(sniper.goal_left>0, "Sniper does not move after only one shot")
	sniper.on_shot(subject)
	check(sniper.goal_left==0 and sniper.movement_goal(subject,distant,true)!=subject.position, "Sniper relocates after two shots")
	subject.kind = 7
	var watch = Tactics.new()
	watch.goal_left = 2
	watch.on_shot(subject)
	check(watch.goal_left==0 and watch.movement_goal(subject,distant,true)!=subject.position, "Mobile sniper relocates after one shot")
	ally.position = Vector3(2,.1,-8)
	await physics_frame
	subject.kind = 6
	var predator = Tactics.new()
	var flank: Vector3 = predator.movement_goal(subject,distant,true)
	check(flank.z < subject.position.z and absf(flank.x)>1 and flank.distance_to(distant)<subject.position.distance_to(distant), "Predator flanks with forward progress while ally distracts")
	subject.kind = 8
	var guardian = Tactics.new()
	var anchor: Vector3 = guardian.movement_goal(subject,distant,true)
	ally.position.x += 3
	check(guardian.movement_goal(subject,known,true)==anchor, "Guardian holds cached anchor despite moving group")
	guardian.tick(subject,1)
	check(guardian.anchor_left>0 and guardian.movement_goal(subject,known,true)==anchor, "Guardian anchor remains stable during four-second hold")
	# A new critically injured patient should outrank a recently healed ally.
	ally.position = Vector3(6,.1,0)
	ally.health = int(ally.max_health*.8)
	support.health = int(support.max_health*.15)
	await physics_frame
	subject.kind = 10
	var mobile_switch = Tactics.new()
	mobile_switch.previous_patient = str(ally.name)
	check(mobile_switch.choose_patient(subject)==support, "Mobile healer switches to more severely injured patient")
	subject.kind = 14
	var runner_burst = Tactics.new()
	runner_burst.on_shot(subject)
	runner_burst.on_shot(subject)
	check(runner_burst.allow_attack(subject) and runner_burst.attack_interval_multiplier(subject)<1, "Runner burst allows first two fast shots")
	runner_burst.on_shot(subject)
	check(not runner_burst.allow_attack(subject) and runner_burst.burst_pause>0, "Runner pauses after exactly three shots")
	var shift: Vector3 = runner_burst.movement_goal(subject,distant,true)
	check(absf(shift.x-subject.position.x)>1, "Runner shifts laterally during burst pause")
	subject.kind = 15
	var bastion = Tactics.new()
	var before_links := arena.beams
	bastion.tick(subject,.1)
	check(arena.beams>before_links, "Bastion renders links to visible nearby allies")
	var group_goal: Vector3 = bastion.movement_goal(subject,distant,true)
	check(group_goal.distance_to(ally.position)<subject.position.distance_to(ally.position), "Bastion moves toward allied group center")
	subject.kind = 12
	subject.boss = true
	var boss_tactics = Tactics.new()
	check(boss_tactics.allow_attack(subject) and boss_tactics.attack_interval_multiplier(subject)==1, "Boss ignores subtype suppression gates and burst scaling")
	check(boss_tactics.attack_point(subject,distant,false)==distant, "Boss aiming stays controlled by boss controller")
	arena.queue_free()
	await process_frame
	await process_frame
	print("ENEMY TACTICS: %d failures" % failures)
	quit(0 if failures==0 else 1)
