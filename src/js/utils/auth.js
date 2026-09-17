const Auth = {
  csrf: null,
  username: null,

  async init() {
    try {
      const response = await fetch('/web-api/auth/session', {
        credentials: 'same-origin',
        headers: { Accept: 'application/json' },
      });
      if (!response.ok) return false;
      const data = await response.json();
      this.csrf = data.csrf;
      this.username = data.username;
      return data.authenticated === true;
    } catch {
      return false;
    }
  },

  async login(username, password) {
    const response = await fetch('/web-api/auth/login', {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ username, password }),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(data.error || 'Falha no login');
    this.csrf = data.csrf;
    this.username = data.username;
    return true;
  },

  async logout() {
    try {
      await fetch('/web-api/auth/logout', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'X-CSRF-Token': this.csrf || '' },
      });
    } finally {
      this.csrf = null;
      this.username = null;
    }
  },
};
