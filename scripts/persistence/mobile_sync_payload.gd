extends RefCounted
## Creates a JSON snapshot from the active mobile profile without modifying SQLite.

static func build(store: RefCounted, profile_id: String, device_id: String) -> Dictionary:
	if store == null or store.db == null or profile_id.is_empty() or device_id.is_empty():
		return {}
	var profile_rows: Array = store.rows("SELECT uuid,display_name,record,tutorial_completed,state_json FROM profiles WHERE id=?", [profile_id])
	if profile_rows.is_empty():
		return {}
	var profile_row: Dictionary = profile_rows[0]
	var state: Variant = JSON.parse_string(str(profile_row.get("state_json", "{}")))
	if not state is Dictionary:
		return {}
	var profile := {
		"uuid": str(profile_row.uuid),
		"name": str(profile_row.display_name),
		"record": int(profile_row.record),
		"tutorialCompleted": bool(profile_row.tutorial_completed),
		"completed": state.get("completed", []),
		"scores": state.get("scores", {}),
		"weaponUnlocks": state.get("weapon_unlocks", []),
		"grenadeUnlocks": state.get("grenade_unlocks", []),
		"discoveredEnemies": state.get("discovered_enemies", []),
		"choices": state.get("choices", {}),
		"loadout": state.get("loadout", ["pistol", "rifle"])
	}
	var runs: Array[Dictionary] = []
	var seen_runs := {}
	for row: Dictionary in store.rows("SELECT id,level_number,difficulty,outcome,duration_seconds,score,kills,started_at,ended_at FROM run_history WHERE profile_id=? ORDER BY ended_at", [profile_id]):
		runs.append(_run_from_row(row, true))
		seen_runs[str(row.id)] = true
	for row: Dictionary in store.rows("SELECT id,level_number,difficulty,outcome,duration_seconds,kills,started_at,updated_at FROM run_sessions WHERE profile_id=? ORDER BY started_at", [profile_id]):
		if seen_runs.has(str(row.id)):
			continue
		runs.append({"id": str(row.id), "level": int(row.level_number), "difficulty": int(row.difficulty), "outcome": str(row.outcome), "durationSeconds": float(row.duration_seconds), "score": null, "kills": int(row.kills), "startedAt": str(row.started_at), "endedAt": str(row.updated_at) if str(row.outcome) != "in_progress" else "", "updatedAt": str(row.updated_at)})
	var events: Array[Dictionary] = []
	for row: Dictionary in store.rows("SELECT e.id,e.session_id,e.sequence,e.event_type,e.occurred_at,e.mission_seconds,e.active_seconds,e.payload_json,s.level_number FROM game_events e JOIN run_sessions s ON s.id=e.session_id WHERE s.profile_id=? ORDER BY e.occurred_at,e.sequence", [profile_id]):
		var payload: Variant = JSON.parse_string(str(row.payload_json))
		events.append({"id": str(row.id), "runId": str(row.session_id), "level": int(row.level_number), "type": str(row.event_type), "occurredAt": str(row.occurred_at), "sequence": int(row.sequence), "missionSeconds": float(row.mission_seconds), "activeSeconds": float(row.active_seconds), "payload": payload if payload is Dictionary else {}})
	for row: Dictionary in store.rows("SELECT id,event_type,occurred_at,payload_json FROM profile_events WHERE profile_id=? ORDER BY occurred_at,id", [profile_id]):
		var payload: Variant = JSON.parse_string(str(row.payload_json))
		events.append({"id": str(row.id), "runId": "", "level": 0, "type": str(row.event_type), "occurredAt": str(row.occurred_at), "sequence": 0, "missionSeconds": 0.0, "activeSeconds": 0.0, "payload": payload if payload is Dictionary else {}, "scope": "profile"})
	var archive: Array[Dictionary] = []
	for row: Dictionary in store.rows("SELECT level_number,outcome,attempts,duration_seconds,kills FROM history_archive WHERE profile_id=?", [profile_id]):
		archive.append({"level": int(row.level_number), "outcome": str(row.outcome), "attempts": int(row.attempts), "durationSeconds": float(row.duration_seconds), "kills": int(row.kills)})
	# Replay traces can be much larger than the profile/event snapshot; keep them local.
	return {"version": 1, "deviceId": device_id, "profile": profile, "runs": runs, "events": events, "historyArchive": archive, "replays": []}

static func _run_from_row(row: Dictionary, has_score: bool) -> Dictionary:
	var score: Variant = null
	if has_score:
		score = int(row.score)
	return {"id": str(row.id), "level": int(row.level_number), "difficulty": int(row.difficulty), "outcome": str(row.outcome), "durationSeconds": float(row.duration_seconds), "score": score, "kills": int(row.kills), "startedAt": str(row.started_at), "endedAt": str(row.ended_at), "updatedAt": str(row.ended_at)}
