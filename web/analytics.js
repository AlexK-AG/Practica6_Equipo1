/* Local, dependency-free statistics. Archived totals never become invented daily data. */
(() => {
  'use strict';
  const escape = value => String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
  const number = value => new Intl.NumberFormat('es-MX').format(value);
  const upgradeNames = {health:'Vitalidad',damage:'Munición potenciada',shield:'Escudo regenerable',rifle:'Especialista en fusil',reload:'Recarga táctica',regen:'Nanorreparación',magazine:'Cargador ampliado',armor:'Blindaje',melee:'Cuchillo mejorado',speed:'Movilidad'};
  let activityMode = 'players';
  const dayKey = date => `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`;
  function runLoadout(data, run) {
    if (Array.isArray(run.loadout) && run.loadout.length) return run.loadout;
    const helper = globalThis.S07_EQUIPMENT?.loadoutForRun;
    return helper ? helper(run, data) : null;
  }
  function calculate(data, {playerId='',runs=data.runs || []} = {}) {
    const unique = new Map();
    runs.forEach(run => {if ((!playerId || run.playerId === playerId) && run.id && !unique.has(run.id)) unique.set(run.id, run);});
    const daily = new Map(), weapons = new Map(), upgrades = new Map();
    let knownLoadouts = 0, invalidDates = 0;
    for (const run of unique.values()) {
      const timestamp = Date.parse(run.startedAt);
      if (Number.isFinite(timestamp)) {
        const date = new Date(timestamp), key = dayKey(date);
        if (!daily.has(key)) daily.set(key, {date:key,runs:0,players:new Set()});
        const day = daily.get(key); day.runs++;
        if (run.playerId) day.players.add(run.playerId);
      } else invalidDates++;
      const loadout = runLoadout(data, run);
      if (Array.isArray(loadout) && loadout.some(id => typeof id === 'string' && id)) {
        knownLoadouts++;
        for (const id of new Set(loadout.filter(id => typeof id === 'string' && id))) weapons.set(id,(weapons.get(id)||0)+1);
      }
    }
    const seenEvents = new Set();
    for (const event of data.events || []) {
      if (event.type !== 'upgrade_chosen' || (playerId && event.playerId !== playerId) || !event.payload?.upgrade) continue;
      const key = event.id || JSON.stringify([event.playerId,event.runId,event.occurredAt,event.payload]);
      if (seenEvents.has(key)) continue;
      seenEvents.add(key);
      const id = String(event.payload.upgrade); upgrades.set(id,(upgrades.get(id)||0)+1);
    }
    const sort = map => [...map].map(([id,count])=>({id,count})).sort((a,b)=>b.count-a.count || a.id.localeCompare(b.id));
    const days = [...daily.values()].sort((a,b)=>a.date.localeCompare(b.date));
    return {days:days.map(day=>({...day,players:day.players.size})),weapons:sort(weapons),upgrades:sort(upgrades),knownLoadouts,totalRuns:unique.size,invalidDates,upgradeChoices:seenEvents.size};
  }
  function chartDays(days) {
    if (!days.length) return [];
    const last = new Date(`${days[days.length-1].date}T12:00:00`), first = new Date(last);
    first.setDate(first.getDate()-29);
    const earliest = new Date(`${days[0].date}T12:00:00`);
    if (first < earliest) first.setTime(earliest.getTime());
    const values = new Map(days.map(day=>[day.date,day])), result = [];
    for (const date=new Date(first);date<=last;date.setDate(date.getDate()+1)) {
      const key=dayKey(date); result.push(values.get(key)||{date:key,runs:0,players:0});
    }
    return result;
  }
  const dateLabel = key => new Date(`${key}T12:00:00`).toLocaleDateString('es-MX',{day:'numeric',month:'short'});
  function dailyChart(stats) {
    const days=chartDays(stats.days), label=activityMode==='players'?'Jugadores únicos':'Partidas iniciadas', max=Math.max(1,...days.map(day=>day[activityMode]));
    if (!days.length) return '<div class="analytics-empty">No hay partidas con fecha de inicio para esta selección.</div>';
    const labelStep=Math.max(1,Math.ceil(days.length/7));
    return `<div class="analytics-daily-scroll" tabindex="0" aria-label="Gráfica diaria; desplázate horizontalmente si es necesario"><div class="analytics-daily" style="--daily-count:${days.length}" role="list" aria-label="${label} por día">${days.map((day,index)=>`<div class="analytics-day" role="listitem" aria-label="${escape(dateLabel(day.date))}: ${day[activityMode]} ${label.toLowerCase()}"><span class="analytics-day-count">${number(day[activityMode])}</span><div class="analytics-day-track"><span style="height:${day[activityMode]/max*100}%" title="${escape(dateLabel(day.date))}: ${number(day[activityMode])}"></span></div><span class="analytics-day-label">${index%labelStep===0||index===days.length-1?escape(dateLabel(day.date)):''}</span></div>`).join('')}</div></div><p class="analytics-caption">${escape(dateLabel(days[0].date))} – ${escape(dateLabel(days[days.length-1].date))} · Fechas locales · Cada partida cuenta el día que comenzó.</p>`;
  }
  function ranking(rows, name, total, unit, tone) {
    if (!rows.length) return `<div class="analytics-empty">${unit==='elecciones'?'Aún no hay elecciones de mejora registradas.':'No hay equipaciones registradas para estas partidas.'}</div>`;
    const max=Math.max(1,...rows.map(row=>row.count));
    return `<ol class="analytics-ranking ${tone}">${rows.map(row=>`<li><div class="analytics-ranking-label"><span>${escape(name(row.id))}</span><b>${number(row.count)} <small>${unit}</small></b></div><div class="analytics-ranking-track"><span style="width:${row.count/max*100}%"></span></div><span class="analytics-share">${Math.round(row.count/Math.max(1,total)*100)}% ${unit==='elecciones'?'de las elecciones':'de las partidas con equipación conocida'}</span></li>`).join('')}</ol>`;
  }
  function render(data, options={}) {
    const stats=calculate(data,options), weapons=globalThis.S07_CATALOG?.weapons || [];
    const archived=(data.historyArchive||[]).some(row=>!options.playerId||row.playerId===options.playerId);
    const explanation = 'Se usan las partidas y los eventos conservados en la base. Las partidas antiguas sin equipación registrada no se incluyen en el ranking de armas.';
    return `<section class="analytics" data-analytics-root aria-label="Gráficas de actividad y preferencias"><section class="panel analytics-activity"><div class="section-head"><div><h2>Actividad por día</h2><p>Hasta 30 días, terminando en la última fecha registrada.</p></div><label class="analytics-selector"><span class="sr-only">Mostrar actividad por día</span><select data-analytics-mode aria-label="Mostrar actividad por día"><option value="players" ${activityMode==='players'?'selected':''}>Jugadores por día</option><option value="runs" ${activityMode==='runs'?'selected':''}>Partidas por día</option></select></label></div><div data-analytics-daily>${dailyChart(stats)}</div></section><div class="analytics-rankings"><section class="panel"><div class="section-head"><div><h2>Armas más utilizadas</h2><p>Presencia en la equipación inicial de cada partida.</p></div></div>${ranking(stats.weapons,id=>weapons.find(weapon=>weapon.id===id)?.name||id,stats.knownLoadouts,'partidas','analytics-mint')}<p class="analytics-caption">Equipación conocida en ${number(stats.knownLoadouts)} de ${number(stats.totalRuns)} partidas. Cada arma cuenta una vez por partida.</p></section><section class="panel"><div class="section-head"><div><h2>Mejoras más elegidas</h2><p>Elecciones confirmadas en el registro de eventos.</p></div></div>${ranking(stats.upgrades,id=>upgradeNames[id]||id,stats.upgradeChoices,'elecciones','analytics-amber')}<p class="analytics-caption">${number(stats.upgradeChoices)} elecciones registradas. Los reinicios de campaña no se infieren como elecciones nuevas.</p></section></div><p class="analytics-note">${explanation}${archived?' Los totales archivados conservan los acumulados, pero no la fecha ni el detalle necesario para estas gráficas.':''}${stats.invalidDates?' Se omiten de la actividad diaria las partidas sin fecha de inicio válida.':''}</p></section>`;
  }
  const dataForRoot = new WeakMap();
  function bind(root, data, options={}) {
    const target = root.matches?.('[data-analytics-root]') ? root : root.querySelector('[data-analytics-root]');
    if (!target || !data) return;
    dataForRoot.set(target,{data,options});
    if (target.dataset.analyticsBound) return;
    target.dataset.analyticsBound='true';
    target.addEventListener('change',event=>{
      if (!event.target.matches('[data-analytics-mode]')) return;
      activityMode=event.target.value==='runs'?'runs':'players';
      const context=dataForRoot.get(target);
      target.querySelector('[data-analytics-daily]').innerHTML=dailyChart(calculate(context.data,context.options));
    });
  }
  globalThis.S07_ANALYTICS={render,bind,calculate,chartDays};
})();
