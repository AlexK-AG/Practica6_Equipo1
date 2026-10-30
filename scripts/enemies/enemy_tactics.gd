extends RefCounted
## Authored intent only: the controller owns movement, rays, damage and phases.
const Deployment = preload("res://scripts/enemies/enemy_deployment.gd")
var clock: float = 0
var sense_wait: float = 0
var visible_cache: bool = false
var has_memory: bool = false
var last_seen := Vector3.ZERO
var memory_left: float = 0
var ability_cooldown: float = 3
var channel: String = ""
var channel_left: float = 0
var ally_name: String = ""
var previous_patient: String = ""
var move_goal := Vector3.ZERO
var goal_left: float = 0
var shots: int = 0
var scout_hold_until: float = 0
var scout_shots_at_hold: int = -1
var scout_last_clear: float = -100
var burst_pause: float = 0
var charge_state: String = ""
var charge_left: float = 0
var charge_goal := Vector3.ZERO
var charge_vector := Vector3.ZERO
var charge_kind: int = -1
var anchor_goal := Vector3.ZERO
var anchor_left: float = 0
var pending_blink: bool = false
var blink_goal := Vector3.ZERO
var blink_marker: MeshInstance3D
var summon_goal := Vector3.ZERO
var enraged_left: float = 0
var visual_wait: float = 0
var deployment: Node3D
var deployment_health: int = 90
var deployed_names: Array[String] = []

func tick(e, delta: float) -> void:
	if e.boss or e.health <= 0:
		return
	clock += delta
	for property in ["ability_cooldown", "goal_left", "burst_pause", "enraged_left", "memory_left", "visual_wait", "anchor_left"]:
		set(property, maxf(0, float(get(property)) - delta))
	# Alerted reinforcements investigate one communicated location, never live tracking.
	if not has_memory and e.alerted:
		has_memory = true
		last_seen = e.game.player.global_position
		memory_left = 3
	sense_wait -= delta
	if sense_wait <= 0:
		sense_wait = .28
		visible_cache = can_see_player(e)
		if visible_cache:
			has_memory = true
			last_seen = e.game.player.global_position
			memory_left = 5.0 if e.kind == 12 else 3.0
	if e.kind == 17 and e.phase_wait < 1.2:
		if not pending_blink:
			blink_goal = choose_blink_destination(e)
			pending_blink = true
		ensure_blink_marker(e)
	if e.kind == 15 and visual_wait <= 0:
		visual_wait = .45
		for ally in nearby_allies(e, 9):
			e.game.beam(e.global_position + Vector3.UP*1.4, ally.global_position + Vector3.UP, Color("af7fb8"))
	if charge_state != "":
		charge_left -= delta
		if charge_left <= 0:
			if charge_state == "warning":
				charge_state = "charge"
				charge_left = .85 if e.kind == 9 else .65
				e.title.text = "¡CARGA!" if e.kind == 9 else "¡AVANCE LATERAL!"
			else:
				charge_state = ""
				ability_cooldown = 5.5
				e.update_title()
		return
	if channel != "":
		channel_left -= delta
		if channel == "heal":
			var ally = ally_by_name(e, ally_name)
			if ally == null or not e.sees_ally(ally) or e.global_position.distance_to(ally.global_position) > 13:
				cancel_channel(e)
				return
			if visual_wait <= 0:
				visual_wait = .15
				e.game.beam(e.global_position + Vector3.UP*1.3, ally.global_position + Vector3.UP, Color("45bc79"))
		elif channel == "summon":
			if visual_wait <= 0:
				visual_wait = .2
				e.game.beam(e.global_position + Vector3.UP, summon_goal + Vector3.UP*.2, Color("f2ae73"))
		elif channel == "deploy":
			if deployment == null:
				make_deployment(e)
			if not is_instance_valid(deployment) or deployment.is_queued_for_deletion() or deployment.health <= 0:
				cancel_channel(e)
				return
			deployment_health = deployment.health
		e.title.text = "%s · %.1fs" % [{"heal":"CURACIÓN · INTERRÚMPELA", "summon":"REFUERZOS · INTERRUMPE", "deploy":"DESPLIEGUE PESADO"}.get(channel,"CANALIZANDO"), maxf(0,channel_left)]
		if channel_left <= 0:
			finish_channel(e)
		return
	if ability_cooldown > 0 or not is_instance_valid(e.game.mission):
		return
	match e.kind:
		4, 10:
			var patient = choose_patient(e)
			if patient != null:
				ally_name = str(patient.name)
				channel = "heal"
				channel_left = .95 if e.kind == 4 else .80
			else:
				ability_cooldown = 1.0
		5:
			if can_summon(e, 18) and live_summons(e) < 3:
				summon_goal = choose_summon_point(e)
				if valid_deployment_point(e,summon_goal):
					channel = "summon"
					channel_left = 1.8
				else:
					ability_cooldown = 2
			else:
				ability_cooldown = 2
		11:
			if can_summon(e, 20) and live_summons(e) < 2 and e.get_tree().get_nodes_in_group("enemy_deployments").size() < 2:
				summon_goal = choose_summon_point(e)
				if not valid_deployment_point(e,summon_goal):
					ability_cooldown = 2
					return
				channel = "deploy"
				channel_left = 2.6
				deployment_health = 90
				make_deployment(e)
			else:
				ability_cooldown = 2
		3, 9:
			if visible_cache and e.global_position.distance_to(last_seen) < 16:
				charge_state = "warning"
				charge_left = .85 if e.kind == 9 else .7
				var forward: Vector3 = (last_seen - e.global_position).normalized()
				var side := Vector3(-forward.z,0,forward.x) * (1 if int(clock)%2 == 0 else -1)
				charge_goal = e.global_position + (forward * 10 if e.kind == 9 else (forward*5 + side*4))
				charge_goal.y = e.position.y
				charge_goal = safe_point(e, charge_goal)
				charge_vector = charge_goal-e.global_position
				charge_vector.y = 0
				charge_vector = charge_vector.normalized()
				charge_kind = e.kind
				e.title.text = "¡CARGA INMINENTE!" if e.kind == 9 else "¡SPRINT INMINENTE!"
			else:
				ability_cooldown = 1

