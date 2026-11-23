#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if ! xcode-select -p >/dev/null 2>&1; then
  echo "error: Xcode is not selected. Install Xcode, then run: sudo xcode-select -s /Applications/Xcode.app" >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild was not found. Install Xcode and the command-line tools." >&2
  exit 1
fi

xcodebuild \
  -project "$ROOT/RAMControl.xcodeproj" \
  -scheme RAMControl \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$ROOT/build/DerivedData" \
  build \
  CODE_SIGNING_ALLOWED=NO \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  ENABLE_APP_SANDBOX=NO

APP_PATH="$(find "$ROOT/build/DerivedData/Build/Products/Release" -type d -name 'RAM Control.app' -print -quit)"
if [[ -z "${APP_PATH}" || ! -d "${APP_PATH}" ]]; then
  echo "error: RAM Control.app was not produced" >&2
  exit 1
fi

codesign --force --sign - "$APP_PATH"

ABSOLUTE="$(cd "$(dirname "$APP_PATH")" && pwd)/$(basename "$APP_PATH")"
echo "$ABSOLUTE"
