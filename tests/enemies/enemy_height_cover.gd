extends SceneTree
const Kit = preload("res://scripts/common/kit.gd")
var failures := 0
class PlayerFixture extends CharacterBody3D:
	var camera: Camera3D
	var health := 10000
	func take_damage(amount: int) -> void:
		health -= amount
class ArenaFixture extends Node3D:
	var player: PlayerFixture
	var level_number := 8
	var finished := false
	var mission: Node
	var grid := AStarGrid2D.new()
	func pursuit_route(from: Vector3,to: Vector3) -> PackedVector2Array:
		return grid.get_point_path(Vector2i(roundi(from.x),roundi(from.z)),Vector2i(roundi(to.x),roundi(to.z)))
	func route(from: Vector3,to: Vector3) -> PackedVector2Array:
		return pursuit_route(from,to)
	func navigation_segment_clear(from: Vector3,to: Vector3,_radius: float=0) -> bool:
		return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from+Vector3.UP,to+Vector3.UP,1)).is_empty()
	func beam(_a: Vector3,_b: Vector3,_c: Color) -> void:
		pass
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	root.get_node("Campaign").save_path = "res://.godot/height-cover-private.cfg"
	var arena := ArenaFixture.new()
	root.add_child(arena)
	arena.grid.region = Rect2i(-20,-20,41,41)
	arena.grid.update()
	for x in range(-1,2):
		for z in range(-1,2):
			arena.grid.set_point_solid(Vector2i(x,z))
	var floor_body := StaticBody3D.new()
	arena.add_child(floor_body)
	Kit.collider(floor_body,Vector3(40,.2,40),Vector3(0,-.1,0))
	var lower := StaticBody3D.new()
	arena.add_child(lower)
	Kit.collider(lower,Vector3(1.8,1.3,1.8),Vector3(0,.65,0))
	var upper := StaticBody3D.new()
	arena.add_child(upper)
	Kit.collider(upper,Vector3(1.8,1.3,1.8),Vector3(0,1.95,0))
	var upper_shape: CollisionShape3D = upper.get_child(0)
	arena.player = PlayerFixture.new()
	arena.player.position = Vector3(0,.01,-3)
	arena.add_child(arena.player)
	Kit.collider(arena.player,Vector3(.7,1.8,.7),Vector3(0,.9,0))
	arena.player.camera = Camera3D.new()
	arena.player.camera.position.y = 1.6
	arena.player.add_child(arena.player.camera)
	for kind in range(18):
		var enemy: EnemyController = load("res://scenes/actors/enemy_%d.tscn" % kind).instantiate()
		enemy.position = Vector3(0,.01,5)
		arena.add_child(enemy)
		enemy.set_physics_process(false)
		upper_shape.disabled = true
		await physics_frame
		await physics_frame
		var tall: bool = enemy.steering.body_height(enemy)>1.3001
		var can_fire: bool = enemy.steering.clear_shot(enemy,arena.player.position)
		check(can_fire == tall,"Single crate: tall enemy sees exposed head; small enemy remains covered kind%d" % kind)
		check(enemy.tactics.can_see_player(enemy) == tall,"Perception agrees with height-aware firing kind%d" % kind)
		enemy.tactics.visible_cache = enemy.tactics.can_see_player(enemy)
		var health := arena.player.health
		enemy.fire_at_player()
		check((arena.player.health<health)==tall,"Real shot only damages over single crate for tall enemy kind%d" % kind)
		if not tall:
			check(is_equal_approx(enemy.steering.firing_height(enemy),.8),"Small enemy retains its original firing height")
		upper_shape.disabled = false
		await physics_frame
		await physics_frame
		check(not enemy.steering.clear_shot(enemy,arena.player.position),"Double crate blocks direct fire kind%d" % kind)
		check(not enemy.tactics.can_see_player(enemy),"Double crate blocks perception kind%d" % kind)
		health = arena.player.health
		enemy.fire_at_player()
		check(arena.player.health==health,"No damage through double crate kind%d" % kind)
		enemy.alerted = true
		enemy.tactics.has_memory = true
		enemy.tactics.last_seen = arena.player.position
		enemy.tactics.memory_left = 0
		enemy._physics_process(1.0/60)
		check(enemy.search.initialized,"Hidden target activates existing shared search kind%d" % kind)
		print("HEIGHT COVER kind=",kind," height=",enemy.steering.body_height(enemy)," tall=",tall)
		arena.remove_child(enemy)
		enemy.free()
	arena.queue_free()
	await process_frame
	# These are authored nodes, so they are visible and editable in Godot.
	var stacks := 0
	for level in range(1,11):
		var path := "res://scenes/main.tscn" if level==1 else "res://scenes/levels/level_%d.tscn" % level
		var game = load(path).instantiate()
		var count := 0
		for body in game.get_node("Arena").get_children():
			if not str(body.name).begins_with("DoubleCover"):
				continue
			count += 1
			var base_name: String = str(body.name).trim_prefix("Double").trim_suffix("Upper")
			var base = game.get_node("Arena").get_node(base_name)
			var lower_collision: CollisionShape3D = base.get_node("Collision")
			var upper_collision: CollisionShape3D = body.get_node("Collision")
			check(body.position.is_equal_approx(base.position+Vector3.UP*lower_collision.shape.size.y),"Upper crate rests exactly on lower crate level%d" % level)
			check(upper_collision.shape.size==lower_collision.shape.size,"Double cover uses matching solid collision level%d" % level)
			check(body.position.y+upper_collision.shape.size.y*.5>=2.59,"Stack reaches 2.6m level%d" % level)
		check(count>0,"Every campaign level has tall cover")
		stacks += count
		game.free()
	check(stacks==26,"Twenty-six sparse double crates are authored across campaign")
	await process_frame
	print("HEIGHT COVER: %d failures; %d double crates" % [failures,stacks])
	quit(1 if failures else 0)
