#!/bin/bash
set -e

DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null || echo "/Applications/Xcode.app/Contents/Developer")}"
export DEVELOPER_DIR

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo "=== Clean Build ==="
rm -rf ./build

echo "=== Building Clarc (Release) ==="
xcodebuild -project Clarc.xcodeproj \
  -scheme Clarc \
  -configuration Release \
  -derivedDataPath ./build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | tee /tmp/clarc-build.log | grep -E "error:|warning:|BUILD|Compiling|Linking" | tail -40

BUILD_EXIT=${PIPESTATUS[0]}
if [ $BUILD_EXIT -ne 0 ]; then
  echo "❌ Build failed (exit $BUILD_EXIT). Full log: /tmp/clarc-build.log"
  exit 1
fi

APP_PATH="./build/Build/Products/Release/Clarc.app"
if [ ! -d "$APP_PATH" ]; then
  echo "❌ Build failed — no .app found"
  exit 1
fi

if [ ! -f "$APP_PATH/Contents/MacOS/Clarc" ]; then
  echo "❌ Build incomplete — executable missing. Check: /tmp/clarc-build.log"
  grep -i "error:" /tmp/clarc-build.log | tail -10
  exit 1
fi

echo ""
echo "✅ Build succeeded: $APP_PATH"

if [ "$1" = "--deploy" ] || [ "$1" = "-d" ]; then
  echo ""
  echo "=== Deploying to /Applications ==="
  pkill -x Clarc 2>/dev/null || true
  sleep 1
  rm -rf /Applications/Clarc.app
  ditto "$APP_PATH" /Applications/Clarc.app

  SRC_MD5=$(cd "$APP_PATH" && find . -type f | sort | xargs md5 -q | md5 -q)
  DST_MD5=$(cd /Applications/Clarc.app && find . -type f | sort | xargs md5 -q | md5 -q)
  if [ "$SRC_MD5" = "$DST_MD5" ]; then
    echo "✅ Verified: checksums match"
  else
    echo "❌ Checksum mismatch — deploy failed!"
    exit 1
  fi

  echo ""
  echo "=== Launching Clarc ==="
  open /Applications/Clarc.app
fi

echo "✅ Done"
