extends RigidBody3D
const Kit = preload("res://scripts/common/kit.gd")
const Catalog = preload("res://scripts/combat/grenade_catalog.gd")
var grenade_type: String = "basic"
var detonated: bool = false
var fuse: float = 1.6

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if not Catalog.DATA.has(grenade_type):
		grenade_type = "basic"
	fuse = float(Catalog.DATA[grenade_type].fuse)
	collision_layer = 0
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.12
	collision.shape = sphere
	add_child(collision)
	Kit.box(self, Vector3(.20, .24, .20), Vector3.ZERO, Catalog.DATA[grenade_type].color)
	Kit.box(self, Vector3(.08, .05, .10), Vector3(0, .14, 0), Color("60717b"))
	add_collision_exception_with(get_parent().player)

func _physics_process(delta: float) -> void:
	if get_parent().finished:
		queue_free()
		return
	fuse -= delta
	if fuse > 0:
		return
	detonate()

func detonate() -> void:
	if detonated:
		return
	detonated = true
	if get_parent().has_method("log_event"):
		get_parent().log_event("grenade_exploded",{"grenade":grenade_type,"position":[global_position.x,global_position.y,global_position.z]})
	var data: Dictionary = Catalog.DATA[grenade_type]
	var player: Node3D = get_parent().get("player")
	if is_instance_valid(player):
		var player_distance: float = global_position.distance_to(player.global_position)
		var shake_reach: float = float(data.radius) * 1.5
		var proximity: float = clampf(1.0 - player_distance / shake_reach, 0.0, 1.0)
		var shake_strength: float = {"basic": .105, "fragmentation": .19, "slow": .12}.get(grenade_type, .1)
		var shake_duration: float = {"basic": .24, "fragmentation": .34, "slow": .28}.get(grenade_type, .24)
		if player.has_method("apply_camera_shake"):
			player.apply_camera_shake(shake_strength * proximity, shake_duration)
		if grenade_type == "slow" and player_distance <= 3.0 and player.has_method("apply_stasis_slow"):
			var slow_sight := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position, player.global_position + Vector3.UP, 1, [get_rid()]))
			if slow_sight.is_empty() or slow_sight.collider == player:
				player.apply_stasis_slow(3.0, .55)
		var player_target: Vector3 = player.global_position + Vector3.UP
		var player_damage_distance: float = global_position.distance_to(player_target)
		if player_damage_distance <= float(data.radius):
			var damage_sight := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position, player_target, 1, [get_rid()]))
			if damage_sight.is_empty() or damage_sight.collider == player:
				var player_damage: int = roundi(float(data.damage) * maxf(0.0, 1.0 - player_damage_distance / float(data.falloff)))
				if player_damage > 0 and player.has_method("take_damage"):
					player.take_damage(player_damage)
	for enemy in get_parent().get_children():
		if not enemy is Node3D or enemy == get_parent().player or not enemy.has_method("take_damage"):
			continue
		if enemy is EnemyController and (enemy.health <= 0 or enemy.phase_left >= 0):
			continue
		var target: Vector3 = enemy.global_position + Vector3.UP
		var distance := global_position.distance_to(target)
		if distance > float(data.radius):
			continue
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position, target, 1, [get_rid()]))
		if hit.is_empty() or hit.collider == enemy:
			if grenade_type == "slow" and enemy.has_method("apply_slow"):
				enemy.apply_slow(float(data.duration), float(data.factor))
			var damage := roundi(float(data.damage) * (1 - distance / float(data.falloff)))
			if enemy is EnemyController:
				enemy.take_damage(damage,{"source":"grenade","grenade":grenade_type})
			else:
				enemy.take_damage(damage)
	var effect := Kit.box(get_parent(), Vector3.ONE * (2.5 if grenade_type == "slow" else 2), global_position, data.color, true)
	get_tree().create_timer(.28 if grenade_type == "slow" else .18, false).timeout.connect(effect.queue_free)
	# Explosion survives projectile deletion and the final-result pause.
	var sound := AudioStreamPlayer3D.new()
	sound.name = "GrenadeExplosion"
	sound.process_mode = Node.PROCESS_MODE_ALWAYS
	sound.stream = load("res://assets/audio/grenades/%s_explode.wav" % grenade_type)
	sound.bus = &"Effects"
	sound.volume_db = -8
	sound.max_distance = 65
	sound.unit_size = 12
	get_parent().add_child(sound)
	sound.global_position = global_position
	sound.finished.connect(sound.queue_free)
	sound.play()
	queue_free()
