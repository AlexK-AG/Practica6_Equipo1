/* Shared equipment rules: browser presentation and server-side historical attribution. */
(function (root) {
  'use strict';
  const allowed = new Set(['pistol', 'rifle', 'shotgun', 'precision', 'plasma']);
  const defaults = {pistol:'Pistola',rifle:'Fusil',shotgun:'Escopeta',precision:'Precisión',plasma:'Plasma'};
  const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  function normalize(value) {
    return Array.isArray(value) && value.length > 0 && value.length <= 2 &&
      value.every(id => allowed.has(id)) && new Set(value).size === value.length ? [...value] : null;
  }
  function forRun(data, run) {
    if (!run) return {weapons:[],known:false,source:null};
    const stored = normalize(run.loadout);
    if (stored) return {weapons:stored,known:true,source:run.loadoutSource || 'recorded'};
    // Only an event belonging to this exact attempt can establish its equipment.
    const events = (data?.events || []).filter(event => event.runId === run.id &&
      event.playerId === run.playerId).sort((a,b) => (a.sequence || 0) - (b.sequence || 0) ||
        Date.parse(a.occurredAt) - Date.parse(b.occurredAt));
    const selection = events.find(event => event.type === 'loadout_selected' && normalize(event.payload?.weapons));
    const started = events.find(event => event.type === 'run_started' && normalize(event.payload?.loadout));
    const event = selection || started;
    const weapons = event && normalize(event.type === 'loadout_selected' ? event.payload.weapons : event.payload.loadout);
    return weapons ? {weapons,known:true,source:event.type} : {weapons:[],known:false,source:null};
  }
  function loadoutForRun(run, data) {
    const result = forRun(data,run);
    return result.known ? result.weapons : null;
  }
  function favorite(data, playerId) {
    const combinations = new Map();
    let totalKnownRuns = 0, unknownRuns = 0;
    for (const run of data?.runs || []) {
      if (run.playerId !== playerId) continue;
      const result = forRun(data,run);
      if (!result.known) {unknownRuns++;continue;}
      totalKnownRuns++;
      // Slot order is irrelevant: a pair represents the same equipment in either slot.
      const weapons = [...result.weapons].sort(), key = weapons.join('|');
      const item = combinations.get(key) || {weapons,runs:0};
      item.runs++;
      combinations.set(key,item);
    }
    const ordered = [...combinations.values()].sort((a,b) => b.runs-a.runs || a.weapons.join('|').localeCompare(b.weapons.join('|')));
    if (!ordered.length) return null;
    const winner = ordered[0], alternatives = ordered.filter(item => item.runs === winner.runs).map(item => item.weapons);
    return {...winner,tied:alternatives.length > 1,alternatives,totalKnownRuns,unknownRuns};
  }
  function annotate(data) {
    for (const run of data.runs || []) {
      const result = forRun(data,run);
      run.loadout = result.known ? result.weapons : null;
      run.loadoutSource = result.source;
    }
    for (const player of data.players || []) player.favoriteLoadout = favorite(data,player.id);
    return data;
  }
  const name = id => root.S07_CATALOG?.weapons?.find(weapon => weapon.id === id)?.name || defaults[id] || id;
  const chips = weapons => weapons.map(id => `<span class="item-chip known">${escape(name(id))}</span>`).join('');
  function renderRun(data, run) {
    const result = forRun(data,run);
    return `<section class="run-equipment" aria-label="Equipación de esta partida"><h3>Equipación elegida</h3>${result.known ? `<div class="upgrade-list">${chips(result.weapons)}</div><p class="subtle">Armas equipadas al iniciar este intento. El cuchillo está siempre disponible.</p>` : '<p class="subtle">Sin registro de equipación para esta partida. La selección actual del perfil no permite reconstruirla.</p>'}</section>`;
  }
  function renderFavorite(data, playerId) {
    const result = favorite(data,playerId);
    return `<section class="panel favorite-equipment" aria-label="Equipación favorita"><div class="section-head"><div><h2>Equipación favorita</h2><p>La combinación más elegida entre las partidas conservadas con equipación registrada.</p></div></div>${result ? `<div class="upgrade-list">${chips(result.weapons)}</div><p class="subtle">${result.runs} de ${result.totalKnownRuns} partidas con equipación conocida.${result.tied ? ` Empate con ${result.alternatives.slice(1).map(weapons=>weapons.map(id=>escape(name(id))).join(' + ')).join('; ')}.` : ''}${result.unknownRuns ? ` ${result.unknownRuns} partidas sin equipación registrada quedan fuera del cálculo.` : ''}</p>` : '<p class="subtle">Todavía no hay partidas con equipación registrada para calcular una favorita.</p>'}</section>`;
  }
  const api = {normalize,forRun,loadoutForRun,favorite,annotate,renderRun,renderFavorite};
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.S07_EQUIPMENT = api;
})(typeof window === 'undefined' ? globalThis : window);
