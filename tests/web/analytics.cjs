/* Statistics use retained attempts/events, never current profile equipment or archive estimates. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const context = {Intl,Date,Set,Map,WeakMap,S07_CATALOG:{weapons:[{id:'rifle',name:'Fusil'}]}};
vm.createContext(context);
vm.runInContext(fs.readFileSync(path.resolve(__dirname,'../../web/analytics.js'),'utf8'),context);
const charts = context.S07_ANALYTICS;
const iso = (day,hour=12) => new Date(2026,9,day,hour).toISOString();
const runs=[
  {id:'one',playerId:'a',startedAt:iso(10),loadout:['rifle','pistol','rifle']},
  {id:'two',playerId:'a',startedAt:iso(10,15),loadout:['rifle','shotgun']},
  {id:'three',playerId:'b',startedAt:iso(10,16),loadout:null},
  {id:'four',playerId:'a',startedAt:iso(12),loadout:['pistol','shotgun']},
  {id:'five',playerId:'a',startedAt:'invalid',loadout:null}
];
const events=[
  {id:'e1',playerId:'a',type:'upgrade_chosen',payload:{upgrade:'health'}},
  {id:'e2',playerId:'a',type:'upgrade_chosen',payload:{upgrade:'health'}},
  {id:'e3',playerId:'b',type:'upgrade_chosen',payload:{upgrade:'shield'}},
  {id:'e4',playerId:'a',type:'weapon_found',payload:{upgrade:'health',weapon:'rifle'}}
];
const data={runs:[...runs,runs[0]],events:[...events,events[0]],players:[{id:'b',loadout:['plasma'],upgrades:[{id:'damage'}]}],historyArchive:[{playerId:'a',attempts:999}]};
const stats=charts.calculate(data);
assert.equal(stats.totalRuns,5);
assert.equal(stats.knownLoadouts,3);
assert.equal(stats.invalidDates,1);
assert.equal(stats.days[0].players,2);
assert.equal(stats.days[0].runs,3);
assert.equal(stats.weapons.find(row=>row.id==='rifle').count,2);
assert.equal(stats.weapons.find(row=>row.id==='pistol').count,2);
assert.equal(stats.weapons.some(row=>row.id==='plasma'),false);
assert.equal(stats.upgradeChoices,3);
assert.equal(stats.upgrades.find(row=>row.id==='health').count,2);
assert.equal(stats.upgrades.some(row=>row.id==='damage'),false);
const player=charts.calculate(data,{playerId:'a'});
assert.equal(player.days[0].players,1);
assert.equal(player.days[0].runs,2);
assert.equal(player.upgradeChoices,2);
assert.equal(charts.chartDays(stats.days).length,3);
assert.equal(charts.chartDays(stats.days)[1].runs,0);
assert.equal(charts.chartDays([{date:'2026-01-01',runs:1,players:1},{date:'2026-10-17',runs:1,players:1}]).length,30);
assert.equal(charts.calculate(data,{runs:[runs[0]]}).totalRuns,1);
assert.match(charts.render(data),/Los totales archivados/);
assert.match(charts.render(data),/Equipación conocida en 3 de 5 partidas/);
assert.match(charts.render({runs:[],events:[]}),/No hay partidas con fecha/);
assert.match(charts.render({runs:[],events:[{type:'upgrade_chosen',payload:{upgrade:'<img onerror="bad">'}}]}),/&lt;img/);
context.S07_EQUIPMENT={loadoutForRun:run=>run.id==='three'?['precision','rifle']:null};
assert.equal(charts.calculate(data).knownLoadouts,4);
let changed;
const daily={innerHTML:''}, target={dataset:{},matches:()=>true,addEventListener:(event,callback)=>{changed=callback;},querySelector:()=>daily};
charts.bind(target,data);
changed({target:{matches:()=>true,value:'runs'}});
assert.match(daily.innerHTML,/Partidas iniciadas/);
assert.match(charts.render(data),/value="runs" selected/);
charts.bind(target,{runs:[],events:[]});
changed({target:{matches:()=>true,value:'players'}});
assert.match(daily.innerHTML,/No hay partidas/);
console.log('Analytics: unique daily activity, local dates, missing days, weapons, choices, archive exclusion, escaping and selector passed.');
