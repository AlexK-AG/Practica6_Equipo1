extends SceneTree
var failures := 0
var campaign: Node

func _initialize() -> void:
	preload("res://tests/helpers/test_paths.gd").prepare()
	call_deferred("run")

func check(value: bool,message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/test-results/logs/combat-redesign-profile.cfg"
	campaign.profiles = {"visual":campaign.fresh_profile("Visual")}
	campaign.active_id = "visual"
	campaign.profile().completed = range(10)
	campaign.profile().weapon_unlocks = ["rifle","shotgun","precision","plasma"]
	for level in range(1,11):
		campaign.profile().erase("checkpoint")
		var game = load(campaign.LEVELS[level - 1].path).instantiate()
		root.add_child(game)
		current_scene = game
		if game.has_node("LoadoutScreen"):game.get_node("LoadoutScreen").accept()
		game.set_pause(false)
		game.player.set_physics_process(false)
		game.mission.set_process(false)
		game.mission.doors.set_process(false)
		for actor in game.get_children():
			if actor is EnemyController:
				actor.set_physics_process(false)
				for mesh in actor.get_children():
					if mesh is MeshInstance3D and "Alien_" in mesh.mesh.resource_path:
						check(mesh.material_override is ShaderMaterial,"Enemy retains real kit mesh and gets skin detail")
						check(mesh.material_override.get_shader_parameter("skin_color") == actor.Catalog.ENTRIES[actor.kind].color,"Subtype color remains unchanged")
		var details = game.get_node("Arena/Details")
		var count: int = details.get_meta("solid_props")
		check(count >= 5 and count <= 24,"Moderate amount of physical dressing in sector%d: %d" % [level,count])
		for point in game.mission.objects:
			check(preload("res://tests/helpers/navigation_checks.gd").route(game,game.player.position,point.position).size() > 0,"Dressing preserves objective/supply/weapon routes")
		if level == 1:
			var player = game.player
			check(player.gun_models.size() == 5,"Five unique redesigned first-person weapons")
			for id in player.Weapons.DATA:
				player.loadout.assign([id,"pistol" if id != "pistol" else "rifle"])
				player.equip(id)
				check(player.get_node("Shot").stream.resource_path == "res://assets/audio/weapons/%s.wav" % id,"Weapon selects its own sound")
				var visible_count := 0
				for key in player.gun_models:
					if player.gun_models[key].visible:visible_count += 1
				check(visible_count == 1 and player.gun_models[id].visible,"Only the equipped gun is visible")
				check(player.gun_models[id].get_child_count() >= 16,"Detailed gun construction")
				player.switch_time = 0
				player.cooldown = 0
				player.shoot()
				check(player.get_node("Shot").playing and is_equal_approx(player.get_node("Shot").pitch_scale,1),"Redesigned shot plays at its authored pitch")
				player.start_reload()
				check(player.reload_audio.playing and player.reload_audio.bus == &"Effects", "Reload plays on Effects")
				check(player.reload_audio.stream.resource_path.ends_with(id + "_reload.wav"), "Each gun has its own reload")
				check(is_equal_approx(player.reload_audio.stream.get_length() / player.reload_audio.pitch_scale, player.reload_duration), "Reload sound follows upgrade duration")
				player.equip(id)
				check(not player.reload_audio.playing and player.reload_time == 0, "Equipping cancels reload sound")
				player.switch_time = 0
				player.ammo = player.ammo_capacity
				player.start_reload()
				check(not player.reload_audio.playing, "Full magazine does not trigger audio")
				player.ammo = 0
				player.reserve = 0
				player.start_reload()
				check(not player.reload_audio.playing, "Empty reserve does not trigger audio")
			player.reserve = 5
			player.start_reload()
			player.melee_wait = 0
			player.melee_attack()
			check(not player.reload_audio.playing, "Knife interrupts reload audio")
			player._physics_process(.01)
			check(player.knife.visible and player.knife_audio.playing,"Knife has redesigned geometry and independent sound")
		paused = false
		game.queue_free()
		await process_frame
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(.3).timeout
	print("COMBAT REDESIGN: ","PASS" if failures == 0 else "FAIL"," / failures=",failures)
	quit(failures)
