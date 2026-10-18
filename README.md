# PlugWatch

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black.svg)](#requirements)
[![CI](https://img.shields.io/badge/CI-xcodebuild-lightgrey.svg)](.github/workflows/ci.yml)

Lightweight native **macOS menu bar agent** that tracks AC vs battery usage, nudges you after continuous awake unplugged time, and keeps a persistent history you can export.

> Screenshots welcome via PR — PlugWatch lives in the menu bar (bolt / battery SF Symbols); there is no Dock icon (`LSUIElement`).

## Features

- **Event-driven power monitoring** via IOKit (`IOPSNotificationCreateRunLoopSource`) — no polling, low energy impact
- **Habit alerts** after a configurable awake-on-battery threshold (default 15 minutes in Release)
- **Dismiss** / **Snooze** actions (notifications + optional floating panel)
- **Awake-time history** for AC and battery sessions (sleep does not count)
- **Export CSV** and clear history
- **Launch at login** via `SMAppService`

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+ (Swift 5.9+)

## Build & run

```bash
# Open in Xcode
open PlugWatch.xcodeproj

# Or build from the CLI
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project PlugWatch.xcodeproj -scheme PlugWatch \
  -configuration Release -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO
open build/Build/Products/Release/PlugWatch.app
```

### Install to Applications (local)

```bash
cp -R build/Build/Products/Release/PlugWatch.app /Applications/
codesign --force --deep --sign - /Applications/PlugWatch.app
open /Applications/PlugWatch.app
```

Ad-hoc signing works for local use. For distribution to others, use an Apple Developer ID certificate and notarization (not covered in this repo yet).

## Privacy

- **No network access** — PlugWatch does not phone home
- Local history is stored only at:

  `~/Library/Application Support/com.plugwatch.app/power_history.json`

## Usage

1. Click the menu bar icon for power state, snooze/pause, **History…**, and **Settings…**
2. Allow notifications when prompted
3. Open **History…** for today / 7-day / all-time summaries and CSV export

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Please follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

[MIT](LICENSE) © 2026 PlugWatch contributors
