const assert = require('node:assert/strict');
const { chromium } = require('playwright');
const { registerAuthMock, registerMoonlightMock, registerNexusMock } = require('./fixtures/nexus-mock');

const BASE_URL = process.env.NOVA_WEB_TEST_URL || 'http://127.0.0.1:3001';

const MODULES = ['link', 'nexus', 'arcadia', 'cortex', 'settings'];
const VIEWPORTS = [
  { name: '1366x768', width: 1366, height: 768, modules: MODULES },
  { name: '1920x1080', width: 1920, height: 1080, modules: MODULES },
  { name: '2560x1440', width: 2560, height: 1440, modules: ['link', 'arcadia', 'cortex'] },
  { name: '3840x2160', width: 3840, height: 2160, modules: ['link', 'nexus', 'settings'] },
  { name: 'tablet-landscape', width: 1024, height: 768, modules: MODULES },
  { name: 'compact-window', width: 900, height: 700, modules: ['link', 'nexus', 'arcadia', 'settings'] },
];

const ZOOM_EQUIVALENTS = [
  { label: '33', width: 5760, height: 3240 },
  { label: '50', width: 3840, height: 2160 },
  { label: '80', width: 2400, height: 1350 },
  { label: '100', width: 1920, height: 1080 },
  { label: '125', width: 1536, height: 864 },
  { label: '150', width: 1280, height: 720 },
];

let browser;

async function main() {
  browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 1366, height: 768 }, reducedMotion: 'no-preference' });
  const page = await context.newPage();
  const consoleErrors = [];
  const failedRequests = [];

  page.on('console', message => {
    if (message.type() === 'error' && !message.text().startsWith('Failed to load resource:')) consoleErrors.push(message.text());
  });
  page.on('requestfailed', request => {
    if (request.url().startsWith(BASE_URL)) failedRequests.push(`${request.method()} ${request.url()} ${request.failure()?.errorText || ''}`);
  });

  await installRoutes(page);
  await page.goto(BASE_URL, { waitUntil: 'networkidle' });
  await waitForModule(page, 'link');
  await validateContrast(page);

  for (const viewport of VIEWPORTS) {
    await page.setViewportSize({ width: viewport.width, height: viewport.height });
    for (const module of viewport.modules) {
      await openModule(page, module, `${viewport.name}/${module}`);
      await assertViewportIntegrity(page, `${viewport.name}/${module}`);
      await assertAccessibleControls(page, `${viewport.name}/${module}`);
    }
    await page.screenshot({ path: `test-results/visual-${viewport.name}.png`, fullPage: false });
  }

  // Browser zoom changes the effective CSS viewport. These equivalent viewports
  // exercise the same reflow pressure without relying on browser chrome shortcuts.
  for (const zoom of ZOOM_EQUIVALENTS) {
    await page.setViewportSize({ width: zoom.width, height: zoom.height });
    for (const module of MODULES) {
      await openModule(page, module, `zoom-${zoom.label}/${module}`);
      await assertViewportIntegrity(page, `zoom-${zoom.label}/${module}`);
      const visibleArea = await page.locator('.module-view').evaluate(element => {
        const rect = element.getBoundingClientRect();
        const style = getComputedStyle(element);
        return { width: rect.width, height: rect.height, opacity: Number(style.opacity) };
      });
      assert(visibleArea.width > 100 && visibleArea.height > 100 && visibleArea.opacity > .9,
        `zoom-${zoom.label}/${module}: conteúdo principal não ficou visível ${JSON.stringify(visibleArea)}`);
    }
    await page.waitForTimeout(500);
    await page.screenshot({ path: `test-results/visual-zoom-${zoom.label}.png`, fullPage: false });
  }

  await page.setViewportSize({ width: 1440, height: 1000 });
  await openModule(page, 'cortex');
  await validateCortexCanvasInteraction(page);

  await page.emulateMedia({ reducedMotion: 'reduce' });
  await openModule(page, 'link');
  const motion = await page.locator('.module-view').evaluate(element => ({
    transition: getComputedStyle(element).transitionDuration,
    animation: getComputedStyle(element).animationDuration,
  }));
  assert(motion.transition.split(',').every(value => Number.parseFloat(value) <= .001), `Reduced motion não neutralizou transição: ${motion.transition}`);

  assert.deepEqual(consoleErrors, [], `Erros no console: ${consoleErrors.join(' | ')}`);
  assert.deepEqual(failedRequests, [], `Falhas HTTP: ${failedRequests.join(' | ')}`);

  await browser.close();
  browser = null;
  console.log(`VISUAL_MATRIX_OK ${VIEWPORTS.length} viewports • ${ZOOM_EQUIVALENTS.length} níveis de zoom • ${MODULES.length} módulos`);
}

