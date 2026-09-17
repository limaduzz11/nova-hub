'use strict';

// ═══ NOVA HUB V5 WEB — Nexus mock em memória (opção A, sem credencial) ═══
// ARGOS-017 removeu o path X-API-Key do Nexus (agora exige Bearer OIDC). Testes de UI
// usam este mock autocontido; a validação com dados reais permanece em
// `integration-probe.js` (`probe:integrations`).

const nexusDb = {
  workspaces: [
    { id: 'ws-rotina', name: 'Rotina', kind: 'system', icon: 'check', color: '#7C4DFF', position: 0, created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z' },
    { id: 'ws-work', name: 'Work', kind: 'custom', icon: 'folder', color: '#4DB6AC', position: 1, created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z' },
    { id: 'ws-pessoal', name: 'Pessoal', kind: 'custom', icon: 'user', color: '#FFB74D', position: 2, created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z' },
    { id: 'ws-estudos', name: 'Estudos', kind: 'custom', icon: 'grid', color: '#EF5350', position: 3, created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z' },
  ],
  items: [
    { id: 'item-1', workspace_id: 'ws-work', type: 'task', title: 'Implementar pipeline de deploy', body: 'Configurar CI/CD com testes.', status: 'todo', tags: ['devops'], position: 0, created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z' },
    { id: 'item-2', workspace_id: 'ws-work', type: 'task', title: 'Revisar pull request do Nexus', body: 'Revisão de código.', status: 'doing', tags: ['revisao'], position: 1, created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z' },
    { id: 'item-3', workspace_id: 'ws-work', type: 'note', title: 'Notas da reunião de arquitetura', body: 'Decisões registradas.', status: 'standby', tags: ['notas'], position: 2, created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z' },
    { id: 'item-4', workspace_id: 'ws-rotina', type: 'task', title: 'Rotina matinal de revisão', body: 'Checklist diário.', status: 'concluded', tags: ['rotina'], position: 0, created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z' },
  ],
  games: [
    { id: 'game-1', igdb_id: 111, name: 'Celeste', cover_id: 'smoke-celeste', rating: 94, release_date: 1516579200, platforms: ['PC'], genres: ['Platform'], summary: 'Jogo de plataforma.', status: 'playing', user_rating: 9, notes: 'Excelente', created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z' },
  ],
  itemSeq: 1000,
};

const telemetryFixture = {
  status: 'online',
  timestamp: new Date().toISOString(),
  host: { hostname: 'pop-os', uptime_seconds: 3600 },
  cpu: { usage_percent: 25, temperature_celsius: 55 },
  memory: { total_bytes: 32e9, used_bytes: 16e9, usage_percent: 50 },
  disks: [
    { mount: '/', percent: 60, total_gb: 500, used_gb: 300 },
    { mount: '/home', percent: 40, total_gb: 1000, used_gb: 400 },
  ],
  gpu: { name: 'NVIDIA', temperature_celsius: 50, usage_percent: 10 },
  errors: [],
};

function buildGraph(n = 1100) {
  const groups = ['Arquitetura', 'Seguranca', 'Banco', 'Integracao', 'Testes', 'Frontend'];
  const nodes = [];
  const degree = new Map();
  for (let i = 0; i < n; i++) {
    const group = groups[i % groups.length];
    nodes.push({ id: `n${i}`, label: `${group} ${i}`, group, degree: 0, path: `/vault/${group.toLowerCase()}-${i}.md`, content: `Conteúdo textual do documento ${i}.` });
    degree.set(`n${i}`, 0);
  }
  const edges = [];
  for (let i = 0; i < n; i++) {
    if (i + 1 < n) { edges.push({ from: `n${i}`, to: `n${i + 1}` }); degree.set(`n${i}`, degree.get(`n${i}`) + 1); degree.set(`n${i + 1}`, degree.get(`n${i + 1}`) + 1); }
    if (i + 7 < n) { edges.push({ from: `n${i}`, to: `n${i + 7}` }); degree.set(`n${i}`, degree.get(`n${i}`) + 1); degree.set(`n${i + 7}`, degree.get(`n${i + 7}`) + 1); }
  }
  for (const node of nodes) node.degree = degree.get(node.id);
  return { nodes, edges };
}
const graphFixture = buildGraph(1100);

// PNG 1×1 transparente, para capas IGDB sem depender da rede externa.
const PNG_1x1 = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  'base64'
);

async function registerAuthMock(page, username) {
  await page.route('**/web-api/auth/session', route => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({ authenticated: true, username, csrf: `${username}-csrf` }),
  }));
}

async function registerMoonlightMock(page) {
  await page.route('**/web-api/integrations/moonlight', route => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({ sunshine: 'online', host: 'pop-os', tailscale_ip: '100.117.90.59', mode: 'external-client', reachable_ports: [47984, 47989, 47990, 48010] }),
  }));
}

async function registerNexusMock(page, { onPowerOff } = {}) {
  await page.route('**/web-api/nexus/**', async route => {
    const request = route.request();
    const url = new URL(request.url());
    const targetPath = `${url.pathname.replace('/web-api/nexus', '')}${url.search}`;
    const method = request.method();
    const json = (status, data) => route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(data) });

    if (targetPath === '/api/v1/telemetry') return json(200, telemetryFixture);
    if (targetPath === '/health') return json(200, { status: 'ok' });
    if (method === 'POST' && targetPath === '/api/power/off') {
      if (onPowerOff) onPowerOff();
      return json(200, { ok: true, intercepted: true });
    }
    if (method === 'POST' && targetPath === '/api/power/wol') return json(200, { ok: true });

    if (method === 'GET' && targetPath === '/api/workspaces') return json(200, nexusDb.workspaces);
    if (method === 'GET' && /^\/api\/workspaces\/[^/]+\/items/.test(targetPath)) {
      const wsId = decodeURIComponent(targetPath.split('/')[3]);
      return json(200, nexusDb.items.filter(item => item.workspace_id === wsId));
    }
    if (method === 'GET' && targetPath === '/api/items') return json(200, nexusDb.items);
    if (method === 'POST' && targetPath === '/api/items') {
      const body = JSON.parse(request.postDataBuffer().toString() || '{}');
      const item = {
        id: `item-${nexusDb.itemSeq++}`,
        workspace_id: body.workspace_id,
        type: body.type || 'task',
        title: body.title,
        body: body.body || '',
        status: body.status || 'todo',
        tags: body.tags || [],
        position: nexusDb.items.length,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };
      nexusDb.items.push(item);
      return json(201, item);
    }
    if (method === 'PATCH' && /^\/api\/items\/[^/]+$/.test(targetPath)) {
      const id = decodeURIComponent(targetPath.split('/')[3]);
      const body = JSON.parse(request.postDataBuffer().toString() || '{}');
      const item = nexusDb.items.find(candidate => candidate.id === id);
      if (!item) return json(404, { error: 'não encontrado' });
      Object.assign(item, body, { updated_at: new Date().toISOString() });
      return json(200, item);
    }
    if (method === 'DELETE' && /^\/api\/items\/[^/]+$/.test(targetPath)) {
      const id = decodeURIComponent(targetPath.split('/')[3]);
      nexusDb.items = nexusDb.items.filter(candidate => candidate.id !== id);
      // 200 (não 204): 204 sem corpo faz o navegador abortar o DELETE (ERR_ABORTED).
      return json(200, { ok: true });
    }
    if (method === 'GET' && targetPath === '/api/library') return json(200, nexusDb.games);
    if (method === 'GET' && targetPath === '/api/graph') return json(200, graphFixture);
    if (method === 'POST' && targetPath === '/news/enrich') return json(200, { results: [] });

    return json(404, { error: `não mockado: ${targetPath}` });
  });

  await page.route('**/images.igdb.com/**', route => route.fulfill({
    status: 200,
    contentType: 'image/png',
    body: PNG_1x1,
  }));
}

module.exports = { nexusDb, telemetryFixture, graphFixture, buildGraph, registerAuthMock, registerMoonlightMock, registerNexusMock };
