#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h}"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/Info.plist")
app_dir="$project_dir/dist/通用滚轮缩放.app"
stage_dir=$(mktemp -d -t chrome-scroll-package)
trap 'rm -rf "$stage_dir"' EXIT
[[ -d "$app_dir" ]] || { print -u2 '请先运行 ./build.sh'; exit 1; }
mkdir -p "$stage_dir/ScrollZoom"
/usr/bin/ditto --noextattr --norsrc "$app_dir" "$stage_dir/ScrollZoom/通用滚轮缩放.app"
cp "$project_dir/docs/使用说明.md" "$stage_dir/ScrollZoom/使用说明.md"
ln -s /Applications "$stage_dir/ScrollZoom/Applications"
/usr/bin/codesign --verify --strict "$stage_dir/ScrollZoom/通用滚轮缩放.app"
base_name="ScrollZoom-$version-universal"
zip_path="$project_dir/dist/$base_name.zip"
dmg_path="$project_dir/dist/$base_name.dmg"
/usr/bin/ditto -c -k --norsrc --keepParent "$stage_dir/ScrollZoom" "$zip_path"
/usr/bin/hdiutil create -ov -quiet -volname '通用滚轮缩放' \
  -srcfolder "$stage_dir/ScrollZoom" -format UDZO "$dmg_path"
(cd "$project_dir/dist" && /usr/bin/shasum -a 256 "$base_name.zip" "$base_name.dmg" > SHA256SUMS.txt)
print -r -- "$zip_path" "$dmg_path"
