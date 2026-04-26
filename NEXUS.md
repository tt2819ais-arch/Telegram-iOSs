# Nexus

**Nexus** is an unofficial iOS client built on top of the open-source [Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS) codebase.

> Nexus is **not** affiliated with, endorsed by, or sponsored by Telegram Messenger Inc. Use at your own risk.

## Why Nexus

Nexus extends the official Telegram client with a small, focused set of additions while keeping full feature parity with upstream Telegram:

1. **Connect without VPN** — automatic discovery, ping-testing and selection of MTProto proxies. The fastest proxy is selected on launch and re-tested in the background; if it goes down, Nexus transparently falls back to the next best one.
2. **Saved deleted / edited messages** — the original text of every message is kept locally so you can review what was changed or removed (visible only on the Nexus client).
3. **Nexus verification badge** — a client-side cosmetic verification badge that mirrors the official Telegram one, visible only to other Nexus users.
4. **Admin panel** — a hidden panel for managing the list of users with the Nexus badge.

## Status

| Stage | Description | Status |
| ----- | ----------- | ------ |
| 1 | Rebrand (name, bundle, "About Nexus", Localizable strings) and module scaffolding | implemented |
| 2 | MTProto auto-proxy: list fetch + ping + auto-select + fallback | scaffolded |
| 3 | Saved deleted / edited messages (interception + local store + UI) | scaffolded |
| 4 | Fake verification badge rendering in chat / profile / contact list | scaffolded |
| 5 | Hidden admin panel for managing the Nexus verification list | scaffolded |

The scaffolded modules live under [`submodules/Nexus/`](submodules/Nexus/) and currently expose stable type-only APIs that the rest of the app can depend on without behaviour changes. Each module is wired into the Bazel build but is otherwise inert until its respective stage lands.

## Building

The build pipeline is identical to upstream Telegram-iOS — see [`README.md`](README.md). Briefly, on macOS with the Xcode version listed in `versions.json`:

```
python3 build-system/Make/Make.py \
    --cacheDir="$HOME/telegram-bazel-cache" \
    generateProject \
    --configurationPath=build-system/template_minimal_development_configuration.json \
    --xcodeManagedCodesigning
```

The displayed app name is controlled by the `AppNameInfoPlist` Bazel fragment in `Telegram/BUILD` and by `APP_NAME` in `Telegram/Telegram-iOS/Config-*.xcconfig`. Both are now set to `Nexus`.

## Distribution

Nexus cannot be published on the App Store because some of its features (notably client-side fake verification and persisted deleted messages) violate Telegram's published Terms of Service. It is intended for sideload only — TestFlight via your own developer account, AltStore, or Sideloadly.

## Disclaimer

The Nexus verification badge is a purely cosmetic client-side label. It is **not** issued by Telegram and confers no real verification. It is visible only inside the Nexus app to other Nexus users and is not synchronised with Telegram's servers.

Nexus stores the original text of deleted and edited messages **locally on the device**. Nothing is uploaded to any server. The behaviour is opt-in and disabled by default.
