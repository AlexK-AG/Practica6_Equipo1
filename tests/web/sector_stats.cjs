const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const context = {Intl,S07_CATALOG:{levels:['<script>']}};
vm.createContext(context);
vm.runInContext(fs.readFileSync(path.resolve(__dirname,'../../web/sector-stats.js'),'utf8'),context);
const stats = context.S07_SECTORS;
const runs = [
  {id:'win',playerId:'a',level:1,outcome:'victory',durationSeconds:20},
  {id:'loss',playerId:'a',level:1,outcome:'defeat',durationSeconds:30},
  {id:'left',playerId:'a',level:1,outcome:'abandoned',durationSeconds:40},
  {id:'open',playerId:'a',level:1,outcome:'in_progress',durationSeconds:50},
  {id:'interrupted',playerId:'a',level:1,outcome:'interrupted',durationSeconds:60},
  {id:'other',playerId:'b',level:1,outcome:'defeat',durationSeconds:10},
  {id:'only-open',playerId:'a',level:2,outcome:'in_progress',durationSeconds:4},
  {id:'only-win',playerId:'a',level:3,outcome:'victory',durationSeconds:5},
];
const data = {runs:[...runs,runs[0]],historyArchive:[
  {playerId:'a',level:1,outcome:'victory',attempts:3,durationSeconds:90},
  {playerId:'a',level:1,outcome:'defeat',attempts:1,durationSeconds:15},
  {playerId:'a',level:1,outcome:'abandoned',attempts:10,durationSeconds:100},
  {playerId:'b',level:2,outcome:'defeat',attempts:8,durationSeconds:70},
]};
const all = stats.calculate(data), player = stats.calculate(data,{playerId:'a'});
assert.equal(all.length,10);
assert.equal(all[0].seconds,415,'All attempt times and archives are counted once');
assert.equal(player[0].seconds,405);
assert.equal(player[0].victories,4);
assert.equal(player[0].defeats,2);
assert.equal(player[0].resolved,6,'Denominator excludes abandoned, open and interrupted attempts, including archives');
assert.equal(player[0].rate,2/6*100);
assert.equal(all[0].rate,3/7*100);
assert.equal(player[1].rate,null,'No completed win/loss sample is unknown, not zero percent');
assert.equal(player[2].rate,0,'A sector with only wins has a real zero percent');
assert.equal(stats.calculate(data,{playerId:'b'})[1].rate,100,'Archive-only sector remains measurable');
assert.equal(stats.calculate({runs:[]})[0].rate,null);
assert.match(stats.render(data),/&lt;script&gt;/,'Names are escaped');
assert.match(stats.render(data),/Tiempo activo acumulado/);
assert.equal((stats.render(data,{available:false}).match(/sector-value">—/g)||[]).length,10,'Offline does not fabricate zero results');
console.log('SECTOR STATS: totals, archives, denominators, profile filters, unknown/zero and escaping PASS');
