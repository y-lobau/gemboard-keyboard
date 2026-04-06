#!/bin/sh

set -eu

ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
METRO_PORT=${METRO_PORT:-8082}
SIMULATOR_NAME=${SIMULATOR_NAME:-iPhone 16e}
STARTED_METRO=0
METRO_PID=""

cleanup() {
  if [ "$STARTED_METRO" -eq 1 ] && [ -n "$METRO_PID" ]; then
    kill "$METRO_PID" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT INT TERM

if ! curl -fsS "http://127.0.0.1:${METRO_PORT}/status" >/dev/null 2>&1; then
  cd "$ROOT_DIR"
  npm start -- --port "$METRO_PORT" >/tmp/Plyń-metro-e2e.log 2>&1 &
  METRO_PID=$!
  STARTED_METRO=1

  ATTEMPTS=0
  until curl -fsS "http://127.0.0.1:${METRO_PORT}/status" >/dev/null 2>&1; do
    ATTEMPTS=$((ATTEMPTS + 1))
    if [ "$ATTEMPTS" -ge 30 ]; then
      echo "Metro did not become ready on port ${METRO_PORT}." >&2
      exit 1
    fi
    sleep 1
  done
fi

cd "$ROOT_DIR"
xcodebuild test \
  -workspace ios/PlyńKeyboard.xcworkspace \
  -scheme PlyńKeyboard \
  -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}" \
  -only-testing:PlyńKeyboardE2ETests
