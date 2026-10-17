#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h}"
if [[ -z "${DEVELOPER_DIR:-}" && -x /Library/Developer/CommandLineTools/usr/bin/swiftc ]]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi
test_dir=$(mktemp -d -t chrome-scroll-tests)
trap 'rm -rf "$test_dir"' EXIT
/usr/bin/xcrun swiftc "$project_dir/Sources/ScrollQuantizer.swift" \
    "$project_dir/Tests/main.swift" -o "$test_dir/scroll-tests"
"$test_dir/scroll-tests"
/usr/bin/xcrun swiftc "$project_dir/Sources/ZoomMenuPolicy.swift" \
    "$project_dir/Tests/ZoomMenuPolicy/main.swift" -o "$test_dir/menu-tests"
"$test_dir/menu-tests"
