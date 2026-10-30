extends SceneTree

class FailingCampaign extends "res://scripts/persistence/campaign.gd":
	func save_data() -> bool:
		save_error = "Simulated test write failure"
		return false

func _initialize() -> void:
	preload("res://tests/helpers/test_paths.gd").prepare()
	call_deferred("run")

func capture(name: String) -> void:
	if "--profile-gallery" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/test-results/capturas/profile-management-%s.png" % name)

func run() -> void:
	var campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/test-results/logs/profile-management.cfg"
	campaign.profiles = {"alfa": campaign.fresh_profile("Alfa"), "beta": campaign.fresh_profile("Beta")}
	campaign.profiles.alfa.completed = [0, 1]
	campaign.profiles.alfa.scores = {"0": 1200, "1": 1400}
	campaign.profiles.alfa.record = 2600
	campaign.profiles.alfa.discovered_enemies = [0, 2, 13]
	campaign.profiles.beta.weapon_unlocks = ["shotgun"]
	campaign.profiles.beta.discovered_enemies = [4, 5]
	campaign.profiles.beta.record = 1800
	campaign.active_id = "alfa"
	campaign.music_volume = 0
	assert(campaign.save_data())
	var untouched: Dictionary = campaign.profiles.alfa.duplicate(true)
	var menu = load("res://scenes/start.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu.show_page("WeaponPage")
	var cards = menu.find_child("WeaponCards", true, false)
	assert(cards.get_child_count() == 6)
	assert(cards.get_node("WeaponCard_pistol").get_meta("unlocked"))
	assert(cards.get_node("WeaponCard_knife").get_meta("unlocked"))
	assert(not cards.get_node("WeaponCard_shotgun").get_meta("unlocked"))
	for card in cards.get_children():
		assert(card.find_child("WeaponPreview", true, false).texture != null)
	await capture("weapons-locked")
	campaign.active_id = "beta"
	menu.show_page("WeaponPage")
	assert(cards.get_node("WeaponCard_shotgun").get_meta("unlocked"))
	assert(not cards.get_node("WeaponCard_precision").get_meta("unlocked"))
	await capture("weapons-unlocked")
	if "--profile-gallery" in OS.get_cmdline_user_args():
		campaign.profiles.beta.weapon_unlocks = ["shotgun", "precision", "plasma"]
		menu.show_page("WeaponPage")
		await process_frame
		await process_frame
		cards.get_parent().scroll_vertical = int(cards.get_parent().get_v_scroll_bar().max_value)
		await capture("weapons-plasma-knife")
		campaign.profiles.beta.weapon_unlocks = ["shotgun"]
	campaign.active_id = "alfa"
	menu.show_profiles()
	menu.request_profile_deletion()
	var dialog: ConfirmationDialog = menu.get_node("DeleteConfirmation")
	assert(dialog.visible)
	assert("Alfa" in dialog.dialog_text)
	assert(campaign.profiles.size() == 2)
	await capture("confirmation")
	dialog.hide()
	dialog.canceled.emit()
	assert(menu.pending_delete_id.is_empty())
	assert(campaign.profiles.size() == 2)
	var beta_index: int = menu.profile_ids.find("beta")
	menu.get_node("%SavedProfiles").select(beta_index)
	menu.profile_selection_changed(beta_index)
	menu.request_profile_deletion()
	assert("Beta" in dialog.dialog_text)
	dialog.hide()
	dialog.confirmed.emit()
	assert(campaign.active_id == "alfa")
	assert(campaign.profiles.size() == 1)
	assert(campaign.profiles.alfa == untouched)
	var backup = preload("res://scripts/persistence/campaign_store.gd").new()
	assert(backup.open(campaign.database_path()+".bak"))
	var snapshot: Dictionary = backup.load_snapshot()
	assert(not snapshot.profiles.has("beta"))
	assert(snapshot.profiles.alfa == untouched)
	backup.close()
	menu.request_profile_deletion()
	dialog.hide()
	dialog.confirmed.emit()
	assert(campaign.active_id.is_empty())
	assert(campaign.profiles.is_empty())
	assert(menu.find_child("ProfilePage", true, false).visible)
	assert(menu.find_child("DeleteProfile", true, false).disabled)
	assert(menu.get_node("%SavedProfiles").item_count == 0)
	assert(menu.get_node("%PlayerName").text.is_empty())
	await capture("empty")
	campaign.load_data()
	assert(campaign.profiles.is_empty())
	var failure := FailingCampaign.new()
	failure.profiles = {"alfa": untouched.duplicate(true)}
	failure.active_id = "alfa"
	assert(not failure.delete_profile("alfa"))
	assert(failure.active_id == "alfa")
	assert(failure.profiles.alfa == untouched)
	failure.free()
	print("PROFILE MANAGEMENT PASS · cancel, inactive/active/last deletion, backup, reload, rollback, weapon index")
	# Muted playback still owns an audio-thread playback resource. Release the
	# entire menu fixture before shutting down the headless mixer.
	menu.menu_music_player.stream_paused = false
	menu.menu_music_player.stop()
	menu.menu_music_player.stream = null
	campaign.music.stop()
	campaign.music.stream = null
	menu.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	await create_timer(0.3).timeout
	quit()
