const crypto = require('crypto');
const os = require('os');
const path = require('path');
const pty = require('node-pty');
const { WebSocket, WebSocketServer } = require('ws');

const MAX_TERMINALS = 8;
const DETACH_GRACE_MS = 15_000;
const MAX_DETACHED_BUFFER = 256 * 1024;
const MAX_INPUT_SIZE = 64 * 1024;
const STALE_SESSION_MAX_MS = 120_000;

function attachTerminalServer({ server, authenticate, isAllowedAddress }) {
  const websocketServer = new WebSocketServer({ noServer: true, maxPayload: MAX_INPUT_SIZE });
  const terminals = new Map();

  function send(socket, message) {
    if (socket.readyState === WebSocket.OPEN) socket.send(JSON.stringify(message));
  }

  function sameOrigin(request) {
    try {
      const origin = new URL(request.headers.origin || '');
      return ['http:', 'https:'].includes(origin.protocol) && origin.host === request.headers.host;
    } catch {
      return false;
    }
  }

  function terminateSession(terminal, reason = 'closed') {
    if (!terminal || terminal.closed) return;
    terminal.closed = true;
    clearTimeout(terminal.detachTimer);
    clearTimeout(terminal.maxLifetimeTimer);
    terminals.delete(terminal.id);
    for (const socket of terminal.sockets) {
      send(socket, { type: 'exit', reason });
      socket.close(1000, reason);
    }
    terminal.sockets.clear();
    try { terminal.process.kill('SIGHUP'); } catch {}
  }

  function sweepStaleSessions() {
    const now = Date.now();
    for (const terminal of terminals.values()) {
      if (terminal.sockets.size === 0 && !terminal.closed) {
        const idleMs = now - (terminal.detachStartTime || now);
        if (idleMs > STALE_SESSION_MAX_MS) {
          console.log(`[nova-web] terminal SSH limpo (stale ${Math.round(idleMs / 1000)}s) ${terminal.id.slice(0, 8)}`);
          terminateSession(terminal, 'Sessão stale removida');
        }
      }
    }
  }

  function spawnTerminal(ownerSessionId) {
    sweepStaleSessions();
    if (terminals.size >= MAX_TERMINALS) {
      const oldest = [...terminals.values()].filter(t => t.sockets.size === 0).sort((a, b) => (a.detachStartTime || 0) - (b.detachStartTime || 0))[0];
      if (oldest) {
        console.log(`[nova-web] terminal SSH forçado (limite atingido) ${oldest.id.slice(0, 8)}`);
        terminateSession(oldest, 'Sessão substituída');
      } else {
        throw new Error('Limite de sessões de terminal atingido. Feche uma aba do terminal.');
      }
    }

    const id = crypto.randomBytes(24).toString('hex');
    const host = process.env.NOVA_SSH_HOST || '127.0.0.1';
    const port = String(Number(process.env.NOVA_SSH_PORT || 22));
    const user = process.env.NOVA_SSH_USER || os.userInfo().username;
    const knownHosts = process.env.NOVA_SSH_KNOWN_HOSTS || path.join(os.homedir(), '.ssh', 'known_hosts');
    const identityFile = process.env.NOVA_SSH_IDENTITY_FILE || '';
    const args = [
      '-tt',
      '-o', 'BatchMode=yes',
      '-o', 'StrictHostKeyChecking=yes',
      '-o', `UserKnownHostsFile=${knownHosts}`,
      '-o', 'ConnectTimeout=10',
      '-o', 'ServerAliveInterval=30',
      '-o', 'ServerAliveCountMax=3',
      ...(identityFile ? ['-i', identityFile, '-o', 'IdentitiesOnly=yes'] : []),
      '-p', port,
      `${user}@${host}`,
    ];
    const processHandle = pty.spawn('/usr/bin/ssh', args, {
      name: 'xterm-256color',
      cols: 110,
      rows: 32,
      cwd: os.homedir(),
      env: { ...process.env, TERM: 'xterm-256color', COLORTERM: 'truecolor' },
    });
    const terminal = {
      id,
      ownerSessionId,
      process: processHandle,
      sockets: new Set(),
      detachedBuffer: '',
      detachTimer: null,
      maxLifetimeTimer: null,
      closed: false,
      target: `${user}@${process.env.NOVA_SSH_DISPLAY_HOST || TAILSCALE_DISPLAY_HOST()}:${port}`,
    };
    terminal.maxLifetimeTimer = setTimeout(() => terminateSession(terminal, 'Tempo máximo da sessão atingido'), 60 * 60 * 1000);
    terminal.maxLifetimeTimer.unref?.();
    processHandle.onData(data => {
      if (terminal.sockets.size) {
        for (const socket of terminal.sockets) send(socket, { type: 'output', data });
      } else {
        terminal.detachedBuffer = `${terminal.detachedBuffer}${data}`.slice(-MAX_DETACHED_BUFFER);
      }
    });
    processHandle.onExit(({ exitCode, signal }) => {
      for (const socket of terminal.sockets) send(socket, { type: 'exit', exitCode, signal });
      terminateSession(terminal, 'Sessão SSH encerrada');
    });
    terminals.set(id, terminal);
    console.log(`[nova-web] terminal SSH criado ${id.slice(0, 8)}`);
    return terminal;
  }

  function TAILSCALE_DISPLAY_HOST() {
    return process.env.NOVA_SSH_HOST === '127.0.0.1'
      ? '127.0.0.1'
      : (process.env.NOVA_SSH_DISPLAY_HOST || '100.117.90.59');
  }

  function attach(socket, terminal, auth) {
    clearTimeout(terminal.detachTimer);
    terminal.detachTimer = null;
    terminal.detachStartTime = null;
    terminal.sockets.add(socket);
    socket.terminal = terminal;
    socket.ownerSessionId = auth.id;
    send(socket, { type: 'ready', sessionId: terminal.id, target: terminal.target, resumed: Boolean(terminal.detachedBuffer) });
    if (terminal.detachedBuffer) {
      send(socket, { type: 'output', data: terminal.detachedBuffer });
      terminal.detachedBuffer = '';
    }
  }

  websocketServer.on('connection', (socket, request, auth, requestedSessionId) => {
    let terminal = requestedSessionId ? terminals.get(requestedSessionId) : null;
    if (terminal && terminal.ownerSessionId !== auth.id) terminal = null;
    try {
      if (!terminal) terminal = spawnTerminal(auth.id);
      attach(socket, terminal, auth);
    } catch (error) {
      send(socket, { type: 'error', message: error.message || 'Falha ao criar terminal' });
      socket.close(1013, 'Terminal indisponível');
      return;
    }

    socket.on('message', raw => {
      if (!authenticate(request) || terminal.closed) return socket.close(1008, 'Sessão inválida');
      let message;
      try { message = JSON.parse(raw.toString()); } catch { return send(socket, { type: 'error', message: 'Mensagem de terminal inválida' }); }
      if (message.type === 'input' && typeof message.data === 'string') {
        if (Buffer.byteLength(message.data) <= MAX_INPUT_SIZE) terminal.process.write(message.data);
      } else if (message.type === 'resize') {
        const cols = Math.max(20, Math.min(300, Number(message.cols) || 80));
        const rows = Math.max(8, Math.min(120, Number(message.rows) || 24));
        terminal.process.resize(cols, rows);
      } else if (message.type === 'close') {
        terminateSession(terminal, 'Encerrada pelo usuário');
      }
    });

    socket.on('close', () => {
      terminal.sockets.delete(socket);
      if (!terminal.closed && terminal.sockets.size === 0) {
        terminal.detachStartTime = Date.now();
        terminal.detachTimer = setTimeout(() => terminateSession(terminal, 'Reconexão expirada'), DETACH_GRACE_MS);
        terminal.detachTimer.unref?.();
      }
    });
    socket.on('error', error => console.warn(`[nova-web] WebSocket terminal: ${error.code || error.name}`));
  });

  function handleUpgrade(request, socket, head) {
    let url;
    try { url = new URL(request.url, `http://${request.headers.host || 'localhost'}`); } catch { return socket.destroy(); }
    if (url.pathname !== '/web-api/terminal') return socket.destroy();
    if (!isAllowedAddress(request.socket.remoteAddress) || !sameOrigin(request)) {
      socket.write('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n');
      return socket.destroy();
    }
    const auth = authenticate(request);
    if (!auth) {
      socket.write('HTTP/1.1 401 Unauthorized\r\nConnection: close\r\n\r\n');
      return socket.destroy();
    }
    websocketServer.handleUpgrade(request, socket, head, websocket => {
      websocketServer.emit('connection', websocket, request, auth, url.searchParams.get('session'));
    });
  }

  server.on('upgrade', handleUpgrade);

  const authSweep = setInterval(() => {
    sweepStaleSessions();
    for (const terminal of terminals.values()) {
      if (!authenticate({ headers: { cookie: `nova_session=${terminal.ownerSessionId}` } })) {
        terminateSession(terminal, 'Sessão NOVA expirada');
      }
    }
  }, 15_000);
  authSweep.unref();
  server.on('close', () => {
    clearInterval(authSweep);
    for (const terminal of [...terminals.values()]) terminateSession(terminal, 'Servidor encerrado');
    websocketServer.close();
  });

  return { terminals, handleUpgrade };
}

module.exports = { attachTerminalServer };