func movement_goal(e, target: Vector3, visible: bool) -> Vector3:
	if e.boss:
		return target
	if channel != "" or charge_state == "warning":
		return e.global_position
	if charge_state == "charge":
		return charge_goal
	var known: Vector3 = target if visible else (last_seen if has_memory else e.global_position)
	if e.kind == 0:
		return scout_goal(e, known, visible)
	if e.kind in [4,10]:
		var ally = rear_ally(e,known)
		if ally != null:
			if goal_left > 0:
				return move_goal
			return cover_goal(e,ally,known)
	if goal_left > 0:
		return move_goal
	match e.kind:
		1, 7:
			if visible:
				if e.global_position.distance_to(known) < 20 or e.kind == 7 or shots >= 2:
					shots = 0
					return sniper_goal(e, known)
				return e.global_position
		2, 13:
			var support = support_ally(e)
			if support != null and has_memory:
				var toward: Vector3 = (known-support.global_position).normalized()
				return safe_point(e, support.global_position + toward*(3 if e.kind == 2 else 2))
		3:
			if visible:
				return advance_flank(e, known, 5, 2)
		4:
			var patient = choose_patient(e)
			if patient != null:
				return cover_goal(e, patient, known)
		5, 11:
			if visible and e.global_position.distance_to(known) < 11:
				return retreat_goal(e, known, 4)
		6:
			if visible:
				for ally in nearby_allies(e, 15):
					if ally.alerted and ally.global_position.distance_to(known) < e.global_position.distance_to(known):
						return advance_flank(e, known, 6, 4)
		8:
			if anchor_left <= 0:
				anchor_goal = group_center(e)
				if visible:
					anchor_goal += (known-anchor_goal).normalized()*2.5
				anchor_goal = safe_point(e,anchor_goal)
				anchor_left = 4
			return anchor_goal
		10:
			var patient = choose_patient(e)
			if patient != null:
				return cover_goal(e, patient, known)
		12:
			if not visible:
				return e.global_position if memory_left > 0 else known
			if e.global_position.distance_to(known) < 9:
				return retreat_goal(e, known, 3)
		14:
			if burst_pause > 0 and visible:
				return lateral_goal(e, known, 4)
		15:
			return safe_point(e, group_center(e))
		16:
			if enraged_left > 0 and visible:
				return known
		17:
			if visible and e.phase_wait < 1.2:
				return e.global_position
	return known

