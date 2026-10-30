extends Node3D
## Authored encounters, stage effects and cargo for the first three sectors.
const Kit = preload("res://scripts/common/kit.gd")
const PLANS := {
	1: {"labels": ["RESTABLECER ENERGÍA", "ANULAR SEGURIDAD", "TARJETA", "BALIZA DE EXTRACCIÓN", "SALIDA"], "points": [Vector3(22, .1, 4), Vector3(-3, .1, 1), Vector3(-24, .1, 2), Vector3(4, .1, -18), Vector3(0, .1, -23)], "guards": [0, 2, 4]},
	2: {"labels": ["CARGA A", "ENTREGAR CARGA A", "CARGA B", "ENTREGAR CARGA B", "GENERADOR DEL MUELLE", "AUTORIZAR TRANSPORTE", "INICIAR DEFENSA", "TRANSPORTE"], "points": [Vector3(-28, .1, 1), Vector3(-4, .1, -24), Vector3(28, .1, 1), Vector3(4, .1, -24), Vector3(24, .1, -18), Vector3(-24, .1, -18), Vector3(0, .1, 0), Vector3(0, .1, -26)], "guards": [0, 2, 4, 5]},
	3: {"labels": ["FUSIBLE OESTE", "FUSIBLE ESTE", "REPARAR REFRIGERACIÓN", "REGULAR PRESIÓN", "ESTABILIZAR REACTOR", "INICIAR PURGA", "RECUPERAR CARGA DE EVACUACIÓN", "EVACUACIÓN CON CARGA"], "points": [Vector3(-19, .1, 8), Vector3(19, .1, 8), Vector3(-17, .1, -4), Vector3(17, .1, -4), Vector3(-3, .1, -19), Vector3(3, .1, -19), Vector3(0, .1, 26), Vector3(25, .1, -17)], "guards": [0, 1, 4, 6, 7]}
}
var mission: Node
var stage: int = 0
var cargo: bool = false
var stage_started: bool = false
var signals: Array[MeshInstance3D] = []
var gate: StaticBody3D
var shutter_baseline: Dictionary = {}
const SHUTTER_POINT := Vector3(17, 0, -2)
const SHUTTER_SIZE := Vector3(4.2, 4.15, .4)

func _ready() -> void:
	var saved: Dictionary = Campaign.profile().get("checkpoint", {})
	if int(saved.get("level", -1)) == mission.game.level_number and int(saved.get("mission_version", 0)) == mission.MISSION_VERSION:
		cargo = bool(saved.get("cargo", false))
		stage_started = bool(saved.get("stage_started", false))
	stage = mission.done.size()
	mission.game.player.cargo_factor = 0.8 if cargo else 1.0
	for enemy in mission.game.get_children():
		if enemy is EnemyController:
			enemy.home_position = enemy.position
	# Two entry paths already exist in the reactor. A security shutter closes
	# one during evacuation, leaving the marked opposite gallery available.
	if mission.game.level_number == 3:
		gate = StaticBody3D.new()
		gate.name = "EmergencyShutter"
		# Seal the straight gallery, rather than the T junction at z = -6.
		gate.position = SHUTTER_POINT
		add_child(gate)
		Kit.box(gate, SHUTTER_SIZE, Vector3(0, 2.075, 0), Color("823c42"))
		Kit.model(gate, "Prop_AccessPoint", Vector3(3.9, 3.9, .45), Vector3(0, 2, 0), Color("f4a658"))
		Kit.collider(gate, SHUTTER_SIZE, Vector3(0, 2.075, 0))
		for x in range(15, 20):
			var cell := Vector2i(x, int(SHUTTER_POINT.z))
			shutter_baseline[cell] = mission.game.grid.is_point_solid(cell)
		set_shutter(mission.done.has(5))
	for index in range(mission.objective_count):
		var item: Node3D = mission.objects[index]
		signals.append(Kit.box(self, Vector3(.25, .15, .25), item.position + Vector3(0, 2.7, 0), Color("ffad4f"), true))
	# Small caches sit in optional side rooms and have no distant screen beacon.
	var secret: Vector3 = {1: Vector3(26, .1, 8), 2: Vector3(-28, .1, -25), 3: Vector3(-28, .1, -18)}[mission.game.level_number]
	mission.add_supply(secret, "RESERVA OCULTA")
	var cache = mission.objects.back()
	if mission.used_supplies.has(cache.object_id):
		cache.deactivate()
	if mission.game.level_number == 3:
		# Append after the existing cache to preserve its checkpoint identifier.
		mission.add_supply(Vector3(-4, .1, 26), "SUMINISTROS DE ACCESO")
		var initial_cache = mission.objects.back()
		if mission.used_supplies.has(initial_cache.object_id):
			initial_cache.deactivate()
	update_visibility()
	if not stage_started:
		start_stage()

func set_shutter(closed: bool) -> void:
	gate.visible = closed
	gate.collision_layer = 1 if closed else 0
	# Update the same grid used by player-route checks and enemy pathfinding.
	for cell in shutter_baseline:
		mission.game.grid.set_point_solid(cell, closed or bool(shutter_baseline[cell]))

