#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
swift build -c release
binary_dir="$(swift build -c release --show-bin-path)"
app_dir="$project_dir/build/ChiikawaCompanion.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/ChiikawaCompanion" "$app_dir/Contents/MacOS/ChiikawaCompanion"
cp -R "$project_dir/Sources/ChiikawaCompanion/Resources/." "$app_dir/Contents/Resources/"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.chiikawa.companion</string>
  <key>CFBundleName</key><string>ChiikawaCompanion</string>
  <key>CFBundleDisplayName</key><string>치이카와 데스크톱</string>
  <key>CFBundleExecutable</key><string>ChiikawaCompanion</string>
  <key>CFBundleVersion</key><string>51</string>
  <key>CFBundleShortVersionString</key><string>0.24.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
"$binary_dir/ChiikawaCompanion" --render-artwork "$project_dir/build/artwork"
# Render native animation once during packaging; the running app only decodes atlases.
# These generated files predate the character-specific item and activity rules.
# Remove both the export and bundle copies when rebuilding an existing checkout.
for friend in usagi kurimanju momonga rakko shisa kani; do
  for retired_action in guitar vomit study eat camera; do
    rm -f "$project_dir/build/roster/$friend/$retired_action-12.png" \
      "$app_dir/Contents/Resources/Roster/$friend/$retired_action-12.png"
  done
  rm -f "$app_dir/Contents/Resources/$friend-expression-study-v38.png"
  if [ "$friend" != usagi ]; then
    rm -f "$project_dir/build/roster/$friend/attack-12.png" \
      "$app_dir/Contents/Resources/Roster/$friend/attack-12.png" \
      "$app_dir/Contents/Resources/$friend-expression-attack-v38.png"
  fi
done
for expression in laugh attack surprised sleep neutral; do
  rm -f "$app_dir/Contents/Resources/usagi-expression-$expression-v38.png"
done
"$binary_dir/ChiikawaCompanion" --render-roster "$project_dir/build/roster"
mkdir -p "$app_dir/Contents/Resources/Roster"
for friend in usagi kurimanju momonga rakko shisa kani; do
  mkdir -p "$app_dir/Contents/Resources/Roster/$friend"
  cp "$project_dir/build/roster/$friend/"*-24.png "$project_dir/build/roster/$friend/"*-12.png "$app_dir/Contents/Resources/Roster/$friend/"
done
icon_dir="$project_dir/build/AppIcon.iconset"
mkdir -p "$icon_dir"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$project_dir/build/artwork/icon.png" --out "$icon_dir/icon_${size}x${size}.png" >/dev/null
  double_size=$((size * 2))
  sips -z "$double_size" "$double_size" "$project_dir/build/artwork/icon.png" --out "$icon_dir/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$icon_dir" -o "$app_dir/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier local.chiikawa.companion "$app_dir"
echo "Built: $app_dir"
