#!/bin/sh

set -eu

if [ "${ACTION:-}" != "install" ]; then
  echo "note: Skipping React Native framework dSYM preparation for ACTION=${ACTION:-build}"
  exit 0
fi

FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
ARCHIVE_DSYMS_DIR="${DWARF_DSYM_FOLDER_PATH}"

if [ ! -d "$FRAMEWORKS_DIR" ]; then
  echo "note: No embedded frameworks directory at $FRAMEWORKS_DIR"
  exit 0
fi

mkdir -p "$ARCHIVE_DSYMS_DIR"

generate_framework_dsym() {
  framework_name="$1"
  framework_binary="$FRAMEWORKS_DIR/${framework_name}.framework/${framework_name}"
  framework_dsym="$ARCHIVE_DSYMS_DIR/${framework_name}.framework.dSYM"

  if [ ! -f "$framework_binary" ]; then
    echo "note: Skipping ${framework_name}.framework because $framework_binary is missing"
    return
  fi

  echo "note: Generating ${framework_name}.framework.dSYM"
  dsymutil "$framework_binary" -o "$framework_dsym"
}

strip_embedded_framework_dsyms() {
  framework_name="$1"
  embedded_dsyms_dir="$FRAMEWORKS_DIR/${framework_name}.framework/dSYMs"

  if [ -d "$embedded_dsyms_dir" ]; then
    echo "note: Removing embedded dSYMs from ${framework_name}.framework"
    rm -rf "$embedded_dsyms_dir"
  fi
}

for framework_name in React ReactNativeDependencies hermesvm; do
  generate_framework_dsym "$framework_name"
  strip_embedded_framework_dsyms "$framework_name"
done