func speed_multiplier(e) -> float:
	if e.boss:
		return 1
	if channel != "" or charge_state == "warning":
		return 0
	if charge_state == "charge":
		return 2.1 if e.kind == 9 else 1.65
	if e.kind == 16 and enraged_left > 0:
		return 1.3
	if e.kind == 8:
		return .7
	return 1

func allow_attack(e) -> bool:
	if e.boss:
		return true
	if e.kind == 12 and not visible_cache and memory_left <= 0:
		return false
	return e.boss or (channel == "" and charge_state == "" and burst_pause <= 0)

func attack_interval_multiplier(e) -> float:
	if e.boss:
		return 1
	if e.kind == 16 and enraged_left > 0:
		return .72
	if e.kind in [12,14] and burst_pause <= 0:
		return .22
	return 1

func is_committed_charge() -> bool:
	return charge_state == "charge" and charge_kind == 9

func committed_direction() -> Vector3:
	return charge_vector

func on_damaged(e) -> void:
	if e.boss:
		return
	if channel != "":
		cancel_channel(e)
	if charge_state == "warning":
		charge_state = ""
		ability_cooldown = 2
	if e.kind in [0,1,7,10]:
		goal_left = 0

func on_revived(e) -> void:
	if e.kind == 16:
		enraged_left = 7
		e.title.text = "¡REANIMADO · SOBRECARGA 7s!"
		e.attack_time = minf(e.attack_time, 1)

func on_shot(e) -> void:
	if e.boss:
		return
	shots += 1
	if e.kind in [1,7] and shots >= (1 if e.kind == 7 else 2):
		goal_left = 0
	if e.kind in [12,14]:
		var limit := 4 if e.kind == 12 else 3
		if shots % limit == 0:
			burst_pause = 1.6 if e.kind == 12 else 1.1
			goal_left = 0

func blink_destination(e) -> Vector3:
	var destination: Vector3 = blink_goal if pending_blink else choose_blink_destination(e)
	if destination.distance_to(e.game.player.global_position) < 5 or not space_clear(e,destination,.5) or not reachable(e,destination) or (e.game.has_method("navigation_segment_clear") and not e.game.navigation_segment_clear(e.global_position,destination,.5)):
		destination = e.global_position
	pending_blink = false
	if is_instance_valid(blink_marker):
		blink_marker.queue_free()
	blink_marker = null
	return destination

func choose_blink_destination(e) -> Vector3:
	var known: Vector3 = last_seen if has_memory else e.global_position - e.global_basis.z*8
	var side := lateral(e, known)
	var best: Vector3 = e.global_position
	var score := -INF
	for offset in [side*5,-side*5,side*4+(e.global_position-known).normalized()*2,-side*4+(e.global_position-known).normalized()*2]:
		var candidate: Vector3 = e.global_position + offset
		if candidate.distance_to(known) < 6 or not reachable(e,candidate) or not space_clear(e,candidate,.5):
			continue
		# Segment clearance stops blinking across closed doors or props.
		if e.game.has_method("navigation_segment_clear") and not e.game.navigation_segment_clear(e.global_position,candidate,.5):
			continue
		var candidate_score := candidate.distance_to(e.global_position) - absf(candidate.distance_to(known)-10)*.2
		if candidate_score > score:
			score = candidate_score
			best = candidate
	return best

func attack_point(e, target: Vector3, visible: bool) -> Vector3:
	if e.boss:
		return target
	if e.kind == 12 and not visible and has_memory and memory_left > 0:
		return last_seen
	return target

func capture_state() -> Dictionary:
	var result := {}
	for property in ["clock","sense_wait","visible_cache","has_memory","last_seen","memory_left","ability_cooldown","channel","channel_left","ally_name","previous_patient","move_goal","goal_left","shots","scout_hold_until","scout_shots_at_hold","scout_last_clear","burst_pause","charge_state","charge_left","charge_goal","charge_vector","charge_kind","enraged_left","visual_wait","deployment_health","deployed_names","anchor_goal","anchor_left","pending_blink","blink_goal","summon_goal"]:
		result[property] = get(property)
	if is_instance_valid(deployment):
		result.deployment_health = deployment.health
	return result.duplicate(true)

func restore_state(data: Dictionary) -> void:
	for property in capture_state():
		if data.has(property):
			if property == "deployed_names":
				deployed_names.assign(data[property])
			else:
				set(property, data[property])
	# Force a current physics LOS check rather than trusting a saved perception.
	sense_wait = 0
	visible_cache = false

