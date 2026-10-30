extends SceneTree

func _initialize() -> void:
	preload("res://tests/helpers/test_paths.gd").prepare()
	call_deferred("run")

func paths(node: Node, base: Node) -> Array[String]:
	var result: Array[String] = [str(base.get_path_to(node))]
	for child in node.get_children():
		result.append_array(paths(child,base))
	return result

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	var campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/test-results/logs/start-scene-private.cfg"
	campaign.profiles = {"scene":campaign.fresh_profile("Scene Test")}
	campaign.active_id = "scene"
	campaign.profile().completed = [0,1,2]
	campaign.profile().weapon_unlocks = ["shotgun"]
	campaign.profile().discovered_enemies = [0,1]
	var menu = load("res://scenes/start.tscn").instantiate()
	var levels = menu.get_node("Margin/Stack/LevelsPage/Scroll/Grid")
	assert(levels.get_child_count() == 10,"All ten level cards exist in the scene")
	var enemies = menu.get_node("Margin/Stack/EnemyPage/Scroll/EnemyCards")
	var weapons = menu.get_node("Margin/Stack/WeaponPage/Scroll/WeaponCards")
	assert(enemies.get_child_count() == 18 and weapons.get_child_count() == 6)
	assert(menu.has_node("Margin/Stack/SettingsPage/Layout/OptionsPanel/GameOptions/Content/Brightness"))
	var headline: Label = menu.get_node("Margin/Stack/MainPage/Layout/Hero/Margin/Content/Headline")
	assert(headline.text == "LA CONTENCIÓN\nHA FALLADO","Authored multiline copy keeps its original spacing")
	headline.text = "CAMBIO DESDE EL EDITOR"
	headline.add_theme_font_size_override("font_size",31)
	var before := paths(menu,menu)
	root.add_child(menu)
	current_scene = menu
	await process_frame
	assert(paths(menu,menu) == before,"Menu scripts do not construct or reparent any UI nodes")
	assert(headline.text == "CAMBIO DESDE EL EDITOR" and headline.get_theme_font_size("font_size") == 31)
	var slides = menu.get_node("Margin/Stack/MainPage/Layout/Hero/MainSlideshow")
	var timer: Timer = slides.get_node("SlideTimer")
	assert(not timer.is_stopped() and timer.wait_time == 7,"Authored slideshow timer starts automatically")
	var first_slide: int = slides.slide_index
	timer.start(.05)
	await create_timer(.08).timeout
	assert(slides.slide_index != first_slide,"Timer advances the slideshow without a button")
	timer.start(7)
	menu.show_page("EnemyPage")
	assert(enemies.get_node("EnemyCard0").get_meta("discovered"))
	assert(not enemies.get_node("EnemyCard2").get_meta("discovered"))
	assert(not enemies.get_node("EnemyCard2/Row/Content/Behavior").visible)
	for section in ["Height", "DescriptionTitle", "TacticDivider", "TacticTitle", "Tactic"]:
		assert(enemies.get_node("EnemyCard0/Row/Content/" + section).visible)
		assert(not enemies.get_node("EnemyCard2/Row/Content/" + section).visible)
	assert(enemies.get_node("EnemyCard0/Row/Content/Tactic").text == preload("res://scripts/enemies/enemy_catalog.gd").ENTRIES[0].weakness)
	var catalog = preload("res://scripts/enemies/enemy_catalog.gd")
	campaign.profile().discovered_enemies = range(catalog.ENTRIES.size())
	menu.show_page("EnemyPage")
	for kind in range(catalog.ENTRIES.size()):
		var actor = load("res://scenes/actors/enemy_%d.tscn" % kind).instantiate()
		var collider: CollisionShape3D
		for child in actor.get_children():
			if child is CollisionShape3D:
				collider = child
		var expected: float = collider.shape.size.y*collider.scale.y*actor.scale.y
		assert(is_equal_approx(catalog.body_height(kind),expected),"Index height matches the authored collider")
		var height_label: Label = enemies.get_node("EnemyCard%d/Row/Content/Height" % kind)
		assert(height_label.visible and height_label.text == catalog.height_text(kind))
		assert("." not in height_label.text,"Height uses Spanish decimal notation")
		actor.free()
	assert(enemies.get_node("EnemyCard6/Row/Content/Height").text == "ALTURA · 1,65 m")
	menu.show_page("WeaponPage")
	assert(weapons.get_node("WeaponCard_shotgun").get_meta("unlocked"))
	assert(not weapons.get_node("WeaponCard_plasma").get_meta("unlocked"))
	menu.show_levels()
	assert(levels.get_node("Level3/Content/Launch").disabled == false)
	assert(levels.get_node("Level4/Content/Launch").disabled)
	menu.show_page("SettingsPage")
	menu.show_page("ProfilePage")
	menu.show_page("MainPage")
	assert(paths(menu,menu) == before,"Page switches update data without rebuilding cards")
	menu.menu_music_player.stream_paused = false
	menu.menu_music_player.stop()
	menu.menu_music_player.stream = null
	menu.queue_free()
	current_scene = null
	await process_frame
	await create_timer(.3).timeout
	print("START SCENE PASS: editor nodes, preserved styling, stable hierarchy, profile-specific data and navigation")
	quit()
