extends SceneTree
const Store = preload("res://scripts/persistence/campaign_store.gd")
const DB := "res://.godot/retention-private.sqlite"
var store = Store.new()
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func total(sql: String, args: Array = []) -> int:
	return int(store.rows(sql,args)[0].n)

func stamp(index: int) -> String:
	return Time.get_datetime_string_from_unix_time(1700000000+index)+"Z"

func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	for suffix in ["",".bak"]:
		if FileAccess.file_exists(DB+suffix):
			assert(DirAccess.remove_absolute(DB+suffix)==OK)
	check(store.open(DB),"Open private database")
	var profiles := {"alpha":{"name":"Alpha","record":12345},"beta":{"name":"Beta","record":456}}
	check(store.save_snapshot(profiles,{},"alpha"),"Save private profiles")
	var profile_before: Dictionary = store.load_snapshot().profiles.duplicate(true)
	check(store.execute("BEGIN IMMEDIATE"),"Begin oversized fixture")
	for profile in ["alpha","beta"]:
		for index in range(405 if profile=="alpha" else 3):
			var id: String = profile+"-"+str(index)
			assert(store.execute("INSERT INTO run_history VALUES(?,?,?,?,?,?,?,?,?,?)",[id,profile,1,1,"victory",10,100,2,stamp(index),stamp(index)]))
			assert(store.execute("INSERT INTO run_sessions VALUES(?,?,?,?,?,?,?,?,?,?)",[id,profile,1,1,stamp(index),stamp(index),"victory",10,2,OS.get_process_id()]))
	assert(store.execute("INSERT INTO run_sessions VALUES('active','alpha',1,1,'2000-01-01T00:00:00Z','2000-01-01T00:00:00Z','in_progress',13,1,?)",[OS.get_process_id()]))
	for index in range(2405):
		assert(store.execute("INSERT INTO game_events VALUES(?,?,?,?,?,?,?,?)",["g-"+str(index),"active",index+1,"shot_fired",stamp(index),index,index,"{}"]))
	assert(store.execute("INSERT INTO game_events VALUES('old-parent','alpha-0',1,'run_started','1999-01-01T00:00:00Z',0,0,'{}')"))
	for index in range(10):
		assert(store.execute("INSERT INTO profile_events VALUES(?,'alpha','profile_selected',?,'{}')",["p-"+str(index),"2030-01-01T00:00:%02dZ" % index]))
	for index in range(2404):
		assert(store.execute("INSERT INTO profile_events VALUES(?,NULL,'settings_changed',?,'{}')",["system-"+str(index),stamp(index)]))
	assert(store.execute("INSERT INTO profile_events VALUES('beta-event','beta','profile_created','1999-01-01T00:00:00Z','{}')"))
	assert(store.execute("COMMIT"))
	# Opening an existing schema 2 save must migrate and prune automatically.
	assert(store.execute("DROP TABLE history_archive"))
	assert(store.execute("PRAGMA user_version=2"))
	store.close()
	check(store.open(DB),"Upgrade schema 2 and apply retention")
	check(int(store.rows("PRAGMA user_version")[0].user_version)==Store.SCHEMA_VERSION,"Schema upgraded")
	check(total("SELECT COUNT(*) n FROM (SELECT id FROM run_history WHERE profile_id='alpha' UNION SELECT id FROM run_sessions WHERE profile_id='alpha')")==400,"Exactly 400 unique attempts per player")
	check(total("SELECT COUNT(*) n FROM run_history WHERE profile_id='beta'")==3,"Other player's history is independent")
	check(not store.rows("SELECT id FROM run_sessions WHERE id='active'").is_empty(),"Active attempt survives even with an old timestamp")
	check(store.rows("SELECT id FROM run_history WHERE id='alpha-0'").is_empty(),"Oldest attempts removed")
	check(store.rows("SELECT id FROM game_events WHERE id='old-parent'").is_empty(),"Deleted attempt cascades its events")
	check(total("SELECT COUNT(*) n FROM event_log WHERE profile_id='alpha'")+total("SELECT COUNT(*) n FROM profile_events WHERE profile_id='alpha'")==2400,"Game and menu events share 2400 slots per player")
	check(total("SELECT COUNT(*) n FROM profile_events WHERE profile_id IS NULL")==2400,"General settings have their own allowance")
	check(not store.rows("SELECT id FROM profile_events WHERE id='beta-event'").is_empty(),"Another player's oldest event is untouched")
	check(store.rows("SELECT id FROM game_events WHERE id='g-0'").is_empty(),"Oldest actions deleted first")
	check(not store.rows("SELECT id FROM game_events WHERE id='g-2404'").is_empty(),"Newest action retained")
	check(total("SELECT SUM(attempts) n FROM history_archive WHERE profile_id='alpha'")==6,"Removed attempts are aggregated once")
	check(total("SELECT SUM(duration_seconds) n FROM history_archive WHERE profile_id='alpha'")==60,"Lifetime active time retained")
	check(store.load_snapshot().profiles==profile_before,"Retention does not modify progression or records")
	check(store.save_telemetry({}) and store.save_telemetry({}),"Repeated cleanup succeeds")
	check(total("SELECT SUM(attempts) n FROM history_archive WHERE profile_id='alpha'")==6,"Cleanup does not duplicate archived totals")
	var entry := {"id":"new-run","profile_id":"alpha","level":1,"difficulty":1,"outcome":"victory","duration":20,"score":200,"kills":4,"started_at":"2031-01-01T00:00:00Z","ended_at":"2031-01-01T00:00:20Z"}
	check(store.save_snapshot(profiles,{},"alpha",[entry]),"A new result prunes the next oldest attempt in the same transaction")
	check(total("SELECT SUM(attempts) n FROM history_archive WHERE profile_id='alpha'")==7,"New removal added to aggregate")
	check(total("SELECT SUM(duration_seconds) n FROM history_archive WHERE profile_id='alpha'")+total("SELECT SUM(duration_seconds) n FROM run_history WHERE profile_id='alpha'")+13==4083,"Lifetime duration is unchanged by automatic deletion")
	assert(store.execute("CREATE TRIGGER fail_prune BEFORE DELETE ON game_events BEGIN SELECT RAISE(ABORT,'intentional retention rollback'); END"))
	var event := {"id":"rejected","session_id":"active","sequence":3000,"event_type":"shot_fired","occurred_at":"1990-01-01T00:00:00Z","mission_seconds":0,"active_seconds":0,"payload":{}}
	check(not store.save_telemetry({"events":[event]}),"A cleanup failure is reported")
	check(store.rows("SELECT id FROM game_events WHERE id='rejected'").is_empty(),"Insertion and cleanup roll back together")
	assert(store.execute("DROP TRIGGER fail_prune"))
	check(store.save_snapshot(profiles,{},"alpha"),"Backup includes bounded history and aggregates")
	check(store.rows("PRAGMA foreign_key_check").is_empty(),"No orphan records")
	assert(store.execute("BEGIN"))
	for index in range(401):
		assert(store.execute("INSERT INTO run_history VALUES(?,'beta',1,1,'victory',1,1,1,'2035-01-01T00:00:00Z','2035-01-01T00:00:00Z')",["same-"+str(1000-index)]))
	assert(store.execute("COMMIT"))
	check(store.save_telemetry({}),"Prune attempts with identical timestamps")
	check(store.rows("SELECT id FROM run_history WHERE id='same-1000'").is_empty(),"Timestamp ties remove the oldest insertion, not the lexically smallest ID")
	check(not store.rows("SELECT id FROM run_history WHERE id='same-600'").is_empty(),"Newest insertion survives a timestamp tie")
	store.close()
	check(store.open(DB),"Reopen the bounded database")
	check(total("SELECT SUM(attempts) n FROM history_archive WHERE profile_id='alpha'")==7,"Archived totals persist without being added again on open")
	check(store.execute("DELETE FROM profiles WHERE id='alpha'"),"Delete test player")
	check(store.rows("SELECT * FROM history_archive WHERE profile_id='alpha'").is_empty(),"Deleting a profile also deletes its aggregates")
	store.close()
	print("SQLITE RETENTION: %d failures; per-player limits, migration, ordering, active session, totals and rollback" % failures)
	quit(1 if failures else 0)
