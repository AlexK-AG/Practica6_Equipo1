extends Node3D
## Campaign stages preserve the identity of each sector while adding encounters.
const Kit = preload("res://scripts/common/kit.gd")
const PLANS := {
	4: {"labels": ["FUSIBLE INDUSTRIAL", "BOMBA DE REFRIGERACIÓN", "CONTROL DEL HORNO", "CONTROL DE PRENSAS", "CONTROL DE PASARELA", "ABRIR MONTACARGAS", "APAGAR FRAGUA", "DESACTIVAR HORNO DE EMERGENCIA", "SALIDA"], "points": [Vector3(-26,.1,5),Vector3(2,.1,5),Vector3(25,.1,5),Vector3(25,.1,-23),Vector3(0,.1,-23),Vector3(-24,.1,-20),Vector3(-27,.1,-24),Vector3(25,.1,5),Vector3(-27,.1,-24)], "guards": [0,2,4,6,7], "kinds": [7,13,14], "secret": Vector3(-29,.1,-18)},
	5: {"labels": ["MUESTRA BIOLÓGICA", "SELLAR CUARENTENA", "NIDO OESTE", "NIDO ESTE", "NIDO CENTRAL", "INICIAR PURGA", "EXTRACCIÓN"], "points": [Vector3(-25,.1,8),Vector3(0,.1,12),Vector3(-27,.1,0),Vector3(27,.1,0),Vector3(0,.1,-15),Vector3(-25,.1,-25),Vector3(26,.1,-25)], "guards": [0,2,3,4,6], "kinds": [8,9,16], "secret": Vector3(-30,.1,-26)},
	6: {"labels": ["RECONOCER BASTIÓN", "DEFENSA OESTE", "DEFENSA ESTE", "LLAVE DE MANDO OESTE · 1/3", "LLAVE DE MANDO ESTE · 2/3", "LLAVE DE MANDO CENTRAL · 3/3", "ASEGURAR AL CAPITÁN", "ACCESO AL NÚCLEO"], "points": [Vector3(0,.1,7),Vector3(-25,.1,10),Vector3(25,.1,10),Vector3(-23,.1,-17),Vector3(25,.1,10),Vector3(0,.1,7),Vector3(0,.1,-23),Vector3(5,.1,-25)], "guards": [0,1,2,3,4,5], "kinds": [8,10,15], "secret": Vector3(-27,.1,-20)},
	7: {"labels": ["ENLACE OESTE", "REPETIDOR CENTRAL", "ENLACE ESTE", "ALIMENTAR GENERADOR", "INICIAR TRANSMISIÓN", "CONFIRMAR ENVÍO", "EXTRACCIÓN"], "points": [Vector3(-28,.1,4),Vector3(0,.1,-19),Vector3(28,.1,4),Vector3(0,.1,12),Vector3(27,.1,-25),Vector3(24,.1,-23),Vector3(-28,.1,-25)], "guards": [0,1,2,3,6], "kinds": [7,11,17], "secret": Vector3(-30,.1,-27)},
	8: {"labels": ["COMBUSTIBLE OESTE", "ENTREGAR COMBUSTIBLE A", "COMBUSTIBLE ESTE", "ENTREGAR COMBUSTIBLE B", "AUTORIZACIÓN DE VUELO", "INICIAR CARGA", "EMBARQUE"], "points": [Vector3(-29,.1,1),Vector3(-3,.1,-5),Vector3(29,.1,-12),Vector3(3,.1,-5),Vector3(-28,.1,25),Vector3(0,.1,-12),Vector3(3,.1,-33)], "guards": [0,2,4,6], "kinds": [9,12,16], "secret": Vector3(32,.1,-16)},
	9: {"labels": ["NÚCLEO OESTE", "NÚCLEO CENTRAL", "NÚCLEO ESTE", "SINCRONIZAR PLASMA", "SELLAR ARSENAL", "ASEGURAR SALIDA DEL ARSENAL", "RECUPERAR CARGA DEL ARSENAL", "ENTREGAR CARGA Y SALIR"], "points": [Vector3(-25,.1,3),Vector3(15,.1,-24),Vector3(26,.1,3),Vector3(-18,.1,-23),Vector3(27,.1,26),Vector3(25,.1,29),Vector3(-25,.1,26),Vector3(25,.1,29)], "guards": [0,1,2,4], "kinds": [12,15,17], "secret": Vector3(-29,.1,-24)},
	10: {"labels": ["AUTORIZACIÓN ÁUREA", "AISLAR LA ESTACIÓN", "ENERGÍA OESTE", "ENERGÍA ESTE", "ENERGÍA SUR", "DESCARGAR EL NÚCLEO", "SALIDA FINAL"], "points": [Vector3(-26,.1,18),Vector3(26,.1,18),Vector3(-9,.1,-13),Vector3(9,.1,-13),Vector3(0,.1,-2),Vector3(0,.1,-18),Vector3(0,.1,-36)], "guards": [0,1,2,3,4,6], "kinds": [11,16,17], "secret": Vector3(29,.1,-16)}
}
var mission: Node
var stage: int = 0
var cargo: bool = false
var stage_started: bool = false
var signals: Array[MeshInstance3D] = []
var safety_gate: StaticBody3D
var defense: RefCounted
var delivery: RefCounted

