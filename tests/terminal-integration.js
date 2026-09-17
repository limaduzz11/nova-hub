const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { spawn } = require('node:child_process');
const { chromium } = require('playwright');
const { WebSocket } = require('ws');

async function waitForHealth(url, timeout = 15000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    try { if ((await fetch(url)).status < 500) return; } catch {}
    await new Promise(resolve => setTimeout(resolve, 150));
  }
  throw new Error(`Servidor não iniciou em ${url}`);
}

function startServer(port, sshHost, sshUser, sshPort = 22) {
  const password = crypto.randomBytes(18).toString('hex');
  const child = spawn(process.execPath, ['server.js'], {
    cwd: process.cwd(),
    env: {
      ...process.env,
      NOVA_WEB_PORT: String(port),
      LOCAL_AUTH_USERS: `terminal-test:${password}`,
      NOVA_SSH_HOST: sshHost,
      NOVA_SSH_USER: sshUser,
      NOVA_SSH_PORT: String(sshPort),
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let logs = '';
  child.stdout.on('data', chunk => { logs += chunk.toString(); });
  child.stderr.on('data', chunk => { logs += chunk.toString(); });
  return { child, password, logs: () => logs };
}

async function login(port, password) {
  const response = await fetch(`http://127.0.0.1:${port}/web-api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'terminal-test', password }),
  });
  assert.equal(response.status, 200, 'Login temporário do teste falhou');
  return response.headers.get('set-cookie').split(';')[0];
}

function connect(port, cookie, sessionId = '') {
  const suffix = sessionId ? `?session=${encodeURIComponent(sessionId)}` : '';
  const socket = new WebSocket(`ws://127.0.0.1:${port}/web-api/terminal${suffix}`, {
    headers: { Cookie: cookie, Origin: `http://127.0.0.1:${port}` },
  });
  const messages = [];
  socket.on('message', raw => {
    try { messages.push(JSON.parse(raw.toString())); } catch {}
  });
  return { socket, messages };
}

async function waitFor(messages, predicate, timeout = 15000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const match = messages.find(predicate);
    if (match) return match;
    await new Promise(resolve => setTimeout(resolve, 50));
  }
  throw new Error(`Mensagem esperada não chegou. Recebidas: ${messages.map(item => item.type).join(', ')}`);
}

async function waitForTranscript(messages, pattern, timeout = 15000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const transcript = messages.filter(message => message.type === 'output').map(message => message.data).join('');
    if (pattern.test(transcript)) return transcript;
    await new Promise(resolve => setTimeout(resolve, 50));
  }
  throw new Error(`Saída esperada não chegou: ${pattern}`);
}

async function closeSocket(socket) {
  if (socket.readyState === WebSocket.CLOSED) return;
  await new Promise(resolve => { socket.once('close', resolve); socket.close(); });
}