async function installRoutes(page) {
  await registerAuthMock(page, 'visual-validation');
  await registerNexusMock(page);
  await registerMoonlightMock(page);
}

async function openModule(page, module, label = module) {
  if (await page.locator(`body[data-active-module="${module}"]`).count() === 0) {
    await page.locator(`.nav-item[data-module="${module}"]`).click();
  }
  await waitForModule(page, module);
  await settleModuleTransition(page, label);
}

async function waitForModule(page, module) {
  const targets = {
    link: async () => page.getByText('Online', { exact: true }).waitFor({ timeout: 20000 }),
    nexus: async () => page.waitForFunction(() => document.querySelectorAll('#wsSelector option').length > 0, null, { timeout: 20000 }),
    arcadia: async () => page.waitForFunction(() => /\d+ de \d+ jogos/.test(document.querySelector('#arcadiaLibrarySummary')?.textContent || ''), null, { timeout: 20000 }),
    cortex: async () => page.locator('#cortexStats').filter({ hasText: /\d+ nós/ }).waitFor({ timeout: 30000 }),
    settings: async () => page.locator('#settingsNexusStatus').filter({ hasText: /Online|Indisponível/ }).waitFor({ timeout: 20000 }),
  };
  await targets[module]();
}

async function settleModuleTransition(page, label) {
  const view = page.locator('.module-view');
  await view.waitFor({ state: 'visible' });
  await page.waitForFunction(() => {
    const element = document.querySelector('.module-view');
    return element?.classList.contains('is-visible') && Number(getComputedStyle(element).opacity) > .9;
  }, null, { timeout: 5000 }).catch(async error => {
    const state = await page.locator('.module-view').evaluate(element => ({
      classes: element.className,
      opacity: getComputedStyle(element).opacity,
      connected: element.isConnected,
      activeModule: document.body.dataset.activeModule,
    })).catch(() => ({ missing: true }));
    throw new Error(`${label}: transição não concluiu ${JSON.stringify(state)} — ${error.message}`);
  });
  await view.evaluate(async element => {
    await Promise.all(element.getAnimations().map(animation => animation.finished.catch(() => {})));
  });
}

async function assertViewportIntegrity(page, label) {
  const report = await page.evaluate(() => {
    const root = document.documentElement;
    const duplicateIds = [...document.querySelectorAll('[id]')]
      .map(element => element.id)
      .filter((id, index, ids) => ids.indexOf(id) !== index);
    const tinyControls = [...document.querySelectorAll('button:not([disabled]),a[href],input:not([type="hidden"]),select,textarea')]
      .filter(element => {
        const style = getComputedStyle(element);
        const rect = element.getBoundingClientRect();
        return style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0 && (rect.height < 30 || rect.width < 24);
      })
      .slice(0, 10)
      .map(element => `${element.tagName.toLowerCase()}#${element.id || ''}.${element.className || ''}`);
    return {
      clientWidth: root.clientWidth,
      scrollWidth: root.scrollWidth,
      duplicateIds,
      tinyControls,
    };
  });
  assert(report.scrollWidth <= report.clientWidth + 2, `${label}: overflow horizontal ${report.scrollWidth}px > ${report.clientWidth}px`);
  assert.deepEqual(report.duplicateIds, [], `${label}: IDs duplicados: ${report.duplicateIds.join(', ')}`);
  assert.deepEqual(report.tinyControls, [], `${label}: controles pequenos: ${report.tinyControls.join(', ')}`);
}

