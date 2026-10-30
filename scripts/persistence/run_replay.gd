extends RefCounted
## Replay telemetry only: no changes to actors, collision or mission rules.
const INTERVAL := 0.5
var game: Node3D
var metadata: Dictionary
var frames: Array = []
var chunk_index := 0
var wait := 0.0
var ended := false
var extra_doors: Array[StaticBody3D] = []

func start(owner_game: Node3D) -> void:
	game = owner_game
	metadata = {"version":1,"level":game.level_number,"intervalSeconds":INTERVAL,
		"loadout":game.player.loadout.duplicate(),"map":capture_map()}
	queue_header()
	capture()
	flush()
	wait = INTERVAL
	publish_start()

func publish_start() -> void:
	game.get_node("/root/Campaign").flush_events()

func queue_header() -> void:
	game.get_node("/root/Campaign").events.replay_header(game._history_id,metadata)

func set_loadout(weapons: Array) -> void:
	metadata.loadout = weapons.duplicate()
	queue_header()

func tick(delta: float) -> void:
	if ended:
		return
	wait -= delta
	if wait <= 0:
		wait = INTERVAL
		capture()
		if frames.size() >= 4:
			flush()

func point(value: Vector3) -> Array:
	return [snappedf(value.x,.01),snappedf(value.z,.01)]

func capture() -> void:
	# Children leave the tree before the game receives _exit_tree. Keep the
	# last confirmed positions rather than reading detached global transforms.
	if not is_instance_valid(game.player) or not game.player.is_inside_tree():
		return
	var enemies: Array = []
	for actor in game.get_children():
		if actor is EnemyController and actor.health > 0 and actor.phase_left < 0:
			enemies.append({"id":str(actor.get_instance_id()),"kind":actor.kind,"boss":actor.boss,"p":point(actor.global_position)})
	var closed: Array = []
	if is_instance_valid(game.mission.doors):
		for gate in game.mission.doors.gates:
			if gate.closed:
				closed.append(str(gate.body.name))
	for door in extra_doors:
		if is_instance_valid(door) and door.collision_layer & 1:
			closed.append("extra:"+str(door.get_instance_id()))
	var time := snappedf(maxf(0,game.elapsed-game._history_elapsed_start),.001)
	var frame := {"t":time,"p":point(game.player.global_position),"enemies":enemies,"closedDoors":closed}
	# Final snapshots can share the last timestamp; retain only the latest state.
	if not frames.is_empty() and frames.back().t == time:
		frames[-1] = frame
	else:
		frames.append(frame)

func flush() -> void:
	if frames.is_empty():
		return
	game.get_node("/root/Campaign").events.replay_chunk(game._history_id,chunk_index,frames)
	chunk_index += 1
	frames.clear()

func checkpoint() -> void:
	if not ended:
		capture()
		flush()

func finish() -> void:
	if ended:
		return
	ended = true
	if is_instance_valid(game.player):
		capture()
	flush()

func polygon(collision: CollisionShape3D) -> Array:
	var half: Vector3 = collision.shape.size*.5
	var points: Array = []
	for corner in [Vector3(-half.x,0,-half.z),Vector3(half.x,0,-half.z),Vector3(half.x,0,half.z),Vector3(-half.x,0,half.z)]:
		points.append(point(collision.to_global(corner)))
	return points

func capture_map() -> Dictionary:
	var result := {"floors":[],"obstacles":[],"doors":[]}
	for body in game.get_node("Arena").find_children("*","StaticBody3D",true,false):
		for shape in body.get_children():
			if not shape is CollisionShape3D or not shape.shape is BoxShape3D or shape.disabled:
				continue
			var half_height: float = shape.shape.size.y*absf(shape.global_basis.y.y)*.5
			if str(body.name).begins_with("Floor"):
				result.floors.append({"points":polygon(shape)})
			elif shape.global_position.y-half_height < 2.8 and shape.global_position.y+half_height > .2:
				result.obstacles.append({"points":polygon(shape)})
	if is_instance_valid(game.mission.doors):
		for gate in game.mission.doors.gates:
			var collision: CollisionShape3D = null
			for child in gate.body.get_children():
				if child is CollisionShape3D:
					collision = child
			if collision != null:
				result.doors.append({"id":str(gate.body.name),"points":polygon(collision)})
	# Mission shutters live outside Arena and can change collision during a run.
	for door in game.find_children("*Shutter","StaticBody3D",true,false):
		extra_doors.append(door)
		for child in door.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				result.doors.append({"id":"extra:"+str(door.get_instance_id()),"points":polygon(child)})
	return result
