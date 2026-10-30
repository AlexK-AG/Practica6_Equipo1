extends Node3D
## Gates are inferred from every walkable entrance to an authored room.
const Kit = preload("res://scripts/common/kit.gd")
const ROOMS := {
	1:[[Rect2(-28,-3,14,14),1,"ARCHIVO"],[Rect2(-8,-26,16,14),2,"EXTRACCIÓN"]],
	2:[[Rect2(16,-4,16,16),1,"CARGA ESTE"]],
	3:[[Rect2(-10,-24,20,16),3,"REACTOR"],[Rect2(16,-22,14,12),5,"EVACUACIÓN"]],
	4:[[Rect2(16,-29,16,14),2,"CONTROL TÉRMICO"],[Rect2(-33,-29,16,14),4,"MONTACARGAS"]],
	5:[[Rect2(15,-6,18,20),2,"CULTIVOS ESTE"],[Rect2(-11,-21,22,18),3,"INCUBADORA"],[Rect2(-33,-30,18,14),4,"PURGA"],[Rect2(15,-30,18,14),5,"EXTRACCIÓN MÉDICA"]],
	6:[[Rect2(-30,-24,14,14),0,"PUESTO DE PRECISIÓN"],[Rect2(-10,-30,20,14),2,"MANDO"]],
	7:[[Rect2(18,-5,16,18),1,"ENLACE ESTE"],[Rect2(18,-31,16,14),3,"TRANSMISOR"],[Rect2(-34,-31,16,14),5,"EXTRACCIÓN"]],
	8:[[Rect2(21,-20,14,16),1,"DEPÓSITO ESTE"],[Rect2(-6,-36,18,10),5,"EMBARQUE"]],
	9:[[Rect2(5,-29,20,14),0,"CÁMARA DE NÚCLEOS"],[Rect2(19,-8,14,22),1,"DEPÓSITO ESTE"],[Rect2(17,21,16,12),3,"SALIDA ORBITAL"]],
	10:[[Rect2(-13,-22,26,26),1,"CÁMARA DEL GUARDIÁN"]]
}
var mission: Node
var gates: Array[Dictionary] = []
var baseline: Dictionary = {}
var arena_sealed: bool = false
var arena: Rect2 = Rect2(-13,-22,26,26)
var signature: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var saved: Dictionary = Campaign.profile().get("checkpoint",{})
	if int(saved.get("level",-1)) == mission.game.level_number:
		arena_sealed = bool(saved.get("arena_sealed",false))
	for room in ROOMS[mission.game.level_number]:
		room_entrances(room[0],room[1],room[2])
	if mission.game.level_number == 2:
		create_gate(Vector3(0,0,-25),Vector3(19.5,4.15,.35),[],6,"EMBARQUE")
	sync(false)

func room_entrances(rectangle: Rect2, prerequisite: int, title: String) -> void:
	var x0 := floori(rectangle.position.x)
	var z0 := floori(rectangle.position.y)
	var x1 := ceili(rectangle.end.x) - 1
	var z1 := ceili(rectangle.end.y) - 1
	for side in range(4):
		var run: Array[Vector2i] = []
		var low: int = z0 if side < 2 else x0
		var high: int = z1 if side < 2 else x1
		for value in range(low,high + 2):
			var cell := Vector2i(x0 if side == 0 else x1,value) if side < 2 else Vector2i(value,z0 if side == 2 else z1)
			var outside: Vector2i = cell + [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN][side]
			var walkable: bool = value <= high and not mission.game.grid.is_point_solid(cell) and not mission.game.grid.is_point_solid(outside)
			if walkable:
				run.append(cell)
			elif not run.is_empty():
				entrance_run(run,side,prerequisite,title)
				run = []

func entrance_run(cells: Array[Vector2i], side: int, prerequisite: int, title: String) -> void:
	var first := cells[0]
	var last: Vector2i = cells.back()
	var center := Vector3((first.x + last.x) * .5,0,(first.y + last.y) * .5)
	var normal: Vector2i = [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN][side]
	center += Vector3(normal.x,0,normal.y) * .5
	var size := Vector3(.35,4.15,cells.size() + .9) if side < 2 else Vector3(cells.size() + .9,4.15,.35)
	create_gate(center,size,cells,prerequisite,title)

