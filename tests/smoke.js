const assert = require('node:assert/strict');
const { chromium } = require('playwright');
const { registerAuthMock, registerMoonlightMock, registerNexusMock } = require('./fixtures/nexus-mock');

const BASE_URL = process.env.NOVA_WEB_TEST_URL || 'http://127.0.0.1:3001';
let browser;
let cleanupItemId = null;

async function main() {
  browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 } });
  const page = await context.newPage();
  const consoleErrors = [];
  const failedRequests = [];

  page.on('console', message => {
    if (message.type() === 'error' && !message.text().startsWith('Failed to load resource:')) {
      consoleErrors.push(message.text());
    }
  });
  page.on('requestfailed', request => {
    if (request.url().startsWith(BASE_URL)) {
      failedRequests.push(`${request.method()} ${request.url()} ${request.failure()?.errorText || ''}`);
    }
  });

  await page.goto(BASE_URL, { waitUntil: 'networkidle' });
  await page.locator('.login-card').waitFor({ state: 'visible' });
  const bodyBg = await page.locator('body').evaluate(el => getComputedStyle(el).backgroundColor);
  assert.notEqual(bodyBg, 'rgba(0, 0, 0, 0)', 'CSS não foi aplicado ao body');
  assert.equal(await page.locator('.login-brand-mark').evaluate(img => img.naturalWidth > 0), true);
  await page.screenshot({ path: 'test-results/login.png', fullPage: true });

  await registerAuthMock(page, 'validation');
  let interceptedPowerOff = 0;
  await registerNexusMock(page, { onPowerOff: () => { interceptedPowerOff++; } });
  await page.route('**/web-api/nexus/api/igdb/search**', route => {
    const query = new URL(route.request().url()).searchParams.get('q');
    if (query === 'offline') {
      return route.fulfill({
        status: 502,
        contentType: 'application/json',
        body: JSON.stringify({ error: 'IGDB externa indisponível' }),
      });
    }
    return route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([{
        id: 987654321,
        name: 'The Legend of Zelda — Smoke Fixture',
        cover_id: '',
        rating: 92,
        release_date: 757382400,
        platforms: ['Nintendo Switch'],
        genres: ['Adventure'],
        summary: 'Fixture determinística para validar a interface sem depender da conectividade externa da IGDB.',
      }]),
    });
  });
  await page.route('**/web-api/nexus/api/news', route => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({ items: [{
      title: 'Arcadia smoke news',
      source: 'NOVA Validation',
      summary: 'Notícia determinística para o teste da interface.',
      link: 'https://example.com/arcadia-smoke',
      published: '2026-08-03T12:00:00Z',
      lang: 'pt-BR',
    }] }),
  }));
  await registerMoonlightMock(page);

  await page.reload({ waitUntil: 'networkidle' });
  await page.getByRole('heading', { name: 'NOVA Link' }).waitFor();
  await page.getByText('Online', { exact: true }).waitFor({ timeout: 15000 });
  page.once('dialog', dialog => dialog.accept());
  await page.locator('#powerOffBtn').click();
  await page.getByText('Comando de desligamento enviado.', { exact: true }).waitFor();
  assert.equal(interceptedPowerOff, 1, 'Desligamento não foi interceptado com segurança');
  await page.screenshot({ path: 'test-results/link.png', fullPage: true });

  await page.locator('[data-module="nexus"]').click();
  await page.getByRole('heading', { name: 'NOVA Nexus' }).waitFor();
  await page.waitForFunction(() => document.querySelectorAll('#wsSelector option').length > 0);
  const workspaceNames = await page.locator('#wsSelector option').allTextContents();
  assert(workspaceNames.includes('Work'), 'Workspace Work não apareceu no Nexus');
  await page.locator('#wsSelector').selectOption({ label: 'Work' });
  await page.locator('.nexus-item').first().waitFor({ timeout: 15000 });
  const firstNexusTitle = (await page.locator('.nexus-item-title').first().textContent()).trim();
  assert(firstNexusTitle.length > 4, 'Título da primeira tarefa Nexus está vazio');

  await page.locator('.nexus-item').first().click();
  await page.locator('#nexusEditDialog').waitFor({ state: 'visible' });
  assert.equal(await page.locator('#editTaskTitleInput').inputValue(), firstNexusTitle);
  await page.locator('#nexusEditDialog [data-close-dialog="nexusEditDialog"]').first().click();

  await page.locator('#nexusSearch').fill(firstNexusTitle.slice(0, 12));
  await page.locator('#nexusResultSummary').filter({ hasText: /\d+ de \d+ itens/ }).waitFor();
  assert((await page.locator('.nexus-item').count()) >= 1, 'Busca Nexus não retornou a tarefa conhecida');
  await page.screenshot({ path: 'test-results/nexus-search.png', fullPage: true });
  await page.locator('#nexusClearFilters').click();

  await page.locator('.nexus-filter-chip[data-status="todo"]').click();
  await page.waitForFunction(() => document.querySelectorAll('[data-column-status]').length === 1);
  assert.equal(await page.locator('[data-column-status="todo"]').count(), 1, 'Filtro de status Nexus não restringiu o board');
  await page.locator('.nexus-filter-chip[data-status="todo"]').click();
  await page.waitForFunction(() => document.querySelectorAll('[data-column-status]').length === 4);

  const temporaryTitle = `[UI-SMOKE-${Date.now()}] Validação temporária`;
  await page.locator('#nexusCreate').click();
  await page.locator('#nexusCreateDialog').waitFor({ state: 'visible' });
  await page.locator('#newTaskTitle').fill(temporaryTitle);
  await page.locator('#newTaskBody').fill('Item temporário criado pelo smoke test e removido ao final.');
  await page.locator('#newTaskTags').fill('ui-smoke, temporario');
  await page.locator('#confirmCreate').click();
  const temporaryCard = page.locator('.nexus-item', { hasText: temporaryTitle }).first();
  await temporaryCard.waitFor({ timeout: 15000 });
  cleanupItemId = await temporaryCard.getAttribute('data-id');
  assert(cleanupItemId, 'Tarefa temporária não expôs ID para cleanup');
  await temporaryCard.locator('.nexus-status-select').selectOption('doing');
  const movedTemporaryCard = page.locator(`.nexus-item[data-id="${cleanupItemId}"]`);
  await movedTemporaryCard.waitFor({ timeout: 15000 });
  assert.equal(await movedTemporaryCard.locator('.nexus-status-select').inputValue(), 'doing', 'Mudança de status temporária não persistiu');
  page.once('dialog', dialog => dialog.accept());
  await movedTemporaryCard.locator('.nexus-delete-btn').click();
  await movedTemporaryCard.waitFor({ state: 'detached', timeout: 15000 });
  cleanupItemId = null;

  await page.locator('#nexusExport').click();
  await page.locator('#nexusExportDialog').waitFor({ state: 'visible' });
  await page.screenshot({ path: 'test-results/nexus-export.png', fullPage: true });
  const downloadPromise = page.waitForEvent('download', { timeout: 30000 });
  await page.locator('#confirmExport').click();
  const exportDownload = await downloadPromise;
  assert.match(exportDownload.suggestedFilename(), /^nexus-.*\.png$/, 'Exportação Nexus não gerou PNG');
  await exportDownload.saveAs('test-results/nexus-export-report.png');
  await page.evaluate(() => {
    window.__novaPrintCalled = false;
    window.print = () => {
      window.__novaPrintCalled = true;
      window.dispatchEvent(new Event('afterprint'));
    };
  });
  await page.locator('#nexusExport').click();
  await page.locator('#nexusExportFormat').selectOption('pdf');
  await page.locator('#confirmExport').click();
  await page.waitForFunction(() => window.__novaPrintCalled === true);
  assert.equal(await page.locator('#nexusPrintReport').count(), 0, 'Relatório de impressão não foi limpo após o print');
  await page.screenshot({ path: 'test-results/nexus.png', fullPage: true });

  await page.locator('[data-module="arcadia"]').click();
  await page.getByRole('heading', { name: 'NOVA Arcadia' }).waitFor();
  await page.locator('.arcadia-game-card').first().waitFor({ timeout: 15000 });
  const libraryGameTitle = (await page.locator('.arcadia-game-card strong').first().textContent()).trim();
  await page.locator('.arcadia-game-card').first().click();
  await page.locator('#arcadiaLibraryDialog').waitFor({ state: 'visible' });
  assert.equal((await page.locator('#arcadiaLibraryDetail h4').textContent()).trim(), libraryGameTitle, 'Detalhe Arcadia abriu jogo incorreto');
  assert.equal(await page.locator('#arcadiaEditStatus').count(), 1, 'Editor Arcadia não exibiu status');
  assert.equal(await page.locator('#arcadiaEditNotes').count(), 1, 'Editor Arcadia não exibiu notas');
  await page.screenshot({ path: 'test-results/arcadia-detail.png', fullPage: true });
  await page.locator('[data-close-dialog="arcadiaLibraryDialog"]').first().click();

  const libraryGameStatus = await page.locator('.arcadia-game-card').first().getAttribute('data-library-status');
  await page.locator(`[data-library-status="${libraryGameStatus}"]`).first().click();
  await page.locator('.arcadia-game-card').first().waitFor();
  await page.locator('[data-library-status="all"]').click();
  await page.locator('#searchGames').fill('zelda');
  await page.locator('.arcadia-add-btn').first().waitFor({ timeout: 10000 });
  await page.locator('.arcadia-add-btn').first().click();
  await page.locator('#arcadiaAddDialog').waitFor({ state: 'visible' });
  assert.match(await page.locator('#arcadiaAddGameName').textContent(), /Zelda/);
  await page.locator('[data-rating-target="add"][data-rating="4"]').click();
  assert.equal(await page.locator('#arcadiaAddRating span').textContent(), '4/5');
  await page.locator('[data-close-dialog="arcadiaAddDialog"]').first().click();
  await page.screenshot({ path: 'test-results/arcadia.png', fullPage: true });
  await page.locator('#searchGames').fill('offline');
  await page.getByText('IGDB temporariamente indisponível', { exact: true }).waitFor({ timeout: 10000 });
  assert.equal(await page.locator('.arcadia-game-card').count(), 1, 'Falha IGDB ocultou a biblioteca local');
  await page.screenshot({ path: 'test-results/arcadia-igdb-degraded.png', fullPage: true });

  await page.locator('[data-arcadia-tab="news"]').click();
  await page.locator('.arcadia-news-card').first().waitFor();
  assert.match(await page.locator('.arcadia-news-card').first().textContent(), /Arcadia smoke news/);
  await page.locator('#arcadiaNewsSearch').fill('conteúdo inexistente');
  await page.getByText('Nenhuma notícia encontrada', { exact: true }).waitFor();
  await page.locator('#arcadiaNewsSearch').fill('Arcadia');
  await page.locator('.arcadia-news-card').first().waitFor();
  await page.screenshot({ path: 'test-results/arcadia-news.png', fullPage: true });
  await page.locator('[data-arcadia-tab="moonlight"]').click();
  await page.getByText('Sunshine online', { exact: true }).waitFor();
  assert.equal(await page.locator('#copyMoonlightHost').getAttribute('data-copy-value'), 'pop-os');
  await page.screenshot({ path: 'test-results/arcadia-moonlight.png', fullPage: true });

  await page.locator('[data-module="cortex"]').click();
  await page.getByRole('heading', { name: 'NOVA Cortex' }).waitFor();
  await page.locator('#cortexStats').filter({ hasText: /\d+ nós/ }).waitFor({ timeout: 30000 });
  const cortexStats = await page.locator('#cortexStats').textContent();
  assert.match(cortexStats, /1\d{3} nós/, 'Cortex não carregou o grafo completo');
  assert.doesNotMatch(cortexStats, /órfãos ocultos/, 'Cortex WEB não respeitou a preferência de exibir órfãos');

  await page.locator('#cortexViewToggle').click();
  await page.locator('.cortex-list-item').first().waitFor({ timeout: 30000 });
  const firstNodeLabel = (await page.locator('.cortex-list-item strong').first().textContent()).trim();
  assert(firstNodeLabel.length > 0, 'Lista Cortex não exibiu rótulo de nó');
  await page.locator('.cortex-list-item').first().click();
  await page.locator('#cortexNodeDetail').waitFor({ state: 'visible' });
  assert.equal((await page.locator('#detailTitle').textContent()).trim(), firstNodeLabel, 'Detalhe Cortex não abriu o nó selecionado');
  await page.screenshot({ path: 'test-results/cortex-detail.png', fullPage: true });
  await page.locator('#cortexDetailClose').click();
  await page.locator('#cortexSearch').fill(firstNodeLabel.slice(0, 10));
  await page.locator('#cortexStats').filter({ hasText: /\d+\/\d+ nós/ }).waitFor();
  assert((await page.locator('.cortex-list-item').count()) >= 1, 'Busca Cortex não retornou o nó conhecido');
  await page.locator('#cortexSearch').fill('');

  await page.locator('#cortexFiltersToggle').click();
  await page.locator('.cortex-group-chip').first().waitFor();
  await page.locator('.cortex-group-chip').first().click();
  await page.locator('#cortexStats').filter({ hasText: /\d+\/\d+ nós/ }).waitFor();
  const originalNodeSize = await page.locator('[data-output="nodeSize"]').textContent();
  await page.locator('[data-physics="nodeSize"]').evaluate(input => {
    input.value = '1.5';
    input.dispatchEvent(new Event('input', { bubbles: true }));
  });
  assert.notEqual(await page.locator('[data-output="nodeSize"]').textContent(), originalNodeSize, 'Controle físico Cortex não atualizou');
  await page.locator('#mainContent').evaluate(element => { element.scrollTop = 0; });
  await page.screenshot({ path: 'test-results/cortex-controls.png', fullPage: true });
  await page.locator('#cortexClearFilters').click();
  await page.locator('#cortexViewToggle').click();
  await page.locator('#cortexCanvas').waitFor({ state: 'visible' });
  await page.locator('#cortexFit').click();
  await page.waitForTimeout(10000);
  const cortexCanvasHealth = await page.locator('#cortexCanvas').evaluate(canvas => ({
    visible: Number(canvas.dataset.visibleNodes || 0),
    finite: Number(canvas.dataset.finiteNodes || 0),
  }));
  assert(cortexCanvasHealth.visible > 500, 'Cortex exibiu poucos nós conectados');
  assert.equal(cortexCanvasHealth.finite, cortexCanvasHealth.visible, 'Cortex gerou coordenadas não finitas após a física');
  await page.screenshot({ path: 'test-results/cortex.png', fullPage: true });

  await page.locator('[data-module="settings"]').click();
  await page.getByRole('heading', { name: 'Settings' }).waitFor();
  await page.locator('#settingsNexusStatus').filter({ hasText: 'Online' }).waitFor({ timeout: 15000 });
  await page.locator('#settingsSunshineStatus').filter({ hasText: 'Online' }).waitFor();
  assert.equal(await page.locator('#settingsUsername').textContent(), 'validation', 'Settings não exibiu usuário da sessão');
  assert.equal(await page.locator('#settingsVersion').textContent(), '0.5.0');
  assert.equal(await page.locator('[data-module="settings"]').evaluate(element => element.classList.contains('active')), true, 'Navegação não marcou Settings como ativo');
  assert.equal(await page.locator('[data-module="cortex"]').evaluate(element => element.classList.contains('active')), false, 'Cortex permaneceu ativo ao abrir Settings');
  await page.screenshot({ path: 'test-results/settings.png', fullPage: true });

  await page.setViewportSize({ width: 390, height: 844 });
  await page.locator('[data-module="link"]').click();
  await page.getByRole('heading', { name: 'NOVA Link' }).waitFor();
  await page.getByText('Online', { exact: true }).waitFor({ timeout: 15000 });
  const dimensions = await page.evaluate(() => ({
    viewport: document.documentElement.clientWidth,
    content: document.documentElement.scrollWidth,
  }));
  assert(dimensions.content <= dimensions.viewport + 1, 'Layout móvel possui overflow horizontal');
  await page.screenshot({ path: 'test-results/mobile-link.png', fullPage: true });

  await page.locator('[data-module="nexus"]').click();
  await page.getByRole('heading', { name: 'NOVA Nexus' }).waitFor();
  await page.waitForFunction(() => document.querySelectorAll('#wsSelector option').length > 0);
  await page.locator('#wsSelector').selectOption({ label: 'Work' });
  await page.locator('.nexus-item').first().waitFor({ timeout: 15000 });
  const mobileNexusDimensions = await page.evaluate(() => ({
    viewport: document.documentElement.clientWidth,
    content: document.documentElement.scrollWidth,
  }));
  assert(mobileNexusDimensions.content <= mobileNexusDimensions.viewport + 1, 'Nexus móvel possui overflow horizontal');
  await page.screenshot({ path: 'test-results/mobile-nexus.png', fullPage: true });

  await page.locator('[data-module="arcadia"]').click();
  await page.getByRole('heading', { name: 'NOVA Arcadia' }).waitFor();
  await page.locator('.arcadia-game-card').first().waitFor({ timeout: 15000 });
  const mobileArcadiaDimensions = await page.evaluate(() => ({
    viewport: document.documentElement.clientWidth,
    content: document.documentElement.scrollWidth,
  }));
  assert(mobileArcadiaDimensions.content <= mobileArcadiaDimensions.viewport + 1, 'Arcadia móvel possui overflow horizontal');
  await page.screenshot({ path: 'test-results/mobile-arcadia.png', fullPage: true });

  await page.locator('[data-module="cortex"]').click();
  await page.getByRole('heading', { name: 'NOVA Cortex' }).waitFor();
  await page.locator('#cortexStats').filter({ hasText: /\d+ nós/ }).waitFor({ timeout: 30000 });
  await page.locator('#cortexViewToggle').click();
  await page.locator('.cortex-list-item').first().waitFor({ timeout: 30000 });
  const mobileCortexDimensions = await page.evaluate(() => ({
    viewport: document.documentElement.clientWidth,
    content: document.documentElement.scrollWidth,
  }));
  assert(mobileCortexDimensions.content <= mobileCortexDimensions.viewport + 1, 'Cortex móvel possui overflow horizontal');
  await page.screenshot({ path: 'test-results/mobile-cortex.png', fullPage: true });

  assert.deepEqual(consoleErrors, [], `Erros no console: ${consoleErrors.join(' | ')}`);
  assert.deepEqual(failedRequests, [], `Falhas HTTP: ${failedRequests.join(' | ')}`);

  await browser.close();
  browser = null;
  console.log(`SMOKE_OK ${workspaceNames.join(', ')} | ${cortexStats}`);
}

main().catch(async error => {
  await cleanupTemporaryItem();
  if (browser) await browser.close().catch(() => {});
  console.error(error);
  process.exitCode = 1;
});

async function cleanupTemporaryItem() {
  // O mock é em memória: o DELETE já removeu o item durante o fluxo (opção A).
  // Não há persistência no Nexus real para limpar. Mantido como no-op de contingência.
  cleanupItemId = null;
}
