extends Control
## One lesson at a time; the campaign's progress and inventory remain untouched.
var mission: Node
var game: Node
var steps: Array[Dictionary] = []
var step: int = 0
var complete: bool = false
var reload_started: bool = false
var reload_ammo: int = 0
var reload_weapon: String = ""
var grenade_count: int = 0
@onready var panel: PanelContainer = $GuidePanel
@onready var phase: Label = $GuidePanel/Content/Phase
@onready var title: Label = $GuidePanel/Content/Title
@onready var body: Label = $GuidePanel/Content/Body
@onready var preview: TextureRect = $GuidePanel/Content/EnemyPreview
@onready var status: Label = $GuidePanel/Content/Status
@onready var next: Button = $GuidePanel/Content/Actions/Next
@onready var focus_frame: Panel = $FocusFrame

func _ready() -> void:
	game = mission.game
	var key: Callable = Callable(mission,"key_name")
	steps = [
		{"id":"welcome","title":"BIENVENIDO A SECTOR 07","body":"Aprende a leer tu equipo y practica sin perder tu campaña. Cada explicación y ejercicio es independiente. Pulsa Siguiente para avanzar; ESC permite salir desde la pausa."},
		{"id":"vitals","title":"TU VIDA Y ESCUDO","body":"Abajo a la izquierda están tus PV y tu escudo. La barra roja avisa de vida crítica. Tras dejar de recibir daño, la reparación recupera vida; el texto indica la espera. El escudo necesita una mejora para estar disponible.","focus":"GameHUD/VitalsInstrument"},
		{"id":"arsenal","title":"ARMA, CARGADOR Y RESERVA","body":"Abajo a la derecha ves el arma equipada, las balas del cargador y la reserva. Recargar transfiere balas; no crea munición. La barra ámbar muestra la recarga. Debajo están la granada seleccionada y las existencias de cada tipo.","focus":"GameHUD/ArsenalInstrument"},
		{"id":"missions","title":"OBJETIVOS Y PROGRESO","body":"Arriba a la derecha ves la fase, el objetivo activo y sus requisitos. Algunas salas se abren al cumplirlos. Arriba a la izquierda están el sector, las bajas y el tiempo: eliminar enemigos no sustituye la misión.","focus":"MissionPanel"},
		{"id":"markers","title":"CÓMO LEER LAS TARJETAS DEL MAPA","body":"El rombo ámbar señala el objetivo y sus metros de distancia. El cuadro cian identifica suministros o equipo. Una indicación bloqueada muestra que falta un requisito. Aquí solo aparecerá el marcador que corresponde al ejercicio actual."},
		{"id":"move","title":"MIRAR Y MOVERSE","body":"Llega a la baliza con %s / %s / %s / %s. Mira con el ratón. Mantén %s para correr y usa %s para saltar. Al completar el ejercicio aparecerá Siguiente." % [key.call("forward"),key.call("left"),key.call("back"),key.call("right"),key.call("sprint"),key.call("jump")],"target":0},
		{"id":"terminal","title":"INTERACTUAR CON TERMINALES","body":"Apunta al terminal y pulsa %s a menos de 3,5 metros. La misma acción activa controles, balizas y salidas. Acercarte sin apuntar no basta." % key.call("interact"),"target":4},
		{"id":"card","title":"RECOGER UNA TARJETA","body":"Busca la tarjeta ámbar, apunta y pulsa %s. Escucharás la confirmación y su marcador desaparecerá. En campaña puede habilitar el siguiente acceso; todavía debes cumplir los demás objetivos." % key.call("interact"),"target":5},
		{"id":"supply","title":"SUMINISTROS Y MUNICIÓN","body":"Apunta a la caja cian y pulsa %s. Repone reservas respetando sus límites y añade una granada del tipo seleccionado. Las cajas se consumen una vez: en campaña conviene usarlas cuando hacen falta." % key.call("interact"),"target":-10},
		{"id":"weapons","title":"CONOCE TU ARSENAL","body":"En campaña, los perfiles nuevos empiezan con pistola y cuchillo. El fusil se recoge en la última sala del nivel 1; escopeta, precisión y plasma en los niveles 3, 6 y 9. Recoge con %s y termina la misión para conservar el arma. Si omites una, puedes volver después. Los perfiles anteriores conservan el fusil. Aquí tienes pistola y fusil de práctica." % key.call("interact")},
		{"id":"shoot","title":"DISPARAR AL BLANCO","body":"Apunta al blanco ámbar y dispara con clic izquierdo hasta destruirlo. La pistola dispara una vez por pulsación; el fusil admite mantener el botón. Mantén una reserva para los siguientes encuentros.","target":1},
		{"id":"cover_small","title":"CUBRIRTE CON UNA CAJA","body":"Coloca la caja entre el enemigo y tú. Los enemigos pequeños no pueden ver ni disparar por encima de una caja que los tapa, pero pueden rodearla. Si sales por un lado, vuelves a quedar expuesto.","enemy":0},
		{"id":"cover_tall","title":"ENEMIGOS ALTOS, COBERTURA ALTA","body":"Los enemigos altos pueden verte y dispararte por encima de una caja simple. Busca dos cajas apiladas o una pared y mantenla entre el enemigo y tú. Asómate para atacar y vuelve a cubrirte; una sola caja no siempre basta.","enemy":5},
		{"id":"cover_search","title":"TE HAS OCULTADO, PERO TE BUSCAN","body":"Al perderte de vista, irán a donde te vieron por última vez y revisarán los alrededores. Aprovecha la cobertura para cambiar de posición. Si te encuentran, retomarán el ataque; si no, terminarán por volver a vigilar."},
		{"id":"reload","title":"RECARGAR CON RESERVA","body":"Pulsa %s y espera a que termine la recarga. El sonido y la barra acompañan el proceso. Cambiar de arma o usar el cuchillo la cancela." % key.call("reload")},
		{"id":"switch","title":"CAMBIAR DE ARMA","body":"Equipa el fusil con %s o la rueda del ratón. %s selecciona la primera ranura. Cada arma guarda su propio cargador y reserva; cambiar no rellena munición." % [key.call("weapon_two"),key.call("weapon_one")]},
		{"id":"knife","title":"CUCHILLO A CORTA DISTANCIA","body":"Acércate al blanco y pulsa %s. El cuchillo no consume munición, pero tiene alcance corto y una pausa entre golpes. Los disparos no completan este ejercicio." % key.call("melee"),"target":2},
		{"id":"grenade","title":"LANZAR UNA GRANADA","body":"Apunta a la galería vacía y pulsa %s. La básica está disponible desde el inicio; fragmentación se recoge en el nivel 2 y estasis en el 5. %s alterna los tipos que hayas encontrado. Conserva distancia y recuerda que las paredes bloquean la explosión." % [key.call("grenade"),key.call("grenade_cycle")]}
	]
	steps.append({"id":"weapon_pickup","title":"ENCONTRAR UN ARMA","body":"Apunta a la escopeta de demostración y pulsa %s. Se equipa en la segunda ranura. Este equipo solo sirve para entrenar: en campaña debes encontrar cada arma en su sector y completar la misión para conservarla." % key.call("interact"),"target":-103})
	steps.append({"id":"grenade_pickup","title":"ENCONTRAR EQUIPO TÁCTICO","body":"Recoge la granada de fragmentación con %s. Tiene sus propias existencias y hace más daño que la básica. La estasis ralentiza enemigos. Los tipos especiales también deben recogerse y conservarse completando su misión; aquí solo son de práctica." % key.call("interact"),"target":-205})
	steps.append({"id":"grenade_cycle","title":"ELEGIR EL TIPO DE GRANADA","body":"Pulsa %s para alternar de fragmentación a básica. Mira el nombre y las cantidades en el panel de armamento. Cambiar de tipo no repone ninguna granada." % key.call("grenade_cycle")})
	var catalog = preload("res://scripts/enemies/enemy_catalog.gd")
	for kind in range(6):
		var enemy: Dictionary = catalog.ENTRIES[kind]
		steps.append({"id":"enemy%d" % kind,"title":"%s · %s" % [enemy.name.to_upper(),enemy.role.to_upper()],"body":enemy.behavior + "\n\nCómo responder: " + enemy.weakness,"enemy":kind})
	steps.append({"id":"exit","title":"PRÁCTICA COMPLETADA","body":"Ya conoces el HUD, las tarjetas, las interacciones, las armas, las coberturas y los seis roles básicos. En campaña aparecerán variantes más peligrosas. Apunta a la salida y pulsa %s para registrar el entrenamiento como completado." % key.call("interact"),"target":3})
	next.pressed.connect(advance)
	$GuidePanel/Content/Actions/Leave.pressed.connect(game.go_home)
	enter_step()

