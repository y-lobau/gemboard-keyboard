#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="${BUNDLE_ID:-com.holas.plynkeyboard.mac}"

tccutil reset Accessibility "${BUNDLE_ID}" >/dev/null 2>&1 || true
tccutil reset PostEvent "${BUNDLE_ID}" >/dev/null 2>&1 || true
tccutil reset ListenEvent "${BUNDLE_ID}" >/dev/null 2>&1 || true

echo "Reset macOS privacy permissions for ${BUNDLE_ID}."