async function assertAccessibleControls(page, label) {
  const unnamed = await page.evaluate(() => [...document.querySelectorAll('button,a[href],input:not([type="hidden"]),select,textarea,canvas[tabindex]')]
    .filter(element => {
      const style = getComputedStyle(element);
      const rect = element.getBoundingClientRect();
      if (style.display === 'none' || style.visibility === 'hidden' || rect.width === 0 || rect.height === 0) return false;
      const labelledBy = element.getAttribute('aria-labelledby');
      const labelledText = labelledBy ? document.getElementById(labelledBy)?.textContent?.trim() : '';
      const labelText = element.labels ? [...element.labels].map(label => label.textContent.trim()).join(' ') : '';
      const name = element.getAttribute('aria-label') || labelledText || labelText || element.textContent.trim() || element.getAttribute('placeholder') || element.getAttribute('title');
      return !name;
    })
    .map(element => `${element.tagName.toLowerCase()}#${element.id || ''}.${element.className || ''}`));
  assert.deepEqual(unnamed, [], `${label}: controles sem nome acessível: ${unnamed.join(', ')}`);

  const imagesWithoutAlt = await page.locator('img:visible').evaluateAll(images => images.filter(image => !image.hasAttribute('alt')).map(image => image.src));
  assert.deepEqual(imagesWithoutAlt, [], `${label}: imagens sem alt: ${imagesWithoutAlt.join(', ')}`);
}

async function validateContrast(page) {
  const ratios = await page.evaluate(() => {
    const root = getComputedStyle(document.documentElement);
    const tokens = ['--text-ivory', '--text-ash', '--brand-signal', '--state-success'];
    const background = root.getPropertyValue('--bg-void').trim();
    const parse = value => {
      const hex = value.replace('#', '');
      return [0, 2, 4].map(index => Number.parseInt(hex.slice(index, index + 2), 16));
    };
    const luminance = color => parse(color).map(channel => {
      const normalized = channel / 255;
      return normalized <= .04045 ? normalized / 12.92 : ((normalized + .055) / 1.055) ** 2.4;
    }).reduce((sum, channel, index) => sum + channel * [.2126, .7152, .0722][index], 0);
    const bgLum = luminance(background);
    return Object.fromEntries(tokens.map(token => {
      const color = root.getPropertyValue(token).trim();
      const lum = luminance(color);
      return [token, (Math.max(lum, bgLum) + .05) / (Math.min(lum, bgLum) + .05)];
    }));
  });
  assert(ratios['--text-ivory'] >= 7, `Contraste do texto principal abaixo de AAA: ${ratios['--text-ivory']}`);
  assert(ratios['--text-ash'] >= 4.5, `Contraste do texto secundário abaixo de AA: ${ratios['--text-ash']}`);
  assert(ratios['--brand-signal'] >= 4.5, `Contraste do destaque abaixo de AA: ${ratios['--brand-signal']}`);
  assert(ratios['--state-success'] >= 4.5, `Contraste do estado online abaixo de AA: ${ratios['--state-success']}`);
}

async function validateCortexCanvasInteraction(page) {
  const canvas = page.locator('#cortexCanvas');
  await page.locator('#cortexFit').click();
  await page.waitForTimeout(350);
  const before = await canvas.evaluate(element => element.toDataURL());
  const box = await canvas.boundingBox();
  assert(box, 'Canvas Cortex sem bounding box');
  let diagnosticPoint = await page.evaluate(() => CortexModule.diagnostics().firstNode);
  assert(diagnosticPoint, 'Cortex não produziu nó diagnosticável no canvas');
  await page.mouse.move(diagnosticPoint.x, diagnosticPoint.y);
  await page.locator('#cortexTooltip').waitFor({ state: 'visible', timeout: 5000 });
  assert((await page.locator('#cortexTooltip strong').textContent()).trim().length > 0, 'Tooltip Cortex sem título');
  await page.screenshot({ path: 'test-results/visual-cortex-hover.png', fullPage: false });

  // A simulação física pode mover o nó enquanto a captura é gravada. Localize
  // novamente e clique de imediato para validar a seleção real no canvas.
  diagnosticPoint = await page.evaluate(() => CortexModule.diagnostics().firstNode);
  assert(diagnosticPoint, 'Cortex perdeu todos os nós visíveis antes da seleção');
  await page.mouse.move(diagnosticPoint.x, diagnosticPoint.y);
  await page.locator('#cortexTooltip').waitFor({ state: 'visible', timeout: 5000 });
  await page.mouse.down();
  await page.mouse.up();
  await page.locator('#cortexNodeDetail').waitFor({ state: 'visible', timeout: 5000 });
  const after = await canvas.evaluate(element => element.toDataURL());
  assert.notEqual(after, before, 'Seleção Cortex não alterou destaque visual do canvas');
  await page.screenshot({ path: 'test-results/visual-cortex-selected.png', fullPage: false });
}

main().catch(async error => {
  if (browser) await browser.close().catch(() => {});
  console.error(error);
  process.exitCode = 1;
});