async function runSuccessCase() {
  const port = 3101;
  const server = startServer(port, '127.0.0.1', process.env.USER);
  try {
    await waitForHealth(`http://127.0.0.1:${port}/healthz`);
    const cookie = await login(port, server.password);

    const unauthorized = new WebSocket(`ws://127.0.0.1:${port}/web-api/terminal`, { headers: { Origin: `http://127.0.0.1:${port}` } });
    const unauthorizedStatus = await new Promise(resolve => unauthorized.once('unexpected-response', (_request, response) => resolve(response.statusCode)));
    assert.equal(unauthorizedStatus, 401, 'WebSocket aceitou cliente sem sessão');

    const first = connect(port, cookie);
    const ready = await waitFor(first.messages, message => message.type === 'ready');
    first.socket.send(JSON.stringify({ type: 'resize', cols: 123, rows: 41 }));
    first.socket.send(JSON.stringify({ type: 'input', data: "printf '\\nNOVA_TERMINAL_OK\\n'; stty size; printf 'NOVA_RESIZE_OK\\n'\r" }));
    await waitForTranscript(first.messages, /NOVA_TERMINAL_OK[\s\S]*41\s+123[\s\S]*NOVA_RESIZE_OK/);

    first.socket.send(JSON.stringify({ type: 'input', data: 'sleep 20\r' }));
    await new Promise(resolve => setTimeout(resolve, 350));
    first.socket.send(JSON.stringify({ type: 'input', data: '\u0003' }));
    first.socket.send(JSON.stringify({ type: 'input', data: "printf 'NOVA_CTRL_C_OK\\n'\r" }));
    await waitForTranscript(first.messages, /NOVA_CTRL_C_OK/);

    await closeSocket(first.socket);
    const resumed = connect(port, cookie, ready.sessionId);
    const resumedReady = await waitFor(resumed.messages, message => message.type === 'ready');
    assert.equal(resumedReady.sessionId, ready.sessionId, 'Reconexão não retomou a sessão PTY');
    resumed.socket.send(JSON.stringify({ type: 'input', data: "printf 'NOVA_RECONNECT_OK\\n'\r" }));
    await waitForTranscript(resumed.messages, /NOVA_RECONNECT_OK/);
    resumed.socket.send(JSON.stringify({ type: 'close' }));
    await closeSocket(resumed.socket);

    const browser = await chromium.launch({ headless: true });
    try {
      const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
      await page.goto(`http://127.0.0.1:${port}`);
      await page.locator('#username').fill('terminal-test');
      await page.locator('#password').fill(server.password);
      await page.locator('#loginBtn').click();
      await page.locator('#sshBtn').waitFor({ timeout: 15000 });
      await page.locator('#sshBtn').click();
      await page.locator('#terminalStatus[data-state="connected"]').waitFor({ timeout: 15000 });
      await page.locator('.xterm-helper-textarea').focus();
      await page.keyboard.type("printf 'NOVA_XTERM_UI_OK\\n'");
      await page.keyboard.press('Enter');
      await page.locator('.xterm-rows').filter({ hasText: 'NOVA_XTERM_UI_OK' }).waitFor({ timeout: 15000 });
      const overlay = await page.locator('#novaTerminalOverlay').boundingBox();
      assert(overlay && overlay.width <= 390 && overlay.height <= 844, 'Terminal móvel excedeu o viewport');
      await page.setViewportSize({ width: 1440, height: 1000 });
      await page.waitForTimeout(700);
      await page.locator('.xterm-helper-textarea').focus();
      await page.keyboard.type("stty size; printf 'NOVA_UI_RESIZE_OK\\n'");
      await page.keyboard.press('Enter');
      await page.locator('.xterm-rows').filter({ hasText: 'NOVA_UI_RESIZE_OK' }).waitFor({ timeout: 15000 });
      const terminalText = await page.locator('.xterm-rows').innerText();
      const dimensions = terminalText.match(/(\d+)\s+(\d+)\s*\r?\nNOVA_UI_RESIZE_OK/);
      assert(dimensions && Number(dimensions[1]) > 35 && Number(dimensions[2]) > 120, `PTY não ocupou a tela disponível: ${dimensions?.slice(1).join('x') || 'sem dimensões'}`);
      await page.locator('#terminalClose').click();
    } finally {
      await browser.close();
    }
  } finally {
    server.child.kill('SIGTERM');
  }
}

async function runFailureCase(port, host, user, expected, sshPort = 22) {
  const server = startServer(port, host, user, sshPort);
  try {
    await waitForHealth(`http://127.0.0.1:${port}/healthz`);
    const cookie = await login(port, server.password);
    const client = connect(port, cookie);
    await waitFor(client.messages, message => message.type === 'ready');
    await waitForTranscript(client.messages, expected, 20000);
    await waitFor(client.messages, message => message.type === 'exit', 20000);
    await closeSocket(client.socket);
  } finally {
    server.child.kill('SIGTERM');
  }
}

(async () => {
  await runSuccessCase();
  await runFailureCase(3102, '127.0.0.1', process.env.USER, /refused|timed out|No route/i, 1);
  await runFailureCase(3103, '127.0.0.1', 'nova-invalid-user', /Permission denied/i);
  console.log('TERMINAL_INTEGRATION_OK auth, PTY, resize, Ctrl+C, reconnect, host e credencial inválidos');
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
