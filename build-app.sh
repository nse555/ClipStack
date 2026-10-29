#!/bin/bash
# Builds ClipStack and assembles a runnable .app bundle at build/ClipStack.app
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/ClipStack.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ClipStack "$APP/Contents/MacOS/ClipStack"
cp Info.plist "$APP/Contents/Info.plist"

# Ad-hoc sign so TCC permissions (Accessibility, pasteboard) stick across rebuilds.
codesign --force --sign - "$APP"

echo "Built $APP"
