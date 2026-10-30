extends RefCounted
## Per-actor routing, local avoidance and firing lanes. Never moves the actor itself.
var route := PackedVector2Array()
var route_wait := 0.0
var route_goal := Vector3.INF
var firing_goal := Vector3.INF
var firing_wait := 0.0
var side := 1.0
var side_wait := 0.0
var movement_wait := 0.0
var movement := Vector3.ZERO
var movement_goal := Vector3.INF
var firing_target := Vector3.INF
var firing_retreat := false

func setup(enemy: CharacterBody3D) -> void:
	side = 1.0 if enemy.get_instance_id() % 2 == 0 else -1.0

func clear_shot(enemy: CharacterBody3D, point: Vector3) -> bool:
	return _shot_from(enemy, enemy.global_position, point)

func body_height(enemy: CharacterBody3D) -> float:
	for child in enemy.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			return child.shape.size.y*child.global_basis.get_scale().abs().y
	return 1.3

func is_tall(enemy: CharacterBody3D) -> bool:
	return body_height(enemy) > 1.3001

func firing_height(enemy: CharacterBody3D) -> float:
	if not is_tall(enemy):
		return .8
	for child in enemy.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			return child.global_position.y-enemy.global_position.y+body_height(enemy)*.5-.06
	return .8

func shot_target(enemy: CharacterBody3D, from: Vector3, point: Vector3) -> Vector3:
	var origin := from+Vector3.UP*firing_height(enemy)
	# Small enemies retain the original single torso ray. Taller enemies can
	# target the exposed head as well, but every shot still hits physical cover.
	var heights := [1.0]
	if is_tall(enemy):
		var head := 1.6
		var camera := enemy.game.player.get_node_or_null("Camera") as Node3D
		if camera != null:
			head = camera.global_position.y-enemy.game.player.global_position.y
		heights = [head,1.0]
	for height in heights:
		var aim: Vector3 = point+Vector3.UP*height
		var hit := enemy.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,aim,1,[enemy.get_rid()]))
		if not hit.is_empty() and hit.collider == enemy.game.player:
			return aim
	return Vector3.INF

func _shot_from(enemy: CharacterBody3D, from: Vector3, point: Vector3) -> bool:
	return shot_target(enemy,from,point).is_finite()

func can_see(enemy: CharacterBody3D, point: Vector3) -> bool:
	if is_tall(enemy):
		return clear_shot(enemy,point)
	# Preserve small-enemy perception independently from its lower muzzle.
	var hit := enemy.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(enemy.global_position+Vector3.UP,point+Vector3.UP,1,[enemy.get_rid()]))
	return not hit.is_empty() and hit.collider == enemy.game.player

func body_radius(enemy: CharacterBody3D) -> float:
	var radius := .43
	for child in enemy.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			var scaled: Vector3 = child.shape.size * child.global_basis.get_scale().abs()
			radius = maxf(scaled.x, scaled.z) * .5
			break
	return radius

func _route(enemy: CharacterBody3D, point: Vector3) -> PackedVector2Array:
	if enemy.game.has_method("pursuit_route"):
		return enemy.game.pursuit_route(enemy.global_position, point)
	return enemy.game.route(enemy.global_position, point)

func _segment(enemy: CharacterBody3D, from: Vector3, to: Vector3, actors: bool = true) -> bool:
	var motion := to - from
	motion.y = 0
	if motion.length_squared() < .00001:
		return true
	if enemy.game.has_method("navigation_segment_clear") and not enemy.game.navigation_segment_clear(from, to, body_radius(enemy)):
		return false
	var exclusions: Array[RID] = [enemy.get_rid()]
	if not actors:
		for body in enemy.game.get_children():
			if body is CharacterBody3D:
				exclusions.append(body.get_rid())
	for child in enemy.get_children():
		if not child is CollisionShape3D or child.disabled or child.shape == null:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = child.shape
		query.transform = child.global_transform
		query.transform.origin += from - enemy.global_position
		query.motion = motion
		query.margin = .025
		query.collision_mask = 1
		query.exclude = exclusions
		var cast := enemy.get_world_3d().direct_space_state.cast_motion(query)
		if cast.size() < 2 or cast[0] < .99:
			return false
	return true

func direction(enemy: CharacterBody3D, goal: Vector3, delta: float) -> Vector3:
	route_wait -= delta
	firing_wait -= delta
	side_wait -= delta
	movement_wait -= delta
	if movement_wait > 0 and movement_goal.distance_to(goal) < .8:
		if movement == Vector3.ZERO or _segment(enemy,enemy.global_position,enemy.global_position + movement * maxf(.2,enemy.move_speed * delta * 2)):
			return movement
	movement_wait = .09
	movement_goal = goal
	movement = _direction(enemy,goal)
	return movement

