#!/bin/bash
set -e

DEVELOPER_DIR="/Users/srivpra/MyProjects/Xcode/Xcode.app/Contents/Developer"
export DEVELOPER_DIR

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo "=== Building Clarc (Release) ==="
xcodebuild -project Clarc.xcodeproj \
  -scheme Clarc \
  -configuration Release \
  -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | grep -E "error:|warning:|BUILD|Compiling|Linking" | tail -40

APP_PATH="./build/Build/Products/Release/Clarc.app"
if [ ! -d "$APP_PATH" ]; then
  echo "❌ Build failed — no .app found"
  exit 1
fi

echo ""
echo "=== Deploying to /Applications ==="
pkill -x Clarc 2>/dev/null || true
sleep 1
cp -R "$APP_PATH" /Applications/Clarc.app

SRC_MD5=$(find "$APP_PATH" -type f -exec md5 -q {} + | sort | md5 -q)
DST_MD5=$(find /Applications/Clarc.app -type f -exec md5 -q {} + | sort | md5 -q)
if [ "$SRC_MD5" = "$DST_MD5" ]; then
  echo "✅ Verified: checksums match"
else
  echo "⚠️  Checksum mismatch!"
fi

echo ""
echo "=== Launching Clarc ==="
open /Applications/Clarc.app
echo "✅ Done"
