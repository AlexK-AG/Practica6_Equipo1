extends RefCounted
## SQLite is authoritative. BLOB snapshots preserve Godot types; SQL rows serve queries.
const SCHEMA_VERSION := 4
const PAGE_SIZE := 8
const MAX_EVENTS := 300 * PAGE_SIZE
const MAX_RUNS := 50 * PAGE_SIZE
var db: Object
var path := ""
var error := ""
var recovered := false
var crypto := Crypto.new()

func execute(sql: String, args: Array = []) -> bool:
	if db == null or not bool(db.query_with_bindings(sql,args)):
		error = str(db.error_message) if db != null else "SQLite no está disponible."
		return false
	return true

func rows(sql: String, args: Array = []) -> Array:
	if not execute(sql,args):
		return []
	return db.query_result

func close() -> void:
	if db != null:
		db.close_db()
		db = null
	path = ""

func open(file_path: String, allow_recovery: bool = true) -> bool:
	if path == file_path and db != null:
		return true
	close()
	error = ""
	recovered = false
	if not ClassDB.class_exists("SQLite"):
		error = "No se pudo cargar la extensión Godot-SQLite."
		return false
	if allow_recovery and not FileAccess.file_exists(file_path) and FileAccess.file_exists(file_path+".bak"):
		if not _recover(file_path):
			error = "Falta la base principal y su respaldo no se pudo verificar."
			return false
		var restored := open(file_path,false)
		recovered = restored
		return restored
	db = ClassDB.instantiate("SQLite")
	db.path = file_path
	db.default_extension = ""
	db.verbosity_level = 0
	var opened: bool = db.open_db()
	var integrity: Array = rows("PRAGMA quick_check") if opened else []
	if not opened or integrity.is_empty() or str(integrity[0].values()[0]) != "ok":
		close()
		if allow_recovery and _recover(file_path):
			var ok := open(file_path,false)
			recovered = ok
			return ok
		error = "No se pudo abrir o verificar la base SQLite; no se sobrescribieron tus datos."
		return false
	path = file_path
	var version: int = int(rows("PRAGMA user_version")[0].user_version)
	if version > SCHEMA_VERSION:
		error = "Esta base pertenece a una versión más reciente del juego."
		close()
		return false
	if not execute("PRAGMA foreign_keys = ON") or not execute("PRAGMA busy_timeout = 500") or not execute("PRAGMA synchronous = FULL"):
		close()
		return false
	if not execute("BEGIN IMMEDIATE"):
		close()
		return false
	var schema := [
		"CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)",
		"CREATE TABLE IF NOT EXISTS profiles (id TEXT PRIMARY KEY, uuid TEXT NOT NULL UNIQUE, display_name TEXT NOT NULL, record INTEGER NOT NULL, pending_upgrade INTEGER NOT NULL, tutorial_completed INTEGER NOT NULL, state BLOB NOT NULL, state_json TEXT NOT NULL, created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')), updated_at TEXT NOT NULL)",
		"CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value BLOB NOT NULL, value_json TEXT NOT NULL)",
		"CREATE TABLE IF NOT EXISTS level_progress (profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE, level_number INTEGER NOT NULL CHECK(level_number BETWEEN 1 AND 10), completed INTEGER NOT NULL, best_score INTEGER NOT NULL, PRIMARY KEY(profile_id,level_number))",
		"CREATE TABLE IF NOT EXISTS unlocks (profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE, category TEXT NOT NULL, item_id TEXT NOT NULL, PRIMARY KEY(profile_id,category,item_id))",
		"CREATE TABLE IF NOT EXISTS upgrades (profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE, stage INTEGER NOT NULL, upgrade_id TEXT NOT NULL, PRIMARY KEY(profile_id,stage))",
		"CREATE TABLE IF NOT EXISTS run_history (id TEXT PRIMARY KEY, profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE, level_number INTEGER NOT NULL CHECK(level_number BETWEEN 1 AND 10), difficulty INTEGER NOT NULL, outcome TEXT NOT NULL CHECK(outcome IN ('victory','defeat','abandoned')), duration_seconds REAL NOT NULL, score INTEGER NOT NULL, kills INTEGER NOT NULL, started_at TEXT NOT NULL, ended_at TEXT NOT NULL)",
		"CREATE INDEX IF NOT EXISTS history_by_player ON run_history(profile_id,ended_at DESC)",
		"CREATE VIEW IF NOT EXISTS leaderboard AS SELECT p.id,p.uuid,p.display_name,p.record,COUNT(CASE WHEN l.completed=1 THEN 1 END) AS levels_completed,COALESCE(SUM(l.best_score),0) AS current_score FROM profiles p LEFT JOIN level_progress l ON p.id=l.profile_id GROUP BY p.id",
		"CREATE TABLE IF NOT EXISTS run_sessions (id TEXT PRIMARY KEY, profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE, level_number INTEGER NOT NULL CHECK(level_number BETWEEN 1 AND 10), difficulty INTEGER NOT NULL, started_at TEXT NOT NULL, updated_at TEXT NOT NULL, outcome TEXT NOT NULL CHECK(outcome IN ('in_progress','victory','defeat','abandoned','interrupted')), duration_seconds REAL NOT NULL, kills INTEGER NOT NULL, owner_pid INTEGER NOT NULL)",
		"CREATE TABLE IF NOT EXISTS game_events (id TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES run_sessions(id) ON DELETE CASCADE, sequence INTEGER NOT NULL CHECK(sequence>0), event_type TEXT NOT NULL, occurred_at TEXT NOT NULL, mission_seconds REAL NOT NULL, active_seconds REAL NOT NULL, payload_json TEXT NOT NULL CHECK(json_valid(payload_json)), UNIQUE(session_id,sequence))",
		"CREATE INDEX IF NOT EXISTS sessions_by_player ON run_sessions(profile_id,started_at DESC)",
		"CREATE INDEX IF NOT EXISTS events_by_type ON game_events(event_type,occurred_at)",
		"CREATE TABLE IF NOT EXISTS profile_events (id TEXT PRIMARY KEY, profile_id TEXT REFERENCES profiles(id) ON DELETE CASCADE, event_type TEXT NOT NULL, occurred_at TEXT NOT NULL, payload_json TEXT NOT NULL CHECK(json_valid(payload_json)))",
		"CREATE INDEX IF NOT EXISTS profile_events_by_player ON profile_events(profile_id,occurred_at)",
		"CREATE VIEW IF NOT EXISTS event_log AS SELECT e.*,s.profile_id,s.level_number,s.difficulty FROM game_events e JOIN run_sessions s ON s.id=e.session_id",
		"CREATE TABLE IF NOT EXISTS history_archive (profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE, level_number INTEGER NOT NULL, outcome TEXT NOT NULL, attempts INTEGER NOT NULL, duration_seconds REAL NOT NULL, kills INTEGER NOT NULL, PRIMARY KEY(profile_id,level_number,outcome))",
		"CREATE TABLE IF NOT EXISTS replay_runs (session_id TEXT PRIMARY KEY REFERENCES run_sessions(id) ON DELETE CASCADE, metadata_json TEXT NOT NULL CHECK(json_valid(metadata_json)))",
		"CREATE TABLE IF NOT EXISTS replay_chunks (session_id TEXT NOT NULL REFERENCES replay_runs(session_id) ON DELETE CASCADE, chunk_index INTEGER NOT NULL, frames_json TEXT NOT NULL CHECK(json_valid(frames_json)), PRIMARY KEY(session_id,chunk_index))",
		"PRAGMA user_version = 4"
	]
	for sql in schema:
		if not execute(sql):
			_abort()
			close()
			return false
	if not _prune_history() or not execute("COMMIT"):
		_abort()
		close()
		return false
	return true

