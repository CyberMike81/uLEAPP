#!/bin/bash
set -euo pipefail
project_dir=$(cd "$(dirname "$0")/.." && pwd)
repository_dir=$(cd "$project_dir/.." && pwd)
build_dir="$project_dir/build"
app_dir="$project_dir/uLEAPP.app"
mkdir -p "$build_dir/module-cache" "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"

# Make a universal binary so the same app works on Apple silicon and Intel.
for architecture in arm64 x86_64; do
    /usr/bin/xcrun swiftc -swift-version 5 -O \
        -target "$architecture-apple-macos13.0" \
        -module-cache-path "$build_dir/module-cache" \
        -framework SwiftUI -framework AppKit \
        "$project_dir"/Sources/*.swift -o "$build_dir/uLEAPP-$architecture"
done
/usr/bin/lipo -create "$build_dir/uLEAPP-arm64" "$build_dir/uLEAPP-x86_64" \
    -output "$app_dir/Contents/MacOS/uLEAPP"

/usr/bin/xcrun swiftc -module-cache-path "$build_dir/module-cache" \
    "$project_dir/tools/MakeIcon.swift" -o "$build_dir/MakeIcon"
"$build_dir/MakeIcon" "$project_dir/Assets/AppIcon.png"
iconset_dir="$build_dir/AppIcon.iconset"
mkdir -p "$iconset_dir"
for pixels in 16 32 128 256 512; do
    /usr/bin/sips -z "$pixels" "$pixels" "$project_dir/Assets/AppIcon.png" \
        --out "$iconset_dir/icon_${pixels}x${pixels}.png" >/dev/null
    retina=$((pixels * 2))
    /usr/bin/sips -z "$retina" "$retina" "$project_dir/Assets/AppIcon.png" \
        --out "$iconset_dir/icon_${pixels}x${pixels}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$iconset_dir" -o "$app_dir/Contents/Resources/AppIcon.icns"
cp "$project_dir/scripts/LEAPP Updater.command" "$app_dir/Contents/Resources/"
cp "$project_dir/scripts/askpass.sh" "$app_dir/Contents/Resources/"
cp "$repository_dir/LICENSE" "$repository_dir/THIRD-PARTY-NOTICES.md" "$app_dir/Contents/Resources/"
/usr/bin/ditto --norsrc "$repository_dir/licenses" "$app_dir/Contents/Resources/licenses"
/usr/bin/ditto --norsrc "$repository_dir/assets/tool-icons" "$app_dir/Contents/Resources/tool-icons"
chmod 755 "$app_dir/Contents/MacOS/uLEAPP" "$app_dir/Contents/Resources/askpass.sh" \
    "$app_dir/Contents/Resources/LEAPP Updater.command"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>uLEAPP</string>
  <key>CFBundleIdentifier</key><string>org.uleapp.updater</string>
  <key>CFBundleName</key><string>uLEAPP</string>
  <key>CFBundleDisplayName</key><string>uLEAPP</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.3.6</string>
  <key>CFBundleVersion</key><string>10</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
</dict></plist>
PLIST
/usr/bin/xattr -cr "$app_dir"
/usr/bin/codesign --force --sign - --timestamp=none "$app_dir"
printf '\nBuilt %s\n' "$app_dir"
