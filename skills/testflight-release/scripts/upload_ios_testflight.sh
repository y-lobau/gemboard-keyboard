#!/bin/sh

set -eu

usage() {
  cat <<'EOF'
Usage: upload_ios_testflight.sh [options]

Builds the PlynKeyboard iOS archive and uploads it to TestFlight.

Options:
  --build-number <number>       Build number to set before archiving.
  --archive-path <path>         Archive output path.
  --export-path <path>          Export/upload working directory.
  --skip-build-number-update    Do not modify CURRENT_PROJECT_VERSION.
  --dry-run                     Print commands without executing them.
  --help                        Show this help.

If --build-number is omitted, the script uses a UTC timestamp.
EOF
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
skill_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
repo_dir=$(CDPATH= cd -- "$skill_dir/../.." && pwd)

build_number=""
archive_path=""
export_path=""
skip_build_number_update=0
dry_run=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --build-number)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --build-number" >&2
        exit 1
      fi
      build_number="$2"
      shift 2
      ;;
    --archive-path)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --archive-path" >&2
        exit 1
      fi
      archive_path="$2"
      shift 2
      ;;
    --export-path)
      if [ "$#" -lt 2 ]; then
        echo "Missing value for --export-path" >&2
        exit 1
      fi
      export_path="$2"
      shift 2
      ;;
    --skip-build-number-update)
      skip_build_number_update=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$build_number" ]; then
  build_number=$(date -u +%Y%m%d%H%M%S)
fi

case "$build_number" in
  ''|*[!0-9]*)
    echo "Build number must be a positive integer: $build_number" >&2
    exit 1
    ;;
esac

workspace_path="$repo_dir/ios/PlynKeyboard.xcworkspace"
scheme_name="PlynKeyboard"
team_id="ZCY45NFH6D"
archive_path=${archive_path:-/tmp/PlynKeyboard-TestFlight-$build_number.xcarchive}
export_path=${export_path:-/tmp/PlynKeyboard-TestFlight-upload-$build_number}
export_options_plist=$(mktemp /tmp/PlynKeyboard-TestFlight-export-options.XXXXXX)

cat > "$export_options_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>upload</string>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>$team_id</string>
  <key>uploadSymbols</key>
  <true/>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
</dict>
</plist>
EOF

cleanup() {
  rm -f "$export_options_plist"
}

trap cleanup EXIT INT TERM

run_cmd() {
  echo "$*"
  if [ "$dry_run" -eq 0 ]; then
    "$@"
  fi
}

if [ "$skip_build_number_update" -eq 0 ]; then
  run_cmd "$script_dir/set_ios_build_number.sh" "$build_number"
fi

run_cmd rm -rf "$archive_path" "$export_path"
run_cmd xcodebuild archive \
  -workspace "$workspace_path" \
  -scheme "$scheme_name" \
  -configuration Release \
  -destination generic/platform=iOS \
  -archivePath "$archive_path" \
  -allowProvisioningUpdates

run_cmd xcodebuild -exportArchive \
  -archivePath "$archive_path" \
  -exportPath "$export_path" \
  -exportOptionsPlist "$export_options_plist" \
  -allowProvisioningUpdates

echo "Finished TestFlight upload flow for build $build_number"