func _recover(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path+".bak"):
		return false
	var backup: Object = ClassDB.instantiate("SQLite")
	backup.path = file_path+".bak"
	backup.default_extension = ""
	backup.read_only = true
	backup.verbosity_level = 0
	var valid: bool = backup.open_db() and backup.query("PRAGMA quick_check")
	if valid:
		var result: Array = backup.query_result
		valid = not result.is_empty() and str(result[0].values()[0]) == "ok"
	backup.close_db()
	if not valid:
		return false
	var damaged := file_path+".corrupt-"+str(Time.get_unix_time_from_system()).replace(".","-")
	for suffix in ["","-wal","-shm","-journal"]:
		if FileAccess.file_exists(file_path+suffix) and DirAccess.rename_absolute(file_path+suffix,damaged+suffix) != OK:
			return false
	return DirAccess.copy_absolute(file_path+".bak",file_path) == OK

func initialized() -> bool:
	return not rows("SELECT value FROM metadata WHERE key='initialized' AND value='1'").is_empty()

func load_snapshot() -> Dictionary:
	error = ""
	var profiles := {}
	for row in rows("SELECT id,state FROM profiles ORDER BY created_at,id"):
		var value: Variant = bytes_to_var(row.state)
		if not value is Dictionary:
			error = "Un perfil guardado no se pudo leer."
			return {}
		profiles[str(row.id)] = value
	var settings := {}
	for row in rows("SELECT key,value FROM settings"):
		settings[str(row.key)] = bytes_to_var(row.value)
	var active: Array = rows("SELECT value FROM metadata WHERE key='active_profile'")
	if not error.is_empty():
		return {}
	return {"profiles":profiles,"settings":settings,"active_id":str(active[0].value) if not active.is_empty() else ""}

