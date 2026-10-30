import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync, mkdirSync, unlinkSync, existsSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createServer, readDashboard, parseOptions, defaultDatabase } from '../../web/server.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const fixtureRoot = path.join(root, '.godot', 'web-server-tests');
mkdirSync(fixtureRoot, { recursive: true });
const filename = path.join(fixtureRoot, `fixture-${process.pid}.sqlite`);
const hash = () => createHash('sha256').update(readFileSync(filename)).digest('hex');

export function createFixture(target) {
  const source = readFileSync(path.join(root, 'scripts', 'persistence', 'campaign_store.gd'), 'utf8');
  const schema = source.split('var schema := [')[1].split('\n\t]')[0];
  const db = new DatabaseSync(target);
  for (const line of schema.trim().split('\n')) db.exec(JSON.parse(line.trim().replace(/,$/, '')));
  const profile = db.prepare("INSERT INTO profiles VALUES(?,?,?,?,?,?,?,?,'2026-10-16T00:00:00Z','2026-10-16T00:00:00Z')");
  profile.run('alpha', 'uuid-alpha', 'Piloto real', 1200, -1, 1, Buffer.alloc(0), JSON.stringify({ loadout: ['shotgun', 'rifle'] }));
  profile.run('beta', 'uuid-beta', 'Segundo piloto', 2500, -1, 0, Buffer.alloc(0), '{}');
  db.exec("INSERT INTO level_progress VALUES('alpha',1,1,1200),('alpha',2,0,0),('beta',1,1,1800)");
  db.exec("INSERT INTO unlocks VALUES('alpha','weapon','rifle'),('alpha','weapon','shotgun'),('alpha','grenade','fragmentation'),('alpha','enemy','12')");
  db.exec("INSERT INTO upgrades VALUES('alpha',1,'health')");
  db.exec("INSERT INTO run_history VALUES('won','alpha',1,2,'victory',10.5,1200,3,'2026-10-16T00:00:00Z','2026-10-16T00:00:11Z')");
  const session = db.prepare('INSERT INTO run_sessions VALUES(?,?,?,?,?,?,?,?,?,?)');
  session.run('won', 'alpha', 1, 2, '2026-10-16T00:00:00Z', '2026-10-16T00:00:11Z', 'victory', 10.5, 3, 2147483647);
  session.run('playing', 'alpha', 2, 1, '2026-10-16T00:01:00Z', '2026-10-16T00:01:12Z', 'in_progress', 12, 1, process.pid);
  session.run('interrupted', 'beta', 1, 0, '2026-10-16T00:02:00Z', '2026-10-16T00:02:12Z', 'interrupted', 8, 2, 2147483647);
  const event = db.prepare('INSERT INTO game_events VALUES(?,?,?,?,?,?,?,?)');
  event.run('first', 'playing', 1, 'run_started', '2026-10-16T00:01:00Z', 30, 0, JSON.stringify({ checkpoint_resumed: true }));
  event.run('second', 'playing', 2, 'shot_fired', '2026-10-16T00:01:01Z', 31, 1, JSON.stringify({ weapon: 'rifle', ammo: 23 }));
  event.run('third', 'won', 1, 'run_ended', '2026-10-16T00:00:11Z', 10.5, 10.5, JSON.stringify({ score: 1200 }));
  db.exec("INSERT INTO profile_events VALUES('upgrade','alpha','upgrade_chosen','2026-10-16T00:00:12Z','{\"stage\":1,\"upgrade\":\"health\"}'),('settings',NULL,'settings_changed','2026-10-16T00:01:05Z','{\"setting\":\"options\",\"after\":{\"brightness\":0.9}}')");
  return db;
}

