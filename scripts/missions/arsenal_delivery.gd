extends RefCounted
## Level 9's return trip starts only after its original exit has been secured.
const Kit = preload("res://scripts/common/kit.gd")
const SECURE := 5
const COLLECT := 6
const DELIVER := 7
const INTERVAL := 7.0
const CARGO_POINT := Vector3(-25,.1,26)
const SUPPLY_POINTS := [Vector3(-28,.1,26),Vector3(-22,.1,26),Vector3(-25,.1,23)]
const REINFORCEMENTS := [6,9,12,13,15,17]
var host: Node3D
var mission: Node
var wait := INTERVAL
var batches := 0
var delivered := false
var supplies: Array[Node3D] = []

func setup(late: Node3D) -> void:
	host = late
	mission = host.mission
	var saved: Dictionary = Campaign.profile().get("checkpoint",{})
	if int(saved.get("level",-1)) == 9:
		var state: Dictionary = saved.get("arsenal_delivery",{})
		wait = clampf(float(state.get("wait",INTERVAL)),0,INTERVAL)
		batches = maxi(0,int(state.get("batches",0)))
		delivered = bool(state.get("delivered",false))
	# Marker names intentionally do not start with Supply: Mission owns those IDs.
	var marker: Node3D = mission.game.get_node_or_null("MissionPoints/DeliveryCargo")
	mission.objects[COLLECT].position = mission.reachable(marker.position if marker != null else CARGO_POINT)
	if host.signals.size() > COLLECT:
		host.signals[COLLECT].position = mission.objects[COLLECT].position + Vector3(0,2.8,0)
	var package: Node3D = mission.objects[COLLECT]
	for child in package.get_children():
		if child is MeshInstance3D and child != package.beacon:
			package.remove_child(child)
			child.free()
	Kit.model(package,"Prop_Chest",Vector3(.8,.85,.8),Vector3(0,.5,0),Color("b29cda"))
	# Appended after old supplies/secret cache, preserving all existing supply IDs.
	for index in range(SUPPLY_POINTS.size()):
		var supply_marker: Node3D = mission.game.get_node_or_null("MissionPoints/DeliverySupply%d" % index)
		mission.add_supply(supply_marker.position if supply_marker != null else SUPPLY_POINTS[index],"MUNICIÓN DE EXTRACCIÓN %d" % (index+1))
		supplies.append(mission.objects.back())
	host.cargo = host.stage == DELIVER and not delivered
	mission.game.player.cargo_factor = .8 if host.cargo else 1.0
	refresh_supplies()

func handles(id: int) -> bool:
	return id >= SECURE and id <= DELIVER

func interact(id: int) -> bool:
	if id != host.stage or delivered:
		mission.notify("Completa primero el objetivo activo","")
		return false
	if id == SECURE:
		if mission.living_enemies() > 0:
			mission.notify("Elimina las amenazas restantes antes de recuperar la carga","")
			return false
		wait = INTERVAL
		advance(id)
		mission.notify("ARSENAL ASEGURADO\nVuelve a la sala inicial y recupera la carga · Refuerzos en camino","pickup_key")
		mission.game.log_event("cargo_route_started",{"level":9,"reinforcement_interval":INTERVAL})
		mission.checkpoint()
		return true
	if id == COLLECT:
		host.cargo = true
		mission.game.player.cargo_factor = .8
		advance(id)
		mission.game.log_event("cargo_collected",{"level":9,"object_id":id,"movement_factor":.8})
		mission.notify("CARGA RECUPERADA\nLlévala a la última sala para salir · No necesitas eliminar los refuerzos","pickup_key")
		mission.checkpoint()
		return true
	if not host.cargo:
		mission.notify("Recupera primero la carga de la sala inicial","")
		return false
	delivered = true
	host.cargo = false
	mission.game.player.cargo_factor = 1.0
	mission.game.log_event("cargo_delivered",{"level":9,"object_id":id,"reinforcement_batches":batches})
	mission.game.log_event("objective_completed",{"object_id":id,"title":mission.objects[id].title,"final":true})
	mission.game.end_game(true)
	return true

func advance(id: int) -> void:
	mission.done.append(id)
	mission.objects[id].deactivate()
	mission.game.log_event("objective_completed",{"object_id":id,"title":mission.objects[id].title,"final":false})
	host.stage += 1
	host.stage_started = false
	if mission.doors != null:
		mission.doors.sync()
	host.start_stage()
	refresh_supplies()
	mission.game.update_hud()

func refresh_supplies() -> void:
	for item in supplies:
		var available: bool = host.stage >= COLLECT and not mission.used_supplies.has(item.object_id)
		item.active = available
		item.visible = available
		item.collision_layer = 1 if available else 0

func tick(delta: float) -> void:
	if mission.game.finished or delivered or host.stage < COLLECT:
		return
	wait -= delta
	if wait > 0:
		return
	# One burst per update prevents a hitch or restored checkpoint causing a flood.
	wait = INTERVAL
	var count := randi_range(1,2)
	var spawned := 0
	for index in range(count):
		if mission.spawn_enemy(REINFORCEMENTS.pick_random()):
			spawned += 1
	batches += 1
	mission.game.log_event("delivery_reinforcements",{"requested":count,"spawned":spawned,"batch":batches,"source":"arsenal_delivery"})

func capture_state() -> Dictionary:
	return {"version":1,"wait":wait,"batches":batches,"delivered":delivered}

func describe() -> String:
	var text := "MISIÓN · ETAPA %d/%d\n%s" % [mini(host.stage+1,mission.objective_count),mission.objective_count,mission.objects[mini(host.stage,mission.objective_count-1)].title]
	if host.stage == SECURE:
		text += "\nElimina las amenazas restantes: %d" % mission.living_enemies()
	elif host.stage == COLLECT:
		text += "\nRegresa a la sala inicial · 3 cajas de munición junto a la carga"
	else:
		text += "\nCARGA EN MANOS · movimiento al 80 %\nAlcanza la última sala sin detenerte a limpiar los refuerzos"
	if host.stage >= COLLECT:
		text += "\nRefuerzos en %ds" % ceili(maxf(0,wait))
	return text + "\nApunta y pulsa " + mission.key_name("interact")
