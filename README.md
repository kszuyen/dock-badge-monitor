# BadgeBell

BadgeBell is a tiny macOS menu bar app for apps that show unread Dock badges but do not reliably send macOS notifications.

The first supported app is CyberLink U.
When U has unread activity, BadgeBell keeps a reminder on screen until you dismiss it or open U.

## Why BadgeBell

Some desktop apps update their Dock badge but never appear in macOS notification settings. That makes them easy to miss if the only signal is a quick Dock bounce.

BadgeBell watches for that unread state and turns it into a persistent reminder.

## Current Status

BadgeBell is early software.

- Supported app: CyberLink U (`com.cyberlink.u`)
- Platform: macOS 13 or newer
- Distribution: build from source for now
- Local installation, login startup, and crash recovery are supported
- Public notarized releases are not available yet

## Install

Clone the repository and package the app:

```sh
git clone https://github.com/kszuyen/dock-badge-monitor.git
cd dock-badge-monitor
./scripts/install-app.sh
```

The installer builds and signs BadgeBell, installs it at `/Applications/BadgeBell.app`, enables login startup on first install, and starts it.
Updates preserve the existing login startup setting.
Run the installer again to update; the previous installed app is backed up under `~/Library/Application Support/BadgeBell/Backups/`.
Keep the installed path fixed so login startup and crash recovery can locate the app.
The source checkout is only needed to develop or rebuild it.
The installer stops the managed app during an update; quit any manually launched development copy first.

For a development build without installation, use `./scripts/package-app.sh` followed by `open dist/BadgeBell.app`.
Development copies do not use the installed app's crash recovery.

## Usage

BadgeBell uses a fixed-width bell symbol in the macOS menu bar.
A bell with a badge indicates unread activity, a crossed bell indicates paused reminders, and a warning triangle indicates missing permission or unavailable detection.
Hover over the symbol for a status summary.
Hiding a reminder does not clear the unread indicator.
Only the Dock's actual unread state can clear it.

Menu actions:

- `Open U` opens CyberLink U and hides the current reminder.
- `Hide This Reminder` hides the card while keeping unread activity visible in the menu bar.
- `Pause Alerts` offers 15 minutes, 30 minutes, 1 hour, or `Until I Resume`.
- `Resume Alerts` immediately checks U and redisplays a reminder if unread activity remains.
- `Help & Diagnostics > Preview Reminder` displays a clearly labeled sample without changing unread activity or pause settings.
- `Check Interval` contains 1, 2, 5, and 10 second choices and displays the current interval on its parent item.
- `Reminder Display` selects the screen with the pointer or the primary screen, and controls whether reminders appear over full-screen apps.
- `Launch at Login` controls startup at the next login.
- `Help & Diagnostics` contains permission settings, local logs, and version information.
- `Quit BadgeBell` exits normally and stays closed until reopened or the next enabled login startup.

The menu opens with a fixed-size summary containing the BadgeBell name, U's icon, current unread state, and monitoring or pause status.
The reminder uses U's installed application icon and shows no message content.
Unread counts lead the card, with detection time in the header and snooze and open actions in a separate footer.
The card uses flat system surfaces and an adaptive high-contrast primary action in light and dark appearances.
`Snooze 10 min` uses the same timed pause as the menu.
Timed pauses persist across restarts and expire after system sleep; monitoring continues while reminders are paused.
The reminder is a nonactivating panel, so appearing does not take keyboard focus from the current app.
Repeated unread updates reuse the same card rather than stacking new windows.
By default, a newly shown reminder uses the screen containing the pointer and remains visible over full-screen apps.
An already visible card stays on its screen when the pointer moves.

Failed Dock reads are shown as unavailable rather than as an empty inbox.
If U's Dock item is unavailable, keep U visible in the Dock and check Accessibility permission.
BadgeBell checks every 2 seconds by default and preserves your selected interval across updates.
Menus apply coalesced updates after root and submenu tracking finishes to avoid layout churn.

## Permissions

BadgeBell needs Accessibility permission to inspect Dock-visible app state. Without it, BadgeBell can run in the menu bar but cannot detect U's unread badge.

If unread detection does not work:

1. Open System Settings.
2. Go to Privacy & Security.
3. Open Accessibility.
4. Enable BadgeBell.
5. BadgeBell resumes monitoring within a few seconds after permission is granted.

If BadgeBell is already enabled but still says permission is needed, remove the stale entry and add `/Applications/BadgeBell.app` to Accessibility again.
Keep using the same local signing identity for updates.

BadgeBell does not need Screen Recording for the current detector.

## Startup and Recovery

The installed app uses a per-user LaunchAgent named `io.github.kszuyen.badgebell.monitor`.
Its persistent configuration lives at `~/Library/LaunchAgents/io.github.kszuyen.badgebell.monitor.plist` when login startup is enabled.
An unsuccessful exit triggers automatic recovery, with a 30-second throttle between starts.
A normal quit does not trigger recovery.
Opening BadgeBell through Finder or Spotlight starts the managed job again and does not create another monitoring instance.

Disabling `Launch at Login` removes the persistent configuration while the loaded job continues supervising the current session.
A manual launch with login startup disabled registers a temporary job for the current session only.
These settings do not require a system-wide daemon or administrator privileges.
macOS can separately block background items; check System Settings > General > Login Items & Extensions if startup fails.

Logs are stored at `~/Library/Logs/BadgeBell/monitor.log`.
They contain lifecycle, permission, and unread-state changes without message contents.
On manual startup, logs larger than 1 MiB rotate to `monitor.previous.log`.
Accessibility permission is checked again while running; monitoring stops if permission is revoked and resumes when it returns.

To remove the installed app, quit it, unload its job, remove its login configuration, then move `/Applications/BadgeBell.app` to Trash:

```sh
launchctl bootout "gui/$(id -u)/io.github.kszuyen.badgebell.monitor"
rm -f "$HOME/Library/LaunchAgents/io.github.kszuyen.badgebell.monitor.plist"
```

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
- More app providers
- Per-app reminder settings

## License

MIT. See `LICENSE`.

## UI Verification

Run `swift test` for reminder-state, pause persistence, native menu action, submenu tracking, and detector regressions.
Render the actual SwiftUI reminder in both appearances without capturing the desktop:

```sh
swiftc Sources/BadgeBell/UI/FloatingAlertView.swift Sources/BadgeBell/UI/MenuStatusHeaderView.swift scripts/render-ui-preview.swift -o .build/render-ui-preview
.build/render-ui-preview /path/to/preview-output
```
