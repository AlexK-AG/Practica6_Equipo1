extends SceneTree
const Steering = preload("res://scripts/enemies/enemy_steering.gd")
class Actor extends CharacterBody3D:
	var game: Node3D
	var move_speed := 3.5
class Arena extends Node3D:
	var player: CharacterBody3D
	func route(from: Vector3, to: Vector3) -> PackedVector2Array:
		return PackedVector2Array([Vector2(from.x,from.z),Vector2(to.x,to.z)])
	func pursuit_route(from: Vector3, to: Vector3) -> PackedVector2Array:
		return route(from,to)
	func navigation_segment_clear(_from: Vector3,_to: Vector3,_radius: float = 0) -> bool:
		return true
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func actor(arena: Arena, point: Vector3, width: float = .85) -> Actor:
	var body := Actor.new()
	body.game = arena
	body.position = point
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width,1.8,width)
	shape.shape = box
	shape.position.y = .9
	body.add_child(shape)
	arena.add_child(body)
	return body
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena := Arena.new()
	root.add_child(arena)
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(40,.2,40)
	floor_collision.shape = floor_box
	floor_body.position.y = -.1
	floor_body.add_child(floor_collision)
	arena.add_child(floor_body)
	var player := actor(arena,Vector3(0,0,-12))
	arena.player = player
	var tank := actor(arena,Vector3.ZERO,1.4)
	var runner := actor(arena,Vector3(0,0,3))
	var steering := Steering.new()
	steering.setup(runner)
	await physics_frame
	await physics_frame
	check(not steering.clear_shot(runner,player.position),"Tank must block the initial shot")
	var firing: Vector3 = steering.firing_position(runner,player.position)
	check(firing != player.position and absf(firing.x) > 1,"Blocked sniper should select a lateral firing lane")
	var max_lateral := 0.0
	var min_distance := INF
	for tick in range(240):
		var movement: Vector3 = steering.direction(runner,player.position,1.0/60)
		runner.velocity = movement * runner.move_speed
		runner.move_and_slide()
		max_lateral = maxf(max_lateral,absf(runner.position.x))
		min_distance = minf(min_distance,runner.position.distance_to(tank.position))
		await physics_frame
	check(runner.position.z < -2,"Fast kamikaze should overtake the stationary tank")
	check(max_lateral > 1,"Overtaking should use a lateral lane")
	check(min_distance > 1.0,"Overtaking must not pass through the tank")
	check(steering.clear_shot(runner,player.position),"Runner should regain a clear player shot")
	# A sealed passage blocks both movement and shots; avoidance cannot phase through.
	var door := StaticBody3D.new()
	var door_collision := CollisionShape3D.new()
	var door_box := BoxShape3D.new()
	door_box.size = Vector3(30,3,.3)
	door_collision.shape = door_box
	door.add_child(door_collision)
	door.position = Vector3(0,1.5,-9)
	arena.add_child(door)
	runner.position = Vector3(0,0,-5)
	await physics_frame
	await physics_frame
	check(not steering.clear_shot(runner,player.position),"Closed door must block the shot")
	check(not steering._segment(runner,runner.position,player.position),"Swept direction must not cross a closed door")
	check(steering.firing_position(runner,player.position,true) == player.position,"Blind sniper must pursue rather than retreat")
	door.queue_free()
	await physics_frame
	# The shape sweep must account for the real scaled footprint near a wall.
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(.2,3,20)
	collider.shape = wall_box
	wall.add_child(collider)
	wall.position = Vector3(2,1.5,0)
	arena.add_child(wall)
	runner.position = Vector3(0,0,2)
	runner.scale = Vector3(2,1,2)
	await physics_frame
	await physics_frame
	check(is_equal_approx(steering.body_radius(runner),.85),"Radius should include collision world scaling")
	check(not steering._segment(runner,runner.position,Vector3(1.5,0,2)),"Swept actor footprint must reject a wall collision")
	arena.queue_free()
	await process_frame
	print("ENEMY STEERING: %d failures" % failures)
	quit(0 if failures == 0 else 1)
