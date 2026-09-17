const crypto = require('crypto');
const dns = require('dns');
const express = require('express');
const fs = require('fs');
const net = require('net');
const os = require('os');
const path = require('path');
const { attachTerminalServer } = require('./terminal-server');

const app = express();

const PORT = Number(process.env.NOVA_WEB_PORT || 3001);
// Bind minimal: loopback por padrão; o IPv4 da Tailscale é adicionado como segundo
// listener no startup (ARGOS-018). Mantém a LAN fora do socket.
const HOST = process.env.NOVA_WEB_LISTEN_HOST || '127.0.0.1';
const TAILSCALE_IP = process.env.NOVA_WEB_HOST || '127.0.0.1';
const KEYCLOAK_TOKEN_URL = process.env.KEYCLOAK_TOKEN_URL ||
  'http://127.0.0.1:18080/auth/realms/nova-hub/protocol/openid-connect/token';
const KEYCLOAK_CLIENT_ID = process.env.KEYCLOAK_CLIENT_ID || 'nova-hub-v3';
const NEXUS_BASE_URL = process.env.NEXUS_BASE_URL || 'http://127.0.0.1:8080';
const BRIDGE_BASE_URL = process.env.BRIDGE_BASE_URL || 'http://127.0.0.1:8082';
// Logo do app: usa o caminho configurado se apontar para um arquivo existente;
// caso contrário (env ausente ou arquivo ausente), cai para o asset local do
// projeto. Evita 404/erro quando o caminho absoluto externo não está acessível.
const DEFAULT_BRAND_LOGO = '';

const LOCAL_BRAND_LOGO = path.join(__dirname, 'public', 'assets', 'elp-nova-mark.svg');
function resolveBrandLogo() {
  const configured = process.env.NOVA_BRAND_LOGO || DEFAULT_BRAND_LOGO;
  try {
    if (configured && fs.existsSync(configured) && fs.statSync(configured).isFile()) return configured;
  } catch {}
  return LOCAL_BRAND_LOGO;
}
const BRAND_LOGO = resolveBrandLogo();
const SUNSHINE_PROBE_HOST = process.env.SUNSHINE_PROBE_HOST || '127.0.0.1';
const MOONLIGHT_DISPLAY_HOST = process.env.MOONLIGHT_DISPLAY_HOST || 'pop-os';

const sessions = new Map();
const loginAttempts = new Map();
const SESSION_COOKIE = 'nova_session';
const MAX_LOGIN_ATTEMPTS = 6;
const LOGIN_WINDOW_MS = 10 * 60 * 1000;

app.disable('x-powered-by');
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: false, limit: '32kb' }));

app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  res.setHeader(
    'Content-Security-Policy',
    "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; " +
      "img-src 'self' data: https://images.igdb.com https://assetsio.gnwcdn.com https://cdn.mos.cms.futurecdn.net https://criticalhits.com.br https://images.nintendolife.com https://images.pushsquare.com https://sm.ign.com https://static0.polygonimages.com https://www.gamespot.com https://www.gamevicio.com https://www.youtube.com; connect-src 'self'; " +
      "font-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
  );
  next();
});

const TAILSCALE_CIDR = /^100\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;
function isAllowedNetworkAddress(address = '') {
  const ip = String(address).replace(/^::ffff:/, '');
  return ip === '127.0.0.1' || ip === '::1' || TAILSCALE_CIDR.test(ip);
}
app.use((req, res, next) => {
  const ip = req.ip || req.socket.remoteAddress || '';
  if (ip === '127.0.0.1' || ip === '::1' || ip === '::ffff:127.0.0.1') return next();
  if (TAILSCALE_CIDR.test(ip.replace(/^::ffff:/, ''))) return next();
  res.status(403).json({ error: 'Acesso permitido apenas via Tailscale' });
});

app.use((req, _res, next) => {
  const started = Date.now();
  _res.on('finish', () => {
    console.log(`[nova-web] ${req.method} ${req.path} ${_res.statusCode} ${Date.now() - started}ms`);
  });
  next();
});

