/* Browser tests only: HTTP responses are intercepted, not a production server. */
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const vm = require('node:vm');
const {chromium} = require(process.env.SECTOR07_PLAYWRIGHT_MODULE || 'playwright');
const root=path.resolve(__dirname,'../..'),web=path.join(root,'web');
const screenshots=path.join(root,'.godot','test-results','capturas');
const errors=[];
async function main(){
  await fs.mkdir(screenshots,{recursive:true});
  const browser=await chromium.launch({channel:'msedge',headless:true});
  try{
    const page=await browser.newPage({viewport:{width:1440,height:1080},acceptDownloads:true});
    page.on('pageerror',error=>errors.push(error.message));
    const headings={overview:'Resumen de operaciones',players:'Archivo de jugadores',leaderboard:'Clasificación',history:'Historial de misiones',unlocks:'Equipo y descubrimientos',events:'Registro de eventos'};
    async function navigate(name){await page.locator(`nav a[data-page="${name}"]`).click();await page.getByRole('heading',{name:headings[name],exact:true}).waitFor();}

    const file=pathToFileURL(path.join(web,'index.html')).href;
    await page.goto(file);
    await page.getByRole('heading',{name:'Resumen de operaciones'}).waitFor();
    assert.match(await page.locator('#connection').innerText(),/Sin conexión/);
    assert.equal(await page.locator('.metric strong').first().innerText(),'—');
    assert.equal(await page.getByText('Piloto Atlas',{exact:true}).count(),0);
    await page.screenshot({path:path.join(screenshots,'web-offline.png'),fullPage:true});
    await page.getByRole('button',{name:'Ver demostración',exact:true}).click();
    assert.match(await page.locator('#notice').innerText(),/ficticios/);
    assert.equal(await page.locator('.metric strong').nth(1).innerText(),'28');
    await page.screenshot({path:path.join(screenshots,'web-overview.png'),fullPage:true});
    await navigate('players');
    await page.locator('.player-card').first().waitFor();
    assert.equal(await page.locator('.player-card').count(),4);
    await page.locator('#search').pressSequentially('nova');
    assert.equal(await page.locator('.player-card').count(),1);
    assert.equal(await page.locator('#search').inputValue(),'nova');
    await page.getByRole('button',{name:'Ver archivo ↗'}).click();
    await page.locator('#detail-dialog[open]').waitFor();
    assert.equal(await page.locator('#detail-title').innerText(),'Nova');
    await page.keyboard.press('Escape');
    assert.equal(await page.locator('#detail-dialog[open]').count(),0);
    await page.locator('#search').fill('no-such-player');
    await page.getByRole('heading',{name:'No se encontraron jugadores'}).waitFor();
    await page.getByRole('button',{name:'Limpiar filtros'}).click();
    await page.screenshot({path:path.join(screenshots,'web-players.png'),fullPage:true});
    await navigate('leaderboard');
    await page.locator('.podium-card').first().waitFor();
    assert.match(await page.locator('.podium-card').first().innerText(),/Piloto Atlas/);
    await page.locator('#sort-filter').selectOption('progress');
    assert.match(await page.locator('.podium-card').first().innerText(),/10 NIVELES/);
    await page.screenshot({path:path.join(screenshots,'web-leaderboard.png'),fullPage:true});
    await page.locator('#search').fill('Nova');
    assert.equal(await page.locator('tbody .rank').innerText(),'02','Filtering preserves the global rank');
    await page.getByRole('button',{name:'Limpiar filtros'}).click();
    await navigate('history');
    await page.locator('tbody tr').first().waitFor();
    assert.equal(await page.locator('tbody tr').count(),8);
    await page.getByRole('button',{name:'Siguiente →',exact:true}).click();
    assert.match(await page.locator('.pagination').innerText(),/9–16 de 28/);
    const downloadPromise=page.waitForEvent('download');
    await page.getByRole('button',{name:'Exportar CSV'}).click();
    const download=await downloadPromise;
    assert.match(download.suggestedFilename(),/demostracion-partidas/);
    const chunks=[];
    for await(const chunk of await download.createReadStream())chunks.push(chunk);
    const csv=Buffer.concat(chunks).toString('utf8');
    assert.equal(csv.split('\r\n').length,29);
    await page.locator('#difficulty-filter').selectOption('0');
    assert.equal(await page.locator('tbody tr .difficulty').filter({hasText:'Fácil'}).count(),8);
    await page.locator('#outcome-filter').selectOption('defeat');
    assert.equal(await page.locator('tbody tr').count(),2);
    await navigate('overview');
    assert.equal(await page.locator('.metric strong').nth(1).innerText(),'28','History-only filters do not silently change overview totals');
    await navigate('history');
    await page.getByRole('button',{name:'Limpiar filtros'}).click();
    await page.locator('tbody tr button[data-run]').first().click();
    await page.locator('#detail-dialog[open]').waitFor();
    assert.match(await page.locator('#detail-content').innerText(),/Acciones de esta misión/);
    await page.screenshot({path:path.join(screenshots,'web-run-detail.png')});
    await page.getByRole('button',{name:'Cerrar detalle'}).click();
    await page.locator('#player-filter').selectOption('vega');
    await page.screenshot({path:path.join(screenshots,'web-history.png'),fullPage:true});
    await navigate('unlocks');
    await page.locator('.equipment-card').first().waitFor();
    assert.equal(await page.locator('.equipment-card').count(),6);
    assert.equal(await page.locator('.equipment-card.locked').count(),2);
    assert.equal(await page.locator('.level-card').count(),10);
    assert.equal(await page.locator('.enemy-card').count(),18);
    assert.equal(await page.locator('.enemy-card:not(.locked) .enemy-height').count(),10);
    await page.locator('.enemy-card').last().scrollIntoViewIfNeeded();
    await page.evaluate(async()=>{const images=[...document.querySelectorAll('#content img')];images.forEach(img=>img.loading='eager');await Promise.all(images.map(img=>img.complete?(img.naturalWidth?Promise.resolve():Promise.reject(new Error('Broken image '+img.src))):new Promise((resolve,reject)=>{img.onload=resolve;img.onerror=()=>reject(new Error('Broken image '+img.src));})));});
    await page.evaluate(()=>scrollTo(0,0));
    await page.screenshot({path:path.join(screenshots,'web-unlocks.png'),fullPage:true});
    await navigate('events');
    await page.locator('#event-filter').selectOption('weapon_found');
    await page.locator('tbody tr').first().waitFor();
    await page.getByRole('button',{name:'Ver detalle ↗',exact:true}).first().click();
    assert.match(await page.locator('#detail-content').innerText(),/shotgun/);
    await page.keyboard.press('Escape');
    await page.screenshot({path:path.join(screenshots,'web-events.png'),fullPage:true});
    await page.getByRole('button',{name:'Salir de demostración'}).click();
    assert.match(await page.locator('#connection').innerText(),/Sin conexión/);
    assert.equal(await page.locator('tbody tr').count(),0);
    await page.getByRole('button',{name:'Ver demostración',exact:true}).click();
    // Exercise every page at narrow widths, including all dropdowns.
    for(const width of [390,760]){
      await page.setViewportSize({width,height:844});
      for(const name of ['overview','players','leaderboard','history','unlocks','events']){
        await page.goto(file+'?demo=1#'+name);
        await page.getByRole('heading',{name:{overview:'Resumen de operaciones',players:'Archivo de jugadores',leaderboard:'Clasificación',history:'Historial de misiones',unlocks:'Equipo y descubrimientos',events:'Registro de eventos'}[name],exact:true}).waitFor();
        if(name==='unlocks')await page.locator('#player-filter').selectOption('vega');
        const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1);
        assert.equal(overflow,false,`${name} must not overflow at ${width}px`);
        if(width===390&&['overview','history','unlocks'].includes(name))await page.screenshot({path:path.join(screenshots,`web-mobile-${name}.png`),fullPage:true});
      }
    }
    // Validate the future API adapter with browser interception; no service installed.
    const sandbox={window:{}};
    vm.runInNewContext(await fs.readFile(path.join(web,'demo.js'),'utf8'),sandbox);
    let payload=JSON.parse(JSON.stringify(sandbox.window.S07_DEMO()));
    payload.capabilities.events=false;payload.events=[];
    payload.players[0].name='<img src=x onerror="window.bad=true">';
    let status=200;
    await page.route('http://sector07.test/**',async route=>{
      const pathname=new URL(route.request().url()).pathname;
      if(pathname==='/api/dashboard')return route.fulfill({status,contentType:'application/json',body:JSON.stringify(payload)});
      const target=path.resolve(web,'.'+(pathname==='/'?'/index.html':decodeURIComponent(pathname)));
      if(!target.startsWith(web+path.sep))return route.fulfill({status:403,body:''});
      try{const body=await fs.readFile(target);const type={'.html':'text/html','.css':'text/css','.js':'application/javascript','.png':'image/png','.svg':'image/svg+xml'}[path.extname(target)]||'application/octet-stream';return route.fulfill({contentType:type,body});}catch{return route.fulfill({status:404,body:''});}
    });
    await page.setViewportSize({width:1440,height:1080});
    await page.goto('http://sector07.test/#players');
    await page.waitForFunction(()=>document.querySelector('#connection').textContent.includes('Datos conectados'));
    assert.equal(await page.locator('.player-card h2').first().innerText(),payload.players[0].name);
    assert.equal(await page.evaluate(()=>Boolean(window.bad)),false);
    await navigate('events');
    await page.getByRole('heading',{name:'Registro detallado pendiente',exact:true}).waitFor();
    assert.equal(await page.locator('tbody tr').count(),0);
    status=503;
    await page.getByRole('button',{name:'Actualizar',exact:true}).click();
    await page.waitForFunction(()=>document.querySelector('#connection').textContent.includes('Sin conexión'));
    assert.equal(await page.getByText('Piloto Atlas',{exact:true}).count(),0,'No demo fallback after an API error');
    status=200;payload={schemaVersion:999};
    await page.getByRole('button',{name:'Actualizar',exact:true}).click();
    await page.waitForFunction(()=>!document.querySelector('#refresh').disabled);
    assert.match(await page.locator('#connection').innerText(),/Sin conexión/);
    assert.deepEqual(errors,[],'No uncaught browser errors');
    console.log('WEB UI PASS: six pages, offline/demo separation, filters, ranking, details, CSV, mobile, API failures and escaped names');
  }finally{await browser.close();}
}
main().catch(error=>{console.error(error);process.exitCode=1;});
