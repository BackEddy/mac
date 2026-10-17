#!/bin/bash
# Compila o Backeddy. Por padrão instala em ~/Applications e abre.
#   SKIP_INSTALL=1 ./build.sh   → só compila em build/ (usado pelo release.sh)
set -e
cd "$(dirname "$0")"
NAME="Backeddy"
APP="build/$NAME.app"
VERSION=$(cat VERSION 2>/dev/null || echo "0.0.0")
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo 1)

rm -rf build; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" docs

echo "Gerando ícone..."
mkdir -p build/AppIcon.iconset
cp assets/AppIcon.png build/icon_1024.png      # ícone (fonte editável em assets/AppIcon.svg)
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon_1024.png --out build/AppIcon.iconset/icon_${s}x${s}.png >/dev/null
  d=$((s*2)); sips -z $d $d build/icon_1024.png --out build/AppIcon.iconset/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
sips -z 256 256 build/icon_1024.png --out docs/icon.png >/dev/null   # ícone usado no README

[ -f assets/avatar.jpg ] && cp assets/avatar.jpg "$APP/Contents/Resources/avatar.jpg"

echo "Compilando $NAME $VERSION ($BUILD_NUMBER)..."
swiftc -O -parse-as-library Sources/*.swift -o "$APP/Contents/MacOS/$NAME" \
  -framework SwiftUI -framework AppKit -framework IOKit -framework ServiceManagement

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>br.com.backeddy.mac</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>pt</string><string>en</string><string>es</string></array>
  <key>NSHumanReadableCopyright</key><string>© 2026 Eddy Antonini — eddyantonini.com.br — MIT License</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSLocalNetworkUsageDescription</key><string>Backeddy procura o Backeddy Server na sua rede para configurar o Time Machine.</string>
  <key>NSBonjourServices</key><array><string>_backeddy._tcp</string></array>
  <key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
PLIST

# Assinatura para uso local (o release.sh reassina com Developer ID)
ID=$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development|Developer ID Application/{print $2; exit}')
if [ -n "$ID" ]; then
  codesign --force --deep -s "$ID" "$APP" && echo "Assinado com: $ID"
else
  codesign --force --deep -s - "$APP"
  echo "⚠️  Assinatura ad-hoc: o Acesso Total ao Disco pode precisar ser reativado após cada build."
fi

[ "$SKIP_INSTALL" = "1" ] && { echo "✅ Compilado em $APP"; exit 0; }

pkill -x "$NAME" 2>/dev/null || true
pkill -x "Backup TM" 2>/dev/null || true
rm -rf "$HOME/Applications/Backup TM.app"          # versão antiga
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/$NAME.app"
cp -R "$APP" "$HOME/Applications/"
touch "$HOME/Applications/$NAME.app"
echo "✅ Instalado em ~/Applications/$NAME.app"
sleep 1; open "$HOME/Applications/$NAME.app"
