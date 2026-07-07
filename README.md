# MouseJiggler 🖱️🟢

A tiny, native macOS menu bar app that nudges your mouse on a schedule —
just enough to keep Teams, Slack, or your screen saver from marking you
away. Free, local, open source. No telemetry, no background server, no
subscription — same idea as movemouse.app, but yours.

## Features

- **Menu bar only** — no Dock icon, lives quietly as a status item
- **Custom schedule** — restrict jiggling to specific days and hours (e.g. weekdays 9–18)
- **App-aware** — optionally only jiggle while Teams and/or Slack are actually running
- **Configurable interval** — 20s to 5 minutes
- **Launch at login** — one toggle, no manual Login Items setup
- **Live status** — menu bar icon shows 🟢 when actively jiggling, ⚪️ when idle/paused

## Requirements

- macOS 13 (Ventura) or later
- Xcode Command Line Tools (not the full Xcode app):
  ```bash
  xcode-select --install
  ```

## Build

```bash
chmod +x build.sh scripts/make_icon.sh
./build.sh
```

This generates the app icon (first run only), compiles the Swift sources, and
produces `build/MouseJiggler.app`.

## Install & run

```bash
mv build/MouseJiggler.app /Applications/
open /Applications/MouseJiggler.app
```

**First launch:** macOS may not prompt automatically since it's an unsigned
(ad-hoc signed) build. If the jiggle doesn't seem to do anything, add it
manually:
**System Settings → Privacy & Security → Accessibility → add MouseJiggler.app**

## Using it

Click the menu bar icon for:
- **Start / Stop** — pause without quitting
- **Preferences…** — schedule, interval, app-awareness, launch at login
- **Quit**

## Project structure

```
MouseJiggler/
├── Sources/
│   ├── main.swift            # entry point
│   ├── AppDelegate.swift     # menu bar wiring
│   ├── JiggleEngine.swift    # timer, schedule & app-detection logic
│   ├── SettingsStore.swift   # persistence (UserDefaults + Codable)
│   ├── SettingsView.swift    # SwiftUI preferences window
│   ├── LoginItemManager.swift# SMAppService login item wrapper
│   └── Models.swift          # Schedule / AppSettings data types
├── Resources/
│   ├── Info.plist
│   └── AppIcon-1024.png      # source icon (converted to .icns at build time)
├── scripts/make_icon.sh      # PNG → .icns conversion
└── build.sh                  # compiles + packages the .app
```

## Roadmap ideas

- [ ] Sparkle-based auto-updates for direct (non-App-Store) distribution
- [ ] Notarized, signed release builds via GitHub Actions
- [ ] Mac App Store submission (requires Apple Developer account + proper signing identity)
- [ ] Per-app custom idle thresholds
- [ ] Optional real idle-detection (skip jiggling if you're already actively using the mouse/keyboard)

Contributions and issues welcome once this lands on GitHub.

## License

MIT — see [LICENSE](LICENSE).

## How it works

The engine reads the current cursor position, nudges it 1px, then moves it
back 50ms later — enough to reset the OS's idle timer without visibly
disturbing your cursor. A background check every 15 seconds evaluates
whether the current time/day falls in your schedule and whether your chosen
target apps (Teams/Slack) are running, and only jiggles when both conditions
are met.
