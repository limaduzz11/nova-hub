const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { spawn } = require('node:child_process');
const { chromium } = require('playwright');

const PORT = 3101;
const URL = `http://127.0.0.1:${PORT}`;

async function waitForHealth() {
  const deadline = Date.now() + 15000;
  while (Date.now() < deadline) {
    try { if ((await fetch(`${URL}/healthz`)).status < 500) return; } catch {}
    await new Promise(resolve => setTimeout(resolve, 150));
  }
  throw new Error('Servidor isolado do teste Cortex não iniciou');
}

async function sample(page, label) {
  const diagnostic = await page.evaluate(() => CortexModule.diagnostics());
  assert(diagnostic.totalNodes >= 1400, `${label}: dataset total incompleto`);
  assert(diagnostic.visibleNodes > 500, `${label}: poucos nós conectados visíveis`);
  assert.equal(diagnostic.visibleNodes, diagnostic.totalNodes, `${label}: preferência de exibir órfãos não foi mantida`);
  assert.equal(diagnostic.finiteNodes, diagnostic.visibleNodes, `${label}: coordenadas NaN/Infinity`);
  assert.equal(diagnostic.animationRunning, true, `${label}: animação contínua do Cortex foi interrompida`);
  const painted = await page.locator('#cortexCanvas').evaluate(canvas => {
    const context = canvas.getContext('2d');
    const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
    let count = 0;
    for (let index = 3; index < pixels.length; index += 64) if (pixels[index] > 0) count++;
    return count;
  });
  assert(painted > 150, `${label}: canvas visualmente vazio`);
  return diagnostic;
}

(async () => {
  const password = crypto.randomBytes(18).toString('hex');
  const server = spawn(process.execPath, ['server.js'], {
    cwd: process.cwd(),
    env: { ...process.env, NOVA_WEB_PORT: String(PORT), LOCAL_AUTH_USERS: `cortex-test:${password}` },
    stdio: 'ignore',
  });
  let browser;
  try {
    await waitForHealth();
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
    await page.goto(URL);
    await page.locator('#username').fill('cortex-test');
    await page.locator('#password').fill(password);
    await page.locator('#loginBtn').click();
    await page.getByRole('heading', { name: 'NOVA Link' }).waitFor();
    await page.locator('[data-module="cortex"]').click();
    await page.locator('#cortexStats').filter({ hasText: /1\d{3} nós/ }).waitFor({ timeout: 30000 });

    await page.waitForTimeout(5000); let previousDiagnostic = await sample(page, '5s');
    await page.waitForTimeout(25000); let currentDiagnostic = await sample(page, '30s');
    assert(currentDiagnostic.frameCount > previousDiagnostic.frameCount, '30s: frames do Cortex não avançaram');
    previousDiagnostic = currentDiagnostic;
    await page.waitForTimeout(60000); currentDiagnostic = await sample(page, '90s');
    assert(currentDiagnostic.frameCount > previousDiagnostic.frameCount, '90s: frames do Cortex não avançaram');
    previousDiagnostic = currentDiagnostic;
    await page.waitForTimeout(90000); const finalDiagnostic = await sample(page, '180s');
    assert(finalDiagnostic.frameCount > previousDiagnostic.frameCount, '180s: frames do Cortex não avançaram');

    const canvas = page.locator('#cortexCanvas');
    await canvas.hover();
    await page.mouse.wheel(0, -420);
    const box = await canvas.boundingBox();
    await page.mouse.move(box.x + box.width * .55, box.y + box.height * .55);
    await page.mouse.down(); await page.mouse.move(box.x + box.width * .62, box.y + box.height * .6); await page.mouse.up();
    await sample(page, 'zoom-pan');

    await page.locator('#cortexFit').click();
    const clickTarget = await page.evaluate(() => CortexModule.diagnostics().firstNode);
    assert(clickTarget, 'Nenhum nó disponível para teste de clique');
    await page.mouse.click(clickTarget.x, clickTarget.y);
    await page.locator('#cortexNodeDetail').waitFor({ state: 'visible' });
    await page.locator('#cortexDetailClose').click();

    await page.locator('#cortexFiltersToggle').click();
    await page.locator('#cortexShowOrphans').uncheck();
    await page.waitForFunction(() => CortexModule.diagnostics().visibleNodes < CortexModule.diagnostics().totalNodes);
    await page.locator('#cortexShowOrphans').check();
    await page.waitForFunction(() => CortexModule.diagnostics().visibleNodes === CortexModule.diagnostics().totalNodes);

    await page.locator('[data-module="settings"]').click();
    await page.locator('[data-module="cortex"]').click();
    await page.locator('#cortexStats').filter({ hasText: /1\d{3} nós/ }).waitFor({ timeout: 30000 });
    await page.locator('#cortexRefresh').click();
    await page.locator('#cortexStats').filter({ hasText: /1\d{3} nós/ }).waitFor({ timeout: 30000 });
    await page.waitForTimeout(10000);
    await sample(page, 'retorno-refresh');
    console.log(`CORTEX_STABILITY_OK 180s | ${finalDiagnostic.visibleNodes}/${finalDiagnostic.totalNodes} nós | ${finalDiagnostic.visibleEdges}/${finalDiagnostic.totalEdges} arestas`);
  } finally {
    if (browser) await browser.close().catch(() => {});
    server.kill('SIGTERM');
  }
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
