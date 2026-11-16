#!/bin/bash
# Builds Tiller.app, TillerTestWindows.app and tiller-proof into build/, signed with your Apple Development certificate.
# A stable signature keeps the Accessibility permission after each rebuild.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
bin=$(swift build -c release --show-bin-path)
identity=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')
[ -n "$identity" ] || { echo "An Apple Development certificate wasn't found in the keychain."; exit 1; }

# The .icns file contains one appearance. The light and dark appearances need an asset catalog, and actool ships only with Xcode.
mkdir -p build
iconset=$(mktemp -d)/AppIcon.iconset
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  sips -z $size $size Resources/AppIcon-dark.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) Resources/AppIcon-dark.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o build/AppIcon.icns

bundle() { # name bundle-id agent
  local app="build/$1.app"
  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cp "$bin/$1" "$app/Contents/MacOS/$1"
  cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>$1</string>
  <key>CFBundleIdentifier</key><string>$2</string>
  <key>CFBundleName</key><string>$1</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSUIElement</key><$3/>
  <key>CFBundleIconFile</key><string>AppIcon</string>
</dict></plist>
PLIST
  cp build/AppIcon.icns "$app/Contents/Resources/"
  cp Resources/menubar.png Resources/menubar@2x.png "$app/Contents/Resources/"
  codesign --force --sign "$identity" "$app"
}

mkdir -p build
bundle Tiller com.tiller.Tiller true
bundle TillerTestWindows com.tiller.TestWindows false
cp "$bin/tiller-proof" build/tiller-proof
codesign --force --sign "$identity" build/tiller-proof
echo "Built into build/ with: $identity"