func _ready() -> void:
	stage = mission.done.size()
	var saved: Dictionary = Campaign.profile().get("checkpoint", {})
	if int(saved.get("level", -1)) == mission.game.level_number and int(saved.get("mission_version", 0)) == mission.MISSION_VERSION:
		cargo = bool(saved.get("cargo", false))
		stage_started = bool(saved.get("stage_started", false))
	mission.game.player.cargo_factor = .8 if cargo else 1.0
	for enemy in mission.game.get_children():
		if enemy is EnemyController:
			enemy.home_position = enemy.position
	for index in range(mission.objective_count):
		var point: Vector3 = mission.objects[index].position
		signals.append(Kit.box(self, Vector3(.3,.16,.3), point + Vector3(0,2.8,0), Color("ffbb6b"), true))
	mission.add_supply(PLANS[mission.game.level_number].secret, "RESERVA OCULTA")
	var cache = mission.objects.back()
	if mission.used_supplies.has(cache.object_id):
		cache.deactivate()
	if mission.game.level_number == 5:
		mission.add_supply(Vector3(-4,.1,29), "SUMINISTROS DE ACCESO")
		var initial_cache = mission.objects.back()
		if mission.used_supplies.has(initial_cache.object_id):
			initial_cache.deactivate()
	make_details()
	if mission.game.level_number==8:
		defense = preload("res://scripts/missions/hangar_defense.gd").new()
		defense.setup(self)
	if mission.game.level_number==9:
		delivery = preload("res://scripts/missions/arsenal_delivery.gd").new()
		delivery.setup(self)
	update_effects()
	update_visibility()
	if not stage_started:
		start_stage()

func make_details() -> void:
	var level: int = mission.game.level_number
	var palettes := {4: Color("ffa45b"),5: Color("d58caf"),6: Color("d7a68e"),7: Color("e9cf7a"),8: Color("7cd6d1"),9: Color("bd9de8"),10: Color("f7d56b")}
	for index in range(mission.objective_count):
		var item = mission.objects[index]
		Kit.model(self, "Prop_Computer" if level in [7,9] else "Prop_Vent_Big", Vector3(.7,1.1,.35), item.position + Vector3(-1.4,.65,0), palettes[level])
	# The foundry's direct northern passage unlocks after controlling its furnaces;
	# its west gallery remains an alternative route throughout.
	if level == 4:
		safety_gate = StaticBody3D.new()
		safety_gate.name = "ThermalShutter"
		safety_gate.position = Vector3(24,0,-10)
		add_child(safety_gate)
		Kit.model(safety_gate,"Prop_AccessPoint",Vector3(3.7,3.8,.3),Vector3(0,1.9,0),palettes[level])
		Kit.collider(safety_gate,Vector3(3.7,3.8,.3),Vector3(0,1.9,0))
		var closed: bool = not mission.done.has(2)
		safety_gate.visible = closed
		safety_gate.collision_layer = 1 if closed else 0
		for x in range(23,26):
			mission.game.grid.set_point_solid(Vector2i(x,-10),closed)

