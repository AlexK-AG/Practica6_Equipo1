import assert from 'node:assert/strict';
import {readFileSync,unlinkSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import vm from 'node:vm';
import {createFixture} from './web_server.mjs';
import {readDashboard,createServer} from '../../web/server.mjs';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const filename = path.join(root,'.godot/web-server-tests',`sector-${process.pid}.sqlite`);
const context = {Intl};
vm.createContext(context);
vm.runInContext(readFileSync(path.join(root,'web/sector-stats.js'),'utf8'),context);
let db,server;
try {
  db = createFixture(filename);
  db.exec("INSERT INTO run_history VALUES('loss','alpha',1,1,'defeat',20,0,2,'2026-10-17T00:00:00Z','2026-10-17T00:00:20Z')");
  db.exec("INSERT INTO run_sessions VALUES('loss','alpha',1,1,'2026-10-17T00:00:00Z','2026-10-17T00:00:20Z','defeat',20,2,2147483647)");
  db.exec("INSERT INTO history_archive VALUES('alpha',1,'defeat',2,40,3),('alpha',1,'victory',3,60,6),('alpha',1,'abandoned',10,100,0)");
  const hash = () => createHash('sha256').update(readFileSync(filename)).digest('hex');
  const before = hash(),data = readDashboard(filename);
  assert.equal(data.runs.length,4,'Finished sessions and history rows merge by attempt ID');
  const row = context.S07_SECTORS.calculate(data,{playerId:'uuid-alpha'})[0];
  assert.equal(row.seconds,230.5);
  assert.equal(row.victories,4);
  assert.equal(row.defeats,3);
  assert.equal(row.resolved,7);
  assert.equal(row.rate,3/7*100);
  server = createServer({databasePath:filename});
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  for (const [file,type] of [['sector-stats.js','text/javascript'],['sector-stats.css','text/css']]) {
    const response = await fetch(base+'/'+file);
    assert.equal(response.status,200);
    assert.ok(response.headers.get('content-type').startsWith(type));
  }
  assert.equal(hash(),before,'Dashboard and public resources never write personal or fixture data');
  console.log('SECTOR STATS SQLITE: session/history union, archived totals, profile scope, static routes and read-only DB PASS');
} finally {
  if(server)await new Promise(resolve=>server.close(resolve));
  db?.close();
  for(const suffix of ['', '-wal','-shm','-journal'])try{unlinkSync(filename+suffix);}catch{}
}
