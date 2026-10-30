/* Explicitly fictional preview. Never used as a fallback for a real API error. */
window.S07_DEMO = () => {
  const generatedAt = '2026-10-16T20:30:00Z';
  const players = [
    {id:'atlas',name:'Piloto Atlas',record:18420,completedLevels:[1,2,3,4,5,6,7,8,9,10],weaponUnlocks:['rifle','shotgun','precision','plasma'],grenadeUnlocks:['fragmentation','slow'],discoveredEnemies:Array.from({length:18},(_,i)=>i),upgrades:[{stage:1,id:'health'},{stage:2,id:'damage'},{stage:3,id:'shield'}],tutorialCompleted:true,loadout:['precision','plasma'],scores:{1:1640,2:1830,3:1720,4:1930,5:2100,6:1860,7:1540,8:2030,9:1870,10:1900}},
    {id:'nova',name:'Nova',record:12680,completedLevels:[1,2,3,4,5,6,7],weaponUnlocks:['rifle','shotgun','precision'],grenadeUnlocks:['fragmentation','slow'],discoveredEnemies:[0,1,2,3,4,5,6,7,8,9,10,11,13,14,15,16,17],upgrades:[{stage:1,id:'shield'},{stage:2,id:'reload'}],tutorialCompleted:true,loadout:['rifle','precision'],scores:{1:1800,2:1840,3:1710,4:1900,5:1760,6:1820,7:1850}},
    {id:'vega',name:'Vega',record:7420,completedLevels:[1,2,3,4],weaponUnlocks:['rifle','shotgun'],grenadeUnlocks:['fragmentation'],discoveredEnemies:[0,1,2,3,4,5,6,7,13,14],upgrades:[{stage:1,id:'health'},{stage:2,id:'reload'}],tutorialCompleted:false,loadout:['pistol','shotgun'],scores:{1:1710,2:1820,3:1930,4:1960}},
    {id:'echo',name:'Echo',record:1690,completedLevels:[1],weaponUnlocks:['rifle'],grenadeUnlocks:[],discoveredEnemies:[0,1,2,3,4,5,6],upgrades:[{stage:1,id:'health'}],tutorialCompleted:true,loadout:['pistol','rifle'],scores:{1:1690}}
  ];
  const runs = Array.from({length:28},(_,i)=>{
    const p=players[i%4], level=1+(i%Math.min(10,p.completedLevels.length+1)), outcome=i%7===0?'defeat':i%9===0?'abandoned':'victory';
    const end = new Date(Date.parse(generatedAt)-i*7*3600000), duration=155+(i*43)%510;
    return {id:'demo-run-'+i,playerId:p.id,level,difficulty:i%3,outcome,durationSeconds:duration,score:outcome==='victory'?1400+(i*71)%900:0,kills:9+(i*7)%35,startedAt:new Date(end-duration*1000).toISOString(),endedAt:end.toISOString()};
  });
  const types=['objective_completed','weapon_found','shot_fired','reload_completed','enemy_killed','supply_collected','grenade_used','run_ended'];
  const events=runs.flatMap((r,i)=>types.slice(0,4+i%5).map((type,j)=>({id:`demo-event-${i}-${j}`,runId:r.id,playerId:r.playerId,level:r.level,type,occurredAt:new Date(Date.parse(r.startedAt)+j*14000).toISOString(),payload:type==='weapon_found'?{weapon:'shotgun'}:type==='enemy_killed'?{enemy:'Explorador'}:type==='objective_completed'?{objective:'Restablecer energía'}:{}})));
  return {schemaVersion:1,generatedAt,capabilities:{events:true},players,runs,events};
};
