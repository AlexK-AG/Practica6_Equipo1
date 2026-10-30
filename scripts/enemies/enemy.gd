class_name EnemyController
extends CharacterBody3D

const Kit = preload("res://scripts/common/kit.gd")
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")
const Steering = preload("res://scripts/enemies/enemy_steering.gd")
const Tactics = preload("res://scripts/enemies/enemy_tactics.gd")
const Search = preload("res://scripts/enemies/enemy_search.gd")
var steering = Steering.new()
var tactics = Tactics.new()
var search = Search.new()
const TYPES = [
	{"name": "Explorador", "model": "Alien_Cyclop", "hp": 50, "damage": 6, "speed": 2.5, "color": Color("5ce5bf"), "size": 1.2},
	{"name": "Acechador", "model": "Alien_Scolitex", "hp": 75, "damage": 9, "speed": 2.8, "color": Color("ebc65d"), "size": 1.4},
	{"name": "Centinela", "model": "Alien_Oculichrysalis", "hp": 100, "damage": 12, "speed": 1.5, "color": Color("75baff"), "size": 1.6},
	{"name": "Asaltante", "model": "Alien_Cyclop", "hp": 125, "damage": 15, "speed": 2.0, "color": Color("f38757"), "size": 1.8},
	{"name": "Devastador", "model": "Alien_Scolitex", "hp": 150, "damage": 18, "speed": 1.2, "color": Color("d981f1"), "size": 2.0},
	{"name": "Comandante", "model": "Alien_Oculichrysalis", "hp": 200, "damage": 22, "speed": 0.9, "color": Color("f36483"), "size": 2.3},
	{"name": "Depredador", "model": "Alien_Cyclop", "hp": 175, "damage": 20, "speed": 3.1, "color": Color("c4ff52"), "size": 1.65},
	{"name": "Vigía", "model": "Alien_Cyclop", "hp": 65, "damage": 8, "speed": 2.4, "color": Color("40d9ff"), "size": 1.3},
	{"name": "Guardián", "model": "Alien_Oculichrysalis", "hp": 140, "damage": 16, "speed": 1.4, "color": Color("ffa344"), "size": 1.9},
	{"name": "Cazador", "model": "Alien_Scolitex", "hp": 90, "damage": 11, "speed": 3.0, "color": Color("afff64"), "size": 1.5},
	{"name": "Espectro", "model": "Alien_Scolitex", "hp": 110, "damage": 14, "speed": 3.2, "color": Color("ad8dff"), "size": 1.6},
	{"name": "Coloso", "model": "Alien_Cyclop", "hp": 225, "damage": 24, "speed": 0.8, "color": Color("ff6475"), "size": 2.5},
	{"name": "Núcleo", "model": "Alien_Oculichrysalis", "hp": 250, "damage": 26, "speed": 1.0, "color": Color("fff085"), "size": 2.4}
]
var game: Node3D
@export_range(0, 17) var kind: int = 0
@export var encounter_stage: int = -1
var alerted: bool = false
var home_position := Vector3.ZERO
var patrol_clock: float = 0
var shield_health: int = 70
var shield_visual: MeshInstance3D
var difficulty_applied: bool = false
var boss_enraged: bool = false
var discovery_wait: float = 0
var has_revived: bool = false
var revival_left: float = -1
var revival_core: int = 45
var standing_scale := Vector3.ONE
var standing_title_height: float = 1.95
var phase_left: float = -1
var phase_wait: float = 7
@export var max_health: int = 50
@export var attack_damage: int = 6
@export var move_speed: float = 2.5
@export var attack_interval: float = 2.4
@export var attack_range: float = 15.0
@export var warning_duration: float = 0.0
@export var boss: bool = false
var warning_left: float = -1.0
var health: int
var attack_time: float = 2.5
var path_time: float = 0
var path := PackedVector2Array()
var title: Label3D
var invulnerable: bool = false
var ability_wait: float = 6.0
var stuck_wait: float = 0
var previous_position: Vector3
var death_committed: bool = false
var slow_left: float = 0
var slow_factor: float = 1
const ROLES := ["ASALTANTE", "FRANCOTIRADOR", "TANQUE", "KAMIKAZE", "SOPORTE", "INVOCADOR"]

