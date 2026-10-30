extends SceneTree
const DB := "res://.godot/sqlite-events-private.sqlite"
var campaign: Node
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func count(type: String, id: String = "") -> int:
	return int(campaign.store.rows("SELECT COUNT(*) AS n FROM game_events WHERE event_type=? AND (?='' OR session_id=?)",[type,id,id])[0].n)

func finish() -> void:
	campaign.music.stream_paused = false
	campaign.music.stop()
	campaign.music.stream = null
	await create_timer(.3).timeout
	print("SQLITE EVENTS: %d failures" % failures)
	quit(1 if failures else 0)

func freeze(game: Node) -> void:
	game.set_pause(false)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.mission.set_process(false)
	game.mission.doors.set_process(false)
	for actor in game.get_children():
		if actor is EnemyController:
			actor.set_physics_process(false)

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	campaign = root.get_node("Campaign")
	if "--reload-only" not in OS.get_cmdline_user_args():
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(DB+suffix):
				assert(DirAccess.remove_absolute(DB+suffix)==OK)
	campaign.save_path = DB
	campaign.load_data()
	if "--reload-only" in OS.get_cmdline_user_args():
		check(count("shot_fired")>0,"Events survive a separate process")
		check(count("session_interrupted","interrupted-fixture")==1,"Interruption recovery survives restart without duplication")
		check(campaign.store.rows("PRAGMA integrity_check")[0].values()[0]=="ok","SQLite integrity")
		finish()
		return
	check(campaign.select_profile("Events"),"Create private player")
	check(campaign.store.rows("SELECT * FROM profile_events WHERE event_type='profile_created'").size()==1,"Profile creation is recorded with the profile")
	# Emulate a version 1 database; opening it must add tables without touching saves.
	var original: Dictionary = campaign.profile().duplicate(true)
	for sql in ["DROP VIEW event_log","DROP TABLE game_events","DROP TABLE run_sessions","PRAGMA user_version=1"]:
		check(campaign.store.execute(sql),"Prepare version 1 fixture")
	campaign.store.close()
	campaign.load_data()
	check(campaign.profile()==original,"Schema upgrade retains the original profile")
	check(campaign.store.rows("PRAGMA user_version")[0].user_version==preload("res://scripts/persistence/campaign_store.gd").SCHEMA_VERSION,"Version 1 upgrades automatically")
	check(count("run_started")==0,"Migration does not invent old actions")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	freeze(game)
	var id: String = game._history_id
	check(count("run_started",id)==1,"Start is durable immediately")
	game.elapsed = 3.0
	game.player.shoot()
	game.player.shoot()
	check(count("shot_fired",id)==0,"Shots are queued rather than written per trigger")
	game.player.cooldown = 0
	game.player.ammo = 4
	game.player.start_reload()
	game.player._physics_process(game.player.reload_duration+.01)
	game.player.start_reload() # Full magazine must not create a reload event.
	game.player.observe_movement(true,true)
	game.player.observe_movement(true,true)
	game.set_pause(true)
	game.set_pause(true)
	game.set_pause(false)
	check(count("shot_fired",id)==1,"Cooldown rejects duplicate shots")
	check(count("reload_started",id)==1 and count("reload_completed",id)==1,"Only actual reloads are logged")
	check(count("movement_started",id)==1 and count("movement_stopped",id)==1,"Movement transitions end on pause")
	check(count("sprint_started",id)==1 and count("sprint_ended",id)==1,"Sprint transitions are not repeated per frame")
	check(count("level_paused",id)==1 and count("level_resumed",id)==1,"Repeated pause calls do not duplicate actions")
	# A blocked write keeps the complete batch; no partial profile or event writes.
	check(campaign.store.execute("CREATE TRIGGER fail_event BEFORE INSERT ON game_events WHEN NEW.event_type='retry_fixture' BEGIN SELECT RAISE(ABORT,'intentional event failure'); END"),"Install failure fixture")
	game.log_event("retry_fixture",{"quote":"' & < >","value":17})
	check(not campaign.flush_events(),"Write failure is reported")
	check(count("retry_fixture",id)==0 and not campaign.events.pending.is_empty(),"Failed batch is retained")
	check(not campaign.save_data(),"Snapshot also rolls back when an event cannot be saved")
	check(campaign.store.execute("DROP TRIGGER fail_event"),"Remove failure fixture")
	check(campaign.flush_events() and campaign.flush_events(),"Retry succeeds and may be repeated")
	check(count("retry_fixture",id)==1,"Retried event is inserted exactly once")
	var payload = JSON.parse_string(campaign.store.rows("SELECT payload_json FROM game_events WHERE event_type='retry_fixture'")[0].payload_json)
	check(payload.quote=="' & < >" and payload.value==17,"Payload uses safe parameter bindings and valid JSON")
	# Successful pickups create events and checkpoints; repeated interaction is rejected.
	for item in game.mission.objects:
		if item.object_id < 0:
			item.active = true
			var type := "weapon_found" if item.object_id <= -100 else "supply_collected"
			check(game.mission.interact_object(item.object_id),"Collect an actual mission object")
			check(not game.mission.interact_object(item.object_id),"Cannot collect the same object twice")
			check(count(type,id)>0,"Pickup and checkpoint are saved together")
	# Damage and final death, including the revival core, are distinct events.
	var enemy: EnemyController
	for actor in game.get_children():
		if actor is EnemyController:
			enemy = actor
			break
	enemy.take_damage(100000,{"source":"test","weapon":"pistol"})
	enemy.finish_death()
	game.player.take_damage(5)
	game.player.grenade_wait = 0
	game.player.throw_grenade()
	for node in game.get_children():
		if node.get_script()==preload("res://scripts/combat/grenade.gd"):
			node.detonate()
	campaign._process(2.1)
	check(count("enemy_hit",id)>0 and count("enemy_killed",id)==1,"Damage and final death are recorded once")
	check(count("player_damaged",id)==1,"Player health and shield damage is recorded")
	check(count("grenade_used",id)==1 and count("grenade_exploded",id)==1,"Grenade launch and explosion are distinct")
	game.elapsed = 12
	check(game._save_run_history("abandoned"),"Finalize session and history")
	check(game._save_run_history("abandoned"),"Repeat finalization safely")
	check(count("run_ended",id)==1,"Exactly one terminal event")
	game.log_event("shot_fired")
	check(campaign.events.pending.is_empty(),"Closed sessions reject late combat events")
	var result: Dictionary = campaign.store.rows("SELECT * FROM run_sessions WHERE id=?",[id])[0]
	check(result.outcome=="abandoned" and result.duration_seconds==12,"Session matches final history time")
	game.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	paused = false
	# A resumed process that died never becomes a fabricated defeat or victory.
	campaign.events.begin("interrupted-fixture","events",1,1,"2026-10-16T00:00:00Z",100,true)
	campaign.events.heartbeat("interrupted-fixture",105,2)
	check(campaign.flush_events(),"Write active session fixture")
	check(campaign.store.execute("UPDATE run_sessions SET owner_pid=2147483647 WHERE id='interrupted-fixture'"),"Emulate dead process")
	campaign.events.recovered_database = ""
	check(campaign.events.recover_interrupted(campaign.store) and campaign.flush_events(),"Recover interrupted session")
	check(count("session_interrupted","interrupted-fixture")==1,"Interruption is recorded once")
	check(campaign.events.recover_interrupted(campaign.store) and campaign.flush_events(),"Recovery is idempotent")
	check(campaign.store.rows("SELECT * FROM run_history WHERE id='interrupted-fixture'").is_empty(),"No invented result after a crash")
	check(campaign.store.rows("SELECT mission_seconds FROM game_events WHERE event_type='session_interrupted'")[0].mission_seconds==105,"Interrupted checkpoint preserves cumulative mission time")
	check(campaign.select_profile("Delete"),"Create deletion fixture")
	campaign.begin_events("delete-fixture","delete",1,"2026-10-16T00:00:00Z",0,false)
	check(campaign.delete_profile("delete"),"Delete profile with active session")
	check(campaign.store.rows("SELECT * FROM game_events WHERE session_id='delete-fixture'").is_empty(),"Deletion cascades to sessions and events")
	check(campaign.select_profile("Events"),"Return to original player")
	check(campaign.store.rows("SELECT * FROM profile_events WHERE profile_id='delete'").is_empty(),"Profile deletion removes its menu actions")
	check(campaign.reset_campaign(),"Reset campaign")
	check(count("shot_fired",id)==1,"Reset preserves event history")
	check(campaign.complete_level(0,100),"Prepare a pending reward without an open game scene")
	check(campaign.choose_upgrade("health"),"Choose pending reward from the menu")
	check(not campaign.choose_upgrade("health"),"Cannot choose the same reward twice")
	check(campaign.store.rows("SELECT * FROM profile_events WHERE event_type='upgrade_chosen'").size()==1,"Menu upgrade is logged once without a running scene")
	var options_before: Dictionary = campaign.options.duplicate(true)
	campaign.options.brightness = .85
	check(campaign.save_data(),"Save a global option change")
	var settings_count: int = campaign.store.rows("SELECT COUNT(*) AS n FROM profile_events WHERE event_type='settings_changed'")[0].n
	check(settings_count>0,"Option changes have an audit history")
	check(campaign.save_data(),"Save unchanged options again")
	check(campaign.store.rows("SELECT COUNT(*) AS n FROM profile_events WHERE event_type='settings_changed'")[0].n==settings_count,"Unchanged options do not duplicate events")
	check(campaign.store.rows("SELECT * FROM profile_events WHERE event_type='settings_changed' AND profile_id IS NOT NULL").is_empty(),"Global options are not attributed to a profile")
	campaign.options = options_before
	var before_tutorial := int(campaign.store.rows("SELECT COUNT(*) AS n FROM game_events")[0].n)
	var tutorial = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(tutorial)
	tutorial.log_event("shot_fired")
	tutorial.queue_free()
	await process_frame
	check(int(campaign.store.rows("SELECT COUNT(*) AS n FROM game_events")[0].n)==before_tutorial,"Tutorial does not pollute campaign statistics")
	check(campaign.store.rows("PRAGMA foreign_key_check").is_empty(),"All event references are valid")
	check(campaign.save_data(),"Backup contains committed events")
	await create_timer(1.2).timeout
	finish()