func finish_channel(e) -> void:
	match channel:
		"heal":
			var patient = ally_by_name(e, ally_name)
			if patient != null and e.sees_ally(patient):
				patient.health = mini(patient.max_health, patient.health + 28 + e.game.level_number*2)
				patient.update_title()
				patient.show_healing_trail()
				previous_patient = ally_name
			ability_cooldown = cooldown(e, 1.55 if e.kind == 4 else 1.25)
		"summon", "deploy":
			if can_summon(e, 18 if channel == "summon" else 20):
				var before: Array = e.game.get_children()
				var pool: Array[int] = []
				pool.assign(pressure_pool(e) if channel == "summon" else [8])
				if e.game.mission.spawn_enemy(pool.pick_random()):
					for child in e.game.get_children():
						if not before.has(child) and child is EnemyController:
							deployed_names.append(str(child.name))
			ability_cooldown = cooldown(e, 13 if channel == "summon" else 17)
	channel = ""
	channel_left = 0
	clear_deployment()
	e.update_title()

func cancel_channel(e) -> void:
	channel = ""
	channel_left = 0
	ability_cooldown = 2.5
	clear_deployment()
	e.update_title()

func clear_deployment() -> void:
	if is_instance_valid(deployment):
		deployment.queue_free()
	deployment = null

func make_deployment(e) -> void:
	if not valid_deployment_point(e,summon_goal):
		channel = ""
		ability_cooldown = 2
		return
	deployment = StaticBody3D.new()
	deployment.set_script(Deployment)
	deployment.name = "Deployment_" + str(e.name)
	deployment.owner_enemy = e
	deployment.health = deployment_health
	deployment.position = summon_goal
	e.game.add_child(deployment)

func can_summon(e, cap: int) -> bool:
	return e.game.level_number > 2 and e.game.mission.living_enemies() < cap and has_memory and memory_left > 0

func live_summons(e) -> int:
	var count := 0
	for name in deployed_names:
		if ally_by_name(e,name) != null:
			count += 1
	return count

func cooldown(e, base: float) -> float:
	# Small pressure adjustment, separate from already-scaled attack/move stats.
	var difficulty: float = e.Catalog.DIFFICULTY[clampi(int(e.get_node("/root/Campaign").options.difficulty),0,2)].attack
	return base / minf(1.35, (1 + .02*maxi(0,e.game.level_number-1))*sqrt(difficulty))

func can_see_player(e) -> bool:
	if e.global_position.distance_to(e.game.player.global_position) > 45:
		return false
	return e.steering.can_see(e,e.game.player.global_position)

func ally_by_name(e, name: String):
	var ally = e.game.get_node_or_null(NodePath(name)) if not name.is_empty() else null
	return ally if ally is EnemyController and ally != e and ally.health > 0 and ally.phase_left < 0 else null

func nearby_allies(e, radius: float) -> Array:
	var result: Array = []
	for ally in e.game.get_children():
		if ally is EnemyController and ally != e and ally.health > 0 and ally.phase_left < 0 and ally.global_position.distance_to(e.global_position) <= radius and e.sees_ally(ally):
			result.append(ally)
	return result

func choose_patient(e):
	var best = null
	var score := 0.0
	for ally in nearby_allies(e, 12):
		var need: float = 1 - float(ally.health)/maxi(1,ally.max_health)
		if e.kind == 10 and str(ally.name) == previous_patient:
			need *= .7
		if need > score:
			score = need
			best = ally
	return best

func rear_ally(e, known: Vector3):
	var patient = choose_patient(e)
	if patient != null:
		return patient
	var best = null
	var score := -INF
	for ally in nearby_allies(e,12):
		# Prefer the frontline even when nobody currently needs healing.
		if ally.kind in [4,10]:
			continue
		var candidate: float = -ally.global_position.distance_to(known) - ally.global_position.distance_to(e.global_position)*.2
		if candidate > score:
			score = candidate
			best = ally
	return best

func support_ally(e):
	for ally in nearby_allies(e, 12):
		if ally.kind in [4,5,10,11,15]:
			return ally
	return null

func group_center(e) -> Vector3:
	var center: Vector3 = e.global_position
	var allies := nearby_allies(e, 9)
	for ally in allies:
		center += ally.global_position
	return center/(allies.size()+1)

