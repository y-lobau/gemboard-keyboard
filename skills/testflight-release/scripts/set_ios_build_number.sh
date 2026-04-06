#!/bin/sh

set -eu

usage() {
  cat <<'EOF'
Usage: set_ios_build_number.sh <build-number>

Updates CURRENT_PROJECT_VERSION in ios/PlynKeyboard.xcodeproj/project.pbxproj.
The build number must be a positive integer.
EOF
}

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 1
fi

build_number="$1"

case "$build_number" in
  ''|*[!0-9]*)
    echo "Build number must be a positive integer: $build_number" >&2
    exit 1
    ;;
esac

if [ "$build_number" -le 0 ]; then
  echo "Build number must be greater than zero: $build_number" >&2
  exit 1
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
skill_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
repo_dir=$(CDPATH= cd -- "$skill_dir/../.." && pwd)
project_file="$repo_dir/ios/PlynKeyboard.xcodeproj/project.pbxproj"

if [ ! -f "$project_file" ]; then
  echo "Could not find Xcode project file: $project_file" >&2
  exit 1
fi

tmp_file=$(mktemp)
sed -E "s/(CURRENT_PROJECT_VERSION = )[0-9]+;/\\1$build_number;/g" "$project_file" > "$tmp_file"

if cmp -s "$project_file" "$tmp_file"; then
  rm -f "$tmp_file"
  echo "Build number already set to $build_number"
  exit 0
fi

mv "$tmp_file" "$project_file"
echo "Updated CURRENT_PROJECT_VERSION to $build_number in $project_file"
