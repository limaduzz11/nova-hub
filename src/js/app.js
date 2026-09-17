document.addEventListener('DOMContentLoaded', async () => {
  const authenticated = await Auth.init();
  if (authenticated) showApp();
  else showLogin();

  document.getElementById('loginForm').addEventListener('submit', async event => {
    event.preventDefault();
    const username = document.getElementById('username').value.trim();
    const password = document.getElementById('password').value;
    const errorEl = document.getElementById('loginError');
    const button = document.getElementById('loginBtn');
    const spinner = button.querySelector('.btn-spinner');

    errorEl.classList.add('hidden');
    spinner.classList.remove('hidden');
    button.disabled = true;
    try {
      await Auth.login(username, password);
      document.getElementById('password').value = '';
      showApp();
    } catch (error) {
      errorEl.textContent = error.message;
      errorEl.classList.remove('hidden');
    } finally {
      spinner.classList.add('hidden');
      button.disabled = false;
    }
  });

  document.getElementById('logoutBtn').addEventListener('click', async () => {
    await Auth.logout();
    showLogin();
  });

  window.addEventListener('nova:unauthorized', () => showLogin('Sua sessão expirou. Entre novamente.'));
});

function showLogin(message = '') {
  Router.destroyCurrent?.();
  document.getElementById('mainApp').classList.add('hidden');
  document.getElementById('loginScreen').classList.remove('hidden');
  if (message) {
    const errorEl = document.getElementById('loginError');
    errorEl.textContent = message;
    errorEl.classList.remove('hidden');
  }
}

function showApp() {
  document.getElementById('loginScreen').classList.add('hidden');
  document.getElementById('mainApp').classList.remove('hidden');

  Router.register('link', LinkModule);
  Router.register('nexus', NexusModule);
  Router.register('arcadia', ArcadiaModule);
  Router.register('cortex', CortexModule);
  Router.register('settings', SettingsModule);

  document.querySelectorAll('.nav-item[data-module]').forEach(item => {
    if (item.dataset.bound === 'true') return;
    item.dataset.bound = 'true';
    item.addEventListener('click', event => {
      event.preventDefault();
      Router.navigate(item.dataset.module);
    });
  });

  Router.navigate('link');
}
