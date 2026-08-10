# Mobile Development

**NOVA HUB** — Desenvolvimento mobile (Android/iOS).

---

## Visão Geral

O NOVA HUB mobile é a plataforma principal, com Android como foco atual.

---

## Status

| Plataforma | Status | Versão |
|------------|--------|--------|
| Android | ✅ **Estável** | 2.0.0+7 |
| iOS | 📋 Planejado | - |

---

## Configuração Android

### build.gradle

```gradle
android {
    compileSdkVersion 36
    
    defaultConfig {
        applicationId "com.nova.nova_hub"
        minSdkVersion 24
        targetSdkVersion 36
        versionCode 7
        versionName "2.0.0"
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }
}
```

### Permissões

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.VIBRATE" />
```

---

## Estrutura de Pastas

```
android/
├── app/
│   ├── build.gradle
│   └── src/
│       ├── main/
│       │   ├── AndroidManifest.xml
│       │   ├── java/
│       │   └── res/
│       └── debug/
│           └── AndroidManifest.xml
├── build.gradle
├── gradle.properties
└── settings.gradle
```

---

## Assets

### Ícones

| Asset | Tamanho | Uso |
|-------|---------|-----|
| `app_icon.png` | 512x512 | Ícone principal |
| `app_icon_foreground.png` | 512x512 | Foreground adaptive icon |
| `splash.png` | 1284x2778 | Splash screen |

### Configuração

```yaml
# pubspec.yaml
flutter_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
  adaptive_icon_background: "#020617"
```

---

## Features Android

### Implementadas

| Feature | Status | Descrição |
|---------|--------|-----------|
| Nova Link | ✅ | Dashboard principal |
| Telemetria | ✅ | Monitoramento ao vivo |
| Arcadia | ✅ | Video Games Tracker |
| Cortex | ✅ | Knowledge Graph |
| Nexus | ✅ | PKM Hub |
| SSH | ✅ | Terminal SSH |
| OpenCode | ✅ | Editor integrado |
| Command Deck | ✅ | Ações rápidas |
| Alertas | ✅ | Centro de alertas |

### Pendentes

| Feature | Status | Descrição |
|---------|--------|-----------|
| Notificações Push | 📋 | Notificações remotas |
| Widgets | 📋 | Widgets da home screen |
| Shortcuts | 📋 | Atalhos da home screen |
| Background Service | 📋 | Serviço em background |
| Share Intent | 📋 | Compartilhar conteúdo |

---

## Build

### Debug

```bash
flutter run
```

### Release

```bash
flutter build apk --release
```

### Output

```
build/app/outputs/flutter-apk/app-release.apk
```

---

## Testes

### Unitários

```bash
flutter test
```

### Widget

```bash
flutter test --platform=android
```

### Integração

```bash
flutter drive --target=test_driver/app.dart
```

---

## Performance

### Métricas

| Métrica | Valor | Meta |
|---------|-------|------|
| Tamanho do APK | ~20MB | < 25MB |
| Tempo de inicialização | ~2s | < 3s |
| FPS | 60fps | 60fps |
| Memória | ~100MB | < 150MB |

### Otimizações

- **Lazy Loading:** Carregamento sob demanda
- **Cached Network Image:** Cache de imagens
- **Skeleton Screens:** Feedback visual
- **IndexedStack:** Manter estado das tabs

---

## Publicação

### Google Play Store

1. Gerar keystore
2. Configurar `key.properties`
3. Build release
4. Upload para Play Console
5. Preencher listing
6. Submeter para revisão

### Requisitos

- [ ] Ícone 512x512
- [ ] Feature graphic 1024x500
- [ ] Screenshots (mínimo 2)
- [ ] Descrição curta (80 caracteres)
- [ ] Descrição completa (4000 caracteres)
- [ ] Política de privacidade

---

## Referências

- [Flutter Android Setup](https://docs.flutter.dev/deployment/android)
- [Google Play Console](https://play.google.com/console)
- [Android Developer](https://developer.android.com)

---

*Última atualização: 19 de Julho de 2026*
