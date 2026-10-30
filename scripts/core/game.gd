class_name GameController
extends Node3D

signal result_presented
const VICTORY_DELAY: float = 0.4
const Kit = preload("res://scripts/common/kit.gd")
const Player = preload("res://scripts/player/player.gd")
const Enemy = preload("res://scripts/enemies/enemy.gd")
var enemy_count: int = 7
var player: CharacterBody3D
var kills: int = 0
var finished: bool = false
var grid := AStarGrid2D.new()
var stats: Label
var regen_status: Label
var crosshair: Label
var damage_overlay: ColorRect
var stasis_frame: Control
var low_health_cloud: ColorRect
var low_health_material: ShaderMaterial
var menu: PanelContainer
var menu_title: Label
var resume_button: Button
var hit_time: float = 0
var damage_time: float = 0

@export var level_number: int = 1
@export var level_title: String = "Laboratorio"
@export_file("*.tscn") var next_level: String = "res://scenes/levels/level_2.tscn"
@export var navigation_extent: int = 15
@export var map_scale: float = 1.5
@export var room_layout: bool = false
@export var tutorial_mode: bool = false
var run_weapons: Array[String] = []
var loadout_pending: bool = false
var elapsed: float = 0.0
var next_button: Button
var mission: Node
var hud_view: Control
var _visual_fov: float = -1
var _history_id := ""
var _history_profile := ""
var _history_started := ""
var _history_elapsed_start := 0.0
var _history_kills_start := 0
var _history_saved := false

var replay: RefCounted

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	setup_inputs()
	player = $Player
	stats = find_child("Stats", true, false)
	regen_status = find_child("Regeneration", true, false)
	crosshair = find_child("Crosshair", true, false)
	damage_overlay = find_child("DamageOverlay", true, false)
	stasis_frame = find_child("StasisFrame", true, false)
	low_health_cloud = find_child("LowHealthCloud", true, false)
	low_health_material = low_health_cloud.material as ShaderMaterial
	if is_instance_valid(low_health_material):
		low_health_material = low_health_material.duplicate()
		low_health_cloud.material = low_health_material
	menu = find_child("PauseMenu", true, false)
	menu_title = find_child("MenuTitle", true, false)
	resume_button = find_child("Resume", true, false)
	next_button = find_child("NextLevel", true, false)
	hud_view = get_node("HUD/Interface/GameHUD")
	hud_view.bind_game(self)
	stats.hide()
	regen_status.hide()
	find_child("Heading", true, false).hide()
	resume_button.pressed.connect(func(): set_pause(false))
	find_child("Restart", true, false).pressed.connect(restart_mission)
	find_child("Quit", true, false).pressed.connect(quit_game)
	find_child("Home", true, false).pressed.connect(go_home)
	next_button.pressed.connect(advance)
	find_child("Heading", true, false).text = "SECTOR 07 / NIVEL %d / %s" % [level_number, level_title.to_upper()]
	if tutorial_mode:
		find_child("Heading", true, false).text = "SECTOR 07 / ENTRENAMIENTO OPCIONAL"
		find_child("Restart", true, false).text = "Reiniciar entrenamiento"
	enemy_count = 0
	for child in get_children():
		if child is CharacterBody3D and child != player:
			enemy_count += 1
	# Scale authored geometry and actors together, keeping collision routes aligned.
	$Arena.scale *= Vector3(map_scale, 1, map_scale)
	player.position *= Vector3(map_scale, 1, map_scale)
	for child in get_children():
		if child is EnemyController:
			child.position *= Vector3(map_scale, 1, map_scale)
	navigation_extent = ceili(navigation_extent * map_scale)
	preload("res://scripts/visuals/station_surfaces.gd").apply($Arena)
	build_navigation()
	if preload("res://scripts/visuals/station_details.gd").populate(self) > 0:
		build_navigation()
	preload("res://scripts/visuals/surface_visibility.gd").apply($Arena)
	apply_visual_options()
	menu.hide()
	update_hud()
	$UpgradeScreen.selected.connect(_upgrade_selected)
	$UpgradeScreen.back_requested.connect(go_home)
	$UpgradeScreen.hide()
	if Campaign.profile().is_empty() or (not tutorial_mode and (not Campaign.unlocked(level_number - 1) or Campaign.pending() >= 0)):
		finished = true
		call_deferred("go_home")
		return
	Campaign.play_music(level_number - 1)
	mission = Node.new()
	mission.name = "Mission"
	mission.set_script(preload("res://scripts/missions/mission.gd"))
	add_child(mission)
	hud_view.bind_mission(mission)
	if not tutorial_mode:
		_history_id = Crypto.new().generate_random_bytes(16).hex_encode()
		_history_profile = Campaign.active_id
		_history_started = Time.get_datetime_string_from_system(true)+"Z"
		_history_elapsed_start = elapsed
		_history_kills_start = kills
		Campaign.begin_events(_history_id,_history_profile,level_number,_history_started,elapsed,int(Campaign.profile().get("checkpoint",{}).get("level",-1))==level_number)
		replay = preload("res://scripts/persistence/run_replay.gd").new()
		replay.start(self)
	find_child("Controls", true, false).hide()
	var checkpoint_button: Button = get_node("HUD/Interface/PauseMenu/Actions/RetryCheckpoint")
	checkpoint_button.pressed.connect(restart)
	checkpoint_button.visible = not tutorial_mode
	var saved: Dictionary = Campaign.profile().get("checkpoint", {})
	var discovery: String = {1: "rifle", 3: "shotgun", 6: "precision", 9: "plasma"}.get(level_number, "")
	var must_find_weapon := not discovery.is_empty() and not Campaign.available_weapons(level_number).has(discovery)
	if not tutorial_mode and not must_find_weapon and Campaign.available_weapons(level_number).size() > 1 and int(saved.get("level", -1)) != level_number:
		loadout_pending = true
		set_pause(true)
		menu.hide()
		var equipment := CanvasLayer.new()
		equipment.set_script(preload("res://scripts/ui/loadout_screen.gd"))
		equipment.name = "LoadoutScreen"
		add_child(equipment)