function parseCookies(header = '') {
  return Object.fromEntries(
    header.split(';').map(v => v.trim()).filter(Boolean).map(pair => {
      const index = pair.indexOf('=');
      if (index < 0) return [pair, ''];
      return [decodeURIComponent(pair.slice(0, index)), decodeURIComponent(pair.slice(index + 1))];
    })
  );
}

function getSession(req) {
  const id = parseCookies(req.headers.cookie)[SESSION_COOKIE];
  if (!id) return null;
  const session = sessions.get(id);
  if (!session || session.refreshExpiresAt <= Date.now()) {
    sessions.delete(id);
    return null;
  }
  return { id, session };
}

function setSessionCookie(res, id, maxAgeSeconds) {
  res.setHeader(
    'Set-Cookie',
    `${SESSION_COOKIE}=${encodeURIComponent(id)}; HttpOnly; SameSite=Strict; Path=/; Max-Age=${maxAgeSeconds}`
  );
}

function clearSessionCookie(res) {
  res.setHeader('Set-Cookie', `${SESSION_COOKIE}=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0`);
}

function requireSession(req, res, next) {
  const current = getSession(req);
  if (!current) return res.status(401).json({ error: 'Sessão inválida ou expirada' });
  req.sessionId = current.id;
  req.session = current.session;
  next();
}

function requireCsrf(req, res, next) {
  if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) return next();
  if (req.get('X-CSRF-Token') !== req.session.csrf) {
    return res.status(403).json({ error: 'Token CSRF inválido' });
  }
  next();
}

async function keycloakToken(params) {
  const response = await fetch(KEYCLOAK_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(params),
    signal: AbortSignal.timeout(15000),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(payload.error_description || 'Falha na autenticação');
    error.status = response.status;
    error.oauthError = payload.error;
    throw error;
  }
  return payload;
}

const FALLBACK_AUTH_ENABLED = process.env.NOVA_AUTH_FALLBACK_ENABLED === 'true';
const FALLBACK_USER = process.env.NOVA_FALLBACK_USER || 'admin';
const FALLBACK_HASH = process.env.NOVA_FALLBACK_HASH || '';

function verifyFallbackAuth(user, pass) {
  if (!FALLBACK_AUTH_ENABLED || !FALLBACK_HASH) return false;
  if (user !== FALLBACK_USER) return false;
  const hash = crypto.createHash('sha256').update(pass).digest('hex');
  try {
    return crypto.timingSafeEqual(Buffer.from(hash, 'utf8'), Buffer.from(FALLBACK_HASH, 'utf8'));
  } catch {
    return false;
  }
}

async function refreshSession(id, session) {
  if (session.isOfflineFallback) {
    if (session.refreshExpiresAt - Date.now() > 0) return true;
    sessions.delete(id);
    return false;
  }
  if (session.accessExpiresAt - Date.now() > 15000) return true;
  try {
    const token = await keycloakToken({
      client_id: KEYCLOAK_CLIENT_ID,
      grant_type: 'refresh_token',
      refresh_token: session.refreshToken,
    });
    session.accessToken = token.access_token;
    session.refreshToken = token.refresh_token;
    session.accessExpiresAt = Date.now() + Number(token.expires_in || 300) * 1000;
    session.refreshExpiresAt = Date.now() + Number(token.refresh_expires_in || 1800) * 1000;
    sessions.set(id, session);
    return true;
  } catch {
    sessions.delete(id);
    return false;
  }
}

