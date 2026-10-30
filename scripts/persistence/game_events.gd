extends RefCounted
## Campaign owns the queue so scene changes and pauses do not discard pending writes.
const FLUSH_SECONDS := 2.0
var sessions: Dictionary = {}
var pending: Array[Dictionary] = []
var profile_pending: Array[Dictionary] = []
var dirty: Dictionary = {}
var database := ""
var recovered_database := ""
var timer := 0.0
var replay_headers: Dictionary = {}
var replay_chunks: Array[Dictionary] = []

func bind_database(path: String) -> void:
	if database == path:
		return
	database = path
	recovered_database = ""
	sessions.clear()
	pending.clear()
	profile_pending.clear()
	replay_headers.clear()
	replay_chunks.clear()
	dirty.clear()
	timer = 0

func batch() -> Dictionary:
	var updates: Array = []
	for id in dirty:
		updates.append(sessions[id].duplicate(true))
	return {"sessions":updates,"events":pending.duplicate(true),"profile_events":profile_pending.duplicate(true),"replays":replay_headers.values().duplicate(true),"replay_chunks":replay_chunks.duplicate(true)}

func committed() -> void:
	pending.clear()
	profile_pending.clear()
	replay_headers.clear()
	replay_chunks.clear()
	dirty.clear()
	timer = 0

func profile_action(profile_id: String, type: String, payload: Dictionary = {}) -> String:
	var id := Crypto.new().generate_random_bytes(16).hex_encode()
	profile_pending.append({"id":id,"profile_id":profile_id,"event_type":type,"occurred_at":Time.get_datetime_string_from_system(true)+"Z","payload":payload.duplicate(true)})
	return id

func cancel_profile_action(id: String) -> void:
	profile_pending = profile_pending.filter(func(event):return event.id != id)

func begin(id: String, profile_id: String, level: int, difficulty: int, started: String, elapsed: float, resumed: bool) -> void:
	for old_id in sessions.keys():
		if sessions[old_id].outcome != "in_progress" and not dirty.has(old_id):
			sessions.erase(old_id)
	sessions[id] = {"id":id,"profile_id":profile_id,"level":level,"difficulty":difficulty,"started_at":started,"updated_at":started,"outcome":"in_progress","duration":0.0,"kills":0,"owner_pid":OS.get_process_id(),"sequence":0,"elapsed_start":elapsed}
	append(id,"run_started",elapsed,{"checkpoint_resumed":resumed,"elapsed_start":elapsed})

func heartbeat(id: String, elapsed: float, kills: int) -> void:
	if not sessions.has(id) or sessions[id].outcome != "in_progress":
		return
	var session: Dictionary = sessions[id]
	session.duration = maxf(0,elapsed-float(session.elapsed_start))
	session.kills = kills
	session.updated_at = Time.get_datetime_string_from_system(true)+"Z"
	dirty[id] = true

func append(id: String, type: String, elapsed: float, payload: Dictionary = {}) -> void:
	if not sessions.has(id):
		return
	var session: Dictionary = sessions[id]
	if session.outcome != "in_progress" and type != "upgrade_chosen":
		return
	session.sequence += 1
	session.updated_at = Time.get_datetime_string_from_system(true)+"Z"
	var active := maxf(0,elapsed-float(session.elapsed_start))
	pending.append({"id":id+":"+str(session.sequence),"session_id":id,"sequence":session.sequence,"event_type":type,"occurred_at":session.updated_at,"mission_seconds":maxf(0,elapsed),"active_seconds":active,"payload":payload.duplicate(true)})
	dirty[id] = true

func finish(entry: Dictionary) -> void:
	if not sessions.has(entry.id) or sessions[entry.id].outcome != "in_progress":
		return
	var session: Dictionary = sessions[entry.id]
	var elapsed := float(session.elapsed_start)+float(entry.duration)
	heartbeat(entry.id,elapsed,int(entry.kills))
	append(entry.id,"run_ended",elapsed,{"outcome":entry.outcome,"score":entry.score,"kills":entry.kills,"duration_seconds":entry.duration})
	session.outcome = entry.outcome

func recover_interrupted(store: RefCounted) -> bool:
	if recovered_database == database:
		return true
	store.error = ""
	var stale: Array = store.rows("SELECT s.*,COALESCE(MAX(e.sequence),0) AS last_sequence,COALESCE((SELECT mission_seconds-active_seconds FROM game_events WHERE session_id=s.id ORDER BY sequence DESC LIMIT 1),0) AS elapsed_start FROM run_sessions s LEFT JOIN game_events e ON e.session_id=s.id WHERE s.outcome='in_progress' GROUP BY s.id")
	if not store.error.is_empty():
		return false
	for row in stale:
		if OS.is_process_running(int(row.owner_pid)):
			continue
		var now := Time.get_datetime_string_from_system(true)+"Z"
		var seq := int(row.last_sequence)+1
		# No invented finish time or victory: retain the last confirmed active duration.
		sessions[row.id] = {"id":row.id,"profile_id":row.profile_id,"level":row.level_number,"difficulty":row.difficulty,"started_at":row.started_at,"updated_at":now,"outcome":"interrupted","duration":row.duration_seconds,"kills":row.kills,"owner_pid":row.owner_pid,"sequence":seq,"elapsed_start":0.0}
		dirty[row.id] = true
		pending.append({"id":str(row.id)+":"+str(seq),"session_id":row.id,"sequence":seq,"event_type":"session_interrupted","occurred_at":now,"mission_seconds":float(row.duration_seconds)+float(row.elapsed_start),"active_seconds":float(row.duration_seconds),"payload":{"last_confirmed_at":row.updated_at,"reason":"process_ended_without_finalization"}})
	recovered_database = database
	return true

func replay_header(id: String, metadata: Dictionary) -> void:
	if sessions.has(id):
		replay_headers[id] = {"session_id":id,"metadata":metadata.duplicate(true)}
		dirty[id] = true

func replay_chunk(id: String, index: int, frames: Array) -> void:
	if sessions.has(id) and not frames.is_empty():
		replay_chunks.append({"session_id":id,"index":index,"frames":frames.duplicate(true)})
		dirty[id] = true