func save_snapshot(profiles: Dictionary, settings: Dictionary, active_id: String, history: Array = [], migration_source: String = "", telemetry: Dictionary = {}) -> bool:
	error = ""
	if not execute("BEGIN IMMEDIATE"):
		return false
	for row in rows("SELECT id FROM profiles"):
		if not profiles.has(str(row.id)) and not execute("DELETE FROM profiles WHERE id=?",[row.id]):
			return _abort()
	for id in profiles:
		var data: Dictionary = profiles[id]
		var state := var_to_bytes(data)
		var existing: Array = rows("SELECT state FROM profiles WHERE id=?",[id])
		if not existing.is_empty() and existing[0].state == state:
			continue
		if not execute("INSERT INTO profiles(id,uuid,display_name,record,pending_upgrade,tutorial_completed,state,state_json,updated_at) VALUES(?,?,?,?,?,?,?,?,strftime('%Y-%m-%dT%H:%M:%fZ','now')) ON CONFLICT(id) DO UPDATE SET display_name=excluded.display_name,record=excluded.record,pending_upgrade=excluded.pending_upgrade,tutorial_completed=excluded.tutorial_completed,state=excluded.state,state_json=excluded.state_json,updated_at=excluded.updated_at",[id,crypto.generate_random_bytes(16).hex_encode(),str(data.get("name",id)),int(data.get("record",0)),int(data.get("pending",-1)),int(bool(data.get("tutorial_completed",false))),state,JSON.stringify(data)]):
			return _abort()
		for table in ["level_progress","unlocks","upgrades"]:
			if not execute("DELETE FROM "+table+" WHERE profile_id=?",[id]):
				return _abort()
		for index in range(10):
			if not execute("INSERT INTO level_progress VALUES(?,?,?,?)",[id,index+1,int(data.get("completed",[]).has(index)),int(data.get("scores",{}).get(str(index),0))]):
				return _abort()
		for spec in [["weapon","weapon_unlocks"],["grenade","grenade_unlocks"],["enemy","discovered_enemies"]]:
			for item in data.get(spec[1],[]):
				if not execute("INSERT OR IGNORE INTO unlocks VALUES(?,?,?)",[id,spec[0],str(item)]):
					return _abort()
		for stage in data.get("choices",{}):
			if not execute("INSERT INTO upgrades VALUES(?,?,?)",[id,int(stage)+1,str(data.choices[stage])]):
				return _abort()
	for key in settings:
		var previous: Array = rows("SELECT value FROM settings WHERE key=?",[str(key)])
		if not previous.is_empty() and previous[0].value != var_to_bytes(settings[key]):
			if not execute("INSERT INTO profile_events VALUES(?,NULL,'settings_changed',strftime('%Y-%m-%dT%H:%M:%fZ','now'),?)",[crypto.generate_random_bytes(16).hex_encode(),JSON.stringify({"setting":key,"before":bytes_to_var(previous[0].value),"after":settings[key]})]):
				return _abort()
		if not execute("INSERT INTO settings VALUES(?,?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value,value_json=excluded.value_json",[str(key),var_to_bytes(settings[key]),JSON.stringify(settings[key])]):
			return _abort()
	for entry in history:
		if profiles.has(entry.profile_id) and not execute("INSERT OR IGNORE INTO run_history VALUES(?,?,?,?,?,?,?,?,?,?)",[entry.id,entry.profile_id,entry.level,entry.difficulty,entry.outcome,entry.duration,entry.score,entry.kills,entry.started_at,entry.ended_at]):
			return _abort()
	for key in ["initialized","active_profile","profile_version"]:
		var value: String = {"initialized":"1","active_profile":active_id,"profile_version":"5"}[key]
		if not execute("INSERT INTO metadata VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",[key,value]):
			return _abort()
	if not migration_source.is_empty() and not execute("INSERT INTO metadata VALUES('legacy_source',?) ON CONFLICT(key) DO NOTHING",[migration_source]):
		return _abort()
	if not _write_telemetry(telemetry) or not _prune_history():
		return _abort()
	if not error.is_empty():
		return _abort()
	if not execute("COMMIT"):
		return _abort()
	# Native SQLite backup includes committed pages even if a future reader uses WAL.
	var backup_path := ProjectSettings.globalize_path(path+".bak")
	if not bool(db.backup_to(backup_path)):
		# A stale backup must not resurrect an explicitly deleted profile.
		if FileAccess.file_exists(path+".bak"):
			DirAccess.remove_absolute(path+".bak")
	return true