func _process(_delta: float) -> void:
	visible = not get_tree().paused and not game.finished

func current_id() -> String:
	return steps[step].id

func active_object_id() -> int:
	return int(steps[step].get("target",-999)) if not complete else -999

func accepts(id: int) -> bool:
	return not complete and active_object_id() == id

func set_controls(practice: bool) -> void:
	game.player.set_physics_process(practice)
	game.player.set_process_unhandled_input(practice)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if practice else Input.MOUSE_MODE_VISIBLE
	if not practice:
		game.player.velocity = Vector3.ZERO

func enter_step() -> void:
	# Feedback from the previous exercise must not cover the next lesson.
	mission.notification_left = 0
	var notice: Label = mission.get("notification")
	notice.hide()
	mission.announcement = ""
	complete = not steps[step].has("target") and current_id() not in ["reload","switch","grenade","grenade_cycle"]
	reload_started = false
	if current_id() == "grenade":
		game.player.grenade_type = "basic"
		game.player.grenades = maxi(1,game.player.grenades)
	grenade_count = game.player.grenades
	if current_id() == "shoot":
		game.player.equip("pistol")
		game.player.switch_time = 0
	if current_id() == "switch":
		game.player.equip("pistol")
		game.player.switch_time = 0
	if current_id() == "reload" and game.player.ammo == game.player.ammo_capacity:
		# Earlier voluntary reloads must not make this lesson impossible.
		game.player.ammo -= 1
		game.player.reserve += 1
	if current_id() in ["reload","shoot"]:
		game.player.reserve = maxi(12,game.player.reserve)
	phase.text = "ENTRENAMIENTO  /  %02d DE %02d" % [step + 1,steps.size()]
	title.text = steps[step].title
	body.text = steps[step].body
	# During exercises, keep the central crosshair and target unobstructed.
	panel.anchor_left = 0.0 if not complete else .5
	panel.anchor_right = panel.anchor_left
	panel.offset_left = 22 if not complete else -275
	panel.offset_right = 422 if not complete else 275
	panel.offset_bottom = panel.offset_top
	preview.visible = steps[step].has("enemy")
	if preview.visible:
		preview.texture = load("res://assets/previews/enemies/enemy_%02d.png" % int(steps[step].enemy))
	focus_frame.hide()
	if steps[step].has("focus"):
		var target: Control = game.get_node("HUD/Interface/" + steps[step].focus)
		focus_frame.position = target.global_position - Vector2(5,5)
		focus_frame.size = target.size + Vector2(10,10)
		focus_frame.show()
	sync_objects()
	update_status()

