const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const {chromium} = require(process.env.SECTOR07_PLAYWRIGHT_MODULE || 'playwright');
const root = path.resolve(__dirname,'../..');
async function run() {
  const browser = await chromium.launch({channel:'msedge',headless:true});
  const errors = [];
  try {
    const page = await browser.newPage({viewport:{width:1440,height:1080}});
    page.on('pageerror',error=>errors.push(error.message));
    await page.goto(pathToFileURL(path.join(root,'web/index.html')).href);
    await page.locator('[data-sector-mode]').waitFor();
    assert.equal(await page.locator('.sector-value').first().innerText(),'—');
    await page.getByRole('button',{name:'Ver demostración',exact:true}).click();
    await page.getByRole('combobox',{name:'Mostrar actividad por sector',exact:true}).selectOption('difficulty');
    assert.equal(await page.locator('.sector-bar').count(),10);
    const expected = await page.evaluate(()=>window.S07_SECTORS.calculate(window.S07_DEMO()).map(row=>({defeats:row.defeats,rate:row.rate})));
    assert.deepEqual(await page.locator('.sector-value').allTextContents(),expected.map(row=>String(row.defeats)));
    await page.getByRole('combobox',{name:'Medida de derrotas',exact:true}).selectOption('rate');
    assert.deepEqual(await page.locator('.sector-value').allTextContents(),expected.map(row=>row.rate===null?'—':new Intl.NumberFormat('es-MX',{maximumFractionDigits:1}).format(row.rate)+'%'));
    assert.match(await page.locator('.sector-explanation').innerText(),/excluye abandonos/);
    assert.match(await page.locator('.sector-explanation').innerText(),/fallos por tiempo u objetivos/);
    await page.locator('#player-filter').selectOption('echo');
    assert.equal(await page.locator('[data-sector-mode]').inputValue(),'difficulty');
    assert.equal(await page.locator('[data-sector-measure]').inputValue(),'rate');
    const filtered = await page.evaluate(()=>window.S07_SECTORS.calculate(window.S07_DEMO(),{playerId:'echo'}).map(row=>row.rate));
    assert.deepEqual(await page.locator('.sector-value').allTextContents(),filtered.map(rate=>rate===null?'—':new Intl.NumberFormat('es-MX',{maximumFractionDigits:1}).format(rate)+'%'));
    await fs.mkdir(path.join(root,'.godot/test-results/capturas'),{recursive:true});
    await page.locator('[data-sector-stats]').screenshot({path:path.join(root,'.godot/test-results/capturas/sector-defeats-desktop.png')});
    await page.setViewportSize({width:390,height:844});
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),true,'Chart controls do not overflow on mobile');
    await page.locator('[data-sector-stats]').screenshot({path:path.join(root,'.godot/test-results/capturas/sector-defeats-mobile.png')});
    await page.locator('[data-sector-mode]').selectOption('time');
    assert.equal(await page.locator('[data-sector-measure]').count(),0);
    assert.match(await page.locator('.sector-explanation').innerText(),/tiempo activo/);
    assert.deepEqual(errors,[]);
    console.log('SECTOR STATS UI: selectors, values, profile scope, mode persistence, responsive layout and no page errors PASS');
  } finally {await browser.close();}
}
run().catch(error=>{console.error(error);process.exitCode=1;});