func _upgrade_selected() -> void:
	next_button.text = "Siguiente nivel"
	menu.show()
	next_button.grab_focus()

func apply_visual_options() -> void:
	var quality: int = clampi(int(Campaign.options.quality), 0, 2)
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][quality]
	if is_instance_valid(player) and is_instance_valid(player.camera):
		if _visual_fov < 0:
			_visual_fov = float(Campaign.options.fov)
		var mobile_aim: bool = (OS.get_name() in ["Android", "iOS"] or bool(Campaign.options.get("touch_debug", false))) and player.weapon_id == "precision" and player.touch_aim_enabled
		var zoom: float = .5 if mobile_aim or (player.weapon_id == "precision" and player.camera.fov < _visual_fov * .75) else 1.0
		player.camera.fov = float(Campaign.options.fov) * zoom
		_visual_fov = float(Campaign.options.fov)
	for light in $Arena.find_children("*", "Light3D", true, false):
		if not light.has_meta("authored_shadow"):
			light.set_meta("authored_shadow", light.shadow_enabled)
		light.shadow_enabled = quality > 0 and bool(light.get_meta("authored_shadow"))
	for world in find_children("*", "WorldEnvironment", true, false):
		if world.environment == null:
			continue
		if not world.has_meta("authored_environment"):
			world.set_meta("authored_environment", world.environment.duplicate())
			world.environment = world.environment.duplicate()
		var original: Environment = world.get_meta("authored_environment")
		world.environment.fog_enabled = quality == 2 and original.fog_enabled
		world.environment.tonemap_exposure = original.tonemap_exposure * clampf(float(Campaign.options.brightness), .75, 1.35)

