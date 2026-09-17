/* NOVA HUB V5 WEB — terminal SSH real: xterm.js + WebSocket + PTY no servidor. */
const TerminalModule = (() => {
  let overlay = null;
  let terminal = null;
  let fitAddon = null;
  let socket = null;
  let resizeObserver = null;
  let reconnectTimer = null;
  let intentionalClose = false;
  let ctrlArmed = false;
  let terminalTarget = '';

  function computeFontSize() {
    const w = window.innerWidth || 1200;
    if (w <= 520) return 13;
    if (w <= 768) return 14;
    if (w <= 1100) return 15;
    if (w <= 1440) return 16;
    if (w <= 1920) return 17;
    return 18;
  }

  function open() {
    if (!window.Terminal || !window.FitAddon?.FitAddon) {
      alert('Componente de terminal indisponível. Recarregue o NOVA HUB.');
      return;
    }
    if (!overlay) createOverlay();
    overlay.classList.remove('hidden');
    intentionalClose = false;
    requestAnimationFrame(() => {
      fit();
      connect();
      terminal.focus();
    });
  }

  function createOverlay() {
    overlay = document.createElement('section');
    overlay.id = 'novaTerminalOverlay';
    overlay.className = 'nova-terminal-overlay hidden';
    overlay.setAttribute('aria-label', 'Terminal SSH NOVA Link');
    overlay.innerHTML = `
      <div class="nova-terminal-shell">
        <header class="nova-terminal-header">
          <div class="nova-terminal-title"><span>${Util.icon('terminal')}</span><div><strong>SSH Terminal</strong><small id="terminalTarget">Conectando ao ambiente NOVA</small></div></div>
          <span class="nova-terminal-status" id="terminalStatus" data-state="connecting"><i></i>Conectando…</span>
          <div class="nova-terminal-actions">
            <button class="btn btn-glass btn-sm" id="terminalReconnect" type="button">${Util.icon('refresh')}<span>Reconectar</span></button>
            <button class="btn btn-glass btn-sm" id="terminalClear" type="button">${Util.icon('close')}<span>Limpar</span></button>
            <button class="btn btn-glass btn-icon" id="terminalClose" type="button" aria-label="Fechar terminal">${Util.icon('close')}</button>
          </div>
        </header>
        <div class="nova-terminal-screen" id="terminalScreen"></div>
        <div class="nova-terminal-keys" aria-label="Teclas auxiliares">
          <button type="button" data-terminal-key="CTRL">CTRL</button><button type="button" data-terminal-key="\t">TAB</button><button type="button" data-terminal-key="\u001b">ESC</button>
          <button type="button" data-terminal-key="\u001b[A">↑</button><button type="button" data-terminal-key="\u001b[B">↓</button><button type="button" data-terminal-key="\u001b[D">←</button><button type="button" data-terminal-key="\u001b[C">→</button>
          <button type="button" data-terminal-key="/">/</button><button type="button" data-terminal-key="c">C</button><button type="button" data-terminal-key="d">D</button><button type="button" data-terminal-key="l">L</button>
        </div>
        <footer class="nova-terminal-statusbar" id="terminalStatusBar">
          <span id="statusbarLeft">SSH • Conectando…</span>
          <span id="statusbarRight">UTF-8 • PTY</span>
        </footer>
      </div>`;
    document.body.appendChild(overlay);

    const fontSize = computeFontSize();
    terminal = new window.Terminal({
      cursorBlink: true,
      cursorStyle: 'bar',
      convertEol: false,
      scrollback: 10000,
      fontFamily: 'JetBrains Mono, ui-monospace, SFMono-Regular, Consolas, monospace',
      fontSize,
      lineHeight: 1.2,
      allowProposedApi: false,
      disableStdin: false,
      sendMouseEvents: false,
      theme: {
        background: '#050B14', foreground: '#FFFFFF', cursor: '#7FB4FF', selectionBackground: '#5C8CFF48',
        black: '#050B14', red: '#D95345', green: '#6FE090', yellow: '#A78BFA', blue: '#7FB4FF', magenta: '#8BB9D7', cyan: '#94A8BE', white: '#FFFFFF',
        brightBlack: '#6B7B8D', brightRed: '#FF7568', brightGreen: '#65D685', brightYellow: '#C4B5FD', brightBlue: '#5C8CFF', brightMagenta: '#94A8BE', brightCyan: '#B0C4DE', brightWhite: '#FFFFFF',
      },
    });
    fitAddon = new window.FitAddon.FitAddon();
    terminal.loadAddon(fitAddon);
    terminal.open(overlay.querySelector('#terminalScreen'));
    terminal.onData(data => sendInput(applyCtrl(data)));
    terminal.onResize(({ cols, rows }) => {
      send({ type: 'resize', cols, rows });
      updateStatusBar(cols, rows);
    });

    overlay.querySelector('#terminalClose').addEventListener('click', close);
    overlay.querySelector('#terminalReconnect').addEventListener('click', () => connect(true));
    overlay.querySelector('#terminalClear').addEventListener('click', () => { terminal.clear(); terminal.focus(); });
    overlay.querySelectorAll('[data-terminal-key]').forEach(button => button.addEventListener('click', () => auxiliaryKey(button)));
    resizeObserver = new ResizeObserver(fit);
    resizeObserver.observe(overlay.querySelector('#terminalScreen'));
  }

  function applyCtrl(data) {
    if (!ctrlArmed || data.length !== 1) return data;
    ctrlArmed = false;
    updateCtrlButton();
    const code = data.toUpperCase().charCodeAt(0);
    return code >= 64 && code <= 95 ? String.fromCharCode(code - 64) : data;
  }

  function auxiliaryKey(button) {
    const value = button.dataset.terminalKey;
    if (value === 'CTRL') {
      ctrlArmed = !ctrlArmed;
      updateCtrlButton();
    } else {
      sendInput(applyCtrl(value));
      terminal.focus();
    }
  }

  function updateCtrlButton() {
    overlay?.querySelector('[data-terminal-key="CTRL"]')?.classList.toggle('active', ctrlArmed);
  }

  function connect(forceNew = false) {
    clearTimeout(reconnectTimer);
    if (socket && [WebSocket.OPEN, WebSocket.CONNECTING].includes(socket.readyState)) socket.close();
    setStatus('connecting', 'Conectando…');
    updateStatusBarText('SSH • Conectando…');
    const sessionId = forceNew ? '' : sessionStorage.getItem('novaTerminalSession') || '';
    if (forceNew) sessionStorage.removeItem('novaTerminalSession');
    const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
    const query = sessionId ? `?session=${encodeURIComponent(sessionId)}` : '';
    socket = new WebSocket(`${protocol}//${location.host}/web-api/terminal${query}`);
    socket.addEventListener('open', () => {
      setStatus('connected', 'Conectado');
      fit();
      sendCurrentSize();
    });
    socket.addEventListener('message', event => {
      let message;
      try { message = JSON.parse(event.data); } catch { return; }
      if (message.type === 'output') terminal.write(message.data);
      if (message.type === 'ready') {
        sessionStorage.setItem('novaTerminalSession', message.sessionId);
        terminalTarget = message.target || 'Ambiente NOVA';
        overlay.querySelector('#terminalTarget').textContent = terminalTarget;
        setStatus('connected', message.resumed ? 'Reconectado' : 'Conectado');
        sendCurrentSize();
        updateStatusBarText(`SSH • ${terminalTarget}`);
      }
      if (message.type === 'error') {
        setStatus('error', 'Erro');
        terminal.writeln(`\r\n\x1b[31m[NOVA] ${message.message}\x1b[0m`);
      }
      if (message.type === 'exit') {
        setStatus('disconnected', 'Encerrado');
        sessionStorage.removeItem('novaTerminalSession');
        updateStatusBarText('SSH • Encerrado');
      }
    });
    socket.addEventListener('close', event => {
      socket = null;
      if (event.code === 1008) sessionStorage.removeItem('novaTerminalSession');
      if (!intentionalClose && !overlay.classList.contains('hidden')) {
        setStatus('disconnected', 'Desconectado');
      }
    });
    socket.addEventListener('error', () => {
      setStatus('error', 'Falha de conexão');
      terminal.writeln('\r\n\x1b[31m[NOVA] Não foi possível abrir o canal seguro do terminal.\x1b[0m');
    });
  }

  function send(message) {
    if (socket?.readyState === WebSocket.OPEN) socket.send(JSON.stringify(message));
  }
  function sendInput(data) { if (data) send({ type: 'input', data }); }
  function fit() {
    if (!overlay || overlay.classList.contains('hidden')) return;
    try { fitAddon.fit(); } catch {}
  }
  function sendCurrentSize() {
    if (terminal) send({ type: 'resize', cols: terminal.cols, rows: terminal.rows });
    if (terminal) updateStatusBar(terminal.cols, terminal.rows);
  }
  function setStatus(state, label) {
    const status = overlay?.querySelector('#terminalStatus');
    if (!status) return;
    status.dataset.state = state;
    status.innerHTML = `<i></i>${Util.escape(label)}`;
  }
  function updateStatusBar(cols, rows) {
    const right = overlay?.querySelector('#statusbarRight');
    if (right) right.textContent = `UTF-8 • PTY • ${cols}×${rows}`;
  }
  function updateStatusBarText(text) {
    const left = overlay?.querySelector('#statusbarLeft');
    if (left) left.textContent = text;
  }
  function close() {
    intentionalClose = true;
    overlay?.classList.add('hidden');
    socket?.close();
    socket = null;
  }

  return { open, close };
})();