app.post('/web-api/auth/login', async (req, res) => {
  const ip = req.ip;
  const now = Date.now();
  const recent = (loginAttempts.get(ip) || []).filter(ts => now - ts < LOGIN_WINDOW_MS);
  if (recent.length >= MAX_LOGIN_ATTEMPTS) {
    return res.status(429).json({ error: 'Muitas tentativas. Aguarde alguns minutos.' });
  }
  loginAttempts.set(ip, [...recent, now]);

  const username = String(req.body.username || '').trim();
  const password = String(req.body.password || '');
  if (!username || !password) return res.status(400).json({ error: 'Usuário e senha são obrigatórios' });

  try {
    const token = await keycloakToken({
      client_id: KEYCLOAK_CLIENT_ID,
      grant_type: 'password',
      username,
      password,
    });

    const id = crypto.randomBytes(32).toString('hex');
    const csrf = crypto.randomBytes(24).toString('hex');
    const refreshExpiresIn = Number(token.refresh_expires_in || 1800);
    sessions.set(id, {
      username,
      csrf,
      accessToken: token.access_token,
      refreshToken: token.refresh_token,
      accessExpiresAt: Date.now() + Number(token.expires_in || 300) * 1000,
      refreshExpiresAt: Date.now() + refreshExpiresIn * 1000,
    });
    loginAttempts.delete(ip);
    setSessionCookie(res, id, refreshExpiresIn);
    res.json({ authenticated: true, username, csrf });
  } catch (error) {
    const invalidCredentials = error.status === 401 || error.oauthError === 'invalid_grant';
    // Fallback de contingência offline se o Keycloak estiver inacessível
    if (!invalidCredentials && verifyFallbackAuth(username, password)) {
      console.log(`[nova-web] Autenticacao de contingencia local (offline) concedida para ${username}`);
      const id = crypto.randomBytes(32).toString('hex');
      const csrf = crypto.randomBytes(24).toString('hex');
      const refreshExpiresIn = 24 * 3600;
      sessions.set(id, {
        username,
        csrf,
        isOfflineFallback: true,
        accessToken: 'offline_token_' + crypto.randomBytes(16).toString('hex'),
        refreshToken: 'offline_refresh_' + crypto.randomBytes(16).toString('hex'),
        accessExpiresAt: Date.now() + 12 * 3600 * 1000,
        refreshExpiresAt: Date.now() + refreshExpiresIn * 1000,
      });
      loginAttempts.delete(ip);
      setSessionCookie(res, id, refreshExpiresIn);
      return res.json({ authenticated: true, username, csrf, offlineFallback: true });
    }
    console.warn(`[nova-web] login recusado para ${username}: ${error.status || 'rede'}`);
    res.status(invalidCredentials ? 401 : 502).json({
      error: invalidCredentials ? 'Usuário ou senha inválidos' : 'Serviço de autenticação indisponível',
    });
  }
});

app.get('/web-api/auth/session', requireSession, async (req, res) => {
  if (!(await refreshSession(req.sessionId, req.session))) {
    clearSessionCookie(res);
    return res.status(401).json({ error: 'Sessão expirada' });
  }
  res.setHeader('Cache-Control', 'no-store');
  res.json({ authenticated: true, username: req.session.username, csrf: req.session.csrf });
});

app.post('/web-api/auth/logout', requireSession, requireCsrf, (req, res) => {
  sessions.delete(req.sessionId);
  clearSessionCookie(res);
  res.status(204).end();
});

function probeTcp(host, port, timeoutMs = 1000) {
  return new Promise(resolve => {
    const socket = net.createConnection({ host, port });
    let settled = false;
    const finish = online => {
      if (settled) return;
      settled = true;
      socket.destroy();
      resolve(online);
    };
    socket.setTimeout(timeoutMs);
    socket.once('connect', () => finish(true));
    socket.once('timeout', () => finish(false));
    socket.once('error', () => finish(false));
  });
}

app.get('/web-api/integrations/moonlight', requireSession, async (req, res) => {
  if (!(await refreshSession(req.sessionId, req.session))) {
    clearSessionCookie(res);
    return res.status(401).json({ error: 'Sessão expirada' });
  }
  const ports = [47984, 47989, 47990, 48010];
  const checks = await Promise.all(ports.map(port => probeTcp(SUNSHINE_PROBE_HOST, port)));
  res.setHeader('Cache-Control', 'no-store');
  res.json({
    sunshine: checks.some(Boolean) ? 'online' : 'offline',
    reachable_ports: ports.filter((_port, index) => checks[index]),
    host: MOONLIGHT_DISPLAY_HOST,
    tailscale_ip: TAILSCALE_IP,
    mode: 'external-client',
  });
});

