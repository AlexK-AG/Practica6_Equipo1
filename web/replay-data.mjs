import { DatabaseSync } from 'node:sqlite';
import { statSync } from 'node:fs';

export function readReplay(databasePath, sessionId) {
  if (typeof sessionId !== 'string' || !sessionId || sessionId.length > 160) {
    throw Object.assign(new Error('Selecciona una partida válida.'), {code:'INVALID_RUN'});
  }
  let db;
  try {
    if (!statSync(databasePath).isFile()) throw new Error('missing');
    db = new DatabaseSync(databasePath, {readOnly:true,timeout:250});
    db.exec('PRAGMA query_only=ON; PRAGMA trusted_schema=OFF; BEGIN');
    const version = db.prepare('PRAGMA user_version').get().user_version;
    if (version > 4 || version < 1) throw Object.assign(new Error('Actualiza el juego y el servidor a la misma versión.'), {code:'DB_VERSION_UNSUPPORTED'});
    if (version < 4) return {available:false,reason:'Esta partida es anterior al registro de recorridos.'};
    const row = db.prepare('SELECT metadata_json FROM replay_runs WHERE session_id=?').get(sessionId);
    if (!row) return {available:false,reason:'Esta partida no tiene un recorrido registrado. Las partidas anteriores conservan sus resultados y eventos.'};
    const metadata = JSON.parse(row.metadata_json);
    const chunks = db.prepare('SELECT frames_json FROM replay_chunks WHERE session_id=? ORDER BY chunk_index').all(sessionId);
    const byTime = new Map();
    for (const chunk of chunks) for (const frame of JSON.parse(chunk.frames_json)) {
      if (!Number.isFinite(frame.t) || frame.t < 0 || !Array.isArray(frame.p) || frame.p.length !== 2 || !frame.p.every(Number.isFinite) || !Array.isArray(frame.enemies)) throw new Error('invalid replay');
      byTime.set(frame.t,frame);
    }
    const frames = [...byTime.values()].sort((a,b)=>a.t-b.t);
    db.exec('COMMIT');
    return {available:frames.length>0,sessionId,metadata,frames,reason:frames.length?'':'Todavía no hay muestras guardadas. Actualiza después de jugar unos segundos.'};
  } catch (error) {
    if (error.code && ['INVALID_RUN','DB_VERSION_UNSUPPORTED'].includes(error.code)) throw error;
    throw Object.assign(new Error(/locked|busy/i.test(error.message)?'El juego está guardando. Inténtalo de nuevo.':'No se pudo leer el recorrido guardado.'), {code:'REPLAY_UNAVAILABLE'});
  } finally { db?.close(); }
}
