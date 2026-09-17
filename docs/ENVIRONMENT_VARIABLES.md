# Variáveis de Ambiente

| Variável | Padrão | Uso |
|---|---|---|
| `NOVA_WEB_HOST` | `100.64.0.1` | bind Tailscale |
| `NOVA_WEB_PORT` | `3000` | porta web |
| `KEYCLOAK_TOKEN_URL` | endpoint atual do realm | login/refresh |
| `KEYCLOAK_CLIENT_ID` | `nova-hub-v3` | cliente público Keycloak |
| `NEXUS_BASE_URL` | `http://127.0.0.1:8080` | backend oficial |
| `SUNSHINE_PROBE_HOST` | `127.0.0.1` | host local usado apenas para verificar portas Sunshine |
| `MOONLIGHT_DISPLAY_HOST` | `pop-os` | nome copiado pelo usuário para o cliente Moonlight |
| `NEXUS_API_KEY_FILE` | arquivo local oficial | segredo somente servidor |
| `NOVA_BRAND_LOGO` | referência visual oficial | logo servida pelo backend |
| `NOVA_SSH_HOST` | `127.0.0.1` | host alvo do terminal SSH web |
| `NOVA_SSH_PORT` | `22` | porta SSH do terminal web |
| `NOVA_SSH_USER` | usuário do SO | usuário usado pelo terminal web |
| `NOVA_SSH_KNOWN_HOSTS` | `~/.ssh/known_hosts` | known_hosts do cliente SSH |
| `NOVA_SSH_IDENTITY_FILE` | *(vazio)* | chave privada exclusiva do terminal web |

Consulte `.env.example`; valores secretos não devem ser versionados.

---
## Relações no Context Engine

- [[02-PROJECTS/PROJECT-RELATIONSHIP-MAP|PROJECT RELATIONSHIP MAP]]
- [[02-PROJECTS/NOVA HUB/NOVA HUB V4 WEB/PROJECT|PROJECT]]
- [[03-KNOWLEDGE/ANDROID/CONTEXT-INDEX|CONTEXT INDEX]]
- [[03-KNOWLEDGE/FLUTTER/CONTEXT-INDEX|CONTEXT INDEX]]
- [[02-PROJECTS/NOVA HUB/ARCADIA/PROJECT|PROJECT]]
- [[01-INDEX/CONTEXT-GRAPH|CONTEXT GRAPH]]
