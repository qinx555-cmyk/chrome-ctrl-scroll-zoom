#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h}"
# Prefer standalone CLT when available; otherwise use the selected Xcode.
if [[ -z "${DEVELOPER_DIR:-}" && -x /Library/Developer/CommandLineTools/usr/bin/swiftc ]]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi
output_app="$project_dir/dist/Chrome 滚轮缩放.app"
build_dir=$(mktemp -d -t chrome-scroll-build)
trap 'rm -rf "$build_dir"' EXIT
app_dir="$build_dir/Chrome 滚轮缩放.app"
mkdir -p "$app_dir/Contents/MacOS"
cp -X "$project_dir/Info.plist" "$app_dir/Contents/Info.plist"
for architecture in arm64 x86_64; do
  /usr/bin/xcrun swiftc -O -target "$architecture-apple-macos13.0" \
    -framework AppKit -framework ApplicationServices \
    "$project_dir/Sources/ScrollQuantizer.swift" "$project_dir/Sources/main.swift" \
    -o "$build_dir/ChromeScrollZoom-$architecture"
done
/usr/bin/xcrun lipo -create "$build_dir/ChromeScrollZoom-arm64" "$build_dir/ChromeScrollZoom-x86_64" \
  -o "$app_dir/Contents/MacOS/ChromeScrollZoom"
# Sign outside file-provider folders, which may attach Finder metadata.
/usr/bin/codesign --force --sign - --identifier com.qinxin.chrome-ctrl-scroll-zoom "$app_dir"
/usr/bin/codesign --verify --strict "$app_dir"
/usr/bin/ditto --noextattr --norsrc "$app_dir" "$output_app"
# package.sh verifies a clean copy again; file providers can add output metadata.
print -r -- "$output_app"
