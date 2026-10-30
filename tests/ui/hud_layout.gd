extends SceneTree

func _initialize() -> void:
	preload("res://tests/helpers/test_paths.gd").prepare()
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/test-results/capturas/hud-%s.png" % name)

func run() -> void:
	root.size = Vector2i(1280, 720)
	# The editor can inspect and change every instrument without running a level.
	var preview = load("res://scenes/ui/hud.tscn").instantiate()
	assert(preview.has_node("Interface/GameHUD/VitalsInstrument/Content/HealthBar"))
	assert(preview.has_node("Interface/GameHUD/ArsenalInstrument/Content/AmmoRow/Ammunition"))
	assert(preview.has_node("Interface/MissionPanel/Content/Title"))
	var preview_title: Label = preview.get_node("Interface/MissionPanel/Content/Title")
	preview_title.add_theme_font_size_override("font_size",19)
	var authored_children: int = preview.get_node("Interface/GameHUD").get_child_count()
	root.add_child(preview)
	await process_frame
	assert(preview_title.get_theme_font_size("font_size") == 19,"Controller preserves editor styling")
	assert(preview.get_node("Interface/GameHUD").get_child_count() == authored_children,"No instruments constructed at runtime")
	preview.queue_free()
	await process_frame
	var campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/test-results/logs/hud-layout-profile.cfg"
	campaign.profiles = {"hud": campaign.fresh_profile("HUD Test")}
	campaign.active_id = "hud"
	campaign.profile().completed = range(10)
	campaign.profile().weapon_unlocks = ["rifle", "shotgun", "precision", "plasma"]
	campaign.profile().grenade_unlocks = ["fragmentation", "slow"]
	campaign.music_volume = 0
	var game = load(campaign.LEVELS[0].path).instantiate()
	root.add_child(game)
	current_scene = game
	if game.has_node("LoadoutScreen"):
		game.get_node("LoadoutScreen").accept()
	game.set_pause(false)
	await process_frame
	await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	for node in game.find_children("*", "Node", true, false):
		node.process_mode = Node.PROCESS_MODE_DISABLED
	game.update_hud()
	await capture("normal")
	var hud = game.hud_view
	assert(not game.stats.visible)
	assert(not game.find_child("Controls", true, false).visible)
	assert(hud.health_bar.value == game.player.health)
	assert(hud.ammunition.text == "12 / 12")
	assert(hud.grenade.text == game.player.grenade_label())
	var aim_area := Rect2(root.size / 2 - Vector2i(150, 100), Vector2(300, 200))
	for instrument: Control in hud.get_children():
		assert(not instrument.get_global_rect().intersects(aim_area), "Instruments must leave the aiming area clear")
		assert(Rect2(Vector2.ZERO, root.size).encloses(instrument.get_global_rect()), "Instrument outside viewport")
	game.player.health = 23
	game.player.shield_max = 50
	game.player.shield = 19
	game.player.regen_wait = 3.2
	game.player.ammo = 0
	game.player.reload_time = game.player.reload_duration * .55
	game.kills = 7
	game.elapsed = 367
	game.update_hud()
	await capture("critical-reload")
	assert(hud.health_bar.value == 23)
	assert(hud.gun_state.text == "RECARGANDO")
	assert(hud.telemetry.text.contains("06:07"))
	assert(hud.recovery.text.contains("3.2"))
	game.player.reload_time = 0
	game.player.set_loadout(["pistol", "plasma"])
	game.player.equip("plasma")
	game.player.grenade_type = "slow"
	campaign.bindings.grenade_cycle = KEY_T
	game.mission.hint.text = "MISIÓN · ETAPA 4/8\nASEGURAR LA TRANSMISIÓN\nDEFENSA 42 s · amenazas activas 6\nProtege los tres enlaces hasta completar el envío."
	game.update_hud()
	await capture("arsenal-grenades")
	assert(hud.grenade.text == game.player.grenade_label())
	assert(hud.grenade_key.text.contains("T"))
	assert(hud.grenade_stocks.text.contains("FRAG."))
	assert(hud.objective_title.text == "ASEGURAR LA TRANSMISIÓN")
	assert(hud.objective_details.text.contains("42 s"))
	assert(game.get_node("HUD/Interface/MissionPanel").anchor_right == 1)
	assert(game.get_node("HUD/Interface/MissionPanel").offset_left == -350)
	campaign.music.stream_paused = false
	campaign.music.stop()
	campaign.music.stream = null
	game.queue_free()
	current_scene = null
	await process_frame
	await create_timer(.3).timeout
	print("HUD LAYOUT PASS · corner panels, health/reload states, grenade stocks/key, mission display")
	quit()
