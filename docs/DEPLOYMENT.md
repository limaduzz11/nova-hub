# Implantação

O serviço user-systemd instalado é `nova-hub-web.service`.

```bash
systemctl --user daemon-reload
systemctl --user enable --now nova-hub-web
systemctl --user restart nova-hub-web
systemctl --user status nova-hub-web
journalctl --user -u nova-hub-web -f
```

Health check: `curl http://100.64.0.1:3001/healthz`.

---
## Relações no Context Engine

- [[02-PROJECTS/PROJECT-RELATIONSHIP-MAP|PROJECT RELATIONSHIP MAP]]
- [[02-PROJECTS/NOVA HUB/NOVA HUB V4 WEB/PROJECT|PROJECT]]
- [[03-KNOWLEDGE/ANDROID/CONTEXT-INDEX|CONTEXT INDEX]]
- [[03-KNOWLEDGE/FLUTTER/CONTEXT-INDEX|CONTEXT INDEX]]
- [[02-PROJECTS/NOVA HUB/ARCADIA/PROJECT|PROJECT]]
- [[01-INDEX/CONTEXT-GRAPH|CONTEXT GRAPH]]
