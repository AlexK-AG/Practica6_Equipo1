extends SceneTree
const Driver = preload("res://tests/helpers/mission_driver.gd")
var campaign: Node
func _initialize() -> void:
	call_deferred("run")
func make_game() -> Node:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	if game.has_node("LoadoutScreen"):
		game.get_node("LoadoutScreen").accept()
	game.set_pause(false)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.mission.set_process(false)
	game.mission.doors.set_process(false)
	for actor in game.get_children():
		if actor is EnemyController:
			actor.set_physics_process(false)
	return game
func close_game(game: Node) -> void:
	game.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	paused = false
func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	campaign = root.get_node("Campaign")
	campaign.save_path = "res://.godot/sqlite-history-private.sqlite"
	campaign.profiles = {}
	assert(campaign.select_profile("History"))
	campaign.profile().completed = range(10)
	campaign.options.difficulty = 2
	var game = make_game()
	game.elapsed = 12.5
	game.mission.checkpoint()
	var first_id: String = game._history_id
	await close_game(game)
	var rows: Array = campaign.store.rows("SELECT * FROM run_history WHERE id=?",[first_id])
	assert(rows.size()==1 and rows[0].outcome=="abandoned" and rows[0].duration_seconds==12.5)
	campaign.load_data()
	game = make_game()
	assert(game.elapsed==12.5,"Checkpoint preserves elapsed mission time in SQLite")
	game.elapsed = 17.5
	var second_id: String = game._history_id
	game.end_game(false)
	await close_game(game)
	rows = campaign.store.rows("SELECT * FROM run_history WHERE id=?",[second_id])
	assert(rows.size()==1 and rows[0].outcome=="defeat" and rows[0].duration_seconds==5.0,"Resumed attempt counts only new active time")
	campaign.profile().erase("checkpoint")
	game = make_game()
	game.elapsed = 9
	game.kills = 4
	var third_id: String = game._history_id
	await game.end_game(true)
	assert(game._save_run_history("victory"),"Repeating finalization is idempotent")
	await close_game(game)
	rows = campaign.store.rows("SELECT * FROM run_history WHERE id=?",[third_id])
	assert(rows.size()==1 and rows[0].outcome=="victory" and rows[0].kills==4 and rows[0].difficulty==2)
	assert(rows[0].score == int(campaign.profile().scores["0"]),"History stores the actual winning score")
	var count: int = campaign.store.rows("SELECT COUNT(*) AS n FROM run_history")[0].n
	assert(count==3)
	var tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	await close_game(tutorial)
	assert(campaign.store.rows("SELECT COUNT(*) AS n FROM run_history")[0].n==count,"Optional training does not create campaign history")
	assert(campaign.reset_campaign())
	assert(campaign.store.rows("SELECT COUNT(*) AS n FROM run_history")[0].n==count,"Reset keeps history")
	assert(campaign.delete_profile("history"))
	assert(campaign.store.rows("SELECT COUNT(*) AS n FROM run_history")[0].n==0,"Profile deletion removes its own history")
	campaign.music.stream_paused = false
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(.3).timeout
	print("SQLITE HISTORY PASS: abandonment, defeat, victory, active time, duplicate protection, tutorial, reset and deletion")
	quit()
