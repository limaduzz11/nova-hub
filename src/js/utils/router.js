const Router = {
  current: null,
  modules: {},

  register(name, module) { this.modules[name] = module; },

  destroyCurrent() {
    if (this.current && this.modules[this.current]?.destroy) this.modules[this.current].destroy();
    this.current = null;
  },

  navigate(name) {
    if (!this.modules[name]) return;
    this.destroyCurrent();
    this.current = name;
    document.querySelectorAll('.nav-item[data-module]').forEach(element => {
      element.classList.toggle('active', element.dataset.module === name);
    });
    const mainContent = document.getElementById('mainContent');
    if (mainContent) mainContent.scrollTop = 0;
    const container = document.getElementById('moduleContainer');
    const view = this.modules[name].render();
    view.classList.add('module-view');
    document.body.dataset.activeModule = name;
    container.replaceChildren(view);
    const reveal = () => {
      if (view.isConnected && container.firstElementChild === view) view.classList.add('is-visible');
    };
    requestAnimationFrame(reveal);
    setTimeout(reveal, 80);
  },
};