func create_gate(point: Vector3,size: Vector3,cells: Array,prerequisite: int,title: String) -> void:
	var body := StaticBody3D.new()
	body.name = "SectorDoor%d" % gates.size()
	body.position = point
	add_child(body)
	var panel := Kit.box(body,size,Vector3(0,2.075,0),Color("343d4b"))
	panel.material_override = preload("res://scripts/visuals/station_surfaces.gd").surface("Trim_02",Color(.65,.7,.78),.2)
	Kit.collider(body,size,Vector3(0,2.075,0))
	var lamp := Kit.box(body,Vector3(.15,2.5,.15),Vector3(0,2.1,0),Color("e6a454"),true)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.65
	label.font_size = 28
	label.pixel_size = .004
	label.outline_size = 8
	label.no_depth_test = true
	body.add_child(label)
	var blocked: Array[Vector2i] = []
	for x in range(floori(point.x - size.x / 2 - .5),ceili(point.x + size.x / 2 + .5) + 1):
		for z in range(floori(point.z - size.z / 2 - .5),ceili(point.z + size.z / 2 + .5) + 1):
			if absf(x - point.x) >= size.x / 2 + .6 or absf(z - point.z) >= size.z / 2 + .6:
				continue
			var cell := Vector2i(x,z)
			if not baseline.has(cell):
				baseline[cell] = mission.game.grid.is_point_solid(cell)
			if not baseline[cell]:
				blocked.append(cell)
	gates.append({"body":body,"lamp":lamp,"label":label,"prerequisite":prerequisite,"title":title,"cells":blocked,"closed":true})

func is_open(gate: Dictionary) -> bool:
	var level: int = mission.game.level_number
	if level == 10:
		var boss = mission.game.get_node_or_null("FinalBoss")
		if not is_instance_valid(boss) or boss.health <= 0:
			return true
		return mission.done.has(1) and not arena_sealed
	if not mission.done.has(gate.prerequisite):
		return false
	if (level == 5 and gate.title == "EXTRACCIÓN MÉDICA") or (level == 8 and gate.title == "EMBARQUE"):
		return mission.defense_time == 0
	if level == 2 and gate.title == "EMBARQUE":
		return mission.wave >= mission.WAVE_SIZES.size() and mission.wave_remaining == 0 and mission.living_enemies() == 0
	return true

func sync(announce: bool = true) -> void:
	var next := ""
	var opened: Array[String] = []
	for gate in gates:
		var closed: bool = not is_open(gate)
		next += "1" if closed else "0"
		if not signature.is_empty() and gate.closed == closed:
			continue
		if gate.closed and not closed and not opened.has(gate.title):
			opened.append(gate.title)
		gate.closed = closed
		gate.body.collision_layer = 1 if closed else 0
		# Remain visible above the doorway when open, serving as a door frame.
		gate.body.position.y = 0 if closed else 4.2
		gate.label.text = ("BLOQUEO DE COMBATE" if arena_sealed and mission.game.level_number == 10 else "BLOQUEADA · " + mission.objects[gate.prerequisite].title) if closed else gate.title + " · ABIERTA"
		if closed and mission.done.has(gate.prerequisite) and mission.game.level_number in [2,5,8]:
			gate.label.text = "BLOQUEADA · COMPLETA LA DEFENSA"
		gate.lamp.material_override = Kit.material(Color("e3ab60") if closed else Color("76d7a9"),true)
	if signature == next:
		return
	signature = next
	for cell in baseline:
		mission.game.grid.set_point_solid(cell,baseline[cell])
	for gate in gates:
		if gate.closed:
			for cell in gate.cells:
				mission.game.grid.set_point_solid(cell,true)
	if announce and not opened.is_empty():
		call_deferred("announce_access"," · ".join(opened))

func announce_access(rooms: String) -> void:
	# Append after the objective's own feedback so neither notification is lost.
	var notice: Label = mission.get("notification")
	mission.notify(notice.text + "\nACCESO DESBLOQUEADO: " + rooms,"pickup_key")

func _process(_delta: float) -> void:
	if mission.game.finished:
		return
	for gate in gates:
		gate.label.visible = gate.closed and gate.body.position.distance_to(mission.game.player.position) < 12
	if mission.game.level_number == 10 and not arena_sealed and mission.done.has(1):
		var point: Vector3 = mission.game.player.position
		if arena.grow(-1.4).has_point(Vector2(point.x,point.z)):
			arena_sealed = true
			sync(false)
			mission.notify("CÁMARA SELLADA\nDerrota al Guardián para abrir las salidas","pickup_key")
			mission.checkpoint()
	sync()
