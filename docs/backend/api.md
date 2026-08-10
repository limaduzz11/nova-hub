# API Backend

**NOVA HUB** — Documentação da API do NOVA Nexus.

---

## Visão Geral

O NOVA Nexus é o backend principal do NOVA HUB, construído em Go com SQLite.

**Base URL:** `http://localhost:8080`

**Autenticação:** API Key via header `X-API-Key`

---

## Endpoints

### Workspace

#### Listar Workspaces

```
GET /api/workspaces
```

**Response:**
```json
{
  "workspaces": [
    {
      "id": "string",
      "name": "string",
      "description": "string",
      "createdAt": "2026-07-19T00:00:00Z",
      "updatedAt": "2026-07-19T00:00:00Z"
    }
  ]
}
```

#### Criar Workspace

```
POST /api/workspaces
```

**Request:**
```json
{
  "name": "string",
  "description": "string"
}
```

**Response:**
```json
{
  "id": "string",
  "name": "string",
  "description": "string",
  "createdAt": "2026-07-19T00:00:00Z"
}
```

### Items

#### Listar Items

```
GET /api/items?workspaceId=string
```

**Query Parameters:**
- `workspaceId` (optional) — Filtrar por workspace
- `tag` (optional) — Filtrar por tag
- `search` (optional) — Busca textual

**Response:**
```json
{
  "items": [
    {
      "id": "string",
      "workspaceId": "string",
      "title": "string",
      "content": "string",
      "tags": ["string"],
      "metadata": {},
      "createdAt": "2026-07-19T00:00:00Z",
      "updatedAt": "2026-07-19T00:00:00Z"
    }
  ]
}
```

#### Criar Item

```
POST /api/items
```

**Request:**
```json
{
  "workspaceId": "string",
  "title": "string",
  "content": "string",
  "tags": ["string"],
  "metadata": {}
}
```

**Response:**
```json
{
  "id": "string",
  "workspaceId": "string",
  "title": "string",
  "content": "string",
  "tags": ["string"],
  "metadata": {},
  "createdAt": "2026-07-19T00:00:00Z"
}
```

#### Atualizar Item

```
PUT /api/items/:id
```

**Request:**
```json
{
  "title": "string",
  "content": "string",
  "tags": ["string"],
  "metadata": {}
}
```

**Response:**
```json
{
  "id": "string",
  "title": "string",
  "content": "string",
  "tags": ["string"],
  "metadata": {},
  "updatedAt": "2026-07-19T00:00:00Z"
}
```

#### Deletar Item

```
DELETE /api/items/:id
```

**Response:**
```json
{
  "success": true
}
```

### Vault (Knowledge Graph)

#### Listar Entidades

```
GET /api/vault/entities
```

**Response:**
```json
{
  "entities": [
    {
      "name": "string",
      "type": "string",
      "observations": ["string"]
    }
  ]
}
```

#### Listar Relações

```
GET /api/vault/relations
```

**Response:**
```json
{
  "relations": [
    {
      "from": "string",
      "to": "string",
      "relationType": "string"
    }
  ]
}
```

### Telemetria (WebSocket)

#### Conectar

```
ws://localhost:8081/ws
```

**Mensagens recebidas:**
```json
{
  "cpu": {
    "usage": 45.2,
    "cores": 8,
    "temperature": 65
  },
  "ram": {
    "total": 16384,
    "used": 8192,
    "percentage": 50.0
  },
  "disk": {
    "total": 512000,
    "used": 256000,
    "percentage": 50.0
  },
  "gpu": {
    "name": "NVIDIA RTX 3080",
    "usage": 75.0,
    "temperature": 72
  },
  "network": {
    "up": 1000,
    "down": 5000
  },
  "volume": {
    "level": 75,
    "muted": false
  }
}
```

### Comandos

#### Listar Comandos

```
GET /api/commands
```

**Response:**
```json
{
  "commands": [
    {
      "id": "string",
      "name": "string",
      "command": "string",
      "icon": "string",
      "danger": false
    }
  ]
}
```

#### Executar Comando

```
POST /api/commands/:id/run
```

**Response:**
```json
{
  "success": true,
  "output": "string",
  "exitCode": 0
}
```

### SSH

#### Conectar

```
ws://localhost:8082/ssh
```

**Mensagens:**
```json
// Input
{
  "type": "input",
  "data": "ls -la\n"
}

// Output
{
  "type": "output",
  "data": "total 32\ndrwxr-xr-x 4 user user 4096 Jul 19 10:00 .\n"
}
```

### UpSnap (Wake-on-LAN)

#### Listar Dispositivos

```
GET /api/upsnap/devices
```

**Response:**
```json
{
  "devices": [
    {
      "id": "string",
      "name": "string",
      "ip": "string",
      "mac": "string",
      "status": "online|offline"
    }
  ]
}
```

#### Wake Device

```
POST /api/upsnap/devices/:id/wake
```

**Response:**
```json
{
  "success": true,
  "message": "Magic packet sent"
}
```

### Arcadia (IGDB Proxy)

#### Buscar Jogos

```
GET /api/arcadia/games/search?q=string
```

**Response:**
```json
{
  "games": [
    {
      "id": 123,
      "name": "string",
      "cover": "url",
      "rating": 85,
      "releaseDate": "2026-01-01",
      "platforms": ["PC", "PlayStation 5"]
    }
  ]
}
```

#### Listar Biblioteca

```
GET /api/arcadia/library
```

**Response:**
```json
{
  "games": [
    {
      "id": 123,
      "name": "string",
      "cover": "url",
      "rating": 85,
      "status": "playing|completed|backlog|dropped",
      "hoursPlayed": 42
    }
  ]
}
```

---

## Erros

### Formato de Erro

```json
{
  "error": {
    "code": "string",
    "message": "string",
    "details": {}
  }
}
```

### Códigos de Erro

| Código | HTTP Status | Descrição |
|--------|-------------|-----------|
| `INVALID_REQUEST` | 400 | Requisição inválida |
| `UNAUTHORIZED` | 401 | Não autenticado |
| `FORBIDDEN` | 403 | Sem permissão |
| `NOT_FOUND` | 404 | Recurso não encontrado |
| `CONFLICT` | 409 | Conflito de dados |
| `INTERNAL_ERROR` | 500 | Erro interno |

---

## Rate Limiting

**Limite:** 100 requisições por minuto por IP

**Headers:**
- `X-RateLimit-Limit`: Limite total
- `X-RateLimit-Remaining`: Restante
- `X-RateLimit-Reset`: Reset timestamp

---

## CORS

**Origens permitidas:**
- `*` (desenvolvimento)
- `http://localhost:3000` (produção)

**Headers permitidos:**
- `Content-Type`
- `Authorization`
- `X-API-Key`

---

## Exemplos de Uso

### Flutter (HTTP)

```dart
final response = await http.get(
  Uri.parse('http://localhost:8080/api/workspaces'),
  headers: {
    'X-API-Key': apiKey,
    'Content-Type': 'application/json',
  },
);

if (response.statusCode == 200) {
  final data = jsonDecode(response.body);
  final workspaces = data['workspaces'];
}
```

### Flutter (WebSocket)

```dart
final channel = WebSocketChannel.connect(
  Uri.parse('ws://localhost:8081/ws'),
);

channel.stream.listen((message) {
  final data = jsonDecode(message);
  // Atualizar UI com dados de telemetria
});
```

---

## Referências

- [Arquitetura](../architecture/overview.md)
- [Features](../features/implemented.md)
- [Desktop](../desktop/roadmap.md)

---

*Última atualização: 19 de Julho de 2026*
