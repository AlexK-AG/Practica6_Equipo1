import { DatabaseSync } from 'node:sqlite';
import { existsSync } from 'node:fs';

export const MAX_SYNC_BODY = 12 * 1024 * 1024;

export function validateMobileSnapshot(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value) || value.version !== 1) throw new Error('Versión de sincronización no compatible.');
  const id = /^[a-f0-9]{32}$/i;
  if (!id.test(value.deviceId || '') || !value.profile || !id.test(value.profile.uuid || '')) throw new Error('Identificador del dispositivo o perfil inválido.');
  const p = value.profile;
  if (typeof p.name !== 'string' || !p.name.trim() || p.name.length > 64 || !Number.isSafeInteger(p.record) || p.record < 0) throw new Error('Datos de perfil inválidos.');
  if (!Array.isArray(p.completed) || p.completed.length > 10 || !p.completed.every(n => Number.isInteger(n) && n >= 0 && n < 10)) throw new Error('Progreso de perfil inválido.');
  for (const field of ['scores','choices']) if (!p[field] || typeof p[field] !== 'object' || Array.isArray(p[field])) throw new Error(`Datos de perfil inválidos: ${field}.`);
  for (const field of ['weaponUnlocks','grenadeUnlocks','discoveredEnemies','loadout']) if (!Array.isArray(p[field])) throw new Error(`Datos de perfil inválidos: ${field}.`);
  if (!Array.isArray(value.runs) || value.runs.length > 400 || !Array.isArray(value.events) || value.events.length > 4800 || !Array.isArray(value.historyArchive) || value.historyArchive.length > 30 || !Array.isArray(value.replays) || value.replays.length > 400) throw new Error('El volumen de datos sincronizados excede el límite.');
  const runIds = new Set();
  for (const run of value.runs) {
    if (!run || typeof run.id !== 'string' || !/^[a-f0-9:_-]{1,160}$/i.test(run.id) || runIds.has(run.id) || !Number.isInteger(run.level) || run.level < 1 || run.level > 10 || !Number.isInteger(run.difficulty) || run.difficulty < 0 || run.difficulty > 2 || !['in_progress','victory','defeat','abandoned','interrupted'].includes(run.outcome) || !Number.isFinite(run.durationSeconds) || run.durationSeconds < 0 || !Number.isSafeInteger(run.kills) || run.kills < 0) throw new Error('Hay una partida con datos inválidos.');
    runIds.add(run.id);
  }
  for (const event of value.events) {
    if (!event || typeof event.id !== 'string' || !/^[a-f0-9:_-]{1,180}$/i.test(event.id) || typeof event.type !== 'string' || event.type.length > 80 || typeof event.occurredAt !== 'string' || !event.payload || typeof event.payload !== 'object' || Array.isArray(event.payload)) throw new Error('Hay un evento con datos inválidos.');
    if (event.runId && !runIds.has(event.runId)) throw new Error('Hay un evento ligado a una partida desconocida.');
  }
  const json = JSON.stringify(value);
  if (Buffer.byteLength(json, 'utf8') > MAX_SYNC_BODY) throw new Error('La copia de datos supera el tamaño permitido.');
  return json;
}

export function writeMobileSnapshot(databasePath, snapshot) {
  const json = validateMobileSnapshot(snapshot);
  const db = new DatabaseSync(databasePath, { timeout: 1500 });
  try {
    db.exec(`PRAGMA busy_timeout=1500;
      CREATE TABLE IF NOT EXISTS mobile_snapshots (
        device_id TEXT NOT NULL,
        profile_uuid TEXT NOT NULL,
        payload_json TEXT NOT NULL CHECK(json_valid(payload_json)),
        synced_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
        PRIMARY KEY(device_id,profile_uuid)
      );
      BEGIN IMMEDIATE;`);
    db.prepare(`INSERT INTO mobile_snapshots(device_id,profile_uuid,payload_json,synced_at)
      VALUES(?,?,?,strftime('%Y-%m-%dT%H:%M:%fZ','now'))
      ON CONFLICT(device_id,profile_uuid) DO UPDATE SET payload_json=excluded.payload_json,synced_at=excluded.synced_at`)
      .run(snapshot.deviceId, snapshot.profile.uuid, json);
    db.exec('COMMIT');
    return { profileId: snapshot.profile.uuid, runCount: snapshot.runs.length, eventCount: snapshot.events.length };
  } catch (error) {
    try { db.exec('ROLLBACK'); } catch { /* Transaction already ended. */ }
    throw error;
  } finally { db.close(); }
}

export function readMobileSnapshots(databasePath) {
  if (!existsSync(databasePath)) return [];
  let db;
  try {
    db = new DatabaseSync(databasePath, { readOnly: true, timeout: 250 });
    const exists = db.prepare("SELECT 1 AS found FROM sqlite_master WHERE type='table' AND name='mobile_snapshots'").get();
    if (!exists) return [];
    return db.prepare('SELECT payload_json FROM mobile_snapshots ORDER BY synced_at,device_id,profile_uuid').all().map(row => {
      const value = JSON.parse(row.payload_json);
      validateMobileSnapshot(value);
      return value;
    });
  } catch (error) {
    throw Object.assign(new Error('No se pudo leer el archivo de sincronización móvil.'), {code:'MOBILE_SYNC_INVALID', cause:error});
  } finally { db?.close(); }
}

export function readMobileReplay(databasePath, externalRunId) {
  const match = /^mobile:([a-f0-9]{32}):([a-f0-9]{32}):([a-f0-9:_-]{1,160})$/i.exec(String(externalRunId || ''));
  if (!match) return null;
  const [, deviceId, profileUuid, sourceRunId] = match;
  const snapshot = readMobileSnapshots(databasePath).find(item => item.deviceId.toLowerCase() === deviceId.toLowerCase() && item.profile.uuid.toLowerCase() === profileUuid.toLowerCase());
  if (!snapshot) return null;
  const replay = snapshot.replays.find(item => item.runId === sourceRunId);
  if (!replay) return {available:false, reason:'Esta partida móvil no tiene un recorrido registrado.'};
  const byTime = new Map();
  for (const chunk of replay.chunks) for (const frame of chunk.frames) {
    if (!Number.isFinite(frame.t) || frame.t < 0 || !Array.isArray(frame.p) || frame.p.length !== 2 || !frame.p.every(Number.isFinite) || !Array.isArray(frame.enemies)) throw Object.assign(new Error('El recorrido móvil tiene datos inválidos.'), {code:'REPLAY_UNAVAILABLE'});
    byTime.set(frame.t, frame);
  }
  const frames = [...byTime.values()].sort((a,b) => a.t - b.t);
  return {available:frames.length > 0, sessionId:externalRunId, metadata:replay.metadata, frames, reason:frames.length ? '' : 'Todavía no hay muestras de recorrido para esta partida.'};
}