func _ready() -> void:
	game = get_parent()
	steering.setup(self)
	apply_difficulty()
	health = max_health
	standing_scale = scale
	attack_time = attack_interval
	title = $Title
	standing_title_height = title.position.y
	previous_position = position
	home_position = position
	if kind >= 13:
		for child in get_children():
			if child is MeshInstance3D:
				child.material_override = Kit.material(Catalog.ENTRIES[kind].color)
	if kind == 13:
		shield_visual = Kit.model(self, "Prop_AccessPoint", Vector3(1.2, 1.55, 0.12), Vector3(0, 0.85, 0.55), Color("54e6ff"))
	elif kind == 15:
		Kit.model(self, "Prop_ItemHolder", Vector3(0.6, 0.5, 0.6), Vector3(0, 1.6, 0), Color("d49bff"))
	elif kind in [16,17]:
		Kit.model(self,"Prop_ItemHolder",Vector3(.4,.4,.4),Vector3(0,1.3,.3),Catalog.ENTRIES[kind].color)
	add_role_details()
	preload("res://scripts/visuals/combat_visuals.gd").enemy(self,kind)
	if combat_role() == 1:
		attack_range = maxf(attack_range, 38)
		var sector: int = int(game.get("level_number")) if game.get("level_number") != null else 1
		warning_duration = maxf(warning_duration, maxf(.7,1.1 - maxf(0,sector - 3) * .04))
	elif combat_role() == 4:
		ability_wait = 2.1
	update_title()

func update_title() -> void:
	title.text = "%s\n%d PV · %s" % [("GUARDIÁN ÁUREO" if boss else Catalog.ENTRIES[kind].name), health, "ESCUDO ACTIVO" if invulnerable else Catalog.ENTRIES[kind].role.to_upper()]
	if kind == 13 and shield_health > 0:
		title.text += " · ESCUDO %d" % shield_health
	if shield_visual != null:
		shield_visual.visible = shield_health > 0
	if revival_left >= 0:
		title.text = "REANIMACIÓN %ds · NÚCLEO %d\nDISPARA PARA IMPEDIRLA" % [ceili(revival_left),revival_core]
	elif kind == 16 and tactics.enraged_left > 0:
		title.text += " · SOBRECARGA %ds" % ceili(tactics.enraged_left)
	elif kind == 17 and phase_wait < .8:
		title.text = "¡DESFASE INMINENTE!"

func apply_difficulty() -> void:
	if difficulty_applied:
		return
	var modifiers: Dictionary = Catalog.DIFFICULTY[clampi(int(get_node("/root/Campaign").options.difficulty), 0, 2)]
	var tuning: Vector3 = Catalog.TUNING[kind]
	var sector: int = int(game.get("level_number")) if game.get("level_number") != null else 1
	var progression := maxf(0,sector - 1)
	if not boss:
		var durability: float = {2:1.6,8:1.85,11:1.4,13:1.15,15:1.15}.get(kind,1.0)
		max_health = roundi(max_health * durability)
	max_health = maxi(1, roundi(max_health * float(modifiers.health)))
	attack_damage = maxi(1, roundi(attack_damage * tuning.x * (1.0 + .045 * progression) * modifiers.damage))
	if combat_role() == 1:
		attack_damage = ceili(attack_damage * 1.45)
	move_speed = minf(4.6,lerpf(move_speed,tuning.y,.7) * (1.0 + .018 * progression) * modifiers.movement)
	attack_interval = maxf(.48,attack_interval * .78 / (tuning.z * (1.0 + .03 * progression) * modifiers.attack))
	difficulty_applied = true

func add_role_details() -> void:
	var color: Color = Catalog.ENTRIES[kind].color
	var role := combat_role()
	if kind >= 13:
		return
	if role == 1:
		Kit.box(self,Vector3(.12,.12,.35),Vector3(.3,1.2,.4),color,true)
	elif role == 2:
		for side in [-1,1]:
			Kit.model(self,"Prop_PipeHolder",Vector3(.35,.6,.3),Vector3(side * .55,1,.05),color)
	elif role == 3:
		Kit.model(self,"Prop_Barrel_Large",Vector3(.35,.6,.35),Vector3(0,.8,-.4),color)
	elif role == 4:
		Kit.box(self,Vector3(.5,.12,.12),Vector3(0,1.45,.2),color,true)
		Kit.box(self,Vector3(.12,.4,.12),Vector3(0,1.45,.2),color,true)
	elif role == 5:
		Kit.model(self,"Prop_Cable_1",Vector3(.16,.9,.16),Vector3(0,1.7,-.15),color)

func combat_role() -> int:
	return {13: 2, 14: 0, 15: 4,16:0,17:0}.get(kind, kind % 6)

func is_threat() -> bool:
	return health > 0 or revival_left >= 0

