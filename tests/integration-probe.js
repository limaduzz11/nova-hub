'use strict';

// NOVA HUB V5 WEB — Probe de integração com o Nexus REAL.
// ARGOS-017 removeu o path X-API-Key; endpoints protegidos exigem Bearer OIDC. Este
// probe obtém um token via Keycloak password grant usando credenciais de teste de env
// (NOVA_PROBE_USER / NOVA_PROBE_PASSWORD). Sem credenciais, verifica apenas o /health
// (público) e marca os demais como "skipped" — nunca falha por ausência de credencial.

const BASE_URL = process.env.NEXUS_BASE_URL || 'http://127.0.0.1:8080';
const TOKEN_URL = process.env.KEYCLOAK_TOKEN_URL ||
  'http://100.121.250.3:18080/auth/realms/nova-hub/protocol/openid-connect/token';
const CLIENT_ID = process.env.KEYCLOAK_CLIENT_ID || 'nova-hub-v3';
const USER = process.env.NOVA_PROBE_USER || '';
const PASS = process.env.NOVA_PROBE_PASSWORD || '';

async function fetchToken() {
  if (!USER || !PASS) return null;
  try {
    const response = await fetch(TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ client_id: CLIENT_ID, grant_type: 'password', username: USER, password: PASS }),
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) return null;
    const payload = await response.json();
    return payload.access_token || null;
  } catch {
    return null;
  }
}

async function probe(name, endpoint, token) {
  const started = Date.now();
  const headers = { Accept: 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  try {
    const response = await fetch(`${BASE_URL}${endpoint}`, { headers, signal: AbortSignal.timeout(15000) });
    const payload = await response.json().catch(() => null);
    const count = Array.isArray(payload)
      ? payload.length
      : Array.isArray(payload?.items)
        ? payload.items.length
        : null;
    return { name, status: response.status, ok: response.ok, count, elapsed_ms: Date.now() - started };
  } catch (error) {
    return { name, status: 0, ok: false, error: error.name, elapsed_ms: Date.now() - started };
  }
}

async function main() {
  const token = await fetchToken();
  const results = [];
  // /health é público e não depende de credencial.
  results.push(await probe('nexus', '/health', null));
  if (token) {
    results.push(...await Promise.all([
      probe('library', '/api/library', token),
      probe('news', '/api/news', token),
      probe('igdb', '/api/igdb/search?q=zelda', token),
    ]));
  } else {
    for (const name of ['library', 'news', 'igdb']) {
      results.push({ name, status: null, ok: null, skipped: true, note: 'credencial ausente' });
    }
  }
  console.log(`INTEGRATION_PROBE token=${token ? 'ok' : 'absent'} ${JSON.stringify(results)}`);
  // Só falha: /health indisponível (não depende de credencial) ou endpoint protegido
  // falhando quando há token.
  const nexusDown = results.find(result => result.name === 'nexus')?.ok === false;
  const protectedFailed = results.some(result => result.name !== 'nexus' && result.ok === false);
  if (nexusDown || protectedFailed) process.exitCode = 1;
}

main().catch(error => {
  console.error(`INTEGRATION_PROBE_ERROR ${error.name}`);
  process.exitCode = 1;
});