func _write_telemetry(batch: Dictionary) -> bool:
	for session in batch.get("sessions",[]):
		# Profiles deleted by the snapshot cascade their events, including queued ones.
		if rows("SELECT id FROM profiles WHERE id=?",[session.profile_id]).is_empty():
			continue
		if not execute("INSERT INTO run_sessions VALUES(?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET updated_at=excluded.updated_at,outcome=excluded.outcome,duration_seconds=excluded.duration_seconds,kills=excluded.kills",[session.id,session.profile_id,session.level,session.difficulty,session.started_at,session.updated_at,session.outcome,session.duration,session.kills,session.owner_pid]):
			return false
	for event in batch.get("events",[]):
		if rows("SELECT id FROM run_sessions WHERE id=?",[event.session_id]).is_empty():
			continue
		if not execute("INSERT INTO game_events VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(id) DO NOTHING",[event.id,event.session_id,event.sequence,event.event_type,event.occurred_at,event.mission_seconds,event.active_seconds,JSON.stringify(event.payload)]):
			return false
	for replay in batch.get("replays",[]):
		if rows("SELECT id FROM run_sessions WHERE id=?",[replay.session_id]).is_empty():
			continue
		if not execute("INSERT INTO replay_runs VALUES(?,?) ON CONFLICT(session_id) DO UPDATE SET metadata_json=excluded.metadata_json",[replay.session_id,JSON.stringify(replay.metadata)]):
			return false
	for chunk in batch.get("replay_chunks",[]):
		if rows("SELECT session_id FROM replay_runs WHERE session_id=?",[chunk.session_id]).is_empty():
			continue
		if not execute("INSERT INTO replay_chunks VALUES(?,?,?) ON CONFLICT(session_id,chunk_index) DO NOTHING",[chunk.session_id,chunk.index,JSON.stringify(chunk.frames)]):
			return false
	for event in batch.get("profile_events",[]):
		if rows("SELECT id FROM profiles WHERE id=?",[event.profile_id]).is_empty():
			continue
		if not execute("INSERT INTO profile_events VALUES(?,?,?,?,?) ON CONFLICT(id) DO NOTHING",[event.id,event.profile_id,event.event_type,event.occurred_at,JSON.stringify(event.payload)]):
			return false
	return error.is_empty()