func _direction(enemy: CharacterBody3D, goal: Vector3) -> Vector3:
	var from := enemy.global_position
	var direct := goal - from
	direct.y = 0
	if direct.length() < .3:
		return Vector3.ZERO
	if route_wait <= 0 or route_goal.distance_to(goal) > 1.5:
		route = _route(enemy, goal)
		route_goal = goal
		route_wait = .55 + float(enemy.get_instance_id() % 7) * .035
	# Direct shortcuts require the complete physical footprint to fit.
	var waypoint := goal
	if not _segment(enemy, from, goal, false):
		if route.is_empty():
			return Vector3.ZERO
		while route.size() > 1 and Vector2(from.x,from.z).distance_to(route[0]) < .4:
			route.remove_at(0)
		waypoint = Vector3(route[0].x,from.y,route[0].y)
		if from.distance_to(waypoint) < .4 and route.size() > 1:
			waypoint = Vector3(route[1].x,from.y,route[1].y)
	var desired := (waypoint - from).normalized()
	desired.y = 0
	if desired.length_squared() < .01:
		return Vector3.ZERO
	# Do not test beyond a near waypoint into the crate behind it. That would
	# reject a safe final approach and repeatedly turn away from the firing lane.
	var horizon := minf(clampf(enemy.move_speed * .45, .8, 1.8), maxf(.3,from.distance_to(waypoint)))
	var near_ally := false
	var separation := Vector3.ZERO
	var radius := body_radius(enemy)
	for ally in enemy.game.get_children():
		if ally == enemy or not ally is CharacterBody3D or ally == enemy.game.player or ally.collision_layer == 0:
			continue
		var offset: Vector3 = from - ally.global_position
		offset.y = 0
		var distance := offset.length()
		var clearance := radius + body_radius(ally) + .45
		if distance < clearance + horizon and distance > .01:
			near_ally = true
			separation += offset.normalized() * clampf((clearance + .5 - distance) / clearance, 0, 1)
	if not near_ally and _segment(enemy, from, from + desired * horizon):
		return desired
	var best := Vector3.ZERO
	var best_score := -INF
	# Keep one passing side until clear; both the slow and fast actor can yield.
	for angle in [0.0, side * .45, side * .85, side * 1.25, -side * .45, -side * .85, -side * 1.25, side * 1.65]:
		var candidate: Vector3 = desired.rotated(Vector3.UP, angle)
		if not _segment(enemy, from, from + candidate * horizon):
			continue
		var score := candidate.dot(desired) + candidate.dot(separation) * 1.5
		if angle * side > 0:
			score += .2
		if score > best_score:
			best_score = score
			best = candidate
	if best != Vector3.ZERO and side_wait <= 0:
		var turn := desired.cross(best).y
		if absf(turn) > .1:
			side = signf(turn)
			side_wait = 1.3
	return best

func firing_position(enemy: CharacterBody3D, target: Vector3, retreat: bool = false) -> Vector3:
	var from := enemy.global_position
	var visible := clear_shot(enemy,target)
	if retreat and not visible:
		return target
	# Reposition caches do not remain valid through closing doors or a moving target.
	if firing_wait > 0 and retreat == firing_retreat and firing_target.distance_to(target) < 1.5:
		if firing_goal == Vector3.INF:
			return target
		if firing_goal.distance_to(from) > .5 and _shot_from(enemy,firing_goal,target) and enemy.game.route(from,firing_goal).size() > 1:
			return firing_goal
	firing_wait = .85
	firing_target = target
	firing_retreat = retreat
	firing_goal = Vector3.INF
	var forward := target - from
	forward.y = 0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var best_score := -INF
	for distance in [2.0, 4.0, 6.0]:
		for lateral in [side, -side]:
			for back in [0.0, -1.0, 1.0]:
				var point: Vector3 = from + right * distance * lateral + forward * back * distance * .7
				var path: PackedVector2Array = enemy.game.route(from,point)
				if path.size() < 2 or not _shot_from(enemy, point,target):
					continue
				var endpoint := Vector3(path[-1].x,from.y,path[-1].y)
				if endpoint.distance_to(point) > 1 or not _segment(enemy, endpoint,point,false):
					continue
				if retreat and point.distance_to(target) < from.distance_to(target) + 1:
					continue
				var occupied := false
				for ally in enemy.game.get_children():
					if ally != enemy and ally is CharacterBody3D and ally.global_position.distance_to(point) < body_radius(enemy) + body_radius(ally) + .5:
						occupied = true
						break
				if occupied:
					continue
				var score: float = -float(path.size()) * .25 + (.3 if lateral == side else 0)
				if retreat:
					score += point.distance_to(target) * .4
				if score > best_score:
					best_score = score
					firing_goal = point
	return firing_goal if firing_goal != Vector3.INF else target
