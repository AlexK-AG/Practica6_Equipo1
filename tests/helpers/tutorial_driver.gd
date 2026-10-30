extends RefCounted
## Deterministic actions; explanations still require an explicit Next.
static func practice(game: Node) -> void:
	var mission = game.mission
	var guide = mission.tutorial_guide
	match guide.current_id():
		"move":
			game.player.position = mission.objects[0].position
			mission.process_tutorial()
		"terminal","card","supply","weapon_pickup","grenade_pickup","exit":
			for item in mission.objects:
				if guide.accepts(item.object_id):
					item.interact()
					break
		"shoot":
			mission.objects[1].take_damage(60)
			game.player.ammo -= 3
		"reload":
			game.player.switch_time = 0
			game.player.start_reload()
			mission.process_tutorial()
			game.player._physics_process(game.player.reload_duration + .01)
			mission.process_tutorial()
		"switch":
			game.player.equip("rifle")
			mission.process_tutorial()
		"knife":
			game.player.melee_flash = .2
			mission.objects[2].take_damage(65)
		"grenade":
			game.player.grenade_wait = 0
			game.player.throw_grenade()
			mission.process_tutorial()
		"grenade_cycle":
			game.player.cycle_grenade()
			mission.process_tutorial()

static func complete(game: Node) -> void:
	var guide = game.mission.tutorial_guide
	for iteration in range(40):
		if game.finished:
			return
		if not guide.complete:
			practice(game)
		if not game.finished:
			assert(guide.complete,"Tutorial practice must finish before Next")
			guide.advance()