func lateral(e, target: Vector3) -> Vector3:
	var toward: Vector3 = (target-e.global_position).normalized()
	return Vector3(-toward.z,0,toward.x) * (1 if int(e.get_instance_id())%2 == 0 else -1)

func lateral_goal(e, target: Vector3, amount: float) -> Vector3:
	for side in [1,-1]:
		var point: Vector3 = e.global_position + lateral(e,target)*amount*side
		if reachable(e,point):
			move_goal = point
			goal_left = 1.8
			return point
	return target

func retreat_goal(e, target: Vector3, amount: float) -> Vector3:
	return safe_point(e, e.global_position+(e.global_position-target).normalized()*amount)

func sniper_goal(e, target: Vector3) -> Vector3:
	var best: Vector3 = e.global_position
	var score := -INF
	for offset in [lateral(e,target)*5,-lateral(e,target)*5,(e.global_position-target).normalized()*5]:
		var point: Vector3 = e.global_position + offset
		if not reachable(e,point):
			continue
		var dist := point.distance_to(target)
		var candidate := -absf(dist-26) + point.distance_to(e.global_position)*.3
		if candidate > score:
			score = candidate
			best = point
	move_goal = best
	goal_left = 2.8
	return best

func safe_point(e, point: Vector3) -> Vector3:
	return point if reachable(e,point) else e.global_position

func reachable(e, point: Vector3) -> bool:
	if point.distance_to(e.global_position) < .25:
		return true
	var path: PackedVector2Array = e.game.pursuit_route(e.global_position,point) if e.game.has_method("pursuit_route") else e.game.route(e.global_position,point)
	if path.size() <= 1:
		return false
	# A clamped fallback endpoint must not become an out-of-map tactical goal.
	return Vector2(point.x,point.z).distance_to(path[path.size()-1]) < 2

func ensure_blink_marker(e) -> void:
	if is_instance_valid(blink_marker):
		blink_marker.global_position = Vector3(blink_goal.x,e.global_position.y+.08,blink_goal.z)
		blink_marker.global_basis = Basis.IDENTITY
		return
	blink_marker = MeshInstance3D.new()
	blink_marker.name = "BlinkDestination"
	var ring := TorusMesh.new()
	ring.inner_radius = .60
	ring.outer_radius = .78
	ring.rings = 16
	ring.ring_segments = 8
	blink_marker.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("bb84d6")
	blink_marker.material_override = mat
	e.add_child(blink_marker)
	blink_marker.global_position = Vector3(blink_goal.x, e.global_position.y+.08, blink_goal.z)
	blink_marker.global_basis = Basis.IDENTITY

func restore_visuals(e) -> void:
	if pending_blink:
		ensure_blink_marker(e)
	if channel == "deploy" and not is_instance_valid(deployment):
		make_deployment(e)

func cover_goal(e, patient, known: Vector3) -> Vector3:
	var away: Vector3 = patient.global_position-known
	away.y = 0
	away = away.normalized()
	if away.is_zero_approx():
		away = e.global_position-patient.global_position
		away.y = 0
		away = away.normalized()
	if away.is_zero_approx():
		away = Vector3.BACK
	var side := Vector3(-away.z,0,away.x)
	var best: Vector3 = e.global_position
	var best_score := -INF
	for offset in [away*3,away*4,away*3+side*2,away*3-side*2,away*1.8,away*1.8+side,away*1.8-side]:
		var point: Vector3 = patient.global_position + offset
		if not reachable(e,point) or not e.search.standable(e,point):
			continue
		var occupied := false
		for ally in nearby_allies(e,12):
			if ally.global_position.distance_to(point) < e.steering.body_radius(e)+e.steering.body_radius(ally)+.25:
				occupied = true
		if occupied:
			continue
		var patient_ray: Dictionary = e.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP,patient.global_position+Vector3.UP,1,[e.get_rid()]))
		if not patient_ray.is_empty() and patient_ray.collider != patient:
			continue
		var cover_ray: Dictionary = e.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(known+Vector3.UP,point+Vector3.UP,1,[e.get_rid(),patient.get_rid()]))
		var protected: bool = not cover_ray.is_empty() and cover_ray.collider != e.game.player
		var score := (8.0 if protected else 0.0) - point.distance_to(e.global_position)*.2
		if score > best_score:
			best_score = score
			best = point
	move_goal = best
	goal_left = .65
	return best

