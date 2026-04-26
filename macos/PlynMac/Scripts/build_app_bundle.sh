#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_DIR="${PACKAGE_DIR}/.build/Plyń.app"
INSTALL_APP_DIR="${INSTALL_APP_DIR:-/Applications/Plyń Dev.app}"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
ENTITLEMENTS="${PACKAGE_DIR}/Resources/PlynMac.entitlements"
GOOGLE_SERVICE_INFO="${PACKAGE_DIR}/../../ios/PlynKeyboard/GoogleService-Info.plist"
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  SIGN_IDENTITY="$({ security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -n 1; } || true)"
fi
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

swift build --package-path "${PACKAGE_DIR}" -c "${CONFIGURATION}"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"
cp "${PACKAGE_DIR}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
if [[ -f "${GOOGLE_SERVICE_INFO}" ]]; then
  cp "${GOOGLE_SERVICE_INFO}" "${RESOURCES_DIR}/GoogleService-Info.plist"
fi
cp "${PACKAGE_DIR}/.build/${CONFIGURATION}/PlynMac" "${MACOS_DIR}/PlynMac"
chmod +x "${MACOS_DIR}/PlynMac"

codesign --force --deep --sign "${SIGN_IDENTITY}" --entitlements "${ENTITLEMENTS}" "${APP_DIR}"
rm -rf "${INSTALL_APP_DIR}"
ditto "${APP_DIR}" "${INSTALL_APP_DIR}"

echo "Built ${APP_DIR}"
echo "Signed ${APP_DIR} with identity '${SIGN_IDENTITY}'."
echo "Installed ${INSTALL_APP_DIR}."
