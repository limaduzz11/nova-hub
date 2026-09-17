const API = (() => {
  const BASE = '/web-api/nexus';

  async function request(path, options = {}) {
    return requestUrl(`${BASE}${path}`, options);
  }

  async function requestUrl(url, options = {}) {
    const method = options.method || 'GET';
    const headers = { Accept: 'application/json', ...options.headers };
    if (options.body !== undefined) headers['Content-Type'] = 'application/json';
    if (!['GET', 'HEAD'].includes(method)) headers['X-CSRF-Token'] = Auth.csrf || '';

    const response = await fetch(url, {
      ...options,
      method,
      headers,
      credentials: 'same-origin',
    });
    if (response.status === 401) {
      window.dispatchEvent(new CustomEvent('nova:unauthorized'));
      throw new Error('Sessão expirada');
    }
    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error.error || error.message || `HTTP ${response.status}`);
    }
    if (response.status === 204) return null;
    return response.json();
  }

  return {
    listWorkspaces: () => request('/api/workspaces'),
    createWorkspace: name => request('/api/workspaces', {
      method: 'POST',
      body: JSON.stringify({ name, kind: 'custom', icon: 'folder', color: '#7C4DFF' }),
    }),
    listItems: workspaceId => request(`/api/workspaces/${encodeURIComponent(workspaceId)}/items`),
    createItem: item => request('/api/items', { method: 'POST', body: JSON.stringify(item) }),
    updateItem: (id, patch) => request(`/api/items/${encodeURIComponent(id)}`, {
      method: 'PATCH', body: JSON.stringify(patch),
    }),
    deleteItem: id => request(`/api/items/${encodeURIComponent(id)}`, { method: 'DELETE' }),
    getTelemetry: () => request('/api/v1/telemetry'),
    wol: () => request('/api/power/wol', { method: 'POST' }),
    powerOff: () => request('/api/power/off', { method: 'POST' }),
    searchGames: query => request(`/api/igdb/search?q=${encodeURIComponent(query)}`),
    getLibrary: () => request('/api/library'),
    addGame: game => request('/api/library', { method: 'POST', body: JSON.stringify(game) }),
    updateGame: (id, patch) => request(`/api/library/${encodeURIComponent(id)}`, {
      method: 'PATCH', body: JSON.stringify(patch),
    }),
    deleteGame: id => request(`/api/library/${encodeURIComponent(id)}`, { method: 'DELETE' }),
    getNews: () => request('/api/news'),
    enrichNewsImages: urls => request('/news/enrich', { method: 'POST', body: JSON.stringify({ urls }) }),
    getGraph: () => request('/api/graph'),
    getMoonlightStatus: () => requestUrl('/web-api/integrations/moonlight'),
    health: () => request('/health'),
    requestUrl,
  };
})();
