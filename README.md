# BadgeBell

BadgeBell is a tiny macOS menu bar app for apps that show unread Dock badges but do not reliably send macOS notifications.

The first supported app is CyberLink U. When U has unread activity, BadgeBell keeps a reminder on screen until you dismiss it or open U.

## Why BadgeBell

Some desktop apps update their Dock badge but never appear in macOS notification settings. That makes them easy to miss if the only signal is a quick Dock bounce.

BadgeBell watches for that unread state and turns it into a persistent reminder.

## Current Status

BadgeBell is early software.

- Supported app: CyberLink U (`com.cyberlink.u`)
- Platform: macOS 13 or newer
- Distribution: build from source for now
- Installers and signed releases are not available yet

## Install

Clone the repository and package the app:

```sh
git clone https://github.com/kszuyen/dock-badge-monitor.git
cd dock-badge-monitor
./scripts/package-app.sh
open dist/BadgeBell.app
```

You can move `dist/BadgeBell.app` to `/Applications` if you want to keep it installed.

## Usage

After launch, BadgeBell appears in the menu bar as `Bell`.

Menu actions:

- `Open U` opens CyberLink U.
- `Dismiss Alert` hides the current reminder.
- `Pause Alerts` stops floating reminders while BadgeBell keeps checking U.
- `Resume Alerts` turns floating reminders back on.
- `Check every 1s`, `Check every 2s`, `Check every 5s`, and `Check every 10s` set how often BadgeBell checks the Dock badge.
- `Quit BadgeBell` exits the app.

When BadgeBell detects unread activity from U, it shows a persistent top-right reminder. The reminder does not include message contents.

BadgeBell checks every 2 seconds by default. Faster checks react sooner but inspect Dock state more often.

Quiet Mode is controlled by `Pause Alerts`. While paused, BadgeBell still updates the menu bar status, but it does not show the floating reminder.

## Permissions

BadgeBell needs Accessibility permission to inspect Dock-visible app state. Without it, BadgeBell can run in the menu bar but cannot detect U's unread badge.

If unread detection does not work:

1. Open System Settings.
2. Go to Privacy & Security.
3. Open Accessibility.
4. Enable BadgeBell.
5. Quit and reopen BadgeBell.

If BadgeBell is already enabled but still says permission is needed, remove BadgeBell from the Accessibility list, package the app again, reopen it, and add the rebuilt app bundle back to Accessibility.

BadgeBell does not need Screen Recording for the current detector.

## Privacy

BadgeBell is designed to avoid private message content.

It does not read:

- message text
- sender names
- channel names
- screenshots
- OCR output

The first version only tries to detect whether unread activity exists.

## Limitations

- CyberLink U is the only supported app right now.
- Dock badge detection depends on what macOS exposes through automation/accessibility APIs.
- If macOS or the target app does not expose badge state, BadgeBell may show app status but fail to detect unread count.
- Local builds are signed ad-hoc by default unless you provide a signing identity.
- BadgeBell release artifacts are not notarized yet.

## Build From Source

Requirements:

- macOS 13 or newer
- Xcode or Xcode Command Line Tools

Commands:

```sh
swift test
swift build
./scripts/package-app.sh
open dist/BadgeBell.app
```

By default, `package-app.sh` uses ad-hoc signing. For a Developer ID signed build, install a `Developer ID Application` certificate in Keychain and pass its signing identity:

```sh
security find-identity -v -p codesigning
BADGEBELL_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/package-app.sh
```

Developer ID signing enables hardened runtime and timestamping. Notarization is still a separate release step.

For development builds without an Apple Developer Program account, create a stable local signing certificate once:

```sh
./scripts/create-local-signing-certificate.sh
./scripts/package-app.sh
```

After the local identity exists, `package-app.sh` uses `BadgeBell Local Code Signing` automatically. This is not a replacement for Developer ID distribution, but it makes local rebuilds less likely to reset Accessibility permission than ad-hoc signing.

## Roadmap

- Developer ID signed and notarized releases
- DMG distribution
- Launch at login
- More app providers
- Per-app reminder settings

## License

MIT. See `LICENSE`.