func start_stage() -> void:
	stage_started = true
	var level: int = mission.game.level_number
	if stage >= mission.objective_count:
		return
	if PLANS[level].guards.has(stage):
		var point: Vector3 = mission.objects[stage].position
		var count: int = 2 if level == 1 or (level == 3 and stage == 6) else 3
		for index in range(guards_alive(), count):
			var kind: int = {1:[0,1],2:[0,2,3],3:[4,6,13]}[level][index]
			var enemy = load("res://scenes/actors/enemy_%d.tscn" % kind).instantiate()
			var location: Vector3 = mission.reachable(point + Vector3(3 + index * 2, 0, 3))
			if location.distance_to(mission.game.player.position) < 9:
				var candidates: Array[Vector3] = mission.valid_spawn_points()
				if not candidates.is_empty():
					location = candidates[0]
				else:
					enemy.free()
					continue
			enemy.position = location
			enemy.encounter_stage = stage
			enemy.max_health = 45 + level * 10 + index * 5
			enemy.attack_damage = 4 + level * 2
			mission.game.add_child(enemy)
			mission.game.enemy_count += 1
	update_visibility()

func guards_alive() -> int:
	var count := 0
	for enemy in mission.game.get_children():
		if enemy is EnemyController and enemy.is_threat() and enemy.encounter_stage == stage:
			count += 1
	return count

func interact(id: int) -> bool:
	if id != stage:
		mission.notify("Completa el objetivo activo antes de continuar", "")
		return false
	if guards_alive() > 0:
		mission.notify("ASEGURA EL SECTOR · %d defensores restantes" % guards_alive(), "")
		return false
	var level: int = mission.game.level_number
	if level == 3 and id == 7 and not cargo:
		mission.notify("Recupera la carga en la sala inicial antes de evacuar", "")
		return false
	if id == mission.objective_count - 1:
		if level == 2 and (mission.wave < mission.WAVE_SIZES.size() or mission.wave_remaining > 0 or mission.living_enemies() > 0):
			mission.notify("Completa las dos oleadas antes de abordar", "")
			return false
		if level == 3:
			mission.game.log_event("cargo_delivered", {"object_id":id,"title":mission.objects[id].title})
		mission.game.log_event("objective_completed",{"object_id":id,"title":mission.objects[id].title,"final":true})
		mission.game.end_game(true)
		return true
	if level == 2:
		if id in [0, 2]:
			cargo = true
		elif id in [1, 3]:
			cargo = false
			mission.notify("CARGA ENTREGADA\n" + mission.game.player.resupply(), "pickup_ammo")
		elif id == 6:
			mission.wave_wait = 5
		mission.game.player.cargo_factor = 0.8 if cargo else 1.0
	mission.done.append(id)
	mission.game.log_event("objective_completed",{"object_id":id,"title":mission.objects[id].title,"final":false})
	if mission.doors != null:
		mission.doors.sync()
	mission.objects[id].deactivate()
	stage += 1
	stage_started = false
	if level == 3 and id == 5:
		mission.timer = 180
		set_shutter(true)
		mission.notify("PURGA INICIADA · 180 s\nRecupera la carga en la sala inicial por la galería oeste y vuelve a evacuación", "pickup_key")
	elif level == 3 and id == 6:
		cargo = true
		mission.game.player.cargo_factor = .8
		mission.game.log_event("cargo_collected", {"object_id":id,"title":mission.objects[id].title})
		mission.notify("CARGA RECUPERADA · regresa a evacuación antes de que termine la purga", "pickup_key")
	elif level == 1 and id == 2:
		mission.notify("TARJETA OBTENIDA\nActiva la baliza: se aproxima una emboscada", "pickup_key")
	elif not (level == 2 and id in [1, 3]):
		mission.notify("%s · COMPLETADO\nPunto de control guardado" % mission.objects[id].title, "pickup_key")
	start_stage()
	mission.game.update_hud()
	mission.checkpoint()
	return true

func update_visibility() -> void:
	for index in range(mission.objective_count):
		var item = mission.objects[index]
		item.visible = index == stage
		item.collision_layer = 1 if index == stage and item.active else 0
		if index < signals.size():
			signals[index].material_override = Kit.material(Color("65ffc1") if mission.done.has(index) else Color("ffad4f"), true)

func describe() -> String:
	var objective: String = mission.objects[mini(stage, mission.objective_count - 1)].title
	var text := "MISIÓN · ETAPA %d/%d\n%s" % [mini(stage + 1, mission.objective_count), mission.objective_count, objective]
	if guards_alive() > 0:
		text += "\nAsegura el sector: %d defensores" % guards_alive()
	if cargo:
		text += "\nCARGA EN MANOS · movimiento al 80 %\nEntrega en el muelle; puedes usar tus armas."
	if mission.game.level_number == 2 and mission.done.has(6):
		text += "\nOLEADA %d/%d · enemigos %d" % [mission.wave, mission.WAVE_SIZES.size(), mission.living_enemies() + mission.wave_remaining]
		if mission.wave_wait >= 0:
			text += " · en %ds" % ceili(mission.wave_wait)
	if mission.timer > 0:
		text += "\nEVACUACIÓN %ds · usa la galería oeste" % ceili(mission.timer)
	text += "\nApunta y pulsa %s" % mission.key_name("interact")
	return text
