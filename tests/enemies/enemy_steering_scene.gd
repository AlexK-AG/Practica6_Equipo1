extends SceneTree
const Steering = preload("res://scripts/enemies/enemy_steering.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	var campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/enemy-steering-scene-private.cfg"
	campaign.profiles = {}
	campaign.select_profile("Steering scene")
	campaign.profile().completed = range(10)
	campaign.profile().pending = -1
	campaign.profile().erase("checkpoint")
	var game = load(campaign.LEVELS[0].path).instantiate()
	root.add_child(game)
	current_scene = game
	game.set_pause(false)
	if game.has_node("LoadoutScreen"):
		game.get_node("LoadoutScreen").accept()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.position = Vector3(-7,.01,7.35)
	game.mission.set_process(false)
	game.mission.doors.set_process(false)
	var pursuer: EnemyController
	for child in game.get_children():
		if child is EnemyController:
			child.set_physics_process(false)
			child.collision_layer = 0
			if pursuer == null and child.kind == 0:
				pursuer = child
	pursuer.collision_layer = 1
	pursuer.position = Vector3(-7,.01,2)
	var steering := Steering.new()
	steering.setup(pursuer)
	await physics_frame
	await physics_frame
	check(not steering.clear_shot(pursuer,game.player.position),"Cover199 initially blocks the shot")
	var start := pursuer.position
	var moved := 0.0
	var visible := false
	for tick in range(420):
		var direction: Vector3 = steering.direction(pursuer,game.player.position,1.0/60)
		pursuer.velocity = direction * pursuer.move_speed
		pursuer.velocity.y = -1
		pursuer.move_and_slide()
		moved = maxf(moved,pursuer.position.distance_to(start))
		visible = visible or steering.clear_shot(pursuer,game.player.position)
		await physics_frame
	check(moved > 2,"Real actor must approach around the crate instead of freezing")
	check(visible,"Real actor must eventually regain a firing angle near Cover199")
	print("COVER STEERING position=%s moved=%.2f visible=%s" % [pursuer.position,moved,visible])
	game.queue_free()
	await process_frame
	campaign.music.stream_paused = false
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(.3).timeout
	print("ENEMY STEERING SCENE: %d failures" % failures)
	quit(1 if failures else 0)
