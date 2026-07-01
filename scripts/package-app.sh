#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/BadgeBell.app"
CONTENTS_DIR="$APP_DIR/Contents"
LOCAL_CODESIGN_IDENTITY="${BADGEBELL_LOCAL_CODESIGN_IDENTITY:-BadgeBell Local Code Signing}"
CODESIGN_IDENTITY="${BADGEBELL_CODESIGN_IDENTITY:-}"

cd "$ROOT_DIR"

if [[ -z "$CODESIGN_IDENTITY" ]]; then
  if security find-identity -v -p codesigning | grep -Fq "\"$LOCAL_CODESIGN_IDENTITY\""; then
    CODESIGN_IDENTITY="$LOCAL_CODESIGN_IDENTITY"
  else
    CODESIGN_IDENTITY="-"
  fi
fi

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"

cp "$ROOT_DIR/.build/release/BadgeBell" "$CONTENTS_DIR/MacOS/BadgeBell"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>BadgeBell</string>
	<key>CFBundleIdentifier</key>
	<string>io.github.kszuyen.badgebell</string>
	<key>CFBundleName</key>
	<string>BadgeBell</string>
	<key>CFBundleDisplayName</key>
	<string>BadgeBell</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
</dict>
</plist>
PLIST

codesign_args=(--force --deep --sign "$CODESIGN_IDENTITY")
if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
  codesign_args+=(--options runtime)
  if [[ "$CODESIGN_IDENTITY" != "$LOCAL_CODESIGN_IDENTITY" ]]; then
    codesign_args+=(--timestamp)
  fi
fi

codesign "${codesign_args[@]}" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "Packaged $APP_DIR"
if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
  echo "Signed ad-hoc. Set BADGEBELL_CODESIGN_IDENTITY to use a Developer ID Application certificate."
else
  echo "Signed with $CODESIGN_IDENTITY"
fi