func restore_special_visuals() -> void:
	scale = standing_scale * (Vector3(1,.25,1) if revival_left >= 0 else Vector3.ONE)
	title.scale = Vector3(1,4,1) if revival_left >= 0 else Vector3.ONE
	title.position.y = standing_title_height * (4 if revival_left >= 0 else 1)
	collision_layer = 0 if phase_left >= 0 else 1
	for child in get_children():
		if child is MeshInstance3D and child.name != "BlinkDestination":
			child.visible = phase_left < 0
	title.visible = phase_left < 0
	update_title()

func finish_death() -> void:
	if death_committed:
		return
	death_committed = true
	health = 0
	revival_left = -1
	if not boss and combat_role() == 5 and is_instance_valid(game.mission) and not game.finished:
		for index in range(2):
			game.mission.spawn_enemy(summon_pool().pick_random(),global_position)
	_event("enemy_killed",{"enemy_id":str(get_instance_id()),"kind":kind,"boss":boss,"source":_last_damage_source.duplicate(true)})
	game.enemy_killed()
	queue_free()

func summon_pool() -> Array[int]:
	return [0,3,6] if kind == 5 else [8,14,15]

func apply_slow(seconds: float, factor: float = .5) -> void:
	slow_left = maxf(slow_left,seconds)
	slow_factor = minf(slow_factor,clampf(factor,.2,1))

func ranged_damage(distance: float) -> int:
	if combat_role() != 1:
		return attack_damage
	# Close shots still hurt; long sightlines gradually reach full sniper damage.
	return maxi(1,roundi(attack_damage * lerpf(.6,1.25,clampf(distance / 38.0,0,1))))

func show_healing_trail() -> void:
	var trail := Node3D.new()
	trail.name = "HealingTrail"
	add_child(trail)
	for index in range(3):
		var ring := MeshInstance3D.new()
		var shape := TorusMesh.new()
		shape.inner_radius = .37
		shape.outer_radius = .42
		shape.rings = 16
		shape.ring_segments = 8
		ring.mesh = shape
		var material := Kit.material(Color("1cba52"),true)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_energy_multiplier = .4
		ring.material_override = material
		ring.position.y = .35 + index * .3
		trail.add_child(ring)
	var tween := create_tween()
	tween.tween_property(trail,"position:y",.8,.75)
	tween.tween_callback(trail.queue_free)

func special_tick(delta: float) -> bool:
	if revival_left >= 0:
		revival_left -= delta
		if revival_left <= 0:
			revival_left = -1
			has_revived = true
			health = ceili(max_health * .6)
			attack_time = 1.0
			alerted = true
			tactics.on_revived(self)
			restore_special_visuals()
		else:
			update_title()
		return true
	if kind != 17:
		return false
	if phase_left >= 0:
		phase_left -= delta
		if phase_left <= 0:
			phase_left = -1
			phase_wait = 7
			# The destination is announced before vanishing and remains in this sector.
			var destination: Vector3 = tactics.blink_destination(self)
			if destination.distance_to(game.player.position) >= 5 and game.pursuit_route(position,destination).size() > 1:
				position = destination
			attack_time = 1.0
			path_time = 0
			restore_special_visuals()
		return true
	phase_wait -= delta
	if phase_wait < .8:
		update_title()
	if phase_wait <= 0:
		phase_left = 1.8
		warning_left = -1
		restore_special_visuals()
		return true
	return false