app.use('/web-api/nexus', requireSession, requireCsrf, async (req, res) => {
  if (!(await refreshSession(req.sessionId, req.session))) {
    clearSessionCookie(res);
    return res.status(401).json({ error: 'Sessão expirada' });
  }

  const target = new URL(req.originalUrl.replace('/web-api/nexus', ''), NEXUS_BASE_URL);
  const headers = {
    Accept: req.get('Accept') || 'application/json',
    Authorization: `Bearer ${req.session.accessToken}`,
  };
  let body;
  if (!['GET', 'HEAD'].includes(req.method) && req.body !== undefined) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(req.body);
  }

  try {
    const upstream = await fetch(target, {
      method: req.method,
      headers,
      body,
      signal: AbortSignal.timeout(35000),
    });
    res.status(upstream.status);
    const contentType = upstream.headers.get('content-type');
    if (contentType) res.setHeader('Content-Type', contentType);
    const data = Buffer.from(await upstream.arrayBuffer());
    res.send(data);
  } catch (error) {
    console.error(`[nova-web] proxy Nexus: ${error.name}`);
    res.status(502).json({ error: 'Backend NOVA Nexus indisponível' });
  }
});

// ── Qualitor Bridge Proxy ─────────────────────────────────────
app.use('/web-api/bridge', requireSession, requireCsrf, async (req, res) => {
  if (!(await refreshSession(req.sessionId, req.session))) {
    clearSessionCookie(res);
    return res.status(401).json({ error: 'Sessão expirada' });
  }
  const bridgePath = req.originalUrl.replace(/^\/web-api\/bridge/, '') || '/';
  const target = `${BRIDGE_BASE_URL}${bridgePath}`;
  const headers = { Accept: req.get('Accept') || 'application/json' };
  let body;
  if (!['GET', 'HEAD'].includes(req.method) && req.body !== undefined) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(req.body);
  }
  try {
    const upstream = await fetch(target, {
      method: req.method,
      headers,
      body,
      signal: AbortSignal.timeout(300000),
    });
    res.status(upstream.status);
    const contentType = upstream.headers.get('content-type');
    if (contentType) res.setHeader('Content-Type', contentType);
    const data = Buffer.from(await upstream.arrayBuffer());
    res.send(data);
  } catch (error) {
    console.error(`[nova-web] proxy Bridge: ${error.name} ${error.message} target=${target}`);
    console.error(error.stack);
    res.status(502).json({ error: 'Qualitor Bridge indisponível — reiniciando, tente em 5s' });
  }
});

app.get('/healthz', async (_req, res) => {
  let nexus = 'offline';
  try {
    const response = await fetch(`${NEXUS_BASE_URL}/health`, { signal: AbortSignal.timeout(3000) });
    nexus = response.ok ? 'online' : 'degraded';
  } catch {}
  res.status(nexus === 'online' ? 200 : 503).json({ web: 'online', nexus });
});

// ── News Image Enrichment ──────────────────────────────────────
// Extrai og:image / twitter:image de uma página de artigo quando o
// feed RSS não forneceu uma imagem válida.
const ENRICH_CACHE = new Map();
const ENRICH_CACHE_TTL = 30 * 60 * 1000; // 30 min
const ENRICH_TIMEOUT = 8000;

// ── Anti-SSRF: só permite buscar URLs HTTP(S) externas (nunca loopback,
// LAN, link-local ou cloud-metadata). Resolve o hostname e bloqueia IPs
// internos antes de qualquer fetch server-side (ARGOS hardening).
function isInternalIp(ip) {
  if (!ip || ip === '0.0.0.0' || ip === '::') return true;
  const parts = ip.split('.').map(Number);
  if (parts.length === 4) {
    if (parts[0] === 10) return true;                       // 10.0.0.0/8
    if (parts[0] === 127) return true;                      // loopback
    if (parts[0] === 169 && parts[1] === 254) return true;  // 169.254/16 (incl. metadata)
    if (parts[0] === 172 && parts[1] >= 16 && parts[1] <= 31) return true; // 172.16/12
    if (parts[0] === 192 && parts[1] === 168) return true;  // 192.168/16
  }
  return ip === '::1' || ip.startsWith('fe80:') || ip.startsWith('fc') || ip.startsWith('fd') || ip === '0:0:0:0:0:0:0:1';
}

