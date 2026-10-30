import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFileSync,unlinkSync,mkdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import vm from 'node:vm';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {readDashboard} from '../../web/server.mjs';
import {createFixture} from './web_server.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const equipment = createRequire(import.meta.url)('../../web/equipment.js');
const run = (id,playerId='a',loadout=null) => ({id,playerId,loadout});
const event = (runId,type,payload,sequence,playerId='a') => ({runId,playerId,type,payload,sequence,occurredAt:'2026-10-17T12:00:00Z'});
const data = {players:[{id:'a',loadout:['plasma','precision']}],runs:[run('old'),run('first'),run('second'),run('third'),run('other','b')],events:[
  event('first','run_started',{loadout:['pistol','rifle']},1),
  event('first','loadout_selected',{weapons:['rifle','shotgun']},2),
  event('second','loadout_selected',{weapons:['shotgun','rifle']},1),
  event('third','run_started',{loadout:['pistol']},1),
  event('other','loadout_selected',{weapons:['plasma','precision']},1,'b'),
  event('old','loadout_selected',{weapons:['plasma','precision']},1,'wrong-profile'),
]};
assert.equal(equipment.loadoutForRun(data.runs[0],data),null,'Current profile and another player cannot fill missing historical data');
assert.deepEqual(equipment.loadoutForRun(data.runs[1],data),['rifle','shotgun'],'Actual selection overrides initial equipment');
assert.equal(equipment.normalize(['knife']),null,'Always available knife is not a selected weapon slot');
assert.equal(equipment.normalize(['rifle','rifle']),null);
assert.equal(equipment.normalize(['<script>']),null);
assert.equal(equipment.normalize(['rifle','shotgun','pistol']),null);
const favorite = equipment.favorite(data,'a');
assert.deepEqual(favorite.weapons,['rifle','shotgun']);
assert.equal(favorite.runs,2,'Swapping slots does not create another favorite combination');
assert.equal(favorite.totalKnownRuns,3);
assert.equal(favorite.unknownRuns,1);
assert.equal(favorite.tied,false);
assert.equal(equipment.favorite(data,'missing'),null);
const tied = equipment.favorite({runs:[run('one','a',['rifle']),run('two','a',['pistol'])]},'a');
assert.equal(tied.tied,true);
assert.equal(tied.alternatives.length,2,'Do not conceal tied favorites');
equipment.annotate(data);
assert.deepEqual(data.players[0].favoriteLoadout,favorite);
assert.match(equipment.renderRun(data,data.runs[0]),/Sin registro de equipación/);
assert.match(equipment.renderFavorite(data,'a'),/2 de 3 partidas/);

// Run the exact same script as a plain browser script, with hostile catalog text.
const context = {window:{S07_CATALOG:{weapons:[{id:'rifle',name:'<img src=x onerror=alert(1)>'}]}}};
vm.runInNewContext(readFileSync(path.join(root,'web/equipment.js'),'utf8'),context);
const html = context.window.S07_EQUIPMENT.renderRun({events:[]},run('safe','a',['rifle']));
assert.ok(html.includes('&lt;img'));
assert.ok(!html.includes('<img src=x'));

// Real server attribution and read-only behavior, using an isolated fixture.
const fixtureRoot = path.join(root,'.godot','web-server-tests');
mkdirSync(fixtureRoot,{recursive:true});
const filename = path.join(fixtureRoot,`equipment-${process.pid}.sqlite`);
let db;
try {
  db = createFixture(filename);
  db.exec('PRAGMA user_version=3');
  const insert = db.prepare('INSERT INTO game_events VALUES(?,?,?,?,?,?,?,?)');
  insert.run('equipment-won','won',2,'loadout_selected','2026-10-16T00:00:01Z',1,1,JSON.stringify({weapons:['rifle','shotgun']}));
  insert.run('equipment-playing','playing',3,'loadout_selected','2026-10-16T00:01:02Z',32,2,JSON.stringify({weapons:['shotgun','rifle']}));
  const hash = () => createHash('sha256').update(readFileSync(filename)).digest('hex');
  const before = hash(), snapshot = readDashboard(filename);
  assert.equal(hash(),before);
  assert.deepEqual(snapshot.runs.find(item=>item.id==='won').loadout,['rifle','shotgun']);
  assert.equal(snapshot.runs.find(item=>item.id==='interrupted').loadout,null);
  assert.equal(snapshot.players.find(item=>item.id==='uuid-alpha').favoriteLoadout.runs,2);
  assert.equal(snapshot.players.find(item=>item.id==='uuid-beta').favoriteLoadout,null);
} finally {
  db?.close();
  for(const suffix of ['', '-wal','-shm','-journal'])try{unlinkSync(filename+suffix);}catch{}
}
console.log('Equipment: historical attribution, unknown data, slot order, ties, escaping, server and read-only SQLite PASS');
