/* Level comparisons include archived totals; a defeat is a lost mission, not a death event. */
(() => {
  'use strict';
  const esc = value => String(value ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const nf = new Intl.NumberFormat('es-MX',{maximumFractionDigits:1});
  const number = value => nf.format(value);
  let mode = 'time', measure = 'count';
  function calculate(data, {playerId='',runs=data.runs || []}={}) {
    const levels = Array.from({length:10},(_,index)=>({level:index+1,seconds:0,victories:0,defeats:0,resolved:0,rate:null}));
    const seen = new Set();
    function add(row, attempts, seconds) {
      if (playerId && row.playerId !== playerId) return;
      const target = levels[row.level-1];
      if (!target) return;
      target.seconds += Math.max(0,Number(seconds)||0);
      if (row.outcome === 'victory') target.victories += attempts;
      if (row.outcome === 'defeat') target.defeats += attempts;
    }
    for (const run of runs) {
      if (seen.has(run.id)) continue;
      seen.add(run.id);
      add(run,1,run.durationSeconds);
    }
    for (const row of data.historyArchive || []) add(row,Math.max(0,Number(row.attempts)||0),row.durationSeconds);
    for (const row of levels) {
      row.resolved = row.victories + row.defeats;
      row.rate = row.resolved ? row.defeats/row.resolved*100 : null;
    }
    return levels;
  }
  function content(data, options) {
    const rows = calculate(data,options), online = options.available !== false;
    const difficulty = mode === 'difficulty', rate = measure === 'rate';
    const levels = globalThis.S07_CATALOG?.levels || [];
    const maximum = difficulty && rate ? 100 : Math.max(1,...rows.map(row=>difficulty ? row.defeats : row.seconds));
    const description = difficulty ? (rate ? 'Porcentaje de derrotas entre victorias y derrotas de cada nivel.' : 'Número de partidas perdidas en cada nivel.') : 'Tiempo activo acumulado en cada nivel.';
    return `<div class="section-head sector-heading"><div><h2>Actividad por sector</h2><p>${description}</p></div><div class="sector-controls"><label><span>Mostrar</span><select data-sector-mode aria-label="Mostrar actividad por sector"><option value="time" ${!difficulty?'selected':''}>Tiempo activo</option><option value="difficulty" ${difficulty?'selected':''}>Dificultad · derrotas</option></select></label>${difficulty ? `<label><span>Medida</span><select data-sector-measure aria-label="Medida de derrotas"><option value="count" ${!rate?'selected':''}>Número de derrotas</option><option value="rate" ${rate?'selected':''}>Porcentaje de derrotas</option></select></label>` : ''}</div></div><div class="sector-bars ${difficulty?'sector-defeats':''}" role="list" aria-label="${difficulty?'Derrotas':'Tiempo activo'} por nivel">${rows.map(row=>{
      const value = difficulty ? (rate ? row.rate : row.defeats) : row.seconds;
      const label = levels[row.level-1] || `Nivel ${row.level}`;
      const amount = !online ? '—' : difficulty ? (rate ? row.rate===null ? '—' : number(row.rate)+'%' : number(row.defeats)) : number(Math.round(row.seconds/60))+' min';
      const detail = difficulty ? `${number(row.defeats)} derrotas de ${number(row.resolved)} partidas resueltas` : `${number(Math.round(row.seconds))} segundos de tiempo activo`;
      const tooltip = online ? `${label}: ${difficulty && rate && row.rate===null ? 'sin victorias ni derrotas registradas' : detail}` : `${label}: sin datos conectados`;
      return `<div class="sector-bar" role="listitem" aria-label="${esc(tooltip)}" title="${esc(tooltip)}"><span class="bar-number">${String(row.level).padStart(2,'0')}</span><div class="bar-track" aria-hidden="true"><span style="height:${online && value!==null ? Math.min(100,value/maximum*100) : 0}%;${!online||!value?'min-height:0;':''}"></span></div><span class="bar-caption">${esc(label)}</span><span class="mono sector-value">${amount}</span>${difficulty ? `<span class="sector-sample">${online?number(row.defeats)+' / '+number(row.resolved)+' resueltas':'Sin datos'}</span>` : ''}</div>`;
    }).join('')}</div><p class="sector-explanation">${difficulty ? 'Derrota significa misión perdida: incluye muerte del jugador y fallos por tiempo u objetivos. El porcentaje es derrotas ÷ (victorias + derrotas) × 100; excluye abandonos, partidas en curso e interrumpidas. «—» indica que no hay victorias ni derrotas para calcularlo. Cada intento cuenta una vez.' : 'Suma el tiempo activo de todos los intentos, incluidos abandonados, en curso e interrumpidos.'} Incluye los acumulados archivados y respeta el filtro de jugador. ${difficulty?'Se agrupan todas las dificultades; la muestra de cada sector ayuda a interpretar el resultado.':''}</p>`;
  }
  function render(data,options={}) {return `<section class="panel sector-statistics" data-sector-stats aria-label="Actividad por sector">${content(data,options)}</section>`;}
  const contexts = new WeakMap();
  function bind(root,data,options={}) {
    const target = root.matches?.('[data-sector-stats]') ? root : root.querySelector('[data-sector-stats]');
    if (!target) return;
    contexts.set(target,{data,options});
    if (target.dataset.sectorBound) return;
    target.dataset.sectorBound = 'true';
    target.addEventListener('change',event=>{
      if (event.target.matches('[data-sector-mode]')) mode = event.target.value === 'difficulty' ? 'difficulty' : 'time';
      else if (event.target.matches('[data-sector-measure]')) measure = event.target.value === 'rate' ? 'rate' : 'count';
      else return;
      const context = contexts.get(target);
      const selector = event.target.hasAttribute('data-sector-mode') ? '[data-sector-mode]' : '[data-sector-measure]';
      target.innerHTML = content(context.data,context.options);
      target.querySelector(selector)?.focus();
    });
  }
  globalThis.S07_SECTORS = {calculate,render,bind};
})();