func save_telemetry(batch: Dictionary) -> bool:
	# Periodic batches avoid rewriting profiles or copying the entire database per shot.
	error = ""
	if not execute("BEGIN IMMEDIATE"):
		return false
	if not _write_telemetry(batch) or not _prune_history() or not execute("COMMIT"):
		return _abort()
	return true

func _prune_history() -> bool:
	# Freeze the removal set: history and session rows represent the same attempt.
	var statements := [
		"CREATE TEMP TABLE IF NOT EXISTS retention_old_runs (id TEXT PRIMARY KEY, profile_id TEXT, level_number INTEGER, outcome TEXT, duration_seconds REAL, kills INTEGER)",
		"DELETE FROM retention_old_runs",
		"WITH attempts AS (SELECT h.id,h.profile_id,h.level_number,h.outcome,h.duration_seconds,h.kills,h.ended_at AS stamp,0 AS active,h.rowid AS ordinal FROM run_history h UNION ALL SELECT s.id,s.profile_id,s.level_number,s.outcome,s.duration_seconds,s.kills,s.updated_at AS stamp,CASE WHEN s.outcome='in_progress' THEN 1 ELSE 0 END AS active,s.rowid AS ordinal FROM run_sessions s WHERE NOT EXISTS(SELECT 1 FROM run_history h WHERE h.id=s.id)), ranked AS (SELECT *,ROW_NUMBER() OVER(PARTITION BY profile_id ORDER BY active DESC,julianday(stamp) DESC,ordinal DESC,id DESC) AS position FROM attempts) INSERT INTO retention_old_runs SELECT id,profile_id,level_number,outcome,duration_seconds,kills FROM ranked WHERE position>"+str(MAX_RUNS),
		"INSERT INTO history_archive SELECT profile_id,level_number,outcome,COUNT(*),SUM(duration_seconds),SUM(kills) FROM retention_old_runs GROUP BY profile_id,level_number,outcome HAVING COUNT(*)>0 ON CONFLICT(profile_id,level_number,outcome) DO UPDATE SET attempts=attempts+excluded.attempts,duration_seconds=duration_seconds+excluded.duration_seconds,kills=kills+excluded.kills",
		"DELETE FROM run_sessions WHERE id IN(SELECT id FROM retention_old_runs)",
		"DELETE FROM run_history WHERE id IN(SELECT id FROM retention_old_runs)"
	]
	for statement in statements:
		if not execute(statement):
			return false
	# Game actions and menu actions share one allowance per player. NULL is the
	# separate bucket for global settings. Old sessions cascade their own events.
	var ranking := "WITH combined AS (SELECT 'game' AS source,e.rowid AS rid,s.profile_id,e.occurred_at FROM game_events e JOIN run_sessions s ON s.id=e.session_id UNION ALL SELECT 'profile',e.rowid,e.profile_id,e.occurred_at FROM profile_events e), ranked AS (SELECT *,ROW_NUMBER() OVER(PARTITION BY profile_id ORDER BY julianday(occurred_at) DESC,rid DESC,source DESC) AS position FROM combined) "
	for pair in [["game_events","game"],["profile_events","profile"]]:
		if not execute(ranking+"DELETE FROM "+pair[0]+" WHERE rowid IN(SELECT rid FROM ranked WHERE source='"+pair[1]+"' AND position>"+str(MAX_EVENTS)+")"):
			return false
	return error.is_empty()

func _abort() -> bool:
	var reason := error
	db.query("ROLLBACK")
	error = reason
	return false
