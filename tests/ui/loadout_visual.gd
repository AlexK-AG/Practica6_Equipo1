extends SceneTree
## Isolated UI test: no campaign file is read or written by the fixture.
class FakeCampaign extends Node:
	var state := {"loadout": ["pistol", "rifle"]}
	var saved := false
	func available_weapons(_level: int) -> Array[String]:
		return ["pistol", "rifle", "shotgun", "precision", "plasma"]
	func profile() -> Dictionary:
		return state
	func save_data() -> void:
		saved = true

class FakePlayer extends Node:
	const Weapons = preload("res://scripts/combat/weapon_catalog.gd")
	var loadout: Array[String] = ["pistol", "rifle"]
	var inventory: Dictionary = {}
	func _init() -> void:
		for id in Weapons.DATA:
			inventory[id] = {"reserve": Weapons.DATA[id].reserve}
	func capacity_for(id: String) -> int:
		return Weapons.DATA[id].capacity
	func set_loadout(ids: Array) -> bool:
		if ids[0] == ids[1]:
			return false
		loadout.assign(ids)
		return true

class FakeGame extends Node:
	var level_number := 10
	var player := FakePlayer.new()
	var loadout_pending := true
	var resumed := false
	func set_pause(value: bool) -> void:
		resumed = not value

func _initialize() -> void:
	preload("res://tests/helpers/test_paths.gd").prepare()
	call_deferred("run")

func run() -> void:
	var original := root.get_node("Campaign")
	root.remove_child(original)
	var campaign := FakeCampaign.new()
	campaign.name = "Campaign"
	root.add_child(campaign)
	var game := FakeGame.new()
	root.add_child(game)
	game.add_child(game.player)
	var screen := CanvasLayer.new()
	screen.set_script(load("res://scripts/ui/loadout_screen.gd"))
	game.add_child(screen)
	await process_frame
	assert(screen.first.is_item_disabled(1))
	assert(screen.second.is_item_disabled(0))
	screen.assign_weapon("rifle")
	assert(screen.first.selected == 0, "Clicking other slot's weapon is blocked")
	screen.assign_weapon("shotgun")
	assert(screen.first.selected == 2)
	assert(not screen.second.is_item_disabled(0), "Previous gun becomes available immediately")
	assert(screen.second.is_item_disabled(2))
	screen.select_slot(1)
	screen.assign_weapon("plasma")
	assert(screen.second.selected == 4)
	screen.first.select(4)
	screen.changed(4, 0)
	assert(screen.first.selected != screen.second.selected, "Programmatic duplicate is corrected")
	screen.select_slot(0)
	screen.assign_weapon("shotgun")
	screen.select_slot(1)
	screen.assign_weapon("plasma")
	await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/test-results/capturas/loadout-visual.png")
	screen.accept()
	assert(campaign.saved and game.resumed and not game.loadout_pending)
	assert(game.player.loadout == ["shotgun", "plasma"])
	await process_frame
	game.queue_free()
	campaign.queue_free()
	await process_frame
	root.add_child(original)
	print("PASS: visual loadout, reciprocal duplicate blocking, reassignment and deploy")
	quit()