func _physics_process(delta: float) -> void:
	if game.finished:
		return
	slow_left = maxf(0,slow_left - delta)
	if slow_left <= 0:
		slow_factor = 1
	if special_tick(delta) or health <= 0:
		return
	var target: Vector3 = game.player.global_position
	var distance := global_position.distance_to(target)
	var role := combat_role()
	discovery_wait -= delta
	if discovery_wait <= 0:
		discovery_wait = .6
		if distance < 28 and game.player.camera.is_position_in_frustum(global_position + Vector3.UP):
			if steering.can_see(self,target):
				_discover_event()
	if is_instance_valid(game.mission) and game.mission.early != null and game.mission.early.get("defense") != null:
		if game.mission.early.defense.tick_enemy(self,delta):
			return
	# Early encounters remain in their sector until seen, approached or hit.
	if not alerted and not boss:
		alerted = distance < 5 or (distance < 19 and steering.can_see(self,target))
		if not alerted:
			patrol_clock += delta
			var patrol_target := home_position + Vector3(sin(patrol_clock * 0.3) * 2, 0, cos(patrol_clock * 0.3) * 2)
			var patrol_path: PackedVector2Array = game.route(position, patrol_target)
			var patrol_direction := Vector3.ZERO
			if patrol_path.size() > 1:
				patrol_direction = (Vector3(patrol_path[1].x, position.y, patrol_path[1].y) - position).normalized()
			velocity = Vector3(patrol_direction.x * move_speed * 0.45 * slow_factor, velocity.y - 22 * delta, patrol_direction.z * move_speed * 0.45 * slow_factor)
			move_and_slide()
			return
	if not boss:
		var was_enraged: bool = tactics.enraged_left > 0
		tactics.tick(self, delta)
		if kind == 16 and (was_enraged or tactics.enraged_left > 0):
			update_title()
	attack_time -= delta
	if warning_left >= 0:
		warning_left -= delta
		if warning_left <= 0:
			warning_left = -1
			update_title()
			fire_at_player()
			attack_time = _attack_delay()
	var visible: bool = steering.clear_shot(self, target)
	var desired_range := 24.0 if role == 1 else (1.4 if role in [0, 3] else 7.0)
	var goal: Vector3 = tactics.movement_goal(self, target, visible) if not boss else target
	if not boss:
		if visible:
			# Physical observation is the only source of a new pursuit location.
			tactics.has_memory = true
			tactics.last_seen = target
			tactics.memory_left = 5.0 if kind == 12 else 3.0
			search.observe(target)
		elif search.eligible(self):
			goal = search.investigate(self,tactics.last_seen,delta)
			if search.give_up:
				alerted = false
				tactics.has_memory = false
				tactics.memory_left = 0
				tactics.goal_left = 0
				warning_left = -1
				search.observe(position)
	if not boss and kind == 9 and tactics.is_committed_charge():
		# A charging Cazador commits to its announced line; it cannot home in mid-run.
		goal.y = position.y
	elif not boss:
		if role == 1 and visible and distance < 18:
			goal = steering.firing_position(self, target, true)
		elif visible and goal.distance_to(target) < .2 and distance <= desired_range:
			goal = position
	if boss:
		if global_position.distance_to(home_position) > 9:
			goal = home_position
		elif distance > 23 or (visible and distance < 7):
			goal = position
	var direction := Vector3.ZERO
	if not boss and kind == 9 and tactics.is_committed_charge():
		direction = tactics.committed_direction()
	else:
		direction = steering.direction(self, goal, delta)
	var role_speed := 0.75 if role == 2 else (1.25 if role == 3 else 1.0)
	var tactic_speed: float = tactics.speed_multiplier(self) if not boss else 1.0
	velocity.x = direction.x * move_speed * role_speed * slow_factor * tactic_speed
	velocity.z = direction.z * move_speed * role_speed * slow_factor * tactic_speed
	velocity.y -= 22 * delta
	move_and_slide()
	# Count failed pursuit as well as failed physical motion. Never teleport out of cover.
	var wants_to_move := goal.distance_to(position) > .8 and tactic_speed > 0
	if wants_to_move and position.distance_to(previous_position) < .005:
		stuck_wait += delta
	else:
		stuck_wait = maxf(0, stuck_wait - delta * 2)
	previous_position = position
	if stuck_wait > 1.2:
		path_time = 0
		steering = Steering.new()
		steering.setup(self)
		stuck_wait = 0
	if role == 3 and not boss and distance < 2.2:
		if steering.clear_shot(self, target):
			game.player.take_damage(attack_damage * 2)
			take_damage(max_health * 10)
			return
	var look_target: Vector3 = target if visible or boss else (goal if goal.distance_to(position) > .5 else tactics.last_seen)
	var facing := Vector3(look_target.x, global_position.y, look_target.z)
	if kind == 9 and not boss and tactics.is_committed_charge():
		facing = global_position + tactics.committed_direction()
	if global_position.distance_to(facing) > 0.1:
		if kind in [2,8,13]:
			var target_yaw := atan2(facing.x - global_position.x,facing.z - global_position.z)
			rotation.y = lerp_angle(rotation.y,target_yaw,minf(1,delta * 2.5))
		else:
			look_at(facing, Vector3.UP, true)
	var attack_goal: Vector3 = tactics.attack_point(self, target, visible) if not boss else target
	var can_attack: bool = boss or tactics.allow_attack(self)
	var suppressing := kind == 12 and not boss and not visible and attack_goal.is_finite()
	if can_attack and (visible or suppressing) and global_position.distance_to(attack_goal) < attack_range and attack_time <= 0 and warning_left < 0:
		if warning_duration > 0:
			warning_left = warning_duration
			title.text = "¡FUEGO!\n" + ("GUARDIÁN ÁUREO" if boss else Catalog.ENTRIES[kind].name)
		else:
			fire_at_player()
			attack_time = _attack_delay()