func update_effects() -> void:
	var level: int = mission.game.level_number
	if level == 6:
		var captain = mission.game.get_node_or_null("FortressCaptain")
		if is_instance_valid(captain):
			captain.invulnerable = not (mission.done.has(1) and mission.done.has(2))
			captain.update_title()
	if level == 10:
		var boss = mission.game.get_node_or_null("FinalBoss")
		if is_instance_valid(boss) and boss.health > 0:
			if boss.health <= floori(boss.max_health * .33):
				mission.boss_phase = 2
				if not boss.boss_enraged:
					boss.attack_interval *= .78
					boss.boss_enraged = true
			elif boss.health <= floori(boss.max_health * .66):
				mission.boss_phase = maxi(1,mission.boss_phase)
			boss.invulnerable = not mission.done.has(2 + mission.boss_phase)
			boss.update_title()

func start_stage() -> void:
	stage_started = true
	var level: int = mission.game.level_number
	if stage >= mission.objective_count:
		return
	if PLANS[level].guards.has(stage):
		var count: int = 4 if level == 4 and stage == 7 else 3
		for index in range(guards_alive(), count):
			var kind: int = PLANS[level].kinds[(index + stage) % 3]
			var enemy = load("res://scenes/actors/enemy_%d.tscn" % kind).instantiate()
			var point: Vector3 = mission.reachable(mission.objects[stage].position + Vector3(3 + index * 2,0,3))
			if point.distance_to(mission.game.player.position) < 10:
				var alternatives: Array[Vector3] = mission.valid_spawn_points()
				if alternatives.is_empty():
					enemy.free()
					continue
				point = alternatives[0]
			enemy.position = point
			enemy.encounter_stage = stage
			enemy.max_health = 55 + level * 7 + index * 8
			enemy.attack_damage = 5 + level
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
	var level: int = mission.game.level_number
	if id != stage:
		mission.notify("Completa primero el objetivo activo", "")
		return false
	if delivery != null and delivery.handles(id):
		return delivery.interact(id)
	if guards_alive() > 0:
		mission.notify("ASEGURA EL SECTOR · %d defensores" % guards_alive(), "")
		return false
	if level in [7,8] and id == (5 if level == 7 else 6) and mission.defense_time != 0:
		mission.notify("La defensa sigue en curso", "")
		return false
	if level == 5 and id == 6 and mission.defense_time != 0:
		mission.notify("Espera a que termine la purga", "")
		return false
	if level == 6 and id == 6:
		var captain = mission.game.get_node_or_null("FortressCaptain")
		if is_instance_valid(captain) and captain.health > 0:
			mission.notify("Elimina al capitán para asegurar el mando", "")
			return false
	if level == 10:
		update_effects()
		if id in [3,4] and mission.boss_phase < id - 2:
			mission.notify("Debilita al Guardián para habilitar esta fuente", "")
			return false
		if id == 5:
			var boss = mission.game.get_node_or_null("FinalBoss")
			if is_instance_valid(boss) and boss.health > 0:
				mission.notify("Derrota al Guardián antes de descargar el núcleo", "")
				return false
	if id == mission.objective_count - 1:
		if level in [5,6,9,10] and mission.living_enemies() > 0:
			mission.notify("Elimina las amenazas restantes", "")
			return false
		mission.game.log_event("objective_completed",{"object_id":id,"title":mission.objects[id].title,"final":true})
		mission.game.end_game(true)
		return true
	mission.done.append(id)
	mission.game.log_event("objective_completed",{"object_id":id,"title":mission.objects[id].title,"final":false})
	if mission.doors != null:
		mission.doors.sync()
	mission.objects[id].deactivate()
	if level == 8:
		if id in [0,2]:
			cargo = true
		elif id in [1,3]:
			cargo = false
		mission.game.player.cargo_factor = .8 if cargo else 1.0
	if (level == 7 and id == 4) or (level == 8 and id == 5) or (level == 5 and id == 5):
		mission.defense_time = {5:90.0,7:45.0,8:120.0}[level]
		mission.reinforcements_left = randi_range(5,6) if level == 5 else {7:7,8:9}[level]
		mission.nest_wait = 4
		if level==8:
			defense.begin()
	if level == 4 and id == 6:
		mission.timer = 120
	elif level == 4 and id == 7:
		mission.timer = -1
		mission.game.log_event("furnace_disabled", {"object_id":id})
	if level == 4 and id == 2:
		safety_gate.hide()
		safety_gate.collision_layer = 0
		for x in range(23,26):
			mission.game.grid.set_point_solid(Vector2i(x,-10),false)
	var receipt := ""
	if id % 3 == 2 or (level == 8 and id in [1,3]):
		receipt = "\n" + mission.game.player.resupply()
	stage += 1
	stage_started = false
	update_effects()
	start_stage()
	mission.game.update_hud()
	if level == 4 and id == 6:
		mission.notify("EMERGENCIA · 120 s\nVuelve al horno del ala este y desactívalo antes de que termine el tiempo", "pickup_key")
	elif level == 4 and id == 7:
		mission.notify("HORNO DESACTIVADO · reloj detenido, salida habilitada", "pickup_key")
	else:
		mission.notify("%s · COMPLETADO\nPunto de control guardado%s" % [mission.objects[id].title,receipt],"pickup_ammo" if not receipt.is_empty() else "pickup_key")
	mission.checkpoint()
	return true