func build_navigation() -> void:
	grid.region = Rect2i(-navigation_extent, -navigation_extent, navigation_extent * 2 + 1, navigation_extent * 2 + 1)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	if room_layout:
		for x in range(-navigation_extent, navigation_extent + 1):
			for z in range(-navigation_extent, navigation_extent + 1):
				grid.set_point_solid(Vector2i(x, z))
		for body in $Arena.get_children():
			if not body.name.begins_with("Floor"):
				continue
			var floor_shape: CollisionShape3D = body.get_node("Collision")
			var size: Vector3 = floor_shape.shape.size
			for x in range(floori(body.position.x - size.x / 2), ceili(body.position.x + size.x / 2)):
				for z in range(floori(body.position.z - size.z / 2), ceili(body.position.z + size.z / 2)):
					grid.set_point_solid(Vector2i(x, z), false)
	# Derive blocked cells from the edited scene's actual collision transforms.
	for body in $Arena.find_children("*", "StaticBody3D", true, false):
		if not body is StaticBody3D:
			continue
		for shape_node in body.get_children():
			if not shape_node is CollisionShape3D or not shape_node.shape is BoxShape3D:
				continue
			var size: Vector3 = shape_node.shape.size
			if shape_node.global_position.y - size.y / 2 > 1.8:
				continue
			if shape_node.global_position.y + size.y / 2 < 0.2:
				continue
			for x in range(-navigation_extent, navigation_extent + 1):
				for z in range(-navigation_extent, navigation_extent + 1):
					var local: Vector3 = shape_node.to_local(to_global(Vector3(x, shape_node.position.y, z)))
					if absf(local.x) < size.x / 2 + 0.6 and absf(local.z) < size.z / 2 + 0.6:
						grid.set_point_solid(Vector2i(x, z))

func go_home() -> void:
	if not finished:
		_save_run_history("abandoned")
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/start.tscn")

func advance() -> void:
	if not finished or next_level.is_empty():
		return
	if Campaign.pending() >= 0:
		$UpgradeScreen.refresh()
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(next_level)

func setup_inputs() -> void:
	Campaign.apply_input_bindings()

func route(from: Vector3, to: Vector3) -> PackedVector2Array:
	var start := Vector2i(clampi(roundi(from.x), -navigation_extent, navigation_extent), clampi(roundi(from.z), -navigation_extent, navigation_extent))
	var end := Vector2i(clampi(roundi(to.x), -navigation_extent, navigation_extent), clampi(roundi(to.z), -navigation_extent, navigation_extent))
	if grid.is_point_solid(start) or grid.is_point_solid(end):
		return PackedVector2Array()
	return grid.get_point_path(start, end)

func pursuit_route(from: Vector3, to: Vector3) -> PackedVector2Array:
	# Actors can stand in a physically free strip which the conservative grid
	# reserves around a crate. Connect that strip to nearby safe grid nodes;
	# never move the actor or open a blocked cell to obtain a route.
	var starts := _navigation_endpoints(from)
	var ends := _navigation_endpoints(to)
	for start in starts:
		for end in ends:
			var candidate: PackedVector2Array = grid.get_point_path(start, end)
			if not candidate.is_empty():
				return candidate
	return PackedVector2Array()

func _navigation_endpoints(point: Vector3) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var center := Vector2i(roundi(point.x), roundi(point.z))
	if not grid.is_in_boundsv(center):
		return result
	if not grid.is_point_solid(center):
		if navigation_segment_clear(point, Vector3(center.x, point.y, center.y)):
			result.append(center)
			return result
	# Bounded recovery covers the box padding plus rounding, not entire rooms.
	for x in range(center.x - 2, center.x + 3):
		for z in range(center.y - 2, center.y + 3):
			var cell := Vector2i(x, z)
			if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
				continue
			var endpoint := Vector3(x, point.y, z)
			if point.distance_to(endpoint) <= 2.25 and navigation_segment_clear(point, endpoint):
				result.append(cell)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).distance_squared_to(Vector2(point.x, point.z)) < Vector2(b).distance_squared_to(Vector2(point.x, point.z)))
	return result