export async function run() {
  let writer, server;
  const mobileDatabase = filename + '.mobile-sync.sqlite';
  const syncToken = 'test-token-with-at-least-16-chars';
  try {
    writer = createFixture(filename);
    const before = hash(), data = readDashboard(filename);
    assert.equal(data.schemaVersion, 2);
    assert.equal(data.players.length, 2);
    assert.deepEqual(data.players[0].completedLevels, [1], 'SQL levels remain 1-based');
    assert.deepEqual(data.players[0].loadout, ['shotgun', 'rifle']);
    assert.deepEqual(data.players[1].loadout, ['pistol'], 'Missing saved selection follows game equipment availability');
    assert.deepEqual(data.players[0].discoveredEnemies, [12]);
    assert.equal(data.players[0].scores[1], 1200);
    assert.equal(data.runs.length, 3, 'History/session union does not double count a victory');
    assert.equal(data.runs.find(r => r.id === 'playing').score, null);
    assert.equal(data.runs.find(r => r.id === 'interrupted').endedAt, null, 'No invented finish time');
    assert.equal(data.events.length, 5);
    assert.equal(data.events.find(e => e.scope === 'system').playerId, null);
    assert.equal(data.events.find(e => e.type === 'shot_fired').sequence, 2);
    assert.equal(hash(), before, 'Reading never changes the game database');
    writer.exec('BEGIN EXCLUSIVE');
    assert.throws(() => readDashboard(filename), error => error.code === 'DB_BUSY');
    writer.exec('ROLLBACK');
    server = createServer({ databasePath: filename, mobileDatabasePath: mobileDatabase, lanEnabled: true, syncToken });
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    const base = `http://127.0.0.1:${server.address().port}`;
    const mobileSnapshot = {
      version: 1, deviceId: 'a'.repeat(32),
      profile: { uuid: 'b'.repeat(32), name: 'Piloto móvil', record: 900, tutorialCompleted: true, completed: [0], scores: { 0: 900 }, weaponUnlocks: ['rifle'], grenadeUnlocks: [], discoveredEnemies: [], choices: {}, loadout: ['pistol', 'rifle'] },
      runs: [{ id: 'c'.repeat(32), level: 1, difficulty: 1, outcome: 'victory', durationSeconds: 35, score: 900, kills: 4, startedAt: '2026-10-29T10:00:00Z', endedAt: '2026-10-29T10:00:35Z', updatedAt: '2026-10-29T10:00:35Z' }],
      events: [{ id: `${'c'.repeat(32)}:1`, runId: 'c'.repeat(32), level: 1, type: 'run_ended', occurredAt: '2026-10-29T10:00:35Z', sequence: 1, missionSeconds: 35, activeSeconds: 35, payload: { score: 900 } }],
      historyArchive: [], replays: [],
    };
    assert.equal((await fetch(`${base}/api/mobile-sync`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer wrong-token-with-16-chars' }, body: JSON.stringify(mobileSnapshot) })).status, 401, 'Mobile sync requires the configured token');
    const syncResponse = await fetch(`${base}/api/mobile-sync`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${syncToken}` }, body: JSON.stringify(mobileSnapshot) });
    assert.equal(syncResponse.status, 200);
    assert.equal((await syncResponse.json()).ok, true);
    const dashboardWithMobile = readDashboard(filename, mobileDatabase);
    assert.equal(dashboardWithMobile.players.length, 3, 'Mobile profiles appear alongside PC profiles');
    assert.equal(dashboardWithMobile.players.find(player => player.name === 'Piloto móvil').record, 900);
    assert.equal(dashboardWithMobile.runs.find(run => run.playerId.startsWith('mobile:')).score, 900);
    assert.ok(dashboardWithMobile.events.some(event => event.type === 'run_ended' && event.playerId.startsWith('mobile:')));
    assert.equal(hash(), before, 'Mobile sync never writes the PC database');
    assert.equal((await fetch(base)).status, 200);
    assert.equal((await fetch(`${base}/assets/mark.svg`)).status, 200);
    assert.equal((await fetch(`${base}/app.js`, { method: 'HEAD' })).headers.get('content-type'), 'text/javascript; charset=utf-8');
    for (const route of ['/server.mjs', '/package.json', '/README.md', '/sector07.sqlite', '/assets/%2e%2e/server.mjs', '/api/../server.mjs']) {
      assert.equal((await fetch(base + route)).status, 404, `Private files are not served: ${route}`);
    }
    assert.equal((await fetch(`${base}/api/dashboard`, { method: 'POST' })).status, 405);
    assert.equal((await fetch(`${base}/api/dashboard`, { headers: { Origin: 'http://another-site.test' } })).status, 403);
    const response = await fetch(`${base}/api/dashboard`);
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.equal((await response.json()).players[0].record, 1200);
    writer.exec("UPDATE profiles SET record=1400 WHERE id='alpha'");
    assert.equal((await (await fetch(`${base}/api/dashboard`)).json()).players[0].record, 1400, 'Refresh reads new committed game data');
    writer.exec("DELETE FROM profiles WHERE id='beta'");
    const afterDelete = await (await fetch(`${base}/api/dashboard`)).json();
    assert.equal(afterDelete.players.length, 2, 'Deletion is reflected without server restart while mobile profiles remain');
    assert.ok(afterDelete.players.some(player => player.name === 'Piloto móvil'));
    writer.exec("INSERT INTO history_archive VALUES('alpha',1,'victory',12,120,24)");
    assert.equal(readDashboard(filename).historyArchive[0].durationSeconds,120,'Lifetime aggregates are delivered separately from retained details');
    writer.exec('BEGIN');
    const extraRun=writer.prepare('INSERT INTO run_history VALUES(?,?,?,?,?,?,?,?,?,?)');
    for(let i=0;i<405;i++) extraRun.run(`ret-run-${i}`,'alpha',1,1,'victory',1,1,1,new Date(1900000000000+i*1000).toISOString(),new Date(1900000000000+i*1000).toISOString());
    const extraEvent=writer.prepare('INSERT INTO profile_events VALUES(?,?,?,?,?)');
    for(let i=0;i<2405;i++) {
      extraEvent.run(`ret-event-${i}`,'alpha','profile_selected',new Date(1900000000000+i*1000).toISOString(),'{}');
      extraEvent.run(`ret-system-${i}`,null,'settings_changed',new Date(1900000000000+i*1000).toISOString(),'{}');
    }
    writer.exec('COMMIT');
    const limited=readDashboard(filename);
    assert.equal(limited.runs.filter(r=>r.playerId==='uuid-alpha').length,400);
    assert.equal(limited.events.filter(e=>e.playerId==='uuid-alpha').length,2400);
    assert.equal(limited.events.filter(e=>e.playerId===null).length,2400);
    assert.equal(limited.historyArchive.reduce((sum,row)=>sum+row.attempts,0),19,'Existing aggregates and old-schema preview overflow are counted once');
    assert.ok(limited.runs.some(r=>r.id==='playing'),'Current session is protected');
    assert.equal(writer.prepare('SELECT COUNT(*) n FROM run_history').get().n,406,'Preview limit does not make the web a database writer');
    writer.exec("DELETE FROM run_history WHERE id LIKE 'ret-run-%'; DELETE FROM profile_events WHERE id LIKE 'ret-%'; DELETE FROM history_archive");
    writer.exec('PRAGMA user_version=999');
    const future = await fetch(`${base}/api/dashboard`);
    assert.equal(future.status, 503);
    assert.equal((await future.json()).error.code, 'DB_VERSION_UNSUPPORTED');
    assert.equal(writer.prepare('PRAGMA user_version').get().user_version, 999);
    writer.exec('PRAGMA user_version=2');
    writer.exec("UPDATE profiles SET state_json='invalid' WHERE id='alpha'");
    assert.throws(() => readDashboard(filename), error => error.code === 'DB_INVALID');
    writer.exec("UPDATE profiles SET state_json='{}' WHERE id='alpha'");
    writer.exec('DROP VIEW event_log; DROP TABLE game_events; DROP TABLE run_sessions; DROP TABLE profile_events; PRAGMA user_version=1');
    const legacy = readDashboard(filename);
    assert.equal(legacy.capabilities.events, true, 'Mobile events remain available when the PC database is legacy');
    assert.equal(legacy.runs.length, 2, 'The legacy PC run and mobile run remain visible');
    assert.equal(writer.prepare('PRAGMA user_version').get().user_version, 1, 'Web never migrates saves');
    const missing = filename + '.missing';
    assert.throws(() => readDashboard(missing), error => error.code === 'DB_NOT_FOUND');
    assert.equal(existsSync(missing), false, 'Reading a missing database never creates one');
    const corrupt = filename + '.corrupt';
    writeFileSync(corrupt, 'not a SQLite database');
    try { assert.throws(() => readDashboard(corrupt), error => error.code === 'DB_INVALID'); }
    finally { unlinkSync(corrupt); }
    assert.equal(parseOptions(['--port', '3001', '--db', filename], {}).port, 3001);
    assert.throws(() => parseOptions(['--port', '0'], {}));
    assert.throws(() => parseOptions(['--host', '0.0.0.0'], {}));
    assert.ok(defaultDatabase({ APPDATA: 'C:/Fixture' }, 'win32').endsWith(path.join('Sector 07 - Contencion', 'sector07.sqlite')));
    console.log('WEB SERVER PASS: SQLite mapping, read-only PC save, authenticated mobile sync, merged profiles/runs/events, live reads, locks, versions, missing/corrupt files and local HTTP');
  } finally {
    if (server) await new Promise(resolve => server.close(resolve));
    writer?.close();
    for (const target of [filename, mobileDatabase]) for (const suffix of ['', '-journal', '-wal', '-shm']) if (existsSync(target + suffix)) unlinkSync(target + suffix);
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) run().catch(error => { console.error(error); process.exitCode = 1; });