func update_visibility() -> void:
	for index in range(mission.objective_count):
		var item = mission.objects[index]
		item.visible = index == stage
		item.collision_layer = 1 if index == stage and item.active else 0
		signals[index].material_override = Kit.material(Color("7ad5ab") if mission.done.has(index) else Color("e6bd70"),true)

func tick(delta: float) -> void:
	update_effects()
	if defense != null:
		defense.tick(delta)
	if delivery != null:
		delivery.tick(delta)
	if mission.game.level_number == 5 and not (mission.done.has(2) and mission.done.has(3) and mission.done.has(4)):
		mission.nest_wait -= delta
		if mission.nest_wait <= 0:
			mission.nest_wait = 16
			if mission.living_enemies() < 8:
				mission.spawn_enemy([3,9,10].pick_random())

func describe() -> String:
	if delivery != null and stage>=5:
		return delivery.describe()
	var level: int = mission.game.level_number
	var text := "MISIÓN · ETAPA %d/%d\n%s" % [mini(stage + 1,mission.objective_count),mission.objective_count,mission.objects[mini(stage,mission.objective_count - 1)].title]
	if guards_alive() > 0:
		text += "\nAsegura el sector: %d defensores" % guards_alive()
	if mission.timer > 0:
		text += "\nHORNO DE EMERGENCIA · %ds" % ceili(mission.timer)
	if level == 6:
		var keys := 0
		for key_id in [3,4,5]:
			if mission.done.has(key_id): keys += 1
		text += "\nLLAVES DE MANDO · %d/3" % keys
	if cargo:
		text += "\nCARGA EN MANOS · movimiento al 80 %"
	if mission.defense_time > 0:
		text += "\n%s %ds" % ["PURGA" if level == 5 else "DEFENSA",ceili(mission.defense_time)]
	if defense != null and defense.started:
		text += "\nCARGA %d / 150 · %s" % [defense.health,"DEFENSA COMPLETADA" if defense.completed else "PROTÉGELA"]
	if level == 10:
		text += "\nGUARDIÁN · FASE %d/3" % (mission.boss_phase + 1)
	if level == 4 and not mission.done.has(2):
		text += "\nCompuerta térmica cerrada: galería oeste disponible."
	text += "\n%s" % ("Dispara al nido" if level == 5 and stage in [2,3,4] else "Apunta y pulsa " + mission.key_name("interact"))
	return text
