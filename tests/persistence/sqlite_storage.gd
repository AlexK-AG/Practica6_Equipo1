extends SceneTree
const CampaignScript = preload("res://scripts/persistence/campaign.gd")
const Store = preload("res://scripts/persistence/campaign_store.gd")
const DB_PATH := "res://.godot/sqlite-storage-private.sqlite"
const CFG_PATH := "res://.godot/sqlite-storage-private.cfg"
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func remove_fixture(path: String) -> void:
	assert(path.begins_with("res://.godot/sqlite-storage-private"))
	if FileAccess.file_exists(path):
		assert(DirAccess.remove_absolute(path)==OK)
func make_campaign():
	var campaign = CampaignScript.new()
	campaign.save_path = DB_PATH
	campaign.legacy_save_path = CFG_PATH
	return campaign
func history(id: String,profile_id: String = "legacy") -> Dictionary:
	return {"id":id,"profile_id":profile_id,"level":3,"difficulty":2,"outcome":"victory","duration":75.5,"score":2400,"kills":11,"started_at":"2026-10-16T00:00:00Z","ended_at":"2026-10-16T00:01:15Z"}
func run() -> void:
	assert("--campaign-test" in OS.get_cmdline_user_args())
	var campaign = make_campaign()
	if "--existing-save-check" in OS.get_cmdline_user_args():
		var source := "user://campaigns.cfg"
		assert(FileAccess.file_exists(source),"Existing CFG is present")
		var source_bytes := FileAccess.get_file_as_bytes(source)
		campaign.save_path = "res://.godot/sqlite-existing-check.sqlite"
		campaign.legacy_save_path = "res://.godot/sqlite-existing-check.cfg"
		for suffix in ["",".bak"]:
			if FileAccess.file_exists(campaign.save_path+suffix):
				assert(DirAccess.remove_absolute(campaign.save_path+suffix)==OK)
		assert(DirAccess.copy_absolute(source,campaign.legacy_save_path)==OK)
		var original := ConfigFile.new()
		assert(original.load(source)==OK)
		var expected = CampaignScript.new()
		expected.profiles = original.get_value("campaign","profiles",{}).duplicate(true)
		expected._migrate_profiles(int(original.get_value("campaign","version",1)))
		campaign.load_data()
		check(campaign.save_error.is_empty() and campaign.profiles==expected.profiles,"Copy of actual existing save migrates without losing profile data")
		check(FileAccess.get_file_as_bytes(source)==source_bytes,"Actual save remains untouched")
		print("EXISTING SAVE MIGRATION COPY: ",campaign.profiles.size()," profiles verified")
		expected.free()
		campaign.free()
		finish()
		return
	if "--reload-only" in OS.get_cmdline_user_args():
		campaign.load_data()
		check(campaign.profile().name=="Reload","Active player survives another process")
		check(campaign.profile().checkpoint.player.position==Vector3(2,1,3),"Typed checkpoint survives another process")
		check(campaign.store.rows("SELECT * FROM run_history WHERE id='reload-history'").size()==1,"Run history survives another process")
		check(campaign.available_weapons(3).has("shotgun"),"Unlocks survive another process")
		campaign.free()
		finish()
		return
	for suffix in ["",".bak"]:
		remove_fixture(DB_PATH+suffix)
		remove_fixture(CFG_PATH+suffix)
	var legacy: Dictionary = campaign.fresh_profile("Legacy")
	legacy.completed = [0,1]
	legacy.scores = {"0":1200,"1":1500}
	legacy.record = 4000
	legacy.choices = {"0":"health","1":"damage"}
	legacy.weapon_unlocks = ["shotgun"]
	legacy.grenade_unlocks = ["fragmentation"]
	legacy.discovered_enemies = [0,4,13]
	legacy.loadout = ["pistol","shotgun"]
	legacy.tutorial_completed = true
	legacy.extra_future_field = {"keep":true}
	legacy.checkpoint = {"level":3,"elapsed":61.25,"player":{"position":Vector3(2,1,3),"inventory":{"pistol":{"ammo":3,"reserve":8}}},"enemies":[{"position":Vector3(5,0,3),"scale":Vector3.ONE,"search":{"points":[Vector3(1,0,1)]},"path":PackedVector2Array([Vector2(1,2),Vector2(3,4)])}]}
	var config := ConfigFile.new()
	config.set_value("campaign","version",4)
	config.set_value("campaign","profiles",{"legacy":legacy,"inactive":campaign.fresh_profile("Inactive")})
	config.set_value("settings","options",{"brightness":1.2,"difficulty":2,"resolution":1})
	config.set_value("settings","bindings",{"reload":KEY_T})
	config.set_value("settings","music",.6)
	assert(config.save(CFG_PATH)==OK)
	var old_bytes := FileAccess.get_file_as_bytes(CFG_PATH)
	campaign.load_data()
	check(campaign.save_error.is_empty(),"Legacy migration succeeds")
	check(FileAccess.get_file_as_string(DB_PATH).begins_with("SQLite format 3"),"Save is a real SQLite database")
	check(campaign.profiles.legacy.checkpoint==legacy.checkpoint,"Migration preserves nested Godot values exactly")
	check(campaign.profiles.legacy.extra_future_field==legacy.extra_future_field,"Unknown profile fields survive migration")
	check(campaign.profiles.inactive.weapon_unlocks.has("rifle"),"Version-four migration includes inactive profiles")
	check(FileAccess.get_file_as_bytes(CFG_PATH)==old_bytes,"Legacy configuration stays untouched")
	check(campaign.bindings.reload==KEY_T and is_equal_approx(campaign.music_volume,.6) and campaign.options.difficulty==2,"Settings and controls migrate")
	check(campaign.select_profile("Legacy"),"Migrated profile can be selected")
	var expected: Dictionary = campaign.profiles.duplicate(true)
	campaign.profiles.clear()
	campaign.load_data()
	check(campaign.profiles==expected,"Full snapshot round trip preserves all profiles")
	check(campaign.store.rows("SELECT * FROM level_progress WHERE profile_id='legacy' AND completed=1").size()==2,"Completed levels have queryable rows")
	check(campaign.store.rows("SELECT * FROM unlocks WHERE profile_id='legacy'").size()==6,"Weapons, grenades and enemy discoveries have queryable rows")
	check(campaign.store.rows("SELECT * FROM upgrades WHERE profile_id='legacy'").size()==2,"Chosen improvements have queryable rows")
	check(int(campaign.store.rows("SELECT * FROM leaderboard WHERE id='legacy'")[0].current_score)==2700,"SQL leaderboard matches saved best scores")
	var uuid: String = campaign.store.rows("SELECT uuid FROM profiles WHERE id='legacy'")[0].uuid
	check(campaign.record_run(history("one")),"Run history saves")
	check(campaign.record_run(history("one")),"A retried history entry is safe")
	check(campaign.store.rows("SELECT * FROM run_history").size()==1,"Run history is idempotent")
	check(campaign.reset_campaign(),"Campaign reset still works")
	check(campaign.store.rows("SELECT * FROM run_history").size()==1,"Campaign reset retains history")
	check(campaign.store.rows("SELECT uuid FROM profiles WHERE id='legacy'")[0].uuid==uuid,"Player UUID survives campaign reset")
	# A failure after deleting another profile must roll the entire transaction back.
	check(campaign.store.execute("CREATE TRIGGER reject_test BEFORE UPDATE ON profiles WHEN NEW.display_name='Blocked' BEGIN SELECT RAISE(ABORT,'test rollback'); END"),"Create failure fixture")
	var before: Dictionary = campaign.store.load_snapshot()
	var rejected: Dictionary = before.profiles.duplicate(true)
	rejected.erase("inactive")
	rejected.legacy.name = "Blocked"
	check(not campaign.store.save_snapshot(rejected,before.settings,"legacy"),"Failed transaction reports failure")
	check(campaign.store.load_snapshot()==before,"Partial profile/settings writes are rolled back")
	check(campaign.store.execute("DROP TRIGGER reject_test"),"Remove failure fixture")
	# A second writer cannot partially overwrite data or create a ghost player.
	var lock: Object = ClassDB.instantiate("SQLite")
	lock.path = DB_PATH
	lock.default_extension = ""
	lock.verbosity_level = 0
	check(lock.open_db() and lock.query("BEGIN IMMEDIATE"),"Hold a write lock")
	var previous_active: String = campaign.active_id
	check(not campaign.select_profile("Ghost"),"Busy database reports failed profile creation")
	check(campaign.active_id==previous_active and not campaign.profiles.has("ghost"),"Failed selection restores memory")
	lock.query("ROLLBACK")
	lock.close_db()
	check(campaign.save_data(),"Saving recovers after the writer releases its lock")
	check(campaign.delete_profile("inactive"),"Delete inactive profile")
	campaign.store.close()
	# Physical corruption recovers a complete backup without reimporting stale CFG.
	var corrupt := FileAccess.open(DB_PATH,FileAccess.WRITE)
	corrupt.store_string("damaged sqlite fixture")
	corrupt.close()
	campaign.load_data()
	check(campaign.store.recovered,"Corrupt database recovers verified SQLite backup")
	check(not campaign.profiles.has("inactive"),"Recovery never resurrects the deleted legacy player")
	check(campaign.store.rows("SELECT * FROM run_history").size()==1,"Backup contains the complete history")
	campaign.store.close()
	remove_fixture(DB_PATH)
	campaign.load_data()
	check(campaign.store.recovered and not campaign.profiles.has("inactive"),"Missing primary restores SQLite backup before considering legacy CFG")
	check(campaign.delete_profile("legacy"),"Delete last profile")
	campaign.load_data()
	check(campaign.profiles.is_empty() and campaign.store.rows("SELECT * FROM run_history").is_empty(),"Empty database remains authoritative; related history is deleted")
	# A DB from a future version is never downgraded or replaced by a backup.
	check(campaign.store.execute("PRAGMA user_version=999"),"Simulate future schema")
	campaign.store.close()
	campaign.load_data()
	check(not campaign.save_error.is_empty() and not campaign.save_data(),"Unsupported schema blocks writes")
	var future: Object = ClassDB.instantiate("SQLite")
	future.path = DB_PATH
	future.default_extension = ""
	future.verbosity_level = 0
	assert(future.open_db() and future.query("PRAGMA user_version=1"))
	future.close_db()
	campaign.load_data()
	check(campaign.select_profile("Reload"),"Create fixture for process restart")
	campaign.profile().checkpoint = legacy.checkpoint.duplicate(true)
	campaign.profile().weapon_unlocks = ["shotgun"]
	check(campaign.record_run(history("reload-history","reload")),"Store restart fixture")
	campaign.free()
	finish()
func finish() -> void:
	print("SQLITE STORAGE: %d failures" % failures)
	quit(1 if failures else 0)
