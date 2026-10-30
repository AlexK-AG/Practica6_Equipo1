extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var campaign = root.get_node("Campaign")
	campaign.options.difficulty = 1
	assert("--campaign-test" in OS.get_cmdline_user_args())
	campaign.profiles = {}
	campaign.select_profile("Smoke")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	await physics_frame
	scene.set_pause(false)
	check(scene.player.health == 100, "Vida inicial")
	check(scene.player.ammo == 12, "MuniciÃ³n inicial")
	var enemies: Array = []
	for child in scene.get_children():
		if child.get_script() == preload("res://scripts/enemies/enemy.gd"):
			enemies.append(child)
	check(enemies.size() == 9, "Siete enemigos y dos defensores de misión")
	var healths: Array = []
	var damages: Array = []
	for enemy in enemies:
		healths.append(enemy.health)
		damages.append(enemy.attack_damage)
	check(healths.slice(0, 7) == [50, 55, 60, 65, 70, 80, 75], "Vidas diferentes")
	check(damages.min() > 0 and damages.max() > damages.min(), "Daño distinto según subtipo")
	for enemy in enemies:
		check(preload("res://tests/helpers/navigation_checks.gd").route(scene,enemy.position, scene.player.position).size() > 1, "Ruta de cada enemigo al jugador")
	check(preload("res://tests/helpers/navigation_checks.gd").route(scene,Vector3(-21, 0, 4), Vector3(21, 0, 4)).size() > 1, "Nueva zona transitable")
	check(scene.grid.is_point_solid(Vector2i(17, 15)), "Caja ampliada bloquea navegaciÃ³n")
	check(preload("res://tests/helpers/navigation_checks.gd").route(scene,Vector3(0, 0, -20), Vector3(0, 0, 28)).size() > 1, "Ruta disponible")
	check(scene.grid.is_point_solid(Vector2i(-7, 24)), "Coberturas bloquean ruta")
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0, 0.8, 24), Vector3(10, 0.8, 24))
	check(not scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Cobertura fÃ­sica")
	for enemy in enemies:
		enemy.set_physics_process(false)
	enemies[0].position = Vector3(0, 0.1, 25)
	scene.player.camera.look_at(Vector3(0, 0.7, 25))
	await physics_frame
	await physics_frame
	scene.player.shoot()
	check(scene.player.ammo == 11, "Disparo consume municiÃ³n")
	check(enemies[0].health == 25, "Disparo impacta enemigo y resta 25 PV")
	scene.player.reload_time = 0.01
	scene.player._physics_process(0.02)
	check(scene.player.ammo == 12, "Recarga completa")
	scene.player.take_damage(6)
	check(scene.player.health == 94, "DaÃ±o al jugador")
	scene.player.regenerate(3.0)
	check(scene.player.health == 94, "RegeneraciÃ³n espera cuatro segundos")
	scene.player.take_damage(10)
	scene.player.regenerate(3.5)
	check(scene.player.health == 84, "Nuevo daÃ±o reinicia la espera")
	scene.player.regenerate(1.0)
	check(scene.player.health == 88, "Regenera solo el tiempo posterior a la espera")
	scene.player.regenerate(10.0)
	check(scene.player.health == 100, "RegeneraciÃ³n limitada a 100 PV")
	scene.player.take_damage(10)
	scene.set_pause(true)
	check(paused and scene.menu.visible, "Pausa y menÃº")
	scene.player.regenerate(10.0)
	check(scene.player.health == 90 and scene.player.regen_wait == 4.0, "Pausa congela regeneraciÃ³n")
	scene.set_pause(false)
	check(not paused, "Continuar")
	for enemy in enemies:
		if scene.kills == 6:
			check(not scene.finished, "Seis bajas todavÃ­a no dan victoria")
		enemy.take_damage(1000)
		enemy.take_damage(1000)
	check(scene.kills == 9, "Bajas sin duplicados")
	check(not scene.finished, "Las bajas no sustituyen el objetivo")
	preload("res://tests/helpers/mission_driver.gd").complete(scene)
	await scene.result_presented
	check(scene.finished and paused, "Victoria")
	paused = false
	scene.queue_free()
	await process_frame
	campaign.reset_campaign()
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	check(scene.kills == 0 and scene.player.health == 100, "Estado limpio al reiniciar")
	scene.player.take_damage(100)
	check(scene.finished and paused and scene.player.health == 0, "Derrota")
	paused = false
	scene.player.regenerate(20.0)
	check(scene.player.health == 0, "RegeneraciÃ³n no revive al jugador")
	scene.queue_free()
	await process_frame
	print("SMOKE TESTS: ", "PASS" if failures == 0 else "FAIL", " / failures=", failures)
	root.get_node("Campaign").music.stop()
	root.get_node("Campaign").music.stream = null
	await create_timer(0.3).timeout
	quit(failures)