func choose_summon_point(e) -> Vector3:
	var side := lateral(e,last_seen)
	var away: Vector3 = (e.global_position-last_seen).normalized()
	var best: Vector3 = e.global_position
	var score := -INF
	for offset in [side*5,-side*5,away*4,side*3+away*3,-side*3+away*3]:
		var point: Vector3 = e.global_position+offset
		if not valid_deployment_point(e,point):
			continue
		if e.game.has_method("navigation_segment_clear") and not e.game.navigation_segment_clear(point,point,.55):
			continue
		var candidate := point.distance_to(last_seen)*.2 - point.distance_to(e.global_position)*.05
		if visible_cache:
			candidate += absf((point-e.global_position).dot(side))*.25
		if candidate > score:
			score = candidate
			best = point
	return best

func pressure_pool(e) -> Array[int]:
	var pool: Array[int] = []
	pool.assign(e.summon_pool())
	# Close pressure gets a sturdy frontal unit; distant sightlines get a flanker.
	var distance: float = e.global_position.distance_to(last_seen)
	var desired := 3 if distance < 12 else 0
	for ally in nearby_allies(e,18):
		if ally.alerted and ally.global_position.distance_to(last_seen) < distance-3:
			desired = 6
			break
	if not pool.has(desired):
		desired = pool[0]
	var same := 0
	for ally in nearby_allies(e,18):
		if ally.kind == desired:
			same += 1
	return [desired] if same < 2 else pool

func valid_deployment_point(e, point: Vector3) -> bool:
	if point.distance_to(e.global_position) < 1.4 or point.distance_to(e.game.player.global_position) < 12 or not reachable(e,point):
		return false
	return space_clear(e,point,.55)

func space_clear(e, point: Vector3, radius: float) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,point+Vector3.UP*.75)
	query.collision_mask = 1
	query.exclude = [e.get_rid()]
	return e.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func advance_flank(e, target: Vector3, advance: float, width: float) -> Vector3:
	var forward: Vector3 = target-e.global_position
	forward.y = 0
	var distance := forward.length()
	forward = forward.normalized()
	for side in [1,-1]:
		var point: Vector3 = e.global_position + forward*minf(advance,maxf(0,distance-1.5)) + lateral(e,target)*minf(width,distance*.25)*side
		if reachable(e,point):
			move_goal = point
			goal_left = 1.4
			return point
	return target

func scout_goal(e, target: Vector3, visible: bool) -> Vector3:
	# Finish acquiring a firing lane before requesting another lateral maneuver.
	# Brief occlusion by a moving ally should not immediately reverse the intent.
	if not visible:
		goal_left = 0
		if clock - scout_last_clear < .20:
			return e.global_position
		scout_shots_at_hold = -1
		return target
	scout_last_clear = clock
	if e.global_position.distance_to(target) > 11:
		scout_shots_at_hold = -1
		return target
	if scout_shots_at_hold < 0:
		scout_shots_at_hold = shots
		scout_hold_until = clock + .9
		goal_left = 0
	if goal_left > 0:
		if move_goal.distance_to(e.global_position) > .4 and scout_lane_clear(e,move_goal,target):
			return move_goal
		goal_left = 0
		scout_hold_until = clock + .9
		scout_shots_at_hold = shots
		return e.global_position
	# Hold long enough to actually shoot. A peek that immediately abandons its
	# lane can otherwise oscillate indefinitely without ever completing a shot.
	if clock < scout_hold_until or shots <= scout_shots_at_hold:
		return e.global_position
	var toward: Vector3 = target-e.global_position
	toward.y = 0
	toward = toward.normalized()
	var advance: float = .7 if e.global_position.distance_to(target) > 7 else 0.0
	for sign in [1,-1]:
		var point: Vector3 = e.global_position + lateral(e,target)*2*sign + toward*advance
		if not reachable(e,point) or not scout_lane_clear(e,point,target):
			continue
		if not e.game.navigation_segment_clear(e.global_position,point,e.steering.body_radius(e)):
			continue
		move_goal = point
		goal_left = 1.4
		return point
	# No useful lane change: keep shooting rather than bounce against the wall.
	scout_hold_until = clock + 1.2
	scout_shots_at_hold = shots
	return e.global_position

func scout_lane_clear(e, point: Vector3, target: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point+Vector3(0,.8,0),target+Vector3.UP,1,[e.get_rid()])
	var hit: Dictionary = e.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == e.game.player
