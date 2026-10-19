#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
swift build -c release
binary_dir="$(swift build -c release --show-bin-path)"
app_dir="$project_dir/build/ChiikawaCompanion.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/ChiikawaCompanion" "$app_dir/Contents/MacOS/ChiikawaCompanion"
cp "$project_dir"/Sources/ChiikawaCompanion/Resources/*.png "$app_dir/Contents/Resources/"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.chiikawa.companion</string>
  <key>CFBundleName</key><string>ChiikawaCompanion</string>
  <key>CFBundleDisplayName</key><string>치이카와 데스크톱</string>
  <key>CFBundleExecutable</key><string>ChiikawaCompanion</string>
  <key>CFBundleVersion</key><string>12</string>
  <key>CFBundleShortVersionString</key><string>0.6.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
"$binary_dir/ChiikawaCompanion" --render-artwork "$project_dir/build/artwork"
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
