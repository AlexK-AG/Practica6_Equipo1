/* Top-down playback of recorded positions. This never simulates combat. */
(() => {
  'use strict';
  const esc = value => String(value ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const time = seconds => `${Math.floor(seconds/60)}:${String(Math.floor(seconds%60)).padStart(2,'0')}`;
  let active;
  function markup(run) {
    return `<section class="replay-section" aria-label="Mapa y reproducción de la partida"><div class="section-head"><div><span class="eyebrow">RECONSTRUCCIÓN / SECTOR ${String(run.level).padStart(2,'0')}</span><h3>Recorrido de la partida</h3><p>Tu recorrido se dibuja en verde. Los enemigos muestran su posición y subtipo.</p></div></div><div data-replay-host><p class="replay-status" role="status">Consultando el recorrido…</p></div></section>`;
  }
  function demo(run) {
    const floors=[{points:[[-15,-15],[15,-15],[15,15],[-15,15]]}],obstacles=[{points:[[-5,-6],[-2,-6],[-2,0],[-5,0]]},{points:[[3,2],[6,2],[6,5],[3,5]]}];
    return {available:true,metadata:{version:1,intervalSeconds:.5,map:{floors,obstacles,doors:[]}},frames:Array.from({length:121},(_,i)=>({t:i*.5,p:[-10+i*.14,10-Math.sin(i/30)*8],enemies:[{id:'demo-a',kind:0,p:[7-Math.sin(i/20)*4,-8+i*.08]},{id:'demo-b',kind:5,p:[-9+i*.08,-10]}],closedDoors:[]}))};
  }
  function name(enemy) {return (enemy.boss?'Jefe · ':'')+(window.S07_CATALOG.enemies.find(row=>row.id===enemy.kind)?.name || `Subtipo ${enemy.kind}`);}
  function bracket(frames,t) {
    let lo=0,hi=frames.length-1;
    while(lo<hi){const mid=Math.ceil((lo+hi)/2);if(frames[mid].t<=t)lo=mid;else hi=mid-1;}
    return [lo,frames[lo],frames[Math.min(lo+1,frames.length-1)]];
  }
  function interpolate(a,b,f) {return Math.hypot(a[0]-b[0],a[1]-b[1])>8 ? a : [a[0]+(b[0]-a[0])*f,a[1]+(b[1]-a[1])*f];}
  async function mount(root,run,{demoMode=false}={}) {
    active?.destroy();
    const host=root.querySelector('[data-replay-host]');if(!host)return;
    const controller=new AbortController();let raf=0,observer;
    const session={destroy(){controller.abort();cancelAnimationFrame(raf);observer?.disconnect();}};active=session;
    try {
      let data;
      if(demoMode)data=demo(run);
      else {const response=await fetch(`/api/replay?run=${encodeURIComponent(run.id)}`,{signal:controller.signal,cache:'no-store'});data=await response.json();if(!response.ok)throw new Error(data.error?.message||'No se pudo consultar el recorrido.');}
      if(controller.signal.aborted||!host.isConnected)return;
      if(!data.available){host.innerHTML=`<div class="replay-empty"><img src="assets/levels/level_${Number(run.level)}.png" alt="Vista del nivel"><div><h3>Sin recorrido registrado</h3><p>${esc(data.reason)}</p><p class="subtle">El mapa animado estará disponible para las partidas nuevas. No se reconstruyen posiciones que no se guardaron.</p></div></div>`;return;}
      const frames=data.frames,map=data.metadata.map;
      if(!frames?.length||!map?.floors?.length)throw new Error('El recorrido no contiene un mapa válido.');
      let cursor=frames[0].t,playing=false,speed=1,last=0,lastDraw=0,lastLegend=-1;
      const end=frames.at(-1).t;
      host.innerHTML=`${demoMode?'<p class="replay-demo">RECORRIDO FICTICIO · Mapa ilustrativo de demostración.</p>':''}<div class="replay-layout"><div class="replay-map"><canvas aria-label="Mapa cenital del nivel: jugador verde con trazo y enemigos con nombre" role="img"></canvas><div class="replay-compass">N ↑</div></div><aside class="replay-legend"><span class="eyebrow">EN EL MAPA</span><p><i class="replay-player-dot"></i> Jugador y recorrido</p><p class="subtle">Gris: paredes y coberturas.<br>Ámbar: puertas cerradas.</p><h4>Enemigos presentes <span data-replay-count></span></h4><ul data-replay-enemies></ul></aside></div><div class="replay-controls"><button type="button" class="button primary" data-replay-play>▶ Reproducir</button><button type="button" class="button" data-replay-reset>↺ Reiniciar</button><label class="replay-speed">Velocidad <select data-replay-speed aria-label="Velocidad de reproducción"><option value=".5">0,5×</option><option value="1" selected>1×</option><option value="2">2×</option><option value="4">4×</option></select></label><output data-replay-time aria-live="off"></output><label class="replay-seek"><span class="sr-only">Momento de la reproducción</span><input type="range" min="0" max="${end}" step=".1" value="${cursor}" aria-label="Momento de la reproducción"></label></div><p class="replay-footnote">Vista desde arriba · Muestras cada ${data.metadata.intervalSeconds||.5} s · Tiempo activo sin pausas · Última muestra: ${time(end)}${run.outcome==='in_progress'?' · Actualiza para cargar el avance guardado.':''}. Los enemigos no dejan trazo. Los saltos de posición se muestran sin inventar trayectos.</p>`;
      const canvas=host.querySelector('canvas'),ctx=canvas.getContext('2d'),play=host.querySelector('[data-replay-play]'),seek=host.querySelector('input'),clock=host.querySelector('output');
      const allPoints=map.floors.flatMap(shape=>shape.points);
      const minX=Math.min(...allPoints.map(p=>p[0]))-2,maxX=Math.max(...allPoints.map(p=>p[0]))+2,minZ=Math.min(...allPoints.map(p=>p[1]))-2,maxZ=Math.max(...allPoints.map(p=>p[1]))+2;
      const color=kind=>['#dfb17a','#baabd9','#9cbed7','#e29c9c'][kind%4];
      function draw() {
        const box=canvas.getBoundingClientRect(),w=box.width,h=box.height,dpr=Math.min(window.devicePixelRatio||1,2);
        if(canvas.width!==Math.round(w*dpr)||canvas.height!==Math.round(h*dpr)){canvas.width=Math.round(w*dpr);canvas.height=Math.round(h*dpr);}
        ctx.setTransform(dpr,0,0,dpr,0,0);ctx.clearRect(0,0,w,h);
        const scale=Math.min((w-28)/(maxX-minX),(h-28)/(maxZ-minZ)),ox=(w-(maxX-minX)*scale)/2-minX*scale,oz=(h-(maxZ-minZ)*scale)/2-minZ*scale;
        const pos=p=>[p[0]*scale+ox,p[1]*scale+oz];
        function polygon(shape,fill,stroke){ctx.beginPath();shape.points.forEach((p,i)=>{const q=pos(p);i?ctx.lineTo(...q):ctx.moveTo(...q);});ctx.closePath();ctx.fillStyle=fill;ctx.fill();if(stroke){ctx.strokeStyle=stroke;ctx.lineWidth=1;ctx.stroke();}}
        map.floors.forEach(shape=>polygon(shape,'#1b2b34','#34505b'));
        (map.obstacles||[]).forEach(shape=>polygon(shape,'#52616a','#72818b'));
        const [index,a,b]=bracket(frames,cursor),fraction=b.t>a.t&&b.t-a.t<=2?Math.max(0,Math.min(1,(cursor-a.t)/(b.t-a.t))):0;
        (map.doors||[]).forEach(door=>{if(a.closedDoors?.includes(door.id))polygon(door,'#bd8848','#edbe7f');});
        ctx.strokeStyle='#91d7c4';ctx.lineWidth=2.1;ctx.lineJoin='round';ctx.beginPath();
        for(let i=0;i<=index;i++){const p=pos(frames[i].p),prev=frames[i-1];if(!prev||frames[i].t-prev.t>2||Math.hypot(frames[i].p[0]-prev.p[0],frames[i].p[1]-prev.p[1])>8)ctx.moveTo(...p);else ctx.lineTo(...p);}
        const player=pos(interpolate(a.p,b.p,fraction));ctx.lineTo(...player);ctx.stroke();
        const next=new Map(b.enemies.map(e=>[e.id,e]));
        a.enemies.forEach(enemy=>{const point=pos(next.has(enemy.id)?interpolate(enemy.p,next.get(enemy.id).p,fraction):enemy.p);ctx.fillStyle=color(enemy.kind);ctx.beginPath();ctx.arc(...point,enemy.boss?6:4,0,Math.PI*2);ctx.fill();ctx.font='10px Segoe UI';ctx.textAlign='center';ctx.strokeStyle='#091116';ctx.lineWidth=3;ctx.strokeText(name(enemy),point[0],point[1]-9);ctx.fillText(name(enemy),point[0],point[1]-9);});
        ctx.fillStyle='#91d7c4';ctx.strokeStyle='#091116';ctx.lineWidth=2;ctx.beginPath();ctx.arc(...player,5.5,0,Math.PI*2);ctx.fill();ctx.stroke();
        seek.value=cursor;clock.textContent=`${time(cursor)} / ${time(end)}`;seek.setAttribute('aria-valuetext',`${time(cursor)} de ${time(end)}`);
        if(lastLegend!==index){lastLegend=index;const counts=new Map();a.enemies.forEach(e=>counts.set(name(e),(counts.get(name(e))||0)+1));host.querySelector('[data-replay-count]').textContent=`(${a.enemies.length})`;host.querySelector('ul').innerHTML=[...counts].map(([label,n])=>`<li>${esc(label)} <b>×${n}</b></li>`).join('')||'<li>Sin enemigos presentes</li>';}
      }
      function setPlaying(value){cancelAnimationFrame(raf);playing=value;play.textContent=value?'Ⅱ Pausar':'▶ Reproducir';play.setAttribute('aria-pressed',String(value));last=0;if(value)raf=requestAnimationFrame(tick);}
      function tick(now){if(!host.isConnected||controller.signal.aborted){session.destroy();return;}if(!playing)return;if(last)cursor=Math.min(end,cursor+(now-last)/1000*speed);last=now;if(now-lastDraw>32){draw();lastDraw=now;}if(cursor>=end){draw();setPlaying(false);}else raf=requestAnimationFrame(tick);}
      play.addEventListener('click',()=>{if(cursor>=end)cursor=0;setPlaying(!playing);});
      host.querySelector('[data-replay-reset]').addEventListener('click',()=>{setPlaying(false);cancelAnimationFrame(raf);cursor=0;draw();});
      host.querySelector('select').addEventListener('change',event=>{speed=Number(event.target.value);});
      seek.addEventListener('input',()=>{cursor=Number(seek.value);draw();});
      observer=new ResizeObserver(draw);observer.observe(canvas);draw();
    }catch(error){if(error.name!=='AbortError'&&host.isConnected)host.innerHTML=`<p class="replay-status" role="status">${esc(error.message)} Vuelve a abrir el detalle para reintentar.</p>`;}
  }
  window.S07_REPLAY={markup,mount,stop(){active?.destroy();},bracket,interpolate};
})();
