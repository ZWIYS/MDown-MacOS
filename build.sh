#!/bin/bash
set -e
cd "$(dirname "$0")"
swift build -c release
APP=MDown.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MDown "$APP/Contents/MacOS/MDown"
cp Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Готово: $PWD/$APP"
