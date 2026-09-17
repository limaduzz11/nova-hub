/* ═══════════════════════════════════════════════════════════════
   NOVA HUB V5 WEB — NEXUS Module
   ═══════════════════════════════════════════════════════════════ */
const NexusModule = (() => {
  const STATUSES = [
    { key: 'todo', label: 'NA FILA', short: 'Fila', color: '#7FB4FF', badge: 'badge-todo' },
    { key: 'doing', label: 'ATUANDO', short: 'Atuando', color: '#6FE090', badge: 'badge-doing' },
    { key: 'standby', label: 'STANDBY', short: 'Standby', color: '#A78BFA', badge: 'badge-standby' },
    { key: 'concluded', label: 'CONCLUÍDO', short: 'Concluído', color: '#94A8BE', badge: 'badge-concluded' },
  ];

  let workspaces = [];
  let currentWs = null;
  let preferredWorkspaceId = null;
  let items = [];
  let active = false;
  let feedbackTimer = null;
  const filters = { query: '', statuses: new Set(), tag: '', type: '', sev: '', sort: 'recent' };

  function render() {
    active = true;
    filters.query = '';
    filters.statuses.clear();
    filters.tag = '';
    filters.type = '';
    filters.sev = '';
    filters.sort = 'recent';

    const element = document.createElement('div');
    element.className = 'nexus-module';
    element.innerHTML = `
      <div class="module-header nexus-header">
        ${Util.moduleHeading('nexus', 'NOVA Nexus', 'Workspaces, tarefas e fluxo operacional')}
        <div class="module-header-actions nexus-header-actions">
          <label class="nexus-workspace-control"><span>Workspace</span><select id="wsSelector" class="input nexus-workspace-select" aria-label="Workspace atual"></select></label>
          <select id="nexusSortSelect" class="input nexus-sort-select" aria-label="Ordenar tarefas">
            <option value="recent">Recentes</option>
            <option value="oldest">Antigos</option>
            <option value="title">Título A–Z</option>
            <option value="due">Prazo</option>
            <option value="priority">Prioridade</option>
          </select>
          <button class="btn btn-glass btn-sm active" id="nexusFiltersToggle" type="button" aria-expanded="true">${Util.icon('filter')}<span>Filtros</span></button>
          <button class="btn btn-glass btn-sm" id="nexusExport" type="button">${Util.icon('export')}<span>Exportar</span></button>
          <button class="btn btn-glass btn-sm" id="nexusSync" type="button" data-tooltip="Sincronizar chamados do Qualitor">${Util.icon('refresh')}<span>Sync</span></button>
          <button class="btn btn-primary btn-sm" id="nexusCreate" type="button">${Util.icon('plus')}<span>Nova Tarefa</span></button>
        </div>
      </div>

      <section class="glass nexus-controls" aria-label="Busca e filtros do Nexus">
        <div class="nexus-filter-row">
          <label class="nexus-search-field">
            <span class="sr-only">Buscar tarefas</span>
            <span class="input-leading-icon">${Util.icon('search')}</span>
            <input id="nexusSearch" class="input" type="search" placeholder="Buscar por título, descrição ou tag…" autocomplete="off">
          </label>
          <select id="nexusTypeFilter" class="input nexus-filter-select" aria-label="Filtrar por tipo">
            <option value="">Todos os tipos</option>
          </select>
          <select id="nexusTagFilter" class="input nexus-filter-select" aria-label="Filtrar por tag">
            <option value="">Todas as tags</option>
          </select>
          <button id="nexusClearFilters" class="btn btn-glass btn-sm" type="button" disabled>${Util.icon('close')}<span>Limpar</span></button>
        </div>
        <div class="nexus-filter-footer">
          <div id="nexusSevFilters" class="nexus-sev-filters" aria-label="Filtrar por severidade">
            <button class="chip nexus-sev-chip" type="button" data-sev="alta" aria-pressed="false">Alta</button>
            <button class="chip nexus-sev-chip" type="button" data-sev="media" aria-pressed="false">Média</button>
            <button class="chip nexus-sev-chip" type="button" data-sev="baixa" aria-pressed="false">Baixa</button>
            <span class="nexus-sev-sep" aria-hidden="true"></span>
            <div id="nexusStatusFilters" class="nexus-status-filters" aria-label="Filtrar por status">
              ${STATUSES.map(status => `
                <button class="chip nexus-filter-chip" type="button" data-status="${status.key}" aria-pressed="false">
                  ${status.label} <span data-count="${status.key}">0</span>
                </button>
              `).join('')}
            </div>
          </div>
          <span id="nexusResultSummary" class="text-xs" aria-live="polite">Carregando tarefas…</span>
        </div>
        <div id="nexusFeedback" class="nexus-feedback hidden" role="status" aria-live="polite"></div>
      </section>

      <div id="nexusSummary" class="nexus-summary" aria-live="polite" aria-label="Resumo operacional"></div>

      <div class="nexus-board is-kanban" id="nexusColumns" aria-live="polite">
        <div class="state-box"><span class="spinner"></span><span class="desc">Carregando Nexus…</span></div>
      </div>

      ${createDialogMarkup()}
      ${editDialogMarkup()}
      ${exportDialogMarkup()}
    `;

    bindEvents(element);
    load();
    return element;
  }

  function createDialogMarkup() {
    return `
      <div id="nexusCreateDialog" class="nova-modal hidden" role="dialog" aria-modal="true" aria-labelledby="nexusCreateTitle">
        <div class="glass nova-modal-card">
          <div class="nova-modal-header">
            <h3 id="nexusCreateTitle" class="h4">Nova tarefa</h3>
            <button class="btn btn-glass btn-icon" type="button" data-close-dialog="nexusCreateDialog" aria-label="Fechar">${Util.icon('close')}</button>
          </div>
          <div class="nova-form-stack">
            <label class="form-group"><span>Título</span><input id="newTaskTitle" class="input" maxlength="240" required></label>
            <label class="form-group"><span>Descrição</span><textarea id="newTaskBody" class="input" rows="4"></textarea></label>
            <div class="nova-form-grid">
              <label class="form-group"><span>Tipo</span><select id="newTaskType" class="input"><option value="task">Tarefa</option><option value="note">Nota</option></select></label>
              <label class="form-group"><span>Status</span><select id="newTaskStatus" class="input">${statusOptions()}</select></label>
            </div>
            <label class="form-group"><span>Tags (separadas por vírgula)</span><input id="newTaskTags" class="input"></label>
            <label class="form-group"><span>Prazo</span><input id="newTaskDue" class="input" type="date"></label>
          </div>
          <div class="nova-modal-actions">
            <button class="btn btn-glass btn-sm" type="button" data-close-dialog="nexusCreateDialog">Cancelar</button>
            <button class="btn btn-primary btn-sm" type="button" id="confirmCreate">${Util.icon('check')}<span>Salvar</span></button>
          </div>
        </div>
      </div>`;
  }

  function editDialogMarkup() {
    return `
      <div id="nexusEditDialog" class="nova-modal hidden" role="dialog" aria-modal="true" aria-labelledby="nexusEditTitle">
        <div class="glass nova-modal-card nexus-detail-card">
          <div class="nova-modal-header nexus-detail-header">
            <div class="nexus-detail-header-left">
              <span id="detailBadge" class="badge"></span>
              <div><h3 id="nexusEditTitle" class="h4 nexus-detail-title"></h3><div id="editTaskMeta" class="text-xs nexus-detail-meta"></div></div>
            </div>
            <button class="btn btn-glass btn-icon" type="button" data-close-dialog="nexusEditDialog" aria-label="Fechar">${Util.icon('close')}</button>
          </div>
          <input id="editTaskId" type="hidden">
          <div class="nexus-detail-body">
            <div class="nexus-detail-tabs">
              <button class="nexus-detail-tab active" data-tab="info">Informações</button>
              <button class="nexus-detail-tab" data-tab="description">Descrição</button>
              <button class="nexus-detail-tab" data-tab="history">Atendimentos</button>
            </div>
            <div id="tabInfo" class="nexus-detail-tab-content active">
              <div class="nexus-detail-grid">
                <div class="nexus-detail-field" style="grid-column:1/-1"><label>Título</label><input id="editTaskTitleInput" class="input" maxlength="240" required></div>
                <div class="nexus-detail-field" style="grid-column:1/-1"><label>Descrição</label><textarea id="editTaskBody" class="input" rows="5"></textarea></div>
                <div class="nexus-detail-field"><label>Status</label><select id="editTaskStatus" class="input">${statusOptions()}</select></div>
                <div class="nexus-detail-field"><label>Prazo</label><input id="editTaskDue" class="input" type="date"></div>
                <div class="nexus-detail-field"><label>Tags</label><input id="editTaskTags" class="input" placeholder="separadas por vírgula"></div>
              </div>
              <div id="detailQualitorInfo" class="nexus-detail-qualitor-info"></div>
            </div>
            <div id="tabDescription" class="nexus-detail-tab-content">
              <div id="detailDescription" class="nexus-detail-description"></div>
            </div>
            <div id="tabHistory" class="nexus-detail-tab-content">
              <div id="detailHistory" class="nexus-detail-history"></div>
            </div>
          </div>
          <div class="nova-modal-actions">
            <button class="btn btn-glass btn-sm" type="button" data-close-dialog="nexusEditDialog">Fechar</button>
            <button class="btn btn-primary btn-sm" type="button" id="confirmEdit">${Util.icon('check')}<span>Salvar</span></button>
          </div>
        </div>
      </div>`;
  }

  function exportDialogMarkup() {
    return `
      <div id="nexusExportDialog" class="nova-modal hidden" role="dialog" aria-modal="true" aria-labelledby="nexusExportTitle">
        <div class="glass nova-modal-card nova-modal-card-sm">
          <div class="nova-modal-header">
            <div><h3 id="nexusExportTitle" class="h4">Exportar tarefas</h3><div class="text-xs">O relatório usa os dados do workspace atual.</div></div>
            <button class="btn btn-glass btn-icon" type="button" data-close-dialog="nexusExportDialog" aria-label="Fechar">${Util.icon('close')}</button>
          </div>
          <div class="nova-form-stack">
            <label class="form-group"><span>Formato</span>
              <select id="nexusExportFormat" class="input">
                <option value="png">Imagem PNG</option>
                <option value="pdf">PDF / Imprimir</option>
              </select>
            </label>
            <fieldset class="nova-fieldset">
              <legend>Status incluídos</legend>
              <div class="nexus-export-statuses">
                ${STATUSES.map(status => `<label class="chip"><input type="checkbox" name="exportStatus" value="${status.key}" checked> ${status.label}</label>`).join('')}
              </div>
            </fieldset>
            <div class="nexus-export-options">
              <label><input id="exportIncludeDone" type="checkbox" checked> Incluir concluídas</label>
              <label><input id="exportIncludeTags" type="checkbox" checked> Incluir tags</label>
              <label><input id="exportIncludeDates" type="checkbox" checked> Incluir datas</label>
            </div>
          </div>
          <div class="nova-modal-actions">
            <button class="btn btn-glass btn-sm" type="button" data-close-dialog="nexusExportDialog">Cancelar</button>
            <button class="btn btn-primary btn-sm" type="button" id="confirmExport">${Util.icon('export')}<span>Gerar relatório</span></button>
          </div>
        </div>
      </div>`;
  }

  function statusOptions(selected = '') {
    return STATUSES.map(status => `<option value="${status.key}"${selected === status.key ? ' selected' : ''}>${status.label}</option>`).join('');
  }

  function bindEvents(element) {
    element.querySelector('#wsSelector').addEventListener('change', event => {
      currentWs = workspaces.find(workspace => String(workspace.id) === event.target.value) || null;
      preferredWorkspaceId = currentWs?.id || null;
      loadItems();
    });
    element.querySelector('#nexusCreate').addEventListener('click', () => openDialog('nexusCreateDialog', '#newTaskTitle'));
    element.querySelector('#nexusExport').addEventListener('click', () => openDialog('nexusExportDialog', '#nexusExportFormat'));
    element.querySelector('#nexusSync').addEventListener('click', syncQualitor);
    element.querySelector('#nexusFiltersToggle').addEventListener('click', event => {
      const controls = element.querySelector('.nexus-controls');
      const collapsed = controls.classList.toggle('is-collapsed');
      event.currentTarget.setAttribute('aria-expanded', String(!collapsed));
      event.currentTarget.classList.toggle('active', !collapsed);
    });
    element.querySelector('#confirmCreate').addEventListener('click', createItem);
    element.querySelector('#confirmEdit').addEventListener('click', saveItem);
    element.querySelector('#confirmExport').addEventListener('click', exportItems);

    element.querySelector('#nexusSearch').addEventListener('input', event => {
      filters.query = event.target.value;
      renderColumns();
    });
    element.querySelector('#nexusTypeFilter').addEventListener('change', event => {
      filters.type = event.target.value;
      renderColumns();
    });
    element.querySelector('#nexusTagFilter').addEventListener('change', event => {
      filters.tag = event.target.value;
      renderColumns();
    });
    element.querySelector('#nexusClearFilters').addEventListener('click', clearFilters);
    element.querySelector('#nexusSortSelect').addEventListener('change', event => {
      filters.sort = event.target.value;
      renderColumns();
    });
    element.querySelectorAll('.nexus-sev-chip').forEach(button => {
      button.addEventListener('click', () => {
        const sev = button.dataset.sev;
        filters.sev = filters.sev === sev ? '' : sev;
        renderColumns();
      });
    });
    element.querySelectorAll('.nexus-filter-chip').forEach(button => {
      button.addEventListener('click', () => {
        const status = button.dataset.status;
        if (filters.statuses.has(status)) filters.statuses.delete(status);
        else filters.statuses.add(status);
        renderColumns();
      });
    });
    element.querySelectorAll('[data-close-dialog]').forEach(button => {
      button.addEventListener('click', () => closeDialog(button.dataset.closeDialog));
    });
    element.querySelectorAll('.nova-modal').forEach(modal => {
      modal.addEventListener('mousedown', event => {
        if (event.target === modal) closeDialog(modal.id);
      });
    });
    element.addEventListener('keydown', event => {
      if (event.key === 'Escape') element.querySelectorAll('.nova-modal:not(.hidden)').forEach(modal => closeDialog(modal.id));
    });
  }

  async function load() {
    try {
      const previousId = preferredWorkspaceId || currentWs?.id;
      const response = await API.listWorkspaces();
      if (!active) return;
      workspaces = (Array.isArray(response) ? response : []).filter(workspace => workspace.name !== 'sfsf');
      const selector = document.getElementById('wsSelector');
      if (!selector) return;
      selector.innerHTML = workspaces.map(workspace => `<option value="${Util.escape(workspace.id)}">${Util.escape(workspace.name)}</option>`).join('');
      currentWs = workspaces.find(workspace => workspace.id === previousId) || workspaces[0] || null;
      if (currentWs) {
        preferredWorkspaceId = currentWs.id;
        selector.value = String(currentWs.id);
        await loadItems();
      } else {
        items = [];
        renderColumns();
        setFeedback('Nenhum workspace disponível.', 'warning');
      }
    } catch (error) {
      if (active) {
        renderLoadError(error);
        setFeedback(error.message, 'error');
      }
    }
  }

  function renderSkeleton() {
    const board = document.getElementById('nexusColumns');
    if (!board) return;
    board.innerHTML = STATUSES.map(status => `
      <section class="glass nexus-column nexus-column-skeleton" style="--column-color:${status.color}">
        <header class="nexus-column-header">
          <span class="nexus-column-marker" aria-hidden="true"></span>
          <span class="nexus-skeleton-line" style="width:74px"></span>
          <span class="nexus-skeleton-line nexus-skeleton-pill"></span>
        </header>
        <div class="nexus-column-items">
          ${[1, 2, 3].map(() => '<div class="nexus-skeleton-card"></div>').join('')}
        </div>
      </section>`).join('');
  }

  async function loadItems() {
    if (!currentWs || !active) return;
    const board = document.getElementById('nexusColumns');
    if (board) renderSkeleton();
    try {
      const response = await API.listItems(currentWs.id);
      if (!active) return;
      items = (Array.isArray(response) ? response : []).filter(item => !item.deleted_at);
      refreshFilterOptions();
      renderColumns();
    } catch (error) {
      if (active) {
        renderLoadError(error);
        setFeedback(error.message, 'error');
      }
    }
  }

  function renderLoadError(error) {
    const board = document.getElementById('nexusColumns');
    if (!board) return;
    board.innerHTML = `<div class="state-box"><span class="icon">${Util.icon('warning')}</span><span class="title">Não foi possível carregar o Nexus</span><span class="desc">${Util.escape(error.message)}</span><button class="btn btn-glass btn-sm" id="nexusRetry" type="button">${Util.icon('refresh')}<span>Tentar novamente</span></button></div>`;
    board.querySelector('#nexusRetry')?.addEventListener('click', loadItems);
  }

  function getTags(item) {
    return Array.isArray(item.tags) ? item.tags.map(String) : [];
  }

  function getBaseItems() {
    return items.filter(item => !item.deleted_at);
  }

  function severityRank(item) {
    const sev = getSeverityTag(getTags(item)).toLowerCase();
    if (sev.includes('alta') || sev.includes('high') || sev.includes('critica')) return 0;
    if (sev.includes('media') || sev.includes('média')) return 1;
    if (sev.includes('baixa') || sev.includes('low')) return 2;
    if ((getTypeTag(getTags(item)) || '').toLowerCase().includes('incidente')) return 3;
    return 4;
  }

  function getFilteredItems() {
    const query = Util.normalize(filters.query.trim());
    let list = getBaseItems().filter(item => {
      if (filters.statuses.size && !filters.statuses.has(item.status)) return false;
      if (filters.tag && !getTags(item).includes(filters.tag)) return false;
      if (filters.type && item.type !== filters.type) return false;
      if (filters.sev && !severityClass(getSeverityTag(getTags(item))).includes(filters.sev)) return false;
      if (!query) return true;
      const searchable = [item.title, item.body, item.type, ...getTags(item)].map(Util.normalize).join(' ');
      return searchable.includes(query);
    });
    // Ordenação
    switch (filters.sort) {
      case 'oldest':
        list.sort((a, b) => String(a.updated_at || '').localeCompare(String(b.updated_at || '')));
        break;
      case 'title':
        list.sort((a, b) => String(a.title || '').localeCompare(String(b.title || ''), 'pt-BR'));
        break;
      case 'due':
        list.sort((a, b) => {
          const da = a.due_date ? String(a.due_date).split('T')[0] : '9999-12-31';
          const db = b.due_date ? String(b.due_date).split('T')[0] : '9999-12-31';
          return da.localeCompare(db) || String(b.updated_at || '').localeCompare(String(a.updated_at || ''));
        });
        break;
      case 'priority':
        list.sort((a, b) => severityRank(a) - severityRank(b) || String(b.updated_at || '').localeCompare(String(a.updated_at || '')));
        break;
      default: // recent
        list.sort((a, b) => String(b.updated_at || '').localeCompare(String(a.updated_at || '')));
    }
    return list;
  }

  function refreshFilterOptions() {
    const tags = [...new Set(getBaseItems().flatMap(getTags))].sort((a, b) => a.localeCompare(b, 'pt-BR'));
    const types = [...new Set(getBaseItems().map(item => item.type).filter(Boolean))].sort();
    const tagSelect = document.getElementById('nexusTagFilter');
    const typeSelect = document.getElementById('nexusTypeFilter');
    if (tagSelect) {
      tagSelect.innerHTML = `<option value="">Todas as tags</option>${tags.map(tag => `<option value="${Util.escape(tag)}">${Util.escape(tag)}</option>`).join('')}`;
      if (tags.includes(filters.tag)) tagSelect.value = filters.tag;
      else filters.tag = '';
    }
    if (typeSelect) {
      typeSelect.innerHTML = `<option value="">Todos os tipos</option>${types.map(type => `<option value="${Util.escape(type)}">${Util.escape(type === 'task' ? 'Tarefa' : type === 'note' ? 'Nota' : type)}</option>`).join('')}`;
      if (types.includes(filters.type)) typeSelect.value = filters.type;
      else filters.type = '';
    }
  }

  function renderSummary(allItems, filtered) {
    const el = document.getElementById('nexusSummary');
    if (!el) return;
    const base = allItems.filter(i => !i.deleted_at);
    const todo = base.filter(i => i.status === 'todo').length;
    const doing = base.filter(i => i.status === 'doing').length;
    const standby = base.filter(i => i.status === 'standby').length;
    const done = base.filter(i => i.status === 'concluded').length;
    const overdue = base.filter(i => {
      if (!i.due_date || i.status === 'concluded') return false;
      const d = new Date(String(i.due_date).split('T')[0] + 'T23:59:59');
      return !isNaN(d) && d < new Date();
    }).length;
    const sevHigh = base.filter(i => {
      const tags = getTags(i);
      const sev = getSeverityTag(tags).toLowerCase();
      return (sev.includes('alta') || sev.includes('high') || sev.includes('critica')) && i.status !== 'concluded';
    }).length;
    const cells = [
      { label: 'Total', value: base.length, icon: 'dashboard', color: '#5C8CFF', active: true },
      { label: 'Na Fila', value: todo, icon: 'inbox', color: '#7FB4FF', active: todo > 0 || base.length === 0 },
      { label: 'Atuando', value: doing, icon: 'play', color: '#6FE090', active: doing > 0 },
      { label: 'StandBy', value: standby, icon: 'pause', color: '#A78BFA', active: standby > 0 },
      { label: 'Concluído', value: done, icon: 'check', color: '#94A8BE', active: done > 0 },
    ];
    if (overdue > 0) cells.push({ label: 'Atrasados', value: overdue, icon: 'warning', color: '#f87171', active: true });
    if (sevHigh > 0) cells.push({ label: 'Prioritários', value: sevHigh, icon: 'flag', color: '#f87171', active: true });
    const isFiltered = filtered.length !== base.length;
    if (isFiltered) cells.push({ label: 'Filtrados', value: filtered.length, icon: 'filter', color: '#7FB4FF', active: true });
    el.innerHTML = cells.map(c => `
      <div class="nexus-summary-item" style="border-color:${c.active ? c.color + '55' : 'var(--glass-border)'};background:${c.active ? c.color + '14' : 'rgba(255,255,255,.03)'}">
        <span class="nexus-summary-icon" style="color:${c.active ? c.color : 'var(--text-disabled)'};border-color:${c.active ? c.color + '40' : 'var(--glass-border)'}">${Util.icon(c.icon)}</span>
        <div><strong style="color:${c.active ? 'var(--text-ivory)' : 'var(--text-disabled)'}">${c.value}</strong><span>${c.label}</span></div>
      </div>
    `).join('');
    el.style.display = base.length ? 'flex' : 'none';
  }

  function renderColumns() {
    const container = document.getElementById('nexusColumns');
    if (!container) return;
    const filtered = getFilteredItems();
    const base = getBaseItems();
    renderSummary(base, filtered);
    const visibleStatuses = filters.statuses.size ? STATUSES.filter(status => filters.statuses.has(status.key)) : STATUSES;

    if (!currentWs) {
      container.innerHTML = `<div class="state-box"><span class="icon">${Util.icon('nexus')}</span><span class="title">Nenhum workspace</span><span class="desc">Crie um workspace pelo aplicativo Android ou pela API Nexus.</span></div>`;
    } else if (!filtered.length) {
      const hasFilters = Boolean(filters.query.trim() || filters.statuses.size || filters.tag || filters.type);
      container.innerHTML = hasFilters
        ? `<div class="state-box"><span class="icon">${Util.icon('search')}</span><span class="title">Nenhuma tarefa encontrada</span><span class="desc">Ajuste a busca ou limpe os filtros ativos.</span></div>`
        : `<div class="state-box"><span class="icon">${Util.icon('nexus')}</span><span class="title">Workspace vazio</span><span class="desc">Use “Nova tarefa” para criar o primeiro item.</span></div>`;
    } else {
      container.innerHTML = visibleStatuses.map(status => {
        const columnItems = filtered.filter(item => item.status === status.key);
        return `<section class="glass nexus-column" data-column-status="${status.key}" style="--column-color:${status.color}">
          <header class="nexus-column-header">
            <span class="nexus-column-marker" aria-hidden="true"></span>
            <span class="badge ${status.badge}">${status.label}</span>
            <span class="nexus-column-count" aria-label="${columnItems.length} itens">${columnItems.length}</span>
          </header>
          <div class="nexus-column-items" data-drop-status="${status.key}">
            ${columnItems.length ? columnItems.map(item => itemCard(item)).join('') : '<div class="nexus-column-empty text-xs">Arraste um card para cá<br><small>ou crie um novo</small></div>'}
          </div>
        </section>`;
      }).join('');
    }

    bindBoardEvents(container);
    updateFilterState(filtered.length);
  }

  function getSeverityTag(tags) {
    const t = tags.find(v => v.toLowerCase().startsWith('severidade:') || v.toLowerCase().startsWith('severity:'));
    return t ? t.split(':').slice(1).join(':').trim() : '';
  }
  function getClientTag(tags) {
    const t = tags.find(v => v.toLowerCase().startsWith('cliente:'));
    return t ? t.split(':').slice(1).join(':').trim() : '';
  }
  function getTypeTag(tags) {
    const t = tags.find(v => v.toLowerCase().startsWith('tipo:'));
    return t ? t.split(':').slice(1).join(':').trim() : '';
  }
  function severityClass(sev) {
    const s = String(sev || '').toLowerCase();
    if (s.includes('alta') || s.includes('high') || s.includes('critica')) return 'sev-high';
    if (s.includes('media') || s.includes('média')) return 'sev-med';
    if (s.includes('baixa') || s.includes('low')) return 'sev-low';
    return '';
  }
  function cleanBodyPreview(body) {
    let s = String(body || '').trim();
    if (s.startsWith('---')) { const end = s.indexOf('\n---', 3); if (end !== -1) s = s.slice(end + 4).trim(); }
    s = s.replace(/^#+\s*/gm, '').replace(/^>\s*/gm, '').replace(/\n/g, ' ').replace(/\s+/g, ' ').trim();
    return s ? (s.slice(0, 110) + (s.length > 110 ? '…' : '')) : '';
  }

  function itemCard(item) {
    const tags = getTags(item);
    const sev = getSeverityTag(tags);
    const client = getClientTag(tags);
    const typeTag = getTypeTag(tags);
    const isQualitor = tags.includes('qualitor');
    const sevCls = severityClass(sev);
    const qualitorId = (() => { const t = tags.find(v => v.startsWith('qualitor:')); return t ? t.split(':')[1] : (String(item.title).match(/\[QUALITOR\s+(\d+)\]/)?.[1] || ''); })();
    const visibleTags = tags.filter(t => !t.startsWith('qualitor') && !t.toLowerCase().startsWith('cliente:') && !t.toLowerCase().startsWith('severidade:') && !t.toLowerCase().startsWith('tipo:') && t !== 'qualitor').slice(0, 3);
    const hiddenTagCount = Math.max(0, tags.length - visibleTags.length - (isQualitor ? 2 : 0));
    const bodyPreview = cleanBodyPreview(item.body);
    const due = item.due_date ? String(item.due_date).split('T')[0] : '';
    const title = splitTaskTitle(item.title);
    const urgency = dueUrgency(due, item.status);
    const statusDef = STATUSES.find(s => s.key === item.status) || STATUSES[0];
    return `<article class="glass glass-hover nexus-item ${urgency.className} ${sevCls ? 'has-sev-' + sevCls : ''}" data-id="${Util.escape(item.id)}" draggable="true" tabindex="0" role="button" aria-label="Arrastar ou abrir ${Util.escape(item.title)}">
      <div class="nexus-item-topline">
        <span class="nexus-item-type">${isQualitor && qualitorId ? '#'+Util.escape(qualitorId) : Util.escape(item.type === 'note' ? 'NOTA' : 'TAREFA')}</span>
        <span class="nexus-item-draghint" aria-hidden="true">${Util.icon('drag')}</span>
        ${sev ? `<span class="nexus-sev-pill sev-${sevCls}">${Util.escape(sev.toUpperCase())}</span>` : (typeTag ? `<span class="nexus-sev-pill sev-med">${Util.escape(typeTag.toUpperCase())}</span>` : '')}
      </div>
      <div class="h5 nexus-item-title">${title.reference ? `<span class="nexus-item-reference">${Util.escape(title.reference)}</span> ` : ''}<span class="nexus-item-label">${Util.escape(title.label)}</span></div>
      ${bodyPreview ? `<div class="text-xs nexus-item-body">${Util.escape(bodyPreview)}</div>` : ''}
      <div class="nexus-item-meta">
        ${client ? `<span class="nexus-meta-pill client"><span class="nexus-meta-icon">${Util.icon('company')}</span>${Util.escape(client)}</span>` : ''}
        ${due ? `<span class="nexus-meta-pill due ${urgency.className}"><span class="nexus-date-icon" aria-hidden="true"></span>${Util.escape(formatDueDate(due))}${urgency.label ? ` <strong>${urgency.label}</strong>` : ''}</span>` : ''}
        ${item.updated_at ? `<span class="nexus-meta-pill upd" title="${Util.escape(String(item.updated_at).split('.')[0].replace('T', ' '))}"><span class="nexus-meta-icon">${Util.icon('clock')}</span>${Util.escape(timeAgo(item.updated_at))}</span>` : ''}
        ${!client && !due && isQualitor ? `<span class="nexus-meta-pill"><span class="nexus-meta-icon">${Util.icon('nexus')}</span>Qualitor</span>` : ''}
      </div>
      ${visibleTags.length ? `<div class="nexus-item-tags" title="${Util.escape(tags.join(', '))}">${visibleTags.map(tag => `<span class="chip">${Util.escape(tag)}</span>`).join('')}${hiddenTagCount ? `<span class="chip nexus-more-tags">+${hiddenTagCount}</span>` : ''}</div>` : ''}
      <div class="nexus-item-actions">
        <span class="nexus-status-dot" style="background:${statusDef.color}"></span>
        <select class="input nexus-status-select" data-status="${Util.escape(item.status)}" data-id="${Util.escape(item.id)}" aria-label="Alterar status de ${Util.escape(item.title)}">
          ${STATUSES.map(status => `<option value="${status.key}"${status.key === item.status ? ' selected' : ''}>${status.short}</option>`).join('')}
        </select>
        <button class="btn btn-glass btn-icon nexus-delete-btn" type="button" data-id="${Util.escape(item.id)}" aria-label="Excluir tarefa" data-tooltip="Excluir tarefa">${Util.icon('trash')}</button>
      </div>
    </article>`;
  }

  function splitTaskTitle(value) {
    const title = String(value || 'Sem título').trim();
    const bracket = title.match(/^(\[[^\]]+\])\s*(.*)$/);
    if (bracket) return { reference: bracket[1], label: bracket[2] || bracket[1] };
    const called = title.match(/^(Chamado\s+\d+)\s*[-–—:]?\s*(.*)$/i);
    if (called) return { reference: called[1], label: called[2] || called[1] };
    return { reference: '', label: title };
  }

  function dueUrgency(date, status) {
    if (!date || status === 'concluded') return { className: '', label: '' };
    const due = new Date(`${date}T23:59:59`);
    if (Number.isNaN(due.getTime())) return { className: '', label: '' };
    const days = Math.ceil((due.getTime() - Date.now()) / 86400000);
    if (days < 0) return { className: 'is-overdue', label: 'Vencida' };
    if (days <= 3) return { className: 'is-due-soon', label: days === 0 ? 'Hoje' : `Em ${days}d` };
    return { className: '', label: '' };
  }

  function formatDueDate(date) {
    const [year, month, day] = String(date).split('-');
    return year && month && day ? `${day}/${month}/${year}` : date;
  }

  function bindBoardEvents(container) {
    // Click to open
    container.querySelectorAll('.nexus-item').forEach(card => {
      const open = event => {
        if (event.target.closest('button,select,input')) return;
        if (event.type === 'keydown' && !['Enter', ' '].includes(event.key)) return;
        event.preventDefault();
        showItemDetail(card.dataset.id);
      };
      card.addEventListener('click', open);
      card.addEventListener('keydown', open);

      // Drag & Drop — HTML5
      card.addEventListener('dragstart', event => {
        card.classList.add('dragging');
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.setData('text/plain', card.dataset.id);
        // Visual feedback ligeiro
        setTimeout(() => card.style.opacity = '0.45', 0);
      });
      card.addEventListener('dragend', () => {
        card.classList.remove('dragging');
        card.style.opacity = '';
        container.querySelectorAll('.nexus-column.drag-over').forEach(col => col.classList.remove('drag-over'));
      });
    });
    // Column drop zones
    container.querySelectorAll('.nexus-column').forEach(col => {
      const status = col.dataset.columnStatus;
      const dropZone = col.querySelector('.nexus-column-items');
      if (!dropZone) return;
      col.addEventListener('dragover', event => {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
        col.classList.add('drag-over');
      });
      col.addEventListener('dragleave', event => {
        if (!col.contains(event.relatedTarget)) col.classList.remove('drag-over');
      });
      col.addEventListener('drop', event => {
        event.preventDefault();
        col.classList.remove('drag-over');
        const id = event.dataTransfer.getData('text/plain');
        if (!id) return;
        const item = items.find(i => String(i.id) === String(id));
        if (!item || item.status === status) return;
        // Otimismo visual: adiciona loading
        const card = container.querySelector(`.nexus-item[data-id="${CSS.escape(id)}"]`);
        if (card) card.style.opacity = '0.6';
        moveItem(id, status);
      });
    });

    container.querySelectorAll('.nexus-status-select').forEach(select => {
      select.addEventListener('change', event => {
        event.stopPropagation();
        moveItem(select.dataset.id, select.value);
      });
      select.addEventListener('click', event => event.stopPropagation());
    });
    container.querySelectorAll('.nexus-delete-btn').forEach(button => {
      button.addEventListener('click', async event => {
        event.stopPropagation();
        const item = items.find(candidate => String(candidate.id) === button.dataset.id);
        if (!confirm(`Excluir “${item?.title || 'esta tarefa'}”? Esta ação não pode ser desfeita.`)) return;
        await deleteItem(button.dataset.id);
      });
    });
  }

  function updateFilterState(resultCount) {
    const base = getBaseItems();
    document.querySelectorAll('.nexus-filter-chip').forEach(button => {
      const selected = filters.statuses.has(button.dataset.status);
      button.classList.toggle('active', selected);
      button.setAttribute('aria-pressed', String(selected));
      const count = button.querySelector('[data-count]');
      if (count) count.textContent = String(base.filter(item => item.status === button.dataset.status).length);
    });
    document.querySelectorAll('.nexus-sev-chip').forEach(button => {
      const selected = filters.sev === button.dataset.sev;
      button.classList.toggle('active', selected);
      button.setAttribute('aria-pressed', String(selected));
    });
    const sortSelect = document.getElementById('nexusSortSelect');
    if (sortSelect && sortSelect.value !== filters.sort) sortSelect.value = filters.sort;
    const activeFilterCount = filters.statuses.size + Number(Boolean(filters.tag)) + Number(Boolean(filters.type)) + Number(Boolean(filters.sev)) + Number(Boolean(filters.query.trim())) + Number(filters.sort !== 'recent');
    const clear = document.getElementById('nexusClearFilters');
    if (clear) clear.disabled = activeFilterCount === 0;
    const summary = document.getElementById('nexusResultSummary');
    if (summary) summary.textContent = `${resultCount} de ${base.length} itens${activeFilterCount ? ` • ${activeFilterCount} filtro${activeFilterCount > 1 ? 's' : ''}` : ''}`;
  }

  function clearFilters() {
    filters.query = '';
    filters.statuses.clear();
    filters.tag = '';
    filters.type = '';
    filters.sev = '';
    filters.sort = 'recent';
    const search = document.getElementById('nexusSearch');
    const tag = document.getElementById('nexusTagFilter');
    const type = document.getElementById('nexusTypeFilter');
    const sortSelect = document.getElementById('nexusSortSelect');
    if (search) search.value = '';
    if (tag) tag.value = '';
    if (type) type.value = '';
    if (sortSelect) sortSelect.value = 'recent';
    renderColumns();
  }

  function timeAgo(value) {
    if (!value) return '';
    const date = new Date(value);
    if (isNaN(date)) return String(value).split('T')[0];
    const diffMs = Date.now() - date.getTime();
    const minutes = Math.floor(diffMs / 60000);
    if (minutes < 1) return 'agora';
    if (minutes < 60) return `${minutes}m atrás`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h atrás`;
    const days = Math.floor(hours / 24);
    if (days < 7) return `${days}d atrás`;
    return `${String(date.getDate()).padStart(2, '0')}/${String(date.getMonth() + 1).padStart(2, '0')}`;
  }

  async function syncQualitor() {
    const button = document.getElementById('nexusSync');
    setBusy(button, true);
    setFeedback('Sincronizando chamados do Qualitor…', 'info');
    try {
      const response = await fetch('/web-api/bridge/sync/run', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': Auth.csrf || '' },
        credentials: 'same-origin',
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || data.message || 'Erro na sincronização');
      await loadItems();
      setFeedback(`Sync concluído: ${data.synced || 0} chamados sincronizados.`, 'success');
    } catch (error) {
      setFeedback(`Falha na sync: ${error.message}`, 'error');
    } finally {
      setBusy(button, false);
    }
  }

  async function createItem() {
    const title = document.getElementById('newTaskTitle')?.value.trim();
    if (!title || !currentWs) {
      setFeedback('Informe um título para a tarefa.', 'warning');
      return;
    }
    const button = document.getElementById('confirmCreate');
    setBusy(button, true);
    try {
      const due = document.getElementById('newTaskDue').value;
      await API.createItem({
        workspace_id: currentWs.id,
        type: document.getElementById('newTaskType').value,
        title,
        body: document.getElementById('newTaskBody').value.trim(),
        status: document.getElementById('newTaskStatus').value,
        tags: parseTags(document.getElementById('newTaskTags').value),
        ...(due ? { due_date: due } : {}),
      });
      closeDialog('nexusCreateDialog');
      resetCreateForm();
      await loadItems();
      setFeedback('Tarefa criada e sincronizada.', 'success');
    } catch (error) {
      setFeedback(error.message, 'error');
    } finally {
      setBusy(button, false);
    }
  }

  async function moveItem(id, newStatus) {
    try {
      await API.updateItem(id, { status: newStatus });
      await loadItems();
      setFeedback('Status atualizado.', 'success');
    } catch (error) {
      setFeedback(error.message, 'error');
      await loadItems();
    }
  }

  async function deleteItem(id) {
    try {
      await API.deleteItem(id);
      await loadItems();
      setFeedback('Tarefa excluída.', 'success');
    } catch (error) {
      setFeedback(error.message, 'error');
    }
  }

  function showItemDetail(id) {
    const item = items.find(candidate => String(candidate.id) === String(id));
    if (!item) return;
    const tags = getTags(item);
    const isQualitor = tags.includes('qualitor');
    const body = String(item.body || '');
    const title = splitTaskTitle(item.title);
    const statusDef = STATUSES.find(s => s.key === item.status) || STATUSES[0];

    document.getElementById('editTaskId').value = item.id;
    document.getElementById('nexusEditTitle').textContent = title.label;
    const badge = document.getElementById('detailBadge');
    badge.textContent = statusDef.label;
    badge.className = `badge ${statusDef.badge}`;

    const metaParts = [];
    if (title.reference) metaParts.push(`<strong>${Util.escape(title.reference)}</strong>`);
    if (item.updated_at) metaParts.push(`atualizada em ${String(item.updated_at).split('T')[0]}`);
    document.getElementById('editTaskMeta').innerHTML = metaParts.join(' · ');

    const titleInput = document.getElementById('editTaskTitleInput');
    const bodyInput = document.getElementById('editTaskBody');
    if (titleInput) titleInput.value = item.title || '';
    if (bodyInput) bodyInput.value = item.body || '';
    document.getElementById('editTaskStatus').value = item.status || 'todo';
    document.getElementById('editTaskTags').value = tags.join(', ');
    document.getElementById('editTaskDue').value = item.due_date ? String(item.due_date).split('T')[0] : '';

    // Qualitor info
    const qInfo = document.getElementById('detailQualitorInfo');
    if (isQualitor) {
      const qf = parseFrontmatter(body);
      qInfo.innerHTML = `<div class="nexus-qinfo-grid">
        ${qField('Chamado', qf.qualitor_id)}${qField('Cliente', qf.client)}${qField('Contato', qf.contact)}
        ${qField('Equipe', qf.team)}${qField('Responsável', qf.responsible)}${qField('Severidade', qf.severity)}
        ${qField('Tipo', qf.type)}${qField('Categoria', qf.category)}${qField('Localidade', qf.location)}</div>`;
      qInfo.style.display = '';
    } else { qInfo.style.display = 'none'; }

    // Description tab
    const descEl = document.getElementById('detailDescription');
    if (isQualitor) {
      const desc = extractSection(body, 'Descrição');
      descEl.innerHTML = desc ? `<div class="nexus-desc-content">${formatText(desc)}</div>` : '<div class="text-xs">Sem descrição</div>';
    } else {
      descEl.innerHTML = body ? `<div class="nexus-desc-content">${Util.escape(body)}</div>` : '<div class="text-xs">Sem descrição</div>';
    }

    // History tab
    const histEl = document.getElementById('detailHistory');
    if (isQualitor) {
      const hist = extractSection(body, 'Último Acompanhamento');
      histEl.innerHTML = hist ? `<div class="nexus-history-item"><div class="nexus-history-text">${formatText(hist)}</div></div>` : '<div class="text-xs">Nenhum atendimento</div>';
    } else {
      histEl.innerHTML = '<div class="text-xs">Disponível apenas para chamados do Qualitor</div>';
    }

    // Reset tabs
    document.querySelectorAll('.nexus-detail-tab').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.nexus-detail-tab-content').forEach(t => t.classList.remove('active'));
    document.querySelector('.nexus-detail-tab[data-tab="info"]')?.classList.add('active');
    document.getElementById('tabInfo')?.classList.add('active');
    document.querySelectorAll('.nexus-detail-tab').forEach(tab => {
      tab.onclick = () => {
        document.querySelectorAll('.nexus-detail-tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.nexus-detail-tab-content').forEach(t => t.classList.remove('active'));
        tab.classList.add('active');
        const tabId = 'tab' + tab.dataset.tab.charAt(0).toUpperCase() + tab.dataset.tab.slice(1);
        document.getElementById(tabId)?.classList.add('active');
      };
    });

    openDialog('nexusEditDialog');
  }

  function qField(label, value) {
    if (!value) return '';
    return `<div class="nexus-qfield"><label>${Util.escape(label)}</label><span>${Util.escape(value)}</span></div>`;
  }

  function parseFrontmatter(body) {
    const fields = {};
    const m = body.match(/^---\n([\s\S]*?)\n---/);
    if (!m) return fields;
    for (const line of m[1].split('\n')) { const p = line.match(/^(\w+):\s*"?(.*?)"?\s*$/); if (p) fields[p[1]] = p[2]; }
    return fields;
  }

  function extractSection(body, name) {
    const m = body.match(new RegExp(`## ${name}\\s*\\n([\\s\\S]*?)(?=\\n## |$)`));
    return m ? m[1].trim() : '';
  }

  function formatText(t) { return Util.escape(t).replace(/\n/g, '<br>'); }

  async function saveItem() {
    const id = document.getElementById('editTaskId').value;
    if (!id) return;
    const button = document.getElementById('confirmEdit');
    setBusy(button, true);
    try {
      const title = document.getElementById('editTaskTitleInput')?.value.trim();
      if (!title) throw new Error('Informe um título para a tarefa.');
      const patch = {
        title,
        status: document.getElementById('editTaskStatus').value,
        tags: parseTags(document.getElementById('editTaskTags').value),
        due_date: document.getElementById('editTaskDue').value,
      };
      const body = document.getElementById('editTaskBody')?.value;
      if (body !== undefined) patch.body = body;
      await API.updateItem(id, patch);
      closeDialog('nexusEditDialog');
      await loadItems();
      setFeedback('Tarefa atualizada.', 'success');
    } catch (error) {
      setFeedback(error.message, 'error');
    } finally {
      setBusy(button, false);
    }
  }

  function parseTags(value) {
    return [...new Set(String(value || '').split(',').map(tag => tag.trim()).filter(Boolean))];
  }

  function resetCreateForm() {
    ['newTaskTitle', 'newTaskBody', 'newTaskTags', 'newTaskDue'].forEach(id => {
      const field = document.getElementById(id);
      if (field) field.value = '';
    });
    const type = document.getElementById('newTaskType');
    const status = document.getElementById('newTaskStatus');
    if (type) type.value = 'task';
    if (status) status.value = 'todo';
  }

  async function exportItems() {
    const button = document.getElementById('confirmExport');
    const selectedStatuses = new Set([...document.querySelectorAll('input[name="exportStatus"]:checked')].map(input => input.value));
    const includeDone = document.getElementById('exportIncludeDone').checked;
    const includeTags = document.getElementById('exportIncludeTags').checked;
    const includeDates = document.getElementById('exportIncludeDates').checked;
    const format = document.getElementById('nexusExportFormat').value;
    const exported = getBaseItems()
      .filter(item => selectedStatuses.has(item.status))
      .filter(item => includeDone || item.status !== 'concluded')
      .sort((a, b) => STATUSES.findIndex(status => status.key === a.status) - STATUSES.findIndex(status => status.key === b.status) || (a.position || 0) - (b.position || 0));

    if (!selectedStatuses.size || !exported.length) {
      setFeedback('Selecione ao menos um status com tarefas para exportar.', 'warning');
      return;
    }

    setBusy(button, true);
    try {
      if (format === 'png') await exportPng(exported, { includeTags, includeDates });
      else exportPrintReport(exported, { includeTags, includeDates });
      closeDialog('nexusExportDialog');
      setFeedback(format === 'png' ? 'Relatório PNG gerado.' : 'Relatório aberto para impressão/PDF.', 'success');
    } catch (error) {
      setFeedback(`Falha ao exportar: ${error.message}`, 'error');
    } finally {
      setBusy(button, false);
    }
  }

  async function exportPng(exportedItems, options) {
    const width = 1400;
    const padding = 72;
    const contentWidth = width - padding * 2;
    const measureCanvas = document.createElement('canvas');
    const measure = measureCanvas.getContext('2d');
    measure.font = '600 26px Inter, sans-serif';

    const groups = STATUSES.map(status => ({ status, items: exportedItems.filter(item => item.status === status.key) })).filter(group => group.items.length);
    const prepared = groups.map(group => ({
      ...group,
      cards: group.items.map(item => {
        measure.font = '600 26px Inter, sans-serif';
        const titleLines = wrapCanvasText(measure, item.title, contentWidth - 56, 3);
        measure.font = '400 20px Inter, sans-serif';
        const bodyLines = item.body ? wrapCanvasText(measure, item.body, contentWidth - 56, 2) : [];
        const tags = options.includeTags ? getTags(item).map(tag => `#${tag}`).join('  ') : '';
        const date = options.includeDates && item.due_date ? `Prazo: ${String(item.due_date).split('T')[0]}` : '';
        const height = 38 + titleLines.length * 34 + bodyLines.length * 27 + (tags ? 30 : 0) + (date ? 28 : 0) + 24;
        return { item, titleLines, bodyLines, tags, date, height };
      }),
    }));
    const height = Math.max(520, 190 + prepared.reduce((total, group) => total + 70 + group.cards.reduce((sum, card) => sum + card.height + 18, 0), 0) + 72);
    if (height > 16000) throw new Error('Relatório excede o limite de uma única imagem; use PDF/Imprimir.');

    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const context = canvas.getContext('2d');
    context.fillStyle = '#050B14';
    context.fillRect(0, 0, width, height);
    const gradient = context.createRadialGradient(width * 0.75, 0, 20, width * 0.75, 0, width);
    gradient.addColorStop(0, 'rgba(229,106,18,0.16)');
    gradient.addColorStop(1, 'rgba(7,6,5,0)');
    context.fillStyle = gradient;
    context.fillRect(0, 0, width, 500);

    context.fillStyle = '#FFFFFF';
    context.font = '700 42px Inter, sans-serif';
    context.fillText('NOVA NEXUS', padding, 76);
    context.fillStyle = '#7FB4FF';
    context.font = '600 24px Inter, sans-serif';
    context.fillText(currentWs?.name || 'Workspace', padding, 116);
    context.fillStyle = '#94A8BE';
    context.font = '400 18px Inter, sans-serif';
    context.fillText(`${exportedItems.length} itens • gerado em ${new Date().toLocaleString('pt-BR')}`, padding, 150);

    let y = 205;
    for (const group of prepared) {
      context.fillStyle = group.status.color;
      context.font = '700 22px Inter, sans-serif';
      context.fillText(`${group.status.label}  ${group.items.length}`, padding, y);
      y += 30;
      for (const card of group.cards) {
        context.fillStyle = '#0C1A2B';
        roundRect(context, padding, y, contentWidth, card.height, 18);
        context.fill();
        context.strokeStyle = 'rgba(255,255,255,0.13)';
        context.stroke();
        let lineY = y + 42;
        context.fillStyle = '#FFFFFF';
        context.font = '600 26px Inter, sans-serif';
        for (const line of card.titleLines) { context.fillText(line, padding + 28, lineY); lineY += 34; }
        if (card.bodyLines.length) {
          context.fillStyle = '#94A8BE';
          context.font = '400 20px Inter, sans-serif';
          for (const line of card.bodyLines) { context.fillText(line, padding + 28, lineY); lineY += 27; }
        }
        if (card.tags) {
          context.fillStyle = '#8BB9D7';
          context.font = '500 17px Inter, sans-serif';
          context.fillText(card.tags.slice(0, 150), padding + 28, lineY + 2);
          lineY += 30;
        }
        if (card.date) {
          context.fillStyle = '#A78BFA';
          context.font = '500 17px Inter, sans-serif';
          context.fillText(card.date, padding + 28, lineY + 2);
        }
        y += card.height + 18;
      }
      y += 28;
    }

    const blob = await new Promise((resolve, reject) => canvas.toBlob(value => value ? resolve(value) : reject(new Error('Canvas indisponível')), 'image/png'));
    downloadBlob(blob, `nexus-${Util.safeFilename(currentWs?.name)}-${new Date().toISOString().slice(0, 10)}.png`);
  }

  function exportPrintReport(exportedItems, options) {
    cleanupPrintReport();
    const report = document.createElement('article');
    report.id = 'nexusPrintReport';
    report.className = 'nexus-print-report';
    report.innerHTML = `
      <header><h1>NOVA NEXUS</h1><h2>${Util.escape(currentWs?.name || 'Workspace')}</h2><p>${exportedItems.length} itens • ${Util.escape(new Date().toLocaleString('pt-BR'))}</p></header>
      ${STATUSES.map(status => {
        const statusItems = exportedItems.filter(item => item.status === status.key);
        if (!statusItems.length) return '';
        return `<section><h3>${status.label} <span>${statusItems.length}</span></h3>${statusItems.map(item => `
          <article class="nexus-print-item">
            <h4>${Util.escape(item.title)}</h4>
            ${item.body ? `<p>${Util.escape(item.body)}</p>` : ''}
            ${options.includeTags && getTags(item).length ? `<small>${getTags(item).map(tag => `#${Util.escape(tag)}`).join(' ')}</small>` : ''}
            ${options.includeDates && item.due_date ? `<small>Prazo: ${Util.escape(String(item.due_date).split('T')[0])}</small>` : ''}
          </article>`).join('')}</section>`;
      }).join('')}`;
    document.body.append(report);
    document.body.classList.add('nexus-printing');
    const cleanup = () => cleanupPrintReport();
    window.addEventListener('afterprint', cleanup, { once: true });
    window.print();
    setTimeout(cleanup, 30000);
  }

  function cleanupPrintReport() {
    document.getElementById('nexusPrintReport')?.remove();
    document.body.classList.remove('nexus-printing');
  }

  function wrapCanvasText(context, value, maxWidth, maxLines) {
    const words = String(value || '').replace(/\s+/g, ' ').trim().split(' ').filter(Boolean);
    const lines = [];
    let line = '';
    for (const word of words) {
      const candidate = line ? `${line} ${word}` : word;
      if (context.measureText(candidate).width <= maxWidth || !line) line = candidate;
      else { lines.push(line); line = word; }
      if (lines.length === maxLines) break;
    }
    if (line && lines.length < maxLines) lines.push(line);
    if (words.length && lines.length === maxLines && context.measureText(String(value)).width > maxWidth * maxLines) {
      lines[maxLines - 1] = `${lines[maxLines - 1].replace(/…$/, '').slice(0, -1)}…`;
    }
    return lines;
  }

  function roundRect(context, x, y, width, height, radius) {
    context.beginPath();
    context.roundRect(x, y, width, height, radius);
  }

  function downloadBlob(blob, filename) {
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = filename;
    document.body.append(anchor);
    anchor.click();
    anchor.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  function openDialog(id, focusSelector) {
    const dialog = document.getElementById(id);
    if (!dialog) return;
    dialog.classList.remove('hidden');
    requestAnimationFrame(() => dialog.querySelector(focusSelector)?.focus());
  }

  function closeDialog(id) {
    document.getElementById(id)?.classList.add('hidden');
  }

  function setBusy(button, busy) {
    if (!button) return;
    button.disabled = busy;
    if (!button.dataset.originalHtml) button.dataset.originalHtml = button.innerHTML;
    button.innerHTML = busy ? '<span class="spinner button-spinner"></span><span>Processando…</span>' : button.dataset.originalHtml;
  }

  function setFeedback(message, type = 'success') {
    const element = document.getElementById('nexusFeedback');
    if (!element) return;
    clearTimeout(feedbackTimer);
    element.textContent = message;
    element.dataset.type = type;
    element.classList.remove('hidden');
    feedbackTimer = setTimeout(() => element.classList.add('hidden'), 5000);
  }

  function destroy() {
    active = false;
    clearTimeout(feedbackTimer);
    cleanupPrintReport();
    workspaces = [];
    currentWs = null;
    items = [];
  }

  return { render, destroy };
})();