async function isSafeExternalUrl(rawUrl) {
  let parsed;
  try { parsed = new URL(rawUrl); } catch { return false; }
  if (!['http:', 'https:'].includes(parsed.protocol)) return false;
  // Bloqueia credenciais embutidas e hostname vazio
  if (parsed.username || parsed.password || !parsed.hostname) return false;
  // Se já for IP literal, valida direto
  if (net.isIP(parsed.hostname) && isInternalIp(parsed.hostname)) return false;

  // Resolve DNS e valida todos os endereços (best-effort; falha seguro se não resolver)
  const addresses = await new Promise(resolve => {
    dns.lookup(parsed.hostname, { all: true }, (err, addrs) => {
      if (err) return resolve([]);
      resolve(Array.isArray(addrs) ? addrs.map(a => a.address) : []);
    });
  });
  if (!addresses.length) return false;
  return addresses.every(addr => !isInternalIp(addr));
}

async function enrichImageFromPage(articleUrl) {
  if (!articleUrl) return null;
  // Cache check
  const cached = ENRICH_CACHE.get(articleUrl);
  if (cached && Date.now() - cached.ts < ENRICH_CACHE_TTL) return cached.url;

  try {
    // Anti-SSRF: recusa URLs que apontem para loopback/LAN/metadata antes do fetch.
    if (!(await isSafeExternalUrl(articleUrl))) {
      ENRICH_CACHE.set(articleUrl, { url: null, ts: Date.now() });
      return null;
    }

    // Segue redirects manualmente, validando cada hop contra IPs internos.
    let current = articleUrl;
    for (let redirects = 0; redirects < 4; redirects++) {
      if (!(await isSafeExternalUrl(current))) return null;
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), ENRICH_TIMEOUT);
      const resp = await fetch(current, {
        redirect: 'manual',
        signal: controller.signal,
        headers: { 'User-Agent': 'Mozilla/5.0 (compatible; NOVA-HUB/1.0)' },
      });
      clearTimeout(timer);
      if ([301, 302, 303, 307, 308].includes(resp.status) && resp.headers.get('location')) {
        const next = new URL(resp.headers.get('location'), current).toString();
        if (next === current) return null;
        current = next;
        continue;
      }
      if (!resp.ok) return null;
      const contentType = resp.headers.get('content-type') || '';
      if (!contentType.includes('text/html')) return null;
      const html = await resp.text();
      // Extract og:image (priority order)
      const patterns = [
        /property=["']og:image["']\s+content=["']([^"']+)["']/i,
        /content=["']([^"']+)["']\s+property=["']og:image["']/i,
        /name=["']twitter:image["']\s+content=["']([^"']+)["']/i,
        /content=["']([^"']+)["']\s+name=["']twitter:image["']/i,
        /name=["']twitter:image:src["']\s+content=["']([^"']+)["']/i,
      ];
      for (const pat of patterns) {
        const m = html.match(pat);
        if (m && m[1]) {
          let img = m[1].trim();
          // Resolve relative URLs
          if (img.startsWith('//')) img = 'https:' + img;
          else if (img.startsWith('/')) {
            const base = new URL(current);
            img = base.origin + img;
          }
          ENRICH_CACHE.set(articleUrl, { url: img, ts: Date.now() });
          return img;
        }
      }
      break;
    }
  } catch {}
  ENRICH_CACHE.set(articleUrl, { url: null, ts: Date.now() });
  return null;
}

// POST /web-api/news/enrich { urls: [{id, url}] }
// Retorna { results: [{id, image}] } para URLs que precisam de enriquecimento.
app.post('/web-api/news/enrich', requireSession, requireCsrf, async (req, res) => {
  if (!(await refreshSession(req.sessionId, req.session))) {
    clearSessionCookie(res);
    return res.status(401).json({ error: 'Sessão expirada' });
  }
  const urls = Array.isArray(req.body?.urls) ? req.body.urls.slice(0, 10) : [];
  if (!urls.length) return res.json({ results: [] });

  const results = await Promise.all(urls.map(async ({ id, url }) => {
    const image = await enrichImageFromPage(url);
    return { id, image: image || null };
  }));
  res.json({ results });
});

app.get('/assets/nova-logo.png', (_req, res) => res.sendFile(BRAND_LOGO));

app.get('/', (_req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.use(express.static(path.join(__dirname, 'public'), { etag: true, maxAge: '5m' }));
app.use('/src', express.static(path.join(__dirname, 'src'), { etag: true, maxAge: '5m' }));
app.get('/vendor/xterm.js', (_req, res) => res.sendFile(path.join(__dirname, 'node_modules', '@xterm', 'xterm', 'lib', 'xterm.js')));
app.get('/vendor/xterm.css', (_req, res) => res.sendFile(path.join(__dirname, 'node_modules', '@xterm', 'xterm', 'css', 'xterm.css')));
app.get('/vendor/addon-fit.js', (_req, res) => res.sendFile(path.join(__dirname, 'node_modules', '@xterm', 'addon-fit', 'lib', 'addon-fit.js')));

app.use((req, res, next) => {
  if (req.method !== 'GET') return next();
  if (req.path.startsWith('/src/') || req.path.startsWith('/assets/') || req.path.includes('.')) return next();
  res.setHeader('Cache-Control', 'no-store');
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.use((_req, res) => res.status(404).json({ error: 'Recurso não encontrado' }));

setInterval(() => {
  const now = Date.now();
  for (const [id, session] of sessions) {
    if (session.refreshExpiresAt <= now) sessions.delete(id);
  }
  for (const [ip, attempts] of loginAttempts) {
    const recent = attempts.filter(ts => now - ts < LOGIN_WINDOW_MS);
    if (recent.length) loginAttempts.set(ip, recent);
    else loginAttempts.delete(ip);
  }
}, 60000).unref();

function tailscaleIPv4() {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    if (!name.startsWith('tailscale')) continue;
    for (const addr of interfaces[name]) {
      if (addr.family === 'IPv4' && !addr.internal) return addr.address;
    }
  }
  return null;
}

const server = app.listen(PORT, HOST, () => {
  console.log(`[nova-web] ouvindo em http://${HOST}:${PORT}`);
});

// Terminal: anexa o upgrade do WebSocket ao listener loopback e devolve
// handleUpgrade para anexar também aos listeners Tailscale (ARGOS-029).
const terminal = attachTerminalServer({
  server,
  authenticate(request) {
    return getSession(request);
  },
  isAllowedAddress: isAllowedNetworkAddress,
});

// Segundo listener no IPv4 da Tailscale (acesso do app Android e outros devices),
// sem expor a LAN. (ARGOS-027) A Tailscale pode ainda não ter IPv4 no boot; re-tenta.
function startTailscaleListener() {
  const ip = tailscaleIPv4();
  if (ip && ip !== HOST) {
    const tsServer = app.listen(PORT, ip, () => {
      console.log(`[nova-web] ouvindo em http://${ip}:${PORT} (tailscale)`);
    });
    tsServer.on('upgrade', terminal.handleUpgrade);
    return;
  }
  let attempts = 0;
  const MAX_ATTEMPTS = 30; // 30 * 2s = 60s
  const timer = setInterval(() => {
    attempts++;
    const retryIp = tailscaleIPv4();
    if (retryIp && retryIp !== HOST) {
      clearInterval(timer);
      const tsServer = app.listen(PORT, retryIp, () => {
        console.log(`[nova-web] ouvindo em http://${retryIp}:${PORT} (tailscale, ARGOS-027 retry)`);
      });
      tsServer.on('upgrade', terminal.handleUpgrade);
    } else if (attempts >= MAX_ATTEMPTS) {
      clearInterval(timer);
      console.log('[nova-web] tailscale0 sem IPv4 após 60s; apenas loopback (ARGOS-027)');
    }
  }, 2000);
}
startTailscaleListener();
