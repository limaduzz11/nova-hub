/* ═══════════════════════════════════════════════════════════════
   NOVA HUB V5 WEB — LINK Module (Dashboard + Telemetry)
   ═══════════════════════════════════════════════════════════════ */
const LinkModule = (() => {
  let pollTimer = null;
  let feedbackTimer = null;
  let polling = false;
  let active = false;

  function render() {
    active = true;
    const element = document.createElement('div');
    element.className = 'link-module';
    element.innerHTML = `
      <div class="module-header link-header">
        ${Util.moduleHeading('link', 'NOVA Link', 'Telemetria e controle do host principal')}
        <div class="module-header-status">
          <span class="badge badge-todo" id="linkStatus"><span class="status-dot"></span>Conectando…</span>
          <span class="text-xs" id="linkUpdatedAt">Aguardando telemetria</span>
        </div>
        <button class="btn btn-glass btn-sm" id="linkRefresh" type="button">${Util.icon('refresh')}<span>Atualizar</span></button>
      </div>
      <div id="linkFeedback" class="module-toast hidden" role="status" aria-live="polite"></div>
      <div class="link-bento" id="linkContent" aria-live="polite" aria-busy="true">
        <div class="skeleton link-skeleton link-skeleton-wide"></div>
        <div class="skeleton link-skeleton link-skeleton-wide"></div>
        <div class="skeleton link-skeleton"></div>
        <div class="skeleton link-skeleton"></div>
        <div class="skeleton link-skeleton"></div>
        <div class="skeleton link-skeleton"></div>
      </div>`;

    poll();
    pollTimer = setInterval(poll, 7000);
    element.querySelector('#linkRefresh').addEventListener('click', poll);
    return element;
  }

  function destroy() {
    active = false;
    if (pollTimer) clearInterval(pollTimer);
    clearTimeout(feedbackTimer);
    pollTimer = null;
  }

  async function poll() {
    if (polling || !active) return;
    polling = true;
    setRefreshState(true);
    try {
      const telemetry = await API.getTelemetry();
      if (active) update(telemetry);
    } catch (error) {
      if (!active) return;
      const status = document.getElementById('linkStatus');
      if (status) {
        status.innerHTML = '<span class="status-dot"></span>Offline';
        status.className = 'badge badge-standby';
      }
      setFeedback(`Telemetria indisponível: ${error.message}`, 'error');
    } finally {
      polling = false;
      setRefreshState(false);
    }
  }

  function update(telemetry) {
    const status = document.getElementById('linkStatus');
    if (status) {
      status.innerHTML = '<span class="status-dot"></span>Online';
      status.className = 'badge badge-doing';
    }
    const updated = document.getElementById('linkUpdatedAt');
    if (updated) updated.textContent = `Atualizado às ${new Date().toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit', second: '2-digit' })}`;

    const memory = telemetry.memory || {};
    const cpu = telemetry.cpu || {};
    const gpu = telemetry.gpu || {};
    const host = telemetry.host || {};
    const totalGB = Number(memory.total_bytes || 0) / 1e9;
    const usedGB = Number(memory.used_bytes || 0) / 1e9;
    const availableGB = Math.max(0, totalGB - usedGB);
    const ramPercent = totalGB > 0 ? usedGB / totalGB * 100 : Number(memory.usage_percent || 0);
    const disks = Array.isArray(telemetry.disks) ? dedupDisks(telemetry.disks) : [];
    const content = document.getElementById('linkContent');
    if (!content) return;

    content.innerHTML = `
      <section class="glass link-host-card">
        <div class="link-card-topline"><span class="link-card-icon host">${Util.icon('server')}</span><span class="link-live-label"><span></span>HOST ONLINE</span></div>
        <div class="link-host-copy"><h3>POP!_OS <span>— ${Util.escape(host.hostname || 'NOVA')}</span></h3><p>Uptime ${fmtUptime(host.uptime_seconds)} • monitoramento em tempo real</p></div>
        <div class="link-host-actions">
          <button class="btn btn-primary btn-sm" id="wolBtn" type="button">${Util.icon('power')}<span>WOL</span></button>
          <button class="btn btn-danger btn-sm" id="powerOffBtn" type="button">${Util.icon('power')}<span>Desligar</span></button>
        </div>
      </section>

      <section class="glass link-ssh-card">
        <div class="link-card-topline"><span class="link-card-icon">${Util.icon('terminal')}</span><span class="badge badge-doing">INTEGRADO</span></div>
        <h3>SSH Terminal</h3>
        <p class="text-mono">operator@100.64.0.1:22</p>
        <div class="link-connection-row"><span class="status-dot"></span><span>PTY real via canal seguro do HUB</span></div>
        <button class="btn btn-glass btn-sm" id="sshBtn" type="button">${Util.icon('terminal')}<span>Abrir Terminal</span></button>
      </section>

      ${metricCard('CPU', Number(cpu.usage_percent || 0), '%', cpu.temperature_celsius ? `${Number(cpu.temperature_celsius).toFixed(1)}°C` : 'Indisponível', 'cpu')}
      ${metricCard('GPU', Number(gpu.usage_percent || 0), '%', gpu.temperature_celsius ? `${Number(gpu.temperature_celsius).toFixed(1)}°C • ${gpu.name || 'GPU'}` : gpu.name || 'Indisponível', 'cpu')}
      ${metricCard('RAM', ramPercent, '%', `${usedGB.toFixed(1)} GB usados • ${availableGB.toFixed(1)} GB livres`, 'memory')}
      ${disks.map(diskCard).join('')}
    `;
    content.setAttribute('aria-busy', 'false');
    bindActions();
  }

  function metricCard(title, value, unit, detail, icon) {
    const safeValue = Math.max(0, Math.min(100, Number(value) || 0));
    const color = barColor(safeValue);
    return `<article class="glass link-metric-card" style="--metric-value:${safeValue};--metric-color:${color}">
      <div class="link-card-topline"><span class="link-card-icon compact">${Util.icon(icon)}</span><span class="link-metric-state">${metricState(safeValue)}</span></div>
      <div class="link-metric-main"><div><strong>${safeValue.toFixed(1)}<small>${unit}</small></strong></div><div class="metric-ring" aria-label="${safeValue.toFixed(1)} por cento"><span>${Math.round(safeValue)}</span></div></div>
      <div class="progress-track"><div class="progress-fill" style="width:${safeValue}%;background:${color};color:${color}"></div></div>
      <p>${Util.escape(detail)}</p>
    </article>`;
  }

  function diskCard(disk) {
    const percent = Math.max(0, Math.min(100, Number(disk.percent || 0)));
    const total = Number(disk.total_gb || 0);
    const used = Number(disk.used_gb || 0);
    const free = Math.max(0, total - used);
    const color = barColor(percent);
    const info = diskIdentity(disk.mount);
    return `<article class="glass link-disk-card${percent >= 90 ? ' is-critical' : percent >= 75 ? ' is-warning' : ''}" style="--metric-color:${color}">
      <div class="link-card-topline"><span class="link-card-icon compact">${Util.icon('storage')}</span><span class="link-disk-percent">${percent.toFixed(1)}%</span></div>
      <h3>${Util.escape(info.name)}</h3><p class="text-mono" title="${Util.escape(disk.mount || '')}">${Util.escape(info.path)}</p>
      <div class="progress-track"><div class="progress-fill" style="width:${percent}%;background:${color};color:${color}"></div></div>
      <div class="link-disk-stats"><span><strong>${used.toFixed(1)}</strong> GB usados</span><span><strong>${free.toFixed(1)}</strong> GB livres</span><span><strong>${total.toFixed(0)}</strong> GB total</span></div>
    </article>`;
  }

  function bindActions() {
    document.getElementById('wolBtn')?.addEventListener('click', async event => {
      setButtonBusy(event.currentTarget, true, 'Enviando…');
      try {
        await API.wol();
        setFeedback('Comando Wake-on-LAN enviado.', 'success');
      } catch (error) {
        setFeedback(`Falha no WOL: ${error.message}`, 'error');
      } finally {
        setButtonBusy(event.currentTarget, false);
      }
    });
    document.getElementById('powerOffBtn')?.addEventListener('click', async event => {
      if (!confirm('Confirmar desligamento do PC?')) return;
      setButtonBusy(event.currentTarget, true, 'Enviando…');
      try {
        await API.powerOff();
        setFeedback('Comando de desligamento enviado.', 'success');
      } catch (error) {
        setFeedback(`Falha ao desligar: ${error.message}`, 'error');
      } finally {
        setButtonBusy(event.currentTarget, false);
      }
    });
    document.getElementById('sshBtn')?.addEventListener('click', () => {
      TerminalModule.open();
    });
  }

  function dedupDisks(disks) {
    const seen = new Map();
    for (const d of disks) {
      const key = `${d.mount}|${d.total_gb}|${d.used_gb}`;
      if (!seen.has(key)) seen.set(key, d);
    }
    return Array.from(seen.values()).slice(0, 4);
  }

  function diskIdentity(mount = '') {
    if (mount === '/') return { name: 'Sistema principal', path: '/' };
    if (mount === '/boot/efi') return { name: 'Partição EFI', path: mount };
    if (String(mount).toLowerCase().includes('steam')) return { name: 'Biblioteca Steam', path: mount };
    return { name: 'Volume de dados', path: mount || 'Caminho indisponível' };
  }

  function barColor(value) {
    if (value > 90) return 'var(--state-error)';
    if (value > 70) return 'var(--state-warning)';
    return 'var(--state-success)';
  }

  function metricState(value) {
    if (value > 90) return 'Crítico';
    if (value > 70) return 'Atenção';
    if (value > 45) return 'Moderado';
    return 'Estável';
  }

  function fmtUptime(seconds) {
    const value = Number(seconds || 0);
    if (!value || value > 315360000) return 'indisponível';
    const days = Math.floor(value / 86400);
    const hours = Math.floor((value % 86400) / 3600);
    const minutes = Math.floor((value % 3600) / 60);
    return days > 0 ? `${days}d ${hours}h` : `${hours}h ${minutes}m`;
  }

  function setRefreshState(loading) {
    const button = document.getElementById('linkRefresh');
    if (!button) return;
    button.disabled = loading;
    button.classList.toggle('is-loading', loading);
    button.setAttribute('aria-busy', String(loading));
  }

  function setButtonBusy(button, busy, label = '') {
    if (!button) return;
    if (!button.dataset.originalHtml) button.dataset.originalHtml = button.innerHTML;
    button.disabled = busy;
    if (busy) button.innerHTML = `<span class="spinner button-spinner"></span><span>${Util.escape(label)}</span>`;
    else button.innerHTML = button.dataset.originalHtml;
  }

  function setFeedback(message, type) {
    const element = document.getElementById('linkFeedback');
    if (!element) return;
    clearTimeout(feedbackTimer);
    element.textContent = message;
    element.dataset.type = type;
    element.classList.remove('hidden');
    feedbackTimer = setTimeout(() => element.classList.add('hidden'), 4500);
  }

  return { render, destroy };
})();
