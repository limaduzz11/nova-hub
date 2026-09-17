/* ═══════════════════════════════════════════════════════════════
   NOVA HUB V5 WEB — SETTINGS Module
   ═══════════════════════════════════════════════════════════════ */
const SettingsModule = (() => {
  let active = false;
  let refreshSequence = 0;

  function render() {
    active = true;
    const element = document.createElement('div');
    element.className = 'settings-module';
    element.innerHTML = `
      <div class="module-header settings-header">
        ${Util.moduleHeading('settings', 'Settings', 'Sessão, serviços e diagnóstico do ambiente')}
        <span id="settingsUpdatedAt" class="text-xs">Aguardando diagnóstico…</span>
        <button id="settingsRefresh" class="btn btn-glass btn-sm" type="button">${Util.icon('refresh')}<span>Atualizar</span></button>
      </div>

      <div class="settings-grid">
        <section class="glass settings-card settings-session-card">
          <div class="settings-card-heading"><span class="settings-card-icon">${Util.icon('user')}</span><div><h3>Sessão</h3><p>Identidade e acesso atual</p></div><span class="settings-heading-status is-online">ATIVA</span></div>
          <div class="settings-rows">
            ${settingRow('Usuário', 'settingsUsername', Auth.username || '—')}
            ${settingRow('Sessão', 'settingsSessionStatus', 'Autenticada', 'online')}
            ${settingRow('Canal', 'settingsChannel', 'Cookie HttpOnly')}
          </div>
          <button class="btn btn-danger btn-sm settings-card-action" id="settingsLogout" type="button">${Util.icon('logout')}<span>Encerrar sessão</span></button>
        </section>

        <section class="glass settings-card settings-services-card">
          <div class="settings-card-heading"><span class="settings-card-icon">${Util.icon('server')}</span><div><h3>Serviços</h3><p>Diagnóstico somente leitura</p></div><span class="settings-heading-status">LIVE</span></div>
          <div class="settings-rows">
            ${settingRow('NOVA HUB WEB', 'settingsWebStatus', 'Online', 'online')}
            ${settingRow('NOVA Nexus', 'settingsNexusStatus', 'Verificando…', 'loading')}
            ${settingRow('Sunshine', 'settingsSunshineStatus', 'Verificando…', 'loading')}
            ${settingRow('Navegador', 'settingsBrowserStatus', navigator.onLine ? 'Online' : 'Offline', navigator.onLine ? 'online' : 'offline')}
          </div>
        </section>

        <section class="glass settings-card settings-security-card">
          <div class="settings-card-heading"><span class="settings-card-icon">${Util.icon('shield')}</span><div><h3>Segurança</h3><p>Controles ativos no web</p></div><span class="settings-heading-status is-online">5/5</span></div>
          <ul class="settings-check-list">
            <li><span>${Util.icon('check')}</span> Sessão HttpOnly e SameSite=Strict</li>
            <li><span>${Util.icon('check')}</span> CSRF nas operações de escrita</li>
            <li><span>${Util.icon('check')}</span> CSP e frame-ancestors bloqueado</li>
            <li><span>${Util.icon('check')}</span> Chave Nexus ausente do navegador</li>
            <li><span>${Util.icon('check')}</span> Listener restrito à Tailscale</li>
          </ul>
        </section>

        <section class="glass settings-card settings-product-card">
          <div class="settings-card-heading"><span class="settings-card-icon">${Util.icon('settings')}</span><div><h3>NOVA HUB V5 WEB</h3><p>ELP TECH • Midnight Navy</p></div><span class="settings-heading-status">V5</span></div>
          <div class="settings-rows">
            ${settingRow('Versão', 'settingsVersion', '0.5.0')}
            ${settingRow('Endereço', 'settingsAddress', window.location.host)}
            ${settingRow('Rede', 'settingsNetwork', 'Tailscale VPN')}
            ${settingRow('Dados', 'settingsDataSource', 'Nexus/SQLite oficial')}
          </div>
          <div class="settings-note">O projeto web não possui banco próprio e o Android permanece congelado.</div>
        </section>
      </div>`;

    element.querySelector('#settingsRefresh').addEventListener('click', refresh);
    element.querySelector('#settingsLogout').addEventListener('click', async () => {
      await Auth.logout();
      location.reload();
    });
    window.addEventListener('online', updateBrowserStatus);
    window.addEventListener('offline', updateBrowserStatus);
    refresh();
    return element;
  }

  function settingRow(label, id, value, state = '') {
    return `<div class="settings-row"><span>${Util.escape(label)}</span><strong id="${id}"${state ? ` data-state="${state}"` : ''}>${Util.escape(value)}</strong></div>`;
  }

  async function refresh() {
    const sequence = ++refreshSequence;
    const button = document.getElementById('settingsRefresh');
    if (button) {
      if (!button.dataset.originalHtml) button.dataset.originalHtml = button.innerHTML;
      button.disabled = true;
      button.innerHTML = '<span class="spinner button-spinner"></span><span>Atualizando…</span>';
    }
    setStatus('settingsNexusStatus', 'Verificando…', 'loading');
    setStatus('settingsSunshineStatus', 'Verificando…', 'loading');

    const [nexusResult, moonlightResult] = await Promise.allSettled([
      API.health(),
      API.getMoonlightStatus(),
    ]);
    if (!active || sequence !== refreshSequence) return;

    setStatus('settingsNexusStatus', nexusResult.status === 'fulfilled' ? 'Online' : 'Indisponível', nexusResult.status === 'fulfilled' ? 'online' : 'offline');
    if (moonlightResult.status === 'fulfilled') {
      const online = moonlightResult.value.sunshine === 'online';
      setStatus('settingsSunshineStatus', online ? 'Online' : 'Não detectado', online ? 'online' : 'offline');
    } else {
      setStatus('settingsSunshineStatus', 'Indisponível', 'offline');
    }
    updateBrowserStatus();
    const updated = document.getElementById('settingsUpdatedAt');
    if (updated) updated.textContent = `Atualizado às ${new Date().toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit', second: '2-digit' })}`;
    if (button) { button.disabled = false; button.innerHTML = button.dataset.originalHtml; }
  }

  function setStatus(id, text, state) {
    const element = document.getElementById(id);
    if (!element) return;
    element.textContent = text;
    element.dataset.state = state;
  }

  function updateBrowserStatus() {
    setStatus('settingsBrowserStatus', navigator.onLine ? 'Online' : 'Offline', navigator.onLine ? 'online' : 'offline');
  }

  function destroy() {
    active = false;
    refreshSequence++;
    window.removeEventListener('online', updateBrowserStatus);
    window.removeEventListener('offline', updateBrowserStatus);
  }

  return { render, destroy };
})();
