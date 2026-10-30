extends SceneTree
const Catalog = preload("res://scripts/enemies/enemy_catalog.gd")
class TestSector extends Node3D:
	var level_number := 10
	var finished := true

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var campaign := root.get_node("Campaign")
	var original_difficulty: int = campaign.options.difficulty
	var sector := TestSector.new()
	root.add_child(sector)
	var mission := Node.new()
	mission.set_script(load("res://scripts/missions/mission.gd"))
	mission.game = sector
	for difficulty in range(3):
		campaign.options.difficulty = difficulty
		var snapshots: Array = []
		for kind in [0, 2, 8, 13, 15, 12]:
			var actor: EnemyController = load("res://scenes/actors/enemy_%d.tscn" % kind).instantiate()
			actor.name = "HealthTest%d" % kind
			actor.boss = kind == 12
			if actor.boss:
				actor.max_health = 900
			var base: int = actor.max_health
			var durability: float = 1.0 if actor.boss else {2:1.6,8:1.85,11:1.4,13:1.15,15:1.15}.get(kind,1.0)
			var expected: int = roundi(roundi(base * durability) * Catalog.DIFFICULTY[difficulty].health)
			sector.add_child(actor)
			actor.set_physics_process(false)
			assert(actor.max_health == expected and actor.health == expected, "Difficulty health combines with role durability")
			actor.apply_difficulty()
			assert(actor.max_health == expected, "Health multiplier applies once")
			actor.health -= 23
			snapshots.append({"scene":actor.scene_file_path,"name":str(actor.name),"kind":kind,"position":actor.position,"scale":actor.scale,"health":actor.health,"max_health":actor.max_health,"damage":actor.attack_damage,"speed":actor.move_speed,"interval":actor.attack_interval,"range":actor.attack_range,"warning":actor.warning_duration,"boss":actor.boss})
		var path := "res://.godot/difficulty-health-snapshot.bin"
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_var(snapshots)
		file.close()
		file = FileAccess.open(path, FileAccess.READ)
		var saved: Array = file.get_var()
		file.close()
		mission.restore_enemies(saved)
		for snapshot in saved:
			var actor: EnemyController = sector.get_node(NodePath(snapshot.name))
			actor.set_physics_process(false)
			assert(actor.max_health == snapshot.max_health and actor.health == snapshot.health, "Disk snapshot preserves damaged current and maximum health")
			assert(actor.difficulty_applied)
			actor.apply_difficulty()
			assert(actor.max_health == snapshot.max_health, "Restored health never scales twice")
		for actor in sector.get_children():
			actor.queue_free()
		await process_frame
		print("PASS: health scaling and disk restore difficulty %d, including heavies, shield and boss" % difficulty)
	campaign.options.difficulty = original_difficulty
	mission.free()
	sector.queue_free()
	await process_frame
	quit()