func navigation_segment_clear(from: Vector3, to: Vector3, radius: float = 0.0) -> bool:
	# World geometry and closed mission doors share layer 1 with actors.
	# Excluding actors keeps a temporary crowd from invalidating the global path.
	var exclusions: Array[RID] = []
	for actor in get_children():
		if actor is CharacterBody3D:
			exclusions.append(actor.get_rid())
	var side := Vector3(to.z - from.z, 0, from.x - to.x).normalized() * radius
	var space := get_world_3d().direct_space_state
	var offsets: Array[Vector3] = [Vector3.ZERO]
	if radius > 0.0:
		offsets.append(side)
		offsets.append(-side)
	for height in [.35, 1.0]:
		for offset in offsets:
			var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * height + offset, to + Vector3.UP * height + offset, 1, exclusions)
			query.hit_from_inside = true
			if not space.intersect_ray(query).is_empty():
				return false
	return true

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not finished and not loadout_pending:
		set_pause(not get_tree().paused)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not finished:
		_save_run_history("abandoned")
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(menu) and not finished:
		set_pause(true)

func set_pause(paused: bool) -> void:
	if get_tree().paused != paused and not finished:
		if paused and player.has_method("stop_movement_events"):
			player.stop_movement_events()
		log_event("level_paused" if paused else "level_resumed")
		Campaign.flush_events()
	get_tree().paused = paused
	menu.visible = paused
	var mission_notification: Control = get_node_or_null("HUD/Interface/MissionNotification")
	if is_instance_valid(mission_notification) and paused:
		mission_notification.hide()
	menu_title.text = "MISIÓN EN PAUSA"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	if paused:
		resume_button.grab_focus()

func restart() -> void:
	if not finished:
		_save_run_history("abandoned")
	get_tree().paused = false
	get_tree().reload_current_scene()

func restart_mission() -> void:
	if not tutorial_mode:
		Campaign.profile().erase("checkpoint")
		Campaign.save_data()
	restart()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if not finished:
		elapsed += delta
		if not _history_id.is_empty():
			Campaign.events.heartbeat(_history_id,elapsed,maxi(0,kills-_history_kills_start))
			if replay != null:
				replay.tick(delta)
	hit_time = maxf(0, hit_time - delta)
	damage_time = maxf(0, damage_time - delta)
	crosshair.text = "×" if hit_time > 0 else "+"
	crosshair.visible = bool(Campaign.options.crosshair)
	crosshair.modulate = Color("ffce69") if hit_time > 0 else Color.WHITE
	damage_overlay.color = Color(0.9, 0.08, 0.12, damage_time * 0.8)
	if is_instance_valid(stasis_frame) and is_instance_valid(player):
		stasis_frame.visible = not finished and player.stasis_slow_left > 0.0
	if is_instance_valid(low_health_cloud) and is_instance_valid(player):
		var health_ratio: float = float(player.health) / maxf(1.0, float(player.max_health))
		var urgency: float = clampf((0.5 - health_ratio) / 0.5, 0.0, 1.0)
		low_health_cloud.visible = not finished and player.health > 0 and health_ratio < 0.5
		if is_instance_valid(low_health_material):
			low_health_material.set_shader_parameter("cloud_opacity", lerpf(0.07, 0.3, urgency))
			low_health_material.set_shader_parameter("cloud_size", lerpf(0.29, 0.52, urgency))

func update_hud() -> void:
	if not is_instance_valid(stats) or not is_instance_valid(player):
		return
	stats.text = "PV %d/%d · ESCUDO %d · BAJAS %d\n%s %d/%d · RESERVA %d · GRANADAS %d" % [player.health, player.max_health, int(player.shield), kills, player.Weapons.DATA[player.weapon_id].title, player.ammo, player.ammo_capacity, player.reserve, player.grenades]
	if player.reload_time > 0:
		stats.text += " · RECARGANDO"
	regen_status.text = ""
	if player.health > 0 and player.health < player.max_health:
		regen_status.text = "REGENERACIÓN EN %.1f s" % player.regen_wait if player.regen_wait > 0 else "REGENERANDO +%d PV/s" % player.regen_rate
	if is_instance_valid(hud_view):
		hud_view.refresh()