func sync_objects() -> void:
	for item in mission.objects:
		var shown: bool = item.active and accepts(item.object_id)
		item.visible = shown
		item.collision_layer = 1 if shown else 0
		item.label.visible = shown

func update_status() -> void:
	var practice: bool = not complete
	set_controls(practice)
	next.disabled = practice
	next.text = "Siguiente" if step < steps.size() - 1 else "Finaliza en la salida"
	status.text = "Realiza la acción indicada para continuar." if practice else ("Ejercicio completado. Pulsa Siguiente." if steps[step].has("target") or current_id() in ["reload","switch","grenade"] else "Lee esta explicación y pulsa Siguiente.")
	if complete:
		next.grab_focus()
	mission.hint.text = "ENTRENAMIENTO · FASE %d/%d\n%s\n%s" % [step + 1,steps.size(),steps[step].title,"Lee la guía y pulsa Siguiente." if complete else "Completa el ejercicio de la guía."]
	game.update_hud()

func finish_practice() -> void:
	complete = true
	sync_objects()
	update_status()

func advance() -> void:
	if not complete or step >= steps.size() - 1:
		return
	step += 1
	enter_step()

func tick() -> void:
	if complete:
		set_controls(false)
		return
	match current_id():
		"move":
			if game.player.position.distance_to(mission.objects[0].position) < 2.5 and game.player.position.distance_to(mission.tutorial_start) > 3:
				interact(0)
		"reload":
			if game.player.reload_time > 0 and not reload_started:
				reload_started = true
				reload_ammo = game.player.ammo
				reload_weapon = game.player.weapon_id
			elif reload_started and game.player.reload_time <= 0:
				if game.player.weapon_id == reload_weapon and game.player.ammo > reload_ammo:
					mission.tutorial_reloaded = true
					finish_practice()
				reload_started = false
		"switch":
			if game.player.weapon_id == "rifle":
				mission.tutorial_switched = true
				finish_practice()
		"grenade":
			if game.player.grenades < grenade_count and game.player.grenade_wait > 0:
				mission.tutorial_grenade = true
				finish_practice()
		"grenade_cycle":
			if game.player.grenade_type == "basic":
				finish_practice()

func interact(id: int) -> bool:
	if not accepts(id):
		return false
	if id == 3:
		game.end_game(true)
		return true
	if id in [-103,-205]:
		if id == -103:
			game.player.discover_weapon("shotgun")
		else:
			game.player.discover_grenade("fragmentation")
		mission.notify("EQUIPO DE PRÁCTICA RECOGIDO","weapon_unlock")
	elif id < 0:
		mission.used_supplies.append(id)
		mission.notify("SUMINISTROS RECOGIDOS\n" + game.player.resupply(),"pickup_ammo")
	else:
		mission.done.append(id)
		mission.notify("PASO COMPLETADO","pickup_key")
		# Movement is completed by proximity rather than the object's interact().
		if id == 0:
			mission.objects[0].deactivate()
	finish_practice()
	return true
