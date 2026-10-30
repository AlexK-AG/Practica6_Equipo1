extends SceneTree
const DB := "res://.godot/replay-private.sqlite"
var failures := 0
var campaign: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	campaign = root.get_node("Campaign")
	campaign.store.close()
	for suffix in ["",".bak"]:
		if FileAccess.file_exists(DB+suffix):
			assert(DirAccess.remove_absolute(DB+suffix)==OK)
	campaign.save_path = DB
	campaign.load_data()
	check(campaign.select_profile("Replay test"),"Private profile created")
	# A schema-3 save upgrades without changing profile data.
	var original: Dictionary = campaign.profile().duplicate(true)
	check(campaign.store.execute("DROP TABLE replay_chunks"),"Prepare v3 fixture")
	check(campaign.store.execute("DROP TABLE replay_runs"),"Prepare v3 header fixture")
	check(campaign.store.execute("PRAGMA user_version=3"),"Prepare v3 version")
	campaign.store.close()
	campaign.load_data()
	check(campaign.profile()==original,"Migration preserves profile")
	check(campaign.store.rows("PRAGMA user_version")[0].user_version==4,"Version four enabled")
	campaign.profile().completed = range(10)
	for level in [1,3,4,10]:
		var scene := "res://scenes/main.tscn" if level==1 else "res://scenes/levels/level_%d.tscn" % level
		var game = load(scene).instantiate()
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
		var id: String = game._history_id
		var row: Dictionary = campaign.store.rows("SELECT metadata_json FROM replay_runs WHERE session_id=?",[id])[0]
		var metadata: Dictionary = JSON.parse_string(row.metadata_json)
		check(metadata.level==level and metadata.map.floors.size()>0 and metadata.map.obstacles.size()>0,"Actual scene geometry recorded")
		if level in [3,4]:
			check(metadata.map.doors.any(func(door):return str(door.id).begins_with("extra:")),"Mission shutters included in replay map")
		for n in range(1,7):
			game.elapsed = n*.5
			game.player.position.x += .2
			for actor in game.get_children():
				if actor is EnemyController:
					actor.position.z += .1
					break
			game.replay.tick(.5)
			if n==2:
				game.set_pause(true)
				game._process(4)
				check(game.elapsed==1,"Pause excludes inactive time")
				var paused_chunks: Array = campaign.store.rows("SELECT frames_json FROM replay_chunks WHERE session_id=? ORDER BY chunk_index DESC LIMIT 1",[id])
				check(JSON.parse_string(paused_chunks[0].frames_json).back().t==1,"Pause flushes pending replay samples immediately")
				game.set_pause(false)
		game.log_event("loadout_selected",{"weapons":["pistol"]})
		game._save_run_history("abandoned")
		check(campaign.flush_events(),"Final frame and equipment committed")
		row = campaign.store.rows("SELECT metadata_json FROM replay_runs WHERE session_id=?",[id])[0]
		check(JSON.parse_string(row.metadata_json).loadout==["pistol"],"Chosen equipment remains beyond event retention")
		var chunks: Array = campaign.store.rows("SELECT frames_json FROM replay_chunks WHERE session_id=? ORDER BY chunk_index",[id])
		var samples: Array = []
		for chunk in chunks:
			samples.append_array(JSON.parse_string(chunk.frames_json))
		check(samples.size()>=7 and samples.back().t==3,"Start, movement and final sample saved")
		check(samples[0].p!=samples.back().p and samples[0].enemies.size()>0,"Player and enemy positions captured")
		check(samples[0].enemies[0].p!=samples.back().enemies[0].p,"Enemy movement is recorded independently")
		check(samples[0].enemies[0].id==samples.back().enemies[0].id,"Stable enemy identities across samples")
		check(campaign.store.execute("DELETE FROM game_events WHERE session_id=?",[id]),"Simulate event pruning")
		check(not campaign.store.rows("SELECT * FROM replay_chunks WHERE session_id=?",[id]).is_empty(),"Event pruning keeps replay")
		if level==1:
			check(campaign.store.execute("DELETE FROM run_sessions WHERE id=?",[id]),"Simulate old-attempt retention")
			check(campaign.store.rows("SELECT * FROM replay_runs WHERE session_id=?",[id]).is_empty() and campaign.store.rows("SELECT * FROM replay_chunks WHERE session_id=?",[id]).is_empty(),"Old session deletes its replay in cascade")
		game.queue_free()
		await process_frame
	check(campaign.store.rows("PRAGMA integrity_check")[0].values()[0]=="ok","SQLite integrity")
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(.3).timeout
	print("SQLITE REPLAY: %d failures" % failures)
	quit(1 if failures else 0)