func enemy_killed() -> void:
	kills += 1
	update_hud()
	# Mission objectives decide victory; kills remain part of the score.

func end_game(won: bool) -> void:
	if finished:
		return
	finished = true
	var result_title: String
	if won:
		var score := kills * 100 + 500 + maxi(0, 300 - int(elapsed)) + roundi(200.0 * player.health / player.max_health)
		var saved := true
		if not tutorial_mode:
			saved = Campaign.complete_level(level_number - 1, score, mission.found_weapons, mission.found_grenades)
			if saved:
				log_event("level_completed",{"score":score,"total_score":Campaign.total_score(),"weapons_found":mission.found_weapons.duplicate(),"grenades_found":mission.found_grenades.duplicate()})
			saved = _save_run_history("victory",score) and saved
		result_title = ("CAMPAÑA COMPLETADA" if level_number == Campaign.LEVELS.size() else "SECTOR ASEGURADO") + "\n%d puntos · Total %d" % [score, Campaign.total_score()]
		if tutorial_mode:
			result_title = "ENTRENAMIENTO COMPLETADO"
			Campaign.profile()["tutorial_completed"] = true
			Campaign.save_data()
		if not saved:
			result_title += "\n" + Campaign.save_error
		# The winning shot still needs to finish its ray, flash and audio.
		# Save immediately, but keep the tree unpaused while feedback plays.
		var delay := VICTORY_DELAY
		var shot: AudioStreamPlayer = player.get_node("Shot")
		if shot.playing and shot.stream != null:
			delay = maxf(delay, shot.stream.get_length() - shot.get_playback_position() + 0.05)
		await get_tree().create_timer(delay, false).timeout
	else:
		_save_run_history("defeat")
		result_title = "MISIÓN FALLIDA\nBajas: %d / %d" % [kills, enemy_count]
	set_pause(true)
	resume_button.hide()
	menu_title.text = result_title
	next_button.visible = won and not tutorial_mode and level_number < Campaign.LEVELS.size()
	if won and not tutorial_mode and Campaign.pending() >= 0:
		next_button.text = "Elegir mejora"
		$UpgradeScreen.refresh()
	else:
		find_child("Restart", true, false).grab_focus()
	result_presented.emit()

func beam(start: Vector3, end: Vector3, color: Color) -> void:
	var length := start.distance_to(end)
	if length < 0.01:
		return
	var ray := Kit.box(self, Vector3(0.025, 0.025, length), (start + end) / 2, color, true)
	ray.look_at(end)
	get_tree().create_timer(0.06, false).timeout.connect(ray.queue_free)

func _save_run_history(outcome: String, score: int = 0) -> bool:
	if _history_id.is_empty() or _history_saved or tutorial_mode:
		return true
	var entry := {"id":_history_id,"profile_id":_history_profile,"level":level_number,"difficulty":int(Campaign.options.difficulty),"outcome":outcome,"duration":maxf(0,elapsed-_history_elapsed_start),"score":maxi(0,score),"kills":maxi(0,kills-_history_kills_start),"started_at":_history_started,"ended_at":Time.get_datetime_string_from_system(true)+"Z"}
	if player.has_method("stop_movement_events"):
		player.stop_movement_events()
	if player.has_method("cancel_reload_event"):
		player.cancel_reload_event("run_ended")
	if replay != null:
		replay.finish()
	Campaign.events.finish(entry)
	_history_saved = Campaign.record_run(entry)
	return _history_saved

func quit_game() -> void:
	if not finished:
		_save_run_history("abandoned")
	get_tree().quit()

func _exit_tree() -> void:
	if not finished:
		_save_run_history("abandoned")

func log_event(type: String, payload: Dictionary = {}) -> void:
	if tutorial_mode or _history_id.is_empty():
		return
	if replay != null and type in ["level_paused","checkpoint_created"]:
		replay.checkpoint()
	if type == "loadout_selected" and replay != null:
		replay.set_loadout(payload.get("weapons",[]))
	Campaign.events.append(_history_id,type,elapsed,payload)
