/* ═══════════════════════════════════════════════════════════════
   NOVA HUB V5 WEB — ARCADIA Module
   ═══════════════════════════════════════════════════════════════ */
const ArcadiaModule = (() => {
  const STATUSES = [
    { key: 'all', label: 'Todos' },
    { key: 'wishlist', label: 'Desejos' },
    { key: 'backlog', label: 'Backlog' },
    { key: 'playing', label: 'Jogando' },
    { key: 'done', label: 'Zerados' },
    { key: 'dropped', label: 'Abandonados' },
  ];
  const IGDB_COVER = (id, size = 't_cover_big') => id
    ? `https://images.igdb.com/igdb/image/upload/${size}/${encodeURIComponent(id)}.jpg`
    : '';

  let library = [];
  let news = [];
  let searchResults = [];
  let selectedLibraryGame = null;
  let selectedSearchGame = null;
  let statusFilter = 'all';
  let libraryView = 'grid';
  let editRating = 0;
  let addRating = 0;
  let searchTimer = null;
  let searchSequence = 0;
  let loadSequence = 0;
  let active = false;
  let newsLoaded = false;
  let moonlightLoaded = false;
  let feedbackTimer = null;
  let newsQuery = '';
  let newsSource = 'all';
  let newsUpdatedAt = null;
  const NEWS_IMAGE_CACHE_KEY = 'nova_news_image_cache';
  const newsImageCache = loadNewsImageCache();

  function loadNewsImageCache() {
    try { return JSON.parse(localStorage.getItem(NEWS_IMAGE_CACHE_KEY) || '{}'); } catch { return {}; }
  }

  function saveNewsImageCache() {
    try { localStorage.setItem(NEWS_IMAGE_CACHE_KEY, JSON.stringify(newsImageCache)); } catch {}
  }

  function isInvalidNewsImage(url) {
    if (!url) return true;
    const u = url.toLowerCase();
    if (u.includes('youtube.com/embed/') || u.includes('youtu.be/')) return true;
    if (u.startsWith('data:')) return true;
    return false;
  }

  function newsItemKey(item) {
    return item.link || item.title || '';
  }

  function render() {
    active = true;
    statusFilter = 'all';
    libraryView = 'grid';
    selectedLibraryGame = null;
    selectedSearchGame = null;
    searchResults = [];
    newsLoaded = false;
    moonlightLoaded = false;
    newsQuery = '';
    newsSource = 'all';
    newsUpdatedAt = null;

    const element = document.createElement('div');
    element.className = 'arcadia-module';
    element.innerHTML = `
      <div class="module-header arcadia-header">
        ${Util.moduleHeading('arcadia', 'NOVA Arcadia', 'Biblioteca, descoberta e streaming pessoal')}
        <div class="arcadia-tabs" role="tablist" aria-label="Seções do Arcadia">
          <button class="btn btn-glass btn-sm active" type="button" data-arcadia-tab="library" role="tab" aria-selected="true">${Util.icon('grid')}<span>Biblioteca</span></button>
          <button class="btn btn-glass btn-sm" type="button" data-arcadia-tab="news" role="tab" aria-selected="false">${Util.icon('list')}<span>Notícias</span></button>
          <button class="btn btn-glass btn-sm" type="button" data-arcadia-tab="moonlight" role="tab" aria-selected="false">${Util.icon('link')}<span>Moonlight</span></button>
        </div>
      </div>
      <div id="arcadiaFeedback" class="arcadia-feedback hidden" role="status" aria-live="polite"></div>

      <section id="arcadiaLibraryPanel" class="arcadia-panel" role="tabpanel">
        <div class="glass arcadia-search-shell">
          <div class="arcadia-search-row">
            <label class="arcadia-search-field">
              <span class="sr-only">Buscar jogos na IGDB</span>
              <span class="input-leading-icon">${Util.icon('search')}</span>
              <input id="searchGames" class="input" type="search" placeholder="Buscar jogos na IGDB…" autocomplete="off">
            </label>
            <button id="clearGameSearch" class="btn btn-glass btn-sm" type="button" disabled>${Util.icon('close')}<span>Limpar</span></button>
          </div>
          <div id="arcadiaSearchStatus" class="text-xs">Digite ao menos 3 caracteres. A biblioteca local permanece disponível mesmo sem IGDB.</div>
          <div id="searchResults" class="arcadia-search-results hidden"></div>
        </div>

        <div class="arcadia-library-toolbar">
          <div id="arcadiaStatusFilters" class="arcadia-status-filters" aria-label="Filtrar biblioteca por status"></div>
          <span id="arcadiaLibrarySummary" class="text-xs" aria-live="polite"></span>
          <button id="arcadiaViewToggle" class="btn btn-glass btn-sm" type="button" aria-pressed="false">${Util.icon('list')}<span>Lista</span></button>
        </div>
        <div id="arcadiaFeatured" class="arcadia-featured hidden"></div>
        <div id="libraryGrid" class="arcadia-library-grid" aria-live="polite">
          <div class="state-box"><span class="spinner"></span><span class="desc">Carregando biblioteca…</span></div>
        </div>
      </section>

      <section id="arcadiaNewsPanel" class="arcadia-panel hidden" role="tabpanel">
        <div class="glass arcadia-news-toolbar">
          <label class="arcadia-news-search"><span class="sr-only">Buscar nas notícias carregadas</span><span class="input-leading-icon">${Util.icon('search')}</span><input id="arcadiaNewsSearch" class="input" type="search" placeholder="Buscar nas notícias…" autocomplete="off"></label>
          <select id="arcadiaNewsSource" class="input" aria-label="Filtrar notícias por fonte"><option value="all">Todas as fontes</option></select>
          <span id="arcadiaNewsUpdated" class="text-xs">Ainda não atualizado</span>
          <button id="arcadiaNewsRefresh" class="btn btn-glass btn-sm" type="button">${Util.icon('refresh')}<span>Atualizar</span></button>
        </div>
        <div id="newsList"><div class="state-box"><span class="desc">Abra a aba para carregar as notícias.</span></div></div>
      </section>

      <section id="arcadiaMoonlightPanel" class="arcadia-panel hidden" role="tabpanel">
        <div id="moonlightContent"><div class="state-box"><span class="desc">Abra a aba para verificar o Sunshine.</span></div></div>
      </section>

      ${libraryDialogMarkup()}
      ${addDialogMarkup()}
    `;

    bindEvents(element);
    renderStatusFilters();
    loadLibrary();
    return element;
  }

  function libraryDialogMarkup() {
    return `
      <div id="arcadiaLibraryDialog" class="nova-modal hidden" role="dialog" aria-modal="true" aria-labelledby="arcadiaLibraryDialogTitle">
        <div class="glass nova-modal-card arcadia-detail-modal">
          <div class="nova-modal-header">
            <div><h3 id="arcadiaLibraryDialogTitle" class="h4">Detalhes do jogo</h3><div class="text-xs">Na sua biblioteca</div></div>
            <button class="btn btn-glass btn-icon" type="button" data-close-dialog="arcadiaLibraryDialog" aria-label="Fechar">${Util.icon('close')}</button>
          </div>
          <div id="arcadiaLibraryDetail"></div>
          <div id="arcadiaLibraryDialogError" class="arcadia-dialog-error hidden" role="alert"></div>
          <div class="nova-modal-actions arcadia-detail-actions">
            <button class="btn btn-danger btn-sm" id="arcadiaDeleteGame" type="button">${Util.icon('trash')}<span>Excluir</span></button>
            <span class="arcadia-action-spacer"></span>
            <button class="btn btn-glass btn-sm" type="button" data-close-dialog="arcadiaLibraryDialog">Cancelar</button>
            <button class="btn btn-primary btn-sm" id="arcadiaSaveGame" type="button">${Util.icon('check')}<span>Salvar alterações</span></button>
          </div>
        </div>
      </div>`;
  }

  function addDialogMarkup() {
    return `
      <div id="arcadiaAddDialog" class="nova-modal hidden" role="dialog" aria-modal="true" aria-labelledby="arcadiaAddDialogTitle">
        <div class="glass nova-modal-card nova-modal-card-sm">
          <div class="nova-modal-header">
            <div><h3 id="arcadiaAddDialogTitle" class="h4">Adicionar à biblioteca</h3><div id="arcadiaAddGameName" class="text-xs"></div></div>
            <button class="btn btn-glass btn-icon" type="button" data-close-dialog="arcadiaAddDialog" aria-label="Fechar">${Util.icon('close')}</button>
          </div>
          <div class="nova-form-stack">
            <label class="form-group"><span>Status inicial</span><select id="arcadiaAddStatus" class="input">${statusOptions('backlog')}</select></label>
            <div class="form-group"><span>Minha avaliação</span><div id="arcadiaAddRating" class="arcadia-rating" aria-label="Avaliação de zero a cinco"></div></div>
            <label class="form-group"><span>Notas pessoais</span><textarea id="arcadiaAddNotes" class="input" rows="5" placeholder="Suas impressões sobre o jogo…"></textarea></label>
          </div>
          <div id="arcadiaAddDialogError" class="arcadia-dialog-error hidden" role="alert"></div>
          <div class="nova-modal-actions">
            <button class="btn btn-glass btn-sm" type="button" data-close-dialog="arcadiaAddDialog">Cancelar</button>
            <button class="btn btn-primary btn-sm" id="arcadiaConfirmAdd" type="button">${Util.icon('plus')}<span>Adicionar</span></button>
          </div>
        </div>
      </div>`;
  }

  function bindEvents(element) {
    element.querySelectorAll('[data-arcadia-tab]').forEach(button => {
      button.addEventListener('click', () => showTab(button.dataset.arcadiaTab));
    });

    const searchInput = element.querySelector('#searchGames');
    searchInput.addEventListener('input', () => scheduleSearch(searchInput.value));
    searchInput.addEventListener('keydown', event => {
      if (event.key === 'Enter' && searchInput.value.trim().length >= 3) {
        event.preventDefault();
        clearTimeout(searchTimer);
        search(searchInput.value.trim());
      }
    });
    element.querySelector('#clearGameSearch').addEventListener('click', clearSearch);
    element.querySelector('#arcadiaStatusFilters').addEventListener('click', event => {
      const button = event.target.closest('[data-library-status]');
      if (!button) return;
      statusFilter = button.dataset.libraryStatus;
      renderStatusFilters();
      renderLibrary();
    });
    element.querySelector('#arcadiaViewToggle').addEventListener('click', toggleLibraryView);
    element.querySelector('#arcadiaNewsSearch').addEventListener('input', event => {
      newsQuery = event.target.value;
      renderNews();
    });
    element.querySelector('#arcadiaNewsSource').addEventListener('change', event => {
      newsSource = event.target.value;
      renderNews();
    });
    element.querySelector('#arcadiaNewsRefresh').addEventListener('click', loadNews);
    element.querySelector('#arcadiaSaveGame').addEventListener('click', saveLibraryGame);
    element.querySelector('#arcadiaDeleteGame').addEventListener('click', deleteLibraryGame);
    element.querySelector('#arcadiaConfirmAdd').addEventListener('click', addToLibrary);

    element.addEventListener('click', event => {
      const ratingButton = event.target.closest('[data-rating-target]');
      if (ratingButton) setRating(ratingButton.dataset.ratingTarget, Number(ratingButton.dataset.rating));
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

  function showTab(tab) {
    const panels = {
      library: document.getElementById('arcadiaLibraryPanel'),
      news: document.getElementById('arcadiaNewsPanel'),
      moonlight: document.getElementById('arcadiaMoonlightPanel'),
    };
    Object.entries(panels).forEach(([key, panel]) => panel?.classList.toggle('hidden', key !== tab));
    document.querySelectorAll('[data-arcadia-tab]').forEach(button => {
      const selected = button.dataset.arcadiaTab === tab;
      button.classList.toggle('active', selected);
      button.setAttribute('aria-selected', String(selected));
    });
    if (tab === 'news' && !newsLoaded) loadNews();
    if (tab === 'moonlight' && !moonlightLoaded) loadMoonlight();
  }

  async function loadLibrary() {
    const sequence = ++loadSequence;
    const grid = document.getElementById('libraryGrid');
    if (grid) grid.innerHTML = '<div class="state-box"><span class="spinner"></span><span class="desc">Carregando biblioteca…</span></div>';
    try {
      const response = await API.getLibrary();
      if (!active || sequence !== loadSequence) return;
      library = Array.isArray(response) ? response : [];
      renderStatusFilters();
      renderLibrary();
    } catch (error) {
      if (!active || sequence !== loadSequence || !grid) return;
      grid.innerHTML = errorState('Biblioteca indisponível', error.message, 'arcadiaLibraryRetry');
      grid.querySelector('#arcadiaLibraryRetry')?.addEventListener('click', loadLibrary);
    }
  }

  function renderStatusFilters() {
    const container = document.getElementById('arcadiaStatusFilters');
    if (!container) return;
    container.innerHTML = STATUSES.map(status => {
      const count = status.key === 'all' ? library.length : library.filter(game => game.status === status.key).length;
      const selected = statusFilter === status.key;
      return `<button class="chip arcadia-status-chip${selected ? ' active' : ''}" type="button" data-library-status="${status.key}" aria-pressed="${selected}">${status.label} <span>${count}</span></button>`;
    }).join('');
  }

  function renderLibrary() {
    const grid = document.getElementById('libraryGrid');
    const featured = document.getElementById('arcadiaFeatured');
    if (!grid) return;
    const filtered = statusFilter === 'all' ? library : library.filter(game => game.status === statusFilter);
    grid.className = `arcadia-library-grid ${libraryView === 'list' ? 'arcadia-library-list' : ''}`;
    const summary = document.getElementById('arcadiaLibrarySummary');
    if (summary) summary.textContent = `${filtered.length} de ${library.length} jogos`;

    if (!filtered.length) {
      featured?.classList.add('hidden');
      grid.innerHTML = `<div class="glass state-box"><span class="icon">${Util.icon('arcadia')}</span><span class="title">${library.length ? 'Nenhum jogo neste status' : 'Biblioteca vazia'}</span><span class="desc">${library.length ? 'Escolha outro filtro.' : 'Pesquise na IGDB para adicionar seu primeiro jogo.'}</span></div>`;
      return;
    }
    renderFeatured(filtered);
    grid.innerHTML = filtered.map(gameCard).join('');
    wireCoverFallbacks(grid);
    grid.querySelectorAll('[data-library-id]').forEach(card => {
      card.addEventListener('click', () => openLibraryGame(card.dataset.libraryId));
    });
  }

  function gameCard(game) {
    const platforms = asStrings(game.platforms);
    const cover = coverMarkup(game.cover_id || game.coverId, game.name, 't_720p');
    return `<button class="glass glass-hover arcadia-game-card" type="button" data-library-id="${Util.escape(game.id)}" data-library-status="${Util.escape(game.status || 'backlog')}">
      <span class="arcadia-game-cover">${cover}<span class="arcadia-cover-overlay"><span>${Util.icon('grid')}</span><span class="arcadia-cover-action">Ver detalhes</span></span></span>
      <span class="arcadia-game-copy">
        <strong>${Util.escape(game.name)}</strong>
        <small>${Util.escape(platforms.slice(0, 3).join(' • ') || 'Plataforma não informada')}</small>
        <span class="arcadia-game-meta"><span class="badge arcadia-status-${Util.escape(game.status || 'backlog')}">${Util.escape(statusLabel(game.status))}</span>${Number(game.user_rating || game.userRating || 0) > 0 ? `<span class="arcadia-user-rating">★ ${Number(game.user_rating || game.userRating)}/5</span>` : ''}</span>
      </span>
    </button>`;
  }

  function renderFeatured(games) {
    const featured = document.getElementById('arcadiaFeatured');
    if (!featured) return;
    if (libraryView === 'list' || games.length > 2) {
      featured.classList.add('hidden');
      featured.replaceChildren();
      return;
    }
    const game = games[0];
    featured.innerHTML = `<button class="glass glass-hover arcadia-featured-card" type="button" data-featured-id="${Util.escape(game.id)}">
      <span class="arcadia-featured-art">${coverMarkup(game.cover_id || game.coverId, game.name, 't_1080p')}</span>
      <span class="arcadia-featured-copy"><span class="arcadia-section-label">EM DESTAQUE</span><strong>${Util.escape(game.name)}</strong><small>${Util.escape(asStrings(game.platforms).join(' • ') || 'Plataforma não informada')}</small><span class="badge arcadia-status-${Util.escape(game.status || 'backlog')}">${Util.escape(statusLabel(game.status))}</span><span class="arcadia-featured-action">Abrir coleção ${Util.icon('grid')}</span></span>
    </button>`;
    featured.classList.remove('hidden');
    wireCoverFallbacks(featured);
    featured.querySelector('[data-featured-id]')?.addEventListener('click', () => openLibraryGame(game.id));
  }

  function openLibraryGame(id) {
    const game = library.find(candidate => String(candidate.id) === String(id));
    if (!game) return;
    selectedLibraryGame = game;
    editRating = clampRating(game.user_rating ?? game.userRating ?? 0);
    const detail = document.getElementById('arcadiaLibraryDetail');
    detail.innerHTML = `
      <div class="arcadia-detail-hero">
        <div class="arcadia-detail-cover">${coverMarkup(game.cover_id || game.coverId, game.name, 't_1080p')}</div>
        <div class="arcadia-detail-copy">
          <h4>${Util.escape(game.name)}</h4>
          <div class="text-sm">${Util.escape(asStrings(game.platforms).join(' • ') || 'Plataforma não informada')}</div>
          <div class="arcadia-detail-tags">${asStrings(game.genres).map(genre => `<span class="chip">${Util.escape(genre)}</span>`).join('')}</div>
          ${Number(game.rating || 0) > 0 ? `<div class="text-sm arcadia-igdb-rating">★ IGDB ${Number(game.rating).toFixed(1)}</div>` : ''}
          ${releaseYear(game.release_date ?? game.releaseDate) ? `<div class="text-xs">Lançamento: ${releaseYear(game.release_date ?? game.releaseDate)}</div>` : ''}
        </div>
      </div>
      ${game.summary ? `<div class="glass arcadia-summary"><div class="arcadia-section-label">SOBRE</div><p>${Util.escape(game.summary)}</p></div>` : ''}
      <div class="arcadia-edit-grid">
        <label class="form-group"><span>Status</span><select id="arcadiaEditStatus" class="input">${statusOptions(game.status)}</select></label>
        <div class="form-group"><span>Minha avaliação</span><div id="arcadiaEditRating" class="arcadia-rating"></div></div>
      </div>
      <label class="form-group"><span>Notas pessoais</span><textarea id="arcadiaEditNotes" class="input" rows="6" placeholder="Suas impressões sobre o jogo…">${Util.escape(game.notes || '')}</textarea></label>`;
    renderRating('edit', editRating);
    wireCoverFallbacks(detail);
    clearDialogError('arcadiaLibraryDialogError');
    openDialog('arcadiaLibraryDialog', '[data-close-dialog="arcadiaLibraryDialog"]');
  }

  async function saveLibraryGame() {
    if (!selectedLibraryGame) return;
    const button = document.getElementById('arcadiaSaveGame');
    setBusy(button, true);
    clearDialogError('arcadiaLibraryDialogError');
    try {
      await API.updateGame(selectedLibraryGame.id, {
        status: document.getElementById('arcadiaEditStatus').value,
        user_rating: editRating,
        notes: document.getElementById('arcadiaEditNotes').value.trim(),
      });
      closeDialog('arcadiaLibraryDialog');
      await loadLibrary();
      setFeedback('Jogo atualizado e sincronizado.', 'success');
    } catch (error) {
      setDialogError('arcadiaLibraryDialogError', error.message);
    } finally {
      setBusy(button, false);
    }
  }

  async function deleteLibraryGame() {
    if (!selectedLibraryGame) return;
    if (!confirm(`Excluir “${selectedLibraryGame.name}” da biblioteca?`)) return;
    const button = document.getElementById('arcadiaDeleteGame');
    setBusy(button, true);
    clearDialogError('arcadiaLibraryDialogError');
    try {
      await API.deleteGame(selectedLibraryGame.id);
      closeDialog('arcadiaLibraryDialog');
      await loadLibrary();
      setFeedback('Jogo removido da biblioteca.', 'success');
    } catch (error) {
      setDialogError('arcadiaLibraryDialogError', error.message);
    } finally {
      setBusy(button, false);
    }
  }

  function scheduleSearch(value) {
    clearTimeout(searchTimer);
    const query = value.trim();
    const clear = document.getElementById('clearGameSearch');
    if (clear) clear.disabled = !query;
    if (query.length < 3) {
      searchSequence++;
      searchResults = [];
      const results = document.getElementById('searchResults');
      results?.classList.add('hidden');
      setSearchStatus('Digite ao menos 3 caracteres. A biblioteca local permanece disponível mesmo sem IGDB.');
      return;
    }
    setSearchStatus('Aguardando busca…');
    searchTimer = setTimeout(() => search(query), 500);
  }

  async function search(query) {
    const sequence = ++searchSequence;
    const results = document.getElementById('searchResults');
    if (!results) return;
    results.classList.remove('hidden');
    results.innerHTML = '<div class="state-box arcadia-search-state"><span class="spinner"></span><span class="desc">Consultando IGDB…</span></div>';
    setSearchStatus(`Buscando “${query}”…`);
    try {
      const response = await API.searchGames(query);
      if (!active || sequence !== searchSequence) return;
      searchResults = Array.isArray(response) ? response : [];
      renderSearchResults(query);
    } catch (error) {
      if (!active || sequence !== searchSequence) return;
      searchResults = [];
      results.innerHTML = `<div class="state-box arcadia-search-state"><span class="icon">${Util.icon('warning')}</span><span class="title">IGDB temporariamente indisponível</span><span class="desc">${Util.escape(error.message)}. Sua biblioteca local continua operacional.</span><button id="arcadiaSearchRetry" class="btn btn-glass btn-sm" type="button">${Util.icon('refresh')}<span>Tentar novamente</span></button></div>`;
      results.querySelector('#arcadiaSearchRetry')?.addEventListener('click', () => search(query));
      setSearchStatus('Integração IGDB degradada; biblioteca local preservada.', 'warning');
    }
  }

  function renderSearchResults(query) {
    const results = document.getElementById('searchResults');
    if (!results) return;
    if (!searchResults.length) {
      results.innerHTML = `<div class="state-box arcadia-search-state"><span class="icon">${Util.icon('search')}</span><span class="title">Nenhum resultado</span><span class="desc">A IGDB não encontrou “${Util.escape(query)}”.</span></div>`;
      setSearchStatus('Busca concluída sem resultados.');
      return;
    }
    results.innerHTML = `<div class="arcadia-search-grid">${searchResults.slice(0, 16).map(searchResultCard).join('')}</div>`;
    wireCoverFallbacks(results);
    results.querySelectorAll('.arcadia-add-btn').forEach(button => {
      button.addEventListener('click', () => openAddDialog(button.dataset.igdbId));
    });
    setSearchStatus(`${searchResults.length} resultado${searchResults.length === 1 ? '' : 's'} encontrado${searchResults.length === 1 ? '' : 's'}.`);
  }

  function searchResultCard(game) {
    const alreadyAdded = library.some(item => Number(item.igdb_id ?? item.igdbId) === Number(game.id));
    return `<article class="glass arcadia-search-card">
      <div class="arcadia-search-cover">${coverMarkup(game.cover_id || game.coverId, game.name)}</div>
      <div class="arcadia-search-copy">
        <h4>${Util.escape(game.name)}</h4>
        <div class="text-xs">${Util.escape([releaseYear(game.release_date ?? game.releaseDate), ...asStrings(game.platforms).slice(0, 3)].filter(Boolean).join(' • '))}</div>
        ${Number(game.rating || 0) > 0 ? `<div class="text-xs arcadia-igdb-rating">★ ${(Number(game.rating) / 20).toFixed(1)}/5</div>` : ''}
        ${game.summary ? `<p class="text-xs">${Util.escape(String(game.summary).slice(0, 150))}${String(game.summary).length > 150 ? '…' : ''}</p>` : ''}
        <button class="btn ${alreadyAdded ? 'btn-glass' : 'btn-primary'} btn-sm arcadia-add-btn" type="button" data-igdb-id="${Util.escape(game.id)}" ${alreadyAdded ? 'disabled' : ''}>${alreadyAdded ? `${Util.icon('check')}<span>Na biblioteca</span>` : `${Util.icon('plus')}<span>Adicionar</span>`}</button>
      </div>
    </article>`;
  }

  function openAddDialog(igdbId) {
    const game = searchResults.find(candidate => String(candidate.id) === String(igdbId));
    if (!game) return;
    selectedSearchGame = game;
    addRating = 0;
    document.getElementById('arcadiaAddGameName').textContent = game.name;
    document.getElementById('arcadiaAddStatus').value = 'backlog';
    document.getElementById('arcadiaAddNotes').value = '';
    renderRating('add', addRating);
    clearDialogError('arcadiaAddDialogError');
    openDialog('arcadiaAddDialog', '#arcadiaAddStatus');
  }

  async function addToLibrary() {
    if (!selectedSearchGame) return;
    const button = document.getElementById('arcadiaConfirmAdd');
    setBusy(button, true);
    clearDialogError('arcadiaAddDialogError');
    try {
      const game = selectedSearchGame;
      await API.addGame({
        igdb_id: Number(game.id),
        name: game.name,
        status: document.getElementById('arcadiaAddStatus').value,
        platforms: asStrings(game.platforms),
        genres: asStrings(game.genres),
        notes: document.getElementById('arcadiaAddNotes').value.trim(),
        cover_id: game.cover_id || game.coverId || '',
        rating: Number(game.rating || 0),
        user_rating: addRating,
        summary: game.summary || '',
      });
      closeDialog('arcadiaAddDialog');
      clearSearch();
      await loadLibrary();
      setFeedback('Jogo adicionado à biblioteca.', 'success');
    } catch (error) {
      setDialogError('arcadiaAddDialogError', error.message);
    } finally {
      setBusy(button, false);
    }
  }

  function clearSearch() {
    clearTimeout(searchTimer);
    searchSequence++;
    searchResults = [];
    const input = document.getElementById('searchGames');
    const results = document.getElementById('searchResults');
    const clear = document.getElementById('clearGameSearch');
    if (input) input.value = '';
    if (results) { results.innerHTML = ''; results.classList.add('hidden'); }
    if (clear) clear.disabled = true;
    setSearchStatus('Digite ao menos 3 caracteres. A biblioteca local permanece disponível mesmo sem IGDB.');
  }

  async function loadNews() {
    const container = document.getElementById('newsList');
    const refresh = document.getElementById('arcadiaNewsRefresh');
    if (!container) return;
    if (refresh) { refresh.disabled = true; refresh.classList.add('is-loading'); }
    container.innerHTML = '<div class="state-box"><span class="spinner"></span><span class="desc">Carregando notícias…</span></div>';
    try {
      const response = await API.getNews();
      if (!active) return;
      news = Array.isArray(response) ? response : Array.isArray(response.items) ? response.items : [];
      newsLoaded = true;
      newsUpdatedAt = new Date();
      updateNewsSources();
      renderNews();
      enrichMissingImages();
    } catch (error) {
      container.innerHTML = errorState('Notícias indisponíveis', error.message, 'arcadiaNewsRetry');
      container.querySelector('#arcadiaNewsRetry')?.addEventListener('click', loadNews);
    } finally {
      if (refresh) { refresh.disabled = false; refresh.classList.remove('is-loading'); }
    }
  }

  function updateNewsSources() {
    const select = document.getElementById('arcadiaNewsSource');
    if (!select) return;
    const sources = [...new Set(news.map(item => String(item.source || '').trim()).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'pt-BR'));
    select.innerHTML = `<option value="all">Todas as fontes</option>${sources.map(source => `<option value="${Util.escape(source)}">${Util.escape(source)}</option>`).join('')}`;
    if (sources.includes(newsSource)) select.value = newsSource;
    else newsSource = 'all';
  }

  async function enrichMissingImages() {
    // Apply cached images first
    let changed = false;
    news.forEach(item => {
      const key = newsItemKey(item);
      if (newsImageCache[key]) {
        if (!item.image || isInvalidNewsImage(item.image) || item.image === newsImageCache[key]) {
          if (item.image !== newsImageCache[key]) {
            item.image = newsImageCache[key];
            changed = true;
          }
        }
      }
    });
    if (changed) renderNews();

    // Find items needing server-side enrichment
    const needsEnrichment = news.filter(item => {
      if (item.image && !isInvalidNewsImage(item.image)) return false;
      const key = newsItemKey(item);
      return !newsImageCache[key];
    }).slice(0, 8); // limit to 8 items per batch

    if (!needsEnrichment.length) return;

    try {
      const urls = needsEnrichment.map(item => ({ id: newsItemKey(item), url: item.link }));
      const result = await API.enrichNewsImages(urls);
      const results = Array.isArray(result?.results) ? result.results : [];
      let updated = false;
      for (const { id, image } of results) {
        if (!image) continue;
        const item = news.find(n => newsItemKey(n) === id);
        if (!item) continue;
        if (!item.image || isInvalidNewsImage(item.image)) {
          item.image = image;
          newsImageCache[id] = image;
          updated = true;
        }
      }
      if (updated) {
        saveNewsImageCache();
        renderNews();
      }
    } catch (err) {
      console.warn('[arcadia] enrichMissingImages failed:', err.message);
    }
  }

  function renderNews() {
    const container = document.getElementById('newsList');
    if (!container || !newsLoaded) return;
    const query = Util.normalize(newsQuery.trim());
    const portuguese = news.filter(item => item.lang === 'pt' || String(item.lang).startsWith('pt'));
    const base = portuguese.length ? portuguese : news;
    const displayed = base.filter(item => {
      if (newsSource !== 'all' && item.source !== newsSource) return false;
      if (!query) return true;
      return Util.normalize(`${item.title || ''} ${item.summary || ''} ${item.source || ''}`).includes(query);
    }).slice(0, 30);
    const updated = document.getElementById('arcadiaNewsUpdated');
    if (updated && newsUpdatedAt) updated.textContent = `Atualizado às ${newsUpdatedAt.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })} • ${displayed.length} itens`;
    container.innerHTML = displayed.length
      ? `<div class="arcadia-news-grid">${displayed.map((item, index) => newsCard(item, index)).join('')}</div>`
      : `<div class="glass state-box"><span class="icon">${Util.icon('search')}</span><span class="title">Nenhuma notícia encontrada</span><span class="desc">Ajuste a busca local ou selecione outra fonte.</span></div>`;
  }

  function newsCard(item, index) {
    const href = safeUrl(item.link);
    const role = index === 0 ? ' is-lead' : index < 3 ? ' is-secondary' : '';
    const source = item.source || 'Fonte';
    const image = item.image;
    const sourceInitials = source.replace(/\s*(Brasil|BR)\s*$/i, '').slice(0, 2).toUpperCase() || 'GA';
    const visual = image
      ? `<img src="${Util.escape(image)}" alt="" loading="lazy" class="arcadia-news-thumb" onerror="this.style.display='none';this.nextElementSibling.style.display='flex'"><span class="arcadia-news-initials" style="display:none"><span>${Util.escape(sourceInitials)}</span><small>EDITORIAL</small></span>`
      : `<span class="arcadia-news-initials"><span>${Util.escape(sourceInitials)}</span><small>EDITORIAL</small></span>`;
    return `<a class="glass glass-hover arcadia-news-card${role}" href="${href}" target="_blank" rel="noopener noreferrer">
      <div class="arcadia-news-visual">${visual}</div>
      <div class="arcadia-news-content"><div class="arcadia-news-source">${Util.escape(source)}</div>
      <h3>${Util.escape(item.title)}</h3>
      ${item.summary ? `<p>${Util.escape(String(item.summary).slice(0, 260))}${String(item.summary).length > 260 ? '…' : ''}</p>` : ''}
      <div class="arcadia-news-footer"><span class="text-xs">${Util.escape(formatPublished(item.published))}</span><span>Abrir notícia →</span></div></div>
    </a>`;
  }

  async function loadMoonlight() {
    const container = document.getElementById('moonlightContent');
    if (!container) return;
    container.innerHTML = '<div class="state-box"><span class="spinner"></span><span class="desc">Verificando Sunshine…</span></div>';
    try {
      const status = await API.getMoonlightStatus();
      if (!active) return;
      moonlightLoaded = true;
      renderMoonlight(status);
    } catch (error) {
      container.innerHTML = errorState('Integração Moonlight indisponível', error.message, 'arcadiaMoonlightRetry');
      container.querySelector('#arcadiaMoonlightRetry')?.addEventListener('click', loadMoonlight);
    }
  }

  function renderMoonlight(status) {
    const container = document.getElementById('moonlightContent');
    if (!container) return;
    const online = status.sunshine === 'online';
    const host = status.host || status.tailscale_ip || 'pop-os';
    const tailscaleIp = status.tailscale_ip || '';
    container.innerHTML = `<div class="arcadia-moonlight-layout">
      <section class="glass arcadia-moonlight-card">
        <div class="arcadia-stream-waves" aria-hidden="true"><span></span><span></span><span></span></div>
        <div class="arcadia-moonlight-icon">${Util.icon('link')}</div>
        <h3>Moonlight + Sunshine</h3>
        <p>O streaming permanece no cliente Moonlight oficial. O NOVA HUB apenas verifica o host e fornece o endereço; nenhuma credencial Sunshine é enviada ao navegador.</p>
        <div class="arcadia-stream-status ${online ? 'online' : 'offline'}"><span></span>${online ? 'Sunshine online' : 'Sunshine não detectado'}</div>
        <div class="arcadia-host-box"><div><small>Host Tailscale</small><strong>${Util.escape(host)}</strong>${tailscaleIp ? `<span>${Util.escape(tailscaleIp)}</span>` : ''}</div><button id="copyMoonlightHost" class="btn btn-glass btn-sm" type="button" data-copy-value="${Util.escape(host)}">${Util.icon('copy')}<span>Copiar host</span></button></div>
        <div class="arcadia-moonlight-actions">
          <a class="btn btn-primary" href="https://moonlight-stream.org/" target="_blank" rel="noopener noreferrer">${Util.icon('export')}<span>Baixar Moonlight</span></a>
          <a class="btn btn-glass" href="https://play.google.com/store/apps/details?id=com.limelight" target="_blank" rel="noopener noreferrer">${Util.icon('arcadia')}<span>Android</span></a>
        </div>
      </section>
      <aside class="glass arcadia-moonlight-guide">
        <div class="arcadia-section-label">COMO CONECTAR</div>
        <ol><li>Instale o cliente Moonlight oficial no dispositivo.</li><li>Garanta que o dispositivo esteja na mesma tailnet.</li><li>Adicione o host <strong>${Util.escape(host)}</strong>${tailscaleIp ? ` ou <strong>${Util.escape(tailscaleIp)}</strong>` : ''}.</li><li>Faça o pareamento diretamente entre Moonlight e Sunshine.</li></ol>
        <p class="text-xs">O navegador não inicia processos no servidor e não implementa streaming próprio.</p>
      </aside>
    </div>`;
    container.querySelector('#copyMoonlightHost')?.addEventListener('click', async event => {
      const copied = await copyText(event.currentTarget.dataset.copyValue);
      setFeedback(copied ? 'Host Moonlight copiado.' : 'Não foi possível copiar automaticamente.', copied ? 'success' : 'warning');
    });
  }

  function toggleLibraryView() {
    libraryView = libraryView === 'grid' ? 'list' : 'grid';
    const button = document.getElementById('arcadiaViewToggle');
    if (button) {
      button.innerHTML = libraryView === 'grid' ? `${Util.icon('list')}<span>Lista</span>` : `${Util.icon('grid')}<span>Grade</span>`;
      button.classList.toggle('active', libraryView === 'list');
      button.setAttribute('aria-pressed', String(libraryView === 'list'));
    }
    renderLibrary();
  }

  function renderRating(target, value) {
    const container = document.getElementById(target === 'edit' ? 'arcadiaEditRating' : 'arcadiaAddRating');
    if (!container) return;
    container.innerHTML = `<button class="arcadia-rating-clear" type="button" data-rating-target="${target}" data-rating="0" aria-label="Sem avaliação">×</button>${[1, 2, 3, 4, 5].map(rating => `<button type="button" data-rating-target="${target}" data-rating="${rating}" aria-label="${rating} estrela${rating > 1 ? 's' : ''}" aria-pressed="${rating <= value}">${rating <= value ? '★' : '☆'}</button>`).join('')}<span>${value ? `${value}/5` : 'Sem nota'}</span>`;
  }

  function setRating(target, value) {
    if (target === 'edit') editRating = clampRating(value);
    else addRating = clampRating(value);
    renderRating(target, target === 'edit' ? editRating : addRating);
  }

  function statusOptions(selected) {
    return STATUSES.filter(status => status.key !== 'all').map(status => `<option value="${status.key}"${status.key === selected ? ' selected' : ''}>${status.label}</option>`).join('');
  }

  function statusLabel(status) {
    return STATUSES.find(candidate => candidate.key === status)?.label || status || 'Backlog';
  }

  function coverMarkup(coverId, name, size = 't_cover_big') {
    return coverId
      ? `<img class="game-cover-image" src="${IGDB_COVER(coverId, size)}" alt="Capa de ${Util.escape(name)}" data-game-name="${Util.escape(name)}" loading="lazy">`
      : placeholderMarkup(name);
  }

  function wireCoverFallbacks(root) {
    root.querySelectorAll('.game-cover-image').forEach(image => {
      image.addEventListener('error', () => {
        const placeholder = document.createElement('span');
        placeholder.className = 'cover-placeholder';
        placeholder.innerHTML = placeholderContent(image.dataset.gameName || image.alt.replace(/^Capa de\s*/i, ''));
        image.replaceWith(placeholder);
      }, { once: true });
    });
  }

  function placeholderMarkup(name) {
    return `<span class="cover-placeholder">${placeholderContent(name)}</span>`;
  }

  function placeholderContent(name) {
    const words = String(name || 'Jogo').trim().split(/\s+/).filter(Boolean);
    const initials = words.slice(0, 2).map(word => word[0]).join('').toUpperCase().slice(0, 2) || 'NG';
    return `<span class="cover-placeholder-geometry" aria-hidden="true"></span><span class="cover-placeholder-icon">${Util.icon('arcadia')}</span><strong>${Util.escape(initials)}</strong><small>Capa indisponível</small>`;
  }

  function asStrings(value) {
    return Array.isArray(value) ? value.map(item => String(item)) : [];
  }

  function releaseYear(value) {
    if (!value) return '';
    const numeric = Number(value);
    const date = Number.isFinite(numeric)
      ? new Date(numeric < 100000000000 ? numeric * 1000 : numeric)
      : new Date(value);
    const year = date.getUTCFullYear();
    return Number.isFinite(year) && year > 1950 && year < 2200 ? String(year) : '';
  }

  function formatPublished(value) {
    if (!value) return '';
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? String(value).slice(0, 10) : date.toLocaleDateString('pt-BR');
  }

  function safeUrl(value) {
    try {
      const url = new URL(value);
      return ['http:', 'https:'].includes(url.protocol) ? Util.escape(url.href) : '#';
    } catch { return '#'; }
  }

  async function copyText(value) {
    try {
      if (navigator.clipboard?.writeText && window.isSecureContext) {
        await navigator.clipboard.writeText(value);
        return true;
      }
      const textarea = document.createElement('textarea');
      textarea.value = value;
      textarea.style.position = 'fixed';
      textarea.style.opacity = '0';
      document.body.append(textarea);
      textarea.select();
      const copied = document.execCommand('copy');
      textarea.remove();
      return copied;
    } catch { return false; }
  }

  function setSearchStatus(message, type = '') {
    const element = document.getElementById('arcadiaSearchStatus');
    if (!element) return;
    element.textContent = message;
    element.dataset.type = type;
  }

  function errorState(title, message, retryId) {
    return `<div class="glass state-box"><span class="icon">${Util.icon('warning')}</span><span class="title">${Util.escape(title)}</span><span class="desc">${Util.escape(message)}</span><button id="${retryId}" class="btn btn-glass btn-sm" type="button">${Util.icon('refresh')}<span>Tentar novamente</span></button></div>`;
  }

  function setDialogError(id, message) {
    const element = document.getElementById(id);
    if (!element) return;
    element.textContent = message;
    element.classList.remove('hidden');
  }

  function clearDialogError(id) {
    const element = document.getElementById(id);
    if (!element) return;
    element.textContent = '';
    element.classList.add('hidden');
  }

  function setFeedback(message, type = 'success') {
    const element = document.getElementById('arcadiaFeedback');
    if (!element) return;
    clearTimeout(feedbackTimer);
    element.textContent = message;
    element.dataset.type = type;
    element.classList.remove('hidden');
    feedbackTimer = setTimeout(() => element.classList.add('hidden'), 5000);
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

  function clampRating(value) {
    return Math.max(0, Math.min(5, Math.round(Number(value) || 0)));
  }

  function destroy() {
    active = false;
    clearTimeout(searchTimer);
    clearTimeout(feedbackTimer);
    searchSequence++;
    loadSequence++;
    library = [];
    news = [];
    searchResults = [];
    selectedLibraryGame = null;
    selectedSearchGame = null;
  }

  return { render, destroy };
})();
