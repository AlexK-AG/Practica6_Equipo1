extends RefCounted
## Bounded investigation of observed information; never reads player coordinates.
var initialized := false
var anchor := Vector3.ZERO
var phase := 0 # Approach, inspect nearby positions, return to guard.
var point := Vector3.ZERO
var points: Array[Vector3] = []
var cursor := 0
var elapsed := 0.0
var stationary := 0.0
var previous := Vector3.ZERO
var route_wait := 0.0
var lane_wait := 0.0
var give_up := false

func observe(position: Vector3) -> void:
	initialized = false
	anchor = position
	phase = 0
	points.clear()
	cursor = 0
	elapsed = 0
	stationary = 0
	give_up = false

func eligible(e) -> bool:
	if e.boss or not e.alerted or not e.tactics.has_memory:
		return false
	if e.tactics.channel != "" or e.tactics.charge_state != "":
		return false
	if e.kind == 17 and e.phase_wait < 1.2:
		return false
	if e.kind == 12 and e.tactics.memory_left > 0:
		return false # Finish the announced suppression before investigating.
	if e.kind in [2,13] and e.tactics.support_ally(e) != null:
		return false
	if e.kind in [4,10] and e.tactics.rear_ally(e,e.tactics.last_seen) != null:
		return false
	if e.kind in [8,15] and not e.tactics.nearby_allies(e,9).is_empty():
		return false
	return true

func investigate(e, observed: Vector3, delta: float) -> Vector3:
	if not initialized or anchor.distance_to(observed) > 1:
		observe(observed)
		initialized = true
		point = anchor
		previous = e.global_position
		lane_wait = 0
	elapsed += delta
	route_wait -= delta
	if e.global_position.distance_to(previous) < .006:
		stationary += delta
	else:
		stationary = 0
	previous = e.global_position
	if phase == 0:
		lane_wait -= delta
		# Revalidate a remembered firing lane as allies move through it.
		# The steering cache keeps an unobstructed destination stable.
		if lane_wait <= 0 and e.kind in [0,1,6,7,12,14,16,17]:
			lane_wait = .85
			point = e.steering.firing_position(e,anchor)
		if e.global_position.distance_to(point) < 1.2 or stationary > 1.3 or elapsed > 18:
			phase = 1
			elapsed = 0
			stationary = 0
			points = inspection_points(e)
			cursor = 0
			route_wait = 0
		else:
			return point
	if phase == 1:
		if elapsed > 20 or cursor >= mini(10,points.size()):
			phase = 2
			elapsed = 0
		else:
			point = points[cursor]
			var reached: bool = e.global_position.distance_to(point) < .8
			var failed := stationary > 1.3
			if route_wait <= 0:
				route_wait = .65
				failed = failed or path_to(e,point).is_empty()
			if reached or failed:
				cursor += 1
				stationary = 0
				route_wait = 0
				return investigate(e,observed,0)
			return point
	if e.global_position.distance_to(e.home_position) < 1 or elapsed > 12 or path_to(e,e.home_position).is_empty():
		give_up = true
		return e.global_position
	return e.home_position

func path_to(e, position: Vector3) -> PackedVector2Array:
	return e.game.pursuit_route(e.global_position,position)

func inspection_points(e) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var directions := [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK,
		Vector3(-1,0,-1).normalized(),Vector3(1,0,1).normalized(),
		Vector3(-1,0,1).normalized(),Vector3(1,0,-1).normalized()]
	for radius in [2.0,4.0,6.0,8.0]:
		for direction in directions:
			var candidate: Vector3 = anchor + direction*radius
			candidate = Vector3(roundf(candidate.x),e.global_position.y,roundf(candidate.z))
			var cell := Vector2i(roundi(candidate.x),roundi(candidate.z))
			if not e.game.grid.is_in_boundsv(cell) or e.game.grid.is_point_solid(cell):
				continue
			if candidate.distance_to(e.global_position) < .9 or result.has(candidate) or not standable(e,candidate):
				continue
			var path: PackedVector2Array = path_to(e,candidate)
			if path.size() < 2 or path.size() > 34:
				continue
			result.append(candidate)
	# Nearby probes first, then widen the search. A stable order avoids oscillation.
	result.sort_custom(func(a: Vector3,b: Vector3) -> bool:
		return a.distance_squared_to(e.global_position) < b.distance_squared_to(e.global_position))
	return result

func standable(e, position: Vector3) -> bool:
	var exclusions: Array[RID] = []
	for actor in e.game.get_children():
		if actor is CharacterBody3D:
			exclusions.append(actor.get_rid())
	for child in e.get_children():
		if not child is CollisionShape3D or child.disabled or child.shape == null:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = child.shape
		query.transform = child.global_transform
		query.transform.origin += position-e.global_position + Vector3.UP*.05
		query.collision_mask = 1
		query.exclude = exclusions
		if not e.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			return false
	return true

func capture_state() -> Dictionary:
	return {"initialized":initialized,"anchor":anchor,"phase":phase,"point":point,
		"points":points.duplicate(),"cursor":cursor,"elapsed":elapsed,
		"stationary":stationary,"previous":previous,"route_wait":route_wait,"lane_wait":lane_wait,"give_up":give_up}

func restore_state(data: Dictionary) -> void:
	for property in capture_state():
		if data.has(property):
			if property == "points":
				points.assign(data[property])
			else:
				set(property,data[property])
	route_wait = 0 # Revalidate gates and paths in the restored physical world.
