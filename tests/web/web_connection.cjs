/* Browser -> actual HTTP server -> SQLite. Fixtures are separate from real saves. */
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { chromium } = require(process.env.SECTOR07_PLAYWRIGHT_MODULE || 'playwright');
const root = path.resolve(__dirname, '../..');

async function main() {
  const { createServer, readDashboard, defaultDatabase } = await import(pathToFileURL(path.join(root, 'web/server.mjs')));
  const { createFixture } = await import(pathToFileURL(path.join(root, 'tests/web/web_server.mjs')));
  const real = process.argv.includes('--real');
  const fixture = path.join(root, '.godot', 'web-server-tests', `browser-${process.pid}.sqlite`);
  const databasePath = real ? defaultDatabase() : fixture;
  let writer, server, browser;
  const errors = [];
  try {
    if (!real) writer = createFixture(fixture);
    const data = readDashboard(databasePath);
    const originalFile = real ? await fs.readFile(databasePath) : null;
    server = createServer({ databasePath });
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    const url = `http://127.0.0.1:${server.address().port}`;
    browser = await chromium.launch({ channel: 'msedge', headless: true });
    const page = await browser.newPage({ viewport: { width: 1440, height: 1080 }, acceptDownloads: true });
    page.on('pageerror', error => errors.push(error.message));
    async function navigate(name) {
      await page.locator(`[data-page=${name}]`).click();
      await page.locator(`[data-page=${name}][aria-current]`).waitFor({ state: 'attached' });
    }
    await page.goto(url);
    await page.waitForFunction(() => document.querySelector('#connection').textContent.includes('Datos conectados'));
    assert.equal(await page.locator('.metric strong').first().innerText(), String(data.players.length));
    assert.equal(await page.locator('.metric strong').nth(1).innerText(), String(data.runs.length));
    await fs.mkdir(path.join(root, '.godot/test-results/capturas'), { recursive: true });
    await page.screenshot({ path: path.join(root, `.godot/test-results/capturas/web-connected-${real ? 'real' : 'fixture'}.png`), fullPage: true });
    await navigate('players');
    assert.equal(await page.locator('.player-card').count(), data.players.length);
    if (real) {
      for (const player of data.players) assert.ok((await page.locator('.player-card h2').allTextContents()).includes(player.name));
      await navigate('events');
      if (data.events.length) {
        assert.equal(await page.locator('tbody tr').count(), Math.min(8, data.events.length));
        await page.locator('[data-event]').first().click();
        await page.locator('#detail-dialog[open]').waitFor();
        await page.keyboard.press('Escape');
      }
      await page.screenshot({ path: path.join(root, '.godot/test-results/capturas/web-connected-real-events.png'), fullPage: true });
      assert.deepEqual(await fs.readFile(databasePath), originalFile, 'Browser consults the real save without changing its bytes');
    } else {
      await navigate('history');
      assert.equal(await page.locator('tbody tr').count(), 3);
      assert.equal(await page.locator('.badge.in_progress').innerText(), 'En curso');
      assert.equal(await page.locator('.badge.interrupted').innerText(), 'Interrumpida');
      await page.locator('[data-run=playing]').click();
      await page.locator('#detail-dialog[open]').waitFor();
      assert.match(await page.locator('#detail-content').innerText(), /Sin cierre · último estado guardado/);
      assert.equal(await page.locator('#detail-content .metric strong').first().innerText(), '—');
      await page.keyboard.press('Escape');
      await navigate('overview');
      assert.equal(await page.locator('.donut-label strong').innerText(), '100%', 'Open/interrupted attempts do not lower the win ratio');
      await navigate('events');
      assert.equal(await page.locator('tbody tr').count(), 5);
      await page.locator('#event-filter').selectOption('shot_fired');
      assert.equal(await page.locator('tbody tr').count(), 1);
      await page.locator('[data-event]').click();
      assert.match(await page.locator('#detail-content').innerText(), /Orden en el intento\s+2/);
      assert.match(await page.locator('#detail-content').innerText(), /Balas en cargador\s+23/);
      await page.keyboard.press('Escape');
      await page.getByRole('button', { name: 'Limpiar filtros' }).click();
      await page.locator('#player-filter').selectOption('__system__');
      assert.equal(await page.locator('tbody tr').count(), 1);
      assert.match(await page.locator('tbody').innerText(), /Configuración modificada/);
      assert.match(await page.locator('tbody').innerText(), /Menú \/ configuración/);
      await page.getByRole('button', { name: 'Actualizar', exact: true }).click();
      await page.waitForFunction(() => !document.querySelector('#refresh').disabled);
      assert.equal(await page.locator('#player-filter').inputValue(), '__system__');
      const downloading = page.waitForEvent('download');
      await page.getByRole('button', { name: 'Exportar CSV' }).click();
      const download = await downloading, chunks = [];
      for await (const chunk of await download.createReadStream()) chunks.push(chunk);
      const csv = Buffer.concat(chunks).toString('utf8');
      assert.match(csv, /Configuración general/);
      assert.match(csv, /brightness/);
      assert.equal(csv.split('\r\n').length, 2);
      assert.doesNotMatch(download.suggestedFilename(), /demostracion/);
      await navigate('players');
      assert.equal(await page.locator('.player-card').count(), 2, 'Leaving system filter restores regular player sections');
      writer.exec("UPDATE profiles SET record=1400,display_name='<img src=x onerror=window.bad=true>' WHERE id='alpha'");
      await page.getByRole('button', { name: 'Actualizar', exact: true }).click();
      await page.waitForFunction(() => !document.querySelector('#refresh').disabled);
      assert.equal(await page.locator('.player-card h2').first().innerText(), '<img src=x onerror=window.bad=true>');
      assert.equal(await page.evaluate(() => Boolean(window.bad)), false);
      assert.match(await page.locator('.player-record').first().innerText(), /1,400/);
      for (const width of [390, 760]) {
        await page.setViewportSize({ width, height: 900 });
        for (const name of ['overview', 'history', 'events']) {
          await navigate(name);
          assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 1), false, `${name} at ${width}px`);
        }
      }
      await page.screenshot({ path: path.join(root, '.godot/test-results/capturas/web-connected-mobile-events.png'), fullPage: true });
      writer.exec("INSERT INTO history_archive VALUES('alpha',1,'victory',10,100,20)");
      writer.exec('BEGIN');
      const extraRun=writer.prepare('INSERT INTO run_history VALUES(?,?,?,?,?,?,?,?,?,?)');
      for(let i=0;i<400;i++) extraRun.run(`limit-run-${i}`,'alpha',1,1,'victory',1,1,1,new Date(1900000000000+i*1000).toISOString(),new Date(1900000000000+i*1000).toISOString());
      const extraEvent=writer.prepare('INSERT INTO profile_events VALUES(?,?,?,?,?)');
      for(let i=0;i<2405;i++) extraEvent.run(`limit-event-${i}`,'alpha','profile_selected',new Date(1900000000000+i*1000).toISOString(),'{}');
      writer.exec('COMMIT');
      await page.getByRole('button',{name:'Actualizar',exact:true}).click();
      await page.waitForFunction(()=>!document.querySelector('#refresh').disabled);
      await page.locator('#player-filter').selectOption('uuid-alpha');
      assert.match(await page.locator('.pagination').innerText(),/1 \/ 300/,'300 pages of events per player');
      await navigate('history');
      assert.match(await page.locator('.pagination').innerText(),/1 \/ 50/,'50 pages of attempts per player');
      await navigate('overview');
      assert.equal(await page.locator('.metric strong').nth(1).innerText(),'412','Lifetime attempt totals survive detail limits');
      assert.equal(await page.locator('.metric strong').nth(2).innerText(),'8 min 43 s','Lifetime play time survives pruning');
      writer.exec('PRAGMA user_version=999');
      await page.getByRole('button', { name: 'Actualizar', exact: true }).click();
      await page.waitForFunction(() => document.querySelector('#connection').textContent.includes('Sin conexión'));
      assert.match(await page.locator('#notice').innerText(), /versión de la base no es compatible/);
      assert.equal(await page.locator('tbody tr').count(), 0, 'No fake fallback or stale rows after failed database reads');
      writer.exec('PRAGMA user_version=2');
    }
    assert.deepEqual(errors, []);
    console.log(`WEB CONNECTION PASS (${real ? 'real read-only save' : 'private fixture'}): HTTP/SQLite/browser, correct metrics, event links, statuses, filters, details, refresh, CSV and escaped data`);
  } finally {
    await browser?.close();
    if (server) await new Promise(resolve => server.close(resolve));
    writer?.close();
    if (!real) for (const suffix of ['', '-journal', '-wal', '-shm']) {
      try { await fs.unlink(fixture + suffix); } catch (error) { if (error.code !== 'ENOENT') throw error; }
    }
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