func fire_at_player() -> void:
	if not boss and not tactics.allow_attack(self):
		return
	var origin := global_position + Vector3.UP*steering.firing_height(self)
	var target: Vector3 = game.player.global_position
	var visible: bool = steering.clear_shot(self, target)
	var ground_aim: Vector3 = tactics.attack_point(self, target, visible) if not boss else target
	if not ground_aim.is_finite():
		return
	var aim: Vector3 = steering.shot_target(self,global_position,ground_aim)
	if not aim.is_finite():
		# Suppression still fires at remembered cover rather than through it.
		if kind != 12 or boss or visible:
			return
		aim = ground_aim+Vector3.UP
	if origin.distance_to(aim) > attack_range:
		return
	var query := PhysicsRayQueryParameters3D.create(origin, aim, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var hits_player: bool = not hit.is_empty() and hit.collider == game.player
	var suppression := kind == 12 and not boss and not visible
	if not hits_player and not suppression:
		return
	# Allies block the muzzle: reposition rather than drawing shots through them.
	if not hit.is_empty() and hit.collider is EnemyController:
		return
	$Shot.play()
	game.beam(origin, hit.position if not hit.is_empty() else aim, Catalog.ENTRIES[kind].color)
	if hits_player:
		game.player.take_damage(ranged_damage(origin.distance_to(aim)))
	if not boss:
		tactics.on_shot(self)

func _attack_delay() -> float:
	if boss:
		return attack_interval * (.8 if health < max_health / 2 else 1.0)
	return attack_interval * tactics.attack_interval_multiplier(self)

var _last_damage_source: Dictionary = {}

func take_damage(amount: int, context: Dictionary = {}) -> void:
	if revival_left >= 0:
		var previous_core := revival_core
		revival_core -= amount
		_last_damage_source = context.duplicate(true)
		_event("enemy_hit",{"enemy_id":str(get_instance_id()),"kind":kind,"core_damage":mini(previous_core,amount),"source":context})
		if revival_core <= 0:
			finish_death()
		else:
			update_title()
		return
	if health <= 0 or invulnerable or phase_left >= 0:
		return
	var previous_health := health
	var previous_shield := shield_health
	_last_damage_source = context.duplicate(true)
	alerted = true
	if not boss:
		tactics.on_damaged(self)
	_discover_event()
	if kind == 13 and shield_health > 0 and global_basis.z.dot((game.player.position - position).normalized()) > 0.35:
		var absorbed := mini(amount, shield_health)
		shield_health -= absorbed
		amount -= absorbed
	for ally in game.get_children():
		if ally is EnemyController and ally != self and ally.kind == 15 and ally.health > 0 and ally.position.distance_to(position) < 9 and sees_ally(ally):
			amount = ceili(amount * 0.65)
			break
	if not boss and kind % 6 == 2:
		var toward_player: Vector3 = (game.player.position - position).normalized()
		if global_basis.z.dot(toward_player) > 0.5:
			amount = maxi(1, roundi(amount * 0.5))
	health = maxi(0, health - amount)
	if boss and is_instance_valid(game.mission):
		var phase: int = game.mission.boss_phase
		if phase < 2:
			health = maxi(health, floori(max_health * (0.66 if phase == 0 else 0.33)))
	_event("enemy_hit",{"enemy_id":str(get_instance_id()),"kind":kind,"boss":boss,"health_damage":previous_health-health,"shield_damage":previous_shield-shield_health,"health":health,"source":context})
	update_title()
	if health == 0:
		if kind == 16 and not has_revived:
			revival_left = 4
			revival_core = 45
			velocity = Vector3.ZERO
			restore_special_visuals()
		else:
			finish_death()

func sees_ally(ally: Node3D) -> bool:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position + Vector3.UP,ally.global_position + Vector3.UP,1,[get_rid()]))
	return not hit.is_empty() and hit.collider == ally

func _event(type: String, payload: Dictionary) -> void:
	if is_instance_valid(game) and game.has_method("log_event"):
		game.log_event(type,payload)

func _discover_event() -> void:
	if get_node("/root/Campaign").discover_enemy(kind):
		_event("enemy_discovered",{"kind":kind,"boss":boss})
