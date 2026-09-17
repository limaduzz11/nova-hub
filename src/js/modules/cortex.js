/* ═══════════════════════════════════════════════════════════════
   NOVA HUB V5 WEB — CORTEX Module (Knowledge Graph)
   ═══════════════════════════════════════════════════════════════ */
const CortexModule = (() => {
  const GROUP_COLORS = {
    knowledge: '#7FB4FF', skill: '#6FE090', memory: '#6C8FB8',
    project: '#8BB9D7', hub: '#D95345', root: '#94A8BE',
  };
  const DEFAULT_PHYSICS = {
    repulsion: 500,
    attraction: 0.08,
    linkDistance: 400,
    linkOpacity: 0.2,
    nodeSize: 0.3,
  };

  let nodes = [];
  let edges = [];
  let nodeById = new Map();
  let nodeNeighbors = new Map();
  let visibleNodes = [];
  let visibleEdges = [];
  let visibleNodeIds = new Set();
  let selectedGroups = new Set();
  let searchQuery = '';
  let hideOrphans = false;
  let selectedNode = null;
  let selectedNeighborIds = new Set();
  let hoveredNode = null;
  let viewMode = 'graph';
  let physics = { ...DEFAULT_PHYSICS };
  let scale = 0.39;
  let offsetX = 0;
  let offsetY = 0;
  let interaction = null;
  let animationFrame = null;
  let frameCount = 0;
  let cameraTouched = false;
  let active = false;
  let loadSequence = 0;
  let lastPointerMove = 0;
  let searchDebounce = null;
  let resizeObserver = null;
  let ambientPhase = 0;

  function render() {
    active = true;
    selectedGroups = new Set();
    searchQuery = '';
    hideOrphans = false;
    selectedNode = null;
    selectedNeighborIds = new Set();
    hoveredNode = null;
    viewMode = 'graph';
    physics = { ...DEFAULT_PHYSICS };
    resetCamera();
    lastPointerMove = 0;
    ambientPhase = 0;

    const element = document.createElement('div');
    element.className = 'cortex-module';
    element.innerHTML = `
      <div class="module-header cortex-header">
        ${Util.moduleHeading('cortex', 'NOVA Cortex', 'Mapa vivo do Context Engine')}
        <span class="text-sm cortex-stats" id="cortexStats" aria-live="polite">Carregando…</span>
        <label class="cortex-search cortex-search-field">
          <span class="sr-only">Buscar nós</span>
          <span class="input-leading-icon">${Util.icon('search')}</span>
          <input id="cortexSearch" class="input" type="search" placeholder="Buscar nós…" autocomplete="off">
        </label>
        <button class="btn btn-glass btn-sm" id="cortexViewToggle" type="button" aria-pressed="false">${Util.icon('list')}<span>Lista</span></button>
        <button class="btn btn-glass btn-sm" id="cortexFiltersToggle" type="button" aria-expanded="false">${Util.icon('filter')}<span>Filtros</span></button>
        <button class="btn btn-glass btn-sm" id="cortexRefresh" type="button">${Util.icon('refresh')}<span>Atualizar</span></button>
      </div>

      <section id="cortexFilterPanel" class="glass cortex-filter-panel hidden" aria-label="Filtros e parâmetros do Cortex">
        <div class="cortex-filter-heading">
          <div><h3 class="h5">Grupos e parâmetros</h3><p class="text-xs">Os filtros afetam o grafo e a lista sem alterar o Vault.</p></div>
           <button id="cortexClearFilters" class="btn btn-glass btn-sm" type="button">${Util.icon('close')}<span>Limpar filtros</span></button>
        </div>
        <div>
          <div class="cortex-control-label">GRUPOS</div>
          <div id="cortexGroupFilters" class="cortex-group-filters"></div>
        </div>
        <label class="cortex-orphan-toggle"><input id="cortexShowOrphans" type="checkbox" checked><span><strong>Exibir nós órfãos</strong><small>Ativado como visualização principal; desligue para focar somente relações.</small></span></label>
        <div class="cortex-physics-grid">
          ${rangeControl('repulsion', 'Repulsão', 500, 12000, 100, DEFAULT_PHYSICS.repulsion)}
          ${rangeControl('attraction', 'Atração', 0.005, 0.08, 0.005, DEFAULT_PHYSICS.attraction)}
          ${rangeControl('linkDistance', 'Distância', 60, 400, 10, DEFAULT_PHYSICS.linkDistance)}
          ${rangeControl('linkOpacity', 'Links', 0.02, 0.8, 0.02, DEFAULT_PHYSICS.linkOpacity)}
          ${rangeControl('nodeSize', 'Nós', 0.3, 3, 0.1, DEFAULT_PHYSICS.nodeSize)}
        </div>
      </section>

      <div class="cortex-workspace" id="cortexWorkspace">
        <div id="cortexStateOverlay" class="glass state-box cortex-state-overlay hidden"></div>
        <section id="cortexGraphView" class="glass cortex-graph-view" aria-label="Visualização em grafo">
          <canvas id="cortexCanvas" tabindex="0" aria-label="Grafo interativo. Arraste o fundo para mover, use a roda para ampliar e selecione um nó para detalhes."></canvas>
          <div id="cortexTooltip" class="cortex-tooltip hidden" role="status"></div>
          <div class="cortex-graph-hint">Arraste para navegar <span></span> use a roda para ampliar <span></span> clique para inspecionar</div>
          <div class="cortex-camera-controls">
            <button class="btn btn-glass btn-icon" id="cortexZoomOut" type="button" aria-label="Diminuir zoom" data-tooltip="Diminuir zoom">${Util.icon('minus')}</button>
            <span id="cortexZoomLevel" class="text-xs">50%</span>
            <button class="btn btn-glass btn-icon" id="cortexZoomIn" type="button" aria-label="Aumentar zoom" data-tooltip="Aumentar zoom">${Util.icon('plus')}</button>
            <button class="btn btn-glass btn-sm" id="cortexFit" type="button">${Util.icon('fit')}<span>Enquadrar</span></button>
          </div>
        </section>
        <section id="cortexListView" class="cortex-list-view hidden" aria-label="Visualização em lista">
          <div id="cortexList"></div>
        </section>
        <aside class="glass cortex-node-detail hidden" id="cortexNodeDetail" aria-live="polite">
          <div class="cortex-detail-header">
            <div><div class="h5" id="detailTitle"></div><div class="text-sm" id="detailGroup"></div></div>
            <button class="btn btn-glass btn-icon" id="cortexDetailClose" type="button" aria-label="Fechar detalhes">${Util.icon('close')}</button>
          </div>
          <div class="text-sm" id="detailPath"></div>
          <div id="detailContent" class="cortex-detail-content"></div>
          <div id="detailConnections" class="cortex-detail-connections"></div>
        </aside>
      </div>
    `;

    bindEvents(element);
    resizeObserver = new ResizeObserver(() => renderCanvas());
    resizeObserver.observe(element.querySelector('#cortexGraphView'));
    loadGraph();
    return element;
  }

  function rangeControl(key, label, min, max, step, value) {
    return `<label class="cortex-range-control">
      <span>${label}</span>
      <input type="range" data-physics="${key}" min="${min}" max="${max}" step="${step}" value="${value}">
      <output data-output="${key}">${formatPhysicsValue(key, value)}</output>
    </label>`;
  }

  function bindEvents(element) {
    element.querySelector('#cortexSearch').addEventListener('input', event => {
      searchQuery = event.target.value;
      clearTimeout(searchDebounce);
      searchDebounce = setTimeout(() => recomputeVisible(true), 160);
    });
    element.querySelector('#cortexViewToggle').addEventListener('click', toggleViewMode);
    element.querySelector('#cortexFiltersToggle').addEventListener('click', toggleFilterPanel);
    element.querySelector('#cortexRefresh').addEventListener('click', refreshGraph);
    element.querySelector('#cortexClearFilters').addEventListener('click', clearFilters);
    element.querySelector('#cortexDetailClose').addEventListener('click', closeNodeDetail);
    element.querySelector('#cortexZoomOut').addEventListener('click', () => setZoom(scale / 1.25, true));
    element.querySelector('#cortexZoomIn').addEventListener('click', () => setZoom(scale * 1.25, true));
    element.querySelector('#cortexFit').addEventListener('click', () => fitVisibleGraph(true));
    element.querySelector('#cortexGroupFilters').addEventListener('click', event => {
      const button = event.target.closest('[data-group]');
      if (!button) return;
      const group = button.dataset.group;
      if (selectedGroups.has(group)) selectedGroups.delete(group);
      else selectedGroups.add(group);
      recomputeVisible(true);
    });
    element.querySelector('#cortexShowOrphans').addEventListener('change', event => {
      hideOrphans = !event.target.checked;
      recomputeVisible(true);
    });
    element.querySelectorAll('[data-physics]').forEach(input => {
      input.addEventListener('input', () => {
        const key = input.dataset.physics;
        physics[key] = Number(input.value);
        const output = element.querySelector(`[data-output="${key}"]`);
        if (output) output.textContent = formatPhysicsValue(key, physics[key]);
        if (['repulsion', 'attraction', 'linkDistance'].includes(key)) startPhysics();
        else renderCanvas();
      });
    });
    bindCanvasEvents(element.querySelector('#cortexCanvas'));
  }

  function bindCanvasEvents(canvas) {
    canvas.addEventListener('wheel', event => {
      event.preventDefault();
      cameraTouched = true;
      const rect = canvas.getBoundingClientRect();
      const pointerX = event.clientX - rect.left - rect.width / 2;
      const pointerY = event.clientY - rect.top - rect.height / 2;
      const worldX = (pointerX - offsetX) / scale;
      const worldY = (pointerY - offsetY) / scale;
      const nextScale = clamp(scale * (event.deltaY > 0 ? 0.88 : 1.14), 0.05, 8);
      offsetX = pointerX - worldX * nextScale;
      offsetY = pointerY - worldY * nextScale;
      scale = nextScale;
      updateZoomLabel();
      renderCanvas();
    }, { passive: false });

    canvas.addEventListener('pointerdown', event => {
      if (event.button !== 0) return;
      const hit = findNodeAtPointer(canvas, event.clientX, event.clientY);
      interaction = {
        type: hit ? 'node' : 'pan',
        node: hit,
        startX: event.clientX,
        startY: event.clientY,
        previousX: event.clientX,
        previousY: event.clientY,
        moved: false,
      };
      canvas.setPointerCapture(event.pointerId);
      canvas.style.cursor = hit ? 'grabbing' : 'grabbing';
      hideCanvasTooltip();
    });

    canvas.addEventListener('pointermove', event => {
      if (!interaction) {
        const now = performance.now();
        if (lastPointerMove && now - lastPointerMove < 28) return;
        lastPointerMove = now;
        const hit = findNodeAtPointer(canvas, event.clientX, event.clientY);
        canvas.style.cursor = hit ? 'pointer' : 'grab';
        updateCanvasHover(canvas, hit, event.clientX, event.clientY);
        return;
      }
      const deltaX = event.clientX - interaction.previousX;
      const deltaY = event.clientY - interaction.previousY;
      if (Math.hypot(event.clientX - interaction.startX, event.clientY - interaction.startY) > 4) interaction.moved = true;
      if (interaction.type === 'node' && interaction.node) {
        interaction.node.x += deltaX / scale;
        interaction.node.y += deltaY / scale;
        interaction.node.vx = 0;
        interaction.node.vy = 0;
      } else {
        cameraTouched = true;
        offsetX += deltaX;
        offsetY += deltaY;
      }
      interaction.previousX = event.clientX;
      interaction.previousY = event.clientY;
      renderCanvas();
    });

    const finishInteraction = event => {
      if (!interaction) return;
      if (interaction.type === 'node' && interaction.node && !interaction.moved) showNodeDetail(interaction.node);
      interaction = null;
      if (canvas.hasPointerCapture(event.pointerId)) canvas.releasePointerCapture(event.pointerId);
      canvas.style.cursor = 'grab';
    };
    canvas.addEventListener('pointerup', finishInteraction);
    canvas.addEventListener('pointercancel', finishInteraction);
    canvas.addEventListener('pointerleave', () => {
      if (!interaction) updateCanvasHover(canvas, null, 0, 0);
    });
    canvas.addEventListener('dblclick', () => fitVisibleGraph(true));
  }

  function updateCanvasHover(canvas, node, clientX, clientY) {
    const changed = hoveredNode?.id !== node?.id;
    hoveredNode = node || null;
    const tooltip = document.getElementById('cortexTooltip');
    if (!tooltip) return;
    if (!node) {
      tooltip.classList.add('hidden');
      if (changed) renderCanvas();
      return;
    }
    const graphRect = canvas.parentElement.getBoundingClientRect();
    const x = clamp(clientX - graphRect.left + 16, 12, Math.max(12, graphRect.width - 260));
    const y = clamp(clientY - graphRect.top + 16, 12, Math.max(12, graphRect.height - 96));
    tooltip.innerHTML = `<strong>${Util.escape(node.label || 'Nó')}</strong><span><i style="--tooltip-color:${GROUP_COLORS[node.group] || '#94A8BE'}"></i>${Util.escape(node.group || 'sem grupo')} • ${Number(node.degree || 0)} relações</span>`;
    tooltip.style.transform = `translate(${Math.round(x)}px,${Math.round(y)}px)`;
    tooltip.classList.remove('hidden');
    if (changed) renderCanvas();
  }

  function hideCanvasTooltip() {
    hoveredNode = null;
    document.getElementById('cortexTooltip')?.classList.add('hidden');
  }

  async function loadGraph() {
    const sequence = ++loadSequence;
    const stats = document.getElementById('cortexStats');
    if (stats) stats.textContent = 'Carregando…';
    try {
      const data = await API.getGraph();
      if (!active || sequence !== loadSequence) return;
      const sourceNodes = Array.isArray(data.nodes) ? data.nodes : [];
      nodes = sourceNodes.map((node, index) => {
        const radius = 30 * Math.sqrt(index + 1);
        const angle = index * 2.399963229728653;
        return { ...node, x: Math.cos(angle) * radius, y: Math.sin(angle) * radius, vx: 0, vy: 0, physicsIndex: index };
      });
      edges = Array.isArray(data.edges) ? data.edges : [];
      nodeById = new Map(nodes.map(node => [node.id, node]));
      nodeNeighbors = buildAdjacencyIndex();
      document.getElementById('cortexStateOverlay')?.classList.add('hidden');
      selectedNode = null;
      selectedNeighborIds.clear();
      hideCanvasTooltip();
      closeNodeDetail();
      renderGroupFilters();
      recomputeVisible();
      startPhysics();
    } catch (error) {
      if (active && sequence === loadSequence) renderError(error);
    }
  }

  function refreshGraph() {
    searchQuery = '';
    selectedGroups.clear();
    physics = { ...DEFAULT_PHYSICS };
    const search = document.getElementById('cortexSearch');
    if (search) search.value = '';
    document.querySelectorAll('[data-physics]').forEach(input => {
      const key = input.dataset.physics;
      input.value = String(physics[key]);
      const output = document.querySelector(`[data-output="${key}"]`);
      if (output) output.textContent = formatPhysicsValue(key, physics[key]);
    });
    resetCamera();
    loadGraph();
  }

  function renderError(error) {
    const overlay = document.getElementById('cortexStateOverlay');
    const stats = document.getElementById('cortexStats');
    if (stats) stats.textContent = 'Indisponível';
    if (!overlay) return;
    overlay.innerHTML = `<span class="icon">${Util.icon('warning')}</span><span class="title">Não foi possível carregar o Cortex</span><span class="desc">${Util.escape(error.message)}</span><button id="cortexRetry" class="btn btn-glass btn-sm" type="button">${Util.icon('refresh')}<span>Tentar novamente</span></button>`;
    overlay.classList.remove('hidden');
    overlay.querySelector('#cortexRetry')?.addEventListener('click', loadGraph);
  }

  function recomputeVisible(restartLayout = false) {
    const query = Util.normalize(searchQuery.trim());
    visibleNodes = nodes.filter(node => {
      if (hideOrphans && !(nodeNeighbors.get(node.id)?.size > 0)) return false;
      if (selectedGroups.size && !selectedGroups.has(node.group)) return false;
      if (!query) return true;
      return Util.normalize(`${node.label} ${node.group} ${node.path || ''} ${node.content || ''}`).includes(query);
    });
    visibleNodeIds = new Set(visibleNodes.map(node => node.id));
    visibleEdges = edges.filter(edge => visibleNodeIds.has(edge.from) && visibleNodeIds.has(edge.to));
    if (selectedNode && !visibleNodeIds.has(selectedNode.id)) closeNodeDetail();
    updateStats();
    updateGroupFilterState();
    renderList();
    renderCanvas();
    if (restartLayout) startPhysics();
  }

  function renderGroupFilters() {
    const container = document.getElementById('cortexGroupFilters');
    if (!container) return;
    const groups = [...new Set(nodes.map(node => node.group).filter(Boolean))].sort();
    container.innerHTML = groups.map(group => `
      <button class="chip cortex-group-chip" type="button" data-group="${Util.escape(group)}" aria-pressed="false" style="--group-color:${GROUP_COLORS[group] || '#94A8BE'}">
        <span class="cortex-group-dot" style="--group-color:${GROUP_COLORS[group] || '#94A8BE'}"></span>
        ${Util.escape(group)} <span>${nodes.filter(node => node.group === group).length}</span>
      </button>`).join('');
  }

  function updateGroupFilterState() {
    document.querySelectorAll('.cortex-group-chip').forEach(button => {
      const selected = selectedGroups.has(button.dataset.group);
      button.classList.toggle('active', selected);
      button.setAttribute('aria-pressed', String(selected));
    });
    const clear = document.getElementById('cortexClearFilters');
    if (clear) clear.disabled = !selectedGroups.size && !searchQuery.trim();
    const toggle = document.getElementById('cortexFiltersToggle');
    const panel = document.getElementById('cortexFilterPanel');
    if (toggle) toggle.classList.toggle('active', selectedGroups.size > 0 || !panel?.classList.contains('hidden'));
  }

  function updateStats() {
    const stats = document.getElementById('cortexStats');
    if (!stats) return;
    const orphanCount = nodes.filter(node => !(nodeNeighbors.get(node.id)?.size > 0)).length;
    const filtered = visibleNodes.length !== nodes.length || visibleEdges.length !== edges.length;
    stats.textContent = filtered
      ? `${visibleNodes.length}/${nodes.length} nós • ${visibleEdges.length}/${edges.length} arestas${hideOrphans ? ` • ${orphanCount} órfãos ocultos` : ''}`
      : `${nodes.length} nós • ${edges.length} arestas`;
  }

  function toggleViewMode() {
    viewMode = viewMode === 'graph' ? 'list' : 'graph';
    const graph = document.getElementById('cortexGraphView');
    const list = document.getElementById('cortexListView');
    const button = document.getElementById('cortexViewToggle');
    graph?.classList.toggle('hidden', viewMode !== 'graph');
    list?.classList.toggle('hidden', viewMode !== 'list');
    if (button) {
      button.innerHTML = viewMode === 'graph' ? `${Util.icon('list')}<span>Lista</span>` : `${Util.icon('cortex')}<span>Grafo</span>`;
      button.setAttribute('aria-pressed', String(viewMode === 'list'));
      button.classList.toggle('active', viewMode === 'list');
    }
    if (viewMode === 'list') renderList();
    else renderCanvas();
  }

  function toggleFilterPanel() {
    const panel = document.getElementById('cortexFilterPanel');
    const button = document.getElementById('cortexFiltersToggle');
    if (!panel || !button) return;
    const opening = panel.classList.contains('hidden');
    panel.classList.toggle('hidden', !opening);
    button.setAttribute('aria-expanded', String(opening));
    button.classList.toggle('active', opening || selectedGroups.size > 0);
  }

  function clearFilters() {
    searchQuery = '';
    selectedGroups.clear();
    const search = document.getElementById('cortexSearch');
    if (search) search.value = '';
    recomputeVisible(true);
  }

  function renderList() {
    const container = document.getElementById('cortexList');
    if (!container) return;
    if (!visibleNodes.length) {
      container.innerHTML = `<div class="glass state-box"><span class="icon">${Util.icon('search')}</span><span class="title">Nenhum nó encontrado</span><span class="desc">Ajuste a busca ou os filtros de grupo.</span></div>`;
      return;
    }
    const groups = [...new Set(visibleNodes.map(node => node.group))].sort();
    container.innerHTML = groups.map(group => {
      const groupNodes = visibleNodes.filter(node => node.group === group).sort((a, b) => (b.degree || 0) - (a.degree || 0) || String(a.label).localeCompare(String(b.label), 'pt-BR'));
      return `<section class="cortex-list-group">
        <header><span class="cortex-group-dot" style="--group-color:${GROUP_COLORS[group] || '#94A8BE'}"></span><h3>${Util.escape(group)}</h3><span class="text-xs">${groupNodes.length}</span></header>
        <div class="cortex-list-items">${groupNodes.map(node => `
          <button class="glass glass-hover cortex-list-item${selectedNode?.id === node.id ? ' is-selected' : ''}" type="button" data-node-id="${Util.escape(node.id)}">
            <span class="cortex-list-accent" style="--group-color:${GROUP_COLORS[group] || '#94A8BE'}"></span>
            <span class="cortex-list-copy"><strong>${Util.escape(node.label)}</strong><small>${Util.escape(node.path || 'Sem caminho')}</small></span>
            <span class="badge badge-todo">${Number(node.degree || 0)} relações</span>
          </button>`).join('')}</div>
      </section>`;
    }).join('');
    container.querySelectorAll('[data-node-id]').forEach(button => {
      button.addEventListener('click', () => showNodeDetail(nodeById.get(button.dataset.nodeId)));
    });
  }

  function showNodeDetail(node) {
    if (!node) return;
    selectedNode = node;
    selectedNeighborIds = new Set(getConnectedNodes(node.id).map(candidate => candidate.id));
    const detail = document.getElementById('cortexNodeDetail');
    if (!detail) return;
    detail.classList.remove('hidden');
    document.getElementById('detailTitle').textContent = node.label || 'Nó';
    const group = document.getElementById('detailGroup');
    group.textContent = node.group || 'sem grupo';
    group.style.color = GROUP_COLORS[node.group] || '#94A8BE';
    document.getElementById('detailPath').textContent = node.path || '';
    document.getElementById('detailContent').textContent = stripFrontmatter(node.content || '').slice(0, 2000) || 'Sem conteúdo textual.';

    const connected = getConnectedNodes(node.id).sort((a, b) => (b.degree || 0) - (a.degree || 0));
    const connections = document.getElementById('detailConnections');
    connections.innerHTML = connected.length
      ? `<div class="cortex-control-label">CONEXÕES (${connected.length})</div><div class="cortex-connection-list">${connected.slice(0, 20).map(candidate => `<button class="chip" type="button" data-connected-id="${Util.escape(candidate.id)}">${Util.escape(candidate.label)}</button>`).join('')}</div>${connected.length > 20 ? `<div class="text-xs">+ ${connected.length - 20} conexões</div>` : ''}`
      : '<div class="text-xs">Sem conexões diretas.</div>';
    connections.querySelectorAll('[data-connected-id]').forEach(button => {
      button.addEventListener('click', () => showNodeDetail(nodeById.get(button.dataset.connectedId)));
    });
    document.querySelectorAll('.cortex-list-item').forEach(button => button.classList.toggle('is-selected', button.dataset.nodeId === String(node.id)));
    renderCanvas();
  }

  function closeNodeDetail() {
    selectedNode = null;
    selectedNeighborIds.clear();
    document.getElementById('cortexNodeDetail')?.classList.add('hidden');
    document.querySelectorAll('.cortex-list-item.is-selected').forEach(button => button.classList.remove('is-selected'));
    renderCanvas();
  }

  function buildAdjacencyIndex() {
    const neighbors = new Map();
    for (const edge of edges) {
      if (!neighbors.has(edge.from)) neighbors.set(edge.from, new Set());
      if (!neighbors.has(edge.to)) neighbors.set(edge.to, new Set());
      neighbors.get(edge.from).add(edge.to);
      neighbors.get(edge.to).add(edge.from);
    }
    return neighbors;
  }

  function getConnectedNodes(nodeId) {
    return [...(nodeNeighbors.get(nodeId) || new Set())].map(id => nodeById.get(id)).filter(Boolean);
  }

  function stripFrontmatter(content) {
    return String(content).replace(/^---\s*[\s\S]*?\s*---\s*/, '').trim();
  }

  function startPhysics() {
    if (animationFrame) cancelAnimationFrame(animationFrame);
    const physicsNodes = visibleNodes.slice();
    const physicsEdges = visibleEdges.slice();
    if (!physicsNodes.length) { animationFrame = null; return; }
    frameCount = 0;
    const CELL = 180;
    const MAX_SPEED = 12;
    const MAX_SPRING_FORCE = 1.2;
    const frame = () => {
      if (!active || !physicsNodes.length) { animationFrame = null; return; }
      frameCount++;
      ambientPhase += 0.012;

      // Spatial hash para repulsão O(n) ~ O(n*k) onde k é densidade local
      const grid = new Map();
      for (const node of physicsNodes) {
        if (![node.x, node.y, node.vx, node.vy].every(Number.isFinite)) {
          const radius = 30 * Math.sqrt(node.physicsIndex + 1);
          const angle = node.physicsIndex * 2.399963229728653;
          node.x = Math.cos(angle) * radius;
          node.y = Math.sin(angle) * radius;
          node.vx = 0;
          node.vy = 0;
        }
        const cx = Math.floor(node.x / CELL);
        const cy = Math.floor(node.y / CELL);
        const key = `${cx}:${cy}`;
        if (!grid.has(key)) grid.set(key, []);
        grid.get(key).push(node);
      }

      const NEIGHBORS = [[0,0],[-1,-1],[0,-1],[1,-1],[-1,0],[1,0],[-1,1],[0,1],[1,1]];
      for (const node of physicsNodes) {
        const cx = Math.floor(node.x / CELL);
        const cy = Math.floor(node.y / CELL);
        for (const [dx, dy] of NEIGHBORS) {
          const cell = grid.get(`${cx + dx}:${cy + dy}`);
          if (!cell) continue;
          for (const other of cell) {
            if (other === node) continue;
            if (node.physicsIndex >= other.physicsIndex) continue;
            const deltaX = node.x - other.x;
            const deltaY = node.y - other.y;
            const distanceSquared = deltaX * deltaX + deltaY * deltaY;
            if (distanceSquared > 280000 || distanceSquared < 1) continue;
            const distance = Math.sqrt(distanceSquared);
            const force = physics.repulsion / Math.max(1, distanceSquared);
            const forceX = force * deltaX / distance;
            const forceY = force * deltaY / distance;
            node.vx += forceX;
            node.vy += forceY;
            other.vx -= forceX;
            other.vy -= forceY;
          }
        }
      }

      for (const edge of physicsEdges) {
        const first = nodeById.get(edge.from);
        const second = nodeById.get(edge.to);
        if (!first || !second) continue;
        const deltaX = second.x - first.x;
        const deltaY = second.y - first.y;
        const distance = Math.max(1, Math.hypot(deltaX, deltaY));
        const force = clamp(physics.attraction * (distance - physics.linkDistance), -MAX_SPRING_FORCE, MAX_SPRING_FORCE);
        const forceX = force * deltaX / distance;
        const forceY = force * deltaY / distance;
        first.vx += forceX;
        first.vy += forceY;
        second.vx -= forceX;
        second.vy -= forceY;
      }

      for (const node of physicsNodes) {
        // Movimento ambiente determinístico: mantém o grafo vivo sem reaquecer
        // a simulação ou permitir crescimento ilimitado de energia.
        const ambientX = Math.sin(ambientPhase + node.physicsIndex * 0.137) * 0.0018;
        const ambientY = Math.cos(ambientPhase * 0.87 + node.physicsIndex * 0.173) * 0.0018;
        node.vx = (node.vx - node.x * 0.0002 + ambientX) * 0.84;
        node.vy = (node.vy - node.y * 0.0002 + ambientY) * 0.84;
        const speed = Math.hypot(node.vx, node.vy);
        if (speed > MAX_SPEED) {
          node.vx = node.vx / speed * MAX_SPEED;
          node.vy = node.vy / speed * MAX_SPEED;
        }
        node.x += node.vx;
        node.y += node.vy;
      }

      // Física contínua a 60 Hz e pintura limitada a ~30 Hz para 1.500+ nós.
      if (frameCount % 2 === 0 && viewMode === 'graph') renderCanvas();
      animationFrame = requestAnimationFrame(frame);
    };
    animationFrame = requestAnimationFrame(frame);
  }

  function renderCanvas() {
    if (viewMode !== 'graph') return;
    const canvas = document.getElementById('cortexCanvas');
    if (!canvas) return;
    const context = canvas.getContext('2d');
    const pixelRatio = window.devicePixelRatio || 1;
    const displayWidth = Math.max(1, canvas.clientWidth);
    const displayHeight = Math.max(1, canvas.clientHeight);
    const targetWidth = Math.floor(displayWidth * pixelRatio);
    const targetHeight = Math.floor(displayHeight * pixelRatio);
    if (canvas.width !== targetWidth || canvas.height !== targetHeight) {
      canvas.width = targetWidth;
      canvas.height = targetHeight;
    }
    context.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
    context.clearRect(0, 0, displayWidth, displayHeight);
    const centerX = displayWidth / 2 + offsetX;
    const centerY = displayHeight / 2 + offsetY;

    const focusId = selectedNode?.id || hoveredNode?.id || null;
    for (const edge of visibleEdges) {
      const first = nodeById.get(edge.from);
      const second = nodeById.get(edge.to);
      if (!first || !second) continue;
      const x1 = first.x * scale + centerX;
      const y1 = first.y * scale + centerY;
      const x2 = second.x * scale + centerX;
      const y2 = second.y * scale + centerY;
      if ((x1 < -60 && x2 < -60) || (x1 > displayWidth + 60 && x2 > displayWidth + 60) || (y1 < -60 && y2 < -60) || (y1 > displayHeight + 60 && y2 > displayHeight + 60)) continue;
      const direct = focusId && (edge.from === focusId || edge.to === focusId);
      context.strokeStyle = direct ? (GROUP_COLORS[edge.from === focusId ? second.group : first.group] || '#8BB9D7') : '#94A8BE';
      context.globalAlpha = direct ? .78 : (focusId ? Math.max(.07, physics.linkOpacity * .45) : physics.linkOpacity);
      context.lineWidth = direct ? Math.max(1, 1.35 * scale) : Math.max(0.35, 0.7 * scale);
      context.beginPath();
      context.moveTo(x1, y1);
      context.lineTo(x2, y2);
      context.stroke();
    }
    context.globalAlpha = 1;

    const shouldLabel = scale > 1.1 || visibleNodes.length < 80;
    let finiteNodes = 0;
    for (const node of visibleNodes) {
      if (![node.x, node.y].every(Number.isFinite)) continue;
      finiteNodes++;
      const x = node.x * scale + centerX;
      const y = node.y * scale + centerY;
      if (x < -40 || x > displayWidth + 40 || y < -40 || y > displayHeight + 40) continue;
      const baseRadius = Math.max(3, 4 + Math.sqrt(Math.max(0, Number(node.degree || 0))) * 1.7) * physics.nodeSize;
      const radius = Math.max(2.5, baseRadius * scale);
      const color = GROUP_COLORS[node.group] || '#94A8BE';
      const isSelected = selectedNode?.id === node.id;
      const isNeighbor = selectedNeighborIds.has(node.id);
      const isHovered = hoveredNode?.id === node.id;
      if (isSelected || isHovered || isNeighbor && scale > .28) {
        context.beginPath();
        context.arc(x, y, radius + (isSelected ? 8 : isHovered ? 6 : 3), 0, Math.PI * 2);
        context.fillStyle = isSelected ? 'rgba(37,99,235,0.20)' : isHovered ? 'rgba(34,211,238,0.12)' : 'transparent';
        if (isSelected || isHovered) context.fill();
        context.strokeStyle = isSelected || isHovered ? '#7FB4FF' : color;
        context.globalAlpha = isSelected || isHovered ? 1 : .42;
        context.lineWidth = isSelected ? 2 : 1;
        context.stroke();
        context.globalAlpha = 1;
      }
      context.beginPath();
      context.arc(x, y, radius, 0, Math.PI * 2);
      context.fillStyle = color;
      context.globalAlpha = selectedNode ? (isSelected ? 1 : isNeighbor ? .78 : .14) : isHovered ? 1 : .86;
      context.fill();
      context.globalAlpha = 1;
      if ((shouldLabel || isSelected || isHovered) && radius > 3.5) {
        context.font = '11px DM Sans, sans-serif';
        context.fillStyle = '#FFFFFF';
        context.globalAlpha = selectedNode && !isSelected && !isNeighbor ? .2 : 1;
        context.fillText(String(node.label || '').slice(0, 32), x + radius + 5, y + 4);
        context.globalAlpha = 1;
      }
    }
    canvas.dataset.visibleNodes = String(visibleNodes.length);
    canvas.dataset.finiteNodes = String(finiteNodes);
    canvas.dataset.visibleEdges = String(visibleEdges.length);
  }

  function findNodeAtPointer(canvas, clientX, clientY) {
    const rect = canvas.getBoundingClientRect();
    const worldX = (clientX - rect.left - rect.width / 2 - offsetX) / scale;
    const worldY = (clientY - rect.top - rect.height / 2 - offsetY) / scale;
    let closest = null;
    let closestDistance = Infinity;
    for (const node of visibleNodes) {
      const distance = Math.hypot(node.x - worldX, node.y - worldY);
      const hitRadius = Math.max(12 / scale, (5 + Math.sqrt(Math.max(0, Number(node.degree || 0))) * 1.7) * physics.nodeSize);
      if (distance <= hitRadius && distance < closestDistance) {
        closest = node;
        closestDistance = distance;
      }
    }
    return closest;
  }

  function fitVisibleGraph(userInitiated = false) {
    const canvas = document.getElementById('cortexCanvas');
    if (!canvas || !visibleNodes.length) return;
    if (userInitiated) cameraTouched = true;
    const finiteNodes = visibleNodes.filter(node => Number.isFinite(node.x) && Number.isFinite(node.y));
    if (!finiteNodes.length) return;
    const xs = finiteNodes.map(node => node.x).sort((a, b) => a - b);
    const ys = finiteNodes.map(node => node.y).sort((a, b) => a - b);
    const trim = finiteNodes.length > 200 ? Math.floor(finiteNodes.length * .015) : 0;
    const minX = xs[trim];
    const maxX = xs[xs.length - 1 - trim];
    const minY = ys[trim];
    const maxY = ys[ys.length - 1 - trim];
    const width = Math.max(200, maxX - minX + 180);
    const height = Math.max(200, maxY - minY + 180);
    scale = clamp(Math.min(canvas.clientWidth / width, canvas.clientHeight / height), 0.08, 3);
    offsetX = -((minX + maxX) / 2) * scale;
    offsetY = -((minY + maxY) / 2) * scale;
    updateZoomLabel();
    renderCanvas();
  }

  function setZoom(value, userInitiated = false) {
    if (userInitiated) cameraTouched = true;
    scale = clamp(value, 0.05, 8);
    updateZoomLabel();
    renderCanvas();
  }

  function resetCamera() {
    scale = 0.39;
    offsetX = 0;
    offsetY = 0;
    cameraTouched = false;
    updateZoomLabel();
  }

  function updateZoomLabel() {
    const label = document.getElementById('cortexZoomLevel');
    if (label) label.textContent = `${Math.round(scale * 100)}%`;
  }

  function formatPhysicsValue(key, value) {
    if (key === 'attraction') return Number(value).toFixed(3);
    if (key === 'linkOpacity' || key === 'nodeSize') return Number(value).toFixed(1);
    return String(Math.round(Number(value)));
  }

  function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
  }

  function destroy() {
    active = false;
    loadSequence++;
    if (animationFrame) cancelAnimationFrame(animationFrame);
    clearTimeout(searchDebounce);
    resizeObserver?.disconnect();
    resizeObserver = null;
    animationFrame = null;
    nodes = [];
    edges = [];
    visibleNodes = [];
    visibleEdges = [];
    visibleNodeIds = new Set();
    nodeById = new Map();
    nodeNeighbors = new Map();
    selectedNeighborIds.clear();
    hoveredNode = null;
    interaction = null;
  }

  function diagnostics() {
    const canvas = document.getElementById('cortexCanvas');
    const rect = canvas?.getBoundingClientRect();
    const first = visibleNodes.find(node => Number.isFinite(node.x) && Number.isFinite(node.y));
    return {
      totalNodes: nodes.length,
      totalEdges: edges.length,
      visibleNodes: visibleNodes.length,
      visibleEdges: visibleEdges.length,
      finiteNodes: visibleNodes.filter(node => Number.isFinite(node.x) && Number.isFinite(node.y)).length,
      hideOrphans,
      animationRunning: active && animationFrame !== null,
      frameCount,
      firstNode: first && rect ? {
        id: first.id,
        x: rect.left + rect.width / 2 + offsetX + first.x * scale,
        y: rect.top + rect.height / 2 + offsetY + first.y * scale,
      } : null,
    };
  }

  return { render, destroy, diagnostics };
})();
