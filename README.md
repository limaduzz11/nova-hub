# NOVA HUB

Multi-platform dashboard for remote device management — built with Flutter.

## Overview

NOVA HUB provides a unified interface for monitoring and controlling devices remotely. Features include live system telemetry, SSH terminal access, command execution, and integration with the NOVA ecosystem tools.

## Platforms

| Platform | Status |
|---|---|
| Android | Stable |
| Windows | In development |
| Linux | Planned |
| macOS | Planned |

## Key Features

- Real-time system telemetry and monitoring
- SSH terminal for remote device control
- Command deck for quick actions
- Alert center for system notifications
- Dark theme with glassmorphism design

## Tech Stack

`Flutter` `Dart` `SSH` `Material Design 3`

## Project Structure

```
lib/
├── config/          # App configuration
├── core/            # Theme, animations, logging
├── data/            # Services and models
├── presentation/    # UI screens and widgets
└── main.dart        # Entry point
```

## Quick Start

```bash
# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Build APK
flutter build apk
```

## License

MIT
